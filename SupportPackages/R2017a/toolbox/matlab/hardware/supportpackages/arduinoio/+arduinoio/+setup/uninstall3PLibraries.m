function uninstall3PLibraries()
%UNINSTALL3PLIBRARIES uninstall the MWArduino library and motor shield 
%library

% Copyright 2014-2016 The MathWorks, Inc.

IDERootDir = arduinoio.IDERoot;

rmdir(fullfile(IDERootDir, 'libraries', 'Adafruit_MotorShield'), 's');
rmdir(fullfile(IDERootDir, 'libraries', 'MWArduino'), 's');

end