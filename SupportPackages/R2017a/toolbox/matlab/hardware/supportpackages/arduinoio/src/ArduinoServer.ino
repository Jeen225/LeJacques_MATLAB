/**
 * @file ArduinoServer.ino
 * Arduino sketch for MATLAB Arduino server
 * @copyright Copyright 2015-2016 The MathWorks, Inc.
 */

#include <MWArduino.h>

[additional_include]

void setup()
{
    MWArduino.begin([connection_type]);
}

void loop()
{
    MWArduino.update();
}
