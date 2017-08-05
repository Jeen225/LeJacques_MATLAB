function localizedWarning(id, varargin)

%   Copyright 2015-2016 The MathWorks, Inc.
    varargin = cellfun(@(x)strrep(x, '\', '\\'), varargin, 'UniformOutput', false);
    sWarningBacktrace = warning('off', 'backtrace');
    warning(id,getString(message(id, varargin{:})));
    warning(sWarningBacktrace.state, 'backtrace');
end
