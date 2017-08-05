classdef (Sealed) arduino < arduinoio.internal.BaseClass & matlab.mixin.CustomDisplay & dynamicprops
%	Connect to an Arduino.
%
%   Syntax:
%       a = arduino
%       a = arduino(port)
%       a = arduino(port,board,Name,Value)
%       a = arduino(ip,board)
%       a = arduino(ip,board,tcpipport)
%       a = arduino(btaddress,board)
%
%   Description:
%       a = arduino                        Creates a serial connection to an Arduino® hardware.
%       a = arduino(port)                  Creates a serial connection to an Arduino hardware on the specified port.
%       a = arduino(port,board,Name,Value) Creates a serial connection to the Arduino hardware on the specified port and board with additional Name-Value options.
%       a = arduino(ip,board)              Creates a WiFi connection to the Arduino hardware at the specified IP address.
%       a = arduino(ip,board,tcpipport)    Creates a WiFi connection to the Arduino hardware at the specified IP address and TCP/IP remote port.
%       a = arduino(btaddress,board)       Creates a Bluetooth connection to the Arduino hardware at the specified device address.
%
%   Example: 
%   Connect to an Arduino Uno board on COM port 3 on Windows:
%       a = arduino('com3','uno');
% 
%   Connect to an Arduino Uno board on a serial port on Mac:
%       a = arduino('/dev/tty.usbmodem1421');
%
%   Example:
%   Include only I2C library instead of default libraries set (I2C, SPI and Servo)
%       a = arduino('com3','uno','libraries','I2C');
%
%   Example:
%   Connect to an Arduino MKR1000 board at IP address 172.32.45.121:
%       a = arduino('172.32.45.121','mkr1000');
%
%   Connect to an Arduino MKR1000 board at IP address 172.32.45.121 and TCP/IP remote port 8000:
%       a = arduino('172.32.45.121','mkr1000',8000);
%
%   Connect to an Arduino Uno board at device address btspp://98d331fc3af3:
%       a = arduino('btspp://98d331fc3af3','uno');
%
%
%   Input Arguments:
%   port - Device port (character vector or string, e.g. 'com3' or '/dev/tty.usbmodem1421')
%   board - Arduino Board type (character vector or string, e.g. 'Uno', 'Mega2560', ...)
%   ip - Arduino WiFi device address (character vector or string, e.g. '172.32.45.121')
%   tcpipport - Arduino TCP/IP remote port (numeric, e.g. 8000)
%   btaddress - Arduino Bluetooth address (character vector or string, e.g 'btspp://98d331fc3af3')
%
%   Name-Value Pair Input Arguments:
%   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value. 
%   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
%
%   NV Pair:
%   'libraries' - Name of Arduino library (character vector or string)
%              Default libraries downloaded to Arduino: I2C, SPI, Servo.
%
%   Name of the Arduino library specified as a character vector or string.
%   Example: a = arduino('com9','uno','libraries','spi')
%
%   Output Arguments:
%   a - Arduino hardware connection
%
%   See also arduinosetup, listArduinoLibraries, writeDigitalPin, readDigitalPin, i2cdev, spidev

