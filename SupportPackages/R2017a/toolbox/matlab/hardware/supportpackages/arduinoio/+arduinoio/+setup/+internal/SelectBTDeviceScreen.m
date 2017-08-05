classdef SelectBTDeviceScreen < matlab.hwmgr.internal.hwsetup.SelectionWithRadioGroup
    %SELECTBTDEVICESCREEN The SelectBTDeviceScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The SelectBTDeviceScreen is used to allow users to choose the
    % Bluetooth device for use with Arduino to communicate with host
    % computer wirelessly.

    % Copyright 2016-2017 The MathWorks, Inc.

    properties(Access = public)
        % ContentText - Label that contains the main content text
        ContentText
        % ImageFiles - Cell array of fullpaths to the image files. The
        % number of elements in ImageFiles should be equal to the number of
        % items in the radio group
        ImageFiles = {};
        % Radiogroup indicates whether device has been configured
        HasConfiguredRadioGroup
        % Saved Arduino board selected before leaving the screen
        CurrentArduinoBoard
        BluetoothNoteLabelText
    end

    methods(Access = 'public')
        function obj = SelectBTDeviceScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.SelectionWithRadioGroup(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:SelectBTScreenTitle').getString;
            obj.Description.Text = message('MATLAB:arduinoio:general:SelectBTScreenDescription').getString;
            obj.Description.Color = matlab.hwmgr.internal.hwsetup.util.Color.WHITE;
            
            % Set radio group for type selection
            obj.SelectionRadioGroup.Title = message('MATLAB:arduinoio:general:supportedDevicesText').getString;
            obj.SelectionRadioGroup.Items = arduinoio.internal.ArduinoConstants.getSupportedBTDevices(workflow.Board);
            obj.SelectionRadioGroup.SelectionChangedFcn = @obj.radioSelectCallback; 
            obj.SelectionRadioGroup.Visible = 'on';
            
            % Set SelectedImage Properties
            obj.SelectedImage.ImageFile = '';
            
            % Set the ImageFiles property to update the image when the Item 
            % in the radio group changes
            keyset = obj.SelectionRadioGroup.Items;
            valueset = {fullfile(obj.Workflow.ResourcesDir, 'arduino_bluetooth_bluefruit_programmer.png'),...
                        fullfile(obj.Workflow.ResourcesDir, 'arduino_bluetooth_bluefruit_shield.png'),...
                        fullfile(obj.Workflow.ResourcesDir, 'arduino_bluetooth_hc05.png'),...
                        fullfile(obj.Workflow.ResourcesDir, 'arduino_bluetooth_hc06.png')};
            obj.ImageFiles = containers.Map(keyset, valueset);
            
            obj.HelpText.AboutSelection = '';
            obj.HelpText.WhatToConsider = '';
            % Show default image.
            updateDeviceImage(obj);
        end

        function id = getPreviousScreenID(obj)
            id = 'arduinoio.setup.internal.UpdateServerScreen';
            obj.CurrentArduinoBoard = obj.Workflow.Board;
        end
        
        function  id = getNextScreenID(obj)
            % Jump to pairing screen if Adafruit selected or user has
            % already configured the other two devices
            if obj.Workflow.SkipConfigure||any(obj.Workflow.BluetoothDevice==[arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitProgrammer,...
                                                                              arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitShield])
                id = 'arduinoio.setup.internal.ArduinoBTConnectScreen';
            else
                id = 'arduinoio.setup.internal.ComputerBTConnectScreen';
            end
            obj.CurrentArduinoBoard = obj.Workflow.Board;
        end
        
        function reinit(obj)
            if ~strcmp(obj.CurrentArduinoBoard, obj.Workflow.Board)
                obj.SelectionRadioGroup.Items = arduinoio.internal.ArduinoConstants.getSupportedBTDevices(obj.Workflow.Board);
                obj.SelectionRadioGroup.ValueIndex = 1;
                updateDeviceImage(obj);
            end
        end
    end

    methods(Access = 'private')
        function radioSelectCallback(obj, src, ~)
            %Function that is invoked when a radio button is selected. This 
            %function updates the selection.
            
            %Clear bluetooth note
            if ~isempty(obj.BluetoothNoteLabelText)
                obj.BluetoothNoteLabelText.Visible='off';
                delete(obj.BluetoothNoteLabelText);
                obj.BluetoothNoteLabelText=[];
            end
            
            obj.NextButton.Enable = 'on';
            switch src.Value
                case 'Adafruit Bluefruit EZ-Link Programmer'
                    obj.Workflow.BluetoothDevice = arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitProgrammer;
                    hideRadioGroup(obj);
                    obj.HelpText.AboutSelection = '';
                case 'Adafruit Bluefruit EZ-Link Shield'
                    obj.Workflow.BluetoothDevice = arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitShield;
                    hideRadioGroup(obj);
                    obj.HelpText.AboutSelection = '';
                case 'HC-05'
                    obj.Workflow.BluetoothDevice = arduinoio.internal.BluetoothDeviceTypeEnum.HC05;
                    if checkICTInstallation(obj)
                        buildRadioGroup(obj);
                    else
                        return;
                    end
                case 'HC-06'
                    obj.Workflow.BluetoothDevice = arduinoio.internal.BluetoothDeviceTypeEnum.HC06;
                    if checkICTInstallation(obj)
                        buildRadioGroup(obj);
                    else
                        return;
                    end
            end
            updateDeviceImage(obj);
        end
        
        function result = checkICTInstallation(obj)
            %Function that checks the installation and license of ICT 
            % Display ICT requirement only when user does not have ICT installed.
            if ~hwconnectinstaller.internal.isProductInstalled('Instrument Control Toolbox')
                obj.BluetoothNoteLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,...
                    message('MATLAB:arduinoio:general:SelectBTDeviceScreenBTNoteICT').getString, [20,190,430,40], 10);
                obj.BluetoothNoteLabelText.Visible='on';
                obj.SelectedImage.ImageFile='';
                obj.NextButton.Enable = 'off';
                result = false;
            else
                result = true;
            end
        end
        
        function updateDeviceImage(obj) 
            %Function that updates the image displayed on the screen based
            %on selected connection type
            switch obj.Workflow.BluetoothDevice
                case arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitProgrammer
                    position = [20 70 295 162];
                case arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitShield
                    position = [20 40 290 194];
                case arduinoio.internal.BluetoothDeviceTypeEnum.HC05
                    position = [20 40 315 130];
                case arduinoio.internal.BluetoothDeviceTypeEnum.HC06
                    position = [20 30 350 138];
            end
            obj.SelectedImage.Position = position;
            obj.SelectedImage.Visible = 'on';
            file = obj.ImageFiles(obj.SelectionRadioGroup.Value);
            obj.SelectedImage.ImageFile = file;
        end
        
        function hideRadioGroup(obj)
            %Function that destroys the existing dynamic radiogroup
            if ~isempty(obj.HasConfiguredRadioGroup)
                obj.HasConfiguredRadioGroup.Visible = 'off';
                delete(obj.HasConfiguredRadioGroup);
                obj.HasConfiguredRadioGroup = [];
            end
        end
        
        function buildRadioGroup(obj)
            %Function that creates the dynamic radiogroup asking whether
            %the Bluetooth device has been configured before
            % Destroy radiogroup first 
            hideRadioGroup(obj);
            % Reconstruct radiogroup
            if obj.Workflow.SkipConfigure
                index = 1;
                obj.HelpText.AboutSelection = '';
            else
                index = 2;
                obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:SelectBTScreenAboutSelectionHC0506').getString;
            end
            obj.HasConfiguredRadioGroup = arduinoio.setup.internal.ScreenHelper.buildRadioGroup(obj.ContentPanel,...
                {message('MATLAB:arduinoio:general:yesText').getString, message('MATLAB:arduinoio:general:noText').getString}, ...
                message('MATLAB:arduinoio:general:skipConfigureText').getString, [20 150 445 80], @obj.updateSkipConfigFlag, index);
            obj.HasConfiguredRadioGroup.Visible = 'on';
        end
        
        function updateSkipConfigFlag(obj, src, ~)
            %Function that updates the SkipSetup flag to indicate
            %whether to skip board setup or not in the workflow
            if strcmpi(src.Value,'Yes')
                obj.Workflow.SkipConfigure = true;
                obj.HelpText.AboutSelection = '';
            else
                obj.Workflow.SkipConfigure = false;
                obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:SelectBTScreenAboutSelectionHC0506').getString;
            end
        end
    end

end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
