/**
 * @file RotaryEncoderBase.h
 *
 * Class definition for RotaryEncoderBase class 
 *
 * @copyright Copyright 2016 The MathWorks, Inc.
 *
 */
#ifndef RotaryEncoderBase_h
#define RotaryEncoderBase_h

#include "limits.h"
#include "LibraryBase.h"

#define ATTACH_ENCODER      0x01
#define DETACH_ENCODER      0x02
#define CHANGE_DELAY        0x03
#define READ_ENCODER_COUNT  0x04
#define READ_ENCODER_SPEED  0x05
#define WRITE_ENCODER_COUNT 0x06

#define MAX_ENCODER 2
#define SpeedMeasureInterval 20 
        
const char MSG_ATTACH_ENCODER[]           PROGMEM = "RotaryEncoder::attachInterrupt(%d,isrPin%s%d, CHANGE);\n";
const char MSG_DETACH_ENCODER[]           PROGMEM = "RotaryEncoder::detachInterrupt(%d);\nRotaryEncoder::detachInterrupt(%d);\n";
const char MSG_CHANGE_DELAY[]             PROGMEM = "RotaryEncoder::myEncoder[%d].delay = %d\n";
const char MSG_READ_COUNT[]               PROGMEM = "RotaryEncoder::Overflow --> %d\nmyEncoder[%d].count --> %ld;\n";
const char MSG_READ_SPEED[]               PROGMEM = "RotaryEncoder::delay(%d);ID %d, overflowDiff --> %d, countDiff --> %d;\n";
const char MSG_WRITE_COUNT[]              PROGMEM = "RotaryEncoder::myEncoder[%d].count = %ld;\n";

struct encoder_t{
    #if defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_SAM)
    volatile uint32_t* registerA;
    volatile uint32_t* registerB;
    uint32_t maskA;
    uint32_t maskB;
    #else
    volatile uint8_t* registerA;
    volatile uint8_t* registerB;
    uint8_t maskA;
    uint8_t maskB;
    #endif
    volatile int32_t count;
    uint8_t lastValues;
    volatile int8_t overflow = 0;
}myEncoder[MAX_ENCODER];

// Fast digital read without unnecessary checking
#define directDigitalRead(reg, mask) (((*reg) & mask)?1:0)

void updateCount(encoder_t& ec){
    int valA = directDigitalRead(ec.registerA, ec.maskA);
    int valB = directDigitalRead(ec.registerB, ec.maskB);

    uint8_t newValues = (valA << 1)|valB;
    uint8_t temp = (ec.lastValues << 2)|newValues;

    switch(temp){
      case 0b0000:
      case 0b1010:
      case 0b0101:
      case 0b1111:
        // Eliminate cases where no changes on both A and B.
        // The following four sequences are eliminated:
        // oldA   oldB  newA  newB
        //  0      0     0     0
        //  1      0     1     0
        //  0      1     0     1
        //  1      1     1     1
        // No action
      case 0b0011:
      case 0b0110:
      case 0b1001:
      case 0b1100:
        // Eliminate cases where changes on both A and B.
        // The following four sequences are eliminated:
        // oldA   oldB  newA  newB
        //  0      0     1     1    
        //  0      1     1     0    
        //  1      0     0     1    
        //  1      1     0     0    
        // No action
        break;
      case 0b1011:
      case 0b0100:
        // If change happens on B, increment if newA == newB, e.g
        // oldA   oldB  newA  newB
        //  1      0     1     1    
        //  0      1     0     0    
      case 0b0010:
      case 0b1101:
        // If change happens on A, increment if newA != newB, e.g
        // oldA   oldB  newA  newB
        //  0      0     1     0    
        //  1      1     0     1    
      {
        if(ec.count < LONG_MAX){
            ec.count++;
        }
        else{
            ec.count = 0;
            ec.overflow++;
        }
        break;
      }
      case 0b0001:
      case 0b1110:
        // If change happens on B, decrement if newA != newB, e.g
        // oldA   oldB  newA  newB
        //  0      0     0     1    
        //  1      1     1     0    
      case 0b0111:
      case 0b1000:
        // If change happens on A, decrement if newA == newB, e.g
        // oldA   oldB  newA  newB
        //  0      1     1     1    
        //  1      0     0     0   
      {
        if(ec.count > LONG_MIN){
            ec.count--;
        }
        else{
            ec.count = 0;
            ec.overflow--;
        }
        break;
      }
      default:{}
    }
    
    // Update lastValues to store new pin values
    ec.lastValues = newValues;
}

// Encoder 0 pin A interrupt service routine 
void isrChannelA0(void)
{
    updateCount(myEncoder[0]);
} 
// Encoder 0 pin B interrupt service routine
void isrChannelB0(void)
{
    updateCount(myEncoder[0]);
} 
// Encoder 1 pin A interrupt service routine
void isrChannelA1(void)
{
    updateCount(myEncoder[1]); 
} 
// Encoder 1 pin B interrupt service routine
void isrChannelB1(void)
{
    updateCount(myEncoder[1]);
} 

class RotaryEncoderBase : public LibraryBase
{
	public:
		RotaryEncoderBase(MWArduinoClass& a)
		{
            libName = "RotaryEncoder";
 			a.registerLibrary(this);
		}
		
