if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Reading files...', 'Cancelable','on', ...
                                 'Indeterminate','on');
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

    drawnow % Remember to remove if in Standalone version
    figure(Fig) % Remember to remove if in Standalone version
    
    Sheet_StationsRaw = readcell([fold_raw_data,sl,FileName_DataRec], 'Sheet','Stations table'); % REMEMBER: in this sheet you should put stations in the same order of Data table!
    Sheet_DataRec     = readcell([fold_raw_data,sl,FileName_DataRec], 'Sheet','Data table');

    % Reordering of stations
    StationsRaw = string(Sheet_StationsRaw(2:end,1));

    IndStrPartDataSheet = cellfun(@(x) any(strcmp(class(x), {'char','string'})), Sheet_DataRec);
    StringPartDataSheet = string(Sheet_DataRec(IndStrPartDataSheet));

    IndStaInDataSheet = zeros(size(StationsRaw));
    for i1 = 1:length(StationsRaw)
        IndStaInDataSheet(i1) = find(contains(StringPartDataSheet, StationsRaw(i1), 'IgnoreCase',true));
    end

    [~, CorrectStaOrd] = sort(IndStaInDataSheet);
    CorrectStaOrd = [1; CorrectStaOrd+1]; % First 1 is because Sheet have the titles of the columns in first position, +1 is to take into account this first row

    % Stations ordered
    Sheet_Stations    = Sheet_StationsRaw(CorrectStaOrd, :);

    Stations          = string(Sheet_Stations(2:end,1));
    StationsNumber    = length(Stations);

    xLongSta          = [Sheet_Stations{2:end,8}]';
    yLatSta           = [Sheet_Stations{2:end,9}]';
    
    CoordinatesGauges = [xLongSta, yLatSta];
    Gauges            = {Stations, CoordinatesGauges};

    if not(isequal(Sheet_StationsRaw, Sheet_Stations))
        warning(['Station table sheet in excel was automatically reordered because ' ...
                 'did not match order in Data table sheet. Please analyze it and avoid automatic reordering!'])
    end

    %% Check for consistency in excel
    HeaderLine   = find(cellfun(@isdatetime, Sheet_DataRec), 1); % Automatically recognize excel file header line
    MissIn2ndCol = find(cellfun(@(x) all(ismissing(x)), Sheet_DataRec(:,2)));
    DiffInMiss   = diff(MissIn2ndCol);
    IndOfStarts  = find(DiffInMiss > 15); % We suppose to have at least 15 records and less than 15 rows blank
    RowsOfStarts = MissIn2ndCol(IndOfStarts) + 1; % + 1 because you have to start from the next row after the last blank
    RowsOfEnds   = MissIn2ndCol(IndOfStarts+1) - 1; % - 1 because you have to end in the previous row before the first blank
    if not(ismissing(Sheet_DataRec{end,2})) % If your last element is a datetime, then you have to add also the last station (not picked up automatically)
        RowsOfStarts(end+1) = MissIn2ndCol(end) + 1;
        RowsOfEnds(end+1)   = length(Sheet_DataRec(:,2));
    end
    
    RowsRecsPerSta = arrayfun(@(x,y) x:y, RowsOfStarts, RowsOfEnds, 'UniformOutput',false);

    RecDatesStartsPerSta = cellfun(@(x) Sheet_DataRec(x,1), RowsRecsPerSta, 'UniformOutput',false);
    RecDatesEndsPerSta   = cellfun(@(x) Sheet_DataRec(x,2), RowsRecsPerSta, 'UniformOutput',false);
    RecNumDataPerSta     = cellfun(@(x) Sheet_DataRec(x,3), RowsRecsPerSta, 'UniformOutput',false);

    IsDatetimeStarts = cellfun(@(x) cellfun(@isdatetime, x), RecDatesStartsPerSta, 'UniformOutput',false);
    IsDatetimeEnds   = cellfun(@(x) cellfun(@isdatetime, x), RecDatesEndsPerSta  , 'UniformOutput',false);
    IsDataNumeric    = cellfun(@(x) cellfun(@isnumeric, x) , RecNumDataPerSta    , 'UniformOutput',false);

    AreAllDatetimeStartsPerSta = cellfun(@all, IsDatetimeStarts);
    AreAllDatetimeEndsPerSta   = cellfun(@all, IsDatetimeEnds);
    AreAllDataNumericPerSta    = cellfun(@all, IsDataNumeric);

    DataIsConsistent = all([AreAllDatetimeStartsPerSta; AreAllDatetimeEndsPerSta; AreAllDataNumericPerSta]);

    if not(DataIsConsistent)
        if any(not(AreAllDatetimeStartsPerSta))
            ProblematicStations = find(not(AreAllDatetimeStartsPerSta));
            for i1 = ProblematicStations' % ATTENTION, this should be always horizontal!
                ProblematicRowsInExcel = RowsRecsPerSta{i1}(not(IsDatetimeStarts{i1}));
                warning(strcat("Station ", Stations(i1), " have a problem in column n. 1, rows: ", ...
                               strjoin(string(ProblematicRowsInExcel), ', ')))
            end
        elseif any(not(AreAllDatetimeEndsPerSta))
            ProblematicStations = find(not(AreAllDatetimeEndsPerSta));
            for i1 = ProblematicStations' % ATTENTION, this should be always horizontal!
                ProblematicRowsInExcel = RowsRecsPerSta{i1}(not(IsDatetimeEnds{i1}));
                warning(strcat("Station ", Stations(i1), " have a problem in column n. 2, rows: ", ...
                               strjoin(string(ProblematicRowsInExcel), ', ')))
            end
        elseif any(not(AreAllDataNumericPerSta))
            ProblematicStations = find(not(AreAllDataNumericPerSta));
            for i1 = ProblematicStations' % ATTENTION, this should be always horizontal!
                ProblematicRowsInExcel = RowsRecsPerSta{i1}(not(IsDataNumeric{i1}));
                warning(strcat("Station ", Stations(i1), " have a problem in column n. 2, rows: ", ...
                               strjoin(string(ProblematicRowsInExcel), ', ')))
            end
        end
    end

    for i1 = 1:length(RecNumDataPerSta) % To replace missing values
        if strcmp(DataRead,'Rainfall')
            RecNumDataPerSta{i1}(not(IsDataNumeric{i1})) = {0};

        elseif strcmp(DataRead,'Temperature') % REMEMBER TO IMPLLEMENT IT!
            error('Value replacing for temperature not yet implemented, please fill empty rows specified above manually!')
            % THIS IS TAKEN FROM MODEL A, ADAPT IT CONSIDERING THAT YOU
            % WILL NOT HAVE OTHER YEARS IN THIS CASE!
            % RowsEmpty = find(any(not(IsDataNumeric{i1}), 2));
            % for i2 = 1:length(RowsEmpty)
            %     DateEnd  = RecDatesEndsPerSta{i1}{RowsEmpty(i2)};
            %     DateMnth = month(DateEnd);
            %     DateDay  = day(DateEnd);
            % 
            %     MatchMnth = (DateMnth == month([RecDatesEndsPerSta{i1}{:}]))';
            %     MatchDay  = (DateDay  == day([RecDatesEndsPerSta{i1}{:}])  )';
            % 
            %     CellsToUse = repmat(MatchMnth & MatchDay, 1, 3) & IsDataNumeric{i1};
            % 
            %     RowToWrt  = RowsEmpty(i2);
            %     ColsToWrt = find(not(IsDataNumeric{i1}(RowsEmpty(i2),:)));
            % 
            %     AvgValues = zeros(size(ColsToWrt));
            %     for i3 = 1:length(AvgValues)
            %         AvgValues(i3) = mean([RecNumDataPerSta{i1}{CellsToUse(:,ColsToWrt(i3)), ColsToWrt(i3)}]);
            %     end
            %     RecNumDataPerSta{i1}(RowToWrt,ColsToWrt) = num2cell(AvgValues);
            % end

        else
            error('Type of recording not recognized while trying to replace missing values!')
        end
    end

    IsDataNumericNew = cellfun(@(x) cellfun(@isnumeric, x), RecNumDataPerSta, 'UniformOutput',false);

    AreAllDataNumericPerStaNew = cellfun(@all, IsDataNumericNew);
    
    DataIsConsistentNew = all([AreAllDatetimeStartsPerSta; AreAllDatetimeEndsPerSta; AreAllDataNumericPerStaNew]);
    
    if not(DataIsConsistent) && DataIsConsistentNew
        warning(['Stations with inconsistent numeric data were overwritten (0 value) ' ...
                 'in rows that did not contain numbers.'])
    elseif not(DataIsConsistentNew)
        error(['After trying to replace with 0 rows that did not contain numbers, something went wrong. ' ...
               'Maybe Dates in 1st and 2nd columns.'])
    end

    % Extraction of data in single cells and shifting of datetime
    RecDatesStartsPerSta = cellfun(@(x) [x{:}]', RecDatesStartsPerSta, 'UniformOutput',false);
    RecDatesEndsPerSta   = cellfun(@(x) [x{:}]', RecDatesEndsPerSta  , 'UniformOutput',false);
    RecNumDataPerSta     = cellfun(@cell2mat  , RecNumDataPerSta     , 'UniformOutput',false);

    %% Adjustment of dates
    dTRecsRaw = RecDatesStartsPerSta{1}(2)-RecDatesStartsPerSta{1}(1);
    if dTRecsRaw < minutes(59)
        ShiftApprox = 'minute';
    elseif dTRecsRaw < hours(23) && dTRecsRaw >= minutes(59)
        ShiftApprox = 'hour';
    elseif dTRecsRaw >= hours(23)
        ShiftApprox = 'day';
    else
        error('Time discretization of excel not recognized!')
    end

    RecDatesStartsPerStaShifted = cellfun(@(x) dateshift(x, 'start',ShiftApprox, 'nearest'), RecDatesStartsPerSta, 'UniformOutput',false);
    RecDatesEndsPerStaShifted   = cellfun(@(x) dateshift(x, 'start',ShiftApprox, 'nearest'), RecDatesEndsPerSta  , 'UniformOutput',false);

    StartDateCommon = max(cellfun(@min, RecDatesEndsPerStaShifted)); % Start in end dates
    EndDateCommon   = min(cellfun(@max, RecDatesEndsPerStaShifted)); % End in end dates

    IndIntersecated = cellfun(@(x) find(x == StartDateCommon) : find(x == EndDateCommon), RecDatesEndsPerStaShifted, 'UniformOutput',false);

    NumOfCommonRecs = unique(cellfun(@numel, IndIntersecated));

    if length(NumOfCommonRecs) > 1
        error('You have a different timing among stations, please check your excel!')
    end

    DataNotConsidered = cellfun(@(x) length(x) > NumOfCommonRecs, RecDatesEndsPerStaShifted);
    if any(DataNotConsidered)
        warning(strcat('Attention! Some stations (', strjoin(Stations(DataNotConsidered), ', '), ...
                       ') have more recs than others. Recs outside common dates will be excluded.'))
    end

    GeneralDatesStart = RecDatesStartsPerStaShifted{1}(IndIntersecated{1}); % Taking only the firs one
    GeneralDatesEnd   = RecDatesEndsPerStaShifted{1}(IndIntersecated{1}); % Taking only the firs one

    RecDatesEndCommon = GeneralDatesEnd;
    if strcmp(ShiftApprox, 'minute')
        RecDatesEndCommon.Format = 'dd/MM/yyyy HH:mm:ss';
    elseif strcmp(ShiftApprox, 'hour')
        RecDatesEndCommon.Format = 'dd/MM/yyyy HH:mm';
    elseif strcmp(ShiftApprox, 'day')
        RecDatesEndCommon.Format = 'dd/MM/yyyy';
    end

    %% Numeric data writing
    GeneralData = cell2mat(cellfun(@(x,y) x(y), RecNumDataPerSta', IndIntersecated', 'UniformOutput',false));
    
    GeneralData(isnan(GeneralData))  = 0;
    GeneralData(GeneralData == -999) = 0;
    GeneralData = GeneralData';

    VariablesRecorded = {'GeneralData', 'Gauges', 'RecDatesEndCommon'};
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
        %% SLIP process
        dTRecsShifted         = RecDatesEndCommon(2)-RecDatesEndCommon(1);
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
        
        drawnow % Remember to remove if in Standalone version
        figure(Fig) % Remember to remove if in Standalone version

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
ProgressBar.Message = strcat("Saving data...");

NameInterp  = [ShortName,'Interpolated.mat'];
NameGeneral = ['General',DataRead,'.mat'];
AnswerType  = {'AnswerTypeRec', 'AnswerTypeFor', 'InterpDuration'};

save([fold_var,sl,'UserTimeSens_Answers.mat'], VariablesFilenames{:},'AnalysisCase',AnswerType{:});
if exist([fold_var,sl,NameInterp], 'file')
    save([fold_var,sl,NameInterp], VariablesInterpol{:}, '-append');
else
    saveswitch([fold_var,sl,NameInterp], VariablesInterpol);
end
save([fold_var,sl,NameGeneral], VariablesRecorded{:});

close(ProgressBar) % Remember to replace ProgressBar with Fig if you are in standalone version