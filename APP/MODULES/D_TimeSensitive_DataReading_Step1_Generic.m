% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Reading of files', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Data import
cd(fold_var)
StatusPrevAnalysis = 0;
if exist('AnalysisInformation.mat', 'file')
    load('AnalysisInformation.mat', 'StabilityAnalysis')
    StabilityAnalysisOld = StabilityAnalysis;
    clear StabilityAnalysis
    StatusPrevAnalysis = 1;
end

Options = {'Rainfall', 'Temperature'};
DataRead = uiconfirm(Fig, 'What type of data do you want to read?', ...
                          'Reading Data', 'Options',Options, 'DefaultOption',2);

switch DataRead
    case 'Rainfall'
        ShortName = 'Rain';
        fold_raw_data     = fold_raw_rain;
        fold_raw_data_for = fold_raw_rain_for;

    case 'Temperature'
        ShortName = 'Temp';
        if exist('fold_raw_temp', 'var')
            fold_raw_data     = fold_raw_temp;
            fold_raw_data_for = fold_raw_temp_for;
        else
            fold_raw_temp     = [fold_raw,sl,DataRead];
            fold_raw_temp_for = [fold_raw,sl,DataRead,' Forecast'];

            mkdir(fold_raw_temp)
            mkdir(fold_raw_temp_for)
        end
end

%% Initialization
VariablesRecorded = {};
FileNames = {};

