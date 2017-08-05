classdef (Abstract)ServoMotorBase < arduinoio.LibraryBase

    %   Copyright 2014-2016 The MathWorks, Inc.
    properties(SetAccess = immutable)
        MinPulseDuration
        MaxPulseDuration
    end
    
    properties(Access = private)
        ResourceMode            = 'Servo'
        ResourceOwner           = 'Servo'
        ReservePWMPins
        CountCutOff 
        MaxServos
        IsServoAttached
        DefaultMinPulseDuration = 544e-6
        DefaultMaxPulseDuration = 2400e-6
        ResourceAllocationSuccessFlag = true
    end
    
    properties(Access = private, Constant = true)
        ATTACH_SERVO    = hex2dec('00')
        CLEAR_SERVO     = hex2dec('01')
        READ_POSITION   = hex2dec('02')
        WRITE_POSITION  = hex2dec('03')
    end
    
    properties(Access = protected, Constant = true)
        LibraryName = 'Servo'
        DependentLibraries = {}
        ArduinoLibraryHeaderFiles = 'Servo/Servo.h'
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'ServoBase.h')
        CppClassName = 'ServoBase'
    end
    
    methods
        function obj = ServoMotorBase(parentObj, pin, params)
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
            catch e
                throwAsCaller(e);
            end
            
            pin = arduinoio.internal.validateInputPin(pin);
            if pin(1) == 'A'
                pin = getPinAlias(parentObj, pin);
            end
                
            obj.Pins = pin;
            obj.Parent = parentObj;
            obj.IsServoAttached = false;
            
            switch obj.Parent.Board
                % Arduino Servo Library limtation by by board type
                % http://arduino.cc/en/reference/servo
                %
                case {'Mega2560', 'MegaADK'}
                    obj.ReservePWMPins = {'D11', 'D12'};
                    obj.CountCutOff = 12;
                    obj.MaxServos = 48;
                case 'Due'
                    % No PWM pin conflict with usage of servo library on
                    % Due. It uses timer1-5 which do not consume any PWM 
                    % pins on Due (D2-D13), see below:
                    % https://github.com/ivanseidel/DueTimer/issues/11
                    %
                    % Though, the maximum number of servos permitted by the
                    % Servo library is 60 for Due board(12 for each of the 
                    % 5 timers), it is limited to the number of available
                    % digital pins here(2:53).
                    obj.MaxServos = 52;
                    obj.CountCutOff = 0;
                case 'MKR1000'
                    % Only one timer is enabled for servo control. Each
                    % timer controls at most 12 servos
                    obj.MaxServos = 12;
                    obj.CountCutOff = 0;
                otherwise
                    obj.ReservePWMPins = {'D9', 'D10'};
                    obj.CountCutOff = 0;
                    obj.MaxServos = 12;
            end
            
            validatePin(parentObj, pin, 'servo');
            
            try
                p = inputParser;
                addParameter(p, 'MinPulseDuration', obj.DefaultMinPulseDuration);
                addParameter(p, 'MaxPulseDuration', obj.DefaultMaxPulseDuration);
                addParameter(p, 'ResourceMode', 'Servo');
                addParameter(p, 'ResourceOwner', 'Servo');
                parse(p, params{:});
            catch
                parameters = {p.Parameters{1}, p.Parameters{2}};
                obj.localizedError('MATLAB:arduinoio:general:invalidNVPropertyName',...
                    'Servo', ...
                    arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(parameters, ', '));
            end
            
            obj.MinPulseDuration = ...
                arduinoio.internal.validateDoubleParameterRanged('MinPulseDuration', ...
                                                             p.Results.MinPulseDuration, ...
                                                             0, 4e-3, 's');
            obj.MaxPulseDuration = ...
                arduinoio.internal.validateDoubleParameterRanged('MaxPulseDuration', ...
                                                             p.Results.MaxPulseDuration, ...
                                                             0, 4e-3, 's');
            
            if (any(ismember(p.UsingDefaults, 'MinPulseDuration')) && ~any(ismember(p.UsingDefaults, 'MaxPulseDuration'))) ||...
               (any(ismember(p.UsingDefaults, 'MaxPulseDuration')) && ~any(ismember(p.UsingDefaults, 'MinPulseDuration')))
                obj.localizedError('MATLAB:arduinoio:general:requiredBothMinMaxPulseDurations');
            end
            obj.ResourceMode = p.Results.ResourceMode;
            obj.ResourceOwner = p.Results.ResourceOwner;
            
            if obj.MinPulseDuration >= obj.MaxPulseDuration
                obj.localizedError('MATLAB:arduinoio:general:invalidMinMaxPulseDurations');
            else
                obj.allocateResource(pin);
                try
                    attachServo(obj, str2double(pin(2:end)), obj.MinPulseDuration*1e6, obj.MaxPulseDuration*1e6);
                catch e
                    throwAsCaller(e);
                end
            end
        end
    end
    
    methods (Access=protected)
        function delete(obj)
            orig_state = warning('off','MATLAB:class:DestructorError');
            try
                clearServo(obj);
            catch
            end
            
            try
                freeResource(obj);
            catch
            end
            warning(orig_state.state, 'MATLAB:class:DestructorError');
        end
    end
    
        %% Property set/get
     methods (Access = private)
        function attachServo(obj, pin, min, max)
            commandID = obj.ATTACH_SERVO;
            
            min = typecast(uint16(min), 'uint8');
            max = typecast(uint16(max), 'uint8');
            try
                cmd = [pin, min, max];
                sendCommandCustom(obj, obj.LibraryName, commandID, cmd');
            catch e
                throwAsCaller(e);
            end
            obj.IsServoAttached = true;
        end
        
        function clearServo(obj)
            if ~obj.IsServoAttached
                return;
            end
            
            commandID = obj.CLEAR_SERVO;
            try
                cmd = [];
                sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
            catch e
                throwAsCaller(e);
            end
            obj.IsServoAttached = false;
        end
    end
    
    methods (Access = public)
        function value = readPosition(obj)
            %   Read the position of servo motor shaft.
            %
            %   Syntax:
            %   value = readPosition(s)
            %
            %   Description:
            %   Measures the position of a standard servo motor shaft as a
            %   ratio of the motor's min/max range, from 0 to 1
            %
            %   Example:
            %       a = arduino();
            %       s = servo(a, 9);
            %       pos = readPosition(s);
			%
            %   Example:
            %       a = arduino('COM7', 'Uno', 'Libraries', 'Adafruit\MotorShieldV2');
            %       dev = addon(a, 'Adafruit/MotorShieldV2');
            %       s = servo(dev,1);
            %       pos = readPosition(s);
			%
            %   Input Arguments:
            %   s       - Servo motor device 
            %
			%   Output Arguments:
            %   value   - Measured motor shaft position (double) 
			%
			%   See also writePosition
            
            commandID = obj.READ_POSITION;
            try
                value = sendCommandCustom(obj, obj.LibraryName, commandID);
                value = double(round(value(1)*100/180)/100);
            catch e
                throwAsCaller(e);
            end
        end
        
        function writePosition(obj, value)
            %   Set the position of servo motor shaft.
            %
            %   Syntax:
            %   writePosition(s, value)
            %
            %   Description:
            %   Set the position of a standard servo motor shaft as a
            %   ratio of the motor's min/max range, from 0 to 1
            %
            %   Example:
            %       a = arduino();
            %       s = servo(a, 9);
            %       writePosition(s, 0.6);
			%
            %   Example:
            %       a = arduino();
            %       dev = addon(a, 'Adafruit/MotorShieldV2');
            %       s = servo(dev,1);
            %       writePosition(s, 0.6);
			%
            %   Input Arguments:
            %   s       - Servo motor device 
            %   value   - Motor shaft position (double)
			%
			%   See also readPosition
            
            commandID = obj.WRITE_POSITION;
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
            
                arduinoio.internal.validateDoubleParameterRanged('position', value, 0, 1);
                value = uint8(180*value);
                cmd = value;
                sendCommandCustom(obj, obj.LibraryName, commandID, cmd);
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    methods (Access = protected)
        function output = sendCommandCustom(obj, libName, commandID, inputs)
            if nargin > 3
                inputs = [str2double(obj.Pins(2:end)); inputs];
            else
                inputs = str2double(obj.Pins(2:end));
            end
            [output, ~] = sendCommand(obj, libName, commandID, inputs);
        end
    end
    
    %% Protected methods
    %
    %
    methods (Access = protected)       
        function disablePWMPins(obj, pins)
            for i = 1:numel(pins)
                terminal = getTerminalsFromPins(obj.Parent, pins{i});
                resourceOwner = getResourceOwner(obj.Parent, terminal);
                if ~strcmp(resourceOwner, 'Servo') 
                    mode = getTerminalMode(obj.Parent, terminal);
                    switch mode
                        case {'Unset', 'PWM', 'Servo'}
                            % Take resource ownership from Arduino object
                            configurePinResource(obj.Parent, pins{i}, '', 'Unset');
                            configurePinResource(obj.Parent, pins{i}, obj.ResourceOwner, 'Reserved', true);
                        otherwise
                            obj.ResourceAllocationSuccessFlag = false;
                            obj.localizedError('MATLAB:arduinoio:general:reservedServoPins', ...
                                obj.Parent.Board, strjoin(pins, ', '));
                    end
                end
            end
        end
        
        function enablePWMPins(obj, pins)
            for i = 1:numel(pins)
                terminal = getTerminalsFromPins(obj.Parent, pins{i});
                mode = getTerminalMode(obj.Parent, terminal);
                if strcmp(mode, 'Reserved')
                    configurePinResource(obj.Parent, pins{i}, obj.ResourceOwner, 'Unset', false);
                end
            end
        end
        
        function allocateResource(obj, pin)
            count = incrementResourceCount(obj.Parent, obj.ResourceOwner);
            
            % Possible dead code for now till all digital pins on Mega 2560
            % are supported for servo in the future
            if count > obj.MaxServos
                obj.localizedError('MATLAB:arduinoio:general:maxServos', ...
                    obj.Parent.Board, num2str(obj.MaxServos));
            end
            
            if ~strcmp(obj.Parent.Board, 'Due') % No need to reserve PWM pins for Due board
                if count == obj.CountCutOff + 1
                    obj.disablePWMPins(obj.ReservePWMPins)
                end
            end
            
            terminal = getTerminalsFromPins(obj.Parent, pin);
            mode = getTerminalMode(obj.Parent, terminal);
            resourceOwner = getResourceOwner(obj.Parent, terminal);
            if (strcmp(mode, 'Servo') || strcmp(mode, 'PWM')) ...
                    && strcmp(resourceOwner, '')
                % Take resource ownership from Arduino object
                configurePinResource(obj.Parent, pin, resourceOwner, 'Unset');
                configurePinResource(obj.Parent, pin, obj.ResourceOwner, obj.ResourceMode, true);
            elseif strcmp(mode, 'Unset') || ...
                   (strcmp(mode, 'Reserved') || arduinoio.internal.endsWith(mode, '\Reserved') && ...
                   (strcmp(resourceOwner, 'Servo') || arduinoio.internal.endsWith(resourceOwner, '\Servo')))
                % We can only acquire unset resources (or resources
                % reserved by servo)
                configurePinResource(obj.Parent, pin, obj.ResourceOwner, obj.ResourceMode, false);
            else
                obj.ResourceAllocationSuccessFlag = false;
                if strcmp(resourceOwner, 'Servo') && ~isempty(strfind(mode, 'Servo'))
                    obj.localizedError('MATLAB:arduinoio:general:reservedResourceServo', ...
                        pin);
                else
                    obj.localizedError('MATLAB:arduinoio:general:reservedPin', ...
                        pin, mode, 'Servo');
                end
            end
        end
        
        function freeResource(obj)
            count = decrementResourceCount(obj.Parent, obj.ResourceOwner);
            
            % Re-enable disabled pins if we are below the count cut-off
            if ~strcmp(obj.Parent.Board, 'Due') 
                if count == obj.CountCutOff
                    obj.enablePWMPins(obj.ReservePWMPins)
                end
            end
            
            terminal = getTerminalsFromPins(obj.Parent, obj.Pins);
            resourceOwner = getResourceOwner(obj.Parent, terminal);
            if ~strcmp(resourceOwner, obj.ResourceOwner)
                % If we're in the destructor because we failed to
                % construct (due to a resource conflict), we have no
                % pin configuration to repair...
                %
                return;
            end
            
            if obj.ResourceAllocationSuccessFlag
                % Free the servo pin.
                if count <= obj.CountCutOff || (count > obj.CountCutOff && ~ismember(obj.Pins, obj.ReservePWMPins))
                    configurePinResource(obj.Parent, obj.Pins, obj.ResourceOwner, 'Unset', false);
                else
                    configurePinResource(obj.Parent, obj.Pins, obj.ResourceOwner, 'Reserved', true);
                end
            end
        end
    end
end
