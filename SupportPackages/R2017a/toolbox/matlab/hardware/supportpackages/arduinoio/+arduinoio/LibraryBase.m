classdef LibraryBase < arduinoio.internal.BaseClass
    % LIBRARYBASE - True library classes and, addon classes that define a
    % library shall inherit from this base class to get Parent property and
    % other properties and methods.
    
    % Copyright 2014-2016 The MathWorks, Inc.
    
    properties(Hidden, SetAccess = protected)
        Parent
    end
    
    properties(SetAccess = protected)
        Pins
    end
    
    properties(SetAccess = private, GetAccess = protected)
        % Any SDK change that leads to backward incompatibility would
        % update MajorVersion number. Otherwise, only MinorVersion number
        % will be changed
        MajorVersion = 1
        MinorVersion = 0
    end
    
    % Every library class SHALL override all of the following properties
    % with default value
    properties(Abstract = true, Access = protected, Constant = true)
        LibraryName
        DependentLibraries
        
        % Header file of the 3P source/library
        ArduinoLibraryHeaderFiles
        
        % Value SHALL be file name with absolute full path
        CppHeaderFile
        
        CppClassName
    end
    
    methods(Access = protected)
        function count = getAvailableRAM(obj)
            count = getAvailableRAM(obj.Parent);
        end
    end
    
    methods(Access = protected)
        function [dataOut, payloadSize] = sendCommand(obj, libName, commandID, dataIn, timeout)
            try
                % Validate inputs
                % inputs parameter must be a row or column vector or empty
                % matrice
                try
                    validateattributes(dataIn, {'numeric'}, {'2d', 'integer'});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidInputs');
                end
                
                [m, ~] = size(dataIn);
                if ~isempty(dataIn) && m == 1 % row vector
                    dataIn = dataIn';
                end
                
                % Validate commandID
                try
                    validateattributes(commandID, {'numeric'}, {'scalar', 'integer', 'real', 'finite', 'nonnan', 'nonnegative', '>=',0, '<=', 255});
                catch
                    obj.localizedError('MATLAB:arduinoio:general:invalidCommandID');
                end
                
                if ismember(obj.Parent.Board, {'Mega2560', 'MegaADK', 'Due'})
                    maxBytes = 720;
                else
                    maxBytes = 150;
                end
                if numel(dataIn) > maxBytes
                    obj.localizedError('MATLAB:arduinoio:general:maxDataLimit', num2str(maxBytes), obj.Parent.Board);
                end
                
                cmd = [commandID; dataIn];
                
                % accept string type libName but convert it to character vector
                if isstring(libName)
                    libName = char(libName);
                end
                if ischar(libName)
                    if nargin < 5
                        dataOut = sendAddonMessage(obj.Parent, libName, cmd);
                    else
                        % Validate timeout
                        try
                            validateattributes(timeout, {'numeric'}, {'scalar', 'real', 'finite', 'nonnan', 'nonnegative'});
                        catch
                            obj.localizedError('MATLAB:arduinoio:general:invalidTimeout');
                        end
                        dataOut = sendAddonMessage(obj.Parent, libName, cmd, timeout);
                    end
                    payloadSize = dataOut(1);
                    dataOut = dataOut(2:end);
                else
                    arduinoio.internal.localizedError('MATLAB:arduinoio:general:invalidLibraryNameFormat');
                end
            catch e
                throwAsCaller(e);
            end
        end
    end
end
