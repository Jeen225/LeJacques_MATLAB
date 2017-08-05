/**
 * @file ServoBase.h
 *
 * Class definition for ServoBase class that wraps APIs of Servo library
 *
 * @copyright Copyright 2014-2016 The MathWorks, Inc.
 *
 */
#ifndef ServoBase_h
#define ServoBase_h
        
#include "Servo.h"
#include "LibraryBase.h"

// const char MSG_SERVO_ENTER_COMMAND_HANDLER[] 	PROGMEM = "ServoBase::commandHandler: cmdID %d, servoID %d\n";
// const char MSG_SERVO_UNRECOGNIZED_COMMAND[] 		PROGMEM = "ServoBase::commandHandler:unrecognized command ID %d\n";

// Arduino trace commands
const char MSG_SERVO_NEW[]                      PROGMEM = "Arduino::servoArray[%d] = new Servo; --> 0x%04X\n";
// const char MSG_SERVO_DELETE[]     	        PROGMEM = "Arduino::delete servoArray[%d]\nArduino::servoArray[%d] = NULL;\n";
const char MSG_SERVO_ATTACH[] 			        PROGMEM = "Arduino::servoArray[%d]->attach(%d, %d, %d)\n";
const char MSG_SERVO_DETACH[]			        PROGMEM = "Arduino::servoArray[%d]->detach()\n";
const char MSG_SERVO_READ[]			            PROGMEM = "Arduino::servoArray[%d]->read(); --> %d\n";
const char MSG_SERVO_WRITE[]			        PROGMEM = "Arduino::servoArray[%d]->write(%d);\n";

#define ATTACH_SERVO      0x00
#define CLEAR_SERVO       0x01
#define READ_POSITION     0x02
#define WRITE_POSITION    0x03
        
#define MAX_SERVOS_MW TOTAL_PINS - TOTAL_ANALOG_PINS
Servo *servoArray[MAX_SERVOS_MW];

class ServoTrace {
public:
    static void _new(byte servoID) {
        if (NULL == servoArray[servoID]) {
            servoArray[servoID] = new Servo;
            debugPrint(MSG_SERVO_NEW, servoID, servoArray[servoID]);
        }
    }

    static void _delete(byte servoID) {
//  Since Servo library does not actually free up the memory by using
//  delete, any memory that has been allocated before will not be cleaned 
//  up in our code. The same memory address will be used for any servo
//  object created on the same pin
//
//         if (NULL != servoArray[servoID]) {
//             delete servoArray[servoID];
//             servoArray[servoID] = NULL;
//             debugPrint(MSG_SERVO_DELETE, servoID, servoID);
//         }
    }

    static void attach(byte servoID, byte pin, int min, int max) {
        servoArray[servoID]->attach(pin, min, max);
        debugPrint(MSG_SERVO_ATTACH, servoID, pin, min, max);
    }

    static void detach(byte servoID) {
        if (NULL != servoArray[servoID]) {
            servoArray[servoID]->detach();
            debugPrint(MSG_SERVO_DETACH, servoID);
        }
    }

    static byte read(byte servoID) {
        byte angle = servoArray[servoID]->read();
        debugPrint(MSG_SERVO_READ, servoID, angle);
        return angle;
    }

    static void write(byte servoID, byte angle) {
        servoArray[servoID]->write(angle);
        debugPrint(MSG_SERVO_WRITE, servoID, angle);
    }
};

class ServoBase : public LibraryBase
{
	public:
		ServoBase(MWArduinoClass& a)
		{
            libName = "Servo";
 			a.registerLibrary(this);
		}
		
	// Implementation of LibraryBase
	//
	public:
		void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
		{
            //debugPrint(MSG_SERVO_ENTER_COMMAND_HANDLER, cmdID, dataIn[0]);
            switch (cmdID){
                case ATTACH_SERVO:{ 
                    byte servoID = dataIn[0];
                    byte pin = dataIn[1];
                    int min = dataIn[2]+(dataIn[3]<<8);
                    int max = dataIn[4]+(dataIn[5]<<8);
                    

                    ServoTrace::_new(servoID);
                    ServoTrace::attach(servoID, pin, min, max);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case CLEAR_SERVO:{ 
                    byte servoID = dataIn[0];
                    ServoTrace::detach(servoID);
                    //ServoTrace::_delete(servoID);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                case READ_POSITION:{ 
                    byte servoID = dataIn[0];
                    byte angle = ServoTrace::read(servoID);
                    
                    byte val[1] = {angle};
                    sendResponseMsg(cmdID, val, 1);
                    break;
                }
                case WRITE_POSITION:{ 
                    byte servoID = dataIn[0];
                    byte angle = dataIn[1];
                    
                    ServoTrace::write(servoID, angle);
                    
                    sendResponseMsg(cmdID, 0, 0);
                    break;
                }
                default:
                    //debugPrint(MSG_SERVO_UNRECOGNIZED_COMMAND, cmdID);
					break;
            }
		}
};

#endif