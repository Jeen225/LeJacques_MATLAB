function postInstall()
%POSTINSTALL install the Adafruit Motor shield V2 library into the Arduino
%IDE libraries folder

% Copyright 2016 The MathWorks, Inc.

% Get downloaded Arduino IDE libraries path
IDELibraryDir = fullfile(arduinoio.IDERoot, 'libraries');

% Create Adafruit_MotorShield and MWArduino folder inside Arduino IDE folder
AFLibDesDir = fullfile(IDELibraryDir, 'Adafruit_MotorShield');
[~,~] = mkdir(AFLibDesDir);
MWLibDesDir = fullfile(IDELibraryDir, 'MWArduino');
[~,~] = mkdir(MWLibDesDir);

% Get extracted Adafruit motor shield library path
AFLibSrcDir = matlab.internal.get3pInstallLocation('adafruitmotorshieldv2.instrset');
AFLibSrcDir = fullfile(AFLibSrcDir, 'Adafruit_Motor_Shield_V2_Library-1.0.4');
MWLibSrcDir = fullfile(matlabshared.supportpkg.getSupportPackageRoot, 'toolbox', 'matlab', 'hardware', 'supportpackages', 'arduinoio', 'src');

% Copy Adafruit and MWArduino library source into Arduino IDE libraries folder
copyfile(AFLibSrcDir, AFLibDesDir, 'f');
copyfile(fullfile(MWLibSrcDir, 'MWArduino.h'), MWLibDesDir, 'f');
copyfile(fullfile(MWLibSrcDir, 'MWArduino.cpp'), MWLibDesDir, 'f');
copyfile(fullfile(MWLibSrcDir, 'LibraryBase.h'), MWLibDesDir, 'f');
copyfile(fullfile(MWLibSrcDir, 'MWProtocolBase.h'), MWLibDesDir, 'f');
copyfile(fullfile(MWLibSrcDir, 'MWProtocolBase.cpp'), MWLibDesDir, 'f');
copyfile(fullfile(MWLibSrcDir, 'MWProtocolSerial.h'), MWLibDesDir, 'f');
copyfile(fullfile(MWLibSrcDir, 'MWProtocolSerial.cpp'), MWLibDesDir, 'f');
copyfile(fullfile(MWLibSrcDir, 'MWProtocolWiFi.h'), MWLibDesDir, 'f');
copyfile(fullfile(MWLibSrcDir, 'MWProtocolWiFi.cpp'), MWLibDesDir, 'f');

end