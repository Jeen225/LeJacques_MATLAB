classdef ArduinoIO < matlabshared.supportpkg.internal.sppkglegacy.SupportPackageRegistryPluginBase
   % This class is used by support package infrastructure to find the legacy support_package_registry.xml 
   % for the BaseCode specified below. See the base class for more information.
 
   %   Copyright 2016 The MathWorks, Inc.
 
    properties(Constant)
            BaseCode = 'ML_ARDUINO';
    end
    
    methods
        function obj = ArduinoIO()
            try
                obj.addTpRemoveCmd('adafruitmotorshieldv2.instrset', @arduinoio.setup.uninstall3PLibraries);
            catch 
                disp('Unable to remove Adafruit Motor Shield v2 library.');
            end
        end
    end

end