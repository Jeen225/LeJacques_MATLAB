function completeOverride = executeDummyArduinoDriverInstall( hStep, command, varargin )
%EXECUTEUPDATEFIRMWARE Execute function callback for the Update Firmware
%step

%   Copyright 2015-2016 The MathWorks, Inc.

completeOverride = false;
switch(command)
    case 'initialize',
        if (isempty(hStep.StepData))
            xlateEnt = struct('Item1', '');                
            
            % To be Deleted when message is created in hwconnectinstaller
            % resource component
            xlateEnt.Item1 = 'Driver installation is not required on your platform.';
  
            hStep.StepData.Labels = xlateEnt;
            hStep.StepData.Icon   = fullfile(matlabroot,'toolbox', 'shared', 'hwconnectinstaller','resources','warning.png');
            hStep.StepData.UpdateStatus = '';
        end


    case 'callback'
        completeOverride = true;
        assert(~isempty(hStep.StepData));
        switch(varargin{1})
            case 'Help',
                mapFile = arduinoio.internal.getDocMap;
                hwconnectinstaller.helpView('arduinoinstall', mapFile);
            otherwise,
                completeOverride = false;
        end
    case 'next'
        hSetup = hwconnectinstaller.Setup.get();
        hFwUpdate = hSetup.FwUpdater.hFwUpdate;
        
        if(hFwUpdate.EnableDriverInstall)
            hFwUpdate.installArduinoUSBDriver();
        end
 end

