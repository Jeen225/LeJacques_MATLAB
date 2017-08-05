/**
 * @file MWProtocolWiFi.h
 *
 * Class prototype for MWProtocolWiFi class that implements server/client communication protocol between MATLAB and Arduino
 *
 * @copyright Copyright 2016 The MathWorks, Inc.
 *
 */
#ifndef MWProtocolWiFi_h
#define MWProtocolWiFi_h

#if defined(ARDUINO_ARCH_SAMD)  

#include "SPI.h"
#include "WiFi101.h"
#include "MWProtocolBase.h"
#include "MacroInclude.h"

class MWProtocolWiFi: public MWProtocolBase
{
public: 
    const bool connectClient();
    void begin() const;  
    void update();
    void systemReset(void);

private:
    const int bytesAvailable(void) const;
    void writeByte(byte data) const; 
    void print(char* data) const; 
    const int readByte() const;     
    const int readBytes(byte* buffer, size_t length); 
    void respondDeviceInfo(void) const;
    bool isConnected = false;
};

#endif 

#endif /* MWProtocolWiFi_h */

