classdef i2cdev < arduinoio.LibraryBase & matlab.mixin.CustomDisplay
    %I2CDEV Create an I2C device object.
    %
    % dev = i2cdev(bus, address) creates an I2C device object.
    
    % Copyright 2014-2016 The MathWorks, Inc.
    
    properties(SetAccess = immutable)
        Bus
        Address
    end
    
    properties(Access = private, Constant = true)
        MaxI2CData     = 144
    end
    
    properties(Access = private, Constant = true)
        START_I2C       = hex2dec('00')
        READ            = hex2dec('02')
        WRITE           = hex2dec('03')
        READ_REGISTER   = hex2dec('04')
        WRITE_REGISTER  = hex2dec('05')
        AvailablePrecisions = {'int8', 'uint8', 'int16', 'uint16'}
        SIZEOF = struct('int8', 1, 'uint8', 1, 'int16', 2, 'uint16', 2)
    end
    
    properties(Access = private)
        % I2C pins are sharable pins, hence no owner
        ResourceOwner =  ''
        Undo
    end
    
    properties(Access = protected, Constant = true)
        LibraryName = 'I2C'
        DependentLibraries = {}
        ArduinoLibraryHeaderFiles = 'Wire/Wire.h'
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'I2CBase.h')
        CppClassName = 'I2CBase'
    end
    
    methods (Hidden, Access = public)
        function obj = i2cdev(parentObj, address, varargin)
            % Check if I2C pins exist
            I2CTerminals = parentObj.getI2CTerminals();
            
            if isempty(I2CTerminals)
                arduinoio.internal.localizedError('MATLAB:arduinoio:general:notSupportedInterface', 'I2C', parentObj.Board);
            end
            
            obj.Parent = parentObj;
            
            address = validateAddress(obj, address);
            try
                i2cAddresses = getSharedResourceProperty(parentObj, obj.ResourceOwner, 'i2cAddresses');
            catch
                i2cAddresses = [];
            end
            if ismember(address, i2cAddresses)
                obj.localizedError('MATLAB:arduinoio:general:conflictI2CAddress', ...
                    num2str(address),...
                    dec2hex(address));
            end
            i2cAddresses = [i2cAddresses address];
            setSharedResourceProperty(parentObj, obj.ResourceOwner, 'i2cAddresses', i2cAddresses);
            obj.Address = address;
            
            try
                p = inputParser;
                addParameter(p, 'Bus', 0);
                parse(p, varargin{:});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                    'i2cdev', ...
                    arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
            end
            
            obj.Bus = validateBus(obj, p.Results.Bus);
            
            if strcmp(parentObj.Board, 'Due') && (obj.Bus == 1)
                obj.Pins = [];
            else
                iUndo = 0;
                obj.Undo = [];
            
                sda = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+1)); sda = sda{1};
                scl = parentObj.getPinsFromTerminals(I2CTerminals(obj.Bus*2+2)); scl = scl{1};
                
                try
                    sdaConfig = parentObj.configurePinResource(sda);
                    configurePinWithUndo(sda, obj.ResourceOwner, 'I2C', false);
                catch 
                    obj.localizedError('MATLAB:arduinoio:general:reservedI2CPins', ...
                        parentObj.Board, sda, scl, sda, sdaConfig);
                end

                try
                    sclConfig = parentObj.configurePinResource(scl);
                    configurePinWithUndo(scl, obj.ResourceOwner, 'I2C', false);
                catch 
                    obj.localizedError('MATLAB:arduinoio:general:reservedI2CPins', ...
                        parentObj.Board, sda, scl, scl, sclConfig);
                end
                obj.Pins = {sda, scl};
            end
            
            startI2C(obj);
            try
                obj.Undo = [];
                setSharedResourceProperty(parentObj, 'I2C', 'I2CIsUsed', true);
            catch 
                % if I2C library has been used on server side, I2C pins
                % gets permanently reserved, o/w they can be reverted back
                % to its original states
            end
            
            function configurePinWithUndo(pin, resourceOwner, pinMode, forceConfig)
                prevMode = configurePinResource(parentObj, pin);
                terminal = getTerminalsFromPins(parentObj, pin);
                prevResourceOwner = getResourceOwner(parentObj, terminal);
                iUndo = iUndo + 1;
                obj.Undo(iUndo).Pin = pin;
                obj.Undo(iUndo).ResourceOwner = prevResourceOwner;
                obj.Undo(iUndo).PinMode = prevMode;
                configurePinResource(parentObj, pin, resourceOwner, pinMode, forceConfig);
            end
        end
    end
    
    %% Destructor
    methods (Access=protected)
        function delete(obj)
            try
                parentObj = obj.Parent;
