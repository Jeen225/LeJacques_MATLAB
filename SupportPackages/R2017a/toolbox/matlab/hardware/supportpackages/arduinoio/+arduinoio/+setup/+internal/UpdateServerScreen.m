classdef UpdateServerScreen < matlab.hwmgr.internal.hwsetup.TemplateBase
    %UPDATESERVERSCREEN The UpdateServerScreen is one screen that is meant
    %to be included in a package of screens that make up a setup app. There
    %is a Workflow object that is passed from screen to screen to keep
    %workflow specific persistent variables available throughout the entire
    %sequence.
    %
    % The UpdateServerScreen is used to allow users to choose Arduino board
    % related information, including board, port and libraries, so that it
    % programs the board with correct server.

    % Copyright 2016-2017 The MathWorks, Inc.

    properties(SetAccess = private, GetAccess = public)
        %ConnectUSBLabelText - Label that shows connect USB
        ConnectUSBLabelText
        %BoardDropDown - Dropdown menu that selects the board
        BoardDropDown
        %PortDropDown - Dropdown menu that selects the port
        PortDropDown
        %ProgramProgress - Progress bar that shows status
        ProgramProgress
        %ProgramButton - Progress button that starts programming
        ProgramButton
        %ProgramNote - Note to remove Bluetooth device
        ProgramNote
        %BoardLabelText - Label that shows choose board text
        BoardLabelText
        %PortLabelText - Label that shows choose port text
        PortLabelText
        %LibrariesLabelText - Label that shows choose library text
        LibrariesLabelText
        %LibraryCheckBox - Checkbox groups that selects library
        LibraryCheckBox
        %ProgramLabelText - Label that shows program text
        ProgramLabelText
        %ErrorLabelText - Label that shows program error text
        ErrorLabelText
        %PrevConnectionType - Connection type saved before leaving the screen
        PrevConnectionType
        %PrevBoard - Board saved before leaving the screen
        PrevBoard
        %PrevEncryption - Encryption type saved before leaving the screen 
        PrevEncryption 
        %PrevSSID - SSID saved before leaving the screen
        PrevSSID
        %PrevPassword - Password saved before leaving the screen
        PrevPassword
        %PrevPort - TCPIPPort saved before leaving the screen
        PrevPort
        %PrevKeyIndex - Key index saved before leaving the screen
        PrevKeyIndex
        %PrevKey - Key saved before leaving the screen
        PrevKey
        % HelpText for log link
        LogLink
    end
    
    properties(Access = private, Constant=true)
        FontSize = 10
    end

    methods(Access = 'public')
        function obj = UpdateServerScreen(workflow)
            validateattributes(workflow, {'matlab.hwmgr.internal.hwsetup.register.ArduinoWorkflow'}, {});
            obj@matlab.hwmgr.internal.hwsetup.TemplateBase(workflow);
            obj.Title.Text = message('MATLAB:arduinoio:general:UpdateServerScreenTitle').getString;
            obj.HelpText.AboutSelection = message('MATLAB:arduinoio:general:UpdateServerScreenAboutSelection').getString;
            if obj.Workflow.ConnectionType~=arduinoio.internal.ConnectionTypeEnum.WiFi
                obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:UpdateServerScreenWhatToConsider').getString;
            else
                obj.HelpText.WhatToConsider = '';
            end
            buildContentPane(obj);
            obj.NextButton.Enable = 'off';
        end
        
        function id = getPreviousScreenID(obj)
            id = 'arduinoio.setup.internal.SelectConnectionScreen';
            saveCurrentSettings(obj);
        end

        function  id = getNextScreenID(obj)
            switch obj.Workflow.ConnectionType
                case arduinoio.internal.ConnectionTypeEnum.Serial
                    id = 'arduinoio.setup.internal.TestConnectionScreen';
                case arduinoio.internal.ConnectionTypeEnum.Bluetooth
                    id = 'arduinoio.setup.internal.SelectBTDeviceScreen';
                case arduinoio.internal.ConnectionTypeEnum.WiFi
                    id = 'arduinoio.setup.internal.TestConnectionScreen';
            end
            saveCurrentSettings(obj);
        end
        
        function reinit(obj)
            % Rerender screen when connection type has changed or any WiFi
            % settings has changed
            if (obj.PrevConnectionType ~= obj.Workflow.ConnectionType) || ...
               (obj.PrevPort~=obj.Workflow.TCPIPPort)||...
               (~isequal(obj.PrevEncryption, obj.Workflow.Encryption))||...
               (~isequal(obj.PrevSSID, obj.Workflow.SSID)) || ...
               (~isequal(obj.PrevPassword, obj.Workflow.Password)) ||...
               (~isequal(obj.PrevKey, obj.Workflow.Key)) ||...
               (~isequal(obj.PrevKeyIndex, obj.Workflow.KeyIndex))
                obj.NextButton.Enable = 'off';
                obj.ErrorLabelText.Text = '';
                if ~isempty(obj.LogLink)
                    obj.LogLink.Visible = 'off';
                    delete(obj.LogLink);
                    obj.LogLink=[];
                end
            end
            updateBoardDropdown(obj);
            updatePortDropdown(obj);
            if obj.Workflow.ConnectionType~=arduinoio.internal.ConnectionTypeEnum.WiFi
                obj.HelpText.WhatToConsider = message('MATLAB:arduinoio:general:UpdateServerScreenWhatToConsider').getString;
            else
                obj.HelpText.WhatToConsider = '';
            end
        end
        
        function show(obj)
            show@matlab.hwmgr.internal.hwsetup.TemplateBase(obj);
            obj.ProgramProgress.Visible = 'off';
        end
    end

    methods(Access = 'private')
        function buildContentPane(obj)
            %BUILDCONTENTPANE - constructs all of the elements for the
            %content pane and adds them to the content pane element
            %collection
            obj.ConnectUSBLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:UpdateServerScreenConnectUSBText').getString, [20 365 300 20], obj.FontSize);
            obj.BoardLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:chooseBoardText').getString, [20 340 100 20], obj.FontSize);
            obj.PortLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:chooseArduinoPortText').getString, [obj.BoardLabelText.Position(1)+230 obj.BoardLabelText.Position(2) 100 20], obj.FontSize);
            %Set up the dropdown menu to select board
            startPosition = obj.BoardLabelText.Position(1);
            if ismac
                startPosition = startPosition-10;
            end
            obj.BoardDropDown = arduinoio.setup.internal.ScreenHelper.buildDropDown(obj.ContentPanel,...
                {'dummy'}, [startPosition obj.BoardLabelText.Position(2)-20 130 20], @obj.updateBoard, 1);
            updateBoardDropdown(obj);

            %Set up the dropdown menu to select port
            obj.PortDropDown = arduinoio.setup.internal.ScreenHelper.buildDropDown(obj.ContentPanel,...
                {'dummy'}, [startPosition+230 obj.BoardLabelText.Position(2)-20 110 20], @obj.updatePort, 1);
            updatePortDropdown(obj);
            if ~ispc
                obj.PortDropDown.addWidth(70);
            end
            
            %Set up the checkboxes for selecting libraries
            obj.LibrariesLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:UpdateServerScreenLibraryText').getString, [20 280 430 20], obj.FontSize);
            availableLibs = listArduinoLibraries;
            leftLibPosition  = [20 260 190 20];
            rightLibPosition = leftLibPosition+[200 0 30 0];
            for index = 1:numel(availableLibs)
                if ismember(availableLibs{index}, arduinoio.internal.ArduinoConstants.ShippingLibraries)
                    position = leftLibPosition;
                    leftLibPosition = leftLibPosition-[0 20 0 0];
                else
                    position = rightLibPosition;
                    rightLibPosition = rightLibPosition-[0 20 0 0];
                end
                value = ismember(availableLibs{index}, arduinoio.internal.ArduinoConstants.DefaultLibraries);
                obj.LibraryCheckBox{index} = arduinoio.setup.internal.ScreenHelper.buildCheckbox(obj.ContentPanel,...
                 	availableLibs{index}, position, @obj.selectIncludedLibrary, value);
                obj.LibraryCheckBox{index}.Visible = 'on';
            end
            
            %Set up program label/progress bar/button to upload server
            obj.ProgramButton = arduinoio.setup.internal.ScreenHelper.buildButton(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:programButtonText').getString, [20 100 100 23], @obj.uploadServer);
            obj.ProgramLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, ...
                message('MATLAB:arduinoio:general:UpdateServerScreenButtonText').getString, [20 130 430 20], obj.FontSize);
            obj.ProgramProgress = matlab.hwmgr.internal.hwsetup.ProgressBar.getInstance(obj.ContentPanel);
            obj.ProgramProgress.Position = [obj.ProgramButton.Position(1)+130 obj.ProgramButton.Position(2) 280 22];
            
            %Set up error text label
            obj.ErrorLabelText = arduinoio.setup.internal.ScreenHelper.buildTextLabel(obj.ContentPanel, '', [20 50 450 50], obj.FontSize);
        end
        
        function updateBoardDropdown(obj)
            %Helper function that shows the correct set of boards based on
            %connection type selected.
            [boards, index] = getSupportedBoards(obj.Workflow.HWInterface, obj.Workflow.ConnectionType, obj.Workflow.Board);
            obj.BoardDropDown.Items = boards;
            obj.BoardDropDown.ValueIndex = index;
        end
        
        function updatePortDropdown(obj)
            %Helper function that shows the correct set of ports at current
            %screen
            %Keep the same selected port if board has not changed
            if strcmpi(obj.PrevBoard, obj.Workflow.Board)
                [availablePorts, index] = getAvailableArduinoPorts(obj.Workflow.HWInterface, obj.Workflow.Port);
            else %Reset port to "select a value" if board has changed
                [availablePorts, index] = getAvailableArduinoPorts(obj.Workflow.HWInterface, 'select a value');
            end
            obj.PortDropDown.Items = availablePorts;
            obj.PortDropDown.ValueIndex = index;
            obj.Workflow.Port = obj.PortDropDown.Value;
        end
        
        function updateBoard(obj, src, ~)
            %Function that is invoked when a radio button is selected. This 
            %function updates the selection.
            obj.Workflow.Board = src.Value;
        end
        
        function updatePort(obj, src, ~)
            %Function that is invoked when a radio button is selected. This 
            %function updates the selection.
            obj.Workflow.Port = src.Value;
        end
        
        function selectIncludedLibrary(obj, src, ~)
            %Function that is invoked when a checkbox is updated in the
            %checkbox group for selecting libraries
            libs = arduinoio.internal.getFullLibraryList({src.Text});
            if src.Value % checked
                obj.Workflow.Libraries = union(obj.Workflow.Libraries, {src.Text});
                if numel(libs)>1 % checked lib has dependent libs
                    for index=1:numel(obj.LibraryCheckBox)
                        if ismember(obj.LibraryCheckBox{index}.Text, libs)
                            obj.LibraryCheckBox{index}.Value = true;
                            obj.Workflow.Libraries = union(obj.Workflow.Libraries, {obj.LibraryCheckBox{index}.Text});
                        end
                    end
                end
            else % unchecked
                % check if lib to be removed is dependent by any checked lib
                for index=1:numel(obj.Workflow.Libraries)
                    libs = arduinoio.internal.getFullLibraryList(obj.Workflow.Libraries(index));
                    if numel(libs)>1&&~strcmpi(src.Text,obj.Workflow.Libraries{index})&&ismember(src.Text, libs)
                        src.Value = true; % stay checked
                        return;
                    end
                end
                obj.Workflow.Libraries(strcmpi(obj.Workflow.Libraries, src.Text)) = [];
            end
        end
        
        function uploadServer(obj, ~, ~)
            %Function that programs the board with Arduino server based on
            %user-selected information
            disableScreen(obj);
            obj.ProgramProgress.Visible = 'on';
            c = onCleanup(@() cleanup(obj));
            
            successFlag = false;
            obj.ProgramProgress.Indeterminate = true;
            if strcmpi(obj.Workflow.Port, 'select a value')
                id = 'MATLAB:arduinoio:general:noSerialPort';
                error(id, message(id).getString);
            end
            if strcmpi(obj.Workflow.Board, 'select a value')
                id = 'MATLAB:arduinoio:general:noBoardSelected';
                error(id, message(id).getString);
            end
            obj.ErrorLabelText.Text =  getString(message('MATLAB:arduinoio:general:programmingArduino', obj.Workflow.Board, obj.Workflow.Port));
            if ~isempty(obj.LogLink)
                obj.LogLink.Visible = 'off';
                delete(obj.LogLink);
                obj.LogLink=[];
            end
            drawnow;
            try
                msg = uploadArduinoServer(obj.Workflow.HWInterface,obj.Workflow);
                if ~isempty(msg)
                    obj.ErrorLabelText.FontColor = arduinoio.setup.internal.ScreenHelper.RED;
                    obj.ErrorLabelText.Text = getString(message('MATLAB:arduinoio:general:programArduinoFailed'));
                    log(obj.Workflow.Logger, msg);
                    obj.LogLink = arduinoio.setup.internal.ScreenHelper.buildHelpText(obj.ContentPanel, ...
                        getString(message('MATLAB:arduinoio:general:programLogLinkText',obj.Workflow.LogFileName,obj.Workflow.LogFileName)), [20 5 430 50]);
                    obj.LogLink.Visible='on';
                    return;
                end
                if obj.Workflow.ConnectionType == arduinoio.internal.ConnectionTypeEnum.WiFi
                    obj.ErrorLabelText.Text =  message('MATLAB:arduinoio:general:obtainingIP').getString;
                    drawnow;
                    ipAddress = retrieveIPAddress(obj.Workflow.HWInterface, obj.Workflow.Port);
                    if isempty(ipAddress)
                        obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:obtainIPFailed').getString;
                    else
                        obj.Workflow.DeviceAddress = ipAddress;
                        successFlag = true; 
                        obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:operationSuccessText').getString;
                    end
                else
                    obj.ErrorLabelText.Text = message('MATLAB:arduinoio:general:operationSuccessText').getString;
                    successFlag = true;
                end
                if successFlag 
                    obj.ErrorLabelText.FontColor = arduinoio.setup.internal.ScreenHelper.GREEN;
                else
                    obj.ErrorLabelText.FontColor = arduinoio.setup.internal.ScreenHelper.RED; 
                end
            catch e
                obj.ErrorLabelText.FontColor = arduinoio.setup.internal.ScreenHelper.RED;
                switch e.identifier
                    case 'MATLAB:arduinoio:general:openFailed'
                        obj.ErrorLabelText.Text = getString(message('MATLAB:arduinoio:general:openArduinoFailed', obj.Workflow.Port, obj.Workflow.Board));
                    case 'MATLAB:RMDIR:NoDirectoriesRemoved'
                        obj.ErrorLabelText.Text = getString(message('MATLAB:arduinoio:general:NoDirectoriesRemoved', fullfile(tempdir, 'ArduinoServer')));
                    case 'MATLAB:arduinoio:general:invalidIDEPath'
                        obj.ErrorLabelText.Text = getString(message('MATLAB:arduinoio:general:invalidIDEPathNoLink', arduinoio.IDERoot));
                    otherwise
                        obj.ErrorLabelText.Text = e.message;
                end
            end
            
            function cleanup(obj)
                obj.enableScreen();
                obj.ProgramProgress.Indeterminate = false;
                obj.ProgramProgress.Visible = 'off';
                if successFlag
                    obj.NextButton.Enable = 'on';
                else
                    obj.NextButton.Enable = 'off';
                end
            end
        end
        
        function saveCurrentSettings(obj)
            obj.PrevConnectionType = obj.Workflow.ConnectionType;
            obj.PrevBoard = obj.Workflow.Board;
            obj.PrevSSID = obj.Workflow.SSID;
            obj.PrevPassword = obj.Workflow.Password;
            obj.PrevKey = obj.Workflow.Key;
            obj.PrevKeyIndex = obj.Workflow.KeyIndex;
            obj.PrevPort = obj.Workflow.TCPIPPort;
            obj.PrevEncryption = obj.Workflow.Encryption;
        end
    end
end

% LocalWords:  BUILDTEXTLABEL hwmgr hwsetup arduinoio GETNEXTSCREENID
% LocalWords:  BUILDCONTENTPANE
