function pin = validateInputPin(pin)
% This function validates the type and format of a specified input pin
% parameter
%

%   Copyright 2015-2016 The MathWorks, Inc.

    % accept string input but convert to character vector
    if isstring(pin)
        pin = char(pin);
    end
    
    if ~ischar(pin) || ~ismember(upper(pin(1)), {'D', 'A'})
        arduinoio.internal.localizedError('MATLAB:arduinoio:general:invalidPinType');
    end
    pin = upper(pin);
end