	public:
		void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
		{
            switch (cmdID){
                case ATTACH_ENCODER:{ 
                    byte ID = dataIn[0];
                    byte pinA = dataIn[1];
                    byte pinB = dataIn[2];
                    
                    /* Turn on pullup resistors */
                    ArduinoTrace::pinMode(pinA, INPUT);
                    ArduinoTrace::pinMode(pinB, INPUT);
                    ArduinoTrace::digitalWrite(pinA, HIGH);
                    ArduinoTrace::digitalWrite(pinB, HIGH);
                    
                    /* Initialize encoder count */
                    myEncoder[ID].count = 0;
                    myEncoder[ID].overflow = 0;
                    
                    /* Derive register and bit mask corresponds to the pin for fast digitalRead */
                    myEncoder[ID].registerA = portInputRegister(digitalPinToPort(pinA));
                    myEncoder[ID].registerB = portInputRegister(digitalPinToPort(pinB));
                    myEncoder[ID].maskA = digitalPinToBitMask(pinA);
                    myEncoder[ID].maskB = digitalPinToBitMask(pinB);
                    myEncoder[ID].lastValues = (digitalRead(pinA) << 1)|(digitalRead(pinB));
                    switch(ID){
                        case 0:{
                            #if defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_SAM)
                            attachInterrupt(pinA, isrChannelA0, CHANGE);
                            attachInterrupt(pinB, isrChannelB0, CHANGE);
                            #else
                            attachInterrupt(digitalPinToInterrupt(pinA), isrChannelA0, CHANGE);
                            attachInterrupt(digitalPinToInterrupt(pinB), isrChannelB0, CHANGE);
                            #endif
                            break;
                        }
                        case 1:{
                            #if defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_SAM)
                            attachInterrupt(pinA, isrChannelA1, CHANGE);
                            attachInterrupt(pinB, isrChannelB1, CHANGE);
                            #else
                            attachInterrupt(digitalPinToInterrupt(pinA), isrChannelA1, CHANGE);
                            attachInterrupt(digitalPinToInterrupt(pinB), isrChannelB1, CHANGE);
                            #endif
                            break;
                        }
                        default:{}
                    }
                    
                    debugPrint(MSG_ATTACH_ENCODER, pinA, "A\0", ID);
                    debugPrint(MSG_ATTACH_ENCODER, pinB, "B\0", ID);
        
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case DETACH_ENCODER:{
                    noInterrupts();
                    byte ID = dataIn[0];
                    byte pinA = dataIn[1];
                    byte pinB = dataIn[2];
                    #if defined(ARDUINO_ARCH_SAMD) || defined(ARDUINO_ARCH_SAM)
                    detachInterrupt(pinA);
                    detachInterrupt(pinB);
                    #else
                    detachInterrupt(digitalPinToInterrupt(pinA));
                    detachInterrupt(digitalPinToInterrupt(pinB));
                    #endif
                    
                    // Enable interrupts before debugPrint or sendResponseMsg
                    // as serial communication relys on interrupts
                    interrupts();
                    debugPrint(MSG_DETACH_ENCODER, pinA, pinB);
                    
                    sendResponseMsg(cmdID, 0, 0);

                    break;
                }
                case READ_ENCODER_COUNT:{ 
                    noInterrupts();
                    unsigned long time = millis();
                    byte ID = dataIn[0];
                    int32_t count = myEncoder[ID].count;
                    byte flag = dataIn[1];
                    if(flag)
                        myEncoder[ID].count = 0;
                    byte result [9];
                    result[0] = (count & 0x000000ff);
                    result[1] = (count & 0x0000ff00) >> 8;
                    result[2] = (count & 0x00ff0000) >> 16;
                    result[3] = (count & 0xff000000) >> 24;
                    result[4] = (time & 0x000000ff);
                    result[5] = (time & 0x0000ff00) >> 8;
                    result[6] = (time & 0x00ff0000) >> 16;
                    result[7] = (time & 0xff000000) >> 24;
                    result[8] = myEncoder[ID].overflow;
                    
                    interrupts();
                    debugPrint(MSG_READ_COUNT, result[8], ID, count);
                    
                    sendResponseMsg(cmdID, result, 9);

                    break;
                }
                case READ_ENCODER_SPEED:{
                    noInterrupts();
                    byte numEncoders = dataIn[1];
                    byte *result = new byte [3*numEncoders];
                    for(size_t i = 0; i < numEncoders; ++i){
                        byte ID = dataIn[i+2];
                        int32_t oldCount = myEncoder[ID].count;
                        int8_t oldOverflow = myEncoder[ID].overflow;
                        interrupts();
                        delay(SpeedMeasureInterval);
                        int32_t newCount = myEncoder[ID].count;
                        int8_t overflowDiff = myEncoder[ID].overflow-oldOverflow;
                        int16_t countDiff = newCount - oldCount;
                        debugPrint(MSG_READ_SPEED, SpeedMeasureInterval, ID, overflowDiff, countDiff);
                        noInterrupts();
                        
                        result[i*3+0] = overflowDiff;
                        result[i*3+1] = (countDiff & 0x00ff);
                        result[i*3+2] = (countDiff & 0xff00) >> 8;
                    }
                    
                    interrupts();
                    sendResponseMsg(cmdID, result, 3*numEncoders);
                    delete [] result;
                    break;
                }
                case WRITE_ENCODER_COUNT:{
                    noInterrupts();
                    byte ID = dataIn[0];
                    int32_t count = ((int32_t)(dataIn[1]))|
                                    (((int32_t)dataIn[2])<<8)|
                                    (((int32_t)dataIn[3])<<16)|
                                    (((int32_t)dataIn[4])<<24);
                    myEncoder[ID].count = count;
                    myEncoder[ID].overflow = 0;
                    
                    interrupts();
                    debugPrint(MSG_WRITE_COUNT, ID, count);
                    sendResponseMsg(cmdID, 0, 0);

                    break;
                }
                default:{}
            }
        }
};

#endif