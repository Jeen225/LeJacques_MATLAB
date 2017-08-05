/**
 * @file I2CBase.h
 *
 * Class definition for I2CBase class that wraps APIs of Wire library
 *
 * @copyright Copyright 2014-2016 The MathWorks, Inc.
 *
 */
#ifndef I2CBase_h
#define I2CBase_h

#include "Wire.h"
#include "LibraryBase.h"

//const char MSG_I2C_ENTER_COMMAND_HANDLER[] 	PROGMEM = "I2CBase::commandHandler: cmdID %d\n";
//const char MSG_I2C_UNRECOGNIZED_COMMAND[] 	PROGMEM = "I2CBase::commandHandler:unrecognized command ID %d\n";
//const char MSG_I2C_SCAN_BUS[]                PROGMEM = "scanI2CBus(%d)\n";
//const char MSG_I2C_READ_PARAMS[]             PROGMEM = ", params %d, %d, %d\n";
//const char MSG_I2C_WRITE_PARAMS[]            PROGMEM = ", params %d, %d, %d\n";
//const char MSG_I2C_READ_REGISTER_PARAMS[]    PROGMEM = ", params %d, %d, %d, %d\n";
//const char MSG_I2C_READ_VALUES[]             PROGMEM = "Read value: %d\n";
//const char MSG_I2C_WRITE_REGISTER_PARAMS[]   PROGMEM = ", params %d, %d, %d, %d, values ";
//const char MSG_I2C_WRITE_VALUES[]            PROGMEM = "%d, ";

// Arduino trace commands
const char MSG_WIRE_BEGIN[]                  PROGMEM = "Arduino::Wire.begin();\n";
const char MSG_WIRE_BEGINTRANSMISSION[]      PROGMEM = "Arduino::Wire.beginTransmission(%d);\n";
const char MSG_WIRE_ENDTRANSMISSION[]        PROGMEM = "Arduino::Wire.endTransmission(%d); --> %d\n";
const char MSG_WIRE_READ[]                   PROGMEM = "Arduino::Wire.read(); --> %d\n";
const char MSG_WIRE_WRITE[]                  PROGMEM = "Arduino::Wire.write(%d); --> %d\n";
const char MSG_WIRE_WRITE2_1[]               PROGMEM = "Arduino::Wire.write([%d], %d); --> %d\n";
const char MSG_WIRE_WRITE2_2[]               PROGMEM = "Arduino::Wire.write([%d, %d], %d); --> %d\n";
const char MSG_WIRE_WRITE2_3[]               PROGMEM = "Arduino::Wire.write([%d, %d, %d,...], %d); --> %d\n";
const char MSG_WIRE_REQUESTFROM[]            PROGMEM = "Arduino::Wire.requestFrom(%d, %d, %d); --> %d\n";
const char MSG_WIRE1_BEGIN[]                 PROGMEM = "Arduino::Wire1.begin();\n";
const char MSG_WIRE1_BEGINTRANSMISSION[]     PROGMEM = "Arduino::Wire1.beginTransmission(%d);\n";
const char MSG_WIRE1_ENDTRANSMISSION[]       PROGMEM = "Arduino::Wire1.endTransmission(%d); --> %d\n";
const char MSG_WIRE1_READ[]                  PROGMEM = "Arduino::Wire1.read(); --> %d\n";
const char MSG_WIRE1_WRITE[]                 PROGMEM = "Arduino::Wire1.write(%d); --> %d\n";
const char MSG_WIRE1_WRITE2_1[]              PROGMEM = "Arduino::Wire1.write([%d], %d); --> %d\n";
const char MSG_WIRE1_WRITE2_2[]              PROGMEM = "Arduino::Wire1.write([%d, %d], %d); --> %d\n";
const char MSG_WIRE1_WRITE2_3[]              PROGMEM = "Arduino::Wire1.write([%d, %d, %d, ...], %d); --> %d\n";
const char MSG_WIRE1_REQUESTFROM[]           PROGMEM = "Arduino::Wire1.requestFrom(%d, %d, %d); --> %d\n";

