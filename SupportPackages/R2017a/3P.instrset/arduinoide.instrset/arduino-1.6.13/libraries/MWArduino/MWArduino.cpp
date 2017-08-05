/**
 * @file MWArduino.cpp
 *
 * Class definition for MWArduino class - MathWorks Arduino library.
 *
 * @copyright Copyright 2014-2016 The MathWorks, Inc.
 *
 */

#include "MWArduino.h"
#include "MacroInclude.h"
#include "LibraryBase.h"

#define STR_EXPAND(tok) #tok
#define STR(tok) STR_EXPAND(tok)

#define GET_SERVER_INFO          0x01
#define RESET_PINS_STATE         0x02
#define GET_AVAILABLE_RAM        0x03
#define WRITE_DIGITAL_PIN        0x10
#define READ_DIGITAL_PIN         0x11
#define CONFIGURE_PIN            0x12
#define WRITE_PWM_VOLTAGE        0x20
#define WRITE_PWM_DUTY_CYCLE     0x21
#define PLAY_TONE                0x22
#define READ_VOLTAGE             0x30

/* Store static debug message strings in flash to avoid running out of SRAM memory */
//const char MSG_BASE_CMD[]                 PROGMEM = "\nArduino::commandHandler: isLib %d, payload_size %d, cmdID %d, params %d, %d\n";
//const char MSG_ADDON_CMD[]                PROGMEM = "\nLibrary::commandHandler: isLib %d, payload_size %d, libraryID %d, cmdID %d, params %d, %d\n";
const char MSG_UNRECOGNIZED_CMD[]         PROGMEM = "Unrecognized MLIdentifier: %d\n";
const char MSG_MW_GET_SERVER_INFO[]       PROGMEM = "MWArduino::getServerInfo();\n";
const char MSG_MW_GET_AVAILABLE_RAM[]     PROGMEM = "MWArduino::getAvailableRAM() --> %d;\n";

void dispatcher(byte isLib, byte* inputs, unsigned int payloadSize);
void debugPrint(const char *fmt, ... );
void sendResponseMsg(byte cmdID, byte* dataIn, unsigned int payloadSize);

// MWArduino class
//
MWArduinoClass::MWArduinoClass()
{
    for (byte iLoop = 0; iLoop < MAX_NUM_LIBRARIES; ++iLoop) {
        libraryArray[iLoop] = NULL;
    }
  
    isSetup = false;
}

void MWArduinoClass::pinModeMW(byte pin, byte value) {
    ArduinoTrace::pinMode(pin, value);
}

void MWArduinoClass::digitalWriteMW(byte pin, byte value)
{
	ArduinoTrace::digitalWrite(pin, value);
}

byte MWArduinoClass::digitalReadMW(byte pin)
{
    return ArduinoTrace::digitalRead(pin);
}

void MWArduinoClass::analogWriteMW(byte pin, byte value)
{
	ArduinoTrace::analogWrite(pin, value);
}

int MWArduinoClass::analogReadMW(byte pin)
{
	return ArduinoTrace::analogRead(pin);
}

void MWArduinoClass::toneMW(byte pin, unsigned int frequency, unsigned long duration)
{
    #ifdef ARDUINO_ARCH_AVR
	if (frequency == 0 || duration == 0) {
		ArduinoTrace::noTone(pin);
	}
	else {
		ArduinoTrace::tone(pin, frequency, duration);
	}
    #endif
}

void MWArduinoClass::begin(byte type) 
{
    MWProtocol = MWProtocolBase::getMWProtocol(type);
	MWProtocol->attach(dispatcher);
    MWProtocol->begin();
    setupLibs();
}

void MWArduinoClass::update()
{
    MWProtocol->update();
    loopLibs();
}

// Setup
void MWArduinoClass::setupLibs() {
    // Each addon should onyl get one call to setup when an Arduino board is reset.
    // Avoid multiple calls to setup which could result in duplicate resource allocations.
    //
    if (!isSetup) {
        for (byte iLoop = 0; iLoop < MAX_NUM_LIBRARIES; ++iLoop) {
            if (MWArduino.libraryArray[iLoop] != NULL){
                MWArduino.libraryArray[iLoop]->setup();
            }
        }

        isSetup = true;
    }
}

