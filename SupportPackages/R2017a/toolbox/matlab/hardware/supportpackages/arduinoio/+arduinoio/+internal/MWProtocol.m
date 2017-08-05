classdef MWProtocol < arduinoio.internal.ProtocolBase
    
    % Built-in Arduino message format               [A5; payload_size; Addon_Identifier(0)+sequence_ID; cmdID; data; checksum]
    % Add-on library message format                 [A5; payload_size; Addon_Identifier(1)+sequence_ID; libID; cmdID; data; checksum]
    % Arduino return message format                 [5A; payload_size; cmdID; data; checksum]
    %
    % 1 byte of header + 2 bytes of payload_size + 1 byte of identifier and
    % sequence_ID (+ 1 byte of libID) + 1 byte of cmdID + data + 1 byte of
    % checksum
    %
    % Note: checksum is always computed on the message excluding the first
    % byte - header
    % Copyright 2016 The MathWorks, Inc.

    properties(Access = private, Constant = true)
        GET_SERVER_INFO          = hex2dec('01')
        RESET_PINS_STATE         = hex2dec('02')
        GET_AVAILABLE_RAM        = hex2dec('03')
        WRITE_DIGITAL_PIN        = hex2dec('10')
        READ_DIGITAL_PIN         = hex2dec('11')
        CONFIGURE_PIN            = hex2dec('12')
        WRITE_PWM_VOLTAGE        = hex2dec('20')
        WRITE_PWM_DUTY_CYCLE     = hex2dec('21')
        PLAY_TONE                = hex2dec('22')
        READ_VOLTAGE             = hex2dec('30')
        NON_ADDON_HEADER         = hex2dec('00')
        ADDON_HEADER             = hex2dec('01')
        SCAN_I2C_BUS             = hex2dec('01')
    end
    
%% Constructor   
    methods (Access = public)
        function obj = MWProtocol(connectionObj, initTimeout, traceOn)
            obj = obj@arduinoio.internal.ProtocolBase(connectionObj, initTimeout, traceOn);
        end
    end
 