#define START_I2C       0x00
#define SCAN_I2C_BUS    0x01
#define READ            0x02
#define WRITE           0x03
#define READ_REGISTER   0x04
#define WRITE_REGISTER  0x05

#define MAX_I2C_DATA_SIZE 145
byte I2CBuffer[MAX_I2C_DATA_SIZE];

bool hasBegin[2] = {false, false};

class WireTrace {
public:
    static void begin() {
        debugPrint(MSG_WIRE_BEGIN);
        Wire.begin();
    }

    static void beginTransmission(int address) {
        debugPrint(MSG_WIRE_BEGINTRANSMISSION, address);
        Wire.beginTransmission(address);
    }

    static byte endTransmission(byte stop = true) {
        byte status = Wire.endTransmission(stop);
        debugPrint(MSG_WIRE_ENDTRANSMISSION, stop, status);
        return status;
    }

    static byte requestFrom(int address, int quantity, int stop = true) {
        byte status = Wire.requestFrom(address, quantity, stop);
        debugPrint(MSG_WIRE_REQUESTFROM, address, quantity, stop, status);
        return status;
    }

    static int read() {
        int value = Wire.read();
        debugPrint(MSG_WIRE_READ, value);
        return value;
    }

    static size_t write(byte value) {
        size_t n = Wire.write(value);
        debugPrint(MSG_WIRE_WRITE, value, n);
        return n;
    }

    static size_t write(byte* value, size_t length) {
        size_t n = Wire.write(value, length);
		switch (length) {
		case 1:
			debugPrint(MSG_WIRE_WRITE2_1, value[0], length, n);
			break;
		case 2:
			debugPrint(MSG_WIRE_WRITE2_2, value[0], value[1], length, n);
			break;
		default:
			debugPrint(MSG_WIRE_WRITE2_3, value[0], value[1], value[2], length, n);
			break;
		}
        return n;
    }
};

class Wire1Trace {
public:
    static void begin() {
        #ifdef ARDUINO_ARCH_SAM
        debugPrint(MSG_WIRE1_BEGIN);
        Wire1.begin();
        #endif
    }

    static void beginTransmission(byte address) {
        #ifdef ARDUINO_ARCH_SAM
        debugPrint(MSG_WIRE1_BEGINTRANSMISSION, address);
        Wire1.beginTransmission(address);
        #endif

    }

    static byte endTransmission(byte stop = true) {
        byte status = -1;
        #ifdef ARDUINO_ARCH_SAM
        status = Wire1.endTransmission(stop);
        debugPrint(MSG_WIRE1_ENDTRANSMISSION, stop, status);
        #endif
        return status;
    }

    static byte requestFrom(int address, int quantity, int stop = true) {
        byte status = -1;
        #ifdef ARDUINO_ARCH_SAM
        status = Wire1.requestFrom(address, quantity, stop);
        debugPrint(MSG_WIRE1_REQUESTFROM, address, quantity, stop, status);
        #endif
        return status;
    }

    static int read() {
        int value = -1;
        #ifdef ARDUINO_ARCH_SAM
        value = Wire1.read();
        debugPrint(MSG_WIRE1_READ, value);
        #endif
        return value;
    }

    static size_t write(byte value) {
        size_t n = -1;
        #ifdef ARDUINO_ARCH_SAM
        n = Wire1.write(value);
        debugPrint(MSG_WIRE1_WRITE, value, n);
        #endif
        return n;
    }

    static size_t write(byte* value, size_t length) {
        size_t n = -1;
        #ifdef ARDUINO_ARCH_SAM
        n = Wire1.write(value, length);
        switch (length) {
		case 1:
			debugPrint(MSG_WIRE1_WRITE2_1, value[0], length, n);
			break;
		case 2:
			debugPrint(MSG_WIRE1_WRITE2_2, value[0], value[1], length, n);
			break;
		default:
			debugPrint(MSG_WIRE1_WRITE2_3, value[0], value[1], value[3], length, n);
			break;
		}
        #endif
        return n;
    }
};

