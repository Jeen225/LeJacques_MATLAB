function paramValue = validateIntArrayParameterRanged(paramName, paramValue, min, max)

%   Copyright 2014-2016 The MathWorks, Inc.
    try
        validateattributes(paramValue, {'double', 'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}, {'2d', 'integer', 'real', 'finite', 'nonnan'});
    catch
        arduinoio.internal.localizedError('MATLAB:arduinoio:general:invalidIntArrayTypeRanged', ...
            paramName, num2str(min), num2str(max));
    end

    paramValue = floor(paramValue);
    
    if ~(all(paramValue >= min) && all(paramValue <= max))
        arduinoio.internal.localizedError('MATLAB:arduinoio:general:invalidIntArrayValueRanged', ...
            paramName, num2str(min), num2str(max));
    end
end

