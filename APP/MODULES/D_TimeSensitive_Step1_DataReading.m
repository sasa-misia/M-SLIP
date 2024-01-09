if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Reading of rainfall files', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Data import
StatusPrevAnalysis = 0;
if exist([fold_var,sl,'AnalysisInformation.mat'], 'file')
    load([fold_var,sl,'AnalysisInformation.mat'], 'StabilityAnalysis')
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
    if isempty({dir([fold_raw_rain,sl,'*.xlsx']).name})
        Answer = uiconfirm(Fig, strcat("No excel in ",fold_raw_rain), ...
                           'No file in directory', 'Options','Search file');
        copyindirectory('xlsx', fold_raw_rain, 'mode','multiple')
    end

    Files = {dir([fold_raw_rain,sl,'*.xlsx']).name};
    ChoiceRec = listdlg('PromptString',{'Choose a file:',''}, 'ListString',Files);
    FileName_Rainfall = string(Files(ChoiceRec)); 
    NameFile = {'FileName_Rainfall'};

    drawnow % Remember to remove if in Standalone version
    figure(Fig) % Remember to remove if in Standalone version

    Ans = uiconfirm(Fig, ['Have you put stations in the correct order ' ...
                          'in <Stations table> sheet? (see guidelines)'], ...
                         'Reminder', 'Options','Yes, I have done it!');
    
    Sheet_Sta  = readcell([fold_raw_rain,sl,FileName_Rainfall], 'Sheet','Stations table');
    Sheet_Rain = readcell([fold_raw_rain,sl,FileName_Rainfall], 'Sheet','Data table');

    xLongSta = [Sheet_Sta{2:end,8}]';
    yLatSta  = [Sheet_Sta{2:end,9}]';

    Stations = string(Sheet_Sta(2:end,1));
    StationsNumber = length(Stations);
    CoordinatesRainGauges = [xLongSta, yLatSta];
    RainGauges = {Stations, CoordinatesRainGauges};

    RainfallDates = [Sheet_Rain{cellfun(@isdatetime,Sheet_Rain)}];
    RainfallDates = unique(dateshift(RainfallDates,'start','hours','nearest')); % Minutes if analysis time range < 1 hour
    RainfallDates(1) = []; % You only want end dates
    RainfallDates.Format = 'dd/MM/yyyy HH:mm'; % HH:mm:ss if analysis time range < 1 hour

    HeaderLine = find(cellfun(@isdatetime, Sheet_Rain), 1); % Automatically recognize excel file header line
    
    HoursNum = 0; 
    for i1 = HeaderLine:length(Sheet_Rain)
        if ~ismissing(Sheet_Rain{i1,2}); HoursNum = HoursNum+1; else; break; end
    end
    
    RainNumeric = [Sheet_Rain{cellfun(@isnumeric, Sheet_Rain)}]';

    if numel(RainNumeric) ~= HoursNum*StationsNumber
        error("Your excel is inconsistent in the 3rd column, please check it!")
    end

    GeneralRainData = zeros(HoursNum,StationsNumber);
    
    for i1 = 1:StationsNumber
        GeneralRainData(:,i1) = RainNumeric((i1-1)*(HoursNum)+1:(i1-1)*(HoursNum)+(HoursNum));
    end
    
    GeneralRainData(isnan(GeneralRainData))  = 0;
    GeneralRainData(GeneralRainData == -999) = 0;
    GeneralRainData = GeneralRainData';
    
    GeneralDatesStart = dateshift([Sheet_Rain{HeaderLine:HoursNum+HeaderLine-1,1}]', 'start','hours', 'nearest');
    GeneralDatesEnd   = dateshift([Sheet_Rain{HeaderLine:HoursNum+HeaderLine-1,2}]', 'start','hours', 'nearest');

    VariablesRainfall = {'GeneralRainData', 'RainGauges', 'RainfallDates'};

end
    
%% Rainfall Forecast
if AnswerRainfallFor == 1
    %% Import rainfall forecast data    
    Files = {dir([fold_raw_rain_for,sl,'*.']).name, dir([fold_raw_rain_for,sl,'*.grib']).name}; % '*.' is for file without extension
    Files(1:2) = [];
    ChoiceForcstFile = listdlg('PromptString',{'Choose a file:',''}, 'ListString',Files);
    FileNameForecast = strcat(fold_raw_rain_for,sl,char(Files(ChoiceForcstFile)));
    try setup_nctoolbox; catch; disp('A problem has occurred in nctoolbox'); end

    ProgressBar.Message = strcat("Processing data...");
    drawnow % Remember to remove if in Standalone version
    figure(Fig) % Remember to remove if in Standalone version
    
    ForecastData = cell(size(ChoiceForcstFile,2),5);
    for i1 = 1:size(ChoiceForcstFile,2)
        GribData = ncdataset(FileNameForecast(i1,:));  
        GribLat  = double(GribData.data('lat'));
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

    VariablesRainfall = [VariablesRainfall, {'ForecastData','GridForecastModel'}];
    NameFile = [NameFile, {'FileNameForecast'}];
end

%% Analysis type
switch AnalysisCase
    case 'SLIP'
        %% SLIP process
        dTRecordings = RainfallDates(2)-RainfallDates(1);
        AnalysisDateMaxRange = [min(RainfallDates)+days(30), max(RainfallDates)];
        AnalysisDates = AnalysisDateMaxRange(1):dTRecordings:AnalysisDateMaxRange(2);
        AnalysisDates = datetime(AnalysisDates, 'Format','dd/MM/yyyy HH:mm:ss');


        if AnswerRainfallFor == 1
            for i1 = 1:size(ChoiceForcstFile,2)
                ForecastTime = ForecastData{i1,2};
                IndexForecast = find(ForecastTime-days(30) > RainfallDates(1));   
                if ~isempty(IndexForecast)
                    ForecastData{i1,5} = ForecastTime(IndexForecast);
                end
            end
            AnalysisDates = unique(cat(1,ForecastData{:,5}));

            if isempty(AnalysisDates); error('DT 1'); end
        end   

        ChoiceEvent = listdlg('PromptString',{'Select event(s) to analyse through SLIP:',''}, ...
                              'ListString',AnalysisDates);
        AnalysisEvents = AnalysisDates(ChoiceEvent);
        
        drawnow % Remember to remove if in Standalone version
        figure(Fig) % Remember to remove if in Standalone version

        RainfallSetInterval = {AnalysisEvents(1)-days(30)+dTRecordings, AnalysisEvents(end)}; % +dTRecordings because these are end dates and include an hour of rec
        RainfallSetIndex = [find(abs(minutes(GeneralDatesEnd-RainfallSetInterval{1})) <= 1), ...
                            find(abs(minutes(GeneralDatesEnd-RainfallSetInterval{2})) <= 1)];

        StabilityEventsAnalysed = length(AnalysisEvents); % Number of stability analysis
        
        StabilityAnalysis = {StabilityEventsAnalysed, AnalysisEvents, RainfallSetIndex};

        if StatusPrevAnalysis == 1
            DiffNumOfEvents = StabilityAnalysis{1} ~= StabilityAnalysisOld{1};
            DiffDates       = any(StabilityAnalysis{2} ~= StabilityAnalysisOld{2});
            DiffIndices     = any(StabilityAnalysis{3} ~= StabilityAnalysisOld{3});
            if DiffNumOfEvents || DiffDates || DiffIndices
                StatusPrevAnalysis = 0;
            end
        end
           
        IndexInterpolation = RainfallSetIndex(1):RainfallSetIndex(end);
        VariablesInterpolation = {'IndexInterpolation'};
        RainfallEvents = AnalysisEvents;

        if AnswerRainfallFor == 1; ForecastChoice = AnalysisDates(ChoiceEvent); end % Investigate this line
                    
        VariablesAnalysisSLIP = {'StabilityAnalysis', 'AnalysisDateMaxRange', 'StatusPrevAnalysis'};
        save([fold_var,sl,'AnalysisInformation.mat'], VariablesAnalysisSLIP{:});

    case 'Other'
        %% General process
        if AnswerRainfallFor == 1
            RainfallDates = unique(cat(1,ForecastData{:,2}));
        end
        
        ChoiceRain = listdlg('PromptString',{'Select event(s):',''}, ...
                             'ListString',RainfallDates);
        RainfallEvents = string(RainfallDates(ChoiceRain));
        RainfallEvents = datetime(RainfallEvents, 'Format','dd/MM/yyyy HH:mm');

        drawnow % Remember to remove if in Standalone version
        figure(Fig) % Remember to remove if in Standalone version

        if AnswerRainfallFor == 1
            ForecastChoice = RainfallDates(ChoiceRain);
        else
            GeneralDatesStart = datetime(GeneralDatesStart, 'Format','dd/MM/yyyy HH:mm:ss');
            RainfallSetIndex = zeros(1, size(RainfallEvents,2));
            for i3 = 1:size(RainfallEvents,2)
                RainfallSetIndex(i3) = find(abs(minutes(GeneralDatesStart-RainfallEvents(i3)))<=1);
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
            ChoiceForcst = listdlg('PromptString',{'Select forcasted hours:',''}, ...
                                   'ListString',string(PossibleHours));
            SelectedHoursRun{1,1} = PossibleHours(ChoiceForcst);
            SelectedHoursRun{1,2} = RunNumber(ChoiceForcst);
        else
            [SelectedHoursRun{i1,1}, PosMin] = min(PossibleHours);
            SelectedHoursRun{i1,2} = RunNumber(PosMin);
        end


    end    

    %% SLIP and forecast
    if strcmp(AnalysisCase,'SLIP')
        SelectedHoursRun(:,1) = cellfun(@(x) 1:x, SelectedHoursRun(:,1), 'UniformOutput',false);
    end

    VariablesInterpolation = [VariablesInterpolation, {'SelectedHoursRun'}];
end

%% Saving
ProgressBar.Message = strcat("Saving data...");
drawnow

SaveNewFile = true;
if exist([fold_var,sl,'RainInterpolated.mat'], 'file')
    Overwrite = uiconfirm(Fig, 'RainInterpolated.mat file already exist. Overwrite or update?', ...
                               'Overwrite', 'Options',{'Overwrite', 'Update'});
    if strcmp(Overwrite,'Update'); SaveNewFile = false; end
end

if SaveNewFile
    saveswitch([fold_var,sl,'RainInterpolated.mat'], VariablesInterpolation);
else
    save([fold_var,sl,'RainInterpolated.mat'], VariablesInterpolation{:}, '-append');
end

save([fold_var,sl,'UserTimeSens_Answers.mat'], NameFile{:}, 'AnalysisCase', AnswerRainfall{:});
save([fold_var,sl,'GeneralRainfall.mat'], VariablesRainfall{:});

% close(Fig) % Remember to comment this line if is app version