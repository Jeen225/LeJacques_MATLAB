classdef HardwareInterface < handle
    %HARDWAREINTERFACE This interface will be used to execute Arduino
    %Setup functions

    % Copyright 2016-2017 The MathWorks, Inc.
    
    methods
        function ret = installArduinoUSBDriver(~)
            %find the inf installation files in the current arduino IDE root
            %Directory. Launch the inf installer for each
            idedir = ide.internal.getArduinoIDERootDir();
            arduinoinffolder = fullfile(idedir, 'drivers');

            standardInfFile = fullfile(arduinoinffolder, 'arduino.inf');
            orgInfFile = fullfile(arduinoinffolder, 'arduino-org.inf');
            genuinoInfFile = fullfile(arduinoinffolder, 'genuino.inf');

            standardCmdStr = ['rundll32.exe setupapi,InstallHinfSection DefaultInstall 128 ' standardInfFile];
            orgCmdStr = ['rundll32.exe setupapi,InstallHinfSection DefaultInstall 128 ' orgInfFile];
            genuinoCmdStr = ['rundll32.exe setupapi,InstallHinfSection DefaultInstall 128 ' genuinoInfFile];

            %if any of the expected inf files aren't available return a
            %failure
            if ~exist(standardInfFile, 'file') ||...
                    ~exist(orgInfFile, 'file') ||...
                    ~exist(genuinoInfFile, 'file')
                ret=1;
            else
                stdReturn  = system(standardCmdStr, '-runAsAdmin');
                orgReturn  = system(orgCmdStr, '-runAsAdmin');
                genReturn  = system(genuinoCmdStr, '-runAsAdmin');

                %if ret is non-zero there was an error
                ret = abs(stdReturn) + abs(orgReturn) + abs(genReturn);

            end
        end
        
        function [ports, index] = getAvailableArduinoPorts(~, oldPort)
            %find all available serial ports and also return the index 
            %position of the old port in returned cell arrary
            usbdev = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
            ports = getSerialPorts(usbdev);
            if isempty(ports)
                ports = {'select a value'};
            else
                ports = ['select a value',ports];
            end
            % If last selected port still exists, use last port. Otherwise,
            % use first item value
            index = find(ismember(ports, oldPort));
            if isempty(index)
                index = 1;
            end
        end
        
        function ports = getAvailableSerialPorts(~)
            %find all available serial ports on the system
            %this includes true serial, serial over bluetooth and USB
            %serial
            s = seriallist;
            if isempty(s)
                ports = {'select a value'};
            else
                ports = s.cellstr;
                ports = ['select a value',ports];
            end
        end
        
        function validateKey(~, key)
            %Check if key is valid,e.g 10-bit or 26-bit hex number
            keyLen = numel(key);
            if ((keyLen~=arduinoio.internal.ArduinoConstants.MinKeyNumDigits)&&(keyLen~=arduinoio.internal.ArduinoConstants.MaxKeyNumDigits)) || (any(~isstrprop(key, 'xdigit')))
                id = 'MATLAB:arduinoio:general:invalidKey';
                error(id, message(id).getString);
            end
        end
        
        function validateKeyIndex(~, index)
            %Check if key index is valid,e.g integer numeric
            if any(~isstrprop(index,'digit'))
                id = 'MATLAB:arduinoio:general:invalidKeyIndex';
                error(id, message(id).getString);
            end
        end
        
        function validateTCPIPPort(~, port)
            %Check if TCP/IP port is an 16 bit integer bigger than 1024
            try
                validateattributes(port,{'double'}, {'finite','scalar','integer','>', arduinoio.internal.ArduinoConstants.MinPortValue,'<=', arduinoio.internal.ArduinoConstants.MaxPortValue})
            catch
                id = 'MATLAB:arduinoio:general:invalidWiFiPort';
                error(id, getString(message(id,num2str(arduinoio.internal.ArduinoConstants.MinPortValue),num2str(arduinoio.internal.ArduinoConstants.MaxPortValue))));
            end
        end
        
        function validateIPAddress(~, ip)
            %Check if IP format is valid
            output = regexp(ip, '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}','match');
            if isempty(output) || ~strcmp(output, ip)
                id = 'MATLAB:arduinoio:general:invalidIPAddress';
                error(id, message(id).getString);
            end
        end
        
        function validateBTAddress(~, address)
            % Check bluetooth address is 12-bit hex string
            if (numel(address)~=arduinoio.internal.ArduinoConstants.BluetoothAddressLength) || (any(~isstrprop(address, 'xdigit')))
                id = 'MATLAB:arduinoio:general:invalidBTAddress';
                error(id, message(id).getString);
            end
        end
        
        function validateNetworkSettings(~, workflow)
            %Check whether all required network settings parameters have
            %been specified based on the encryption type
            switch workflow.Encryption
                case arduinoio.internal.WiFiEncryptionTypeEnum.WPA
                    % check SSID, Password and Port to be all non-empty
                    if isempty(workflow.SSID) || isempty(workflow.Password) || isempty(workflow.TCPIPPort)
                        id = 'MATLAB:arduinoio:general:emptyWPAParameters';
                        error(id, message(id).getString);
                    end
                case arduinoio.internal.WiFiEncryptionTypeEnum.WEP
                    % check SSID, Key, Key inde and Port to be all non-empty
                    if isempty(workflow.SSID) || isempty(workflow.Key)|| isempty(workflow.KeyIndex) || isempty(workflow.TCPIPPort)
                        id = 'MATLAB:arduinoio:general:emptyWEPParameters';
                        error(id, message(id).getString);
                    end
                case arduinoio.internal.WiFiEncryptionTypeEnum.None
                    % check SSID and Port to be all non-empty
                    if isempty(workflow.SSID) || isempty(workflow.TCPIPPort)
                        id = 'MATLAB:arduinoio:general:emptyNoneParameters';
                        error(id, message(id).getString);
                    end
            end
            if workflow.UseStaticIP
                if isempty(workflow.StaticIP)
                    id = 'MATLAB:arduinoio:general:emptyStaticIPAddress';
                    error(id, message(id).getString);
                end
            end
        end
        
        function msg = uploadArduinoServer(~, workflow)
            %program Arduino board with proper server based on given
            %workflow
            utility = arduinoio.internal.UtilityCreator.getInstance();
            resMgr = arduinoio.internal.ResourceManager(workflow.Board);
            buildInfo = getBuildInfo(resMgr);
            buildInfo.ConnectionType = workflow.ConnectionType;
            buildInfo.Port = workflow.Port;
            buildInfo.Libraries = workflow.Libraries;
            % Always display compile and upload result
            buildInfo.ShowUploadResult = true;
            buildInfo.TraceOn = false;
            if workflow.ConnectionType == arduinoio.internal.ConnectionTypeEnum.WiFi
                buildInfo.Encryption = workflow.Encryption;
                buildInfo.SSID = workflow.SSID;
                buildInfo.TCPIPPort = workflow.TCPIPPort;
                if workflow.UseStaticIP
                    buildInfo.StaticIP = workflow.StaticIP;
                else
                    buildInfo.StaticIP = '';
                end
                switch buildInfo.Encryption
                    case arduinoio.internal.WiFiEncryptionTypeEnum.WPA
                        buildInfo.Password = workflow.Password;
                    case arduinoio.internal.WiFiEncryptionTypeEnum.WEP
                        buildInfo.Key = workflow.Key;
                        buildInfo.KeyIndex = workflow.KeyIndex;
                end
            end
            try
                msg = updateServer(utility, buildInfo);
            catch e
                throwAsCaller(e);
            end
        end
        
        function [boards, index] = getSupportedBoards(~, type, oldBoard)
            %return a cell array of supported boards based on given
            %connection type and also return the index of the old board in
            %the returned board list
            boards = arduinoio.internal.ArduinoConstants.getSupportedBoards(type);
            index = 1;
            switch type
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    boards = ['select a value', boards];
                    if ~strcmpi(oldBoard, 'MKR1000')
                        index = find(ismember(boards, oldBoard));
                        if isempty(index)
                            index = 1;
                        end
                    end
                case arduinoio.internal.ConnectionTypeEnum.Serial
                    boards = ['select a value', boards];
                    index = find(ismember(boards, oldBoard));
            end
        end
        
        function [ipAddress, port] = retrieveIPAddress(~, serialport) 
            %Get the currently assigned IP address of the device which has
            %Arduino server downloaded 
            ipAddress = [];
            port = [];
            s = serial(serialport, 'baudrate', arduinoio.internal.ArduinoConstants.MKR1000SerialBaudRate);
            fopen(s);
            c = onCleanup(@()cleanup(s));
            t = tic;
            % Wait for at most 10s for device to connect to network
            % and respond back with IP address
            try
                while(toc(t) < 10)
                    fwrite(s, 'whatisyourip', 'uint8'); 
                    if(s.BytesAvailable>0)
                        data = fscanf(s, '%s', s.BytesAvailable);
                        output = regexp(data, ';', 'split');
                        status = str2double(output{1});
                        if status == arduinoio.internal.WiFiStatusEnum.WL_CONNECTED
                            ipAddress = output{2};
                            port = str2double(output{3});
                            break;
                        else
                            switch status
                                case arduinoio.internal.WiFiStatusEnum.WL_NO_SSID_AVAIL
                                    id = 'MATLAB:arduinoio:general:noSSIDAvailable';
                                    error(id, message(id).getString);
                                case arduinoio.internal.WiFiStatusEnum.WL_CONNECT_FAILED
                                    id = 'MATLAB:arduinoio:general:wlConnectFailed';
                                    error(id, message(id).getString);
                                case arduinoio.internal.WiFiStatusEnum.WL_CONNECTION_LOST
                                    id = 'MATLAB:arduinoio:general:wlConnectLost';
                                    error(id, message(id).getString);
                                case arduinoio.internal.WiFiStatusEnum.WL_DISCONNECTED
                                    id = 'MATLAB:arduinoio:general:wlDisconneted';
                                    error(id, message(id).getString);
                            end
                        end
                    end
                end
            catch e
                if ~strcmpi(e.identifier, 'MATLAB:serial:fwrite:opfailed')
                    throwAsCaller(e);
                end
            end
            % Make sure serial port is closed on exist of the function
            function cleanup(s)
                fclose(s);
            end
        end
        
        function texts = getBTConfigureSteps(~, type)
            %return a cell array of character vectors containing texts for
            %each step of configuring Bluetooth device based on the type
            texts = [];
            step1 = getString(message('MATLAB:arduinoio:general:ConfigureBTScreenTableText1',arduinoio.internal.ArduinoConstants.PairCode));
            if type == arduinoio.internal.BluetoothDeviceTypeEnum.HC06
                texts = {step1};
            elseif type == arduinoio.internal.BluetoothDeviceTypeEnum.HC05
                texts = {message('MATLAB:arduinoio:general:ConfigureBTScreenTableText2').getString, step1};
            end
        end
        
        function [rates, index] = getBTSupportedBaudRates(~, type)
            %return a cell array of supported baud rates for given type and
            %also return the default factory baud rate index in the cell
            %array
            rates = arduinoio.internal.ArduinoConstants.getBTSupportedBaudRates(type);
            index = [];
            if type == arduinoio.internal.BluetoothDeviceTypeEnum.HC06
                % Set pre-selected baud rate to 38400
                index = 6;
            elseif type == arduinoio.internal.BluetoothDeviceTypeEnum.HC05 
                % HC-05 always enters the limited AT mode with 38400 baud rate
                index = 1;
            end
        end
        
        function result = configureBTDevice(~, type, port, board, newname)
            %configure Bluetooth device HC05/HC06 at given port to
            %board-specific baudrate via AT commands
            %Example:
            %   configureBTDevice(obj, arduinoio.internal.BluetoothDeviceTypeEnum.HC05, 'COM20', 'Uno')
            %   configureBTDevice(obj, arduinoio.internal.BluetoothDeviceTypeEnum.HC05, 'COM82', 'Uno', 'UnoHC05')
            
            % TODO - if other boards with other baudrate are to be
            % supported, this hardcoded value shall be changed into a map
            % or stuct.
            if ismember(board, arduinoio.internal.ArduinoConstants.BluetoothSupportedBoards) 
                newbaudrate = arduinoio.internal.ArduinoConstants.ArduinoBTBaudRate;
            end
            switch type
                case arduinoio.internal.BluetoothDeviceTypeEnum.HC05
                    ATScript = {'AT+ROLE=0', ...
                                ['AT+PSWD=',arduinoio.internal.ArduinoConstants.PairCode], ...
                                ['AT+UART=',num2str(newbaudrate),',0,0']};
                    if nargin > 5
                        ATScript = [ATScript, ['AT+NAME=',newname]];
                    end
                    serialObject = serial(port, 'Terminator', 'CR/LF');
                case arduinoio.internal.BluetoothDeviceTypeEnum.HC06
                    if newbaudrate == 115200 % only use this rate now given the list of boards we support
                        command = 'AT+BAUD8';
                    end
                    ATScript = {['AT+PIN',arduinoio.internal.ArduinoConstants.PairCode], command};
                    if nargin > 5
                        ATScript = [ATScript, ['AT+NAME',newname]];
                    end
                    serialObject = serial(port, 'Terminator', '');
                otherwise
                    result = false;
                    return;
            end
            result = false;
            baudrates = arduinoio.internal.ArduinoConstants.BTSupportedBaudRates(double(type));
            c = onCleanup(@() cleanup(serialObject));
            try
                fopen(serialObject);
                for ii = 1:numel(baudrates)
                    % iterate through all supported baudrates for given BT
                    % device and execute the first AT command to see if the
                    % correct baudrate is found.
                    serialObject.BaudRate = str2double(baudrates(ii));
                    result = sendATHelper(serialObject,ATScript{1});
                    % once the first command executes fine, finish
                    % executing all remaining commands. If any command
                    % fails, return false.
                    index = 2;
                    while result&&index<=length(ATScript)
                        result = sendATHelper(serialObject,ATScript{index});
                        if ~result
                            return;
                        end
                        index=index+1;
                    end
                    % if all comands execute fine, return true
                    if result
                        return;
                    end
                end
            catch
                % do nothing
            end
            
            function out = sendATHelper(serialObject,command)
                out = false;
                fprintf(serialObject, command);
                localTimer = tic;
                while toc(localTimer) < 3
                    if serialObject.BytesAvailable > 0
                        output = char(fread(serialObject,serialObject.BytesAvailable,'uint8')');
                        % Check if result is non-empty and contains OK
                        if contains(output, 'OK')
                            out = true;
                        end
                    end
                end
            end
            
            function cleanup(serialObject)
                fclose(serialObject);
                delete(serialObject);
            end
        end
        
        function [properties, value] = getDeviceProperties(~, workflow)
            %Return Arduino properties and their values based on connection
            %type
            libs = strjoin(workflow.Libraries,', ');
            switch workflow.ConnectionType
                case arduinoio.internal.ConnectionTypeEnum.Serial
                    properties = {'Connection Type','Port','Board','Libraries'};
                    value = {'USB',workflow.Port,workflow.Board,libs};
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    if any(workflow.BluetoothDevice == [arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitProgrammer,...
                                                        arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitShield])
                        properties = {'Connection Type','Port','Board','Libraries'};
                        value = {'Bluetooth',workflow.BluetoothSerialPort,workflow.Board,libs};
                    else
                        properties = {'Connection Type','Device Address','Board','Libraries'};
                        value = {'Bluetooth',workflow.DeviceAddress,workflow.Board,libs};
                    end
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    properties = {'Connection Type','Device Address','Board','Port','Libraries'};
                    value = {'WiFi',workflow.DeviceAddress,workflow.Board,num2str(workflow.TCPIPPort),libs};
            end
        end
        
        function [result,err] = testConnection(~, workflow)
            %Attempts to create arduino connecton based on current settings
            result = false;
            err = '';
            try
                switch workflow.ConnectionType
                    case arduinoio.internal.ConnectionTypeEnum.Serial
                        a = arduino(workflow.Port, workflow.Board); %#ok<NASGU>
                        clear a;
                    case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                        if any(workflow.BluetoothDevice == [arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitProgrammer,...
                                                            arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitShield])
                            a = arduino(workflow.BluetoothSerialPort, workflow.Board); %#ok<NASGU>
                            clear a;
                        else
                            a = arduino(workflow.DeviceAddress, workflow.Board); %#ok<NASGU>
                            clear a;
                        end
                    case arduinoio.internal.ConnectionTypeEnum.WiFi
                        a = arduino(workflow.DeviceAddress, workflow.Board, workflow.TCPIPPort); %#ok<NASGU>
                        clear a;
                end
                result = true;
            catch e
                err = e;
            end
        end
    end

end

% LocalWords:  rundll setupapi