// Loop
void MWArduinoClass::loopLibs() { 
    // Once setup, loop allos background addons to provide their own background 
    // operations to run within the Arduino server.
    //
    if (isSetup) {
        for (byte iLoop = 0; iLoop < MAX_NUM_LIBRARIES; ++iLoop) {
            if (MWArduino.libraryArray[iLoop] != NULL){
                MWArduino.libraryArray[iLoop]->loop();
            }
        }
    }
}

void MWArduinoClass::registerLibrary(LibraryBase* lib)
{
	for (byte iLoop = 0; iLoop < MAX_NUM_LIBRARIES; ++iLoop) {
		if (libraryArray[iLoop]==NULL) {
			libraryArray[iLoop] = lib;
			return;
		}
	}
}

byte MWArduinoClass::isTraceOn(){
    return MWProtocol->m_isTraceOn;
}

void MWArduinoClass::sendResponseMsg(byte cmdID, byte* dataIn, unsigned int payloadSize){
    MWProtocol->sendResponseMsg(cmdID, dataIn, payloadSize);
}

void MWArduinoClass::debugPrint(va_list args, char *fmt_char ){
    MWProtocol->debugPrint(args, fmt_char);
}


// Wrap MWProtocol.debugPrint to debugPrint
void debugPrint(const char *fmt, ... ){
    char formatted_string[100];
    char c;
    uint8_t i = 0;
    while((c = pgm_read_byte(fmt++)) && i < 99){
        formatted_string[i] = c;
        i++;
    }
    formatted_string[i] = 0; // add 0 in the end to indicate end of string
  
    va_list args;
    va_start (args, fmt);
    MWArduino.debugPrint(args, formatted_string);
}
// Wrap MWProtocol.sendResponseMsg to sendResponseMsg
void sendResponseMsg(byte cmdID, byte* dataIn, unsigned int payloadSize){
    MWArduino.sendResponseMsg(cmdID, dataIn, payloadSize);
}

// Utility functions to query available memory space
int getfreeRAM(){
    #if MW_BOARD == Due || MW_BOARD == MKR1000
    return 0; // TODO - Find a function that accurately estimate available dynamic memory
    #else
    extern int __heap_start, *__brkval; 
    int v; 
    return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval); 
    #endif
}

