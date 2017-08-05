classdef SelectConnectionScreen < matlab.hwmgr.internal.hwsetup.SelectionWithRadioGroup
    %SELECTCONNECTIONSCREEN The SelectConnectionScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The SelectConnectionScreen is used to allow users to choose the final
    % board and host computer connection type.

    % Copyright 2016-2017 The MathWorks, Inc.

    properties(Access = public)
        % ImageFiles - Cell array of fullpaths to the image files. The
        % number of elements in ImageFiles should be equal to the number of
        % items in the radio group
        ImageFiles = {};
        %NetworkConfigPanel - Panel for all network configuration
        NetworkConfigPanel
        %ReuseConfigCheckboxLabel - Text label for reuse config checkbox
        ReuseConfigCheckboxLabel
        %ReuseConfigCheckbox - Checkbox to reuse existing network configuration
        ReuseConfigCheckbox
        %EncryptionRadioGroup - Radio group for selecting encryption type
        EncryptionRadioGroup
        %KeyEditText - Edit field for Key
        KeyEditText
        %KeyIndexEditText - Edit field for Key Index
        KeyIndexEditText
        %SSIDEditText - Edit field for SSID
        SSIDEditText
        %PasswdEditText - Edit field for password
        PasswdEditText
        %PortEditText - Edit field for TCP/IP port
        PortEditText
        %KeyLabelText - Label that shows specify Key
        KeyLabelText
        %KeyIndexLabelText - Lable that shows specify Key Index
        KeyIndexLabelText
        %SSIDLabelText - Label that shows specify ssid text
        SSIDLabelText
        %PasswdLabelText - Label that shows specify password text
        PasswdLabelText
        %PortLabelText - Label that shows specify TCP/IP port text
        PortLabelText
        %StaticIPCheckbox - Checkbox that allows static IP
        StaticIPCheckbox
        %StaticIPEditText - Edit field for static IP address
        StaticIPEditText
        %StaticIPLabelText - Label that shows specify ip address
        StaticIPLabelText
        %BluetoothNoteLabelText - Label that shows Bluetooth connection note
        BluetoothNoteLabelText
    end
    
    properties(Access = private, Constant = true)
        InitPanelPosition = [20 500 200 250]
        PositionOff = [20 500 30 50]
        FontSize = 10
    end

    methods(Access = 'public')
        function obj = SelectConnectionScreen(workflow)
            % Validate that only ArduinoWorkflow
            % can access the screen
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.SelectionWithRadioGroup(workflow);
                
            obj.Title.Text = message('MATLAB:arduinoio:general:SelectConnectionScreenTitle').getString;
            obj.Description.Text = message('MATLAB:arduinoio:general:SelectConnectionScreenDescription').getString;
            obj.Description.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            obj.Description.Position = [20 340 430 40];
            
            % Set the ImageFiles property to store all images files to be displayed 
            if strcmpi(computer, 'GLNXA64')
                obj.ImageFiles = {...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_usb_connection.png'),...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_wifi_connection.png')};
            else
                obj.ImageFiles = {...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_usb_connection.png'),...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_bluetooth_connection.png'),...
                    fullfile(obj.Workflow.ResourcesDir, 'arduino_wifi_connection.png')};
            end

            % Set radio group for type selection
            obj.SelectionRadioGroup.Title =  message('MATLAB:arduinoio:general:supportedTypesText').getString;
            obj.SelectionRadioGroup.Items = arduinoio.internal.ArduinoConstants.getSupportedConnectionTypes;
            obj.SelectionRadioGroup.SelectionChangedFcn = @obj.radioSelectCallback;            
            if ispc || ismac
                obj.SelectionRadioGroup.Position = [20 280 200 80];
            else
                obj.SelectionRadioGroup.Position = [20 270 200 80];
            end
            
            % Set up Bluetooth connection note
            if ispc||ismac
                pos = [20,15,430,40];
            else
                pos = obj.PositionOff;
            end
            obj.BluetoothNoteLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,...
                message('MATLAB:arduinoio:general:SelectConnectionScreenBTNote').getString, pos, obj.FontSize);
                    
            % Set up WiFi configuration panel
            obj.NetworkConfigPanel = matlab.hwmgr.internal.hwsetup.Panel.getInstance(obj.ContentPanel);
            obj.NetworkConfigPanel.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            obj.NetworkConfigPanel.Position = obj.InitPanelPosition;
            obj.NetworkConfigPanel.Title = 'Network Settings';
