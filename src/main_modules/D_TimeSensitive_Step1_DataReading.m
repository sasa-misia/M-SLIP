if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Cancelable','on', 'Message','Reading files...');
drawnow

%% Data import
sl = filesep;
StatusPrevAnalysis = 0;
if exist([fold_var,sl,'AnalysisInformation.mat'], 'file')
    load([fold_var,sl,'AnalysisInformation.mat'], 'StabilityAnalysis')
    StabilityAnalysisOld = StabilityAnalysis;
    clear StabilityAnalysis
    StatusPrevAnalysis = 1;
end

Options  = {'Rainfall', 'Temperature'};
DataRead = uiconfirm(Fig, 'What type of data do you want to read?', ...
                          'Reading Data', 'Options',Options, 'DefaultOption',1);

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
            fold_raw_data     = [fold_raw,sl,DataRead];
            fold_raw_data_for = [fold_raw,sl,DataRead,' Forecast'];

            if ~exist(fold_raw_data, 'dir')
                mkdir(fold_raw_data)
                mkdir(fold_raw_data_for)
            end
        end
end

%% Initialization
VariablesRecorded  = {};
VariablesFilenames = {};
VariablesInterpol  = {};

%% Data Recording
if AnswerTypeRec == 1
    %% Import rainfall data record and station
    if isempty({dir([fold_raw_data,sl,'*.xlsx']).name})
        Ans1 = uiconfirm(Fig, strcat("No excel in ",fold_raw_data), ...
                                'No file in directory', 'Options','Search file');
        copyindirectory('xlsx', fold_raw_data, 'mode','multiple')
    end

    Files              = {dir([fold_raw_data,sl,'*.xlsx']).name};
    FileName_DataRec   = char(listdlg2({'Choose a file:'}, Files));
    VariablesFilenames = {'FileName_DataRec'};

    FullNmeRec = [fold_raw_data,sl,FileName_DataRec];
    FileSheets = sheetnames(FullNmeRec);
    Sheets2Use = listdlg2({'Data table:', 'Stations table:'}, FileSheets);
    ReadOption = listdlg2({'Auto fill (missing data):', 'Filter to stations:'}, ...
                          { {'OtherSta','Zeros','AverageYr','AverageLNE','NaN'}, ...
                            {'Yes','No'} });
    AutFllMode = ReadOption{1};
    if strcmp(ReadOption{2}, 'Yes'); StatFilt = true; else; StatFilt = false; end

    [RecDatesStartsPerSta, RecDatesEndsPerSta, ...
        RecNumDataPerSta, Gauges] = readtimesenscell(FullNmeRec, 'AutoFill',AutFllMode, ...
                                                                 'StatsFilt',StatFilt, ...
                                                                 'DataSheet',Sheets2Use{1}, ...
                                                                 'StationSheet',Sheets2Use{2});

    %% Adjustment of data and dates
    dTRecRaw = RecDatesStartsPerSta{1}(2)-RecDatesStartsPerSta{1}(1);
    DltaTime = hours(str2double(inputdlg2({['Delta time rec (current is ',num2str(hours(dTRecRaw)),' h):']}, 'DefInp',{num2str(hours(dTRecRaw))}))); % In hours!!!
    PrmptsMd = strcat({'Aggregation mode, column '},string(1:size(RecNumDataPerSta{1}, 2)),{':'});
    AggrMode = listdlg2(PrmptsMd, {'sum', 'avg', 'min', 'max'});
    [GeneralDatesStart, GeneralDatesEnd, ...
            GeneralData] = adjustrecords(RecDatesStartsPerSta, ...
                                         RecDatesEndsPerSta, ...
                                         RecNumDataPerSta, 'DeltaTime',DltaTime, ...
                                                           'AggrMode',AggrMode, ...
                                                           'ReplaceVal',[nan, 0; -999, 0]);

    GenDataProps = inputdlg2(strcat({'Label name for '},DataRead,{' '}, ...
                                    string(1:numel(GeneralData))), ...
                                'DefInp',repmat(DataRead, numel(GeneralData), 1));

    dTRecsAdj = GeneralDatesStart(2) - GeneralDatesStart(1);

    RecDatesEndCommon = GeneralDatesEnd;

    VariablesRecorded = {'GeneralData', 'Gauges', 'RecDatesEndCommon', 'GenDataProps'};
end
    
%% Rainfall Forecast
if AnswerTypeFor == 1
    %% Import rainfall forecast data
    Files = {dir([fold_raw_data_for,sl,'*.']).name, dir([fold_raw_data_for,sl,'*.grib']).name}; % '*.' is for file without extension
    Files(1:2) = [];
    ChoiceForcstFile = checkbox2(Files, 'Title',{'Choose a file:'}, 'OutType','NumInd');
    FileNameForecast = strcat(fold_raw_data_for,sl,char(Files(ChoiceForcstFile)));
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

        dTForsRaw = ForecastTime(2) - ForecastTime(1);
        if dTForsRaw ~= dTRecsAdj
            error(['Delta time in recordings is different from forecast! ', ...
                   'Please uniform it or contact the support.'])
        end
        
        HoursForecast = ForecastTime-ModelRunTime;
        ForecastData{i1,1} = ModelRunTime;
        ForecastData{i1,2} = ForecastTime;
        ForecastData{i1,3} = HoursForecast;
        ForecastData{i1,4} = RainTemp;

        GridForecastModel = {MeshLong, MeshLat};
    end

    VariablesRecorded  = [VariablesRecorded, {'ForecastData', 'GridForecastModel'}];
    VariablesFilenames = [VariablesFilenames, {'FileNameForecast'}];
end

