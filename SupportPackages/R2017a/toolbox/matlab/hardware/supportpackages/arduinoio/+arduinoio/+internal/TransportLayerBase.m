classdef TransportLayerBase < handle

%   Copyright 2014-2016 The MathWorks, Inc.

    % TransportLayerBase
    properties(Access = protected)
        connectionObject
        Debug
        Timeout	= 5
    end
    
    properties (Access = private)
        isSendMessageExecuting = false
    end
    
    methods(Abstract)
        openConnectionImpl(obj, initTimeout);
        closeConnectionImpl(obj);
        data = readBytesImpl(obj, numBytes);
        writeBytesImpl(obj, data);
    end
    
    methods(Access = public)
        function obj =TransportLayerBase(connectionObj, debug)
            obj.connectionObject = connectionObj;
            obj.Debug = debug;
        end
    end
    
    methods(Access = protected)
        function writeMessageHook(obj, msg)
            try 
                % flush the serial line before sending any command
                if obj.connectionObject.BytesAvailable
                    readBytesImpl(obj, obj.connectionObject.BytesAvailable);
                end
                writeBytesImpl(obj, msg);
            catch e
                id = 'MATLAB:arduinoio:general:connectionIsLost';
                e = MException(id, getString(message(id)));
                closeConnectionImpl(obj);
                throwAsCaller(e);
            end
        end
        
        function [debugStr, value] = readMessageHook(obj)
            debugStr = [];
            value = [];
            localTimer = tic;
            while toc(localTimer) < obj.Timeout + 1
                while obj.connectionObject.BytesAvailable > 0
                    header = readBytesImpl(obj, 1);
                    if header == hex2dec('A5')
                        debugID = readBytesImpl(obj, 1);
                        if debugID == 0
                            payloadSizeBytes = readBytesImpl(obj, 2);
                            payloadSize = bitshift(payloadSizeBytes(1), 8) + payloadSizeBytes(2);
                            cmdID = readBytesImpl(obj, 1);
                            % read remaining bytes - excluding 1 byte of cmdID and including 1 byte of checksum
                            value = [payloadSizeBytes; cmdID; readBytesImpl(obj, payloadSize-1)];
                        else
                            count = readBytesImpl(obj, 1);
                            debugStr = [debugStr; readBytesImpl(obj, count)]; %#ok<AGROW>
                        end
                    else % discard rest data
                        if obj.connectionObject.BytesAvailable>0
                            readBytesImpl(obj, obj.connectionObject.BytesAvailable);
                        end
                    end
                end
                if ~isempty(value)
                    break;
                end
            end
        end
    end
    
    methods(Access = public)
        function value = sendMessage(obj, msg, timeout)
            if obj.isSendMessageExecuting
                [stack] = dbstack;
                arduinoMethodCalled = stack(end).name;
                separator = strfind(arduinoMethodCalled, '.');
                if contains(arduinoMethodCalled, '.')
                    arduinoMethodCalled = arduinoMethodCalled(separator(end)+1:end);
                end
                arduinoio.internal.localizedError('MATLAB:arduinoio:general:reentrancyException', arduinoMethodCalled)
            end
            
            obj.isSendMessageExecuting = true;
            c = onCleanup(@() cleanup(obj));
            
            if nargin >= 3 
                if timeout > obj.Timeout
                    obj.Timeout = timeout; 
                else
                    arduinoio.internal.localizedError('MATLAB:arduinoio:general:invalidTimeoutValue', obj.Timeout);
                end
            end
            
            writeMessageHook(obj, msg);
            [debugStr, value] = readMessageHook(obj);
            
            % print out received character vectors
            if obj.Debug && ~isempty(debugStr)
                if debugStr(end) == 10
                    % Avoid double '\n'
                    debugStr(end) = [];
                end
                fprintf('%s\n', debugStr);
            end
            
            function cleanup(obj)
                % restore time out to 5s no matter what happened in the
                % current command
                obj.Timeout = 5;
                obj.isSendMessageExecuting = false;
            end
        end
    end
end