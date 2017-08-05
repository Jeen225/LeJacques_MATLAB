classdef MacUtility < arduinoio.internal.Utility
%   Utility class used on Mac platform

%   Copyright 2014-2016 The MathWorks, Inc.
    
    methods(Access = {?arduinoio.internal.UtilityCreator, ?arduinoio.accessor.UnitTest})
        % Private constructor with limited access to only utility factory class
        % and test class
        function obj = MacUtility
        end
    end
    
    methods(Access = public)
        function buildInfo = setProgrammer(~, buildInfo)
            segments = strsplit(buildInfo.IDEPath, filesep);
            segments{end} = 'MacOS';
            segments = [segments, 'Arduino'];
        	buildInfo.Programmer = strjoin(segments, filesep);
        end
    end
end




