/**
 * @file MWProtocolWiFi.cpp
 *
 * Class definition for MWProtocolWiFi class that implements server/client communication protocol between MATLAB and Arduino
 *
 * @copyright Copyright 2016 The MathWorks, Inc.
 *
 */
#if defined(ARDUINO_ARCH_SAMD) 
#include "MWProtocolWiFi.h"

//Macro to string conversion
#define STR_EXPAND(tok) #tok
#define STR(tok) STR_EXPAND(tok)

#ifndef MW_PORT 
#define MW_PORT 0
#endif

WiFiServer server{MW_PORT};
WiFiClient client;

//Decode WiFi information
bool decode(char* str, char* origStr){
    if(str==NULL||strlen(str)%4!=0) // input string must be a multiply of 4, if not abort
        return false;
    // define index table
    char table[] = "=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    size_t numInputBytes = strlen(str);
    int numPadEqual = 0;
    // count the number of occurrences of '=' in the last four bytes of input string
    for(int ii=numInputBytes-4;ii<numInputBytes;++ii){
        if(str[ii]=='=')
            numPadEqual++;
    }
    int numLastBytes = 3-numPadEqual;
    int numOutputBytes = (numInputBytes-4)/4*3+numLastBytes;
    int numIters = numInputBytes/4;
    int count = 0;
    int8_t indexes[4]; 
    for(int ii=0;ii<numInputBytes;ii+=4){
        // find char in index table and convert to zero-based
        for(int jj=0;jj<4;jj++){
            char* loc = strchr(table, str[ii+jj]);
            if(loc==NULL) // input string has an invalid character - abort
                return false;
            indexes[jj] = loc-table-1;
        }
        origStr[count++] = (char)(indexes[0]<<2)+(indexes[1]>>4);
        if(indexes[2]!=-1){// not '='
            origStr[count++] = (char)(indexes[1]<<4)+(indexes[2]>>2);
            if(indexes[3]!=-1){// not '='
                origStr[count++] = (char)(indexes[2]<<6)+indexes[3];
            }
        }
    }
    origStr[count] = '\0';
    return true;
}

//******************************************************************************
//* Public Methods
//******************************************************************************
void MWProtocolWiFi::begin() const
{
  // turn on serial for returning IP address
  Serial.begin(9600);
  int status = WL_IDLE_STATUS;     // the Wifi radio's status
    // attempt to connect to Wifi network:
    if(WiFi.status() != WL_CONNECTED) {
        #ifdef MW_STATIC_IP1
        IPAddress ip{MW_STATIC_IP1,MW_STATIC_IP2,MW_STATIC_IP3,MW_STATIC_IP4};
        WiFi.config(ip);
        #endif
        
        char SSID[32];
        #if defined(WIFI_ENCRYPTION_NONE)
        if(decode(STR(MW_SSID), SSID))
            status = WiFi.begin(SSID);
        #elif defined(WIFI_ENCRYPTION_WPA)
        char Password[26];
        if(decode(STR(MW_SSID), SSID)){
            if(decode(STR(MW_PASSWORD), Password))
                status = WiFi.begin(SSID, Password);
        }
        #elif defined(WIFI_ENCRYPTION_WEP)
        char Key[64];
        if(decode(STR(MW_SSID), SSID)){
            if(decode(STR(MW_KEY), Key))
                status = WiFi.begin(SSID, MW_KEYINDEX, Key);
        }
        #endif
    }
    // wait for WiFi connection for up to 10s
    uint8_t timeout = 10;
    while(timeout&&(WiFi.status()!=WL_CONNECTED)){
      delay(1000);
      timeout--;
    }
    if(WiFi.status()==WL_CONNECTED)
        server.begin();
}

const bool MWProtocolWiFi::connectClient() 
{
  if(WiFi.status()!=WL_CONNECTED){
    return false;
  }
  // If server is not connected to any client, check for available client and set flag
  if(!isConnected){
    WiFiClient newclient = server.available();
    if(newclient){
      client = newclient;
      isConnected = (bool)(client.connected());
    }
  }
  // If server is already connected to a client, check for the status of the connection
  // If client has disconnected, clear the flag for reconnection or new connection
  else{
    if(!client.connected())
      isConnected = false;
  }
  return isConnected;
}

void MWProtocolWiFi::update()
{
  // check if client asks for IP address when idle
  if(!isConnected){
      if(Serial.available()){
          respondDeviceInfo();
      }
  }
  bool status = connectClient();
  if(!status)
      return; // no client yet, do nothing and return.
  MWProtocolBase::update();
}

const int MWProtocolWiFi::bytesAvailable(void) const
{
	return client.available();
}

void MWProtocolWiFi::writeByte(byte data) const
{
	client.write(data);
}

void MWProtocolWiFi::print(char* data) const
{
	client.print(data);
}

const int MWProtocolWiFi::readByte() const    
{
	return client.read();
}

const int MWProtocolWiFi::readBytes(byte* buffer, size_t length)
{
	return client.read(buffer, length);
}

void MWProtocolWiFi::systemReset(void)
{
  MWProtocolBase::systemReset();
  client.setTimeout(1000); // set timeout for readBytes to 1000 ms
}
 
const String ipcmd = "whatisyourip";
const byte ipcmdNumBytes = ipcmd.length();

void MWProtocolWiFi::respondDeviceInfo(void) const
{
  // If WiFi connected, return WiFi status;IP;Port
  // If WiFi not connected, return WiFi status
  #ifdef CONNECTION_TYPE_WIFI
  // Request must match exactly with ipcmd string, no more no less
  if(Serial.available() == ipcmdNumBytes){
    byte ipRequestBytes[ipcmdNumBytes];
    Serial.readBytes((char*)ipRequestBytes, ipcmdNumBytes);
    char request[ipcmdNumBytes+1];
    memcpy(request, ipRequestBytes, sizeof(ipRequestBytes));
    request[sizeof(ipRequestBytes)] = '\0';
    if(String(request)==ipcmd){
      Serial.print(WiFi.status());
      Serial.write(';');
      if(WiFi.status()==WL_CONNECTED){
        Serial.print(IPAddress(WiFi.localIP()));
        Serial.write(';');
        Serial.print(MW_PORT); 
        Serial.write(';');
      }
    }
  }
  #endif
}
#endif


