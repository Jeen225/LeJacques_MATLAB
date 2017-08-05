classdef spidev < arduinoio.LibraryBase & matlab.mixin.CustomDisplay
    %SPIDEV Create a SPI device object.
    %   
    % dev = spidev(address) creates a SPI device object.
    
    % Copyright 2014-2016 The MathWorks, Inc.
    
    properties(SetAccess = immutable)
        ChipSelectPin
    end
    
    properties
        Mode
        BitOrder
        BitRate
    end
    
    properties(Access = private)
        ResourceOwner  = 'SPI'
        Undo
    end
    
    properties(Access = private, Constant = true)
        MaxSPIData     = 144
    end
    
    properties(Access = private, Constant = true)
        START_SPI      = hex2dec('00')
        STOP_SPI       = hex2dec('01')
        SET_BIT_RATE   = hex2dec('02')
        SET_BIT_ORDER  = hex2dec('03')
        SET_MODE       = hex2dec('04')
        WRITE_READ     = hex2dec('05')
        SIZEOF = struct('int8', 1, 'uint8', 1, 'int16', 2, 'uint16', 2, ...
            'int32', 4, 'uint32', 4, 'int64', 8, 'uint64', 8)
    end
    
    properties(Access = protected, Constant = true)
        LibraryName = 'SPI'
        DependentLibraries = {}
        ArduinoLibraryHeaderFiles = 'SPI/SPI.h'
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'SPIBase.h')
        CppClassName = 'SPIBase'
    end
    
    methods(Hidden, Access = public)
        function obj = spidev(parentObj, cspin, varargin)
            % Check if SPI pins exist
            try
                spiTerminals = parentObj.getSPITerminals();
            catch e
                throwAsCaller(e);
            end
            
            count = parentObj.incrementResourceCount(obj.ResourceOwner);
            
            iUndo = 0;
            obj.Undo = [];
            
            try
                cspin = arduinoio.internal.validateInputPin(cspin);
                terminal = getTerminalsFromPins(parentObj, cspin);
                if ~isTerminalDigital(parentObj, terminal)
                    arduinoio.internal.localizedError('MATLAB:arduinoio:general:invalidChipSelectPin', cspin);
                end
            catch e
                throwAsCaller(e)
            end
            
            if cspin(1) == 'A'
                cspin = getPinAlias(parentObj, cspin);
            end
            obj.ChipSelectPin = cspin;
            obj.Parent = parentObj;
            
            spiPins = [];
            if ~isempty(spiTerminals)
                spiPins = parentObj.getPinsFromTerminals(spiTerminals);
            end
            
            % check for pre-reserved pins
            spiPinModes = {'MOSI', 'MISO', 'SCK', 'SS'};
            if ~strcmpi(parentObj.Board, 'MKR1000')&&~isempty(spiPins)&&strcmp(obj.ChipSelectPin, spiPins{end})
                    spiPinsNoSS = spiPins(1:end-1);
            else
                spiPinsNoSS = spiPins;
            end
            reservedPins = [];
            for idx = 1: numel(spiPinsNoSS)
                try
                    configurePinWithUndo(spiPinsNoSS{idx}, '', 'SPI', false);
                catch
                    terminal = getTerminalsFromPins(parentObj, spiPinsNoSS{idx});
                    resourceOwner = getResourceOwner(parentObj, terminal);
                    if (idx ~= numel(spiPinsNoSS)) || ...
                       (idx == numel(spiPinsNoSS) && ~strcmp(prevMode, 'DigitalOutput')) || ...
                       (idx == numel(spiPinsNoSS) && ~strcmp(resourceOwner, obj.ResourceOwner))
                        reservedPins = [reservedPins, idx]; %#ok<AGROW>
                    end
                end
            end
            if ~isempty(reservedPins)
                pinsDescription = '';
                for idx = 1 : numel(reservedPins)
                    pinsDescription = [pinsDescription, ...
                        spiPins{reservedPins(idx)}, ...
                        '(', spiPinModes{idx}, '), ']; %#ok<AGROW>
                end
                pinsDescription(end-1:end) = [];
                obj.localizedError('MATLAB:arduinoio:general:reservedSPIPins',...
                    parentObj.Board, pinsDescription);
            end
            
            % Check for conflict between ChipSelect and SPI pins (MOSI,
            % MISO, SCK, SS)
            if ismember(obj.ChipSelectPin, spiPinsNoSS)
                obj.localizedError('MATLAB:arduinoio:general:conflictSPIPinsCS', ...
                    obj.ChipSelectPin,...
                    spiPinModes{find(ismember(spiPinsNoSS, obj.ChipSelectPin))}); %#ok<FNDSB>
            end
            
            if count == 1
                parentObj.setSharedResourceProperty(obj.ResourceOwner, 'IsSSUsedAsCS', false);
            end
            
            % Chipselect pin setup
            terminal = getTerminalsFromPins(obj.Parent, obj.ChipSelectPin);
            mode = getTerminalMode(obj.Parent, terminal);
            resourceOwner = getResourceOwner(obj.Parent, terminal);
            if strcmp(mode, 'SPI')
                if ~strcmpi(obj.Parent.Board, 'MKR1000') && ~isempty(spiPins) && strcmp(obj.ChipSelectPin, spiPins{end})
                    if strcmp(resourceOwner, '') && parentObj.getSharedResourceProperty(obj.ResourceOwner, 'IsSSUsedAsCS') 
                        % used SS pin
                        obj.localizedError('MATLAB:arduinoio:general:reservedResourceSPI', obj.ChipSelectPin);
                    else
                        configurePinWithUndo(obj.ChipSelectPin, '', 'SPI', false); %Set pinmode
                    end
                else
                    configurePinWithUndo(obj.ChipSelectPin, obj.ResourceOwner, 'DigitalOutput', false); %Set pinmode
                end
            else 
                if strcmp(mode, 'DigitalOutput') && strcmp(resourceOwner, obj.ResourceOwner)
                    obj.localizedError('MATLAB:arduinoio:general:reservedResourceSPI', obj.ChipSelectPin);
                else
                    if ~strcmpi(obj.Parent.Board, 'MKR1000') && ~isempty(spiPins) && strcmp(obj.ChipSelectPin, spiPins{end})
                        configurePinWithUndo(obj.ChipSelectPin, '', 'SPI', false);
                    else
                        configurePinWithUndo(obj.ChipSelectPin, obj.ResourceOwner, 'DigitalOutput', false);
                    end
                end
            end
            
            obj.Pins = spiPins;
            
            % Mode and BitOrder should be only set once in the end to avoid
            % incorrect server call
            try
                p = inputParser;
                addParameter(p, 'Mode', 0);
                addParameter(p, 'BitOrder', 'msbfirst');
                addParameter(p, 'BitRate', 4000000);
                parse(p, varargin{:});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                    'spidev', ...
                    arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(p.Parameters, ', '));
            end
            
            % Validate input parameters
            obj.Mode     = p.Results.Mode;
            obj.BitOrder = p.Results.BitOrder;
            obj.BitRate  = p.Results.BitRate;
            
            startSPI(obj);
            
            obj.Undo = [];
            if ~strcmpi(obj.Parent.Board, 'MKR1000') && ~isempty(spiPins) && strcmp(obj.ChipSelectPin, spiPins(end))
                parentObj.setSharedResourceProperty(obj.ResourceOwner, 'IsSSUsedAsCS', true);
            end
            
            function configurePinWithUndo(pin, resourceOwner, pinMode, forceConfig)
                prevMode = configurePinResource(parentObj, pin);
                terminal = getTerminalsFromPins(parentObj, pin);
                prevResourceOwner = getResourceOwner(parentObj, terminal);
                iUndo = iUndo + 1;
                obj.Undo(iUndo).Pin = pin;
                if strcmp(pin, obj.ChipSelectPin) && ...
                        (~isempty(spiPins) && ~ismember(obj.ChipSelectPin, spiPins)|| ... % if CS is not SS, only using its own resourceOwner can revert back its mode to Unset
                        isempty(spiPins))
                    obj.Undo(iUndo).ResourceOwner = obj.ResourceOwner;
                else
                    obj.Undo(iUndo).ResourceOwner = prevResourceOwner;
                end
                obj.Undo(iUndo).PinMode = prevMode;
                configurePinResource(parentObj, pin, resourceOwner, pinMode, forceConfig);
            end
        end
    end
    
    methods (Access=protected)
        function delete(obj)
            try
                count = decrementResourceCount(obj.Parent, obj.ResourceOwner);
                stopSPI(obj, count);

                parentObj = obj.Parent;
                spiTerminals = parentObj.getSPITerminals();
                if ~isempty(spiTerminals)
                    spiPins = parentObj.getPinsFromTerminals(spiTerminals);
                else
                    spiPins = [];
                end
                % Other than chip select, SPI pins to unconfigure are all 
                % SPI pins excluding SS if it is not an MKR1000 board(no SS
                % pin) and its SPI pins have valid terminal numbers. 
                % Otherwise, other than chip select, SPI pins to unconfigure 
                % are all SPI pins
                if ~strcmpi(obj.Parent.Board, 'MKR1000')&&~isempty(spiPins)&& strcmp(obj.ChipSelectPin, spiPins(end))
                    spiPinsNoSS = spiPins(1:end-1);
                    ssPin = spiPins{end};
                    hasSS = true;
                else
                    spiPinsNoSS = spiPins;
                    hasSS = false;
                end
                
                if isempty(obj.Undo)
                    if count == 0 % last SPIDEV object in workspace
                        % Unconfigure non-SS SPI pins
                        for idx = 1: numel(spiPinsNoSS)
                            configurePinResource(parentObj, spiPinsNoSS{idx}, '', 'Unset');
                        end
                        % Unconfigure CS and/or SS pin
                        if hasSS 
                            if strcmpi(obj.ChipSelectPin, ssPin)
                                configurePinResource(parentObj, obj.ChipSelectPin, '', 'Unset', true);
                                setSharedResourceProperty(parentObj, obj.ResourceOwner, 'IsSSUsedAsCS', false);
                            else
                                if ~isempty(spiPins)
                                    configurePinResource(parentObj, ssPin, '', 'Unset');
                                end
                                configurePinResource(parentObj, obj.ChipSelectPin, obj.ResourceOwner, 'Unset', true);
                            end
                        else
                            configurePinResource(parentObj, obj.ChipSelectPin, obj.ResourceOwner, 'Unset', true);
                        end
                    else % more than one SPIDEV objects in workspace
                        % Unconfigure CS (non-SS) pin
                        if hasSS && strcmpi(obj.ChipSelectPin, ssPin) 
                            setSharedResourceProperty(parentObj, obj.ResourceOwner, 'IsSSUsedAsCS', false);
                        else
                            configurePinResource(parentObj, obj.ChipSelectPin, obj.ResourceOwner, 'Unset');
                        end
                    end
                else
                    % Construction failed, revert any pins back to their
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
        function dataOut = writeRead(obj, dataIn, dataPrecision)
            %   Write and read binary data from SPI device.
            %
            %   Syntax:
            %   dataOut = writeRead(dev,dataIn)
            %   dataOut = writeRead(dev,dataIn,dataPrecision)
            %
            %   Description: Writes the data, dataIn, to the device and reads
            %   the data available, dataOut, from the device as a result of
            %   writing dataIn
            %
            %   dataPrecision - Data Precision 'uint8' (default) | 'uint16'
            %
            %   Example:
            %       a = arduino();
            %       dev = spidev(a, 7);
            %       dataIn = [2 0 0 255];
            %       dataOut = writeRead(dev,dataIn);
            %
            %   Input Arguments:
            %   dev     - SPI device
            %   dataIn  - Data to write to the device (double).
            %
            %   Output Argument:
            %   dataOut - Available data read from the device (double)
            
            commandID = obj.WRITE_READ;
            
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                if nargin < 3
                    castDataOut = false;
                    dataPrecision = 'uint8';
                else
                    castDataOut = true;
                    dataPrecision = validatestring(dataPrecision, {'uint8', 'uint16'});
                end
            catch e
                throwAsCaller(e);
            end
            
            numBytes = obj.SIZEOF.(dataPrecision);
            maxValue = 2^(numBytes*8)-1;
            
            try
                dataIn = arduinoio.internal.validateIntArrayParameterRanged(...
                    'dataIn', dataIn, intmin(dataPrecision), intmax(dataPrecision));
            
                dataInLen = size(dataIn,2);
                if dataInLen*numBytes > obj.MaxSPIData
                    obj.localizedError('MATLAB:arduinoio:general:maxSPIData');
                end
                cmd = uint8(dataInLen*numBytes);
                tmp = [];
                for ii = 1:dataInLen
                    val = arduinoio.internal.validateIntParameterRanged(...
                        ['dataIn(' num2str(ii) ')'], ...
                        dataIn(ii), ...
                        0, ...
                        maxValue);
                    val = cast(val, dataPrecision);
                    val = typecast(val, 'uint8');
                    for jj = 1:numBytes
                        % Little endian
                        tmp = [tmp; val(1+numBytes-jj)]; %#ok<AGROW>
                    end
                end
                
                cmd = [cmd; tmp]; 
                
                % Returned data
                %
                output = sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
                returnedData = output';
                dataOutLen = size(returnedData,2)/numBytes;
                if castDataOut
                    switch numBytes
                        case 1
                            dataOut = uint8(zeros(1, dataOutLen));
                        case 2
                            dataOut = uint16(zeros(1, dataOutLen));
                        case 4
                            dataOut = uint32(zeros(1, dataOutLen));
                        case 8
                            dataOut = uint64(zeros(1, dataOutLen));
                    end
                else
                    dataOut = zeros(1, dataOutLen);
                end
                for ii = 1:dataOutLen
                    returnedDataIdx = ((ii-1)*numBytes)+1;
                    for jj = 1:numBytes
                        dataOut(ii) = dataOut(ii) + ...
                            returnedData(returnedDataIdx + jj - 1) * 2^(8*(numBytes-jj));
                    end
                end
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    methods
        function set.Mode(obj, mode)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end

                mode = arduinoio.internal.validateIntParameterRanged('SPI mode', mode, 0, 3);
                sendCommandCustom(obj, obj.LibraryName, obj.SET_MODE, mode);
                obj.Mode = mode;
            catch e
                throwAsCaller(e);
            end
        end
        
        function set.BitOrder(obj, bitOrder)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
              
                bitOrderValues = {'msbfirst', 'lsbfirst'};
                try
                    bitOrder = validatestring(bitOrder, bitOrderValues);
                    
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyValue',...
                        'SPI', ...
                        'BitOrder', ...
                        arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(bitOrderValues, ', '));
                end
                if strcmp(bitOrder, 'lsbfirst')
                    cmd = 0;
                else
                    cmd = 1;
                end
                sendCommandCustom(obj, obj.LibraryName, obj.SET_BIT_ORDER, cmd);
                obj.BitOrder= bitOrder;
            catch e
                throwAsCaller(e);
            end
        end
        
        function set.BitRate(obj, bitRate)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
              
                try
                    validateattributes(bitRate, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidSPIBitRateType');
                end
                cmd = typecast(uint32(bitRate),'uint8');
                sendCommandCustom(obj, obj.LibraryName, obj.SET_BIT_RATE, cmd');
                obj.BitRate = bitRate;
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    methods (Access = private)
        function startSPI(obj)
            commandID = obj.START_SPI;
            try
                cmd = [];
                sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
            catch e
                throwAsCaller(e);
            end
        end
        
        function stopSPI(obj, count)
            mcu = obj.Parent.getMCU();
            if count > 0 && ~strcmp(mcu, 'cortex-m3')
                % Other SPI devices still exist
                % Atmel MCU's call SPI.end without specifying CS
                % One call is sufficient for all SPI devices.
                %
                return;
            end
            
            commandID = obj.STOP_SPI;
            try
                cmd = [];
                sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    methods(Access = protected)
        function output = sendCommandCustom(obj, libName, commandID, inputs)
            if nargin > 3
                inputs = [str2double(obj.ChipSelectPin(2:end)); inputs];
            else
                inputs = str2double(obj.ChipSelectPin(2:end));
            end
            [output, ~] = sendCommand(obj, libName, commandID, inputs);
        end
    end
    
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            
            parentObj = obj.Parent;
            
            if isempty(obj.Pins)
                if strcmp(parentObj.Board, 'Due')
                    spiPins = 'SPI-4(MOSI), SPI-1(MISO), SPI-3(SCK)';
                else
                    spiPins = 'ICSP-4(MOSI), ICSP-1(MISO), ICSP-3(SCK)';
                end
            else
                spiPinModes = {'MOSI', 'MISO', 'SCK', 'SS'};
                spiPins = [];
                for ii = 1:numel(obj.Pins)
                    spiPins = [spiPins sprintf('%s(%s), ', obj.Pins{ii}, spiPinModes{ii})]; %#ok<AGROW>
                end
                spiPins(end-1:end) = [];
            end
            
            % Display main options
            fprintf('    ChipSelectPin: %s\n', obj.ChipSelectPin);
            fprintf('             Pins: %s\n', spiPins);
            fprintf('             Mode: %-15d (0, 1, 2 or 3)\n', obj.Mode);
            fprintf('         BitOrder: %-15s (''msbfirst'' or ''lsbfirst'')\n', obj.BitOrder');
            fprintf('          BitRate: %-15d (Hz)\n', obj.BitRate);
            fprintf('\n');
                  
            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end
