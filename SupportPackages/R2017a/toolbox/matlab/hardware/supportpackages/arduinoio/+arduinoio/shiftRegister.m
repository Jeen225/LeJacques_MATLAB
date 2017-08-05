classdef shiftRegister < arduinoio.LibraryBase & matlab.mixin.CustomDisplay & dynamicprops
    %SHIFTREGISTER Create a shift register object.
    %
    % register = shiftRegister(a, model, dataPin, clockPin, ...) creates a shift register object.
    
    % Copyright 2016 The MathWorks, Inc.
    
    properties(Access = private, Constant = true)
        SHIFT_REGISTER_WRITE       = hex2dec('00')
        SHIFT_REGISTER_READ        = hex2dec('01')
        SHIFT_REGISTER_RESET       = hex2dec('02')
    end
    
    properties(Access = protected, Constant = true)
        LibraryName = 'ShiftRegister'
        DependentLibraries = {}
        ArduinoLibraryHeaderFiles = ''
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'ShiftRegisterBase.h')
        CppClassName = 'ShiftRegisterBase'
    end
    
    properties(SetAccess = private)
        Model
        DataPin
        ClockPin
    end
    
    properties(Access = private, Constant = true)
        SupportedModels = {'74HC165', '74HC595', '74HC164'}
        ModelCodes = struct('MW_74HC165', 1, 'MW_74HC595', 2, 'MW_74HC164', 3)
        AvailableCounts = [8, 16, 24, 32]
        AvailablePrecisions = {'uint8', 'uint16', 'uint32'}
        PrecisionByteSize = struct('uint8', 8, 'uint16', 16, 'uint32', 32)
    end
    
    properties(Access = private)
        ResourceOwner =  'ShiftRegister'
        Undo
    end
    
    methods (Hidden, Access = public)
        function obj = shiftRegister(parentObj, model, dataPin, clockPin, varargin)
            if ~ismember(obj.LibraryName, parentObj.Libraries)
                obj.localizedError('MATLAB:arduinoio:general:libraryNotUploaded', obj.LibraryName);
            end
            narginchk(4, 6);
            obj.Parent = parentObj;
            
            % Validate model
            try
                obj.Model = validatestring(model, obj.SupportedModels);
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegModel', ...
                    ['''', strjoin(obj.SupportedModels, ''', '''), '''']);
            end
            
            % Validate pins
            % 1. validate data pin and clock pin
            dataPin = arduinoio.internal.validateInputPin(dataPin);
            clockPin = arduinoio.internal.validateInputPin(clockPin);
            tmData = getTerminalsFromPins(obj.Parent, dataPin);
            tmClock = getTerminalsFromPins(obj.Parent, clockPin);
            if isTerminalDigital(obj.Parent, tmData) && isTerminalDigital(obj.Parent, tmClock)
                obj.DataPin = upper(dataPin);
                obj.ClockPin = upper(clockPin);
            else
                obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegPin', model);
            end
            % 2. validate other pins depending on model
            switch obj.Model
                case '74HC165'
                    narginchk(6, 6);
                    % validate load pin and clock enable pin
                    loadPin = arduinoio.internal.validateInputPin(varargin{1});
                    clockEnablePin = arduinoio.internal.validateInputPin(varargin{2});
                    tmLoad = getTerminalsFromPins(obj.Parent, loadPin);
                    tmClockEnable = getTerminalsFromPins(obj.Parent, clockEnablePin);
                    if ~isTerminalDigital(obj.Parent, tmLoad) || ~isTerminalDigital(obj.Parent, tmClockEnable)
                        obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegPin', model);
                    end
                    obj.LoadPin = loadPin;
                    obj.ClockEnablePin = clockEnablePin;
                case '74HC595'
                    narginchk(5, 6);
                    % validate latch pin and reset pin
                    latchPin = arduinoio.internal.validateInputPin(varargin{1});
                    tmLatch = getTerminalsFromPins(obj.Parent, latchPin);
                    if ~isTerminalDigital(obj.Parent, tmLatch)
                        obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegPin', model);
                    end
                    obj.LatchPin = latchPin;
                    if nargin == 6
                        resetPin = arduinoio.internal.validateInputPin(varargin{2});
                        tmReset = getTerminalsFromPins(obj.Parent, resetPin);
                        if ~isTerminalDigital(obj.Parent, tmReset)
                            obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegPin', model);
                        end
                        obj.ResetPin = resetPin;
                    end
                case '74HC164'
                    narginchk(4, 5);
                    % validate reset pin
                    if nargin == 5
                        resetPin = arduinoio.internal.validateInputPin(varargin{1});
                        tmReset = getTerminalsFromPins(obj.Parent, resetPin);
                        if isTerminalDigital(obj.Parent, tmReset)
                            obj.ResetPin = resetPin;
                        else
                            obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegPin', model);
                        end
                    end
            end
            
            % Configure pin resources
            iUndo = 0;
            obj.Undo = [];
            if ismember(obj.Model, {'74HC595', '74HC164'})
                configurePinWithUndo(obj.DataPin, obj.ResourceOwner, 'DigitalOutput', false);
            elseif ismember(obj.Model, {'74HC165'})
                configurePinWithUndo(obj.DataPin, obj.ResourceOwner, 'DigitalInput', false);
            end
            configurePinWithUndo(obj.ClockPin, obj.ResourceOwner, 'DigitalOutput', false);
            if isprop(obj, 'LoadPin')
                configurePinWithUndo(obj.LoadPin, obj.ResourceOwner, 'DigitalOutput', false);
            end
            if isprop(obj, 'ClockEnablePin')
                configurePinWithUndo(obj.ClockEnablePin, obj.ResourceOwner, 'DigitalOutput', false);
            end
            if isprop(obj, 'LatchPin')
                configurePinWithUndo(obj.LatchPin, obj.ResourceOwner, 'DigitalOutput', false);
            end
            if isprop(obj, 'ResetPin') && ~isempty(obj.ResetPin)
                configurePinWithUndo(obj.ResetPin, obj.ResourceOwner, 'DigitalOutput', false);
            end
            
            % Nested function that configure pin and also allow reverting
            % them back in case configuration fails
            function configurePinWithUndo(pin, resourceOwner, pinMode, forceConfig)
                prevMode = configurePinResource(parentObj, pin);
                iUndo = iUndo + 1;
                obj.Undo(iUndo).Pin = pin;
                obj.Undo(iUndo).ResourceOwner = resourceOwner;
                obj.Undo(iUndo).PinMode = prevMode;
                try
                    configurePinResource(parentObj, pin, resourceOwner, pinMode, forceConfig);
                catch
                    obj.localizedError('MATLAB:arduinoio:general:reservedShiftRegPins', pin, prevMode);
                end
            end
        end
    end
    
    %% Destructor
    methods (Access=protected)
        function delete(obj)
            try
                parentObj = obj.Parent;
                
                if isempty(obj.Undo)
                    % do nothing since constructor fails before configuring
                    % the pins
                else
                    % Construction failed, revert pins back to their
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
    
    methods
        function set.Model(obj, model)
            % Add dynamic properties, e.g pins, depending on the model
            switch model
                case '74HC165'
                    addprop(obj, 'LoadPin');
                    addprop(obj, 'ClockEnablePin');
                case '74HC595'
                    addprop(obj, 'LatchPin');
                    addprop(obj, 'ResetPin');
                case '74HC164'
                    addprop(obj, 'ResetPin');
                otherwise
            end
            obj.Model = model;
        end
    end
    
    % Hide inherited methods we don't want to show.
    methods (Hidden)
        function addprop(obj, prop)
            % provide access to the implementation
            obj.addprop@dynamicprops(prop);
        end
    end
    
    methods(Access = public)
        function dataOut = read(obj, precision)
            %   Read serial data from PISO type shift register.
            %
            %   Syntax:
            %   dataOut = read(register)
            %
            %   Description:
            %   Read serial data from the shift register device
            %
            %   Example:
            %       a = arduino();
            %       register = shiftRegister(a, '74hc165', 'D3', 'D4', 'D5', 'D6');
            %       dataOut = read(register);
            %
            %   Input Arguments:
            %   register  - Shift register (model 74HC165)
            %   precision - Number of bits to read or precision of data (optional, multiple of 8 such as 8, 16 or 'uint8', 'uint16', 'uint32')
            %
            %   Example:
            %       a = arduino();
            %       register = shiftRegister(a, '74hc165', 'D3', 'D4', 'D5', 'D6');
            %       dataOut = read(register, 8);
            %       dataOut = read(register, 'uint8')
            %
            %   Output Argument:
            %   dataOut   - Value(s) read from the register
            %
            %   See also write

            try
                narginchk(1, 2);
                % Only PISO types support read operation
                if ~ismember(obj.Model, {'74HC165'})
                    obj.localizedError('MATLAB:arduinoio:general:unsupportedShiftRegRead', obj.Model);
                end
                
                
                % Validate precision input
                if (nargin < 2)
                    precision = 8;
                    numBits = precision;
                else
                    try
                        if ischar(precision) || isstring(precision)
                            precision = validatestring(precision, obj.AvailablePrecisions);
                            numBits = obj.PrecisionByteSize.(precision);
                        else
                            % If precision is numeric, it has to be a mutiple
                            % of 8, from 8 - 32
                            assert(ismember(precision, obj.AvailableCounts));
                            numBits = precision;
                        end
                    catch
                        obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegReadPrecision', ...
                            arduinoio.internal.renderArrayOfIntsToCharVector(obj.AvailableCounts), ...
                            ['''', strjoin(obj.AvailablePrecisions, ''', '''), '''']);
                    end
                end
                
                commandID = obj.SHIFT_REGISTER_READ;
                numBytes = numBits/8;
                output = sendCommandCustom(obj, commandID, numBytes);
                if ~ischar(precision)
                    dataOut = zeros(1, numBits);
                    % convert array of doubles into 2-D array of 1s or 0s
                    value = dec2bin(output, 8) - '0'; 
                    % convert to double vector starting from MSB
                    for iLoop = 1:numBytes
                        dataOut(8*(iLoop-1)+(1:8)) = value(numBytes-iLoop+1,:);
                    end
                    dataOut = flip(dataOut);
                else
                    dataOut = uint8(output);
                    dataOut = typecast(dataOut, precision);
                    dataOut = double(dataOut);
                end
            catch e
                throwAsCaller(e);
            end
        end
        
        function write(obj, value, precision)
            %   Write serial data to SIPO type shift register.
            %
            %   Syntax:
            %   write(register,value,precision)
            %
            %   Description:
            %   Write data with specified precision to the shift register
            %
            %   Example:
            %       a = arduino();
            %       register = shiftRegister(a, '74hc595', 'D3', 'D4', 'D7');
            %       write(register, 10);
            %       write(register, '00001010')
            %       write(register, [0 1 0 1 0 0 0 0])
            %
            %   Input Arguments:
            %   register  - Shift register
            %   value	  - Data to write to the shift register (double, character vector or string of 1's or 0's, or vector of 1's or 0's)
            %   precision - Precision of data to write to shift register (optional, character vector or string)
            %
            %   Example:
            %       a = arduino();
            %       register = shiftRegister(a, '74hc595', 'D3', 'D4', 'D7');
            %       write(register, 10, 'uint8')
            %       write(register,'00001010', 'uint8');
            %       write(register,[0 1 0 1 0 0 0 0], 'uint8');
            %
            %   See also read, reset
            
            try
                narginchk(2, 3);
                % Only SIPO types support write operation
                if ~ismember(obj.Model, {'74HC595', '74HC164'})
                    obj.localizedError('MATLAB:arduinoio:general:unsupportedShiftRegWrite', obj.Model);
                end
                
                % Validate precision input
                if (nargin < 3)
                    precision = 'uint8';
                    numBits = 8;
                else
                    try
                        precision = validatestring(precision, obj.AvailablePrecisions);
                        numBits = obj.PrecisionByteSize.(precision);
                    catch
                        obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegWritePrecision', ...
                            ['''', strjoin(obj.AvailablePrecisions, ''', '''), '''']);
                    end
                end
                
                % Validate value input
                try
                    % accept string type value but convert to character vector
                    if isstring(value)
                        value = char(value);
                    end
                    if ischar(value)
                        if length(value) ~= numBits
                            obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegWriteNumBits');
                            return
                        end
                        value = bin2dec(value);
                    else
                        validateattributes(value, {'double'}, {'vector', 'integer', 'finite', 'nonnegative'});
                        len = length(value);
                        if len == 1 % scalar
                            % check to see if scalar is within the range of precision
                            value = arduinoio.internal.validateIntArrayParameterRanged('value', value, intmin(precision), intmax(precision));
                        else % vector
                            % check to see if vector length matches with
                            % precision and is consisted of 1's or 0's
                            if len ~= numBits
                                obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegWriteNumBits');
                                return
                            end
                            validateattributes(value, {'double'}, {'vector', 'integer', '<=', 1, '>=', 0});
                            % convert vector of 1 or 0 to double scalar
                            strValue = num2str(flip(value));
                            strValue(isspace(strValue))='';
                            value = bin2dec(strValue);
                        end
                    end
                catch e 
                    if ~ismember(e.identifier, {'MATLAB:arduinoio:general:invalidShiftRegWriteNumBits', ...
                                                'MATLAB:arduinoio:general:invalidShiftRegWriteNumBits'})
                        obj.localizedError('MATLAB:arduinoio:general:invalidShiftRegValue');
                    else
                        throwAsCaller(e);
                    end
                end
                
                value = cast(value, precision);
                value = typecast(value, 'uint8');
                numBytes = numel(value);
                
                commandID = obj.SHIFT_REGISTER_WRITE;
                cmd = [numBytes, value];
                sendCommandCustom(obj, commandID, cmd);
            catch e
                throwAsCaller(e);
            end
        end
        
        function reset(obj)
            %   Clear all outputs of SIPO type shift register.
            %
            %   Syntax:
            %   reset(register)
            %
            %   Description:
            %   Clear all outputs of shift register
            %
            %   Example:
            %       a = arduino();
            %       register = shiftRegister(a, '74hc595', 'D3', 'D4', 'D7', 'D8');
            %       reset(register);
            %
            %   Input Arguments:
            %   register  - Shift register
            %
            %   See also read, write
            
            try
                % Only shift register with non-empty ResetPin support reset
                % operation
                if ~isprop(obj, 'ResetPin')
                    obj.localizedError('MATLAB:arduinoio:general:unsupportedShiftRegReset', obj.Model);
                end
                if isempty(obj.ResetPin)
                    obj.localizedError('MATLAB:arduinoio:general:shiftRegResetPinNotSpecified');
                end
                
                commandID = obj.SHIFT_REGISTER_RESET;
                sendCommandCustom(obj, commandID, []);
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    methods(Access = protected)
        function output = sendCommandCustom(obj, commandID, inputs)
            dataTerminal = getTerminalsFromPins(obj.Parent, obj.DataPin);
            clockTerminal = getTerminalsFromPins(obj.Parent, obj.ClockPin);
            switch obj.Model
                case '74HC165'
                    model = obj.ModelCodes.MW_74HC165;
                    loadTerminal = getTerminalsFromPins(obj.Parent, obj.LoadPin);
                    ceTerminal = getTerminalsFromPins(obj.Parent, obj.ClockEnablePin);
                    inputs = [model, dataTerminal, clockTerminal, loadTerminal, ceTerminal, inputs];
                case '74HC595'
                    model = obj.ModelCodes.MW_74HC595;
                    latchTerminal = getTerminalsFromPins(obj.Parent, obj.LatchPin);
                    if ~isempty(obj.ResetPin)
                        resetTerminal = getTerminalsFromPins(obj.Parent, obj.ResetPin);
                        inputs = [model, dataTerminal, clockTerminal, latchTerminal, 1, resetTerminal, inputs];
                    else
                        inputs = [model, dataTerminal, clockTerminal, latchTerminal, 0, inputs];
                    end
                case '74HC164'
                    model = obj.ModelCodes.MW_74HC164;
                    if ~isempty(obj.ResetPin)
                        resetTerminal = getTerminalsFromPins(obj.Parent, obj.ResetPin);
                        inputs = [model, dataTerminal, clockTerminal, 1, resetTerminal, inputs];
                    else
                        inputs = [model, dataTerminal, clockTerminal, 0, inputs];
                    end
            end
            output = sendCommand(obj, obj.LibraryName, commandID, inputs);
        end
    end
    
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            
            % Display main options   
                    fprintf('           Model: %-15s\n', ['''', obj.Model, '''']);
                    fprintf('         DataPin: %-15s\n', ['''', obj.DataPin, '''']);
                    fprintf('        ClockPin: %-15s\n', ['''', obj.ClockPin, '''']);
            switch obj.Model
                case '74HC165'
                    fprintf('         LoadPin: %-15s\n', ['''', obj.LoadPin, '''']);
                    fprintf('  ClockEnablePin: %-15s\n', ['''', obj.ClockEnablePin, '''']);
                case '74HC595'
                    fprintf('        LatchPin: %-15s\n', ['''', obj.LatchPin, '''']);
                    if isempty(obj.ResetPin)
                    fprintf('        ResetPin: Not specified\n');
                    else
                    fprintf('        ResetPin: %-15s\n', ['''', obj.ResetPin, '''']);
                    end
                case '74HC164'
                    if isempty(obj.ResetPin)
                    fprintf('        ResetPin: Not specified\n');
                    else
                    fprintf('        ResetPin: %-15s\n', ['''', obj.ResetPin, '''']);
                    end
            end
            fprintf('\n');
            
            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end