class I2CBase : public LibraryBase
{	
	public:
		I2CBase(MWArduinoClass& a) 
		{
            libName = "I2C";
			a.registerLibrary(this);
		}

        void setup()
        {
            hasBegin[0] = false;
            hasBegin[1] = false;
        }
        
	// Implementation of LibraryBase
	//
	public:
		void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
		{
            //debugPrint(MSG_I2C_ENTER_COMMAND_HANDLER, cmdID);
            switch (cmdID){
                case START_I2C:{  
                    byte bus = dataIn[0];
                    byte address = dataIn[1];
                    
                    if(hasBegin[bus] == false){
                        if(bus == 0){
                            WireTrace::begin();
                        }
                        else{ // For now, only bus 0 and 1 are supported
                            #ifdef ARDUINO_ARCH_SAM
                            Wire1Trace::begin();
                            #endif
                        }
                        hasBegin[bus] = true;
                    }
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case SCAN_I2C_BUS:{ 
                    //debugPrint(MSG_I2C_SCAN_BUS, dataIn[0]);
                    byte bus      = dataIn[0];
                    
                    if(hasBegin[bus] == false){
                        if(bus == 0){
                            WireTrace::begin();
                        }
                        else{
                            #ifdef ARDUINO_ARCH_SAM
                            Wire1Trace::begin();
                            #endif
                        }
                        hasBegin[bus] = true;
                    }
                    
                    byte count = 0;
                    for(byte addr = 8; addr < 120; ++addr){
                        if(bus == 0){
                            WireTrace::beginTransmission(addr);
                            byte code = WireTrace::endTransmission();
                            
                            if(code == 0){
                                I2CBuffer[count++] = addr;
                            }
                        }
                        else{
                            #ifdef ARDUINO_ARCH_SAM
                            Wire1Trace::beginTransmission(addr);
                            byte code = Wire1Trace::endTransmission();
                            
                            if(code == 0){
                                I2CBuffer[count++] = addr;
                            }
                            #endif
                        }
                    }
                    if(count == 0){
                        I2CBuffer[0] = 0;
                    }
                    sendResponseMsg(cmdID, I2CBuffer, count);
                    break;
                }
                case READ:{ 
                    //debugPrint(MSG_I2C_READ_PARAMS, dataIn[0], command[2], command[3]);
                    byte bus      = dataIn[0];
                    byte address  = dataIn[1];
                    byte numBytes = dataIn[2]; // numBytes can only be a byte according to requestFrom API prototype
                    
                    byte dataRead;
                    
                    if(bus == 0){
                        WireTrace::beginTransmission(address);
                        if(WireTrace::requestFrom(address, (uint8_t)numBytes) != numBytes){
                            I2CBuffer[0] = 0xFF;
                        }
                        else{
                            I2CBuffer[0] = 0x00;
                            for(byte i = 1; i < numBytes+1; ++i){
                                I2CBuffer[i] = WireTrace::read();
                            }
                        }
                        WireTrace::endTransmission(true); 
                    }
                    else{
                        #ifdef ARDUINO_ARCH_SAM
                        Wire1Trace::beginTransmission(address);
                        if(Wire1Trace::requestFrom(address, (uint8_t)numBytes) != numBytes){
                            I2CBuffer[0] = 0xFF;
                        }
                        else{
                            I2CBuffer[0] = 0x00;
                            for(byte i = 1; i < numBytes+1; ++i){
                                I2CBuffer[i] = Wire1Trace::read();
                            }
                        }
                        Wire1Trace::endTransmission(false); 
                        #endif
                    }
                    
                    sendResponseMsg(cmdID, I2CBuffer, numBytes+1);
                    break;
                }
                case WRITE:{
                    //debugPrint(MSG_I2C_WRITE_PARAMS, command[1], command[2], command[3]);
                    byte bus      = dataIn[0];
                    byte address  = dataIn[1];
                    byte numBytes = dataIn[2]; // numBytes can only be a byte according to requestFrom API prototype
                    
                    byte* val;
                    val = dataIn + 3;
                    for(byte i = 0; i < numBytes; ++i){
                        //debugPrint(MSG_I2C_WRITE_VALUES, val[i]);
                    }
                    
                    if(bus == 0){
                        WireTrace::beginTransmission(address);
                        WireTrace::write(val, numBytes);
                        WireTrace::endTransmission(true);
                    }
                    else{ // For now, only bus 0 and 1 are supported
                        #ifdef ARDUINO_ARCH_SAM
                        Wire1Trace::beginTransmission(address);
                        Wire1Trace::write(val, numBytes);
                        Wire1Trace::endTransmission(true);
                        #endif
                    }
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case READ_REGISTER:{ 
                    //debugPrint(MSG_I2C_READ_REGISTER_PARAMS, command[1], command[2], command[3], command[4]);
                    byte bus      = dataIn[0];
                    byte address  = dataIn[1];
                    byte reg      = dataIn[2];
                    byte numBytes = dataIn[3];
                    byte dataRead;

                    if(bus == 0){
                        WireTrace::beginTransmission(address);
                        WireTrace::write(reg);  
                        WireTrace::endTransmission(false); 
                        if(WireTrace::requestFrom(address, (uint8_t)numBytes) != numBytes){
                            I2CBuffer[0] = 0xFF;
                        }
                        else{
                            I2CBuffer[0] = 0x00;
                            for(byte i = 1; i < numBytes+1; ++i){
                                I2CBuffer[i] = WireTrace::read();
                                //debugPrint(MSG_I2C_READ_VALUES, val[i]);
                            }
                        }
                    }
                    else{
                        #ifdef ARDUINO_ARCH_SAM
                        Wire1Trace::beginTransmission(address);
                        Wire1Trace::write(reg);  
                        Wire1Trace::endTransmission(false); 
                        if(Wire1Trace::requestFrom(address, (uint8_t)numBytes) != numBytes){
                            I2CBuffer[0] = 0xFF;
                        }
                        else{
                            I2CBuffer[0] = 0x00;
                            for(byte i = 1; i < numBytes+1; ++i){
                                I2CBuffer[i] = Wire1Trace::read();
                            }
                        }
                        #endif
                    }
                    
                    sendResponseMsg(cmdID, I2CBuffer, numBytes+1);
                    break;
                }
                case WRITE_REGISTER:{ 
                    //debugPrint(MSG_I2C_WRITE_REGISTER_PARAMS, command[1], command[2], command[3], command[4]);
                    byte bus      = dataIn[0];
                    byte address  = dataIn[1];
                    byte reg      = dataIn[2];
                    byte numBytes = dataIn[3];
                    
                    byte* val;
                    val = dataIn + 4;
                    for(byte i = 0; i < numBytes; ++i){
                        //debugPrint(MSG_I2C_WRITE_VALUES, val[i]);
                    }
                    
                    if(bus == 0){
                        WireTrace::beginTransmission(address);
                        WireTrace::write(reg);
                        WireTrace::write(val, numBytes);
                        WireTrace::endTransmission(true);
                    }
                    else{ // For now, only bus 0 and 1 are supported
                        #ifdef ARDUINO_ARCH_SAM
                        Wire1Trace::beginTransmission(address);
                        Wire1Trace::write(reg);
                        Wire1Trace::write(val, numBytes);
                        Wire1Trace::endTransmission(true);
                        #endif
                    }
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                default:
                    //debugPrint(MSG_I2C_UNRECOGNIZED_COMMAND, cmdID);
					break;
            }
		}
};

#endif
