classdef TCPHostTransportLayer < arduinoio.internal.TransportLayerBase
%   Copyright 2016 The MathWorks, Inc.
    
    %% Constructor
    methods (Access = public)
        function obj =TCPHostTransportLayer(connectionObj, debug)
            obj@arduinoio.internal.TransportLayerBase(connectionObj, debug);
        end
    end
    
    %% Destructor
    methods (Access=protected)
        function delete(obj)
            if isvalid(obj.connectionObject) && strcmp(obj.connectionObject.ConnectionStatus, 'Connected')
                closeConnectionImpl(obj);
            end
        end
    end
    
    %% Public methods
    methods (Access = public) 
        function openConnectionImpl(obj, ~)
            try
                connect(obj.connectionObject);
            catch e
                if strcmpi(e.identifier,'network:tcpclient:connectFailed')
                    arduinoio.internal.localizedError('MATLAB:arduinoio:general:openFailed', 'device address', [obj.connectionObject.RemoteHost,' and port ',num2str(obj.connectionObject.RemotePort)]);
                else
                    throwAsCaller(e);
                end
            end
        end
        
        function closeConnectionImpl(obj)
            disconnect(obj.connectionObject);
        end
        
        function data = readBytesImpl(obj, numBytes)
            data = double(receive(obj.connectionObject, numBytes, 'uint8')');
        end
        
        function writeBytesImpl(obj, data)
            send(obj.connectionObject, uint8(data));
        end
    end
    
    %%
    methods(Access = protected)    
        function [debugStr, value] = readMessageHook(obj)          
            try
                [debugStr, value] = readMessageHook@arduinoio.internal.TransportLayerBase(obj);
            catch 
                % If any error occurred(most likely 'network:tcpclient:receiveFailed'),
                % reset outputs to empty and not throw the error, which
                % will result into a connection lost error with arduino
                % specific message outside
                value = [];
                debugStr = [];
            end
        end
    end
end