%             obj.NetworkConfigPanel.BorderType = 'none';
            % Set up WiFi reuse configuration checkbox
            obj.ReuseConfigCheckboxLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:retrieveIPText').getString, [40 500 400 40], obj.FontSize);
            obj.ReuseConfigCheckbox = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.ContentPanel, '', obj.PositionOff, @obj.reuseConfigCallback, false);
            % Set up WiFi encryption radio group
            types = arduinoio.internal.ArduinoConstants.SupportedEncryptionTypes;
            obj.EncryptionRadioGroup = arduinoio.setup.internal.ScreenHelper.buildRadioGroup(obj.NetworkConfigPanel, ...
                types, message('MATLAB:arduinoio:general:SelectConnectionScreenEncryptionText').getString, obj.PositionOff, @obj.setEncryption, 1);
            % Set up WiFi info edit fields
            obj.SSIDLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'SSID *', obj.PositionOff, obj.FontSize);
            obj.SSIDEditText = matlab.hwmgr.internal.hwsetup.EditText.getInstance(obj.NetworkConfigPanel);
            obj.SSIDEditText.TextAlignment = 'left';
            obj.SSIDEditText.Position = obj.PositionOff;
            obj.SSIDEditText.Text = '';
            obj.SSIDEditText.ValueChangedFcn = @obj.setSSID;
            obj.PasswdLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'Password *', obj.PositionOff, obj.FontSize);
            obj.PasswdEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '', obj.PositionOff, @obj.setPassword);
            obj.KeyLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'Key *', obj.PositionOff, obj.FontSize);
            obj.KeyEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '', obj.PositionOff, @obj.setKey);
            obj.KeyIndexLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'Key Index *', obj.PositionOff, obj.FontSize);
            obj.KeyIndexEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '', obj.PositionOff, @obj.setKeyIndex);
            obj.PortLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'Port *', obj.PositionOff, obj.FontSize);
            obj.PortEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '9500', obj.PositionOff, @obj.setTCPIPPort);
            obj.StaticIPCheckbox = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.NetworkConfigPanel, 'Use static IP address', obj.PositionOff, @obj.staticIPCallback, false);
            obj.StaticIPLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.NetworkConfigPanel, 'IP address *', obj.PositionOff, obj.FontSize);
            obj.StaticIPEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.NetworkConfigPanel, '', obj.PositionOff, @obj.setStaticIP);
            
            obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:SelectConnectionScreenAboutSelection').getString;
            obj.HelpText.WhatToConsider = '';
            % Show default image.
            updateConnectionImage(obj);
        end

        function id = getPreviousScreenID(~)
            id = 'arduinoio.setup.internal.DriverInstallResultScreen';
        end
        
        function  id = getNextScreenID(obj)
            % If WiFi
            if obj.Workflow.ConnectionType==arduinoio.internal.ConnectionTypeEnum.WiFi 
                if obj.Workflow.SkipProgram
                    id = 'arduinoio.setup.internal.ObtainIPScreen';
                else
                    checkNetworkSettings(obj);
                    id = 'arduinoio.setup.internal.UpdateServerScreen';
                end
            else
                id = 'arduinoio.setup.internal.UpdateServerScreen';
            end
            
        end
        
        function show(obj)
            %Overwrite show method to hide Back button if entered with
            %arduinosetup
            show@matlab.hwmgr.internal.hwsetup.TemplateBase(obj)
            if obj.Workflow.LaunchByArduinoSetup
                obj.BackButton.Visible = 'off';
            end
        end
    end

    %% Widget callback methods
    methods(Access = private)
        function radioSelectCallback(obj, src, ~)
            %Function that is invoked when a radio button is selected. This 
            %function updates the selection.
            switch src.Value
                case 'USB'
                    obj.Workflow.ConnectionType = arduinoio.internal.ConnectionTypeEnum.Serial;
                    if ispc||ismac % only show Bluetooth verbiage on Windows and Mac
                        showBluetoothNote(obj);
                    end
                    hideNetworkSettings(obj);
                    obj.HelpText.WhatToConsider = '';
                    obj.NextButton.Enable = 'on';
                case 'Bluetooth®'
                    obj.Workflow.ConnectionType = arduinoio.internal.ConnectionTypeEnum.Bluetooth;
                    showBluetoothNote(obj);
                    hideNetworkSettings(obj);
                    obj.HelpText.WhatToConsider = '';
                case 'WiFi'
                    obj.Workflow.ConnectionType = arduinoio.internal.ConnectionTypeEnum.WiFi;
                    hideBluetoothNote(obj);
                    showNetworkSettings(obj);
                    if obj.ReuseConfigCheckbox.Value
                        disable(obj.NetworkConfigPanel);
                    end
                    obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:SelectConnectionScreenWhatToConsider').getString;
                    obj.NextButton.Enable = 'on';
            end
            updateConnectionImage(obj);
        end
        
        function updateConnectionImage(obj)
            %Function that updates the image displayed on the screen based
            %on selected connection type
            switch obj.Workflow.ConnectionType
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    obj.SelectedImage.Position = [210 20 250 330];
                case arduinoio.internal.ConnectionTypeEnum.Serial
                    obj.SelectedImage.Position = [20 50 430 240];
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    obj.SelectedImage.Position = [20 80 430 240];
            end
            file = obj.ImageFiles{obj.SelectionRadioGroup.ValueIndex};
            obj.SelectedImage.ImageFile = file;
        end
        
        function reuseConfigCallback(obj, src, ~)
            %Function that updates network settings display
            if src.Value % reuse configuration
                disable(obj.NetworkConfigPanel);
            else % specify new configuration
                enable(obj.NetworkConfigPanel);
            end
            obj.Workflow.SkipProgram = src.Value;
        end
        
        function staticIPCallback(obj, src, ~)
            %Function that shows/hides static ip address edit text
            if src.Value
                obj.Workflow.UseStaticIP = true;
                updateStaticIPSettings(obj);
            else
                obj.Workflow.UseStaticIP = false;
                obj.StaticIPEditText.Position = obj.PositionOff;
                obj.StaticIPLabelText.Position = obj.PositionOff;
            end
        end
        
        function setEncryption(obj, src, ~)
            %Function that updates the encryption type
            switch src.Value
                case 'None'
                    obj.Workflow.Encryption = arduinoio.internal.WiFiEncryptionTypeEnum.None;
                case 'WPA/WPA2'
                    obj.Workflow.Encryption = arduinoio.internal.WiFiEncryptionTypeEnum.WPA;
                case 'WEP'
                    obj.Workflow.Encryption = arduinoio.internal.WiFiEncryptionTypeEnum.WEP;
            end
            updateStaticIPSettings(obj);
            showNetworkEditFields(obj);
        end
        
        function setSSID(obj, src, ~)
            %Function that sets the SSID to user specified value
            obj.Workflow.SSID = src.Text;
        end
        
        function setPassword(obj, src, ~)
            %Function that sets the password to user specified value
            obj.Workflow.Password = src.Text;
        end
        
        function setKey(obj, src, ~)
            %Function that sets the Key to user specified value
            try
                validateKey(obj.Workflow.HWInterface, src.Text);
                obj.Workflow.Key = src.Text;
            catch e
                obj.KeyEditText.Text = '';
                throwAsCaller(e);
            end
        end
        
        function setKeyIndex(obj, src, ~)
            %Function that sets the KeyIndex to user specified value
            try
                validateKeyIndex(obj.Workflow.HWInterface, src.Text);
                obj.Workflow.KeyIndex = src.Text;
            catch e
                obj.KeyIndexEditText.Text = '';
                throwAsCaller(e);
            end
        end
        
        function setTCPIPPort(obj, src, ~)
            %Function that sets the TCPIP port to default/user specified
            %value
            % If user clears the field, it will reset the value to 9500
            if isempty(src.Text)
                port = arduinoio.internal.ArduinoConstants.DefaultTCPIPPort;
                obj.PortEditText.Text = num2str(port);
                obj.Workflow.TCPIPPort = port;
            else
                try
                    value = str2double(src.Text);
                    validateTCPIPPort(obj.Workflow.HWInterface, value);
                    obj.Workflow.TCPIPPort = value;
                catch e
                    obj.PortEditText.Text = '9500';
                    throwAsCaller(e);
                end
            end
        end
        
        function setStaticIP(obj, src, ~)
            %Function that sets the static ip address
            try
                validateIPAddress(obj.Workflow.HWInterface, src.Text);
                obj.Workflow.StaticIP = src.Text;
            catch e
                obj.StaticIPEditText.Text = '';
                throwAsCaller(e);
            end
        end
    end
    
    %% Methods for building/removing/hiding/showing widgets
    methods(Access = 'private')   
        function showBluetoothNote(obj)
            %Function that shows Bluetooth connection note 
            obj.BluetoothNoteLabelText.Position = [20,15,430,40];
        end
        
        function hideBluetoothNote(obj)
            %Function that hides Bluetooth connection note 
            obj.BluetoothNoteLabelText.Position = obj.PositionOff;
        end
        
        function hideNetworkEditFields(obj)
            %Function that hides all edit fields 
            obj.KeyEditText.Position = obj.PositionOff;
            obj.KeyIndexEditText.Position = obj.PositionOff;
            obj.SSIDEditText.Position = obj.PositionOff;
            obj.PasswdEditText.Position = obj.PositionOff;
            obj.PortEditText.Position = obj.PositionOff;
            obj.KeyLabelText.Position = obj.PositionOff;
            obj.KeyIndexLabelText.Position = obj.PositionOff;
            obj.SSIDLabelText.Position = obj.PositionOff;
            obj.PasswdLabelText.Position = obj.PositionOff;
            obj.PortLabelText.Position = obj.PositionOff;
        end
        
        function showNetworkEditFields(obj)
            %Function that updates all edit fields positions
            startLabelPos = [10 110 150 20];
            startEditPos = [startLabelPos(1)+80 startLabelPos(2) 100 20];
            obj.SSIDLabelText.Position = startLabelPos;
            obj.SSIDEditText.Position = startEditPos;
            switch obj.Workflow.Encryption
                case arduinoio.internal.WiFiEncryptionTypeEnum.None
                    obj.PortLabelText.Position = obj.SSIDLabelText.Position-[0 20 0 0];
                    obj.PortEditText.Position = obj.SSIDEditText.Position-[0 20 0 0];
                    obj.PasswdLabelText.Position = obj.PositionOff;
                    obj.PasswdEditText.Position = obj.PositionOff;
                    obj.KeyLabelText.Position = obj.PositionOff;
                    obj.KeyEditText.Position = obj.PositionOff;
                    obj.KeyIndexLabelText.Position = obj.PositionOff;
                    obj.KeyIndexEditText.Position = obj.PositionOff;
                case arduinoio.internal.WiFiEncryptionTypeEnum.WPA
                    obj.PasswdLabelText.Position = obj.SSIDLabelText.Position-[0 20 0 0];
                    obj.PasswdEditText.Position = obj.SSIDEditText.Position-[0 20 0 0];
                    obj.PortLabelText.Position = obj.PasswdLabelText.Position-[0 20 0 0];
                    obj.PortEditText.Position = obj.PasswdEditText.Position-[0 20 0 0];
                    obj.KeyLabelText.Position = obj.PositionOff;
                    obj.KeyEditText.Position = obj.PositionOff;
                    obj.KeyIndexLabelText.Position = obj.PositionOff;
                    obj.KeyIndexEditText.Position = obj.PositionOff;
                case arduinoio.internal.WiFiEncryptionTypeEnum.WEP
                    obj.KeyLabelText.Position = obj.SSIDLabelText.Position-[0 20 0 0];
                    obj.KeyEditText.Position = obj.SSIDEditText.Position-[0 20 0 0];
                    obj.KeyIndexLabelText.Position = obj.KeyLabelText.Position-[0 20 0 0];
                    obj.KeyIndexEditText.Position = obj.KeyEditText.Position-[0 20 0 0];
                    obj.PortLabelText.Position = obj.KeyIndexLabelText.Position-[0 20 0 0];
                    obj.PortEditText.Position = obj.KeyIndexEditText.Position-[0 20 0 0];
                    obj.PasswdLabelText.Position = obj.PositionOff;
                    obj.PasswdEditText.Position = obj.PositionOff;
            end
        end
        
        function updateStaticIPSettings(obj)
            %Function that updates the static ip checkbox/label/edit text
            %position based on encryption type
            if ~isempty(obj.StaticIPCheckbox)
                switch obj.Workflow.Encryption
                    case arduinoio.internal.WiFiEncryptionTypeEnum.WPA
                        obj.StaticIPCheckbox.Position = [10 40 150 25];
                    case arduinoio.internal.WiFiEncryptionTypeEnum.WEP
                        obj.StaticIPCheckbox.Position = [10 20 150 25];
                    case arduinoio.internal.WiFiEncryptionTypeEnum.None
                        obj.StaticIPCheckbox.Position = [10 60 150 25];
                end
                if obj.StaticIPCheckbox.Value
                    obj.StaticIPLabelText.Position = [10 obj.StaticIPCheckbox.Position(2)-19 80 18];
                    obj.StaticIPEditText.Position = [obj.StaticIPLabelText.Position(1)+80 obj.StaticIPLabelText.Position(2) 110 obj.StaticIPLabelText.Position(4)];
                end
            end
        end
        
        function showNetworkSettings(obj)
            %Function that creates/shows all additional widgets for WiFi
            %settings
            obj.NetworkConfigPanel.Position = [10 2 210 230];
            if ispc||ismac
                obj.ReuseConfigCheckboxLabel.Position = [40 230 175 40];
                obj.ReuseConfigCheckbox.Position = [20 250 20 20];
            else
                obj.ReuseConfigCheckboxLabel.Position = [40 240 190 40];
                obj.ReuseConfigCheckbox.Position = [20 260 20 20];
            end
            index = obj.EncryptionRadioGroup.ValueIndex;% workaround for changing radio group position resets its Value issue
            obj.EncryptionRadioGroup.Position = [10 140 150 70];
            obj.EncryptionRadioGroup.ValueIndex = index;
            showNetworkEditFields(obj);
            obj.StaticIPCheckbox.Position = [20 30 150 25];
            updateStaticIPSettings(obj);
        end
        
        function hideNetworkSettings(obj)
            %Function that hides reuse checkbox and radio group and
            %dynamic edit fields 
            %Due to the complexity and the multiple widgets are involved,
            %hiding the widgets by positioning them off the screen is used
            %instead of the usual creating/deleting widgets dynamically.
            if ~isempty(obj.NetworkConfigPanel)
                obj.NetworkConfigPanel.Position = obj.PositionOff;
                obj.ReuseConfigCheckboxLabel.Position = obj.PositionOff;
                obj.ReuseConfigCheckbox.Position = obj.PositionOff;
                index = obj.EncryptionRadioGroup.ValueIndex;% workaround for changing radio group position resets its Value issue
                obj.EncryptionRadioGroup.Position = obj.PositionOff;
                obj.EncryptionRadioGroup.ValueIndex = index;
                hideNetworkEditFields(obj);
                obj.StaticIPCheckbox.Position = obj.PositionOff;
                obj.StaticIPEditText.Position = obj.PositionOff;
                obj.StaticIPLabelText.Position = obj.PositionOff;
            end
        end
        
        function checkNetworkSettings(obj)
            try
                validateNetworkSettings(obj.Workflow.HWInterface, obj.Workflow);
            catch e
                throwAsCaller(e);
            end
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
