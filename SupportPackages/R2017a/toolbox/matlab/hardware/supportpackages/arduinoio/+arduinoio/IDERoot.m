function output = IDERoot()
% This function returns the installed directory of Arduino IDE

%   Copyright 2014-2016 The MathWorks, Inc.

if ismac
    output = fullfile(ide.internal.getArduinoIDERootDir, 'Arduino.app', 'Contents', 'Java');
else
    output = ide.internal.getArduinoIDERootDir;
end

end
