classdef SetupCompleteScreen < matlab.hwmgr.internal.hwsetup.LaunchExamples
    %SETUPCOMPLETESCREEN This is an Arduino specific implementation of a
    %Launch Examples screen. This screen will be displayed at the end of
    %the Arduino Setup to give the installer an option to open the examples
    %page for Arduino

    % Copyright 2016 The MathWorks, Inc.

    methods
        function obj = SetupCompleteScreen(workflow)
            obj@matlab.hwmgr.internal.hwsetup.LaunchExamples(workflow);
            obj.customizeScreen();
        end

        function id = getPreviousScreenID(obj)
            if isa(obj.Workflow, 'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow') && obj.Workflow.SkipSetup
                id = 'arduinoio.setup.internal.DriverInstallResultScreen';
            else
                id = 'arduinoio.setup.internal.TestConnectionScreen';
            end
        end

        function customizeScreen(obj)
            obj.Description.Text = message('MATLAB:arduinoio:general:ArduinoCompleteDescription').getString;
            obj.Description.Position = [20 310 430 70];

            %if the LaunchCheckbox is empty then there are no examples to
            %display. Set the ShowExamples property as is appropriate.
            if ~isempty(obj.LaunchCheckbox)
                obj.LaunchCheckbox.Position = [20 280 430 20];
                obj.LaunchCheckbox.ValueChangedFcn = @obj.checkboxCallback;
                obj.LaunchCheckbox.Value=obj.Workflow.ShowExamples; 
            else
                obj.Workflow.ShowExamples = false;
            end

        end
    end

    methods(Access = 'private')
        function checkboxCallback(obj, src, ~)
            obj.Workflow.ShowExamples = src.Value;
        end
    end

end

% LocalWords:  arduinoio