%% Destructor
    methods (Access=protected)
        function delete(~)
        end
    end
 
 %% Public methods - MW's implementations of firmata
    methods (Access = public)
        function writeDigitalPin(obj, pin, value)
            if pin(1) == 'A'
                subsystem = 1;
            else
                subsystem = 0;
            end
            pin = str2double(pin(2:end));
            msg = [...
            obj.WRITE_DIGITAL_PIN;
            subsystem;
            pin; 
            value
            ];
            sendMWMessage(obj, msg);
        end
        
        function value = readDigitalPin(obj, pin)
            if pin(1) == 'A'
                subsystem = 1;
            else
                subsystem = 0;
            end
            pin = str2double(pin(2:end));
            msg = [...
                obj.READ_DIGITAL_PIN;
                subsystem;
                pin;
                ];
            value = sendMWMessage(obj, msg);
            value = value(2);
            value = double(value > 0);
        end
        
        function configurePin(obj, pin, mode)
            if pin(1) == 'A'
                subsystem = 1;
            else
                subsystem = 0;
            end
            pin = str2double(pin(2:end));
            pinmode = 0;
            switch(mode)
                case {'DigitalInput', 'AnalogInput', 'Unset'}
                    pinmode = 0;
                case {'DigitalOutput', 'PWM', 'Servo'}
                    pinmode = 1;
                case 'Pullup' % Input_Pullup
                    pinmode = 2;
            end

            msg = [...
                obj.CONFIGURE_PIN;
                subsystem;
                pin;
                pinmode;
                ];
            sendMWMessage(obj, msg);
        end
        
        function writePWMVoltage(obj, pin, voltage, aref)
            value = uint8(floor(voltage/aref*255));
            msg = [...
                obj.WRITE_PWM_VOLTAGE;
                pin; 
                value;
            ];
            sendMWMessage(obj, msg);
        end
        
        function writePWMDutyCycle(obj, pin, dutyCycle)
            value = uint8(floor(dutyCycle/1*255));
            
            msg = [...
                obj.WRITE_PWM_DUTY_CYCLE;
                pin; 
                value;
            ];
            sendMWMessage(obj, msg);
        end
        
        function value = readVoltage(obj, pin, aref)   
            msg = [...
            obj.READ_VOLTAGE;
            pin
            ];  
            value = sendMWMessage(obj, msg);
            value = (bitshift(value(2), 8) + value(3))/1023*aref;
        end

        function playTone(obj, pin, frequency, duration)
            duration = round(duration*1000);
            
            frequency = typecast(uint16(frequency), 'uint8');
            duration = typecast(uint16(duration), 'uint8');
            
            msg = [...
                obj.PLAY_TONE;
                pin; 
                frequency';
                duration';
                ] ;
            sendMWMessage(obj, msg);
        end
        
        function addrs = scanI2CBus(obj, libID, bus)
            addrs = {};
            commandID = obj.SCAN_I2C_BUS;
            cmd = [commandID; bus];
            output = sendAddonMessage(obj, libID, cmd);
            try
                numAddrsFound = output(1);
                if numAddrsFound ~= hex2dec('0') % devices found
                    values = uint8(output(2:end));
                    addrs = cell(numAddrsFound, 1);
                    for ii = 1:numAddrsFound
                        addrs{ii} = ['0x', dec2hex(values(ii))];
                    end
                end
            catch e
                if strcmp(e.identifier, 'MATLAB:badsubscript')
                    obj.localizedError('MATLAB:arduinoio:general:connectionIsLost');
                elseif strcmp(e.identifier, 'MATLAB:arduinoio:general:connectionIsLost')
                    obj.localizedError('MATLAB:arduinoio:general:communicationLostI2C', num2str(bus));
                end
                throwAsCaller(e);
            end
        end
        
        function value = getAvailableRAM(obj)
            msg = obj.GET_AVAILABLE_RAM;
            value = sendMWMessage(obj, msg);
            value = bitshift(value(2), 8) + value(3);
        end
        
        function resetPinsState(obj)        
            msg = obj.RESET_PINS_STATE;
            sendMWMessage(obj, msg);
        end
        
        function [getInfoSuccessFlag, libVersion, libNames, libIDs, board, traceOn] = getServerInfo(obj)
            msg = obj.GET_SERVER_INFO;
            libIDs = [];
            libNames = {};
            getInfoSuccessFlag = false;
            traceOn = false;
            board = '';
            libVersion = '';
            try 
                value = sendMWMessage(obj, msg);
                if isempty(value)
                    return;
                end
            catch 
                 return; % do nothing
            end
            % value :  first value is payload_size
            output = regexp(char(value(2:end))', ';', 'split'); % separate out libraries using semicolon. 
            
            try % parse returned character vector to get server information
                libVersion = output{1};
                libVersion = [num2str(double(libVersion(1))), '.', num2str(double(libVersion(2)))];
                board = output{2};
                if double(output{3}) == 1
                    traceOn = true;
                end
                if isempty(output{4}) % zero libraries
                    % return empty libs
                    getInfoSuccessFlag = true;
                else
                    if strcmp(output{4}, char(0)) % unexpected returned message
                        % stop parsing
                    else
                        seperatedLibraries = output(4:end); 
                        for ii = 1:length(seperatedLibraries)
                            libIDs = [libIDs, double(seperatedLibraries{ii}(1))]; %#ok<AGROW>
                            libNames = [libNames, {seperatedLibraries{ii}(2:end)}]; %#ok<AGROW>
                        end
                        getInfoSuccessFlag = true;
                    end
                end
            catch % catch any index out of range error for wrong return message
                libIDs = [];
                libNames = {};
            end
        end
    end
    
    %% Public methods
    methods (Access = public)
        function closeTransportLayer(obj)
            closeConnectionImpl(obj.TransportLayer);
        end
        
        function openTransportLayer(obj, initTimeout)
            openConnectionImpl(obj.TransportLayer, initTimeout);
        end
 
        function value = sendAddonMessage(obj, libID, cmd, timeout)
            sentCmdID = cmd(1);
            % The number of bytes to be sent down to server is of data type
            % uint16
            cmd = [libID; cmd];
            payloadSize = numel(cmd)+2; % 1 byte of sequenceID and 1 byte of checksum
            msg = [...
                typecast(cast(payloadSize, 'uint16'), 'uint8')'; 
                bitshift(obj.ADDON_HEADER, 7)+obj.SequenceID;
                cmd]; % includes cmdID
            checksum = computeChecksum(obj, msg);
            msg = [...
                hex2dec('5A');
                msg;
                checksum];
            if nargin < 4
                output = sendMessage(obj.TransportLayer, msg);
            else
                output = sendMessage(obj.TransportLayer, msg, timeout);
            end
            
            if numel(output)>3 && ...  % returned message contains at least payloadSize and checksum
               computeChecksum(obj, output(1:end-1))==output(end) && ...  % returned message checksum match
               output(3) == sentCmdID  % returned message cmdID match
           
            	% Final returned output is [payload, value]
                payloadSize = bitshift(output(1), 8) + output(2);
                value = [payloadSize-2; output(4:end-1)];
           
                % Increase sequence ID by one if command execution succeeds
                if obj.SequenceID == 127
                    obj.SequenceID = 0;
                else
                    obj.SequenceID = obj.SequenceID + 1;
                end
            else
                % for everything else, something wrong in receiving of the
                % message
                obj.localizedError('MATLAB:arduinoio:general:connectionIsLost');
            end
        end

        function value = sendMWMessage(obj, cmd, timeout)
            sentCmdID = cmd(1);
            payloadSize = numel(cmd)+2; % 1 byte of sequenceID and 1 byte of checksum
            msg = [...
                typecast(cast(payloadSize, 'uint16'), 'uint8')'; 
                bitshift(obj.NON_ADDON_HEADER, 7)+obj.SequenceID;
                cmd]; % includes cmdID
            checksum = computeChecksum(obj, msg);
            msg = [...
                hex2dec('5A');
                msg;
                checksum];
            if nargin < 4
                output = sendMessage(obj.TransportLayer, msg);
            else
                output = sendMessage(obj.TransportLayer, msg, timeout);
            end
            
            if numel(output)>3 && ...  % returned message contains at least payloadSize and checksum
               computeChecksum(obj, output(1:end-1))==output(end) && ...  % returned message checksum match
               output(3) == sentCmdID  % returned message cmdID match
           
            	% Final returned output is [payload, value]
                payloadSize = bitshift(output(1), 8) + output(2);
                value = [payloadSize-2; output(4:end-1)];
           
                % Increase sequence ID by one if command execution succeeds
                if obj.SequenceID == 127
                    obj.SequenceID = 0;
                else
                    obj.SequenceID = obj.SequenceID + 1;
                end
            else
                % for everything else, something wrong in receiving of the
                % message
                obj.localizedError('MATLAB:arduinoio:general:connectionIsLost');
            end
        end
    end
    
    methods (Access = private)
        function value = computeChecksum(~, data)
            % simple modular sum checksum algorithm
            % sum of data and checksum always result in least significant 8 bits of 0 
            value = 256-mod(sum(data),256);
            if value == 256
                value = 0;
            end
        end
    end
end
