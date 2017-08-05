classdef DriverInstallResultScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %DRIVERINSTALLRESULTSCREEN The DriverInstallResultScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The DriverInstallResultScreen is used to inform the user of any installation
    % issues that were encountered installation process and to provide a
    % method for the user to indicate whether they want the driver to be
    % installed or not.

    % Copyright 2016 The MathWorks, Inc.

    properties(Access = public)
        % HelpText for Doc link
        DocLink
        ResultLabel
        SetupRadioGroup
    end
    
    properties(Access = private, Constant = true)
        FontSize = 10
    end

    methods(Access = 'public')
        function obj = DriverInstallResultScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:ArduinoResultsScreenTitle').getString;
            obj.Title.Position = [20 7 570 25];
            obj.ResultLabel = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, 'dummy', [20 330 430 50], obj.FontSize);
            obj.ResultLabel.FontColor = arduinoio.setup.internal.ScreenHelper.ORANGE;
            obj.SetupRadioGroup = arduinoio.setup.internal.ScreenHelper.buildRadioGroup(obj.ContentPanel,...
                {message('MATLAB:arduinoio:general:yesText').getString, message('MATLAB:arduinoio:general:noText').getString}, ...
                message('MATLAB:arduinoio:general:skipSetupText').getString, [20 230 445 80], @obj.updateSetupFlag, 1);
            updateScreen(obj);
            obj.HelpText.AboutSelection = '';
            obj.HelpText.WhatToConsider = '';
        end

        function id = getPreviousScreenID(~)
            id = 'arduinoio.setup.internal.DriverInstallScreen';
        end

        function  id = getNextScreenID(obj)
            if obj.Workflow.SkipSetup 
                id = 'arduinoio.setup.internal.SetupCompleteScreen';
            else
                id = 'arduinoio.setup.internal.SelectConnectionScreen';
            end
        end

        function reinit(obj)
            updateScreen(obj);
        end
        
        function show(obj)
            %Overwrite show method to hide Back button on Mac and Linux
            %since it is the entry screen for postinstall setup
            show@matlab.hwmgr.internal.hwsetup.TemplateBase(obj)
            if isunix
                obj.BackButton.Visible = 'off';
            end
        end
    end

    methods(Access = 'private')
        function updateScreen(obj)
            index = obj.SetupRadioGroup.ValueIndex; % workaround for radio group position change issue
            if obj.Workflow.DriverInstallationError
                obj.ResultLabel.Text = message('MATLAB:arduinoio:general:driverInstallFailed').getString;
                obj.ResultLabel.Visible = 'on';
                if isempty(obj.DocLink)
                    obj.DocLink = arduinoio.setup.internal.ScreenHelper.buildHelpText(obj.ContentPanel, ...
                        message('MATLAB:arduinoio:general:driverInstallDocLinkText').getString, [20 310 240 25]);
                end
                % If it errors, warning but still give option to proceed
                obj.SetupRadioGroup.Position = [20 220 445 80];
            else
                obj.ResultLabel.Visible = 'off';
                if ~isempty(obj.DocLink)
                    obj.DocLink.Visible = 'off';
                end
                delete(obj.DocLink);
                obj.DocLink = [];
                obj.SetupRadioGroup.Position = [20 300 445 80];
            end
            obj.SetupRadioGroup.ValueIndex = index;
        end
        
        function updateSetupFlag(obj, src, ~)
            %UPDATESETUPFLAG - updates the SkipSetup flag to indicate
            %whether to skip board setup or not in the workflow
            if strcmpi(src.Value,'No')
                obj.Workflow.SkipSetup = true;
            else
                obj.Workflow.SkipSetup = false;
            end
        end
    end

end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio BUILDCONTENTPANE
% LocalWords:  BUILDSUCCESSCONTENTPANE BUILDFAILURECONTENTPANE