// Callback functions
//
void dispatcher(byte isLib, byte* inputs, unsigned int payloadSize){  
    if(isLib == 0x00){ // basic arduino commands
        //debugPrint(MSG_BASE_CMD, isLib, payloadSize, inputs[0], inputs[1], inputs[2]);     
        byte commandID = inputs[0];
        switch(commandID){
            case GET_SERVER_INFO:{ 
                // keep in here to debug initialization error. 
                // LED 13 should light up briefly during creation of arduino object
                // If not, getServerInfo command is sent before the board's serial 
                // port is properly initialized.
                digitalWrite(13, HIGH);
                debugPrint(MSG_MW_GET_SERVER_INFO);
                
                byte val[256];
                
                // Version
                val[0] = MAJOR_VERSION;
                val[1] = MINOR_VERSION;
                val[2] = 0x3B;
                
                // Board 
                char const *board = STR(MW_BOARD);
                byte len = strlen(board);
                for(byte iLoop = 0; iLoop < len; iLoop++){
                    val[iLoop+3] = board[iLoop];
                }
                val[len+3] = 0x3B; // ';'
                
                // TraceOn
                val[len+4] = MWArduino.isTraceOn();
                val[len+5] = 0x3B;
                
                // Libraries
                int count = len+6;
                for (byte iLoop = 0; iLoop < MAX_NUM_LIBRARIES; ++iLoop) {
                    if (MWArduino.libraryArray[iLoop] != NULL){
                        val[count++] = iLoop;
                        const char * libName = MWArduino.libraryArray[iLoop]->getLibraryName();
                        byte len = strlen(libName);
                        for(byte jLoop = 0; jLoop < len; ++jLoop){
                            val[count++] = libName[jLoop];
                        }
                        if (MWArduino.libraryArray[iLoop+1] != NULL){
                            val[count++] = 0x3B; // send ';' to separate libraries
                        }
                    }
                    else
                        break;
                }
                val[count] = 0;

                // Upon creation of an arduino object, getServerInfo request will be sent first
                // Hence, to make sure setup methods are called regardless of whether the board
                // auto-resets or not or the board gets reprogrammed or not, reset global variable
                // isSetup here 
                MWArduino.isSetup = false;

                sendResponseMsg(commandID, val, count);
                break;
            }
            case RESET_PINS_STATE:{ 
                // Pins start from D2 to last of analog pins
                for(byte iLoop = 2; iLoop < TOTAL_PINS; ++iLoop){
                    if(IS_PIN_DIGITAL(iLoop)){
                        MWArduino.pinModeMW(iLoop, OUTPUT);
                        MWArduino.digitalWriteMW(iLoop, 0);
                        MWArduino.pinModeMW(iLoop, INPUT);
                    }
                }

                sendResponseMsg(commandID, 0, 0);
                break;
            }
            case GET_AVAILABLE_RAM:{
                int availableRAM = getfreeRAM();
                byte val[2];
                val[1] = availableRAM & 0xff; // lsb
                val[0] = availableRAM >> 8;   // msb
                debugPrint(MSG_MW_GET_AVAILABLE_RAM, availableRAM);
        
                sendResponseMsg(commandID, val, 2);
                break;
            }
            case WRITE_DIGITAL_PIN:{
                byte subsystem = inputs[1];
                byte pin = inputs[2];
                byte value = inputs[3];
                
                if(subsystem){ // analog pin
                    pin = A0 + pin;
                }
                MWArduino.digitalWriteMW(pin, value);
                
                sendResponseMsg(commandID, 0, 0);
                break;
            }
            case READ_DIGITAL_PIN:{ 
                byte subsystem = inputs[1];
                byte pin = inputs[2];
                byte value;
                
                if(subsystem){ // analog pin
                    pin = A0 + pin;
                }
                value = MWArduino.digitalReadMW(pin);
                
                sendResponseMsg(commandID, &value, 1);
                break;
            }
            case CONFIGURE_PIN:{ 
                byte subsystem = inputs[1];
                byte pin = inputs[2];
                byte value = inputs[3];
                
                if(subsystem){ // analog pin
                    pin = A0 + pin;
                }
                MWArduino.pinModeMW(pin, value);
                
                sendResponseMsg(commandID, 0, 0);
                break;
            }
            case WRITE_PWM_VOLTAGE: 
            case WRITE_PWM_DUTY_CYCLE:{ 
                byte pin = inputs[1];
                int value = inputs[2]+(inputs[3]<<8);
                
                MWArduino.analogWriteMW(pin, value);
                
                sendResponseMsg(commandID, 0, 0);
                break;
            }
            case PLAY_TONE:{ 
                byte pin = inputs[1];
                unsigned int frequency = inputs[2]+(inputs[3]<<8);
                unsigned long duration = inputs[4]+(inputs[5]<<8);
                
                MWArduino.toneMW(pin, frequency, duration);
                
                sendResponseMsg(commandID, 0, 0);
                break;
            }
            case READ_VOLTAGE:{ 
                byte pin = inputs[1];
                int value;
                
                value = MWArduino.analogReadMW(pin);
                
                byte val[2];
                val[0] = (value >> 8) & 0x03;
                val[1] = value & 0xff;
                sendResponseMsg(commandID, val, 2);
                break;
            }
            default:
                break;
        }
    }
    else if(isLib == 0x01){
         // Addon library commands
         // command is actually libraryID, which is also the index
        //debugPrint(MSG_ADDON_CMD, isLib, payloadSize, inputs[0], inputs[1], inputs[2], inputs[3]);
        byte libraryID = inputs[0];
        if (MWArduino.libraryArray[libraryID] != NULL){
            byte commandID = inputs[1];
            // dataIn starts from the first byte after commandID, hence inputs+2
            // actual data length is 1 less due to libID
            MWArduino.libraryArray[libraryID]->commandHandler(commandID, inputs+2, payloadSize-1);
        }
    }
    else{
        debugPrint(MSG_UNRECOGNIZED_CMD, isLib);
    }
}

