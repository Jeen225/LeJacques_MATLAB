function arduinosetup()
%Launch Arduino setup screens
%
%Syntax:
%arduinosetup
%
%Description:
%Launches the Arduino setup screens for configuring Arduino connection.

%   Copyright 2016 The MathWorks, Inc.

    workflow = matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow('setup');
    workflow.launch;
end