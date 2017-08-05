/**
 * @file MWProtocolSerial.cpp
 *
 * Class definition for MWProtocolSerial class that implements server/client communication protocol between MATLAB and Arduino
 *
 * @copyright Copyright 2016 The MathWorks, Inc.
 *
 */

#include "MWProtocolSerial.h"
#include "HardwareSerial.h"
#include "MacroInclude.h"

#ifndef MW_BAUDRATE
#define MW_BAUDRATE 0
#endif
//******************************************************************************
//* Public Methods
//******************************************************************************
 // On Leonardo and Micro board, Serial is only for serial over CDC(USB) usage. 
 // For TTL serial usage of pin 0/1, Serial1 shall be used
 #if defined(CONNECTION_TYPE_BLUETOOTH) && (defined(ARDUINO_AVR_LEONARDO) || defined(ARDUINO_AVR_MICRO))
 #define PhysicalSerial Serial1
 #else
 #define PhysicalSerial Serial
 #endif


/* begin method for overriding default serial bitrate */
void MWProtocolSerial::begin() const
{
	PhysicalSerial.begin(MW_BAUDRATE);
  PhysicalSerial.write("MWProtocol");
}

const int MWProtocolSerial::bytesAvailable(void) const
{
	return PhysicalSerial.available();
}

void MWProtocolSerial::writeByte(byte data) const
{
  // There might be a bug in Arduino Serial that its buffer get overflow without a flush after a write.
  // It causes Serial.write to crash arduino board sometimes
  PhysicalSerial.write(data);
  PhysicalSerial.flush();
}

void MWProtocolSerial::print(char* data) const
{
  PhysicalSerial.print(data);
  PhysicalSerial.flush();
}

const int MWProtocolSerial::readByte() const    
{
  return PhysicalSerial.read();
}

const int MWProtocolSerial::readBytes(byte* buffer, size_t length)
{
  return PhysicalSerial.readBytes((char*)buffer, length);
}
 
// resets the system state upon a SYSTEM_RESET message from the host software
void MWProtocolSerial::systemReset(void)
{
  MWProtocolBase::systemReset();
  PhysicalSerial.setTimeout(1000); // set timeout for readBytes to 1000 ms
}





