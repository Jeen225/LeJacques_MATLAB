classdef rotaryEncoder < arduinoio.LibraryBase & matlab.mixin.CustomDisplay
    %ROTARYENCODER Create a quadrature rotary encoder object.
    %
    % encoder = rotaryEncoder(a, channelA, channelB, ...) creates a quadrature rotary encoder object.
    
    % Copyright 2016 The MathWorks, Inc.
    
    properties(Access = private, Constant = true)
        ATTACH_ENCODER           = hex2dec('01')
        DETACH_ENCODER           = hex2dec('02')
        CHANGE_DELAY             = hex2dec('03')
        READ_ENCODER_COUNT       = hex2dec('04')
        READ_ENCODER_SPEED       = hex2dec('05')
        WRITE_ENCODER_COUNT      = hex2dec('06')
    end
    
    properties(Access = protected, Constant = true)
        LibraryName = 'RotaryEncoder' 
        DependentLibraries = ''
        ArduinoLibraryHeaderFiles = ''
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'RotaryEncoderBase.h')
        CppClassName = 'RotaryEncoderBase'
    end
    
    properties(SetAccess = immutable)
        ChannelA
        ChannelB
        PulsesPerRevolution
    end
        
    properties(Constant, Access = private)
        DecodingType = 'X4'
        % Set measurement interval to be 20ms such that the slowest
        % quadrature signal it can detect at least generates an edge per 
        % 20ms on eith channel A or B, e.g frequency of 1/0.02=50Hz. 
        % Since it is X4 decoding, the slowest frequency of signal on A or
        % B is 50/4=12.5Hz. 
        SpeedMeasureInterval = 0.02 
        ResourceOwner = 'RotaryEncoder'
    end
    
    properties(Access = private)
        Undo
        IsAttached = false
        ID
    end
        
    methods(Hidden, Access = public)
        function obj = rotaryEncoder(parentObj, chA, chB, ppr)
            narginchk(3, 4);
            obj.Parent = parentObj;
            
            % Validate A and B channel format
            try
                chA = arduinoio.internal.validateInputPin(chA);
                chB = arduinoio.internal.validateInputPin(chB);
            catch
                obj.localizedError('MATLAB:arduinoio:general:invalidEncoderChannelType');
            end
            if strcmpi(chA, chB)
                obj.localizedError('MATLAB:arduinoio:general:invalidEncoderChannelPinDuplicate');
            end
            % Validate A and B are interrupt pins
            validTerminals = getInterruptTerminals(parentObj);
            validPins = getPinsFromTerminals(parentObj, validTerminals);
            if ~ismember(chA, validPins) || ~ismember(chB, validPins)
                obj.localizedError('MATLAB:arduinoio:general:invalidEncoderChannelPin', ...
                    parentObj.Board, ['''', strjoin(validPins, ''', '''), '''']);
            end
            
            % Validate A and B are not already used by an existing encoder
            pins = {chA, chB};
            terminals = getTerminalsFromPins(parentObj, pins);
            for index = 1:2
                if strcmp(getResourceOwner(parentObj, terminals(index)), obj.ResourceOwner)
                    obj.localizedError('MATLAB:arduinoio:general:reuseEncoderChannelPin', pins{index});
                end
            end
           
            % Configure pin resources
            iUndo = 0;
            obj.Undo = [];
            try
                configurePinWithUndo(chA, obj.ResourceOwner, 'Interrupt');
            catch
                obj.localizedError('MATLAB:arduinoio:general:reservedPin', chA, configurePin(parentObj, chA), 'Interrupt'); % Should interrupt configure the pin to INPUT?
            end
            try
                configurePinWithUndo(chB, obj.ResourceOwner, 'Interrupt');
            catch
                obj.localizedError('MATLAB:arduinoio:general:reservedPin', chB, configurePin(parentObj, chA), 'Interrupt');
            end
            obj.ChannelA = chA;
            obj.ChannelB = chB;
            
            % Nested function that configure pin and also allow reverting
            % them back in case configuration fails
            function configurePinWithUndo(pin, resourceOwner, pinMode)
                prevMode = configurePinResource(parentObj, pin);
                iUndo = iUndo + 1;
                obj.Undo(iUndo).Pin = pin;
                obj.Undo(iUndo).ResourceOwner = resourceOwner;
                obj.Undo(iUndo).PinMode = prevMode;
                configurePinResource(parentObj, pin, resourceOwner, pinMode, false);
            end
            
            if nargin > 3
                try
                    validateattributes(ppr, {'double'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'positive'});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidEncoderPPRValue')
                end
                obj.PulsesPerRevolution = ppr;
            end
            
            % Assign an ID to the encoder
            obj.ID = getFreeResourceSlot(parentObj, obj.ResourceOwner);
            if ismember(obj.Parent.Board, {'Mega2560','MegaADK','Due'})
                maxEncoders = 2;
            else
                maxEncoders = 1;
            end
            if obj.ID > maxEncoders
                obj.localizedError('MATLAB:arduinoio:general:maxEncoders', parentObj.Board, num2str(maxEncoders));
            end
            
            % Attach encoders to interrupt pins
            attachEncoder(obj);
            obj.IsAttached = true;
        end
    end
    
    methods(Access = protected)
        function delete(obj)
            try
                parentObj = obj.Parent;
                if ~isempty(obj.ID)
                    clearResourceSlot(parentObj, obj.ResourceOwner, obj.ID);
                end
                if obj.IsAttached
                    detachEncoder(obj);
                end
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
    
    methods(Access = private)
        function attachEncoder(obj)
            cmdID = obj.ATTACH_ENCODER;
            data = getTerminalsFromPins(obj.Parent, {obj.ChannelA, obj.ChannelB});
            sendCommandCustom(obj, cmdID, data');
        end
        
        function detachEncoder(obj)
            cmdID = obj.DETACH_ENCODER;
            data = getTerminalsFromPins(obj.Parent, {obj.ChannelA, obj.ChannelB});
            sendCommandCustom(obj, cmdID, data');
        end
    end
    
    methods(Access = public)
        function [count, time] = readCount(obj, varargin)
            %   Read current count from the encoder with X4 decoding.
            %
            %   Syntax:
            %   [count,time] = readCount(encoder)
            %   [count,time] = readCount(encoder,Name,Value)
            %
            %   Description:
            %   Read current count from the quadrature rotary encoder.
            %
            %   Example:
            %       a = arduino();
            %       encoder = rotaryEncoder(a,'D2','D3');
            %       [count,time] = readCount(encoder);
            %
            %   Example:
            %       a = arduino();
            %       encoder = rotaryEncoder(a,'D2','D3');
            %       [count,time] = readCount(encoder,'reset',true);
            %
            %   Input Arguments:
            %   obj   - Quadrature rotary encoder object
            %
            %   Name-Value Pair Input Arguments:
            %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value. 
            %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
            %
            %   NV Pair:
            %   'reset' - Flag indicating whether to reset count to 0 after reading it from encoder (boolean)
            %
            %   Output Argument:
            %   count  - Current encoder count
            %   time   - Time elasped in seconds since Arduino server starts running (double)
            %
            %   See also readSpeed, resetCount
            
            cmdID = obj.READ_ENCODER_COUNT;
            
            try
                try
                    p = inputParser;
                    addParameter(p, 'reset', false, @islogical);
                    parse(p, varargin{:});
                    resetFlag = p.Results.reset;
                catch e
                    if strcmp(e.identifier, 'MATLAB:InputParser:ArgumentFailedValidation')
                        obj.localizedError('MATLAB:arduinoio:general:invalidCountResetValue');
                    else
                        obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName','readCount', '''reset''');
                    end
                end
                output = sendCommandCustom(obj, cmdID, resetFlag);
                % convert to int32 count
                count = typecast(uint8(output(1:4)), 'int32');
                % convert to int8 overflow
                overflow = double(typecast(uint8(output(9)), 'int8'));
                if overflow == 0
                    count = double(count);
                elseif overflow > 0
                    obj.localizedWarning('MATLAB:arduinoio:general:encoderCountOverflow');
                    count = overflow*(int64(intmax)+1)+int64(count);
                else % overflow < 0
                    obj.localizedWarning('MATLAB:arduinoio:general:encoderCountOverflow');
                    count = int64(count)-overflow*(int64(intmin)-1);
                end
                % convert to uint32 time
                time = typecast(uint8(output(5:8)), 'uint32'); 
                time = double(time)/1000;% unsigned long time convert to double and convert to second
            catch e
                throwAsCaller(e);
            end
        end
        
        function rpm = readSpeed(obj)
            %   Read current rotational speed measured by the encoder(s).
            %
            %   Syntax:
            %   rpm = readSpeed(encoder)
            %
            %   Description:
            %   Read current rotational speed measured by the quadrature rotary encoder(s).
            %
            %   Example:
            %       a = arduino();
            %       encoder = rotaryEncoder(a,'D2','D3');
            %       rpm = readSpeed(encoder);
            %
            %   Example:
            %       a = arduino();
            %       encoder1 = rotaryEncoder(a,'D2','D3');
            %       encoder2 = rotaryEncoder(a,'D18','D19');
            %       rpm = readSpeed([encoder1,encoder2]);
            %
            %   Input Arguments:
            %   obj   - Single or vector of quadrature rotary encoder object(s)
            %
            %   Output Argument:
            %   rpm   - Rotational speed in revolution per minute (double or vector of double)
            %
            %   See also readCount, resetCount
           
            try
                cmdID = obj.READ_ENCODER_SPEED;
                numEncoders = length(obj);
                data = zeros(1, numEncoders+1);
                data(1) = numEncoders; % start with number of encoder objects to read
                for index = 1:length(obj)
                    if isempty(obj(index).PulsesPerRevolution)
                        obj.localizedError('MATLAB:arduinoio:general:encoderPPRNotSpecified');
                    end
                    if ~strcmp(obj(index).Parent.Port, obj(1).Parent.Port)
                        obj.localizedError('MATLAB:arduinoio:general:encoderNotSameParent');
                    end
                    data(index+1) = obj(index).ID-1;
                end
                
                output = sendCommandCustom(obj(1), cmdID, data);
                rpm = zeros(1, numEncoders);
                for index = 1:numEncoders
                    value = typecast(uint8(output(3*(index-1)+1)), 'int8');
                    overflowDiff = double(value);
                    value = typecast(uint8(output(3*(index-1)+(2:3))), 'int16');
                    countDiff = double(value);
                    if overflowDiff == 0
                        count = countDiff;
                    elseif overflowDiff < 0 
                        count = int64(countDiff)-overflowDiff*(int64(intmin)-1);
                    else % overflowDiff > 0 
                        count = overflowDiff*(int64(intmax)+1)+int64(countDiff);
                    end
                    value = double(count)/obj(index).SpeedMeasureInterval/(obj(index).PulsesPerRevolution*4)*60;
                    rpm(index) = value;
                end
            catch e
                throwAsCaller(e);
            end
        end
        
        function resetCount(obj, count)
            %   Reset count value on the encoder.
            %
            %   Syntax:
            %   resetCount(encoder)
            %   resetCount(encoder,count)
            %
            %   Description:
            %   Reset count value on the quadrature rotary encoder.
            %
            %   Example:
            %       a = arduino();
            %       encoder = rotaryEncoder(a,'D2','D3');
            %       resetCount(encoder);
            %       resetCount(encoder,10);
            %
            %   Input Arguments:
            %   obj   - Quadrature rotary encoder object
            %   count - Value to reset encoder count to.(optional, double, default 0)
            %
            %   See also readCount, readSpeed
            
            try
                cmdID = obj.WRITE_ENCODER_COUNT;
                
                if nargin < 2
                    count = 0;
                end
                try
                    validateattributes(count, {'double', 'int32'}, {'scalar', 'real', 'integer', 'finite', 'nonnan', '<=', intmax, '>=', intmin});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidEncoderCount', num2str(intmin), num2str(intmax));
                end
                
                data = typecast(int32(count), 'uint8');
                
                sendCommandCustom(obj, cmdID, data);
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    methods(Access = protected)
        function output = sendCommandCustom(obj, commandID, inputs)
            % Change from 1-based indexing in MATLAB to 0-based indexing in C++
            output = sendCommand(obj, obj.LibraryName, commandID, [obj.ID-1, inputs]); 
        end
    end
    
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
                        
            % Display main options
            fprintf('           ChannelA: ''%s''\n', obj.ChannelA);
            fprintf('           ChannelB: ''%s''\n', obj.ChannelB);
            if isempty(obj.PulsesPerRevolution)
            fprintf('PulsesPerRevolution:  []\n');
            else
            fprintf('PulsesPerRevolution: %d\n', obj.PulsesPerRevolution);
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