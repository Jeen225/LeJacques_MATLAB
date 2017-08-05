classdef (Hidden,Sealed) ResourceManager < arduinoio.internal.BaseClass
    %   RESOURCEMANAGER Manages resources based on board type
    
    %   Copyright 2014-2016 The MathWorks, Inc.
    
    properties (SetAccess = private, GetAccess = {?arduino,?arduinoio.accessor.UnitTest})
        Board
        BoardName
        Package
        CPU
        MemorySize
        BaudRate
        MCU
        VIDPID
        NumTerminals
        TerminalsDigital
        TerminalsAnalog
        TerminalsDigitalAndAnalog
        TerminalsPWM
        TerminalsServo
        TerminalsI2C
        TerminalsInterrupt
        ICSPSPI
        TerminalsSPI
        
        % Wait time for serial initialization on board
        InitTimeout
        
        AnalogPinModes
        DigitalPinModes
        
        % Array struture of terminals (absolute pin numbers) used to track
        % status of each resource.
        Terminals
        
        ResourceMap
    end
    
    methods
        function obj = ResourceManager(boardType)
            b = arduinoio.internal.BoardInfo.getInstance();
            try
                boardType = validatestring(boardType, {b.Boards.Name});
            catch e
                switch (e.identifier)
                    case 'MATLAB:ambiguousStringChoice'
                        matches = strfind(lower({b.Boards.Name}), lower(boardType));
                        matchedBoards = {};
                        for ii = 1:numel(matches)
                            if ~isempty(matches{ii}) && matches{ii}(1)==1
                                matchedBoards = [matchedBoards, b.Boards(ii).Name]; %#ok<AGROW>
                            end
                        end
                        obj.localizedError('MATLAB:arduinoio:general:ambiguousBoardName', boardType, strjoin(matchedBoards, ', '));
                    otherwise
                        obj.localizedError('MATLAB:arduinoio:general:invalidBoardName', boardType, ...
                            arduinoio.internal.renderCellArrayOfCharVectorsToCharVector({b.Boards.Name}, ', '));
                end
            end
            idx = find(arrayfun(@(x) strcmp(x.Name, boardType), b.Boards), 1);
            if isempty(idx)
                obj.localizedError('MATLAB:arduinoio:general:invalidBoardName', boardType, ...
                            arduinoio.internal.renderCellArrayOfCharVectorsToCharVector({b.Boards.Name}, ', '));
            end
            
            obj.Board            = b.Boards(idx).Name;
            obj.BoardName        = b.Boards(idx).BoardName;
            obj.Package          = b.Boards(idx).Package;
            obj.CPU              = b.Boards(idx).CPU;
            obj.MemorySize       = b.Boards(idx).MemorySize;
            obj.BaudRate         = b.Boards(idx).BaudRate;
            obj.MCU              = b.Boards(idx).MCU;
            obj.VIDPID           = b.Boards(idx).VIDPID;
            obj.NumTerminals     = b.Boards(idx).NumPins;
            obj.TerminalsDigital = b.Boards(idx).PinsDigital;
            obj.TerminalsAnalog  = b.Boards(idx).PinsAnalog;
            obj.TerminalsDigitalAndAnalog = intersect(obj.TerminalsDigital, obj.TerminalsAnalog);
            obj.TerminalsAnalog  = setdiff(obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog);
            obj.TerminalsPWM     = b.Boards(idx).PinsPWM;
            obj.TerminalsServo   = b.Boards(idx).PinsServo;
            obj.TerminalsI2C     = b.Boards(idx).PinsI2C;
            obj.TerminalsInterrupt= b.Boards(idx).PinsInterrupt;
            obj.ICSPSPI          = b.Boards(idx).ICSPSPI;
            obj.TerminalsSPI     = b.Boards(idx).PinsSPI;
            obj.InitTimeout      = b.Boards(idx).InitTimeout;
            
            % Define a structure for terminal data
            terminals.Mode = 'Unset';
            terminals.ResourceOwner = '';
            
            % Arduino pins are zero based. Use the getTerminalMode() method to
            % access this array with correct pin indexing.
            %
            obj.Terminals = repmat(terminals, 1, obj.NumTerminals);
            obj.Terminals(1).Mode = 'Rx';
            obj.Terminals(2).Mode = 'Tx';
            
            if isTerminalAnalog(obj, obj.TerminalsI2C(1))
                obj.AnalogPinModes = {'DigitalInput', 'AnalogInput', 'DigitalOutput', 'Pullup', 'I2C', 'Unset'};
                obj.DigitalPinModes = {'DigitalInput', 'DigitalOutput', 'Pullup', 'PWM', 'Servo', 'SPI', 'Interrupt', 'Unset'};
            else
                obj.AnalogPinModes = {'DigitalInput', 'AnalogInput', 'DigitalOutput', 'Pullup', 'Unset'};
                obj.DigitalPinModes = {'DigitalInput', 'DigitalOutput', 'Pullup', 'PWM', 'Servo', 'SPI', 'I2C', 'Interrupt', 'Unset'};
            end
            % Special cases 
            switch obj.MCU
                case 'atmega32u4'
                    % Some Micro and Lenoard digital pins can be analog(aliasing)
                    obj.DigitalPinModes = ['AnalogInput', obj.DigitalPinModes];
                case 'cortex-m3'
                    obj.AnalogPinModes = ['Interrupt', obj.AnalogPinModes];
                case 'cortex-m0plus'
                    obj.AnalogPinModes = ['Interrupt', 'PWM', obj.AnalogPinModes];
                    % D0 and D1 are not used by USB over CDC for host client communication
                    obj.Terminals(1).Mode = 'Unset';
                    obj.Terminals(2).Mode = 'Unset';
            end
            
            % ResourceMap
            obj.ResourceMap = containers.Map;
        end
    end
    
    %% Friend methods
    %
    %
    methods (Access = {?arduino, ?arduinoio.setup.internal.HardwareInterface, ?arduinoio.internal.TabCompletionHelper, ?arduinoio.accessor.UnitTest})
        
        function varargout = configurePin(obj, pin, resourceOwner, mode, forceConfig, isI2CUsed)            
            % Work with absolute microcontroller pin numbers (terminals)
            terminal = getTerminalsFromPins(obj, pin);
            
            if nargout > 0
                if nargin ~= 2
                    error('Internal Error: configurePin invalid number of input arguments');
                end
                terminal = validateTerminalSupportsTerminalMode(obj, terminal, 'Unset');
                varargout = {obj.getTerminalMode(terminal)};
                return;
            end
            
            if nargin < 6
                isI2CUsed = false;
            end
            
            %% Validate input parameter types
            % accept string type mode but convert to character vector
            if isstring(mode)
                mode = char(mode);
            end
            terminal = validateTerminalSupportsTerminalMode(obj, terminal, mode);
            mode = validateTerminalMode(obj, isTerminalDigital(obj, terminal), mode);
            try
                validateattributes(forceConfig, {'logical'}, {'scalar'});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidForceConfig');
            end
            
            try
                validateattributes(resourceOwner, {'char', 'string'}, {'scalartext'});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidResourceOwnerType');
            end
            % accept string type resourceOwner but convert to character vector
            if isstring(resourceOwner)
                resourceOwner = char(resourceOwner);
            end
            
            %% Only the resource owner may make changes to a terminal configuration.
            resourceOwner = obj.validateResourceOwner(terminal, resourceOwner, mode);
            
            %% Special case - SPI
            % configurePin cannot change a pin's mode from SPI to
            % anything else if SPI objects exists in MATLAB
            prevMode = obj.getTerminalMode(terminal);
            if strcmp(prevMode, 'SPI')
                spiTerminals = getSPITerminals(obj);
                if ismember(terminal, spiTerminals) && ~strcmp(prevMode, mode) && getResourceCount(obj, 'SPI')
                    pin = obj.getPinsFromTerminals(terminal);
                    obj.localizedError('MATLAB:arduinoio:general:reservedSPIPins', obj.Board, pin{1});
                end
            end
            
            %% Check if the terminal is already in the requested target mode
            if strcmp(prevMode, mode)
                obj.updateResource(terminal, resourceOwner, mode);
                return;
            end
            
            %% Validate terminal mode conversion is compatible with previous
            % terminal mode
            if ~forceConfig
                obj.validateCompatibleTerminalModeConversion(terminal, mode);
            end
            
            %% Validate terminal mode conversion rules
            obj.validateTerminalConversionRules(terminal, mode, isI2CUsed);
            
            % Apply new terminal mode (if applicable)
            obj.applyFilterTerminalModeChange(terminal, resourceOwner, mode, forceConfig);
        end
        
        function buildInfo = getBuildInfo(obj)
            buildInfo.Board         = obj.Board;
            buildInfo.BoardName     = obj.BoardName;
            buildInfo.Package       = obj.Package;
            buildInfo.CPU           = obj.CPU;
            buildInfo.MemorySize    = obj.MemorySize;
            buildInfo.BaudRate      = num2str(obj.BaudRate);
            buildInfo.MCU           = obj.MCU;
            buildInfo.VIDPID        = obj.VIDPID;
            buildInfo.InitTimeout   = obj.InitTimeout;
        end
        
        function value = getTerminalMode(obj, terminal)
            % Arduino terminal numbers are zero based
            validateTerminalFormat(obj, terminal);
            value = obj.Terminals(terminal+1).Mode;
        end
        
        function resourceOwner = getResourceOwner(obj, terminal)
            validateTerminalFormat(obj, terminal);
            
            resourceOwner = '';
            r = obj.Terminals(terminal+1).ResourceOwner;
            if ~isempty(r)
                resourceOwner = r;
            end
        end
        
        %% Return true or false indicating whether given terminal supports special functionality
        function result = isTerminalAnalog(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, union(obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog));
        end
        
        function result = isTerminalDigital(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, union(obj.TerminalsDigital, obj.TerminalsDigitalAndAnalog));
        end
        
        %% Get equivalent pin
        function output = getPinAlias(obj, pin)
            % Convert given pin to its equivalent pin if exists. Otherwise,
            % same pin number is returned.
            %
            
            terminal = getTerminalsFromPins(obj, pin);
            if ismember(terminal, obj.TerminalsDigitalAndAnalog)
                if strcmp(pin(1), 'A')
                    tAnalogPins = [obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog];
                    if isTerminalDigital(obj, tAnalogPins(str2double(pin(2:end))+1))
                        output = getPinsFromTerminals(obj, tAnalogPins(str2double(pin(2:end))+1));
                        output = output{1};
                    else
                        output = pin;
                    end
                else
                    tAnalogPins = [obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog];
                    output = find(tAnalogPins == terminal, 1);
                    if ~isempty(output)
                        output = ['A' num2str(output-1)];
                    else
                        output = pin;
                    end
                end
            else
                output = pin;
            end
        end
        
        %% Conversions between pins and terminals       
        function pins = getPinsFromTerminals(obj, terminals)
            if ~isempty(terminals)
                pins = cell(1, length(terminals));
                for index = 1:length(terminals)
                    theTerminal = terminals(index);
                    validateTerminalFormat(obj, theTerminal);
                    if ismember(theTerminal, obj.TerminalsDigital)
                        pins{index} = strcat('D', num2str(theTerminal));
                    elseif ismember(theTerminal, obj.TerminalsAnalog)
                        pins{index} = strcat('A', num2str(theTerminal-obj.TerminalsAnalog(1)));
                    end
                end
            else
                obj.localizedError('MATLAB:arduinoio:general:invalidTerminalType');
            end
        end
        
        function terminals = getTerminalsFromPins(obj, pins)
            % accept array of strings type pins, e.g [string('A3'), string('D4')]
            if isstring(pins) && length(pins) > 1
                pins = cellstr(pins);
            end
            if ~iscell(pins)
                pins = {pins};
            else
                terminals = zeros(numel(pins), 1);
            end
            for ii = 1:numel(pins)
                pin = pins{ii};
                
                try
                    pin = validatePinFormat(obj, pin);
                catch e
                    throwAsCaller(e);
                end
                
                subsystem = pin(1);
                pin = str2double(pin(2:end));
                
                if subsystem == 'D'
                    if ismember(pin, obj.TerminalsDigital)
                        terminal = pin;
                    else
                        validPins = getPinsFromTerminals(obj, [obj.TerminalsDigital, obj.TerminalsAnalog]);
                        obj.localizedError('MATLAB:arduinoio:general:invalidPinNumber', obj.Board, strjoin(validPins, ', '));
                    end
                else
                    try
                        analogTerminals = obj.TerminalsAnalog;
                        if strcmp(obj.MCU, 'atmega32u4')
                            analogTerminals = [obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog];
                        end
                        terminal = analogTerminals(pin + 1);
                    catch
                        validPins = getPinsFromTerminals(obj, [obj.TerminalsDigital, obj.TerminalsAnalog]);
                        obj.localizedError('MATLAB:arduinoio:general:invalidPinNumber', obj.Board, strjoin(validPins, ', '));
                    end
                end
                terminals(ii) = terminal;
            end
        end

        %% Obtain terminals with special functionality
        function terminals = getI2CTerminals(obj, bus)
            if nargin < 2
                bus = 0;
            else 
                try 
                    validateattributes(bus, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidI2CBusType');
                end
            end
            busNum = numel(obj.TerminalsI2C)/2;
            buses = 0:busNum-1;
            if bus > busNum-1
                obj.localizedError('MATLAB:arduinoio:general:invalidI2CBusNumber', obj.Board, arduinoio.internal.renderArrayOfIntsToCharVector(buses));
            end
            terminals = obj.TerminalsI2C(2*bus+1:2*bus+2);
        end
        
        function terminals = getSPITerminals(obj)
            if isempty(obj.ICSPSPI) && isempty(obj.TerminalsSPI)
                obj.localizedError('MATLAB:arduinoio:general:notSupportedInterface', 'SPI', obj.Board);
            else
                terminals = obj.TerminalsSPI;
            end
        end
        
        function terminals = getServoTerminals(obj)
            terminals = obj.TerminalsServo;
        end
        
        function terminals = getPWMTerminals(obj)
            terminals = obj.TerminalsPWM;
        end
        
        function terminals = getInterruptTerminals(obj)
            terminals = obj.TerminalsInterrupt;
        end

        function validateTerminalType(obj, type) 
            supportedTypes = {'servo', 'spi', 'i2c', 'pwm', 'analog', 'digital', 'interrupt'};
            try
                validatestring(lower(type), supportedTypes);
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidValidateType', strjoin(supportedTypes, ', '));
            end
        end
        
        %% Return false when given terminal does not support the special functionality 
        function result = validateTerminal(obj, terminal, type)
            validateTerminalFormat(obj, terminal);
            validateTerminalType(obj, type);
            
            switch lower(type)
                case 'digital'
                    result = validateDigitalTerminal(obj, terminal, 'unset');
                case 'analog'
                    result = validateAnalogTerminal(obj, terminal, 'unset');
                case 'pwm'
                    result = validatePWMTerminal(obj, terminal);
                case 'i2c'
                    result = validateI2CTerminal(obj, terminal);
                case 'spi'
                    result = validateSPITerminal(obj, terminal);
                case 'servo'
                    result = validateServoTerminal(obj, terminal);
                case 'interrupt'
                    result = validateInterruptTerminal(obj, terminal);
                otherwise
             end
        end 
        
        %% Resource Count Methods
        function count = incrementResourceCount(obj, resourceName)
            resourceName = validateResourceNameType(obj, resourceName);
            
            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if ~isfield(resource, 'Count')
                    resource.Count = 1;
                else
                    resource.Count = resource.Count + 1;
                end
            else
                resource.Count = 1;
            end
            count = resource.Count;
            obj.ResourceMap(resourceName) = resource;
        end
        
        function count = decrementResourceCount(obj, resourceName)
            resourceName = validateResourceNameType(obj, resourceName);
            
            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if isfield(resource, 'Count')
                    if resource.Count == 0
                        obj.localizedError('MATLAB:arduinoio:general:resourceCountZero');
                    else
                        resource.Count = resource.Count - 1;
                        count = resource.Count;
                        obj.ResourceMap(resourceName) = resource;
                    end
                else % If resourceName exists but Count does not
                    obj.localizedError('MATLAB:arduinoio:general:resourceCountZero');
                end
            else
                obj.localizedError('MATLAB:arduinoio:general:invalidResourceName', arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(keys(obj.ResourceMap), ', '));
            end
        end
        
        function count = getResourceCount(obj, resourceName)
            resourceName = validateResourceNameType(obj, resourceName);
            
            count = 0;
            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if ~isfield(resource, 'Count')
                    return;
                end
                count = resource.Count;
            else
                obj.ResourceMap(resourceName) = struct;
            end
        end
        
        %% Resource Slot Methods
        function slot = getFreeResourceSlot(obj, resourceName)
            resourceName = validateResourceNameType(obj, resourceName);
            
            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if ~isfield(resource, 'Slot')
                    slot = 1;
                    resource.Slot(slot) = true;
                    obj.ResourceMap(resourceName) = resource;
                    return;
                end
                for slot = 1:numel(resource.Slot)
                    if resource.Slot(slot) ==  false
                        resource.Slot(slot) = true;
                        obj.ResourceMap(resourceName) = resource;
                        return;
                    end
                end
                slot = numel(resource.Slot) + 1;
                resource.Slot(slot) = true;
                obj.ResourceMap(resourceName) = resource;
                return;
            end
            
            slot = 1;
            resource.Slot(slot) = true;
            obj.ResourceMap(resourceName) = resource;
        end
        
        function clearResourceSlot(obj, resourceName, slot)
            resourceName = validateResourceNameType(obj, resourceName);
            
            try
                validateattributes(slot, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative'});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidSlotType');
            end
            
            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                if ~isfield(resource, 'Slot') % If resourceName exists but Slot does not
                    beginSlot = 1;
                    resource.Slot(beginSlot) = true;
                end
                if slot > 0 && slot <= numel(resource.Slot)
                    resource.Slot(slot) = false;
                    obj.ResourceMap(resourceName) = resource;
                else
                    slots = 1:numel(resource.Slot);
                    obj.localizedError('MATLAB:arduinoio:general:invalidSlotNumber', arduinoio.internal.renderArrayOfIntsToCharVector(slots));
                end
            else
                obj.localizedError('MATLAB:arduinoio:general:invalidResourceName', arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(keys(obj.ResourceMap), ', '));
            end
        end
        
        function setSharedResourceProperty(obj, resourceName, propertyName, propertyValue)
            resourceName = validateResourceNameType(obj, resourceName);
            
            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
            end
            
            propertyName = validatePropertyNameType(obj, propertyName);
            
            resource.(propertyName) = propertyValue;
            obj.ResourceMap(resourceName) = resource;
        end
        
        function value = getSharedResourceProperty(obj, resourceName, propertyName)
            value = [];
            resourceName = validateResourceNameType(obj, resourceName);
            
            if any(ismember(keys(obj.ResourceMap), resourceName))
                resource = obj.ResourceMap(resourceName);
                
                propertyName = validatePropertyNameType(obj, propertyName);
                
                if isfield(resource, propertyName)
                    value = resource.(propertyName);
                else
                    obj.localizedError('MATLAB:arduinoio:general:invalidPropertyName', arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(fieldnames(resource), ', '));
                end
            else
                obj.localizedError('MATLAB:arduinoio:general:invalidResourceName', arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(keys(obj.ResourceMap), ', '));
            end
        end
        
        function overridePinResource(obj, pin, resourceOwner, mode)
            terminal = getTerminalsFromPins(obj, pin);
            updateResource(obj, terminal, resourceOwner, mode)
        end
    end
    
    %% Private methods
    %
    %
    methods (Access = {?arduinoio.accessor.UnitTest})
        function resourceName = validateResourceNameType(obj, resourceName)
            try
                validateattributes(resourceName, {'char', 'string'}, {'scalartext'});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidResourceNameType');
            end
            % accept string type resourceName but convert to character vector
            if isstring(resourceName)
                resourceName = char(resourceName);
            end
        end
        
        function propertyName = validatePropertyNameType(obj, propertyName)
            try
                validateattributes(propertyName, {'char', 'string'}, {'scalartext'});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidPropertyNameType');
            end
            % accept string type propertyName but convert to character vector
            if isstring(propertyName)
                propertyName = char(propertyName);
            end
        end
        
        function pin = validatePinFormat(obj, pin)
            % accept string input but convert to character vector
            if isstring(pin)
                pin = char(pin);
            end
            
            if ischar(pin) && ~isempty(pin) && ismember(upper(pin(1)), {'A', 'D'})
            else
                obj.localizedError('MATLAB:arduinoio:general:invalidPinType');
            end
            pin = upper(pin);
        end
        
        function validateTerminalFormat(obj, terminal)
            try
                validateattributes(terminal, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan','nonnegative'});
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidTerminalType');
            end
            
            validTerminals = union(obj.TerminalsDigital, obj.TerminalsAnalog);
            if ismember(terminal, validTerminals)
            else
                obj.localizedError('MATLAB:arduinoio:general:invalidTerminalNumber', num2str(terminal), obj.Board, arduinoio.internal.renderArrayOfIntsToCharVector(validTerminals));
            end
        end
        
        function result = isTerminalI2C(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsI2C);
        end
        
        function result = isTerminalSPI(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsSPI);
        end
        
        function result = isTerminalPWM(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsPWM);
        end
        
        function result = isTerminalServo(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsServo);
        end
        
        function result = isTerminalInterrupt(obj, terminal)
            obj.validateTerminalFormat(terminal);
            result = ismember(terminal, obj.TerminalsInterrupt);
        end
        
        function result = validateAnalogTerminal(obj, terminal, mode)
            try
                obj.validateTerminalMode(terminal, mode);
            catch
                % Allow this method to validate the terminal even if mode
                % is invalid
                mode = 'Unset';
            end
            
            validTerminals = obj.TerminalsAnalog;
            switch mode
                case 'i2c'
                    validTerminals = intersect(validTerminals, obj.TerminalsI2C);
                case {'digitalinput','digitaloutput'}
                    if strcmp(obj.MCU, 'atmega328p')
                        validTerminals = validTerminals(validTerminals<20);
                    end
                case 'interrupt'
                    validTerminals = intersect(validTerminals, obj.TerminalsInterrupt);
                otherwise
            end
            
            switch lower(mode)
                case 'unset'
                    pinType = 'analog';
                otherwise
                    pinType = ['analog ' mode];
            end
            
            if ~ismember(terminal, validTerminals)
                validPins = obj.getPinsFromTerminals(validTerminals);
                obj.localizedError('MATLAB:arduinoio:general:invalidPin', ...
                    obj.Board, pinType, strjoin(validPins, ', '));
            end
            result = double(terminal);
        end
        
        function result = validateDigitalTerminal(obj, terminal, mode)
            try
                obj.validateTerminalMode(terminal, mode);
            catch
                % Allow this method to validate the terminal even is mode
                % is invalid
                mode = 'Unset';
            end
            
            validTerminals = obj.TerminalsDigital;
            switch lower(mode)
                case 'pwm'
                    validTerminals = intersect(validTerminals, obj.TerminalsPWM);
                case 'servo'
                    validTerminals = intersect(validTerminals, obj.TerminalsServo);
                case 'i2c'
                    validTerminals = intersect(validTerminals, obj.TerminalsI2C);
                case 'spi'
                    validTerminals = intersect(validTerminals, obj.TerminalsSPI);
                case 'interrupt'
                    validTerminals = intersect(validTerminals, obj.TerminalsInterrupt);
                otherwise
            end
            
            switch lower(mode)
                case 'unset'
                    pinType = 'digital';
                otherwise
                    pinType = ['digital ' mode];
            end
            
            if ~ismember(terminal, validTerminals)
                validPins = obj.getPinsFromTerminals(validTerminals);
                obj.localizedError('MATLAB:arduinoio:general:invalidPin', ...
                    obj.Board, pinType, strjoin(validPins, ', '));
            end
            result = double(terminal);
        end
        
        function result = validateServoTerminal(obj, terminal)
            if ~obj.isTerminalServo(terminal)
                obj.localizedError('MATLAB:arduinoio:general:invalidPin', ...
                    obj.Board, 'servo', strjoin(obj.getPinsFromTerminals(obj.TerminalsServo), ', '));
            end
            result = double(terminal);
        end
        
        function result = validateSPITerminal(obj, terminal)
            if ~obj.isTerminalSPI(terminal)
                if isempty(obj.TerminalsSPI)
                    validTerminals = 'none';
                else
                    validTerminals = strjoin(obj.getPinsFromTerminals(obj.TerminalsSPI), ', ');
                end
                obj.localizedError('MATLAB:arduinoio:general:invalidPin', ...
                    obj.Board, 'SPI', validTerminals);
            end
            result = double(terminal);
        end
        
        function result = validateI2CTerminal(obj, terminal)
            if ~obj.isTerminalI2C(terminal)
                obj.localizedError('MATLAB:arduinoio:general:invalidPin', ...
                    obj.Board, 'I2C', strjoin(obj.getPinsFromTerminals(obj.TerminalsI2C), ', '));
            end
            result = double(terminal);
        end
        
        function result = validatePWMTerminal(obj, terminal)
            if ~obj.isTerminalPWM(terminal)
                obj.localizedError('MATLAB:arduinoio:general:invalidPin', ...
                    obj.Board, 'PWM', strjoin(obj.getPinsFromTerminals(obj.TerminalsPWM), ', '));
            end
            result = double(terminal);
        end
        
        function result = validateInterruptTerminal(obj, terminal)
            if ~obj.isTerminalInterrupt(terminal)
                obj.localizedError('MATLAB:arduinoio:general:invalidPin', ...
                    obj.Board, 'Interrupt', strjoin(obj.getPinsFromTerminals(obj.TerminalsInterrupt), ', '));
            end
            result = double(terminal);
        end
        
        function mode = validateTerminalMode(obj, subsystem, mode)
            % Check if the given mode is a valid mode for the subsystem
            %
            if strcmp(mode, '')
                mode = 'Unset';
            end
            
            % Composit modes
            parentMode = '';
            try
                if contains(mode, '\')
                    k = strfind(mode, '\');
                    kk = k(end);
                    parentMode = mode(1:kk);
                    mode = mode(kk+1:end);
                end
            catch
            end
            
            if subsystem
                subsystem = 'digital';
                validUserPinModes = obj.DigitalPinModes;
                validOtherPinModes = obj.AnalogPinModes;
            else
                subsystem = 'analog';
                validUserPinModes = obj.AnalogPinModes;
                validOtherPinModes = obj.DigitalPinModes;
            end
            
            allValidPinModes = validUserPinModes;
            allValidPinModes{end+1} = 'Reserved';
            try
                mode = validatestring(mode, allValidPinModes);
            catch
                try
                    mode = validatestring(mode, validOtherPinModes);
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidPinMode', ...
                        subsystem, ...
                        arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(validUserPinModes, ', '));
                    return;
                end
                obj.localizedError('MATLAB:arduinoio:general:notSupportedPinMode', ...
                    mode, ...
                    arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(validUserPinModes, ', '));
            end
    
            mode = [parentMode mode];
        end
        
        function result = validateTerminalSupportsTerminalMode(obj, terminal, mode)  
            % writePWMVoltage(a, 'A2', 3)
            % To catch the wrong pin in the above function call and not
            % just throw the error of invalidPinMode, this validation needs
            % to be done first. However, the mode, since not checked yet,
            % needs to be corrected if needed as below
            try 
                mode = validateTerminalMode(obj, isTerminalDigital(obj, terminal), mode);
            catch e
                % When the above validation fails, it is either due to one
                % of the two causes:
                % - 'MATLAB:arduinoio:general:invalidPinMode'
                % mode is not a valid mode for either digital or analog
                % pins
                % - 'MATLAB:arduinoio:general:notSupportedPinMode'
                % mode is a valid mode, but not for the subsystem the
                % terminal belongs to
                % Only change the mode to 'Unset' for the first case such
                % that it is a mode that is supported on all pins to pass
                % this validation
                %
                if strcmp(e.identifier, 'MATLAB:arduinoio:general:invalidPinMode')
                    mode = 'Unset';
                end
            end
            
            validTerminals = [obj.TerminalsDigital, obj.TerminalsAnalog];
            switch mode
                case 'AnalogInput'
                    validTerminals = [obj.TerminalsAnalog, obj.TerminalsDigitalAndAnalog];
                case 'PWM'
                    validTerminals = obj.TerminalsPWM;
                case 'Servo'
                    validTerminals = obj.TerminalsServo;
                case 'I2C'
                    validTerminals = obj.TerminalsI2C;
                case 'SPI'
                    validTerminals = obj.TerminalsSPI;
                case {'DigitalOutput', 'DigitalInput'}
                    if strcmp(obj.MCU, 'atmega328p')
                        validTerminals = validTerminals(validTerminals<20);
                    end
                case 'Interrupt'
                    validTerminals = obj.TerminalsInterrupt;
                otherwise
                    % DigitalInput, DigitalOutput, Pullup, and Unset are supported by all
                    % pins.
            end
            
            switch mode
                case 'Unset'
                    pinType = '';
                otherwise
                    pinType = mode;
            end
            
            if ~ismember(terminal, validTerminals)
                if strcmp(mode, 'SPI') && isempty(validTerminals)
                    validPins = {'none'};
                else
                    validPins = obj.getPinsFromTerminals(validTerminals);
                end
                obj.localizedError('MATLAB:arduinoio:general:invalidPin', obj.Board, pinType, strjoin(validPins, ', '));
            end
            result = double(terminal);
        end
        
        function validateCompatibleTerminalModeConversion(obj, terminal, mode)
            % Digital Pins: I2C, SPI, DigitalInput, Pullup, DigitalOutput, 
            % PWM, Servo, Interrupt, Unset
            %
            % Digital I2C, SPI, Interrupt and Pullup modes cannot be 
            % converted to any other pin modes.
            %
            % Digital Input mode cannot be converted to any other pin modes
            % except for Analog Input if supported on the pin
            %
            % Pullup mode can only be converted to DigitalInput or AnalogInput
            % mode
            %
            % Digital Output, PWM and Servo pin modes are all digital
            % output modes that can be interchanged freely as long as they
            % are all output pins... They cannot be converted to a digital
            % input pin mode.
                        
            % There are no other restrictions on an Unset pin.
            %
            if strcmp(mode, 'Unset')
                return;
            end
            
            currentMode = obj.getTerminalMode(terminal);
            if ~strcmp(mode, currentMode)
                switch(currentMode)
                    case 'I2C'
                        if obj.isTerminalAnalog(terminal)
                            subsystem = 'Analog';
                        else
                            subsystem = 'Digital';
                        end
                        bus = floor((find(obj.TerminalsI2C==terminal)-1)/2);
                        sda = obj.getPinsFromTerminals(obj.TerminalsI2C(1+bus)); sda = sda{1};
                        scl = obj.getPinsFromTerminals(obj.TerminalsI2C(2+bus)); scl = scl{1};
                        obj.localizedError('MATLAB:arduinoio:general:permanentlyReservedI2CPins', ...
                            obj.Board, ...
                            subsystem, ...
                            sda, scl);
                    case {'SPI', 'Servo', 'Interrupt'}
                        pin = obj.getPinsFromTerminals(terminal);
                        obj.localizedError('MATLAB:arduinoio:general:reservedPin', pin{1}, currentMode, mode);
                    case {'DigitalInput', 'AnalogInput'}
                        if ~ismember(mode, {'DigitalInput', 'AnalogInput'}) % Freely change between DigitalInput and AnalogInput
                            pin = obj.getPinsFromTerminals(terminal);
                            obj.localizedError('MATLAB:arduinoio:general:reservedPin', pin{1}, currentMode, mode);
                        end
                    case {'PWM', 'DigitalOutput'}
                        if ~ismember(mode, {'PWM', 'DigitalOutput'}) % Compatible output pins
                            pin = obj.getPinsFromTerminals(terminal);
                            obj.localizedError('MATLAB:arduinoio:general:reservedPin', pin{1}, currentMode, mode);
                        end
                    case {'Pullup'}
                        if ~ismember(mode, {'DigitalInput', 'AnalogInput'}) % Compatible input pins
                            pin = obj.getPinsFromTerminals(terminal);
                            obj.localizedError('MATLAB:arduinoio:general:reservedPin', pin{1}, currentMode, mode);
                        end
                    case {'Reserved'}
                        % Resource owner needs to handle any compatibility issues
                        %
                    otherwise
                        % Unset pins are not reserved
                        %
                end
            end
            
        end
        
        % Terminal conversion rules are hardware limitations that apply
        % regardless of forceConfig flag
        % If I2C pins are in use or have been in use, they cannot be forced
        % changed into other modes
        function validateTerminalConversionRules(obj, terminal, mode, isI2CUsed)
            if isI2CUsed 
                if strcmp(obj.getTerminalMode(terminal), 'I2C') && ~strcmp(mode, 'I2C')
                    if ismember(terminal, obj.TerminalsI2C)
                        bus = ceil(find(obj.TerminalsI2C == terminal)/2)-1;
                        if ismember(terminal, obj.TerminalsAnalog)
                            subsystem = 'analog';
                        else
                            subsystem = 'digital';
                        end
                        sda = obj.getPinsFromTerminals(obj.TerminalsI2C(1+bus)); sda = sda{1};
                        scl = obj.getPinsFromTerminals(obj.TerminalsI2C(2+bus)); scl = scl{1};
                        
                        obj.localizedError('MATLAB:arduinoio:general:permanentlyReservedI2CPins', ...
                            obj.Board, subsystem, sda, scl);
                    end
                end
            end
        end
        
        function applyFilterTerminalModeChange(obj, terminal, resourceOwner, mode, forceConfig)
            % Compatibility has already been verified earlier. Now simply
            % apply the configuration mode changes (except for
            % non-changable modes).
            
            % Example: If the current terminal mode is 'Pullup', reading
            % the terminal should not result in its configuration changing
            % to 'Input'.
            %
            if ~forceConfig
                if strcmp(obj.getTerminalMode(terminal), 'Pullup') && ...
                        ismember(mode, {'DigitalInput', 'AnalogInput'})
                    return;
                end
            end
            
            obj.updateResource(terminal, resourceOwner, mode);
        end
        
        function updateResource(obj, terminal, resourceOwner, mode)
            obj.Terminals(terminal+1).Mode = mode;
            obj.Terminals(terminal+1).ResourceOwner = resourceOwner;
            if strcmp(mode, 'Unset')
                obj.Terminals(terminal+1).ResourceOwner = '';
            end
        end
        
        function newOwner = validateResourceOwner(obj, terminal, resourceOwner, newMode)
            if strcmp(obj.Terminals(terminal+1).Mode, 'Unset')
                % The only time an object may claim a resource is it that
                % resource is in an unset mode
                obj.Terminals(terminal+1).ResourceOwner = resourceOwner;
                newOwner = resourceOwner;
                return;
            end
            
            % Throw an error if resource owners don't match
            if ~strcmp(obj.Terminals(terminal+1).ResourceOwner, resourceOwner)
                if obj.isTerminalAnalog(terminal)
                    subsystem = 'Analog';
                else
                    subsystem = 'Digital';
                end
                pin = obj.getPinsFromTerminals(terminal); pin = pin{1};
                
                resourceOwner = obj.Terminals(terminal+1).ResourceOwner;
                mode = obj.Terminals(terminal+1).Mode;
                
                if strcmp(mode, 'I2C')
                    bus = mod(find(obj.TerminalsI2C==terminal),2)-1;
                    sda = obj.getPinsFromTerminals(obj.TerminalsI2C(1+bus)); sda = sda{1};
                    scl = obj.getPinsFromTerminals(obj.TerminalsI2C(2+bus)); scl = scl{1};
                    obj.localizedError('MATLAB:arduinoio:general:permanentlyReservedI2CPins', ...
                        obj.Board, ...
                        subsystem, ...
                        sda, scl);
                end
                
                if strcmp(resourceOwner, '')
                    obj.localizedError('MATLAB:arduinoio:general:reservedResourceDigitalAnalog', subsystem, pin, mode);
                else
                    obj.localizedError('MATLAB:arduinoio:general:reservedResource', subsystem, pin, resourceOwner, mode);
                end
            else
                % if same resourceOwner, new mode 'Unset' returns the
                % ownership of the resource to Arduino automatically
                if strcmp(newMode, 'Unset')
                    newOwner = '';
                else
                    newOwner = resourceOwner;
                end
            end
        end
    end
end

