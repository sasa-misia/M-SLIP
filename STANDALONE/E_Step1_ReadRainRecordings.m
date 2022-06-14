clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Data import
tic
cd(fold_var)
load('UserE_Answers.mat');

StatusPrevAnalysis = 0;
if exist('AnalysisInformation.mat', 'file')
    load('AnalysisInformation.mat', 'StabilityAnalysis')
    StabilityAnalysisOld = StabilityAnalysis;
    clear StabilityAnalysis
    StatusPrevAnalysis = 1;
end

VariablesRainfall = {};
NameFile = {};
VariablesInterpolation = {};
AnswerRainfall = {'AnswerRainfallRec', 'AnswerRainfallFor'};

%% Rainfall Recording
if AnswerRainfallRec == 1
    %% Import rainfall data record and station
    cd(fold_raw_rain)
    Files = {dir('*.xlsx').name};
    Choice = listdlg('PromptString',{'Choose a file:',''}, 'ListString',Files);
    FileName_Rainfall = string(Files(Choice)); 
    NameFile = {'FileName_Rainfall'};

    Sheet_Sta = readcell(FileName_Rainfall, 'Sheet','Stations table');
    Sheet_Rain = readcell(FileName_Rainfall, 'Sheet','Data table');
    
    xLongSta = [Sheet_Sta{2:end,8}]';
    yLatSta = [Sheet_Sta{2:end,9}]';
    
    Stations = string(Sheet_Sta(2:end,1));
    StationsNumber = length(Stations);
    CoordinatesRainGauges = [xLongSta, yLatSta];
    RainGauges = {Stations, CoordinatesRainGauges};
    
    RainfallDates = unique([Sheet_Rain{cellfun(@isdatetime,Sheet_Rain)}]);
    RainfallDates(1) = [];
    RainfallDates.Format = 'dd/MM/yyyy HH:mm'; % HH:mm:ss if analysis time range < 1 hour
    RainfallDates = dateshift(RainfallDates,'start','hours','nearest'); % Minutes if analysis time range < 1 hour
    
    HeaderLine = find(cellfun(@isdatetime, Sheet_Rain), 1); % Automatically recognize excel file header line
    
    HoursNum = 0; 
    for i = HeaderLine:length(Sheet_Rain)
        if ~ismissing(Sheet_Rain{i,3}); HoursNum = HoursNum+1; else; break; end
    end
    
    RainNumeric = [Sheet_Rain{cellfun(@isnumeric, Sheet_Rain)}]';

    GeneralRainData = zeros(HoursNum, StationsNumber);
    for i = 1:StationsNumber
        GeneralRainData(:,i) = RainNumeric((i-1)*(HoursNum)+1:(i-1)*(HoursNum)+(HoursNum));
    end
    GeneralRainData(isnan(GeneralRainData)) = 0;
    GeneralRainData(GeneralRainData == -999) = 0;
    GeneralRainData = GeneralRainData';
    
    GeneralDatesStart = dateshift([Sheet_Rain{HeaderLine:HoursNum+HeaderLine-1,1}]', ...
                                    'start', 'hours', 'nearest'); % Minutes if analysis time range < 1 hour
    GeneralDatesEnd = dateshift([Sheet_Rain{HeaderLine:HoursNum+HeaderLine-1,2}]', ...
                                    'start', 'hours', 'nearest'); % Minutes if analysis time range < 1 hour
    
    VariablesRainfall = {'GeneralRainData', 'RainGauges', 'RainfallDates'};
end

%% Rainfall Forecast
if AnswerRainfallFor == 1
    %% Import rainfall forecast data
    cd(fold_raw_rain_for)
    Files = {dir('*.').name, dir('*.grib').name}; % '*.' is for file without extension
    Files(1:2) = [];
    Selection = listdlg('PromptString',{'Choose a file:',''}, 'ListString',Files);
    FileNameForecast = strcat(fold_raw_rain_for,sl,char(Files(Selection)));
    
    try setup_nctoolbox; catch; disp('A problem has occurred in nctoolbox'); end
    
    ForecastData = cell(size(Selection,2), 5);
    
    for i1 = 1:size(Selection,2)
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
    VariablesRainfall = [VariablesRainfall, {'ForecastData', 'GridForecastModel'}];
    NameFile = [NameFile, {'FileName_Forecast'}];
end

