/**
 * @file SPIBase.h
 *
 * Class definition for SPIBase class that wraps APIs of SPI library
 *
 * @copyright Copyright 2014-2016 The MathWorks, Inc.
 *
 */
#ifndef SPIBase_h
#define SPIBase_h

#include "SPI.h"
#include "LibraryBase.h"

//const char MSG_SPI_ENTER_COMMAND_HANDLER[] 	PROGMEM = "SPIBase::commandHandler: cmdID %d\n";
//const char MSG_SPI_UNRECOGNIZED_COMMAND[] 	PROGMEM = "SPIBase::commandHandler:unrecognized command ID %d\n";
        
// Arduino trace commands
const char MSG_SPI_BEGIN[]                   PROGMEM = "Arduino::SPI.begin();\n";
const char MSG_SPI_BEGIN_TRANSACTION[]       PROGMEM = "Arduino::SPI.beginTransaction(SPISettings(%lu, %s, %s));\n";
const char MSG_SPI_BEGIN_DUE[]               PROGMEM = "Arduino::SPI.begin(%d);\n";
const char MSG_SPI_END[]                     PROGMEM = "Arduino::SPI.end();\n";
const char MSG_SPI_END_DUE[]                 PROGMEM = "Arduino::SPI.end(%d);\n";
const char MSG_SPI_END_TRANSACTION[]         PROGMEM = "Arduino::SPI.endTransaction();\n";
const char MSG_SPI_TRANSFER[]                PROGMEM = "Arduino::SPI.transfer(%d); --> %d\n";
const char MSG_SPI_TRANSFER_DUE[]            PROGMEM = "Arduino::SPI.transfer(%d, %d, %s); --> %d\n";

#define START_SPI      0x00
#define STOP_SPI       0x01
#define SET_BIT_RATE   0x02
#define SET_BIT_ORDER  0x03
#define SET_MODE       0x04
#define WRITE_READ     0x05

class SPITrace {
public:
    #if defined(ARDUINO_ARCH_SAM) 
    static void begin(byte cspin) {
        ArduinoTrace::pinMode(cspin, OUTPUT);
        // Pull chip select pin high by default to ensure it's low only during transfer of data
        ArduinoTrace::digitalWrite(cspin, HIGH); 
        SPI.begin(cspin);
        debugPrint(MSG_SPI_BEGIN_DUE, cspin);
    }

    static void end(byte cspin) {
        SPI.end(cspin);
        debugPrint(MSG_SPI_END_DUE, cspin);
    }

    static byte transfer(byte cspin, byte val, SPITransferMode transferMode = SPI_LAST) {
        byte dataRead = SPI.transfer(cspin, val, transferMode);
        switch (transferMode) {
			case SPI_CONTINUE:
				debugPrint(MSG_SPI_TRANSFER_DUE, cspin, val, "SPI_CONTINUE", dataRead);
				break;
			case SPI_LAST:
				debugPrint(MSG_SPI_TRANSFER_DUE, cspin, val, "SPI_LAST", dataRead);
				break;
			default:
				char szBuffer[8];
				debugPrint(MSG_SPI_TRANSFER_DUE, cspin, val, itoa(transferMode, szBuffer, 10), dataRead);
				break;
        }
        return dataRead;
    }

    #else
    static void begin(byte cspin, bool& hasBegin) {
        ArduinoTrace::pinMode(cspin, OUTPUT);
        // Pull chip select pin high by default to ensure it's low only during transfer of data
        ArduinoTrace::digitalWrite(cspin, HIGH); 
        if(!hasBegin){
            SPI.begin();
            debugPrint(MSG_SPI_BEGIN);
            hasBegin = true;
        }
    }

    static void end(bool& hasBegin) {
        SPI.end();
        hasBegin = false;
        debugPrint(MSG_SPI_END);
    }
    
    static byte transfer(byte val) {
        byte dataRead = SPI.transfer(val);
        debugPrint(MSG_SPI_TRANSFER, val, dataRead);
        return dataRead;
    }
    #endif
    
