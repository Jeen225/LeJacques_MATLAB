classdef SerialHostTransportLayer < arduinoio.internal.TransportLayerBase
%   Copyright 2014-2016 The MathWorks, Inc.
    
    %% Constructor
    methods (Access = public)
        function obj = SerialHostTransportLayer(connectionObj, debug)
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
        function openConnectionImpl(obj, initTimeout)
            originalState = warning('off','MATLAB:serial:fread:unsuccessfulRead');
            c = onCleanup(@() cleanup(originalState));
            
            try
                fopen(obj.connectionObject);
            catch e
                if strcmpi(e.identifier,'MATLAB:serial:fopen:opfailed')
                    arduinoio.internal.localizedError('MATLAB:arduinoio:general:openFailed', 'serial port', obj.connectionObject.Port);
                else
                    throwAsCaller(e);
                end
            end
            % Wait for board serial to fully initialize before sending any serial request to avoid board lockup during programming mode after reset.
            % 1. For boards that don't auto-reset upon opening serial port and have a serial initialization time - USB or Serial over Bluetooth on Mac(Uno/Mega/Due,etc)
            % 2. For boards that auto-reset upon opening serial port - USB or Serial over Bluetooth on Windows(Uno/Mega/Due,etc)
            if initTimeout >= 0  % For boards that auto-reset upon opening serial port, not including Micro and Leonardo
                value = '';
                localTimer = tic;
                while toc(localTimer)<initTimeout && isempty(value)
                    value = fread(obj.connectionObject, 10);
                end
            end
            
            function cleanup(originalState)
                warning(originalState.state, 'MATLAB:serial:fread:unsuccessfulRead');
            end
        end
        
        function closeConnectionImpl(obj)
            fclose(obj.connectionObject);
        end
        
        function data = readBytesImpl(obj, numBytes)
            data = fread(obj.connectionObject, numBytes);
        end
        
        function writeBytesImpl(obj, data)
            fwrite(obj.connectionObject, data);
        end
    end
    
    %%
    methods(Access = protected)
        function [debugStr, value] = readMessageHook(obj)            
            % Suppress serial read warning before trying to read message
            % response and revert back warning status upon returning
            freadWarning = warning('off','MATLAB:serial:fread:unsuccessfulRead');
            c = onCleanup(@() cleanup(freadWarning));
            [debugStr, value] = readMessageHook@arduinoio.internal.TransportLayerBase(obj);
            function cleanup(freadWarning)
                warning(freadWarning.state, 'MATLAB:serial:fread:unsuccessfulRead');
            end
        end
    end
end