%% Data Recording
if AnswerTypeRec == 1
    %% Import rainfall data record and station
    cd(fold_raw_data)
    if isempty({dir('*.xlsx').name})
        Ans1 = uiconfirm(Fig, strcat("No excel in ",fold_raw_data), ...
                              'No file in directory', 'Options','Search file');
        copyindirectory('xlsx', fold_raw_data, 'mode','multiple')
    end

    Files         = {dir('*.xlsx').name};
    ChoiceRec     = listdlg('PromptString',{'Choose a file:',''}, 'ListString',Files);
    FileName_DataRec = string(Files(ChoiceRec)); 
    FileNames      = {'FileName_DataRec'};

    drawnow % Remember to remove if in Standalone version
    figure(Fig) % Remember to remove if in Standalone version

    Ans2 = uiconfirm(Fig, ['Have you put stations in the correct order ' ...
                           'in <Stations table> sheet? (see guidelines)'], ...
                          'Reminder', 'Options','Yes, I have done it!');
    
    Sheet_Stations = readcell(FileName_DataRec, 'Sheet','Stations table'); % REMEMBER: in this sheet you must put stations in the same order of Data table!
    Sheet_DataRec  = readcell(FileName_DataRec, 'Sheet','Data table');
    cd(fold0)

    xLongSta = [Sheet_Stations{2:end,8}]';
    yLatSta  = [Sheet_Stations{2:end,9}]';

    Stations          = string(Sheet_Stations(2:end,1));
    StationsNumber    = length(Stations);
    CoordinatesGauges = [xLongSta, yLatSta];
    Gauges            = {Stations, CoordinatesGauges};

    RecDates        = [Sheet_DataRec{cellfun(@isdatetime,Sheet_DataRec)}];
    RecDates        = unique(dateshift(RecDates, 'start','hours', 'nearest')); % Minutes if analysis time range < 1 hour
    RecDates(1)     = []; % You only want end dates
    RecDates.Format = 'dd/MM/yyyy HH:mm'; % HH:mm:ss if analysis time range < 1 hour

    HeaderLine = find(cellfun(@isdatetime, Sheet_DataRec), 1); % Automatically recognize excel file header line 
    ObsNum     = find(cellfun(@(x) all(ismissing(x)), Sheet_DataRec(HeaderLine:end,2)), 1) - 1; % -1 to remove the last row, that is missing
    
    DataNumeric = [Sheet_DataRec{cellfun(@isnumeric, Sheet_DataRec)}]';

    if numel(DataNumeric) ~= ObsNum*StationsNumber
        error("Your excel is inconsistent in the 3rd column, please check it!")
    end

    GeneralData = zeros(ObsNum,StationsNumber);   
    for i1 = 1:StationsNumber
        GeneralData(:,i1) = DataNumeric((i1-1)*(ObsNum)+1 : i1*(ObsNum));
    end
    
    GeneralData(isnan(GeneralData))  = 0;
    GeneralData(GeneralData == -999) = 0;
    GeneralData = GeneralData';
    
    GeneralDatesStart = dateshift([Sheet_DataRec{HeaderLine : ObsNum+HeaderLine-1,1}]', 'start','hours', 'nearest');
    GeneralDatesEnd   = dateshift([Sheet_DataRec{HeaderLine : ObsNum+HeaderLine-1,2}]', 'start','hours', 'nearest');

    VariablesRecorded = {'GeneralData', 'Gauges', 'RecDates'};

end
    
%% Rainfall Forecast
if AnswerTypeFor == 1
    %% Import rainfall forecast data    
    cd(fold_raw_data_for)
    Files = {dir('*.').name, dir('*.grib').name}; % '*.' is for file without extension
    Files(1:2) = [];
    ChoiceForcstFile = listdlg('PromptString',{'Choose a file:',''}, 'ListString',Files);
    FileNameForecast = strcat(fold_raw_data_for,sl,char(Files(ChoiceForcstFile)));
    try setup_nctoolbox; catch; disp('A problem has occurred in nctoolbox'); end

    ProgressBar.Message = strcat("Processing data...");
    drawnow % Remember to remove if in Standalone version
    figure(Fig) % Remember to remove if in Standalone version
    
    ForecastData = cell(size(ChoiceForcstFile,2),5);
    for i1 = 1:size(ChoiceForcstFile,2)
        GribData = ncdataset(FileNameForecast(i1,:));  
        GribLat = double(GribData.data('lat'));
        GribLong = double(GribData.data('lon'));
        [MeshLong, MeshLat] = meshgrid(GribLong, GribLat);
        RainTemp = double(GribData.data('Total_precipitation_surface_1_Hour_DifferenceFromEnd'));
        Instants = GribData.time('time1_bounds');
        InstantsTime = datetime(Instants, 'ConvertFrom','datenum');
        InstantsTime.Format = 'dd/MM/yyyy HH:mm'; % HH:mm:ss if analysis time range < 1 hour
        ModelRunTime = InstantsTime(1,1);
        ForecastTime = InstantsTime(:,2);   
        
        HoursForecast = ForecastTime-ModelRunTime;
        ForecastData{i1,1} = ModelRunTime;
        ForecastData{i1,2} = ForecastTime;
        ForecastData{i1,3} = HoursForecast;
        ForecastData{i1,4} = RainTemp;

        GridForecastModel = {MeshLong, MeshLat};
    end
    cd(fold0)

    VariablesRecorded = [VariablesRecorded, {'ForecastData','GridForecastModel'}];
    FileNames = [FileNames, {'FileNameForecast'}];
end

%% Analysis type
switch AnalysisCase
    case 'SLIP'
        %% SLIP process
        dTRecordings         = RecDates(2)-RecDates(1);
        AnalysisDateMaxRange = [min(RecDates)+days(30), max(RecDates)];
        PossibleAnalysisDates        = AnalysisDateMaxRange(1):dTRecordings:AnalysisDateMaxRange(2);
        PossibleAnalysisDates.Format = 'dd/MM/yyyy HH:mm:ss';

        if AnswerTypeFor == 1
            for i1 = 1:size(ChoiceForcstFile,2)
                ForecastTime  = ForecastData{i1,2};
                IndexForecast = find(ForecastTime-days(30) > RecDates(1));   
                if ~isempty(IndexForecast)
                    ForecastData{i1,5} = ForecastTime(IndexForecast);
                end
            end
            PossibleAnalysisDates = unique(cat(1,ForecastData{:,5}));
            if isempty(PossibleAnalysisDates); error('DT 1'); end
        end

        ChoiceEvent = listdlg('PromptString',{'Select event(s) to analyse through SLIP:',''}, 'ListString',PossibleAnalysisDates);
        AnalysisEvents = PossibleAnalysisDates(ChoiceEvent);
        
        drawnow % Remember to remove if in Standalone version
        figure(Fig) % Remember to remove if in Standalone version

        AnalysisInterval = {AnalysisEvents(1)-days(30)+dTRecordings, AnalysisEvents(end)}; % +dTRecordings because these are end dates and include an hour of rec
        AnalysisIndices  = [ find(abs(minutes(GeneralDatesEnd-AnalysisInterval{1})) <= 1), ...
                             find(abs(minutes(GeneralDatesEnd-AnalysisInterval{2})) <= 1) ];

        NumOfEventsAnalysed = length(AnalysisEvents); % Number of stability analysis

        StabilityAnalysis = {NumOfEventsAnalysed, AnalysisEvents, AnalysisIndices};
        
        if StatusPrevAnalysis == 1
            DiffNumOfEvents = StabilityAnalysis{1} ~= StabilityAnalysisOld{1};
            DiffDates       = any(StabilityAnalysis{2} ~= StabilityAnalysisOld{2});
            DiffIndices     = any(StabilityAnalysis{3} ~= StabilityAnalysisOld{3});
            if DiffNumOfEvents || DiffDates || DiffIndices
                StatusPrevAnalysis = 0;
            end
        end
           
        IndexInterpolation = AnalysisIndices(1):AnalysisIndices(end);

        VariablesInterpolation = {'IndexInterpolation'};

        if AnswerTypeFor == 1; ForecastChoice = PossibleAnalysisDates(ChoiceEvent); end % Investigate this line
                    
        cd(fold_var)
        VariablesAnalysisSLIP = {'StabilityAnalysis', 'AnalysisDateMaxRange', 'StatusPrevAnalysis'};
        save('AnalysisInformation.mat', VariablesAnalysisSLIP{:});
        cd(fold0)

    case 'Other'
        %% General process
        if AnswerTypeFor == 1
            RecDates = unique(cat(1,ForecastData{:,2}));
        end
        
        ChoiceEvent    = listdlg('PromptString',{'Select event(s):',''}, 'ListString',RecDates);
        AnalysisEvents = RecDates(ChoiceEvent);
        AnalysisEvents.Format = 'dd/MM/yyyy HH:mm';

        drawnow % Remember to remove if in Standalone version
        figure(Fig) % Remember to remove if in Standalone version

        if AnswerTypeFor == 1
            ForecastChoice = RecDates(ChoiceEvent);
        else
            AnalysisIndices = zeros(1, size(AnalysisEvents,2));
            for i1 = 1:size(AnalysisEvents,2)
                AnalysisIndices(i1) = find(abs(minutes(GeneralDatesEnd-AnalysisEvents(i1)))<=1);
            end
            VariablesInterpolation = {'AnalysisIndices'};
        end
end

%% Indexing for forecast rainfall
if AnswerTypeFor == 1
    %% General with forecast
    for i1 = 1:size(ForecastChoice,1)
        IndTemp = 1;
        RunNumber = [];
        PossibleHours = [];
        for i2 = 1:size(ForecastData,1)
            Indgood = find(ForecastChoice(i1)==ForecastData{i2,2});
            if ~isempty(Indgood)
                RunNumber(IndTemp) = i2;
                PossibleHours(IndTemp) = hours(ForecastData{i2,3}(Indgood));
                IndTemp = IndTemp+1;
            end
        end
        
        if size(ForecastChoice,1) == 1
            ChoiceForcst = listdlg('PromptString',{'Select forcasted hours:',''}, 'ListString',string(PossibleHours));
            SelectedHoursRun{1,1} = PossibleHours(ChoiceForcst);
            SelectedHoursRun{1,2} = RunNumber(ChoiceForcst);
        else
            [SelectedHoursRun{i1,1}, PosMin] = min(PossibleHours);
            SelectedHoursRun{i1,2} = RunNumber(PosMin);
        end
    end    

    %% SLIP with forecast
    if strcmp(AnalysisCase,'SLIP')
        SelectedHoursRun(:,1) = cellfun(@(x) 1:x, SelectedHoursRun(:,1), 'UniformOutput',false);
    end
    VariablesInterpolation = [VariablesInterpolation, {'SelectedHoursRun'}];
end

%% Saving
ProgressBar.Message = strcat("Saving data...");

NameInterp  = [ShortName, 'Interpolated.mat'];
NameGeneral = ['General', DataRead, '.mat'];
AnswerType  = {'AnswerTypeRec', 'AnswerTypeFor'};

cd(fold_var)
save('UserTimeSens_Answers.mat', FileNames{:},'AnalysisCase',AnswerType{:});
if exist(NameInterp, 'file')
    save(NameInterp, VariablesInterpolation{:}, '-append');
else
    save(NameInterp, VariablesInterpolation{:}, '-v7.3');
end
save(NameGeneral, VariablesRecorded{:});
cd(fold0)
close(ProgressBar) % Remember to replace ProgressBar with Fig if you are in standalone version