function allInstalledLibs = listArduinoLibraries()
%Display a list of installed Arduino libraries
%
%Syntax:
%allInstalledLibs = listArduinoLibraries()
%
%Description:
%Creates a list of available Arduino libraries and saves the list to the variable libs.
%
%Output Arguments:
%allInstalledLibs - List of available Arduino libraries (cell array of character vectors)

%   Copyright 2014-2016 The MathWorks, Inc.

    baseList = internal.findSubClasses('arduinoio', 'arduinoio.LibraryBase', true);
    addonList = internal.findSubClasses('arduinoioaddons', 'arduinoio.LibraryBase', true);
    allList = [baseList; addonList];
    allInstalledLibs = {};
    for libClassCount = 1:length(allList)
        thePropList = allList{libClassCount}.PropertyList;
        for propCount = 1:length(thePropList)
            % check classes that have defined constant LibraryName - e.g
            % those that are library classes
            theProp = thePropList(propCount);
            % If the current property's name is 'LibraryName' and it has a
            % default value, then it defines a new library
            if strcmp(theProp.Name, 'LibraryName') && theProp.HasDefault 
                definingClass = theProp.DefiningClass;
                packageNames = strsplit(definingClass.Name, '.');
                vendorPackageName = packageNames{end-1};
                % check vendor package name to form library name character vector
                % convert string type theProp.DefaultValue(LibraryName) to character vector
                if isstring(theProp.DefaultValue)
                    libName = char(theProp.DefaultValue);
                else
                    libName = theProp.DefaultValue;
                end
                if ~strcmp(vendorPackageName, 'arduinoio')  % class within arduinoioaddons.VENDORNAME
                    libName = strrep(libName, '\', '/');
                    if contains(libName, '/')
                        temp = strsplit(libName, '/');
                        if strcmpi(vendorPackageName, temp{1})
                            allInstalledLibs = [allInstalledLibs, libName]; %#ok<AGROW>
                        end
                    end
                else
                    allInstalledLibs = [allInstalledLibs, libName]; %#ok<AGROW>
                end
            end
        end
    end
    allInstalledLibs = unique(allInstalledLibs');
    
    try
        if isempty(allInstalledLibs)
            arduinoio.internal.localizedError('MATLAB:arduinoio:general:IDENotInstalled');
        end
    catch e
        throwAsCaller(e);
    end
end


