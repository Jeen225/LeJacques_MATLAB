classdef ArduinoConstants 
%ARDUINOCONSTANTS This static class contains all constants used by arduino
%source and setup app.

% Copyright 2016-2017 The MathWorks, Inc.
    
    properties(GetAccess = public, Constant = true)
        AREF3VBoards = {'Due', 'Pro328_3V', 'Fio', 'DigitalSandbox', 'MKR1000'}
        LinuxSupportedConnectionTypes = {'USB', 'WiFi'}
        WinMacSupportedConnectionTypes = {'USB','Bluetooth®','WiFi'}
        SupportedEncryptionTypes = {'WPA/WPA2', 'WEP', 'None'}
        DefaultTCPIPPort = 9500
        MinKeyNumDigits = 10
        MaxKeyNumDigits = 26
        MinPortValue = 1024
        MaxPortValue = 65535
        WiFiSupportedBoards = {'MKR1000'}
        BluetoothSupportedBoards = {'Uno', 'Mega2560', 'Nano3', 'Due', 'Leonardo', 'Micro'}% Bluetooth does not support MKR1000 since Serial pins are not broken out on board. TX/RX are Serial1
        DefaultLibraries = {'I2C', 'Servo', 'SPI'}
        ShippingLibraries = {'I2C', 'SPI', 'Servo', 'ShiftRegister', 'RotaryEncoder', 'Adafruit/MotorShieldV2'}
        BTSupportedBaudRates = containers.Map(double([arduinoio.internal.BluetoothDeviceTypeEnum.HC05,arduinoio.internal.BluetoothDeviceTypeEnum.HC06]),...
                                                     {{'38400'}, {'38400','9600','115200','1200','2400','4800','19200','57600'}})
        SupportedBTDevices1 = {'Adafruit Bluefruit EZ-Link Programmer', 'Adafruit Bluefruit EZ-Link Shield', 'HC-05', 'HC-06'}
        SupportedBTDevices2 = {'Adafruit Bluefruit EZ-Link Programmer', 'HC-05', 'HC-06'}
        SupportedBTDevicesNoBluefruit = {'HC-05', 'HC-06'}
        BluetoothAddressLength = 12
        PairCode = '1234'
        ArduinoBTBaudRate = 115200
        MKR1000SerialBaudRate = 9600
    end
    
    methods(Static)
        function devices = getSupportedConnectionTypes
            %Return supported connection types based on OS
            if strcmpi(computer, 'GLNXA64')
                devices = arduinoio.internal.ArduinoConstants.LinuxSupportedConnectionTypes;
            else
                devices = arduinoio.internal.ArduinoConstants.WinMacSupportedConnectionTypes;
            end
        end
        
        function boards = getSupportedBoards(type)
            %Return supported boards based on connection type
            boards = [];
            switch type
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    boards = arduinoio.internal.ArduinoConstants.WiFiSupportedBoards;
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    boards = arduinoio.internal.ArduinoConstants.BluetoothSupportedBoards;
                case arduinoio.internal.ConnectionTypeEnum.Serial
                    boards = arduinoio.internal.TabCompletionHelper.getSupportedBoards;
            end
        end
        
        function devices = getSupportedBTDevices(board)
            %Return supported Bluetooth devices based on Arduino board type
            if ismember(board, {'Leonardo','Micro','Nano3'})
                devices = arduinoio.internal.ArduinoConstants.SupportedBTDevices2;
            else
                devices = arduinoio.internal.ArduinoConstants.SupportedBTDevices1;
            end
        end
        
        function rates = getBTSupportedBaudRates(type)
            %Return supported baud rates based on Bluetooth device
            rates = [];
            if arduinoio.internal.ArduinoConstants.BTSupportedBaudRates.isKey(double(type))
                rates = arduinoio.internal.ArduinoConstants.BTSupportedBaudRates(double(type));
            end
        end
    end
end