%% Analysis type
cd(fold_var)
switch AnalysisCase
    case 'SLIP'
        %% SLIP process
        dTRecordings = RainfallDates(2)-RainfallDates(1);
        AnalysisDateMaxRange = [min(RainfallDates)+days(30)+dTRecordings, max(RainfallDates)];
        AnalysisDates = AnalysisDateMaxRange(1):dTRecordings:AnalysisDateMaxRange(2);

        if AnswerRainfallFor == 1
            for i1 = 1:size(Selection,2)
                ForecastTime = ForecastData{i1,2};
                IndexForecast = find(ForecastTime-days(30) > RainfallDates(1));   
                if ~isempty(IndexForecast)
                    ForecastData{i1,5} = ForecastTime(IndexForecast);
                end
            end

            AnalysisDates = unique(cat(1,ForecastData{:,5}));
            if isempty(AnalysisDates); error('DT 1'); end
        end   

        EventChoice = listdlg('PromptString',{'Select event(s) to analyse through SLIP:',''}, ...
                              'ListString',AnalysisDates);
        AnalysisEvents = AnalysisDates(EventChoice);

        RainfallSetInterval = {AnalysisEvents(1)-days(30)-dTRecordings, AnalysisEvents(end)-dTRecordings}; % From 30 days before the first event to the hour before the last event
        RainfallSetIndex = [find(abs(minutes(GeneralDatesStart-RainfallSetInterval{1})) <= 1), ...
                            find(abs(minutes(GeneralDatesStart-RainfallSetInterval{2})) <= 1)];

        StabilityEventsAnalysed = hours(AnalysisEvents(end)-AnalysisEvents(1))+1; % Number of stability analysis
        StabilityAnalysis = {StabilityEventsAnalysed, AnalysisEvents, RainfallSetIndex};

        if StatusPrevAnalysis == 1
            Check = cellfun(@(x,y) any(x ~= y), StabilityAnalysis, StabilityAnalysisOld);
            if any(Check); StatusPrevAnalysis = 0; end
        end
           
        IndexInterpolation = RainfallSetIndex(1):RainfallSetIndex(end);
        VariablesInterpolation = {'IndexInterpolation'};
        RainfallEvents = AnalysisEvents;

        if AnswerRainfallFor == 1; ForecastChoice = AnalysisDates(EventChoice); end
        
        VariablesAnalysisSLIP = {'StabilityAnalysis', 'AnalysisDateMaxRange', 'StatusPrevAnalysis'};
        save('AnalysisInformation.mat', VariablesAnalysisSLIP{:});

    case 'Other'
        %% General process
        if AnswerRainfallFor == 1
            RainfallDates = unique(cat(1,ForecastData{:,2}));
        end
        
        EventChoice = listdlg('PromptString',{'Select event(s):',''}, 'ListString',RainfallDates);
        RainfallEvents = string(RainfallDates(EventChoice));
        RainfallEvents = datetime(RainfallEvents, 'Format','dd/MM/yyyy HH:mm');
        drawnow;

        if AnswerRainfallFor == 1
            ForecastChoice = RainfallDates(EventChoice);
        else
            GeneralDatesStart = datetime(GeneralDatesStart, 'Format','dd/MM/yyyy HH:mm:ss');
            for i3 = 1:size(RainfallEvents,2)
                RainfallSetIndex(i3) = find(abs(minutes(GeneralDatesStart-RainfallEvents(i3))) <= 1);
            end
            VariablesInterpolation = {'RainfallSetIndex'};
        end
end

%% Indexing for forecast rainfall
if AnswerRainfallFor == 1
    %% General with forecast
    for i1 = 1:size(ForecastChoice,1)
        Ind1 = 1;
        RunNumber = [];
        PossibleHours = [];

        for i2 = 1:size(ForecastData,1)
            Indgood = find(ForecastChoice(i1)==ForecastData{i2,2});
            if ~isempty(Indgood)
                RunNumber(Ind1) = i2;
                PossibleHours(Ind1) = hours(ForecastData{i2,3}(Indgood));
                Ind1 = Ind1+1;
            end
        end
        
        if size(ForecastChoice,1) == 1
            choice3=listdlg('PromptString',{'Select forcasted hours:',''}, ...
                            'ListString',string(PossibleHours));
            SelectedHoursRun{1,1} = PossibleHours(choice3);
            SelectedHoursRun{1,2} = RunNumber(choice3);
        else
            [SelectedHoursRun{i1,1}, posmin] = min(PossibleHours);
            SelectedHoursRun{i1,2} = RunNumber(posmin);
        end

    end    

    %% SLIP and forecast
    if strcmp(AnalysisCase,'SLIP')
        SelectedHoursRun(:,1) = cellfun(@(x) 1:x, SelectedHoursRun(:,1), 'UniformOutput',false);
    end
        VariablesInterpolation = [VariablesInterpolation, {'SelectedHoursRun'}];
end

%% Saving
cd(fold_var)
save('UserE_Answers.mat', NameFile{:}, '-append');

if exist('RainInterpolated.mat', 'file'); save('RainInterpolated.mat', VariablesInterpolation{:}, '-append');
else; save('RainInterpolated.mat', VariablesInterpolation{:}, '-v7.3'); end

save('GeneralRainfall.mat', VariablesRainfall{:});
cd(fold0)