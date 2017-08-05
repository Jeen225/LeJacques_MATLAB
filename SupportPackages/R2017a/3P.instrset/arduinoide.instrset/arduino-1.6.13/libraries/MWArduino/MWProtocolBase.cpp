/**
 * @file MWProtocolBase.cpp
 *
 * Class definition for MWProtocolBase class that implements server/client communication protocol between MATLAB and Arduino
 *
 * @copyright Copyright 2016 The MathWorks, Inc.
 *
 */

#include "MWProtocolBase.h"
#include "MacroInclude.h"
#include <avr/pgmspace.h>

const char MSG_MWPROTOCOL_INPUT_DATA[]            PROGMEM = "MWProtocol::inputData %d\n";
const char MSG_MWPROTOCOL_PAYLOAD_SIZE[]          PROGMEM = "MWProtocol::inputDataBuffer[0] %d, inputDataBuffer[1] %d\n";
const char MSG_MWPROTOCOL_BYTES_READ[]            PROGMEM = "MWProtocol::bytesRead %d\n";
const char MSG_MWPROTOCOL_CHECKSUM[]              PROGMEM = "MWProtocol::computedChecksum %d, receivedChecksum %d\n";

//******************************************************************************
//* Public Methods
//******************************************************************************
#include "MWProtocolSerial.h"
// Conditional include - limit compiled binary size for boards with small memory and don't need WiFi libraries
#if defined(CONNECTION_TYPE_WIFI) 
#include "MWProtocolWiFi.h"
#endif
MWProtocolBase* MWProtocolBase::getMWProtocol(byte type)
{
  switch(type){
    case PROTOCOL_TYPE_SERIAL:{ 
      // Both serial and bluetooth connection use this protocol type
      return new MWProtocolSerial();
    }
    #if defined(CONNECTION_TYPE_WIFI) 
    case PROTOCOL_TYPE_TCPIP:{
      return new MWProtocolWiFi();
    }
    #endif
    default:{} 
  } 
}

MWProtocolBase::MWProtocolBase()
{
  #ifdef MW_TRACEON
    m_isTraceOn = 0x01;
  #else
    m_isTraceOn = 0x00;
  #endif
  systemReset();
}

/* begin method for overriding default serial bitrate */
void MWProtocolBase::begin() const
{}

void MWProtocolBase::update()
{
  while(bytesAvailable()) {
      processInput();
  }
}
 
// resets the system state upon a SYSTEM_RESET message from the host software
void MWProtocolBase::systemReset(void)
{
  for(size_t iLoop=0; iLoop<MAX_MESSAGE_SIZE; iLoop++) {
	    m_inputDataBuffer[iLoop] = 0;
  }
}

void MWProtocolBase::sendResponseMsg(byte cmdID, byte* dataIn, unsigned int payloadSize) const { 
// returning message format: header, debugID, payloadSize, cmdID, data, checksum
//                                            |_______ checksum ______|
//                                                         |____ payload _______|
//
    writeByte(ARDUINO_RESPONSE_HEADER); 
    writeByte(uint8_t(0)); // debugID: 0 - non debug msg; 1 - debug msg
    size_t dataLen = payloadSize;
    payloadSize += 2; //actual message payloadSize is data + 1 byte of cmdID and 1 byte of checksum
    writeByte(payloadSize >> 8); // msb   
    writeByte(payloadSize & 0xff); // lsb
    writeByte(cmdID);
    for(size_t iLoop = 0; iLoop < dataLen; ++iLoop){
        writeByte(dataIn[iLoop]);
    }
    // introduce another computeChecksum method to get around of creating a temp arrary to form the complete message
    writeByte(computeMsgOutChecksum(cmdID, dataIn, payloadSize)); 
    
    #if defined(CONNECTION_TYPE_SERIAL)||defined(CONNECTION_TYPE_BLUETOOTH)
    #if defined(ARDUINO_AVR_LEONARDO)||defined(ARDUINO_AVR_MICRO)
    // Add 1 millisecond delay since serial transmission on Atmega32u4 microprocessor
    // is faster so that it does not fill up host's buffer too fast. See best coding
    // practices in below link,
    // http://arduino.cc/en/Guide/ArduinoLeonardoMicro?from=Guide.ArduinoLeonardo#toc13
    delay(1);
    #endif 
    // empty receive buffer
    while(bytesAvailable()){
        readByte();
    }
    #endif
}

