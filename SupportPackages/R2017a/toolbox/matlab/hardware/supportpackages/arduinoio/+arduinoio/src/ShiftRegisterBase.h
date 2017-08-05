/**
 * @file ShiftRegisterBase.h
 *
 * Class definition for ShiftRegisterBase class 
 *
 * @copyright Copyright 2016 The MathWorks, Inc.
 *
 */
#ifndef ShiftRegisterBase_h
#define ShiftRegisterBase_h

#include "LibraryBase.h"

const char MSG_MWARDUINOCLASS_SHIFT_IN[]            PROGMEM = "Arduino::shiftIn(%d, %d, %d) --> %d;\n";
const char MSG_MWARDUINOCLASS_SHIFT_OUT[]           PROGMEM = "Arduino::shiftOut(%d, %d, %d, %d);\n";
const char MSG_SHIFTREG_WRITE_74HC595[]             PROGMEM = "ShiftRegister::write74HC595(%d, %d, %d, %d, %d)\n";
const char MSG_SHIFTREG_WRITE_74HC164[]             PROGMEM = "ShiftRegister::write74HC164(%d, %d, %d, %d)\n";
const char MSG_SHIFTREG_READ_74HC165[]              PROGMEM = "ShiftRegister::read74HC165(%d, %d, %d, %d, %d)\n";
const char MSG_SHIFTREG_RESET_74HC595[]             PROGMEM = "ShiftRegister::reset74HC595(%d, %d)\n";
const char MSG_SHIFTREG_RESET_74HC164[]             PROGMEM = "ShiftRegister::reset74HC164(%d)\n";

#define SHIFT_REGISTER_WRITE     0x00
#define SHIFT_REGISTER_READ      0x01
#define SHIFT_REGISTER_RESET     0x02

#define MW_74HC165 1
#define MW_74HC595 2
#define MW_74HC164 3

class ShiftRegisterTrace {
public:
    static void read74HC165(byte dataPin, byte clockPin, byte loadPin, byte cePin, byte numBytes, byte* value){
        //debugPrint(MSG_SHIFTREG_READ_74HC165, dataPin, clockPin, loadPin, cePin, numBytes);
        
        digitalWrite(clockPin, HIGH); // PL HIGH and CP HIGH makes DS output D7 first
        digitalWrite(loadPin, LOW);
        delayMicroseconds(5); // Requires a delay here according to the datasheet timing diagram
        digitalWrite(loadPin, HIGH);
        delayMicroseconds(5);
        
        digitalWrite(cePin, LOW); // Enable the clock
        for(size_t iLoop = 0; iLoop < numBytes; ++iLoop){
            value[iLoop] = ::shiftIn(dataPin, clockPin, MSBFIRST);
            debugPrint(MSG_MWARDUINOCLASS_SHIFT_IN, dataPin, clockPin, MSBFIRST, value[iLoop]);
        }
        digitalWrite(cePin, HIGH); // Disable the clock
    }

    static void write74HC595(byte dataPin, byte clockPin, byte latchPin, byte numBytes, byte* value){
        //debugPrint(MSG_SHIFTREG_WRITE_74HC595, dataPin, clockPin, latchPin, numBytes, value[numBytes-1]);

        debugPrint(MSG_MWARDUINOCLASS_DIGITAL_WRITE, latchPin, "LOW");
        ::digitalWrite(latchPin,LOW);
        
        // MSBFIRST
        for(int iLoop = numBytes-1; iLoop >= 0; iLoop--){
            debugPrint(MSG_MWARDUINOCLASS_SHIFT_OUT, dataPin, clockPin, MSBFIRST, value[iLoop]);
            ::shiftOut(dataPin, clockPin, MSBFIRST, value[iLoop]);
        }
        
        debugPrint(MSG_MWARDUINOCLASS_DIGITAL_WRITE, latchPin, "HIGH");
        ::digitalWrite(latchPin,HIGH);
    }

    static void write74HC164(byte dataPin, byte clockPin, byte numBytes, byte* value){    
        //debugPrint(MSG_SHIFTREG_WRITE_74HC164, dataPin, clockPin, numBytes, value[0]);

        for(size_t iLoop = 0; iLoop < numBytes; ++iLoop){
            debugPrint(MSG_MWARDUINOCLASS_SHIFT_OUT, dataPin, clockPin, MSBFIRST, value[iLoop]);
            ::shiftOut(dataPin, clockPin, MSBFIRST, value[iLoop]);
        }
    }