%   Copyright 2014-2017 The MathWorks, Inc.
    
    properties(SetAccess = private) 
        %Arduino hardware type.
        Board
        
        %Available pins on Arduino hardware
        AvailablePins
        
        %Libraries compiled and downloaded to Arduino hardware
        Libraries
    end
    
    properties(Hidden, SetAccess = private)
        %Type of communication between Arduino and host
        ConnectionType
        
        %Display debug trace of commands executed on Arduino hardware
        TraceOn
        
        %Force compile and download of Arduino server.
        ForceBuildOn
        
        %Flag of whether uploading a library or not
        LibrariesSpecified
    end
    
    properties(SetAccess = private, GetAccess = {?arduinoio.LibraryBase, ?arduinoio.internal.TabCompletionHelper})
        ResourceManager
    end
    
    properties(Access = private)
        Utility
        Protocol
        LibraryIDs
        ResourceOwner
        Connection
    end
    
    properties(Access = private, Constant = true)
        DefaultLibList = arduinoio.internal.ArduinoConstants.DefaultLibraries
        % major release/minor release - 17aMarch
        LibVersion = '17.3';
    end
    
    % Aref not officially supported, but may be needed for correct PWM
    % calculations.
    properties(Hidden)
        Aref
    end
    
    % Maintain a map of created objects to gain exclusive access.
    properties (Access = private, Hidden)
        ConnectionMap = containers.Map()
    end
 
    %% Constructor
    methods(Hidden, Access = public)
        function obj = arduino(varargin)
            narginchk(0, 10); 
            
            try
                initUtility(obj);
                
                initProperties(obj, varargin);

                % Resource Owner (Arduino = '')
                obj.ResourceOwner = '';
                
                % Analog reference, for PWM scaling
                initResourceManager(obj, obj.Board);
                obj.Board = obj.ResourceManager.Board;
                tAnalog = obj.ResourceManager.TerminalsAnalog;
                tDigital = obj.ResourceManager.TerminalsDigital;
                obj.AvailablePins = obj.getPinsFromTerminals([tDigital, tAnalog]);
                
                if ismember(obj.Board, arduinoio.internal.ArduinoConstants.AREF3VBoards)
                    obj.Aref = 3.3;
                else
                    obj.Aref = 5.0;
                end
                
                % Setup and initialize host and target connection
                initServerConnection(obj);

                % update preference last to ensure preference is only
                % updated when an arduino object is successfully created
                switch obj.ConnectionType
                    case arduinoio.internal.ConnectionTypeEnum.Serial
                        addressKey = obj.Port;
                        setPreference(obj.Utility, obj.ConnectionType, obj.Port, obj.Board, [], obj.TraceOn);
                    case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                        addressKey = obj.DeviceAddress;
                        setPreference(obj.Utility, obj.ConnectionType, obj.DeviceAddress, obj.Board, [], obj.TraceOn);
                    case arduinoio.internal.ConnectionTypeEnum.WiFi
                        addressKey = obj.DeviceAddress;
                        setPreference(obj.Utility, obj.ConnectionType, obj.DeviceAddress, obj.Board, obj.Port, obj.TraceOn);
                end
                
                % Add current arduino to connectionMap
                obj.ConnectionMap(addressKey) = obj.Board;
                
                % Wire library has not been used yet
                setSharedResourceProperty(obj, 'I2C', 'I2CIsUsed', false);
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    %% Destructor
    methods (Access=protected)
        function delete(obj)
            % User delete of Arduino objects is disabled. Use clear
            % instead.
            if ~isempty(obj.Connection) % Delete the serial object arduino creates
                if obj.ConnectionType == arduinoio.internal.ConnectionTypeEnum.Serial
                    % Reset all pins state to input
                    try
                        buildInfo = getBuildInfo(obj.ResourceManager);
                        if buildInfo.InitTimeout>=0
                            % only reset pin states for boards that auto-reset upon opening serial port with serial connection
                            resetPinsState(obj.Protocol); 
                        end
                    catch
                        % not error out
                    end
                end
                delete(obj.Connection)
                clear obj.Connection;
                
                % Remove current arduino's exclusive lock on transport layer
                if obj.ConnectionType==arduinoio.internal.ConnectionTypeEnum.Serial
                    addressKey = obj.Port;
                else
                    addressKey = obj.DeviceAddress;
                end
                if isKey(obj.ConnectionMap, addressKey)
                    remove(obj.ConnectionMap, addressKey);
                end
            end
        end
    end
    
    %% Public methods
    methods(Access = public)
        function varargout = configurePin(obj, pin, mode)
            %   Arduino pin mode.
            %
            %   Syntax:
            %       pinMode = configurePin(a,pin)
            %       configurePin(a,pin,mode)
            %
            %   Description:
            %       Displays the pin mode of the specified pin or sets the 
            %       specified pin on the Arduino hardware to the specified 
            %       mode.
            %
            %   Example:
            %       a = arduino();
            %       configurePin(a,'D3','pullup');
            %
            %   Example:
            %       a = arduino();
            %       configurePin(a,'A1','Unset');
            %
            %   Input Arguments:
            %   a    - Arduino
            %   pin  - Pin number on the physical hardware (character vector or string).
            %   mode - Pin mode (character vector or string, e.g. DigitalInput, Pullup, DigitalOutput, PWM, ...)
            %
            %   Example:
            %       a = arduino();
            %       config = configurePin(a, 'D2');
            %
            %   Output Arguments:
            %   config - Current mode (character vector) for specified pin.
            
            try
                if nargout > 1
                    obj.localizedError('MATLAB:maxlhs');
                end

                if (nargout > 0 && nargin > 2) || (nargin > 3)
                    obj.localizedError('MATLAB:maxrhs');
                end
                
                pin = arduinoio.internal.validateInputPin(pin);
                if nargin ~= 2
                    % Writing pin configuration
                    configurePinResource(obj, pin, obj.ResourceOwner, mode, true);
                else
                    % Reading pin configuration
                    varargout = {configurePinResource(obj, pin)};
                    return;
                end
            catch e
                throwAsCaller(e);
            end
        end
        
        function writeDigitalPin(obj, pin, value)
            %   Write digital pin value to Arduino hardware.
            %
            %   Syntax:
            %   writeDigitalPin(a,pin,value)
            %
            %   Description:
            %   Writes specified value to the specified pin on the Arduino hardware.
            %
            %   Example:
            %       a = arduino();
            %       writeDigitalPin(a,'D13',1);
            %
            %   Input Arguments:
            %   a     - Arduino hardware
            %   pin   - Digital pin number on the Arduino hardware (character vector or string)
            %   value - Digital value (0, 1) or (true, false) to write to the specified pin (double).
            %
            %   See also readDigitalPin, writePWMVoltage, writePWMDutyCycle
            
            try
                if (nargin < 3)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                pin = arduinoio.internal.validateInputPin(pin);
                configurePinResource(obj, pin, obj.ResourceOwner, 'DigitalOutput', false);
                value = arduinoio.internal.validateDigitalParameter(value);
                if pin(1) == 'A'
                    pin = getPinAlias(obj, pin);
                end
                writeDigitalPin(obj.Protocol, pin, value);
            catch e
                throwAsCaller(e);
            end
        end
        
        function value = readDigitalPin(obj, pin)
            %   Read digital pin value on Arduino hardware.
            %
            %   Syntax:
            %   value = readDigitalPin(a,pin)
            %
            %   Description:
            %   Reads logical value from the specified pin on the Arduino hardware.
            %
            %   Example:
            %       a = arduino();
            %       value = readDigitalPin(a,'D13');
            %
            %   Input Arguments:
            %   a   - Arduino hardware
            %   pin - Digital pin number on the Arduino hardware (character vector or string)
            %
            %   Output Arguments:
            %   value - Digital (0, 1) value acquired from digital pin (double)
            %
            %   See also writeDigitalPin
            
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                pin = arduinoio.internal.validateInputPin(pin);
                configurePinResource(obj, pin, obj.ResourceOwner, 'DigitalInput', false);
                if pin(1) == 'A'
                    pin = getPinAlias(obj, pin);
                end
                value = readDigitalPin(obj.Protocol, pin);
            catch e
                throwAsCaller(e);
            end
        end
        
        function writePWMVoltage(obj, pin, voltage)
            %   Output a PWM signal on a digital pin on the Arduino hardware.
            %
            %   Syntax:
            %   writePWMVoltage(a,pin,voltage)
            %
            %   Description:
            %   Write the specified voltage to the specified PWM pin on the Arduino hardware.
            %
            %   Example:
            %       a = arduino();
            %       writePWMVoltage(a,'D13',2.5);
            %
            %   Input Arguments:
            %   a       - Arduino hardware
            %   pin     - Digital pin number on the Arduino hardware (character vector or string)
            %   voltage - PWM signal voltage to write to the Arduino pin (double).
            %
            %   See also writeDigitalPin, writePWMDutyCycle
            
            try
                if (nargin < 3)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                pin = arduinoio.internal.validateInputPin(pin);
                configurePinResource(obj, pin, obj.ResourceOwner, 'PWM', false);
                voltage = arduinoio.internal.validateDoubleParameterRanged('PWM voltage', voltage, 0, obj.Aref, 'V');
                if pin(1) == 'A'
                    pin = getPinAlias(obj, pin);
                end
                writePWMVoltage(obj.Protocol, str2double(pin(2:end)), voltage, obj.Aref);
            catch e
                throwAsCaller(e);
            end
        end
        
        function writePWMDutyCycle(obj, pin, dutyCycle)
            %   Output a PWM signal on a digital pin on the Arduino hardware.
            %
            %   Syntax:
            %   writePWMDutyCycle(a,pin,dutyCycle)
            %
            %   Description:
            %   Set the specified duty cycle on the specified digital pin on the Arduino hardware.
            %
            %   Example:
            %   Set the bightness of the LED on digital pin 13 of the Arduino hardware to 33%
            %       a = arduino();
            %       writePWMDutyCycle(a,'D13',0.33);
            %
            %   Input Arguments:
            %   a         - Arduino hardware
            %   pin       - Digital pin number on the Arduino hardware (character vector or string)
            %   dutyCycle - PWM signal duty cycle to write to the Arduino pin (double).
            %
            %   See also writeDigitalPin, writePWMVoltage

            try
                if (nargin < 3)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                pin = arduinoio.internal.validateInputPin(pin);
                configurePinResource(obj, pin, obj.ResourceOwner, 'PWM', false);
                dutyCycle = arduinoio.internal.validateDoubleParameterRanged('PWM duty cycle', dutyCycle, 0, 1);
                if pin(1) == 'A'
                    pin = getPinAlias(obj, pin);
                end
                writePWMDutyCycle(obj.Protocol, str2double(pin(2:end)), dutyCycle);
            catch e
                throwAsCaller(e);
            end
        end
        
        function value = readVoltage(obj, pin)
            %   Read analog pin value on Arduino hardware.
            %
            %   Syntax:
            %   value = readVoltage(a,pin)
            %
            %   Description:
            %   Reads analog voltage value from the specified pin on the Arduino hardware.
            %
            %   Example:
            %       a = arduino();
            %       value = readVoltage(a,'A2');
            %
            %   Input Arguments:
            %   a   - Arduino hardware
            %   pin - Analog pin number on the Arduino hardware (character vector or string)
            %
            %   Output Arguments:
            %   value - Voltage value acquired from analog pin (double)
            %
            %   See also readDigitalPin
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end
                
                pin = arduinoio.internal.validateInputPin(pin);
                configurePinResource(obj, pin, obj.ResourceOwner, 'AnalogInput', false);
                if pin(1) == 'D'
                    pin = getPinAlias(obj, pin);
                end
                value = readVoltage(obj.Protocol, str2double(pin(2:end)), obj.Aref);
            catch e
                throwAsCaller(e);
            end    
        end
        
        function playTone(obj, pin, varargin)
            %   Play a tone on piezo speaker
            %
            %   Syntax:
            %   playTone(a,pin)                    Plays a 1000Hz, 1s tone on a piezo speaker attached to
            %                                      the Arduino hardware at a specified pin.
            %   playTone(a,pin,frequency)          Plays a 1s tone at specified frequency.
            %   playTone(a,pin,frequency,duration) Plays a tone at specified frequency and duration.
            %
            %   Example:
            %   Play a tone connected to pin 5 on the Arduino for 30 seconds at 2400Hz.
            %       a = arduino();
            %       playTone(a,'D5',2400,30);
            %
            %   Example:
            %   Stop playing tone.
            %       a = arduino();
            %       playTone(a,'D5',0,0);
            %
            %   Input Arguments:
            %   a         - Arduino
            %   pin       - Digital pin number (character vector or string)
            %   frequency - Frequency of tone (numeric, 0 - 32767Hz)
            %   duration  - Duration of tone to be played (numeric, 0 - 30s)

            %   defaults
            frequency = 1000;
            duration = 1;
            
            try
                if (nargin < 2)
                    obj.localizedError('MATLAB:minrhs');
                end

                if nargin > 4
                    obj.localizedError('MATLAB:maxrhs');
                end
            catch e
                throwAsCaller(e);
            end
            
            if nargin > 3
                duration = varargin{2};
            end
            
            if nargin > 2
                frequency = round(varargin{1});
            end

            try
                pin = arduinoio.internal.validateInputPin(pin);
                configurePinResource(obj, pin, obj.ResourceOwner, 'PWM', false);
                frequency = arduinoio.internal.validateDoubleParameterRanged('tone frequency', frequency, 0, 32767, 'Hz');
                duration = arduinoio.internal.validateDoubleParameterRanged('tone duration', duration, 0, 30, 's');
                if pin(1) == 'A'
                    pin = getPinAlias(obj, pin);
                end
                playTone(obj.Protocol, str2double(pin(2:end)), frequency, duration);
            catch e
                throwAsCaller(e);
            end
        end
        
        function register = shiftRegister(obj, model, dataPin, clockPin, varargin)
            %   Connect to the shift register controlled with the specified pins on the Arduino hardware.
            %
            %   Syntax:
            %   register = shiftRegister(a,'74HC165', dataPin, clockPin, loadPin, clockEnablePin)
            %   register = shiftRegister(a,'74HC595', dataPin, clockPin, latchPin)
            %   register = shiftRegister(a,'74HC595', dataPin, clockPin, latchPin, resetPin)
            %   register = shiftRegister(a,'74HC164', dataPin, clockPin)
            %   register = shiftRegister(a,'74HC164', dataPin, clockPin, resetPin)
            %
            %   Description:
            %   register = shiftRegister(a,model,datapin,clockpin, ...)      Connects to a shift register controlled by the specified pins
            %
            %   Example:
            %       a = arduino();
            %       register = shiftRegister(a,'74hc595','D3','D4','D7');
            %
            %   Example:
            %       a = arduino();
            %       register = shiftRegister(a,'74hc165','D3','D4','D7','D8');
            %
            %   Example:
            %       a = arduino();
            %       register = shiftRegister(a,'74hc164','D3','D4','D7');
            %
            %   Input Arguments:
            %   a        - Arduino
            %   model    - Shift register model number (character vector or string)
            %   dataPin  - Serial data pin (character vector or string)
            %   clockPin - Shift register clock pin (character vector or string)
            %   latchPin - Storage register clock pin (character vector or string)
            %   loadPin  - Parallel load or shift control pin (character vector or string)
            %   clockEnablePin - Enable shift register clock pin (character vector or string)
            %   resetPin - Master reset or clear pin (character vector or string)
            %
            %   See also spidev, i2cdev, servo, addon
            try
                register = arduinoio.shiftRegister(obj, model, dataPin, clockPin, varargin{:});
            catch e
                throwAsCaller(e);
            end
        end
        
        function encoder = rotaryEncoder(obj, channelA, channelB, varargin)
            %   Connect to the quadrature rotary encoder connected to the specified pins on the Arduino hardware.
            %
            %   Syntax:
            %   encoder = rotaryEncoder(a,channelA,channelB)            
            %   encoder = rotaryEncoder(a,channelA,channelB,ppr)
            %
            %   Description:
            %   encoder = rotaryEncoder(a,channelA,channelB)            Connects to a rotary encoder.
            %   encoder = rotaryEncoder(a,channelA,channelB,ppr)        Connects to a rotary encoder with specified pulses per revolution.
            %
            %   Example:
            %       a = arduino();
            %       encoder = rotaryEncoder(a,'D2','D3');
            %
            %   Example:
            %       a = arduino();
            %       encoder = rotaryEncoder(a,'D2','D3',10);
            %
            %   Input Arguments:
            %   a         - Arduino
            %   ChannelA  - Arduino pin connected to channel A output of encoder (character vector or string)
            %   ChannelB  - Arduino pin connected to channel B output of encoder (character vector or string)
            %   PulsesPerRevolution - Number of pulses generated per rotation revolution (numeric, default []).
            %
            %   See also spidev, i2cdev, servo, shiftRegister, addon
            
            try
                encoder = arduinoio.rotaryEncoder(obj, channelA, channelB, varargin{:});
            catch e
                throwAsCaller(e);
            end
        end
        
        function servoObj = servo(obj, pin, varargin)
            %   Attach a servo motor to specified pin on Arduino hardware.
            %
            %   Syntax:
            %   s = servo(a,pin)
            %   s = servo(a,pin,Name,Value)
            %
            %   Description:
            %   s = servo(a,pin)            Creates a servo motor object connected to the specified pin on the Arduino hardware.
            %   s = servo(a,pin,Name,Value) Creates a servo motor object with additional options specified by one or more Name-Value pair arguments.
            %
            %   Example:
            %       a = arduino();
            %       s = servo(a,'D3');
            %
            %   Example:
            %       a = arduino();
            %       s = servo(a,'D3','MinPulseDuration',1e-3,'MaxPulseDuration',2e-3);
            %
            %   Input Arguments:
            %   a   - Arduino
            %   pin - Digital pin number (character vector or string)
            %
            %   Name-Value Pair Input Arguments:
            %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value. 
            %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
            %
            %   NV Pair:
            %   'MinPulseDuration' - The pulse duration for the servo at its minimum position (numeric, 
            %                     default 5.44e-4 seconds.
            %   'MaxPulseDuration' - The pulse duration for the servo at its maximum position (numeric, 
            %                     default 2.4e-3 seconds.
            %
            %   See also i2cdev, spidev, addon
            try
                servoObj = arduinoio.Servo(obj, pin, varargin{:});
            catch e
                throwAsCaller(e);
            end
        end
        
        function i2cObj = i2cdev(obj, address, varargin)
            %   Connect to the I2C device at the specified address on the I2C bus of the Arduino hardware.
            %
            %   Syntax:
            %   device = i2cdev(a,address)
            %   device = i2cdev(a,address,Name,Value)
            %
            %   Description:
            %   device = i2cdev(a,address)      Connects to an I2C device at the specified address on the 
            %                                 default I2C bus of the Arduino hardware.
            %
            %   Example:
            %       a = arduino();
            %       tmp102 = i2cdev(a,'0x48');
            %
            %   Example:
            %       a = arduino();
            %       tmp102 = i2cdev(a,'0x48','Bus',1);
            %
            %   Input Arguments:
            %   a       - Arduino
            %   address - I2C address of device (numeric or character vector or string)
            %
            %   Name-Value Pair Input Arguments:
            %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value. 
            %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
            %
            %   NV Pair:
            %   'bus'     - The I2C bus (numeric, default 0)
            %
            %   See also spidev, servo, addon
            try
                i2cObj = arduinoio.i2cdev(obj, address, varargin{:});
            catch e
                throwAsCaller(e);
            end
        end
        
        function spiObj = spidev(obj, cspin, varargin)
            %   Connect to the SPI device on the specified chip select pin on the Arduino hardware.
            %
            %   Syntax:
            %   device = spidev(a,cspin)
            %   device = spidev(a,cspin,Name,Value)
            %
            %   Description:
            %   device = spidev(a,cspin)      Connects to an SPI device on the specified chip select pin
            %
            %   Example:
            %       a = arduino();
            %       ad5231 = spidev(a,'D10');
            %
            %   Example:
            %       a = arduino();
            %       ad5231 = spidev(a,'D10','bitorder','msbfirst','mode',3, 'bitrate', 20000000);
            %
            %   Input Arguments:
            %   a     - Arduino
            %   cspin - Chip select pin (character vector or string)
            %
            %   Name-Value Pair Input Arguments:
            %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value. 
            %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
            %
            %   NV Pair:
            %   'bitorder' - The SPI communication bit order for the device (character vector or string, e.g. msbfirst, lsbfirst)
            %   'mode'     - The SPI communication mode for clock polarity and phase (numeric, 0 - 3)
            %   'bitrate'  - The SPI communication rate for the device (numeric)
            %
            %   See also i2cdev, servo, addon
            try
                spiObj = arduinoio.spidev(obj, cspin, varargin{:});
            catch e
                throwAsCaller(e);
            end
        end
        
        function addonObj = addon(obj, libname, varargin)
            %   Connect to an add-on device on the Arduino hardware.
            %
            %   Syntax:
            %   device = addon(a,libname)
            %   device = addon(a,libname,Name,Value)
            %
            %   Description:
            %   device = addon(a,libname)      Connects to an add-on device that uses the specified library
            %
            %   Example:
            %       a = arduino('COM7','Uno','Libraries','Adafruit\MotorShieldV2');
            %       shield = addon(a,'Adafruit\MotorShieldV2');
            %
            %   Example:
            %       a = arduino('COM7','Uno','Libraries','Adafruit\MotorShieldV2');
            %       shield = addon(a,'Adafruit\MotorShieldV2','I2CAddress','0x62');
            %
            %   Input Arguments:
            %   a       - Arduino
            %   libname - The library needs to be used (character vector or string)
            %
            %   Name-Value Pair Input Arguments:
            %   Specify optional comma-separated pairs of Name,Value arguments. Name is the argument name and Value is the corresponding value. 
            %   Name must appear inside single quotes (' '). You can specify several name and value pair arguments in any order as Name1,Value1,...,NameN,ValueN.
            %
            %   NV Pair:
            %   'I2CAddress'     - The I2C address of the add-on shield device (numeric or character vector)
            %   'PWMFrequency'   - The frequency of the PWM signals that drive the DC motors (numeric)
            %
            %   See also i2cdev, servo, spidev
            
            try
                if isempty(obj.Libraries) || isempty(getValidAddonLibraries(obj))
                    obj.localizedError('MATLAB:arduinoio:general:noAddonLibraryUploaded');
                else
                    givenLibrary = [];
                    % accept string type libname, but convert to character vector
                    if isstring(libname)
                        libname = char(libname);
                    end
                    if ~ischar(libname)
                        obj.localizedError('MATLAB:arduinoio:general:invalidAddonLibraryType');
                    else
                        givenLibrary = strrep(libname, '\', '/');
                        try
                            givenLibrary = validatestring(givenLibrary, obj.Libraries); % check given libraries all exist
                        catch 
                            validAddonLibs = getValidAddonLibraries(obj);
                            obj.localizedError('MATLAB:arduinoio:general:invalidAddonLibraryValue', libname, strjoin(validAddonLibs, ', '));
                        end
                    end
                    
                    
                    constructCmd = strcat(arduinoio.internal.getLibraryClassName(givenLibrary), '(obj, varargin{:})');
                    addonObj = eval(constructCmd);
                end
            catch e
                if isequal(e.identifier, 'MATLAB:unrecognizedStringChoice')
                    validAddonLibs = getValidAddonLibraries(obj);
                        id = 'MATLAB:arduinoio:general:invalidAddonLibraryValue';
                        e = MException(id, getString(message(id, strrep(libname,'\', '\\'), strjoin(validAddonLibs, ', '))));
                end
                throwAsCaller(e);
            end
        end
        
        function addrs = scanI2CBus(obj, bus)
            %   Scan Arduino I2C bus for connected I2C devices and return the device addresses.
            %
            %   Syntax:
            %   addrs = scanI2CBus(a,bus);
            %
            %   Description: 
            %   Scans the specified Arduino hardware I2C bus for connected I2C devices, and returns a cell array of the I2C device addresses in hex. 
            %
            %   Example:
            %   TMP102 I2C device connected on I2C bus 0.
            %       a = arduino('com9');
            %       addrs = scanI2CBus(a);
            %
            %   Input Arguments:
            %   a   - Arduino
            %   bus - I2C bus number (numeric, default 0)
            %
            %   Output Arguments:
            %   addrs - I2C bus addresses in hex (cell array of character vectors)
            %
            %   See also i2cdev
            
            if nargin < 2
                bus = 0;
            end
            
            try
                terminals = obj.getI2CTerminals();
                
                if strcmp(obj.Board, 'Due')
                    buses = 0:1;
                else
                    buses = 0:floor(numel(terminals)/2)-1;
                end
                
                try
                    bus = arduinoio.internal.validateIntParameterRanged('I2C Bus', bus, 0, buses(end));
                catch
                    buses = sprintf('%d, ', buses);
                    buses = buses(1:end-2);
                    obj.localizedError('MATLAB:arduinoio:general:invalidI2CBusNumber',...
                        obj.Board, buses);
                end

                % Configure I2C pins
                if (floor(numel(terminals)-1)/2) >= bus
                    pins = getPinsFromTerminals(obj.ResourceManager, terminals);
                    sda = pins{bus*2+1};
                    scl = pins{bus*2+2};
                    
                    sdaConfig = obj.configurePinResource(sda);
                    if ~(strcmp(sdaConfig, 'Unset') || strcmp(sdaConfig, 'I2C'))
                        obj.localizedError('MATLAB:arduinoio:general:reservedI2CPins', ...
                            obj.Board, sda, scl, sda, sdaConfig);
                    end
                    
                    sclConfig = obj.configurePinResource(scl);
                    if ~(strcmp(sclConfig, 'Unset') || strcmp(sclConfig, 'I2C'))
                        obj.localizedError('MATLAB:arduinoio:general:reservedI2CPins', ...
                            obj.Board, sda, scl, scl, sclConfig);
                    end
                    % If all validations have passed, reserve the sda/scl pins
                    % for I2C
                    configurePinResource(obj, sda, '', 'I2C', false);
                    configurePinResource(obj, scl, '', 'I2C', false);
                end
                
                libID = getLibraryID(obj, 'I2C');
                addrs = scanI2CBus(obj.Protocol, libID, bus);
                
                setSharedResourceProperty(obj, 'I2C', 'I2CIsUsed', true);
            catch e
                throwAsCaller(e);
            end
        end
    end
    
    % Hide inherited methods
    methods (Hidden)
        function addprop(obj, prop)
            % provide access to the implementation
            obj.addprop@dynamicprops(prop);
        end
    end

    %% Private methods
    methods(Access = private)    
        function output = parseInputs(obj, inputs)
            % Parse validate given inputs
            nInputs = numel(inputs);
            
            output.Address = [];
            output.Board = [];
            output.Libraries = {};
            output.TraceOn = false;
            output.ForceBuildOn = false;
            output.LibrariesSpecified = false;
            
            if nInputs == 0
                return;
            end
            % Step 1 - Derive connection type based on first input parameter
            if nInputs > 0 
                param = inputs{1};
                if ~ischar(param) && ~isstring(param)
                    obj.localizedError('MATLAB:arduinoio:general:invalidAddressType');
                end
                if isstring(param)
                    param = char(param);
                end
                [status, address] = validateAddressExistence(obj.Utility, arduinoio.internal.ConnectionTypeEnum.Serial, param);
                if status
                    obj.ConnectionType = arduinoio.internal.ConnectionTypeEnum.Serial;
                    output.Address = address;
                else
                    [status, address] = validateAddressExistence(obj.Utility, arduinoio.internal.ConnectionTypeEnum.WiFi, param);
                    if status
                        obj.ConnectionType = arduinoio.internal.ConnectionTypeEnum.WiFi;
                        output.Address = address;
                        output.Port = arduinoio.internal.ArduinoConstants.DefaultTCPIPPort;
                    elseif ispc||ismac % Windows and Mac also support Bluetooth connection
                        [status, address] = validateAddressExistence(obj.Utility, arduinoio.internal.ConnectionTypeEnum.Bluetooth, param);
                        if status
                            obj.ConnectionType = arduinoio.internal.ConnectionTypeEnum.Bluetooth;
                            output.Address = address;
                        end
                    end
                end
                if isempty(output.Address)
                    if ispc || ismac
                        obj.localizedError('MATLAB:arduinoio:general:invalidAddressPCMac', param);
                    else
                        obj.localizedError('MATLAB:arduinoio:general:invalidAddressLinux', param);
                    end
                end
            end
            % Step 2 - Get board parameter (Port and Board parameters are 
            % required before specifying any parameter-value pairs)
            if nInputs > 1
                board = inputs{2};
                % validate Board data type
                if ~ischar(board) && ~isstring(board)
                    obj.localizedError('MATLAB:arduinoio:general:invalidBoardType');
                end
                if isstring(board)
                    board = char(board);
                end
                output.Board = board;
            end
            
            % Step 3 - Parse additional NV parameters
            if nInputs > 2
                switch obj.ConnectionType
                    case arduinoio.internal.ConnectionTypeEnum.Serial
                        % Only serial connection type allows
                        % specifying libraries/trace/force, etc.
                        inputs = inputs(3:end);
                        p = inputParser;
                        p.PartialMatching = true;
                        addParameter(p, 'Libraries', {''});
                        addParameter(p, 'TraceOn', false, @islogical);
                        addParameter(p, 'ForceBuildOn', false, @islogical);
                        try
                            parse(p, inputs{:});
                        catch e
                            switch e.identifier
                                case 'MATLAB:InputParser:ParamMissingValue'
                                    message = e.message;
                                    index = strfind(message, '''');
                                    str = message(index(1)+1:index(2)-1);
                                    try 
                                        validatestring(str, {'Libraries','TraceOn','ForceBuildOn'});
                                    catch
                                        obj.localizedError('MATLAB:arduinoio:general:paramNotInPairs');
                                    end
                                    param = e.message(index(1):index(2));
                                    obj.localizedError('MATLAB:arduinoio:general:missingParamValue', param);
                                case 'MATLAB:InputParser:UnmatchedParameter'
                                    message = e.message;
                                    index = strfind(message, '''');
                                    param = e.message(index(1):index(2));
                                    obj.localizedError('MATLAB:arduinoio:general:invalidParam', param);
                                otherwise
                                    throwAsCaller(e);
                            end
                        end
                        
                        % 3. Validate Libraries data type
                        if ~ischar(p.Results.Libraries) && ~iscellstr(p.Results.Libraries) && ~isstring(p.Results.Libraries)
                            obj.localizedError('MATLAB:arduinoio:general:invalidLibrariesType');
                        end
                        % Convert char vector to cell array of char vectors.
                        % For example, 'servo, i2c' -> {'servo', 'i2c'}
                        libs = p.Results.Libraries;
                        if isstring(libs)
                            if length(libs) == 1 % single string
                                libs = char(libs);
                            else % array of strings
                                libs = cellstr(libs);
                            end
                        end
                        if ischar(libs) && ~isempty(libs)
                            libs = strtrim(strsplit(libs, ','));
                        end
                        output.Libraries     = libs;
                        output.TraceOn       = p.Results.TraceOn;
                        output.ForceBuildOn  = p.Results.ForceBuildOn;
                        output.LibrariesSpecified = true;
                        if isempty(output.Libraries) % User specifies '' or {} or []
                            output.Libraries = {};
                        elseif isempty(output.Libraries{1}) % User does not specify 'Libraries' pv pair -> default value of {''}
                            output.Libraries = {};
                            output.LibrariesSpecified = false;
                        end
                    case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                        % No configuration is allowed if connect with Bluetooth
                        obj.localizedError('MATLAB:arduinoio:general:wlLibChangeNotSupported', 'Bluetooth');
                    case arduinoio.internal.ConnectionTypeEnum.WiFi
                        % Only an optional parameter Port is
                        % allowed to be specified other than board
                        % and address
                        if nInputs > 3
                            obj.localizedError('MATLAB:arduinoio:general:wlLibChangeNotSupported', 'WiFi');
                        end
                        try
                            validateattributes(inputs{3},{'double'}, {'finite','scalar','integer','>', arduinoio.internal.ArduinoConstants.MinPortValue,'<=', arduinoio.internal.ArduinoConstants.MaxPortValue})
                            output.Port = inputs{3};
                        catch
                            obj.localizedError('MATLAB:arduinoio:general:invalidWiFiPort',num2str(arduinoio.internal.ArduinoConstants.MinPortValue),num2str(arduinoio.internal.ArduinoConstants.MaxPortValue));
                        end
                end
            end
        end
        
        function initProperties(obj, inputs) 
        % Populate all properties of arduino object based on given inputs
            output = parseInputs(obj, inputs);
            [isPref, oldPref] = getPreference(obj.Utility);
            % Backward compatibility for pre-17a releases, where
            % connection type is not saved into preferences.
            if ~isfield(oldPref, 'ConnectionType')||isempty(oldPref.ConnectionType)
                isPref = false;
            end
        
            % No parameters given:
            % If no last preference, auto-detect serial port
            % If last preference exists, reuse last preference if address exists
            % If last preference exists, auto-detect serial if address no longer exists
            if isempty(output.Address)
                if isPref
                    obj.ConnectionType = oldPref.ConnectionType;
                    if validateAddressExistence(obj.Utility, oldPref.ConnectionType, oldPref.Address)
                        % Unix systems assigns same serial port for
                        % different boards. Therefore always
                        % auto-detect the serial port to ensure
                        % correct board is used rather than blindly
                        % reuse the last preference.
                        % Skip auto-detection for Adafruit EZ-Link ports
                        if isunix && (obj.ConnectionType==arduinoio.internal.ConnectionTypeEnum.Serial) && ~contains(oldPref.Address,'EZ-Link')
                            port = oldPref.Address;
                            % Find port's original string if given a
                            % symlink on Linux
                            if ~ismac
                               port = getOriginalPort(obj.Utility, oldPref.Address);
                            end
                            portInfo = validatePort(obj.Utility, port);
                            output.Address = oldPref.Address;
                            output.Board   = portInfo.board;
                        else
                            output.Address = oldPref.Address;
                            output.Board = oldPref.Board;
                            output.TraceOn = oldPref.TraceOn;
                            if obj.ConnectionType==arduinoio.internal.ConnectionTypeEnum.WiFi
                                output.Port = oldPref.Port;
                            end
                        end
                    else
                        obj.ConnectionType = arduinoio.internal.ConnectionTypeEnum.Serial;
                        % auto-detect
                        portInfo = validatePort(obj.Utility);
                        output.Address = portInfo.port;
                        output.Board   = portInfo.board;
                    end
                else % No previous preference - assume serial connection and auto-detect
                    obj.ConnectionType = arduinoio.internal.ConnectionTypeEnum.Serial;
                    portInfo = validatePort(obj.Utility);
                    output.Address = portInfo.port;
                    output.Board   = portInfo.board;
                end
                % Only given address:
                % Regardless of preference exists or not, always auto-detect based on port if serial communication type
                % If last preference exists, reuse last preference if type and address are the same for wireless
                % If last preference exists but type or address are different, error for wireless
                % If no last preference, error for wireless
            elseif isempty(output.Board)
                if obj.ConnectionType==arduinoio.internal.ConnectionTypeEnum.Serial
                    % auto-detect with port
                    port = output.Address;
                    if isunix && ~ismac
                        % account for Linux symlink
                        port = getOriginalPort(obj.Utility, output.Address);
                    end
                    portInfo = validatePort(obj.Utility, port);
                    output.Address  = output.Address;
                    output.Board    = portInfo.board;
                else
                    if isPref && (obj.ConnectionType==oldPref.ConnectionType) && strcmpi(output.Address, oldPref.Address)
                        % Reuse last preference board for wireless
                        output.Board = oldPref.Board;
                        if obj.ConnectionType==arduinoio.internal.ConnectionTypeEnum.WiFi
                            output.Port = oldPref.Port;
                        end
                    else
                        % No last preference, assume first-time use and error for configure
                        obj.localizedError('MATLAB:arduinoio:general:firstTimeSetup');
                    end
                end
            end
            % Add dynamic properties according to connection type
            switch obj.ConnectionType
                case arduinoio.internal.ConnectionTypeEnum.Serial
                    addprop(obj, 'Port');
                    obj.Port = output.Address;
                    addressKey = obj.Port;
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    addprop(obj, 'DeviceAddress');
                    addprop(obj, 'Channel');
                    obj.DeviceAddress = output.Address;
                    % The supported Bluetooth devices all have one channel
                    obj.Channel = 1;
                    addressKey = obj.DeviceAddress;
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    addprop(obj, 'DeviceAddress');
                    addprop(obj, 'Port');
                    obj.DeviceAddress = output.Address;
                    obj.Port = output.Port;
                    addressKey = obj.DeviceAddress;
            end
            
             % Check if transport layer already occupied, or arduino connection already exists.
             if isKey(obj.ConnectionMap, addressKey)
                 storedBoard = obj.ConnectionMap(addressKey);
                 obj.localizedError('MATLAB:arduinoio:general:connectionExists', storedBoard, addressKey);
             end
             
            obj.Board = output.Board;
            obj.Libraries = output.Libraries;
            obj.TraceOn = output.TraceOn;
            obj.ForceBuildOn = output.ForceBuildOn;
            obj.LibrariesSpecified = output.LibrariesSpecified;
        end
        
        function initUtility(obj)
            obj.Utility = arduinoio.internal.UtilityCreator.getInstance();
        end
        
        function initResourceManager(obj, boardType)
            obj.ResourceManager = arduinoio.internal.ResourceManager(boardType);
            supportedBoards = arduinoio.internal.ArduinoConstants.getSupportedBoards(obj.ConnectionType);
            switch obj.ConnectionType
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    try
                        obj.Board = validatestring(obj.Board, supportedBoards);
                    catch
                        obj.localizedError('MATLAB:arduinoio:general:invalidBluetoothBoard', obj.Board, strjoin(supportedBoards, ', '));
                    end
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    try
                        obj.Board = validatestring(obj.Board, supportedBoards);
                    catch
                        obj.localizedError('MATLAB:arduinoio:general:invalidWiFiBoard', obj.Board, strjoin(supportedBoards, ', '));
                    end
            end
        end
        
        function flag = initCommunication(obj, connectionObj, initTimeout)
            flag = false;
            try
                obj.Protocol = arduinoio.internal.MWProtocol(connectionObj, initTimeout, obj.TraceOn); 
                flag = true;
            catch e
                if strcmpi(e.identifier, 'MATLAB:arduinoio:general:openFailed')
                    throwAsCaller(e);
                end
            end
        end
        
        function initServerConnection(obj)
            % If serial object is not passed in, create one with
            % default value
            buildInfo = getBuildInfo(obj.ResourceManager);
            
            switch obj.ConnectionType
                case arduinoio.internal.ConnectionTypeEnum.Serial
                    % All 3.3V 8MHz boards use baud rate 57600bps due to reports of them not being able to reliably support 115200bps.
                    % 1. http://forum.arduino.cc/index.php?topic=54623.0
                    % 2. https://forum.mysensors.org/topic/1483/trouble-with-115200-baud-on-3-3v-8mhz-arduino-like-serial-gateway-solution-change-baudrate/2
                    % 3. http://www.avrfreaks.net/forum/modifying-arduino-nano-v30-crystal-speed
                    % All other boards use baud rate 115200bps
                    obj.Connection = serial(obj.Port, 'BaudRate', str2double(buildInfo.BaudRate));
                    obj.Connection.InputBufferSize = 65536;
                    obj.Connection.OutputBufferSize = 65536;
                    obj.Connection.Timeout = 10;
                    obj.Connection.Terminator = 'LF'; % New line feed
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    obj.Connection = Bluetooth(obj.DeviceAddress, obj.Channel);
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    obj.Connection = matlabshared.network.internal.TCPClient(obj.DeviceAddress, obj.Port);
                    obj.Connection.ConnectTimeout = 10;
                otherwise
                    % unsupported 
            end
            
            successFlag = initCommunication(obj, obj.Connection, buildInfo.InitTimeout); 

            if ~successFlag % open serial port failed or expected number of bytes was not received
                if obj.ConnectionType == arduinoio.internal.ConnectionTypeEnum.Serial
                    if ~obj.LibrariesSpecified
                        obj.Libraries = obj.DefaultLibList;
                    end
                    obj.Libraries = validateLibraries(obj.Utility, obj.Libraries); % check existence and completeness of libraries
                    obj.LibraryIDs = 0:(length(obj.Libraries)-1);
                    buildInfo = prepareBuildInfo(buildInfo);
                    msg = updateServer(obj.Utility, buildInfo);
                    % Making this a special case here because try/catch
                    % error message has a limit which truncates the
                    % upload error result
                    assert(isempty(msg), msg);
                    successFlag = initCommunication(obj, obj.Connection, buildInfo.InitTimeout);
                    if ~successFlag
                        obj.localizedError('MATLAB:arduinoio:general:incorrectServerInitialization');
                    end
                    validateBoardPortMatch();
                else
                    obj.localizedError('MATLAB:arduinoio:general:wlConnectionFailed');
                end
            else
                % check already downloaded libraries if any and retrieve IDs
                % If nothing has been downloaded, update server code
                % If server code exists but libraries are different, update
                % server code
                % If server code exists and libraries are the same, reuse old
                % library IDs
                [getInfoSuccessFlag, oldVersion, oldLibNames, oldLibIDs, oldBoard, oldTraceOn] = getServerInfo(obj.Protocol);
                if ~obj.LibrariesSpecified % no libraries are given
                    if getInfoSuccessFlag % use the retrieved libs from the board
                        obj.Libraries = oldLibNames;
                    else % use default libraries
                        obj.Libraries = obj.DefaultLibList;
                    end
                else % given libraries
                    obj.Libraries = validateLibraries(obj.Utility, obj.Libraries); % check existence and completeness of libraries
                end
                obj.LibraryIDs = 0:(length(obj.Libraries)-1);
                if ~getInfoSuccessFlag || ...
                   ~strcmpi(oldVersion, obj.LibVersion) || ~isempty(setxor(oldLibNames,obj.Libraries)) || ...
                   (oldTraceOn ~= obj.TraceOn) || ~strcmpi(oldBoard, obj.Board) || obj.ForceBuildOn
                    if obj.ConnectionType == arduinoio.internal.ConnectionTypeEnum.Serial
                        buildInfo = prepareBuildInfo(buildInfo);
                        closeTransportLayer(obj.Protocol);
                        msg = updateServer(obj.Utility, buildInfo);
                        % Making this a special case here because try/catch
                        % error message has a limit which truncates the
                        % upload error result
                        assert(isempty(msg), msg);
                        openTransportLayer(obj.Protocol, buildInfo.InitTimeout);
                        validateBoardPortMatch();
                    else
                        % Only reasons it could come here are 1) getServerInfo
                        % fails 2) board mismatch since all other parameters 
                        % are retrieved from board for wireless connection
                        if ~getInfoSuccessFlag
                            obj.localizedError('MATLAB:arduinoio:general:wlConnectionFailed');
                        else
                            obj.localizedError('MATLAB:arduinoio:general:wlBoardMismatch', oldBoard, obj.DeviceAddress, oldBoard);
                        end
                    end
                else
                    updateLibraryIDs(obj, oldLibNames, oldLibIDs);
                end
            end
            
            if obj.ConnectionType == arduinoio.internal.ConnectionTypeEnum.Serial && buildInfo.InitTimeout>=0
                % Initialize all pins state to input
                resetPinsState(obj.Protocol);
            end
            
            function buildInfo = prepareBuildInfo(buildInfo)
                buildInfo.ConnectionType = obj.ConnectionType;
                buildInfo.Port = obj.Port;
                buildInfo.Libraries = obj.Libraries;
                buildInfo.TraceOn = obj.TraceOn;
                if buildInfo.TraceOn
                    buildInfo.ShowUploadResult = true;
                else
                    buildInfo.ShowUploadResult = false;
                end
                disp(obj.getLocalizedText('MATLAB:arduinoio:general:programmingArduino', buildInfo.Board, buildInfo.Port));
            end
            
            function validateBoardPortMatch()
                % Below code is a workaround for Arduino CLI's incapability
                % to report error code when another arduino board's port is
                % given for the current board
                [flag, ~, ~, ~, board, ~] = getServerInfo(obj.Protocol);
                if ~flag || ~strcmp(board, obj.Board)
                    obj.localizedError('MATLAB:arduinoio:general:failedUpload', obj.Board, obj.Port);
                end
            end
        end
        
        function updateLibraryIDs(obj, libNames, libIDs)
            for whichLib = 1:numel(obj.Libraries)
                IndexC = strfind(libNames, obj.Libraries{whichLib});
                obj.LibraryIDs(whichLib) = libIDs(not(cellfun('isempty', IndexC)));
            end
        end
        
        function libs = getValidAddonLibraries(obj)
            libs = {};
            temp = strfind(obj.Libraries, '/');
            for libCount = 1:length(temp)
                if ~isempty(temp{libCount})
                    libs = [libs, obj.Libraries(libCount)]; %#ok<AGROW>
                end
            end
        end
    end
    
    %% Public methods for arduino libraries implementing LibraryBase
    methods(Access = {?arduinoio.LibraryBase,...
                      ?arduinoio.AddonBase,...
                      ?arduinoio.accessor.UnitTest})
                  
        function id = getLibraryID(obj, libName)
            if contains(strjoin(obj.Libraries), libName)
                id = sum(obj.LibraryIDs.*strcmp(obj.Libraries, libName));
            else
                obj.localizedError('MATLAB:arduinoio:general:libraryNotUploaded', libName);
            end
        end
        
        function count = getAvailableRAM(obj)
            count = getAvailableRAM(obj.Protocol);
        end
        
        function value =  sendAddonMessage(obj, libName, cmd, timeout)
            libID = getLibraryID(obj, libName);
            if nargin < 4
                value = obj.Protocol.sendAddonMessage(libID, cmd);
            else
                value = obj.Protocol.sendAddonMessage(libID, cmd, timeout);
            end
        end
        
        %% Arduino Custom Addon's API
        % BEGIN
        
        function result = getMCU(obj)
            result = obj.ResourceManager.MCU;
        end
        
        function out = getPinAlias(obj, pin)
            try
                out = obj.ResourceManager.getPinAlias(pin);
            catch e
                throwAsCaller(e);
            end
        end
        
        function terminals = getTerminalsFromPins(obj, pins)
            try 
                terminals = obj.ResourceManager.getTerminalsFromPins(pins);
            catch e
                throwAsCaller(e);
            end
        end
        
        function pins = getPinsFromTerminals(obj, terminals)
            if isempty(terminals)
                pins = {};
                return;
            end
            
            try 
                pins = obj.ResourceManager.getPinsFromTerminals(terminals);
            catch e
                throwAsCaller(e);
            end
        end
        
        function result = isTerminalAnalog(obj, terminal)
            try
                result = obj.ResourceManager.isTerminalAnalog(terminal);
            catch e
                throwAsCaller(e);
            end
        end
        
        function result = isTerminalDigital(obj, terminal)
            try
                result = obj.ResourceManager.isTerminalDigital(terminal);
            catch e
                throwAsCaller(e);
            end
        end
        
        function value = getTerminalMode(obj, terminal)
            try
                value = obj.ResourceManager.getTerminalMode(terminal);
            catch e
                throwAsCaller(e);
            end
        end
        
        function terminals = getI2CTerminals(obj, bus)
            try
                if nargin < 2
                    bus = 0;
                end
                terminals = obj.ResourceManager.getI2CTerminals(bus);
            catch e
                throwAsCaller(e);
            end
        end
        
        function terminals = getSPITerminals(obj)
            try 
                terminals = obj.ResourceManager.getSPITerminals();
            catch e
                throwAsCaller(e);
            end
        end
        
        function terminals = getServoTerminals(obj)
            terminals = obj.ResourceManager.getServoTerminals();
        end
        
        function terminals = getPWMTerminals(obj)
            terminals = obj.ResourceManager.getPWMTerminals();
        end
        
        function terminals = getInterruptTerminals(obj)
            terminals = obj.ResourceManager.getInterruptTerminals();
        end
        
        function validatePin(obj, pin, type)
            try
                % Validate terminals does the actual validation based on
                % the Arduino board.
                terminal = getTerminalsFromPins(obj, pin);
                obj.ResourceManager.validateTerminal(terminal, type);
            catch e
                throwAsCaller(e);
            end
        end
        
        function varargout = configurePinResource(obj, pin, resourceOwner, mode, forceConfig)
            try
                if nargout > 0
                    narginchk(2, 2);
                    varargout = {configurePin(obj.ResourceManager, pin)};
                else
                    narginchk(4, 5);
                    prevMode = configurePin(obj.ResourceManager, pin);
                    if nargin < 5
                        forceConfig = false;
                    end
                    
                    isI2CUsed = getSharedResourceProperty(obj, 'I2C', 'I2CIsUsed');
                    
                    configurePin(obj.ResourceManager, pin, resourceOwner, mode, forceConfig, isI2CUsed);
                    mode = configurePin(obj.ResourceManager, pin);
                    if strcmp(mode, 'Unset')
                        configurePin(obj.Protocol, pin, 'DigitalOutput');
                        writeDigitalPin(obj.Protocol, pin, 0);
                        configurePin(obj.Protocol, pin, 'DigitalInput');
                    elseif ismember(mode, {'DigitalInput', 'DigitalOutput', 'Pullup', 'AnalogInput'})
                        if ~strcmp(prevMode, mode) && ...
                                ~(ismember(prevMode, {'DigitalInput', 'AnalogInput'}) && ismember(mode, {'DigitalInput', 'AnalogInput'}))
                            % change pin mode on the board only when the new mode
                            % is different from the previous mode plus it is not a
                            % conversion between DigitalInput and AnalogInput or
                            % vice versa
                            configurePin(obj.Protocol, pin, mode)
                        end
                    end
                end
            catch e
                throwAsCaller(e);
            end
        end
        
        % Resource Count Methods
        function count = incrementResourceCount(obj, resourceName)
            try
                count = obj.ResourceManager.incrementResourceCount(resourceName);
            catch e
                throwAsCaller(e);
            end
        end
        
        function count = decrementResourceCount(obj, resourceName)
            try
                count = obj.ResourceManager.decrementResourceCount(resourceName);
            catch e
                throwAsCaller(e);
            end
        end
        
        function count = getResourceCount(obj, resourceName)
            try
                count = obj.ResourceManager.getResourceCount(resourceName);
            catch e
                throwAsCaller(e);
            end
        end
        
        % Resource Slots
        function slot = getFreeResourceSlot(obj, resourceName)
            try
                slot = obj.ResourceManager.getFreeResourceSlot(resourceName);
            catch e
                throwAsCaller(e);
            end
        end
        
        function clearResourceSlot(obj, resourceName, slot)
            try
                obj.ResourceManager.clearResourceSlot(resourceName, slot);
            catch e
                throwAsCaller(e);
            end
        end
        
        % Resource Properties
        function setSharedResourceProperty(obj, resourceName, propertyName, propertyValue)
            try
                obj.ResourceManager.setSharedResourceProperty(resourceName, propertyName, propertyValue);
            catch e
                throwAsCaller(e);
            end
        end
        
        function value = getSharedResourceProperty(obj, resourceName, propertyName)
            try 
                value = obj.ResourceManager.getSharedResourceProperty(resourceName, propertyName);
            catch e
                throwAsCaller(e);
            end
        end
        
        % Get Pin ResourceOwner
        function resourceOwner = getResourceOwner(obj, terminal)
            try
                resourceOwner = getResourceOwner(obj.ResourceManager, terminal);
            catch e
                throwAsCaller(e);
            end
        end
        
        % END
        
    end
    
    methods (Access = protected)
        function displayScalarObject(obj)
            header = getHeader(obj);
            disp(header);
            
            sAvailablePins = ['{''', obj.AvailablePins{1}, '-D', num2str(obj.ResourceManager.TerminalsDigital(end)), ''', ''A0-', obj.AvailablePins{end}, '''}'];
            
            % Display main options
            switch obj.ConnectionType
                case arduinoio.internal.ConnectionTypeEnum.Serial
                    fprintf('                    Port: ''%s''\n', obj.Port);
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    fprintf('           DeviceAddress: ''%s''\n', obj.DeviceAddress);
                    fprintf('                 Channel: %d\n', obj.Channel);
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    fprintf('           DeviceAddress: ''%s''\n', obj.DeviceAddress);
                    fprintf('                    Port: %d\n', obj.Port);
                otherwise
            end
                    fprintf('                   Board: ''%s''\n', obj.Board);
                    fprintf('           AvailablePins: %s\n', sAvailablePins);
            if ~isempty(obj.Libraries)
            		fprintf('               Libraries: {''%s''}\n', ...
                	arduinoio.internal.renderCellArrayOfCharVectorsToCharVector(obj.Libraries, ''', '''));
            else
                    fprintf('               Libraries: {}\n');
            end
            fprintf('\n');
                  
            % Allow for the possibility of a footer.
            footer = getFooter(obj);
            if ~isempty(footer)
                disp(footer);
            end
        end
    end
end
                                        