classdef BluetoothHostTransportLayer < arduinoio.internal.TransportLayerBase
%   Copyright 2016 The MathWorks, Inc.
    
    %% Constructor
    methods (Access = public)
        function obj =BluetoothHostTransportLayer(connectionObj, debug)
            obj@arduinoio.internal.TransportLayerBase(connectionObj, debug);
        end
    end
    
    %% Destructor
    methods (Access=protected)
        function delete(obj)
            if isvalid(obj.connectionObject) && strcmp(obj.connectionObject.Status, 'open')
                closeConnectionImpl(obj);
            end
        end
    end
    
    %% Public methods
    methods (Access = public)   
        function openConnectionImpl(obj, ~)
            try
                fopen(obj.connectionObject);
            catch e
                if strcmpi(e.identifier,'instrument:fopen:opfailed')
                    arduinoio.internal.localizedError('MATLAB:arduinoio:general:openFailed', 'device address', obj.connectionObject.RemoteID);
                else
                    throwAsCaller(e);
                end
            end
        end
        
        function closeConnectionImpl(obj)
            fclose(obj.connectionObject);
        end
        
        function data = readBytesImpl(obj, numBytes)
            data = fread(obj.connectionObject, numBytes);
        end
        
        function writeBytesImpl(obj, data)
            fwrite(obj.connectionObject, data, 'uint8');
        end
    end
    
    %%
    methods(Access = protected)
        function [debugStr, value] = readMessageHook(obj) 
            % Suppress bluetooth read warning before trying to read message
            % response and revert back warning status upon returning
            freadWarning = warning('off','instrument:fread:unsuccessfulRead');
            c = onCleanup(@() cleanup(freadWarning));
            [debugStr, value] = readMessageHook@arduinoio.internal.TransportLayerBase(obj);
            function cleanup(freadWarning)
                warning(freadWarning.state, 'instrument:fread:unsuccessfulRead');
            end
        end
    end
end