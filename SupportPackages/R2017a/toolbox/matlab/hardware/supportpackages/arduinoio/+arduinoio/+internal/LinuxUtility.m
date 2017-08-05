classdef LinuxUtility < arduinoio.internal.Utility
%   Utility class used on Linux platform

%   Copyright 2014-2016 The MathWorks, Inc.

    methods(Access = {?arduinoio.internal.UtilityCreator, ?arduinoio.accessor.UnitTest})
        % Private constructor with limited access to only utility factory class
        % and test class
        function obj = LinuxUtility
        end
    end
    
    methods(Access = public)        
        function buildInfo = setProgrammer(~, buildInfo)
            buildInfo.Programmer = fullfile(buildInfo.IDEPath, 'arduino');       
        end
    end
end

