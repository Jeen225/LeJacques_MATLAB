% Copyright 2015-2016 The MathWorks, Inc.

% Step 1 - Define MATLAB class that inherits from
% arduinoio.LibraryBase
classdef HelloWorld < arduinoio.LibraryBase
    
    % Step 2 - Define command IDs for all public methods of the class object
    properties(Access = private, Constant = true)
        READ_COMMAND = hex2dec('01')
    end
    
    % Step 3 - Override below constant properties to include any 3P source
    % into the compiled server code
    properties(Access = protected, Constant = true)
        LibraryName = 'ExampleAddon/HelloWorld'
        DependentLibraries = {}
        ArduinoLibraryHeaderFiles = {}
        CppHeaderFile = fullfile(arduinoio.FilePath(mfilename('fullpath')), 'src', 'HelloWorld.h')
        CppClassName = 'HelloWorld'
    end
    
    methods
        % Step 4 - Define class constructor
        function obj = HelloWorld(parentObj)
            % Step 5 - Set class's Parent and Pins property
            obj.Parent = parentObj;
            obj.Pins = [];
        end
        
        % Step 6 - Define method to call 3P functions
        function out = read(obj)
            cmdID = obj.READ_COMMAND;
            inputs = [];
            
            % Step 7 - Send message using sendCommand API
            output = sendCommand(obj, obj.LibraryName, cmdID, inputs);
            
            % Step 8 - Read back data starts from index 3
            out = char(output');
        end
    end
end