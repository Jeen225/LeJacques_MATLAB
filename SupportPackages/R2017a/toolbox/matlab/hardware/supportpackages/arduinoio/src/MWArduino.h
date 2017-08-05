/**
 * @file MWArduino.h
 *
 * Class prototype for MWArduino class.
 *
 * @copyright Copyright 2014-2016 The MathWorks, Inc.
 *
 */

#ifndef MWArduino_h
#define MWArduino_h

// #include "Debug.h"
#include "MWProtocolBase.h"
class LibraryBase;

// Released on 2017.March
#define MAJOR_VERSION 17
#define MINOR_VERSION 3

#define MAX_NUM_LIBRARIES 16

// Arduino debug trace
class ArduinoTrace {
public:
    static void pinMode(byte pin, byte value);
    static void digitalWrite(byte pin, byte value);
    static byte digitalRead(byte pin);
    static void analogWrite(byte pin, byte value);
    static int  analogRead(byte pin);
    static void tone(byte pin, unsigned int frequency, unsigned long duration);
    static byte noTone(byte pin);
    static void delay(unsigned int duration);
};

class MWArduinoClass
{   
public:
    void pinModeMW(byte pin, byte value);
    void digitalWriteMW(byte pin, byte value);
	byte digitalReadMW(byte pin);
	void analogWriteMW(byte pin, byte value);
	int analogReadMW(byte pin);
	void toneMW(byte pin, unsigned int frequency, unsigned long duration);
	
public:
	MWArduinoClass();
    void begin(byte type);
    void update();
    void setupLibs();
    void loopLibs();
    void registerLibrary(LibraryBase* lib);
    void sendResponseMsg(byte cmdID, byte* dataIn, unsigned int payloadSize);
    void debugPrint(va_list args, char *fmt_char );
    byte isTraceOn();

public:
    bool isSetup;
    LibraryBase* libraryArray[MAX_NUM_LIBRARIES];
private:
    MWProtocolBase* MWProtocol;
};


extern MWArduinoClass MWArduino;

#endif // MWArduino.h