%% Analysis type
switch AnalysisCase
    case 'SLIP'
        if hours(dTRecsAdj) < 1
            error(['Rain data is discretized in less than 1 hour. ', ...
                   'It could become too large and it may not work! ', ...
                   'Please contanct the support.'])
        elseif hours(dTRecsAdj) > 1
            warning(['Rain data is discretized in more than 1 hour. ', ...
                     'It may not work! Please contanct the support.'])
        end

        %% SLIP process
        dTRecsShifted         = RecDatesEndCommon(2) - RecDatesEndCommon(1);
        AnalysisDateMaxRange  = [min(RecDatesEndCommon)+days(30), max(RecDatesEndCommon)];
        PossibleAnalysisDates = AnalysisDateMaxRange(1) : dTRecsShifted : AnalysisDateMaxRange(2);
        PossibleAnalysisDates.Format = 'dd/MM/yyyy HH:mm:ss';

        if AnswerTypeFor == 1
            for i1 = 1:size(ChoiceForcstFile,2)
                ForecastTime  = ForecastData{i1,2};
                IndexForecast = find(ForecastTime-days(30) > RecDatesEndCommon(1));   
                if ~isempty(IndexForecast)
                    ForecastData{i1,5} = ForecastTime(IndexForecast);
                end
            end
            PossibleAnalysisDates = unique(cat(1,ForecastData{:,5}));
            if isempty(PossibleAnalysisDates); error('DT 1'); end
        end

        ChoiceEvent    = checkbox2(string(PossibleAnalysisDates), 'Title',{'Select event(s) to analyse:'}, 'OutType','NumInd');
        AnalysisEvents = PossibleAnalysisDates(ChoiceEvent);

        AnalysisInterval = {AnalysisEvents(1)-days(30)+dTRecsShifted, AnalysisEvents(end)}; % +dTRecsShifted because these are end dates and include an hour of rec
        AnalysisIndices  = [ find(abs(minutes(GeneralDatesEnd-AnalysisInterval{1})) <= 1), ...
                             find(abs(minutes(GeneralDatesEnd-AnalysisInterval{2})) <= 1) ];

        NumOfEventsAnalysed = length(AnalysisEvents); % Number of stability analysis

        StabilityAnalysis = {NumOfEventsAnalysed, AnalysisEvents, AnalysisIndices};
        
        if StatusPrevAnalysis == 1
            DiffNumOfEvents = StabilityAnalysis{1} ~= StabilityAnalysisOld{1};
            DiffDates       = not(isequal(StabilityAnalysis{2}, StabilityAnalysisOld{2}));
            DiffIndices     = any(StabilityAnalysis{3} ~= StabilityAnalysisOld{3});
            if DiffNumOfEvents || DiffDates || DiffIndices
                StatusPrevAnalysis = 0;
            end
        end
           
        IndexInterpolation = AnalysisIndices(1) : AnalysisIndices(end);
        VariablesInterpol  = [VariablesInterpol, {'IndexInterpolation'}];

        if AnswerTypeFor == 1; ForecastChoice = PossibleAnalysisDates(ChoiceEvent); end % Investigate this line
                    
        VariablesAnalysisSLIP = {'StabilityAnalysis', 'AnalysisDateMaxRange', 'StatusPrevAnalysis'};
        save([fold_var,sl,'AnalysisInformation.mat'], VariablesAnalysisSLIP{:});

    case 'Other'
        %% General process
        if AnswerTypeFor == 1
            RecDatesEndCommon = unique(cat(1,ForecastData{:,2}));
        end
        
        ChoiceEvent    = checkbox2(string(RecDatesEndCommon), 'Title',{'Select event(s):'}, 'OutType','NumInd');
        AnalysisEvents = RecDatesEndCommon(ChoiceEvent);
        AnalysisEvents.Format = 'dd/MM/yyyy HH:mm';

        drawnow % Remember to remove if in Standalone version
        figure(Fig) % Remember to remove if in Standalone version

        if AnswerTypeFor == 1
            ForecastChoice = RecDatesEndCommon(ChoiceEvent);
        else
            AnalysisIndices = zeros(1, size(AnalysisEvents,2));
            for i1 = 1:size(AnalysisEvents,2)
                AnalysisIndices(i1) = find(abs(minutes(GeneralDatesEnd-AnalysisEvents(i1)))<=1);
            end
            IndexInterpolation = AnalysisIndices;
            VariablesInterpol  = [VariablesInterpol, {'IndexInterpolation'}];
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
            ChoiceForcst = checkbox2(string(PossibleHours), 'Title',{'Select forcasted hours:'}, 'OutType','NumInd');
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
    VariablesInterpol = [VariablesInterpol, {'SelectedHoursRun'}];
end

%% Saving
ProgressBar.Message = 'Saving data...';

NameInterp  = [ShortName,'Interpolated.mat'];
NameGeneral = ['General',DataRead,'.mat'];
AnswerType  = {'AnswerTypeRec', 'AnswerTypeFor', 'InterpDuration'};

SaveNewFile = true;
if exist([fold_var,sl,ShortName,'Interpolated.mat'], 'file')
    Overwrite = uiconfirm(Fig, [ShortName,'Interpolated.mat file already exist. Overwrite or update?'], ...
                               'Overwrite', 'Options',{'Overwrite', 'Update'});
    if strcmp(Overwrite,'Update'); SaveNewFile = false; end
end

if SaveNewFile
    saveswitch([fold_var,sl,NameInterp], VariablesInterpol);
else
    save([fold_var,sl,NameInterp], VariablesInterpol{:}, '-append');
end

save([fold_var,sl,'UserTimeSens_Answers.mat'], VariablesFilenames{:},'AnalysisCase',AnswerType{:});
save([fold_var,sl,NameGeneral               ], VariablesRecorded{:});

close(ProgressBar) % Remember to replace ProgressBar with Fig if you are in standalone version