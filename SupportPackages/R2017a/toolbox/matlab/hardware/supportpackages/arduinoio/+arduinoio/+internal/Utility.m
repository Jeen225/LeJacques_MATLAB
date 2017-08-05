classdef Utility < arduinoio.internal.BaseClass
    
    %   Copyright 2014-2016 The MathWorks, Inc.
    
    properties(Access = protected)
        BoardInfo
    end
    
    properties(Access = private, Constant = true)
        Group = 'MATLAB_HARDWARE'
        Pref = 'ARDUINOIO'
    end
    
    properties(Access = private)
        CurrentSystemPath
        CurrentCPath
        CurrentDYLDLibPath
        CurrentLDLibPath
        DeleteTempDir
    end
    
    
    methods (Abstract)
        buildInfo = setProgrammer(obj, buildInfo);
    end
    
    %% Constructor
    methods
        function obj = Utility
            obj.BoardInfo = arduinoio.internal.BoardInfo.getInstance();
        end
    end
    
    %% Public methods
    methods (Access = public)
        function validateIDEPath(obj, IDEPath)
            % Check if the given IDEPath points to a 1.6.x version of
            % Arduino IDE and if one or few files needed exists
            files = {fullfile('hardware','arduino','avr','cores','arduino', 'hooks.c'), fullfile('libraries','MWArduino','MWArduino.cpp')};
            for i = 1:length(files)
                if ~exist(fullfile(IDEPath, files{i}), 'file')
                    obj.localizedError('MATLAB:arduinoio:general:invalidIDEPath', IDEPath)
                end
            end
        end
        
        function newLibs = validateLibraries(~, libs)
            % Validate given library name input to obtain the full list of
            % libraries including dependent libraries and check their existance
            libraryList = listArduinoLibraries();
            validateFcn = @(x) validatestring(x, libraryList, 'arduinoio', 'libraries');
            libs = strrep(libs, '\', '/');
            givenLibs = cellfun(validateFcn, libs, 'UniformOutput', false); % check given libraries all exist
            newLibs = arduinoio.internal.getFullLibraryList(givenLibs);
        end
        
       function portInfo = validatePort(obj, port)
           % If given port number, this function tries to identify whether it is a
           % valid Arduino board and return the detected board type
           %
           % Otherwise, it returns the first detected Arduino's port number and
           % its corresponding board type
           %
           % Note, old Arduino boards with FTDI chips are not auto-detected
           
           findFlag = false;
           if nargin < 2 % If no input is given, find the first valid board
               usbdev = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
               if ~isempty(getSerialPorts(usbdev))
                   % Loop through all boards in boardInfo to find matching vid/pid pair
                   for bCount = 1:length(obj.BoardInfo.Boards)
                       theVIDPID = obj.BoardInfo.Boards(bCount).VIDPID;
                       if ~isempty(theVIDPID)
                           for index = 1:numel(theVIDPID)
                               pair = strsplit(theVIDPID{index}, '_');
                               port = getSerialPorts(usbdev, 'VendorID', pair{1}, 'ProductID', pair{2});
                               if ~isempty(port)
                                   portInfo.port = port{1};
                                   portInfo.board = obj.BoardInfo.Boards(bCount).Name;
                                   findFlag = true;
                                   break;
                               end
                           end
                       end
                   end
               end
               if ~findFlag
                   obj.localizedError('MATLAB:arduinoio:general:boardNotDetected');
               end
           else % If a port is given, find the matching board type
               origPort = port;
               % Workaround for g1452757 to allow user specify tty port
               % for auto-detection since the HW connection API only
               % detect cu port.
               if ismac
                   port = strrep(port, 'tty', 'cu');
               end
               usbdev = matlab.hwmgr.internal.hwconnection.USBDeviceEnumerator;
               [foundPorts, devinfo] = getSerialPorts(usbdev);
               if ~isempty(foundPorts)
                   % Workaround to find VID/PID based on given serial port
                   index = find(strcmpi(foundPorts, port));
                   foundVIDPID = '';
                   if ~isempty(index)
                       foundVIDPID = strcat('0x', devinfo(index).VendorID, '_0x', devinfo(index).ProductID);
                       foundPort = foundPorts{index};
                   end
                   % Loop through all boards in boardInfo to find matching vid/pid pair
                   for bCount = 1:length(obj.BoardInfo.Boards)
                       theVIDPID = obj.BoardInfo.Boards(bCount).VIDPID;
                       if ~isempty(theVIDPID)
                           for index = 1:numel(theVIDPID)
                               if strcmpi(theVIDPID{index}, foundVIDPID)
                                   if ismac
                                       portInfo.port = origPort; % keep using user specified port, either cu or tty
                                   else
                                       portInfo.port = foundPort; % foundPort is already case-corrected on Windows
                                   end
                                   portInfo.board = obj.BoardInfo.Boards(bCount).Name;
                                   findFlag = true;
                                   break;
                               end
                           end
                       end
                   end
               end
               if ~findFlag % No Arduino board is found at the given port
                   obj.localizedError('MATLAB:arduinoio:general:invalidPort', origPort);
               end
           end
       end
       
       function origPort = getOriginalPort(~, port)
           % Return original serial port based on given port. If symlink
           % port is given, return its original port. Otherwise, return
           % same port back
           [~, origPort] = system(['readlink ', port]);
           if ~isempty(origPort)
               origPort = ['/dev/',strtrim(origPort)];
                else
               origPort = port;
           end
       end
       
       function [status, address] = validateAddressExistence(obj, type, address)
           status = false;
           switch type
               case arduinoio.internal.ConnectionTypeEnum.Serial
                   if ispc
                        address = upper(address);
                   end
                   status = any(ismember(seriallist, address)); % seriallist does not show a port if in use?
               case arduinoio.internal.ConnectionTypeEnum.Bluetooth 
                    address = lower(address);
                    address = strrep(address, '\', '/');
                    isLicensed = hwconnectinstaller.internal.isProductInstalled('Instrument Control Toolbox');
                    if contains(address, 'btspp://') && ~isLicensed 
                        obj.localizedError('MATLAB:arduinoio:general:missingICT');
                    end
                    if isLicensed
                        if contains(address, 'btspp://')
                            address = ['btspp://', upper(address(9:end))];
                        end
                        devices = instrhwinfo('Bluetooth');
                        status = any(ismember(devices.RemoteNames(:), address)) || any(ismember(devices.RemoteIDs(:), address));
                        matches = sum(ismember(devices.RemoteNames(:), address));
                        % If bluetooth remote names are passed in and there
                        % are more than one bluetooth device with the same
                        % name detected, throw an error and ask for the
                        % unique address
                        if matches > 1
                            obj.localizedError('MATLAB:arduinoio:general:ambiguousBTName', address);
                        end
                    end
               case arduinoio.internal.ConnectionTypeEnum.WiFi
                   if strcmp(computer, 'GLNXA64')
                       obj.CurrentLDLibPath = getenv('LD_LIBRARY_PATH');
                       setenv('LD_LIBRARY_PATH', '');
                       c = onCleanup(@() cleanup(obj));
                   end
                   if strcmp(computer, 'PCWIN64')
                       cmd = ['ping -n 3 ',address];
                       [~, result] = system(cmd);
                       match = regexpi(result,'time=[0-9.]+ms TTL=\d+'); % time=6ms TTL=120
            	   else
                       cmd = ['ping -c 3 ',address];
                       [~, result] = system(cmd);
                       match = regexpi(result,'ttl=\d+ time=[0-9.]+ ms'); % ttl=56 time=6.42ms
                   end
                   status = ~isempty(match);
           end
            
           function cleanup(obj)
               setenv('LD_LIBRARY_PATH', obj.CurrentLDLibPath);
            end
        end
        
       function setPreference(obj, type, address, board, port, trace)
            % This function add the given input parameters to MATLAB preference
            % if none exists, or set the existing preference with the given
            % input parameters
            newPref.Address = address;
            newPref.Board = board;
            newPref.ConnectionType = type;
            newPref.Port = port; % TCPIP port
            newPref.TraceOn = trace;
            
            [isPref, oldPref] = getPreference(obj);
            if isPref && ~isequal(newPref, oldPref)
                setpref(obj.Group, obj.Pref, newPref);
            elseif ~isPref
                addpref(obj.Group, obj.Pref, newPref);
            end
        end
        
       function [isPref, pref] = getPreference(obj)
            isPref = ispref(obj.Group, obj.Pref);
            pref = [];
            if isPref
                pref = getpref(obj.Group, obj.Pref);
            end
        end
        
       function errorMsg = updateServer(obj, buildInfo)
       		% This function compiles all necessary source files and downloads
       		% the executable to the hardware 
            origPort = buildInfo.Port;
            buildInfo = preBuildProcess(obj, buildInfo); % populate the complete set of fields in buildInfo structure
            if exist(fullfile(tempdir, 'ArduinoServer'), 'dir')
                rmdir(fullfile(tempdir, 'ArduinoServer'), 's');
            end
            
            obj.DeleteTempDir = (buildInfo.ConnectionType==arduinoio.internal.ConnectionTypeEnum.WiFi);
            generateLibRegistrationHeader(obj, buildInfo);
            generateMacrosIncludeHeader(obj, buildInfo);
            generateMainSketch(obj, buildInfo);
            
            % Add tempdir to compiler's header file search dir
            obj.CurrentCPath = getenv('CPATH');
            setenv('CPATH', fullfile(tempdir, 'ArduinoServer'));
            if ispc
                obj.CurrentSystemPath = getenv('PATH');
                if strcmp(buildInfo.Arch, 'avr')
                    % Empty system path to ensure no interference from other WinAVR
                    % installations.
                    setenv('PATH', arduinoio.IDERoot);
                else
                    setenv('PATH', [obj.CurrentSystemPath, ';', arduinoio.IDERoot]);
                end
            elseif ismac
                % Reset environment variable to avoid Java interference
                % with Arduino IDE(default JAVA 8 runtime)
                obj.CurrentDYLDLibPath = getenv('DYLD_LIBRARY_PATH');
                setenv('DYLD_LIBRARY_PATH','');
            end
            % Turn-off Arduino plugin detection
            internal.deviceplugindetection.EnableArduinoHotPlug.getInstance.setEnableArduinoDPDM(false);
            c = onCleanup(@() cleanup(obj));
            
            errorMsg = '';
            [status, result1] = buildServer(obj, buildInfo);
            if ~status
                % Check compiled hex size fits in the flash memory
                validateServerSize(obj, buildInfo);
                [status, result2] = uploadServer(obj, buildInfo);
                if status
                    errorMsg = result2;
                end
                % Wrong boards specified or board(Due and MKR1000) not programmable
                if contains(result2, 'attempt 10 of 10: not in sync:')||... 
                   contains(result2, 'Unsupported processor')||... 
                   contains(result2, 'stk500v2_getsync(): timeout communicating with programmer')||...
                   contains(result2, ['No device found on ', buildInfo.Port])
                    status = 1;
                    errorMsg = result2;
                end
            else
                errorMsg = result1;
            end
            
            if status
                if ~buildInfo.ShowUploadResult
                    obj.localizedError('MATLAB:arduinoio:general:failedUpload', buildInfo.Board, origPort);
                end
            else
                errorMsg = ''; % reset error message to empty before returning back to indicate success
                if ismember(buildInfo.Board, {'Micro', 'Leonardo'})
                    pause(5);
                elseif buildInfo.ConnectionType==arduinoio.internal.ConnectionTypeEnum.WiFi&&strcmpi(buildInfo.Board, 'MKR1000')
                    pause(10);
                end
            end
            
           function cleanup(obj)
               % Turn-on Arduino plugin detection
               internal.deviceplugindetection.EnableArduinoHotPlug.getInstance.setEnableArduinoDPDM(true);
               try
                   if obj.DeleteTempDir && exist(fullfile(tempdir, 'ArduinoServer'), 'dir')
                       rmdir(fullfile(tempdir, 'ArduinoServer'), 's');
                   end
               catch % only attempt to delete the temp folder and not throw any error
               end
               setenv('CPATH', obj.CurrentCPath);
               if ispc
                   setenv('PATH', obj.CurrentSystemPath);
               elseif ismac
                   setenv('DYLD_LIBRARY_PATH', obj.CurrentDYLDLibPath);
               end
           end
       end
    end
    
    
    %% Private methods
    methods(Access = private)
        function [missingHeaders, libs] = areLibrariesAvailable(~, buildInfo)
            % Check if to be downloaded libraries' 3P source, e.g the
            % corresponding library folder has been installed in either the
            % IDE libraries folder or the sketch preference location's
            % libraries folder.
            searchDirectories{1} = fullfile(arduinoio.IDERoot, 'libraries');
            cmd = [buildInfo.Programmer, ' --get-pref sketchbook.path'];
            [~, result] = system(cmd);
           fields = textscan(result, '%s', 'delimiter', newline); 
            prefDir = fields{1}{end};
            searchDirectories{2} = fullfile(prefDir, 'libraries');
            
            allInstalledLibraries = '';
            for index = 1:2
                result = dir(searchDirectories{index});
                isSubDir = [result(:).isdir];
                libDirs = {result(isSubDir).name}';
                libDirs(ismember(libDirs,{'.','..'})) = [];
                if ~isempty(libDirs)
                    if isempty(allInstalledLibraries)
                        allInstalledLibraries = strcat(allInstalledLibraries, strjoin(libDirs, ', '));
                    else
                        allInstalledLibraries = [allInstalledLibraries, ', ', strjoin(libDirs, ', ')];  %#ok<AGROW>
                    end
                end
            end
            
            libs = {};
            mheaders = {};
            includedLibs = buildInfo.Libraries;
            includedLibs(ismember(includedLibs,{'I2C','SPI'})) = [];
            for libCount = 1:length(includedLibs)
                headerFile = arduinoio.internal.getDefaultLibraryPropertyValue(includedLibs{libCount}, 'ArduinoLibraryHeaderFiles');
                if ~isempty(headerFile)
                    if ischar(headerFile)
                        headerFile = {headerFile};
                    end
                    headerFile = strrep(headerFile{1}, '\', '/');
                    theLib = strsplit(headerFile, '/');
                    if isempty(strfind(allInstalledLibraries, theLib{1}))
                        libs = [libs, includedLibs{libCount}]; %#ok<AGROW>
                        mheaders = [mheaders, headerFile]; %#ok<AGROW>
                    end
                end
            end
            
            if isempty(libs)
                missingHeaders = '';
            else
                missingHeaders = arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(mheaders, ', ');
            end
        end
        
       function buildInfo = preBuildProcess(obj, buildInfo)
           % Populate all needed fields in buildInfo other than those got from
           % boards.xml
           buildInfo.IDEPath = arduinoio.IDERoot;
           validateIDEPath(obj, buildInfo.IDEPath);
           switch buildInfo.MCU
               case 'cortex-m3'
                   buildInfo.Arch = 'sam';
               case 'cortex-m0plus'
                   buildInfo.Arch = 'samd';
               otherwise
                   buildInfo.Arch = 'avr';
           end
           buildInfo = setProgrammer(obj, buildInfo); % set the Programmer field of buildInfo structure
           buildInfo.SPPKGPath = arduinoio.SPPKGRoot;
           buildInfo.ServerPath = tempdir;
           buildInfo.SketchTemplate = fullfile(arduinoio.SPPKGRoot, 'src', 'ArduinoServer.ino');
           buildInfo.SketchFile = fullfile(tempdir, 'ArduinoServer', 'ArduinoServer.ino');
           
           [mheaders, libs] = areLibrariesAvailable(obj, buildInfo);
           if ~isempty(mheaders)
               obj.localizedError('MATLAB:arduinoio:general:addonLibraryNotInstalled', mheaders, strjoin(libs, ', '));
           end
       end
       
       function generateLibRegistrationHeader(obj, buildInfo)
            % Generate Dynamic.h file to be compiled with other source code to
            % register the libraries
            if ~exist(fullfile(buildInfo.ServerPath, 'ArduinoServer'), 'dir')
                try
                    mkdir(fullfile(buildInfo.ServerPath, 'ArduinoServer'));
                catch
                    obj.localizedError('MATLAB:hwshared:general:noWritePermission');
                end
            end
            
            filename = fullfile(buildInfo.ServerPath, 'ArduinoServer', 'LibraryRegistration.h');
            h = fopen(filename, 'w');
            
            contents = '#ifndef LibraryRegistration_h\n#define LibraryRegistration_h\n\n';
            
            for libCount = 1:length(buildInfo.Libraries)
                headerFile = arduinoio.internal.getDefaultLibraryPropertyValue(buildInfo.Libraries{libCount}, 'CppHeaderFile');
                headerFile = strrep(headerFile, '\', '\\');
                contents = strcat(contents, ['#include "', headerFile, '"\n']);
            end
            
            contents = [contents, '\nMWArduinoClass MWArduino;\n\n'];
            
            for libCount = 1:length(buildInfo.Libraries)
                className = arduinoio.internal.getDefaultLibraryPropertyValue(buildInfo.Libraries{libCount}, 'CppClassName');
                contents = strcat(contents, [className, ' a', className, '(MWArduino); // ID = ', num2str(libCount-1), '\n']);
            end
            
            contents = [contents, '\n#endif\n'];
            
            try
                fwrite(h, sprintf(contents));
            catch
                f2 = strrep(filename, '\', '\\');
                obj.localizedError('MATLAB:hwshared:general:noWritePermission', f2);
            end
            fclose(h);
        end
        
       function generateMacrosIncludeHeader(obj, buildInfo)
            % Generate Dynamic.h file to be compiled with other source code to
            % register the libraries
            filename = fullfile(buildInfo.ServerPath, 'ArduinoServer', 'MacroInclude.h');
            h = fopen(filename, 'w');
            
            contents = [];
            switch buildInfo.ConnectionType
                case arduinoio.internal.ConnectionTypeEnum.Serial
                    type = 'CONNECTION_TYPE_SERIAL';
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    type = 'CONNECTION_TYPE_BLUETOOTH';
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    type = 'CONNECTION_TYPE_WIFI';
            end
            contents = [contents, '\n#define ', type, ' 1\n'];
            if buildInfo.TraceOn
                contents = [contents, '\n#define MW_TRACEON 1\n#define MW_BOARD ', buildInfo.Board, '\n'];
            else
                contents = [contents, '\n#define MW_BOARD ', buildInfo.Board, '\n'];
            end
            
            if ismember(buildInfo.ConnectionType, [arduinoio.internal.ConnectionTypeEnum.Serial, arduinoio.internal.ConnectionTypeEnum.Bluetooth])
                contents = [contents, '\n#define MW_BAUDRATE ', buildInfo.BaudRate, '\n'];
            else % 'wifi'
                switch buildInfo.Encryption
                    case arduinoio.internal.WiFiEncryptionTypeEnum.None
                        contents = [contents, '\n#define WIFI_ENCRYPTION_NONE 1\n'];
                    case arduinoio.internal.WiFiEncryptionTypeEnum.WPA
                        contents = [contents, '\n#define WIFI_ENCRYPTION_WPA 1\n'];
                    case arduinoio.internal.WiFiEncryptionTypeEnum.WEP
                        contents = [contents, '\n#define WIFI_ENCRYPTION_WEP 1\n'];
                end
                contents = [contents, '\n#define MW_PORT '    , num2str(buildInfo.TCPIPPort), '\n'];
                switch buildInfo.Encryption
                    case arduinoio.internal.WiFiEncryptionTypeEnum.None
                        contents = [contents, '\n#define MW_SSID '    , arduinoio.internal.encode(buildInfo.SSID), '\n'];
                    case arduinoio.internal.WiFiEncryptionTypeEnum.WPA
                        contents = [contents, '\n#define MW_SSID '    , arduinoio.internal.encode(buildInfo.SSID), '\n'];
                        contents = [contents, '\n#define MW_PASSWORD ', arduinoio.internal.encode(buildInfo.Password), '\n'];
                    case arduinoio.internal.WiFiEncryptionTypeEnum.WEP
                        contents = [contents, '\n#define MW_SSID '    , arduinoio.internal.encode(buildInfo.SSID), '\n'];
                        contents = [contents, '\n#define MW_KEY ', arduinoio.internal.encode(buildInfo.Key), '\n'];
                        contents = [contents, '\n#define MW_KEYINDEX ', buildInfo.KeyIndex, '\n'];
                end
                if ~isempty(buildInfo.StaticIP)
                    output = strsplit(buildInfo.StaticIP, '.');
                    for index = 1:4
                        contents = [contents, '\n#define MW_STATIC_IP', num2str(index), ' ', output{index}, '\n']; %#ok<AGROW>
                    end
                end
            end
            
            if strcmp(buildInfo.Board, 'Uno')
                % User this macro to determine how much memory to allocate
                % for Adafruit motor shields with stacking. 
                contents = [contents, '\n#define MW_UNO_SHIELDS 1\n'];
            end
            
            try
                fwrite(h, sprintf(contents));
            catch
                f2 = strrep(filename, '\', '\\');
                obj.localizedError('MATLAB:hwshared:general:noWritePermission', f2);
            end
            fclose(h);
        end
        
        function generateMainSketch(obj, buildInfo)
            % Copy ArduinoServer.ino to tempdir with necessary libraries
            % included
            [h, ~] = fopen(buildInfo.SketchTemplate);
            if h < 0
                arduinoio.internal.localizedError('MATLAB:hwshared:general:missingFile', buildInfo.SketchTemplate, 'ML_ARDUINO');
            else
                contents = transpose(fread(h, '*char'));
            end
            fclose(h);
            
            extraCode = '';
            libs = buildInfo.Libraries;
            for libCount = 1:length(libs)
                headerFile = arduinoio.internal.getDefaultLibraryPropertyValue(libs{libCount}, 'ArduinoLibraryHeaderFiles');
                if ~isempty(headerFile)
                    if ischar(headerFile)
                        headerFile = {headerFile};
                    end
                    for index = 1:length(headerFile)
                        theFile = headerFile{index};
                        theFile = strrep(theFile, '\', '/');
                        theFile = strsplit(theFile, '/');
                        extraCode = strcat(extraCode, ['#include "', theFile{2}, '"\n']);
                    end
                end
            end
            contents = strrep(contents, '[additional_include]', extraCode);
            
            switch buildInfo.ConnectionType
                case {arduinoio.internal.ConnectionTypeEnum.Serial, arduinoio.internal.ConnectionTypeEnum.Bluetooth}
                    type = 0;
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    type = 1;
            end
            contents = strrep(contents, '[connection_type]', num2str(type));
            
            h = fopen(buildInfo.SketchFile, 'w');
            try
                fwrite(h, sprintf(contents));
            catch
                f2 = strrep(filename, '\', '\\');
                obj.localizedError('MATLAB:hwshared:general:noWritePermission', f2);
            end
            fclose(h);
        end
        
        function output = getAllLibraryBuildInfo(~, libs, propName)
            % Return combined values for given property name of all given
            % libraries for the given architecture
            output = cell(1, numel(libs));
            for libCount = 1:length(libs)
                theLib = libs{libCount};
                value = arduinoio.internal.getDefaultLibraryPropertyValue(theLib, propName);
                output{libCount} = value;
            end
            output = unique(output);
        end
        
        function [status, result] = buildServer(~, buildInfo)
            if exist(fullfile(buildInfo.ServerPath, 'ArduinoServer', 'MW'), 'dir')
                rmdir(fullfile(buildInfo.ServerPath, 'ArduinoServer', 'MW'), 's');
            end
            buildCmd = [buildInfo.Programmer, ' -v --board ', buildInfo.Package, ':', buildInfo.Arch, ':', buildInfo.BoardName];
            if ~isempty(buildInfo.CPU)
                buildCmd = [buildCmd, ':cpu=', buildInfo.CPU];
            end
            buildCmd = [buildCmd, ' --verify ', buildInfo.SketchFile];
            buildCmd = [buildCmd, ' --pref build.path=', fullfile(buildInfo.ServerPath, 'ArduinoServer', 'MW')];
            [status, result] = system(buildCmd);
        end
        
        function [status, result] = uploadServer(~, buildInfo)
           % Bug in Arduino CLI that upload command does not reuse
           % compiled files from compile command and caused multiple
           % redefinition. Currently workaround is to delete compilation
           % outputs
            if exist(fullfile(buildInfo.ServerPath, 'ArduinoServer', 'MW'), 'dir')
                rmdir(fullfile(buildInfo.ServerPath, 'ArduinoServer', 'MW'), 's');
            end
            uploadCmd = [buildInfo.Programmer, ' -v --board ', buildInfo.Package, ':', buildInfo.Arch, ':', buildInfo.BoardName];
            if ~isempty(buildInfo.CPU)
                uploadCmd = [uploadCmd, ':cpu=', buildInfo.CPU];
            end
            uploadCmd = [uploadCmd, ' --upload ', buildInfo.SketchFile];
            uploadCmd = [uploadCmd, ' --port ', buildInfo.Port];
            uploadCmd = [uploadCmd, ' --pref build.path=', fullfile(buildInfo.ServerPath, 'ArduinoServer', 'MW')];
            [status, result] = system(uploadCmd);
        end
        
        function validateServerSize(~, buildInfo)
            % Check whether the compiled server fits in the flash memory
            % available
            if strcmp(buildInfo.Arch, 'avr')
                executableFile = fullfile(tempdir, 'ArduinoServer', 'MW', 'ArduinoServer.ino.hex');
                sizer = fullfile(arduinoio.IDERoot, 'hardware', 'tools', 'avr', 'bin', 'avr-size');
                [~, result] = system([sizer, ' ', executableFile]);
                fields = textscan(result, '%s', 'delimiter', newline); fields = fields{1}{end};
                fields = textscan(fields, '%s');
                currentSize = fields{1}(2);
            else % SAM
                sizer = 'ls -al';
                executableFile = fullfile(tempdir, 'ArduinoServer', 'MW', 'ArduinoServer.ino.bin');
                [~, result] = system([sizer, ' ', executableFile]);
                fields = textscan(result,'%s');
                currentSize = fields{1}(5);
            end
            if str2double(currentSize) > buildInfo.MemorySize
                arduinoio.internal.localizedError('MATLAB:arduinoio:general:outOfFlashMemory', buildInfo.Board, arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(buildInfo.Libraries, ', '));
            end
        end
    end
end
