/**
 * @file LibraryBase.h
 *
 * Class definition for base class for all add-on libraries
 *
 * @copyright Copyright 2014-2016 The MathWorks, Inc.
 *
 */

#ifndef LibraryBase_h
#define LibraryBase_h

#include "MWArduino.h"

class LibraryBase{
	public:
		const char* getLibraryName() const 
		{
			return libName;
		}
		
	public:
		virtual void commandHandler(byte cmdID, byte* dataIn, unsigned int payloadSize) = 0;
        virtual void setup() {}
        virtual void loop() {}
        
    protected:
        const char* libName;
};

#endif