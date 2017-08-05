classdef DriverInstallScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %DRIVERINSTALLSCREEN The DriverInstallScreen is one screen that is meant
    %to be included in a package of screens that are part of a setup app.
    %There is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The DriverInstallScreen is used to inform the Arduino USB Driver
    % installation process and to provide a method for the user to indicate
    % whether they want the driver to be installed or not.

    % Copyright 2016 The MathWorks, Inc.

    properties(SetAccess = private, GetAccess = public)
        %SETUPINFOLABEL - Label that contains the installation info
        SetupInfoLabel
        %SETUPINSTALLSTEPS - Label that contains the steps for installation
        SetupInstallSteps
        %DRIVERENABLECHECKBOX - Checkbox to allow a user to enable or
        %disable driver installation
        DriverEnableCheckbox
    end

    properties(Access = private, Constant = true)
        FontSize = 10
    end
    
    methods(Access = 'public')
        function obj = DriverInstallScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:ArduinoDriverScreenTitle').getString;
            obj.HelpText.AboutSelection = '';
            obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:ArduinoSetupNotes').getString;
            obj.buildContentPane();
        end

        function  id = getNextScreenID(obj)
            %GETNEXTSCREENID - execute the driver installation if the
            %DriverEnable flag is high. Returns the next screen id.
            if(obj.Workflow.DriverEnable)
                errFlag = obj.Workflow.HWInterface.installArduinoUSBDriver();
                obj.Workflow.DriverInstallationError = errFlag;
            end
            id = 'arduinoio.setup.internal.DriverInstallResultScreen';
        end

    end

    methods(Access = 'private')

        function buildContentPane(obj)
            %BUILDCONTENTPANE - constructs all of the elements for the
            %content pane and adds them to the content pane element
            %collection
            
            %Set up the content text. Use three labels to create ideal
            %spacing between paragraphs.
            obj.SetupInfoLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:ArduinoSetupInfoMessage').getString,[20 310 430 60],obj.FontSize);

            obj.SetupInstallSteps = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:ArduinoSetupInstallSteps').getString,[20 240 430 60], obj.FontSize);

            %Set up the checkbox to enable driver installation
            obj.DriverEnableCheckbox = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.ContentPanel,...
                 message('MATLAB:arduinoio:general:ArduinoSetupDriverCheckbox').getString, [20 255 430 20], @(e,v)obj.checkboxCallback(e,v), obj.Workflow.DriverEnable);
        end

        function checkboxCallback(obj, src, ~)
            %CHECKBOXCALLBACK - Function that is invoked when the Driver
            %Enable checkbox value is changed. This function sets the
            %DriverEnable value in the workflow so that the user's
            %selection is available later on in the workflow
            obj.Workflow.DriverEnable = src.Value;
            
            %if this checkboxchanges reset the failure state of the
            %Workflow
            obj.Workflow.DriverInstallationError = false;
        end

    end

end

% LocalWords:  SETUPINFOLABEL SETUPINSTALLSTEPS DRIVERENABLECHECKBOX
% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE CHECKBOXCALLBACK
