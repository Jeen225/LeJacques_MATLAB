classdef ArduinoWorkflow < matlab.hwmgr.internal.hwsetup.Workflow
    %ARDUINOWORKFLOW The ARDUINOWORKFLOW class is an object that contains
    %all of the persistent information for the Arduino Hardware Setup
    %screens

    % Copyright 2017 The MathWorks, Inc.

    properties
        %LaunchByArduinoSetup - Flag indicates whether workflow is launched by arduinosetup
        LaunchByArduinoSetup 
        %DriverEnable - USB driver installation decision from user
        DriverEnable
        %DriverInstallationError - Results from Driver Installation
        DriverInstallationError
        %SkipSetup - Flag indicating whether to skip setting up Arduino
        SkipSetup
        %ShowExamples - Example display decision from user
        ShowExamples
        %HWInterface - Interface for HW specific setup callbacks
        HWInterface
        %ResourcesDir - Full path of resources folder in support package
        ResourcesDir
        %ConnectionType - User selected connection type
        ConnectionType
        %Board - User selected board type
        Board
        %Port - User selected port type
        Port
        %Libraries - User selected libraries to be included in server
        Libraries
        %Encryption - User selected WiFi network encryption type
        Encryption
        %Key - User specified WiFi WEP Key
        Key
        %KeyIndex - User specified WiFi WEP KeyInde
        KeyIndex
        %SSID - User specified WiFi name
        SSID
        %Password - User specified WiFi password
        Password
        %TCPIPPort - Default or user specified TCP/IP port
        TCPIPPort
        %UseStaticIP - Flag indicates users wants to use static IP or not
        UseStaticIP
        %StaticIP - User specified static IP address
        StaticIP
        %BluetoothDevice - User selected Bluetooth device
        BluetoothDevice
        %PairCode - Bluetooth device's pairing code
        PairCode
        %DeviceAddress - Bluetooth/WiFi address
        DeviceAddress
        %BluetoothSerialPort - Serial over Bluetooth port
        BluetoothSerialPort
        %SkipProgram - Flag indicates whether to skip programming WiFi board
        SkipProgram
        %SkipConfigure - Flag indicates whether to skip configuring Bluetooth device
        SkipConfigure
        %LogFileName - Log file name for the current setup session
        LogFileName
        %Logger - Logger handle
        Logger
    end

    properties
       %Workflow Abstract Properties
       Name = 'Arduino IO'
       FirstScreenID
    end

    properties(Constant)
       BaseCode='ML_ARDUINO'
    end

    methods
        function obj = ArduinoWorkflow(varargin)
            % register error message catalog
            m = message('MATLAB:arduinoio:general:invalidPort', 'test');
            try
                m.getString();
            catch
                vendorMFilePath = fileparts(arduinoio.SPPKGRoot);
                toolboxIndex = strfind(arduinoio.SPPKGRoot, [filesep, 'toolbox', filesep]);
                supportPackageBasePath = vendorMFilePath(1:toolboxIndex);
                matlab.internal.msgcat.setAdditionalResourceLocation(supportPackageBasePath);
            end
            
            obj@matlab.hwmgr.internal.hwsetup.Workflow();
            initProperties(obj);
            if nargin>0 && strcmp(varargin{1},'setup')
                obj.FirstScreenID = 'arduinoio.setup.internal.SelectConnectionScreen';
                obj.LaunchByArduinoSetup = true;
            else
                if ~isunix
                    obj.FirstScreenID = 'arduinoio.setup.internal.DriverInstallScreen';
                else
                    obj.DriverInstallationError = false;
                    obj.FirstScreenID = 'arduinoio.setup.internal.DriverInstallResultScreen';
                end
                obj.LaunchByArduinoSetup = false;
            end
        end
        
        function delete(obj)
            delete(obj.Logger);
            % Delete log file created on opening setup but is empty
            s = dir(obj.LogFileName);
            if s.bytes==0
                delete(obj.LogFileName);
            end
        end
    end
    
    methods(Access = protected)
        function initProperties(obj)
            %The default selection for DriverEnable is 1 indicating the
            %user wishes to install the Arduino USB Drivers
            obj.DriverEnable = true;
            obj.DriverInstallationError = false;
            obj.SkipSetup = false;
            obj.SkipConfigure = false;
            obj.ShowExamples = true;
            obj.ResourcesDir = fullfile(arduinoio.SPPKGRoot, 'resources');
            obj.ConnectionType = arduinoio.internal.ConnectionTypeEnum.Serial;
            obj.Board = 'select a value';
            obj.Port = 'select a value';
            obj.BluetoothDevice = arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitProgrammer;
            obj.Libraries = arduinoio.internal.ArduinoConstants.DefaultLibraries;
            obj.PairCode = str2double(arduinoio.internal.ArduinoConstants.PairCode);
            obj.BluetoothSerialPort = 'select a value';
            obj.TCPIPPort = arduinoio.internal.ArduinoConstants.DefaultTCPIPPort;
            obj.Encryption = arduinoio.internal.WiFiEncryptionTypeEnum.WPA;
            obj.UseStaticIP = false;
            obj.HWInterface = arduinoio.setup.internal.HardwareInterface();
            obj.LogFileName = fullfile(tempdir,['MWArduinoLog-',char(datetime('now','format','yyMMddHHmmss')),'.txt']);
            obj.Logger = matlab.hwmgr.internal.logger.Logger(obj.LogFileName);
        end
    end

end

% LocalWords:  arduinoio
