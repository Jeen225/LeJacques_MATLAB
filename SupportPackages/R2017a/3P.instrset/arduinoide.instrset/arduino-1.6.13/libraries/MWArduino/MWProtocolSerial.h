/**
 * @file MWProtocolSerial.h
 *
 * Class prototype for MWProtocolSerial class that implements server/client communication protocol between MATLAB and Arduino
 *
 * @copyright Copyright 2016 The MathWorks, Inc.
 *
 */
#ifndef MWProtocolSerial_h
#define MWProtocolSerial_h

#include "MWProtocolBase.h"

class MWProtocolSerial : public MWProtocolBase
{
public: 
    void begin() const;  
    void systemReset(void);

private:
    const int bytesAvailable(void) const;
    void writeByte(byte data) const; 
    void print(char* data) const; 
    const int readByte() const;     
    const int readBytes(byte* buffer, size_t length); 
};

#endif /* MWProtocolSerial_h */