    static void reset74HC595(byte latchPin, byte resetPin){
        //debugPrint(MSG_SHIFTREG_RESET_74HC595, latchPin, resetPin);

        // shift register output reset when MR/Reset low with rising edge STCP/Latch.
        debugPrint(MSG_MWARDUINOCLASS_DIGITAL_WRITE, resetPin, "LOW");
        ::digitalWrite(resetPin,LOW);
        debugPrint(MSG_MWARDUINOCLASS_DIGITAL_WRITE, latchPin, "LOW");
        ::digitalWrite(latchPin,LOW);
        debugPrint(MSG_MWARDUINOCLASS_DIGITAL_WRITE, latchPin, "HIGH");
        ::digitalWrite(latchPin,HIGH);
    }

    static void reset74HC164(byte resetPin){
        //debugPrint(MSG_SHIFTREG_RESET_74HC164, resetPin);

        // according to datasheet, LOW level on MR/Reset clears the registers asynchronously, forcing all outputs LOW
        debugPrint(MSG_MWARDUINOCLASS_DIGITAL_WRITE, resetPin, "LOW");
        ::digitalWrite(resetPin,LOW);
    }
};

class ShiftRegisterBase : public LibraryBase
{
	public:
		ShiftRegisterBase(MWArduinoClass& a)
		{
            libName = "ShiftRegister";
 			a.registerLibrary(this);
		}
		
	// Implementation of LibraryBase //
	public:
		void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
		{
            switch (cmdID){
                case SHIFT_REGISTER_WRITE:{
                    byte model     = dataIn[0];
                    byte dataPin   = dataIn[1];
                    byte clockPin  = dataIn[2];
                    switch(model){
                        case MW_74HC595: {
                            byte latchPin = dataIn[3];
                            byte isReset  = dataIn[4];
                            byte numBytes;
                            byte* value;
                            if(isReset){
                                byte resetPin = dataIn[5];
                                digitalWrite(resetPin,HIGH);
                                numBytes  = dataIn[6];
                                value    = dataIn+7;
                            }
                            else{
                                numBytes  = dataIn[5];
                                value    = dataIn+6;
                            }
                            ShiftRegisterTrace::write74HC595(dataPin, clockPin, latchPin, numBytes, value);
                            break;
                        }
                        case MW_74HC164: {
                            byte isReset  = dataIn[3];
                            byte numBytes;
                            byte* value;
                            if(isReset){
                                byte resetPin = dataIn[4];
                                digitalWrite(resetPin,HIGH);
                                numBytes  = dataIn[5];
                                value    = dataIn+6;
                            }
                            else{
                                numBytes  = dataIn[4];
                                value    = dataIn+5;
                            }
                            ShiftRegisterTrace::write74HC164(dataPin, clockPin, numBytes, value);
                            break;
                        }
                        default:{
                            // return -1 if wrong model received
                            byte error = -1;
                            sendResponseMsg(cmdID, &error, 1);
                            return;
                        }
                    }
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case SHIFT_REGISTER_READ:{
                    byte model     = dataIn[0];
                    byte dataPin   = dataIn[1];
                    byte clockPin  = dataIn[2];
                    byte numBytes;
                    byte* value;

                    switch(model){
                        case MW_74HC165: {
                            byte loadPin = dataIn[3];
                            byte cePin   = dataIn[4];
                            numBytes  = dataIn[5];
                            value = new byte [numBytes];
                            ShiftRegisterTrace::read74HC165(dataPin, clockPin, loadPin, cePin, numBytes, value);
                            break;
                        }
                        default:{
                            // return -1 if wrong model received
                            byte error = -1;
                            sendResponseMsg(cmdID, &error, 1);
                            return;
                        }
                    }
                    
                    sendResponseMsg(cmdID, value, numBytes);
                    delete [] value;
                    value = NULL;
                    break;
                }
                case SHIFT_REGISTER_RESET:{
                    byte model     = dataIn[0];
                    byte dataPin   = dataIn[1];
                    byte clockPin  = dataIn[2];
                    switch(model){
                        case MW_74HC595: {
                            byte latchPin = dataIn[3];
                            //byte isReset  = dataIn[4];
                            byte resetPin = dataIn[5];
                            ShiftRegisterTrace::reset74HC595(latchPin, resetPin);
                            break;
                        }
                        case MW_74HC164: {
                            //byte isReset  = dataIn[3];
                            byte resetPin = dataIn[4];
                            ShiftRegisterTrace::reset74HC164(resetPin);
                            break;
                        }
                        default:{
                            // return -1 if wrong model received
                            byte error = -1;
                            sendResponseMsg(cmdID, &error, 1);
                            return;
                        }
                    }

                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                default:
					break;
            }
		}
};
#endif