function paramValue = validateIntParameter(paramName, paramValue, validParamValues)
%   Copyright 2014-2016 The MathWorks, Inc.
    try
        validateattributes(paramValue, {'double', 'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64'}, {'scalar', 'integer', 'real', 'finite', 'nonnan'});
    catch
        arduinoio.internal.localizedError('MATLAB:arduinoio:general:invalidIntType', ...
            paramName, arduinoio.internal.renderArrayOfIntsToCharVector(validParamValues));
    end

    paramValue = floor(paramValue);
    
    if ~(ismember(paramValue, validParamValues))
        arduinoio.internal.localizedError('MATLAB:arduinoio:general:invalidIntValue', ...
            paramName, arduinoio.internal.renderArrayOfIntsToCharVector(validParamValues));
    end
end

