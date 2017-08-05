/**
 * @file HelloWorld.h
 *
 * MathWorks Arduino Add-on library template
 *
 * @copyright Copyright 2015-2016 The MathWorks, Inc.
 *
 */

// Step 1 - Include header files, if any, provided by the 3P library

#include "LibraryBase.h"

// Step 2 - Define debug message strings which will print back in MATLAB
const char MSG_EXAMPLE_DEBUG[] 	PROGMEM = "Example debug message: cmdID %d\n";

// Define C++ class that inherits from LibraryBase to get properly registered in server
class HelloWorld : public LibraryBase
{
	public:
		HelloWorld(MWArduinoClass& a)
		{
            // Step 3 - Define 3P library name
            libName = "ExampleAddon/HelloWorld";
            // Register library name and its pointer.
 			a.registerLibrary(this);
		}
		
	public:
		void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize)
		{
            // Print debug message string each time a message is processed
            debugPrint(MSG_EXAMPLE_DEBUG, cmdID);
            switch (cmdID){
                // Step 4 - Dispatch incoming commands using case statement
                case 0x01:{  
                    byte val [13] = "Hello World!";
                    sendResponseMsg(cmdID, val, 13);
                    break;
                }
                default:{
                    // Do nothing
                }
            }
        }
};