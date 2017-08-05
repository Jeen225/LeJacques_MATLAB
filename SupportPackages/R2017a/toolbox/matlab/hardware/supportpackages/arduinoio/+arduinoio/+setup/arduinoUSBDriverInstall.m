classdef arduinoUSBDriverInstall < hwconnectinstaller.FirmwareUpdate
    %FirmwareUpdate Firmware update class.
    %   Detailed explanation goes here
    
    %   Copyright 2014-2016 The MathWorks, Inc.
    
    properties (Access = public)
        EnableDriverInstall = 1;
    end
    
    % Arduino USB Driver Installation methods
    methods
        function obj = arduinoUSBDriverInstall()
            obj.SupportPkg = 'Arduino I/O';
        end
        
        function tSteps = getFirmwareUpdateSteps(obj)
            if ispc
                tSteps(1) = hwconnectinstaller.Step('ArduinoDriverInstall', ...
                    @arduinoio.setup.internal.getArduinoDriverInstallSchema, ...
                    @arduinoio.setup.internal.executeArduinoDriverInstall);
            else
                tSteps(1) = hwconnectinstaller.Step('ArduinoDriverInstall', ...
                    @arduinoio.setup.internal.getDummyArduinoDriverInstallSchema, ...
                    @arduinoio.setup.internal.executeDummyArduinoDriverInstall);
            end 
        end
    end
    
    methods (Static, Access = public)
        function ret = isFirmwareUpdateNeeded()
			ret = true;
        end
    end
    
    methods (Access = public)
        function ret = installArduinoUSBDriver(obj)
                % Install driver
                idedir = ide.internal.getArduinoIDERootDir();
                arduinoinffolder = fullfile(idedir, 'drivers');
                inffile = fullfile(arduinoinffolder, 'arduino.inf');
                cmdstr = ['rundll32.exe setupapi,InstallHinfSection DefaultInstall 128 ' inffile];
                
                [ret, ~] = hwconnectinstaller.internal.systemExecute(cmdstr);
        end
    end
end

% LocalWords:  
