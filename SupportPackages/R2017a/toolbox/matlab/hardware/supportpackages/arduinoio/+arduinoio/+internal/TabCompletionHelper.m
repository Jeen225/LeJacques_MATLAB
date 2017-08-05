classdef TabCompletionHelper
% helper class for dynamic input arguments' values for
% functionSignatures.json

% Copyright 2016 The MathWorks, Inc.
    
    methods(Static)
        function boards = getSupportedBoards
            % Get supported boards list from BoardInfo.m
            b = arduinoio.internal.BoardInfo.getInstance();
            boards = {b.Boards.Name};
        end
        
        function ports = getAvailablePorts
            % Get all serial ports available in MATLAB
            % Note the returned list may be different from the operating
            % system's list(either from Device Manager or Terminal)
            ports = cellstr(char(com.mathworks.toolbox.instrument.SerialComm.findAllPorts()));
        end
        
        function libs = getAddonLibraries
            % Get all valid library strings to specify in 'addon' function
            allLibs = listArduinoLibraries;
            libs = {};
            result = strfind(allLibs, '/');
            for ii = 1:numel(allLibs)
                if ~isempty(result{ii})
                    libs = [libs, allLibs{ii}]; %#ok<AGROW>
                end
            end
        end
        
        function buses = getAvailableBuses(arduinoObj)
            % Get available buses for the given board
            if strcmp(arduinoObj.Board, 'Due')
                buses = {0 1};
            else
                buses = {0};
            end
        end
        
        function pins = getAnalogPins(arduinoObj)
            % Get all analog pins on the given board
            pins = arduinoObj.AvailablePins(strncmp(arduinoObj.AvailablePins, 'A', 1));
        end
        
        function pins = getDigitalPins(arduinoObj, selectedPins)
            % Get all digital pins on the given board
            % If given selectedPins, return the remaining unused digital
            % pins list
            if nargin < 2
                pins = arduinoObj.AvailablePins(strncmp(arduinoObj.AvailablePins, 'D', 1));
            else
                pins = setxor(selectedPins, arduinoio.internal.TabCompletionHelper.getDigitalPins(arduinoObj));
            end
        end
        
        function pins = getPWMPins(arduinoObj)
            % Get all pins supported for PWM on the given board
            terminals = getPWMTerminals(arduinoObj.ResourceManager);
            pins = getPinsFromTerminals(arduinoObj.ResourceManager, terminals);
        end
        
        function pins = getInterruptPins(arduinoObj, selectedPins)
            % Get all interrupt pins on the given board
            terminals = getInterruptTerminals(arduinoObj.ResourceManager);
            pins = getPinsFromTerminals(arduinoObj.ResourceManager, terminals);
            if nargin > 1
                pins = setxor(pins, selectedPins);
            end
        end
        
        function pins = getServoPins(arduinoObj)
            % Get all pins supported for Servo on the given board
            terminals = getServoTerminals(arduinoObj.ResourceManager);
            pins = getPinsFromTerminals(arduinoObj.ResourceManager, terminals);
        end
        
        function precisions = getShiftRegisterWritePrecisions
            % Get all supported precisions for write methods of
            % shiftRegister object
            precisions = {'uint8', 'uint16', 'uint32'};
        end
        
        function precisions = getShiftRegisterReadPrecisions
            % Get all supported precisions for read methods of
            % shiftRegister object
            precisions = {8, 16, 32, 'uint8', 'uint16', 'uint32'};
        end
        
        function types = getStepTypes
            % Get all supported values for StepType NV pair for stepper
            % object
            types = {'Single', 'Double', 'Interleave', 'Microstep'};
        end
        
        function precisions = getI2CReadWritePrecisions
            % Get all supported precisions for read and write methods of
            % i2cdev object
            precisions = {'int8', 'uint8', 'int16', 'uint16'};
        end
        
        function precisions = getSPIReadWritePrecisions
            % Get all supported precisions for read and write methods of
            % spidev object
            precisions = {'uint8', 'uint16', 'int8', 'int16'};
        end
        
        function modes = getSupportedModes
            % Get all supported modes for configurePin method
            modes = {'DigitalInput', 'DigitalOutput', 'AnalogInput', 'Pullup', 'PWM', 'Servo', 'SPI', 'I2C', 'Unset'};
        end
    end
end