// Arduino debug trace
//
//
const char MSG_MWARDUINOCLASS_DIGITAL_WRITE[]       PROGMEM = "Arduino::digitalWrite(%d, %s);\n";
const char MSG_MWARDUINOCLASS_DIGITAL_READ[]        PROGMEM = "Arduino::digitalRead(%d); --> %s\n";
const char MSG_MWARDUINOCLASS_PIN_MODE[]            PROGMEM = "Arduino::pinMode(%d, %s);\n";
const char MSG_MWARDUINOCLASS_ANALOG_WRITE[]        PROGMEM = "Arduino::analogWrite(%d, %d);\n";
const char MSG_MWARDUINOCLASS_ANALOG_READ[]         PROGMEM = "Arduino::analogRead(%d) --> %d;\n";
const char MSG_MWARDUINOCLASS_PLAY_TONE[]           PROGMEM = "Arduino::playTone(%d, %d, %d);\n";
const char MSG_MWARDUINOCLASS_NO_TONE[]             PROGMEM = "Arduino::noTone(%d);\n";
const char MSG_MWARDUINOCLASS_DELAY[]               PROGMEM = "Arduino::delay(%d);\n";

void ArduinoTrace::pinMode(byte pin, byte value) {
	switch (value) {
	case INPUT:
		debugPrint(MSG_MWARDUINOCLASS_PIN_MODE, pin, "INPUT");
		break;
	case OUTPUT:
		debugPrint(MSG_MWARDUINOCLASS_PIN_MODE, pin, "OUTPUT");
		break;
	case INPUT_PULLUP:
		debugPrint(MSG_MWARDUINOCLASS_PIN_MODE, pin, "INPUT_PULLUP");
		break;
	default:
		char szBuffer[8];
		debugPrint(MSG_MWARDUINOCLASS_PIN_MODE, pin, itoa(value, szBuffer, 10));
		break;
	}
    ::pinMode(pin, value);
}

void ArduinoTrace::digitalWrite(byte pin, byte value) {
	switch (value) {
	case HIGH:
		debugPrint(MSG_MWARDUINOCLASS_DIGITAL_WRITE, pin, "HIGH");
		break;
	case LOW:
		debugPrint(MSG_MWARDUINOCLASS_DIGITAL_WRITE, pin, "LOW");
		break;
	default:
		char szBuffer[8];
		debugPrint(MSG_MWARDUINOCLASS_DIGITAL_WRITE, pin, itoa(value, szBuffer, 10));
		break;
	}
    ::digitalWrite(pin, value);
}

byte ArduinoTrace::digitalRead(byte pin) {
    byte value = ::digitalRead(pin);
	switch (value) {
	case HIGH:
		debugPrint(MSG_MWARDUINOCLASS_DIGITAL_READ, pin, "HIGH");
		break;
	case LOW:
		debugPrint(MSG_MWARDUINOCLASS_DIGITAL_READ, pin, "LOW");
		break;
	default:
		char szBuffer[8];
		debugPrint(MSG_MWARDUINOCLASS_DIGITAL_READ, pin, itoa(value, szBuffer, 10));
		break;
	}
    return value;
}

void ArduinoTrace::analogWrite(byte pin, byte value) {
    debugPrint(MSG_MWARDUINOCLASS_ANALOG_WRITE, pin, value);
	::analogWrite(pin, value);
}

int ArduinoTrace::analogRead(byte pin) {
    int value = ::analogRead(pin);
    debugPrint(MSG_MWARDUINOCLASS_ANALOG_READ, pin, value);
    return value;
}

void ArduinoTrace::tone(byte pin, unsigned int frequency, unsigned long duration) {
    #ifdef ARDUINO_ARCH_SAM
    #else
    debugPrint(MSG_MWARDUINOCLASS_PLAY_TONE, pin, frequency, duration);
	::tone(pin, frequency, duration);
    #endif
}

byte ArduinoTrace::noTone(byte pin) {
    #ifdef ARDUINO_ARCH_SAM
    #else
    debugPrint(MSG_MWARDUINOCLASS_NO_TONE, pin);
    ::noTone(pin);
    #endif
}

void ArduinoTrace::delay(unsigned int duration) {
    debugPrint(MSG_MWARDUINOCLASS_DELAY, duration);
    ::delay(duration);
}



//
// Create instance of MWArduino class and any included library class
//
#include "LibraryRegistration.h"
//
//
//
