classdef PairBTScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %PAIRBTSCREEN The PairBTScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The PairBTScreen is used to show users how to pair the Bluetooth
    % device with their host computer
    
    % Copyright 2016-2017 The MathWorks, Inc.

    properties(Access = public)
        % HelpText for Doc link
        DocLink1
        DocLink2
        % Text label that contains information for pairing instructions
        PairStep1TextLabel
        PairStep2TextLabel
        PairStep3TextLabel
        PairStep4TextLabel
        % Dropdown that selects the Bluetooth serial port
        PortDropDown
        % Button that repopulates the port lists
        RefreshButton
        % Edit text that indicates entering device address
        AddressEditText
        % Bluetooth device stored when leaving the screen
        CurrentBluetoothDevice
    end
    
    properties(Access = private, Constant = true)
        FontSize = 10
    end

    methods(Access = 'public')
        function obj = PairBTScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:PairBTScreenTitle').getString;
            
            % Set step text labels
            obj.PairStep1TextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,...
                message('MATLAB:arduinoio:general:PairBTStep1Text').getString,[20 330 430 45],obj.FontSize);
            link1 = message('MATLAB:arduinoio:general:PairBTScreenDocLink1Text').getString;
            link2 = message('MATLAB:arduinoio:general:PairBTScreenDocLink2Text').getString;
            if ispc
                link1 = replace(link1, 'DOCLINK','bluetooth_pair_windows');
                link2 = replace(link2, 'DOCLINK','bluetooth_address_windows');
            elseif ismac
                link1 = replace(link1, 'DOCLINK','bluetooth_pair_mac');
                link2 = replace(link2, 'DOCLINK','bluetooth_address_mac');
            end
            obj.PairStep2TextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,'',[20 300 430 20],obj.FontSize);
            obj.DocLink1 = arduinoio.setup.internal.ScreenHelper.buildHelpText(obj.ContentPanel, link1, [20 270 430 25]);
            obj.PairStep3TextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,'',[20 230 430 20],obj.FontSize);
            obj.DocLink2 = arduinoio.setup.internal.ScreenHelper.buildHelpText(obj.ContentPanel, link2, [20 200 430 25]);
            obj.PairStep4TextLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel,'',[20 160 430 20],obj.FontSize);
            updateScreenSteps(obj);
            
            obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:PairBTScreenWhatToConsider').getString;
            obj.HelpText.AboutSelection = '';
        end

        function id = getPreviousScreenID(obj)
            id = 'arduinoio.setup.internal.ArduinoBTConnectScreen';
            obj.CurrentBluetoothDevice = obj.Workflow.BluetoothDevice;
        end
        
        function  id = getNextScreenID(obj)
            if any(obj.Workflow.BluetoothDevice==[arduinoio.internal.BluetoothDeviceTypeEnum.HC05,...
                                                  arduinoio.internal.BluetoothDeviceTypeEnum.HC06])
                validateBTAddress(obj.Workflow.HWInterface, obj.AddressEditText.Text);
                obj.Workflow.DeviceAddress = strcat('btspp://', obj.AddressEditText.Text);
            end
            id = 'arduinoio.setup.internal.TestConnectionScreen';
            obj.CurrentBluetoothDevice = obj.Workflow.BluetoothDevice;
        end
        
        function reinit(obj)
            % if Bluetooth device changes, empty the address field and
            % disable next button
            if obj.CurrentBluetoothDevice ~= obj.Workflow.BluetoothDevice
                updateScreenSteps(obj);
            end
        end
    end
    
    methods(Access = 'private')
        function updateScreenSteps(obj)
            %Helper function that updates the steps to pair the device
            %based on the currently selected bluetooth device and OS
            if ~isempty(obj.PortDropDown)
                delete(obj.PortDropDown);
                obj.PortDropDown = [];
                delete(obj.RefreshButton);
                obj.RefreshButton = [];
            end
            if ~isempty(obj.AddressEditText)
                delete(obj.AddressEditText);
                obj.AddressEditText = [];
            end
            
            switch obj.Workflow.BluetoothDevice
                case {arduinoio.internal.BluetoothDeviceTypeEnum.HC05,...
                        arduinoio.internal.BluetoothDeviceTypeEnum.HC06}
                    id1 = 'MATLAB:arduinoio:general:PairBTStep2HC0506Text';
                    id2 = 'MATLAB:arduinoio:general:PairBTStep3HC0506Text';
                    id3 = 'MATLAB:arduinoio:general:PairBTStep4HC0506Text';
                case {arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitProgrammer,...
                      arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitShield}
                    id1 = 'MATLAB:arduinoio:general:PairBTStep2BluefruitText';
                    id2 = 'MATLAB:arduinoio:general:PairBTStep3BluefruitText';
                    id3 = 'MATLAB:arduinoio:general:PairBTStep4BluefruitText';
            end
            obj.PairStep2TextLabel.Text =  message(id1).getString;
            obj.PairStep3TextLabel.Text =  message(id2).getString;
            obj.PairStep4TextLabel.Text =  message(id3).getString;
            if any(obj.Workflow.BluetoothDevice == [arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitProgrammer,...
                                                    arduinoio.internal.BluetoothDeviceTypeEnum.BluefruitShield])
                if ispc
                    pos = [250, 160, 100, 20];
                else
                    pos = [200, 160, 170, 20];
                end
                obj.PortDropDown = arduinoio.setup.internal.ScreenHelper.buildDropDown(obj.ContentPanel,...
                    {'dummy'}, pos, @obj.updatePort, 1);
                updatePortDropdown(obj);
                obj.RefreshButton = arduinoio.setup.internal.ScreenHelper.buildButton(obj.ContentPanel, ...
                    message('MATLAB:arduinoio:general:refreshButtonText').getString, [370, 157, 70, 25], @obj.updatePortDropdown);
            else
                % Set Edit field to ask for Bluetooth address or name
                if ispc
                    pos = [270, 160, 110, 20];
                else
                    pos = [240, 160, 110, 20];
                end
                obj.AddressEditText = arduinoio.setup.internal.ScreenHelper.buildEditText(obj.ContentPanel, '', pos, @obj.dummyCallback);
            end
        end
        
        function updatePort(obj, src, ~)
            %Callback function for port dropdown
            obj.Workflow.BluetoothSerialPort = src.Value;
            if strcmp(src.Value, 'None')
                obj.NextButton.Enable = 'off';
            else
                obj.NextButton.Enable = 'on';
            end
        end
        
        function updatePortDropdown(obj, ~, ~)
            %Helper function that shows the correct set of ports at current
            %screen
            obj.PortDropDown.Items = getAvailableSerialPorts(obj.Workflow.HWInterface);
            obj.PortDropDown.ValueIndex = 1;
        end
        
        function dummyCallback(~, ~, ~)
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
