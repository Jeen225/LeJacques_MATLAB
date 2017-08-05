/**
 * @file MWProtocolBase.h
 *
 * Class prototype for abstract MWProtocolBase class that defines server/client communication protocol between MATLAB and Arduino
 *
 * @copyright Copyright 2016 The MathWorks, Inc.
 *
 */
#ifndef MWProtocolBase_h
#define MWProtocolBase_h

#include "Arduino.h"   
#if defined(ARDUINO_ARCH_SAMD)  
#include <stdarg.h> // String formatting- variable-length inputs
#endif

#if defined(__AVR_ATmega328P__)//Uno, Nano, Fio, etc
#define TOTAL_PINS              20 // 14 digital + 6 analog
#define TOTAL_ANALOG_PINS       6
#define MAX_MESSAGE_SIZE 160    // max number of data bytes in a message
#elif defined(__AVR_ATmega2560__)
#define TOTAL_PINS              70 // 54 digital + 16 analog
#define TOTAL_ANALOG_PINS       16
#define MAX_MESSAGE_SIZE 800    // max number of data bytes in a message
#elif defined(__SAM3X8E__)  //Due board
#define TOTAL_PINS              66 // 54 digital + 12 analog
#define TOTAL_ANALOG_PINS       12
#define MAX_MESSAGE_SIZE 800    // max number of data bytes in a message
#elif defined(__AVR_ATmega32U4__)
#define TOTAL_PINS              30 // 14 digital + 12 analog + 4 SPI (D14-D17 on ISP header)
#define TOTAL_ANALOG_PINS       12
#define MAX_MESSAGE_SIZE 160    // max number of data bytes in a message
#elif defined(__SAMD21G18A__)  //MKR1000
#define TOTAL_PINS              22 // 15 digital + 7 analog
#define TOTAL_ANALOG_PINS       7
#define MAX_MESSAGE_SIZE 800    // max number of data bytes in a message
#endif
#define IS_PIN_DIGITAL(p)       ((p) >= 2 && (p) < TOTAL_PINS)


/* 
   MATLAB Message Format 
   HEADER payloadSize isLib+sequenceID cmdID Data Checksum           isLib - 0x00
        1       2             1          1     *     1 
   HEADER payloadSize isLib+sequenceID libID cmdID Data Checksum     isLib - 0x01
        1       2            1           1     1     *     1 

   Arduino Response Format 
   HEADER debugID payloadSize cmdID Data Checksum 
        1    1          2       1     *      1
*/
#define MATLAB_MESSAGE_HEADER          0x5A // start a message sent from MATLAB to Arduino
#define ARDUINO_RESPONSE_HEADER        0xA5 // start a response sent from Arduino to MATLAB

#define PROTOCOL_TYPE_SERIAL    0x00
#define PROTOCOL_TYPE_TCPIP     0x01

extern "C" {
    typedef void (*msgDispatcher)(byte isLib, byte* inputs, unsigned int payloadSize);
}

class MWProtocolBase
{
public: 
    // Factory method for creating the correct transport instance
    static MWProtocolBase *getMWProtocol(byte type);

public: 
    MWProtocolBase();
    void sendResponseMsg(byte cmdID, byte* dataIn, unsigned int payloadSize) const;
    void debugPrint(va_list args, char *fmt_char ) const;
    void attach(msgDispatcher newFunction);
    byte m_isTraceOn;

    // Methods that can optionally be overriden in transport specific classes to perform specific tasks
    virtual void begin() const;  
    virtual void update();
    virtual void systemReset(void);

protected:
    // Method that is called by child class to process incoming messages via its transport
    void processInput(void);

private:
    // Methods that must be defined in transport specific classes
    virtual const int bytesAvailable(void) const = 0;
    virtual void writeByte(byte data) const = 0;      // write a byte
    virtual void print(char* data) const = 0;    // write char array, e.g multiple bytes
    virtual const int readByte() const = 0;           // read a byte
    virtual const int readBytes(byte*, size_t) = 0;      // read mulitiple bytes

    // Internal methods and properties
    const byte computeMsgInChecksum(byte* data, size_t dataLen) const; // for incoming data
    const byte computeMsgOutChecksum(byte cmdID, byte* dataIn, size_t payloadSize) const; // for outgoing data
    void processMessage(void);
    const boolean checkMsgIntegrity(byte* message) const;

    msgDispatcher m_currentMsgDispatcher;
    byte m_inputDataBuffer[MAX_MESSAGE_SIZE];
    size_t m_payloadSize;
    byte m_receivedChecksum;
    // structure of pointers to different fields of an incoming message
    struct MWMessage  
    {
        byte* pPayloadSize;
        byte* pPayload;
        byte* pCmdID;
    } m_msg = {m_inputDataBuffer, m_inputDataBuffer+2,m_inputDataBuffer+3};
};


#endif /* MWProtocolBase_h */