%                 I2CTerminals = parentObj.getI2CTerminals();
                
                i2cAddresses = getSharedResourceProperty(parentObj, obj.ResourceOwner, 'i2cAddresses');
                i2cAddresses(i2cAddresses==obj.Address) = [];
                setSharedResourceProperty(parentObj, obj.ResourceOwner, 'i2cAddresses', i2cAddresses);
                
                if isempty(obj.Undo)
                    % I2C pins reserved permanently
                else
                    % Construction failed, revert I2C pins back to their
                    % original states
                    for idx = 1:numel(obj.Undo)
                        configurePinResource(parentObj, obj.Undo(idx).Pin, obj.Undo(idx).ResourceOwner, obj.Undo(idx).PinMode, true); 
                    end
                end
            catch
                % Do not throw errors on destroy.
                % This may result from an incomplete construction.
            end
        end
    end
    
    methods(Access = public)
        function dataOut = read(obj, count, precision)
            %   Read data from I2C device.
            %
            %   Syntax:
            %   dataOut = read(dev,count,precision)
            %
            %   Description:
            %   Returns the count number of data from the I2C device
            %
            %   Example:
            %       a = arduino();
            %       dev = i2cdev(a, '0x48');
            %       dataOut = read(dev,1);
            %
            %   Input Arguments:
            %   dev       - I2C device
            %   count	  - Number of data to read from the device (double)
            %   precision - Data precision that matches with size of the register on the device (character vector or string)
            %
            %   Example:
            %       a = arduino();
            %       dev = i2cdev(a, '0x48');
            %       dataOut = read(dev,1,'uint16');
            %
            %   Output Argument:
            %   dataOut   - Register value(s) read from the device with the specified data precision
            %
            %   See also write, writeRegister, readRegister
            
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                if (nargin < 3)
                    precision = 'uint8';
                else
                    precision = validatestring(precision, obj.AvailablePrecisions, ...
                        '', 'precision');
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:unrecognizedStringChoice')
                    id = 'MATLAB:arduinoio:general:invalidPrecision';
                    e = MException(id, getString(message(id, strjoin(obj.AvailablePrecisions, ', '))));
                end
                throwAsCaller(e);
            end
            
            try
                arduinoio.internal.validateIntParameterRanged('count', count, 1, floor(obj.MaxI2CData/obj.SIZEOF.(precision)));
            catch
                obj.localizedError('MATLAB:arduinoio:general:maxI2CData');
            end
            numBytes = uint8(count * obj.SIZEOF.(precision));
            
            commandID = obj.READ;
            try
                cmd = numBytes;
                output = sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
                readSuccessFlag = output(1);
                if readSuccessFlag == hex2dec('FF') % error code
                    obj.localizedError('MATLAB:arduinoio:general:unsuccessfulI2CRead', num2str(count), precision);
                else
                    dataOut = uint8(output(2:end));
                    dataOut = typecast(dataOut, precision);
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:arduinoio:general:connectionIsLost');
                elseif strcmp(e.identifier, 'MATLAB:arduinoio:general:connectionIsLost')
                    obj.localizedError('MATLAB:arduinoio:general:communicationLostI2C', num2str(obj.Bus));
                end
                throwAsCaller(e);
            end
        end
        
        function write(obj, dataIn, precision)
            %   Write data to I2C device.
            %
            %   Syntax:
            %   write(dev,dataIn,precision)
            %
            %   Description:
            %   Writes the data, dataIn, with the specified precision to the I2C device
            %
            %   Example:
            %       a = arduino();
            %       dev = i2cdev(a, '0x48');
            %       write(dev,[hex2dec('20') hex2dec('51')]);
            %
            %   Input Arguments:
            %   dev       - I2C device
            %   dataIn	  - Data to write to the I2C device (double, character vector,  or string)
            %   precision - Data precision that matches with size of the register on the device (character vector or string)
            %
            %   Example:
            %       a = arduino();
            %       dev = i2cdev(a, '0x48');
            %       write(dev,[hex2dec('20') hex2dec('51')], 'uint16');
            %
            %   See also read, writeRegister, readRegister
            
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                if (nargin < 3)
                    precision = 'uint8';
                else
                    precision = validatestring(precision, obj.AvailablePrecisions, ...
                        '', 'precision');
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:unrecognizedStringChoice')
                    id = 'MATLAB:arduinoio:general:invalidPrecision';
                    e = MException(id, getString(message(id, strjoin(obj.AvailablePrecisions, ', '))));
                end
                throwAsCaller(e);
            end

            try
                if isstring(dataIn)
                    dataIn = char(dataIn);
                end
                if ischar(dataIn)
                    try dataIn = uint8(dataIn); catch, end
                end
                dataIn = arduinoio.internal.validateIntArrayParameterRanged(...
                    'dataIn', dataIn, intmin(precision), intmax(precision));

                dataIn = cast(dataIn, precision);
                dataIn = typecast(dataIn, 'uint8');
                numBytes = uint8(numel(dataIn));

                if numBytes > obj.MaxI2CData
                    obj.localizedError('MATLAB:arduinoio:general:maxI2CData');
                end
            catch e
                throwAsCaller(e);
            end
            
            commandID = obj.WRITE;
            try
                cmd = numBytes;
                tmp = [];
                for ii = 1:numBytes
                    tmp = [tmp; dataIn(ii)]; %#ok<AGROW>
                end
                cmd = [cmd; tmp];
                sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:arduinoio:general:connectionIsLost');
                elseif strcmp(e.identifier, 'MATLAB:arduinoio:general:connectionIsLost')
                    obj.localizedError('MATLAB:arduinoio:general:communicationLostI2C', num2str(obj.Bus));
                end
                throwAsCaller(e);
            end
        end
        
        function out = readRegister(obj, register, precision)
            %   Read from register on I2C device.
            %
            %   Syntax:
            %   out = readRegister(dev,register,precision)
            %
            %   Description:
            %   Returns data with specified precision from the register on the I2C device
            %
            %   Example:
            %       a = arduino();
            %       dev = i2cdev(a, '0x48');
            %       value = readRegister(dev,hex2dec('20'));
            %
            %   Input Arguments:
            %   dev       - I2C device
            %   register  - Address of the register on the I2C device (double, character vector, or string)
            %   precision - Data precision that matches with size of the register on the device (character vector or string)
            %
            %   Example:
            %       a = arduino();
            %       dev = i2cdev(a, '0x48');
            %       value = readRegister(dev,hex2dec('20'),'uint16');
            %
            %   Output Argument:
            %   out  - Value of the register with the specified data precision
            %
            %   See also read, write, writeRegister
            
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                if ischar(register) || isstring(register)
                    register = hex2dec(register);
                end
                arduinoio.internal.validateIntParameterRanged('register', register, 0, 255);
                if (nargin < 3)
                    precision = 'uint8';
                else
                    precision = validatestring(precision, obj.AvailablePrecisions, ...
                        '', 'precision');
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:unrecognizedStringChoice')
                    id = 'MATLAB:arduinoio:general:invalidPrecision';
                    e = MException(id, getString(message(id, strjoin(obj.AvailablePrecisions, ', '))));
                elseif strcmp(e.identifier, 'MATLAB:hex2dec:IllegalHexadecimal')
                    id = 'MATLAB:arduinoio:general:invalidRegisterValue';
                    e = MException(id, getString(message(id)));
                end
                throwAsCaller(e);
            end
            numBytes = obj.SIZEOF.(precision);
            
            register = uint8(register);
            
            commandID = obj.READ_REGISTER;
            try
                cmd = [register; numBytes];
                output = sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
                readSuccessFlag = output(1);
                if readSuccessFlag == hex2dec('FF') % error code
                    obj.localizedError('MATLAB:arduinoio:general:unsuccessfulI2CReadRegister', precision, dec2hex(register));
                else
                    % Little endian
                    out = uint8(output(end:-1:2));
                    out = typecast(out, precision);
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:arduinoio:general:connectionIsLost');
                elseif strcmp(e.identifier, 'MATLAB:arduinoio:general:connectionIsLost')
                    obj.localizedError('MATLAB:arduinoio:general:communicationLostI2C', num2str(obj.Bus));
                end
                throwAsCaller(e);
            end
        end
        
        function writeRegister(obj, register, dataIn, precision)
            %   Write to register on I2C device.
            %
            %   Syntax:
            %   writeRegister(dev,register,dataIn,precision)
            %
            %   Description:
            %   Writes data, dataIn, with specified precision to the register on the I2C device
            %
            %   Example:
            %       a = arduino();
            %       dev = i2cdev(a, '0x48');
            %       writeRegister(dev,hex2dec('20'),10);
            %
            %   Input Arguments:
            %   dev       - I2C device
            %   register  - Address of the register on the I2C device (double, character vector, or string)
            %   dataIn	  - Data to write to the register (double, character vector, or string)
            %   precision - Data precision that matches with size of the register on the device (character vector or string)
            %
            %   Example:
            %       a = arduino();
            %       dev = i2cdev(a, '0x48');
            %       writeRegister(dev,hex2dec('20'),10,'uint16');
            %
            %   See also read, write, readRegister
            
            try
                if (nargin < 3)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                if ischar(register) || isstring(register)
                    register = hex2dec(register);
                end
                arduinoio.internal.validateIntParameterRanged('register', register, 0, 255);
                if (nargin < 4)
                    precision = 'uint8';
                else
                    precision = validatestring(precision, obj.AvailablePrecisions, ...
                        '', 'precision');
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:unrecognizedStringChoice')
                    id = 'MATLAB:arduinoio:general:invalidPrecision';
                    e = MException(id, getString(message(id, strjoin(obj.AvailablePrecisions, ', '))));
                elseif strcmp(e.identifier, 'MATLAB:hex2dec:IllegalHexadecimal')
                    id = 'MATLAB:arduinoio:general:invalidRegisterValue';
                    e = MException(id, getString(message(id)));
                end
                throwAsCaller(e);
            end
            
            if isstring(dataIn)
                dataIn = char(dataIn);
            end
            if ischar(dataIn)
                try dataIn = uint8(dataIn); catch, end
            end
            dataIn = arduinoio.internal.validateIntParameterRanged(...
                'dataIn', dataIn, intmin(precision), intmax(precision));
                
            dataIn = cast(dataIn, precision);
            dataIn = typecast(dataIn, 'uint8');
            numBytes = obj.SIZEOF.(precision);
            
            register = uint8(register);
            
            commandID = obj.WRITE_REGISTER;
            try
                cmd = [register; numBytes];
                tmp = [];
                for ii = 1:numBytes
                    % Little endian
                    tmp = [tmp; dataIn(1+numBytes-ii)]; %#ok<AGROW>
                end
                cmd = [cmd; tmp];
                sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:arduinoio:general:connectionIsLost');
                elseif strcmp(e.identifier, 'MATLAB:arduinoio:general:connectionIsLost')
                    obj.localizedError('MATLAB:arduinoio:general:communicationLostI2C', num2str(obj.Bus));
                end
                throwAsCaller(e);
            end
        end
    end
    
    %% Private methods
    methods (Access = private)
        function startI2C(obj)
            commandID = obj.START_I2C;
            try
                cmd = obj.Address;
                sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    methods(Access = protected)
        function output = sendCommandCustom(obj, libName, commandID, inputs)
            if nargin > 3
                inputs = [obj.Bus; obj.Address; inputs];
            else
                inputs = [obj.Bus; obj.Address];
            end
            [output, ~] = sendCommand(obj, libName, commandID, inputs);
        end
        
        function bus = validateBus(obj, bus)
            parentObj = obj.Parent;
            I2CTerminals = parentObj.getI2CTerminals();
            
            if strcmp(parentObj.Board, 'Due')
                numBuses = 0:1;
            else
                numBuses = 0:floor(numel(I2CTerminals)/2)-1;
            end
            
            try
                bus = arduinoio.internal.validateIntParameterRanged('I2C Bus', bus, 0, numBuses(end));
            catch
                numBuses = sprintf('%d, ', numBuses);
                numBuses = numBuses(1:end-2);
                obj.localizedError('MATLAB:arduinoio:general:invalidI2CBusNumber',...
                    parentObj.Board, numBuses);
            end
        end
        
        function addr = validateAddress(obj, address)
            % accept string type address but convert to character vector
            if isstring(address)
                address = char(address);
            end
            if ~ischar(address)
                try
                    addr = arduinoio.internal.validateIntParameterRanged('address', address, 0, 127);
                    return;
                catch
                    printableAddress = false;
                    try
                        printableAddress = (size(num2str(address), 1) == 1);
                    catch
                    end
                    
                    if printableAddress
                        obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddress', num2str(address), num2str(0), num2str(127));
                    else
                        obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddressType');
                    end
                end
                
            else
                tmpAddr = address;
                if strcmpi(tmpAddr(1:2), '0x')
                    tmpAddr = tmpAddr(3:end);
                end
                if strcmpi(tmpAddr(end), 'h')
                    tmpAddr(end) = [];
                end
                
                try
                    dec = hex2dec(tmpAddr);
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddress', address,num2str(0), num2str(127));
                end
                
                if dec < 0 || dec > 127
                    obj.localizedError('MATLAB:arduinoio:general:invalidI2CAddress', address, num2str(0), num2str(127));
                end
            end
            
            addr = dec;
        end
    end
    
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            
            % Display main options
            parentObj = obj.Parent;
            
            if strcmp(parentObj.Board, 'Due') && (obj.Bus == 1)
                fprintf('       Pins: %-15s\n', 'SDA1, SCL1');
            else
                pins = [obj.Pins{1} '(SDA), ' obj.Pins{2} '(SCL)'];
                fprintf('       Pins: %-15s\n', pins);
            end
            
            fprintf('        Bus: %-1d\n', obj.Bus);
            fprintf('    Address: %-1d (0x%02s)\n', obj.Address, dec2hex(obj.Address));
            fprintf('\n');
            
            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end


