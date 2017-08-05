function dlgstruct = getDummyArduinoDriverInstallSchema( hStep, dlgstruct )
% Dummy schema for firmware update step on Mac and Linux

%   Copyright 2015-2016 The MathWorks, Inc.

% Schema
%Update the dlgstruct to have nine rows

dlgstruct.LayoutGrid = [11 1];
dlgstruct.RowStretch = [1 1 1 1 1 1 1 1 1 1 1];
dlgstruct.ColStretch = 1;
for i = 2:numel(dlgstruct.Items)
    dlgstruct.Items{i}.RowSpan = [11 11];
end

i = 1;
Item(i).Name = hStep.StepData.Labels.Item1;
Item(i).Type = 'text';
Item(i).RowSpan = [1 1];
Item(i).ColSpan = [1 1];

% Return dlgstruct
dlgstruct.Items{1} = Item(1);
end