    static void beginTransaction(uint32_t clock, uint8_t bitOrder, uint8_t dataMode) {
        char modeStr[] = "SPI_MODE0\0";
        byte mode;
        switch (dataMode) {
            case 0:
                mode = SPI_MODE0;
                break;
            case 1:
                mode = SPI_MODE1;
                modeStr[8] = '1';
                break;
            case 2:
                mode = SPI_MODE2;
                modeStr[8] = '2';
                break;
            case 3:
                mode = SPI_MODE3;
                modeStr[8] = '3';
                break;
            default:
                break;
        }
        #if defined(ARDUINO_ARCH_SAM) || defined(ARDUINO_ARCH_SAMD)
        SPISettings settings(clock, BitOrder(bitOrder), mode);
        #else
        SPISettings settings(clock, bitOrder, mode);
        #endif
        SPI.beginTransaction(settings);
        char orderStr[] = "MSBFIRST\0";
        switch (bitOrder) {
			case MSBFIRST:
				// do nothing
				break;
			case LSBFIRST:
				orderStr[0] = 'L';
				break;
			default:
				break;
		}
        debugPrint(MSG_SPI_BEGIN_TRANSACTION, clock, orderStr, modeStr);
    }

    static void endTransaction() {
        SPI.endTransaction();
        debugPrint(MSG_SPI_END_TRANSACTION);
    }
};

class SPIBase : public LibraryBase
{	
    private:
        uint32_t clock;
        byte mode;
        byte order;
        bool hasBegin = false;
        
	public:
		SPIBase(MWArduinoClass& a)
		{
            libName = "SPI";
			a.registerLibrary(this);
		}
		void setup()
        {
            hasBegin = false;
        }
	// Implementation of LibraryBase
	//
	public:
		void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
		{
            //debugPrint(MSG_SPI_ENTER_COMMAND_HANDLER, cmdID);
            switch (cmdID){
                case START_SPI:{ 
                    byte cspin = dataIn[0];
					
                    #if defined(ARDUINO_ARCH_SAM) 
                    SPITrace::begin(cspin);
                    #else
                    SPITrace::begin(cspin, hasBegin);
                    #endif
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case STOP_SPI:{ 
                    byte cspin = dataIn[0];
                    
                    #if defined(ARDUINO_ARCH_SAM) 
                    SPITrace::end(cspin);
                    #else
                    SPITrace::end(hasBegin);
                    #endif
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case SET_BIT_RATE:{
                    clock = uint32_t(dataIn[1])+(uint32_t(dataIn[2])<<8)+(uint32_t(dataIn[3])<<16)+(uint32_t(dataIn[4])<<24);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case SET_BIT_ORDER:{
                    order = dataIn[1];
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case SET_MODE:{
                    mode = dataIn[1];
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case WRITE_READ:{ 
                    byte cspin = dataIn[0];
                    byte len   = dataIn[1];

                    byte dataRead;
                    byte dataToSend;

                    byte* val;
                    val = dataIn + 2;

                    SPITrace::beginTransaction(clock, order, mode);
                    
                    #if defined(ARDUINO_ARCH_SAM) 
                    ArduinoTrace::digitalWrite(cspin, LOW);
                    for(byte i = 0; i < len-1; ++i){
                        dataToSend = val[i];
                        dataRead = SPITrace::transfer(cspin, dataToSend, SPI_CONTINUE);
                        val[i] = dataRead;
                    }
                    dataToSend = val[len-1];
                    dataRead = SPITrace::transfer(cspin, dataToSend, SPI_LAST);
                    val[len-1] = dataRead;
                    ArduinoTrace::digitalWrite(cspin, HIGH);
                    #else
                    ArduinoTrace::digitalWrite(cspin, LOW);
                    for(byte i = 0; i < len; ++i){
                        dataToSend = val[i];
                        dataRead = SPITrace::transfer(dataToSend);
                        val[i] = dataRead;
                    }
                    ArduinoTrace::digitalWrite(cspin, HIGH);
                    #endif
                    SPITrace::endTransaction();
                    
                    sendResponseMsg(cmdID, val, len);
                    break;
                }
                default:
                    //debugPrint(MSG_SPI_UNRECOGNIZED_COMMAND, cmdID);
					break;
            }
		}
};

#endif