// HEADER payloadSize nonaddonHeader+sequenceID cmdID Data Checksum
//  0x5A  |_______________ checksum _____________________|
//                    |_________________ payload __________________|
//        |________________ m_inputDataBuffer _____________________|
//
void MWProtocolBase::processInput(void)
{
  int inputData = readByte(); // use type int to handle possible return value of -1
  // devDebugHelperVar1(MSG_MWPROTOCOL_INPUT_DATA, inputData);

  if (inputData == MATLAB_MESSAGE_HEADER) {
    readBytes(m_msg.pPayloadSize, 2);
    m_payloadSize = m_msg.pPayloadSize[0]+(m_msg.pPayloadSize[1]<<8);
    
    // devDebugHelperVar2(MSG_MWPROTOCOL_PAYLOAD_SIZE, m_msg.pPayloadSize[0], m_msg.pPayloadSize[1]);

    size_t bytesRead = 0;
    if(m_payloadSize != 0 && m_payloadSize < MAX_MESSAGE_SIZE){
      bytesRead = readBytes(m_msg.pPayload, m_payloadSize);
      // devDebugHelperVar1(MSG_MWPROTOCOL_BYTES_READ, bytesRead);
    }

    if(bytesRead == m_payloadSize){
      m_receivedChecksum = m_msg.pPayload[m_payloadSize-1]; // checksum is the second last byte in payload
      if(checkMsgIntegrity(m_msg.pPayloadSize)){
        processMessage();
      }// End of checkMsgIntegrity
    }// End of bytesRead == m_payloadSize
  }// End of inputData == MATLAB_MESSAGE_HEADER
}

void MWProtocolBase::attach(msgDispatcher newFunction)
{
  m_currentMsgDispatcher = newFunction;
}



//******************************************************************************
//* Private Methods
//******************************************************************************
void MWProtocolBase::processMessage(void)
{
  byte isLib      = (m_msg.pPayload[0] & 0x80) >> 7;
  byte sequenceID = m_msg.pPayload[0]&B01111111;
  unsigned int userDataLength; 
  userDataLength = m_payloadSize-3;// excluding 1 byte of sequenceID, 1 byte of cmdID and 1 byte of checksum
  (*m_currentMsgDispatcher)(isLib, m_msg.pCmdID, userDataLength); 
}

// Given a message, check if the computed checksum matches with the received checksum
const boolean MWProtocolBase::checkMsgIntegrity(byte* message) const {
  // length of data to compute checksum is payload size plus two bytes of payloadSize minus one byte of received checksum
  size_t dataLen = m_payloadSize+1;
  const byte computedChecksum = computeMsgInChecksum(message, dataLen); 
  // devDebugHelperVar2(MSG_MWPROTOCOL_CHECKSUM, computedChecksum, m_receivedChecksum);

  if(computedChecksum != m_receivedChecksum){
    return false;
  }
  return true;
}

// simply modular sum checksum - sum(a byte) of all bytes in data results into 0x00
const byte MWProtocolBase::computeMsgInChecksum(byte* data, size_t dataLen) const {
  byte sum = 0;
  for(size_t iLoop = 0; iLoop < dataLen; ++iLoop){ // Use size_t in case length is big
    sum += data[iLoop];
  }
  return 256-sum;
}

const byte MWProtocolBase::computeMsgOutChecksum(byte cmdID, byte* dataIn, size_t payloadSize) const {
  byte sum = cmdID;
  size_t dataLen = payloadSize -2; // payloadSize is data + 1 byte of cmdID and 1 byte of checksum
  for(size_t iLoop = 0; iLoop < dataLen; ++iLoop){
    sum += dataIn[iLoop];
  }
  sum += (payloadSize >> 8);
  sum += (payloadSize & 0xff);
  return 256-sum;
}

#ifdef MW_TRACEON
void MWProtocolBase::debugPrint(va_list args, char *fmt_char ) const{
  char tmp[100]; // resulting string limited to 100 chars
  vsnprintf(tmp, 100, fmt_char, args);
  va_end (args);
  
  uint8_t count = strlen(tmp);
  
  // format of debug message is count, e.g number of chars, followed by the message
  writeByte(ARDUINO_RESPONSE_HEADER); 
  writeByte(uint8_t(1)); // debugID: 0 - non debug msg; 1 - debug msg
  writeByte(count);
  print(tmp);
  
  // Add 1 millisecond delay since serial transmission on Atmega32u4 microprocessor 
  // is faster so that it does not fill up host's buffer too fast. See best coding 
  // practices in below link,
  // http://arduino.cc/en/Guide/ArduinoLeonardoMicro?from=Guide.ArduinoLeonardo#toc13
  delay(1);
}
#else
void MWProtocolBase::debugPrint(va_list args, char *fmt_char ) const{
        // do nothing
}
#endif





