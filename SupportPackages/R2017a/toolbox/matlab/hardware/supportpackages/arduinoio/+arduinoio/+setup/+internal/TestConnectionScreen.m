classdef TestConnectionScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %TESTCONNECTIONSCREEN The TestConnectionScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The TestConnectionScreen is used to allow users to review the Arduino
    % settings and also test the connection before using it at command
    % line.
    
    % Copyright 2016 The MathWorks, Inc.

    properties(Access = public)
        % Label that shows text for settings table
        SettingsText
        % Label that contains the main content text
        ContentText
        % Button to allow a user to test connection
        TestConnButton
        % Progress bar shows testing status
        TestConnProgress
        % Label that shows result text after testing connection
        ResetLabelText
        % Table that shows a summary of connection info
        DeviceInfoTable
    end

    properties(Access = private, Constant = true)
        FontSize = 10
    end
    
    methods(Access = 'public')
        function obj = TestConnectionScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:TestConnectionScreenTitle').getString;
            obj.HelpText.AboutSelection = '';
            obj.HelpText.WhatToConsider = '';
            
            % Set the DeviceInfoTable
            obj.SettingsText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, 'Current Settings:',[20 350 250 20],obj.FontSize);
            obj.DeviceInfoTable = matlab.hwmgr.internal.hwsetup.DeviceInfoTable.getInstance(obj.ContentPanel);
            updateDeviceInfoTable(obj);
            
            % Set the Test Connection Button
            obj.TestConnButton = arduinoio.setup.internal.ScreenHelper.buildButton(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:testButtonText').getString, [20 190 120 30], @obj.buttonCallback);
            obj.TestConnProgress = matlab.hwmgr.internal.hwsetup.ProgressBar.getInstance(obj.ContentPanel);
            obj.TestConnProgress.Position = [obj.TestConnButton.Position(1)+150 obj.TestConnButton.Position(2) 270 25];
            
            %Set up error text label
            obj.ResetLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, '', [20 130 430 50], obj.FontSize);
        end

        function id = getPreviousScreenID(obj)
            if obj.Workflow.SkipProgram
                id = 'arduinoio.setup.internal.ObtainIPScreen';
            else
                switch obj.Workflow.ConnectionType
                    case arduinoio.internal.ConnectionTypeEnum.Serial
                        id = 'arduinoio.setup.internal.UpdateServerScreen';
                    case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                        id = 'arduinoio.setup.internal.PairBTScreen';
                    case arduinoio.internal.ConnectionTypeEnum.WiFi
                        id = 'arduinoio.setup.internal.UpdateServerScreen';
                end
            end
        end
        
        function  id = getNextScreenID(~)
            id = 'arduinoio.setup.internal.SetupCompleteScreen';
        end
        
        function reinit(obj)
            updateDeviceInfoTable(obj);
            % upon reentry, reset result text and what to
            % consider text
            obj.ResetLabelText.Text = '';
            obj.HelpText.WhatToConsider = '';
        end
        
        function show(obj)
            show@matlab.hwmgr.internal.hwsetup.TemplateBase(obj);
            obj.TestConnProgress.Visible = 'off';
        end
    end

    methods(Access = 'private')
        function updateDeviceInfoTable(obj)
            %Function that renders the current settings table
            [properties, value] = getDeviceProperties(obj.Workflow.HWInterface, obj.Workflow);
            obj.DeviceInfoTable.Labels = properties;
            obj.DeviceInfoTable.Values = value;
            obj.DeviceInfoTable.Position = [20 320 100 20];
            obj.DeviceInfoTable.ColumnWidth = 230;
        end
        
        function buttonCallback(obj, ~, ~)
            %Function that is invoked when the button is clicked. This 
            %function trys to create an Arduino object.
            
            % Disable screen during test connection
            obj.TestConnProgress.Visible = 'on';
            c = onCleanup(@() cleanup(obj));
            disableScreen(obj);
            obj.TestConnProgress.Indeterminate = true;
            drawnow;
            obj.HelpText.WhatToConsider = '';
            obj.ResetLabelText.Text = '';
            [result, err] = testConnection(obj.Workflow.HWInterface, obj.Workflow);
            if result
                obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:TestConnectionScreenWhatToConsider').getString;
                obj.ResetLabelText.FontColor = arduinoio.setup.internal.ScreenHelper.GREEN;
                obj.ResetLabelText.Text = message('MATLAB:arduinoio:general:testConnectionSuccess').getString;
            else
                obj.ResetLabelText.FontColor = arduinoio.setup.internal.ScreenHelper.RED;
                if strcmpi(err.identifier, 'MATLAB:arduinoio:general:connectionExists')
                    obj.ResetLabelText.Text = err.message;
                else
                    obj.ResetLabelText.Text = message('MATLAB:arduinoio:general:testConnectionFailed').getString;
                end
            end
            
            function cleanup(obj)
                enableScreen(obj);
                obj.TestConnProgress.Indeterminate = false;
                obj.TestConnProgress.Visible = 'off';
                drawnow;
            end
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
