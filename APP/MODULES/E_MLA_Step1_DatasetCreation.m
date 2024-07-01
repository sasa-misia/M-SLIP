if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Cancelable','off', 'Message','Reading files...');
drawnow

%% Check for pre existing dataset
sl = filesep;

[AddToExistingDataset, OldSettings] = deal(false);
if exist([fold_var,sl,'DatasetMLA.mat'], 'file')
    Options = {'Yes, add this to the old one.', 'No, overwite it!'};
    MergeDataAns = uiconfirm(Fig, ['A pre-existing dataset for ML has been found. ' ...
                                   'Do you want to merge this new one with the old?'], ...
                                  'Merge datasets', 'Options',Options, 'DefaultOption',1);
    if strcmp(MergeDataAns, 'Yes, add this to the old one.')
        AddToExistingDataset = true;

        load([fold_var,sl,'DatasetMLA.mat'], 'DatasetInfo')
        DsetInfoOld = DatasetInfo;
        DatasetInfo = DatasetInfo(end);

        Options = {'Yes, please', 'No, use different settings'};
        OldSettingsAns = uiconfirm(Fig, 'Do you want to mantain settings of the old one?', ...
                                        'Dataset settings', 'Options',Options, 'DefaultOption',1);
        if strcmp(OldSettingsAns, 'Yes, please'); OldSettings = true; end
    end
end

%% Events definition & options
if AddToExistingDataset && OldSettings
    RainDataSource = DatasetInfo.FullFilePaths.RainSource;
    TempDataSource = DatasetInfo.FullFilePaths.TempSource;

    MinTrsh = DatasetInfo.EventsThresholds.MinimumRainfall;
    MinDays = DatasetInfo.EventsThresholds.MinimumTime;
    MinSpdT = DatasetInfo.EventsThresholds.MinimumSeparationTime;
    MaxDays = DatasetInfo.EventsThresholds.MaximumTime;

    SynthLands = DatasetInfo.Options.SynthetizedLandslides;
    if SynthLands
        MinCauseRain10dds = DatasetInfo.Options.SynthLandsMetrics.MinCauseRain10d;
        MinCauseRain20dds = DatasetInfo.Options.SynthLandsMetrics.MinCauseRain20d;
        MinTriggeringRain = DatasetInfo.Options.SynthLandsMetrics.MinTriggerRain;
        RngAvgCsTemp20dds = DatasetInfo.Options.SynthLandsMetrics.RngAvgCsTemp20d;
    end

    ApproximationDays = DatasetInfo.MatchEventsRules.DeltaTimeMatch;
    
    JustForward = DatasetInfo.MatchEventsRules.JustLookForward;

    SingleMatch = DatasetInfo.MatchEventsRules.SingleMatch;

    if SingleMatch
        SingleChoice = DatasetInfo.MatchEventsRules.SingleMatchType;
    end

    DaysForCause = DatasetInfo.Options.DaysForCauseQuantities;

    StartDateFilter = DatasetInfo.Options.StartDate;
    EndDateFilter   = DatasetInfo.Options.EndDate;

else
    TimeSensSource = listdlg2({'Type of rainfalls?', 'Type of temperature?'}, ...
                              { {'RainGauges', 'Satellite', 'Synthetized'}, ...
                                {'TempGauges', 'Satellite'} });
    RainDataSource = TimeSensSource{1};
    TempDataSource = TimeSensSource{2};

    SynthLands = false;
    if strcmp(RainDataSource,'Synthetized')
        SynthLndsAns = uiconfirm(Fig, 'Since you have synth rainfall, do you want to synthetize also landslides?', ...
                                      'Synthetized landslides', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
        if strcmp(SynthLndsAns,'Yes'); SynthLands = true; end
    end

    if SynthLands
        SynthInputs = inputdlg2({'Min Cause Rain 10 days:', 'Min Cause Rain 20 days:', ...
                                 'Min Triggering Rain:', 'Range Avg Cause Temp 20 days:'}, ...
                                 'DefInp',{'320', '400', '300', '[-17, 40]'}); % {'130', '180', '60', '[1, 10]'}

        MinCauseRain10dds = str2double(SynthInputs{1}); % mm
        MinCauseRain20dds = str2double(SynthInputs{2}); % mm
        MinTriggeringRain = str2double(SynthInputs{3}); % mm
        RngAvgCsTemp20dds = str2num(SynthInputs{4});    % celsius
    end

    InpMinValsEvent = inputdlg2({'Rain threshold [mm/day] for event:', ...
                                 'Min number of days for events [d]:', ...
                                 'Min num of days to separate events [d]:', ...
                                 'Max number of days for an event [d]:'}, ...
                                'DefInp',{'5', '1', '1', '10'});
    MinTrsh = str2double(InpMinValsEvent{1});
    MinDays = str2double(InpMinValsEvent{2});
    MinSpdT = str2double(InpMinValsEvent{3});
    MaxDays = str2double(InpMinValsEvent{4});
    
    ApproximationDays = str2double(inputdlg2('Extra days for rain-lands match?', 'DefInp',{'5'}));
    
    AnsForwardBackward = uiconfirm(Fig, 'Do you want to look only forward or also backwards?', ...
                                        'Loooking forward', 'Options',{'Forward', 'Forward&Backwards'}, 'DefaultOption',1);
    if strcmp(AnsForwardBackward,'Forward'); JustForward = true; else; JustForward = false; end
    
    AnsSingleMatch = uiconfirm(Fig, 'Do you want to have a single match landslides-rainfall events?', ...
                                    'Single match', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
    if strcmp(AnsSingleMatch,'Yes'); SingleMatch = true; else; SingleMatch = false; end
    
    if SingleMatch
        SingleChoice = uiconfirm(Fig, 'If there are multiple matches, how do you want to take single event then?', ...
                                      'Single match', 'Options',{'MaxAmount', 'LastEvent', 'Nearest'}, 'DefaultOption',1);
    end

    DaysForCause = days([10, 20, 30, 60]);

    StartDateFilter = datetime('01-jan-2001', 'InputFormat','dd-MMM-yyyy');
    EndDateFilter   = datetime('31-oct-2019', 'InputFormat','dd-MMM-yyyy');
end

%% Full filenames
ReqAverageProps = {'NDVI'};
FilenameAverage = deal([fold_var,sl,'AverageValues.mat']);
FilenameLndInfo = deal([fold_var,sl,'LandslidesInfo.mat']);

switch RainDataSource
    case 'RainGauges'
        if isempty({dir([fold_raw_rain,sl,'*.xlsx']).name})
            Ans = uiconfirm(Fig, ['No excel in ',fold_raw_rain], ...
                                 'No file in directory', 'Options','Search file');
            copyindirectory('xlsx', fold_raw_rain, 'mode','multiple')
        end
    
        FilesInDir = {dir([fold_raw_rain,sl,'*.xlsx']).name};
        FileRainRG = char(listdlg2({'File with rainfall:'}, FilesInDir));

        FilenameRainRec = [fold_raw_rain,sl,FileRainRG];

    case 'Satellite'
        FilenameRainRec = FilenameAverage;
        ReqAverageProps = [ReqAverageProps, {'Satellite Rain'}];

    case 'Synthetized'
        FilenameRainRec = [fold_var,sl,'SynthetizedRain.mat'];

    otherwise
        error('Rain data source not recognized!')
end

switch TempDataSource
    case 'TempGauges'
        if isempty({dir([fold_raw_temp,sl,'*.xlsx']).name})
            Ans = uiconfirm(Fig, ['No excel in ',fold_raw_temp], ...
                                 'No file in directory', 'Options','Search file');
            copyindirectory('xlsx', fold_raw_temp, 'mode','multiple')
        end
    
        FilesInDir = {dir([fold_raw_temp,sl,'*.xlsx']).name};
        FileTempRG = char(listdlg2({'File with temperature:'}, FilesInDir));

        FilenameTempRec = [fold_raw_temp,sl,FileTempRG];

    case 'Satellite'
        FilenameTempRec = FilenameAverage;
        ReqAverageProps = [ReqAverageProps, {'Satellite Avg Temperature', ...
                                             'Satellite Min Temperature', ...
                                             'Satellite Max Temperature'}];

    otherwise
        error('Temperature data source not recognized!')
end

%% Loading files
load(FilenameAverage, 'AverageValues')
PropsSelAverage = listdlg2(ReqAverageProps, AverageValues.Properties.VariableNames);

if not(SynthLands)
    if exist(FilenameLndInfo, 'file')
        load(FilenameLndInfo, 'GeneralLandslidesSummary','LandslidesCountPerMun')
    else
        error(['LandslidesInfo.mat not found in Variables ', ...
               'folder! Create it to have real landslides.'])
    end
end

switch RainDataSource
    case 'RainGauges'

    case 'Satellite'
        IndRain2T = contains(ReqAverageProps, 'Rain', 'IgnoreCase',true);
        if sum(IndRain2T) ~= 1; error('The column of rainfall must have just onme match!'); end
        RainTable = AverageValues{'Content', PropsSelAverage(IndRain2T)}{:};

    case 'Synthetized'
        if exist(FilenameRainRec, 'file')
            load(FilenameRainRec, 'SynthetizedRain')
        else
            error(['SynthetizedRain.mat not found in Variables ', ...
                   'folder! Create it to use Synthetized rainfall.'])
        end

        RainTable = SynthetizedRain;
        clear('SynthetizedRain')

    otherwise
        error('RainDataSource not recognized while extracting files!')
end

switch TempDataSource
    case 'TempGauges'

    case 'Satellite'
        IndTemp2T = contains(ReqAverageProps, 'Temperature', 'IgnoreCase',true);
        if sum(IndTemp2T) ~= 3; error('The columns of temperature must have 3 matches!'); end
        TempTable = AverageValues{'Content', PropsSelAverage(IndTemp2T)}; % IT MUST BE A 1x3 CELL!!

    otherwise
        error('RainDataSource not recognized while extracting files!')
end

%% Dataset Options
if AddToExistingDataset && OldSettings
    TstMode = DatasetInfo.Options.TestMode;
    switch TstMode
        case 'AfterYear'
            LimYear = DatasetInfo.Options.StartTestYear;

        case 'RandomSplit'
            TstPerc = DatasetInfo.Options.TestPercentage;

        otherwise
            error('Test mode not recognized!')
    end

    OutMode = DatasetInfo.Options.OutputType;
    MltClss = false;
    RegrANN = false;
    switch OutMode
        case '4 risk classes'
            MltClss = true;
            ClssThr = arrayfun(@(x) num2str(x), DatasetInfo.Options.ThresholdsMC, 'UniformOutput',false);
    
        case 'L-NL classes'
            MinLandsClassL = DatasetInfo.Options.MinLandsNumClassL;
    
        case 'Regression'
            RegrANN = true;
    
        otherwise
            error('OutMode choice not recognized!')
    end

    ResDset = DatasetInfo.Options.Resampling;
    if ResDset
        Rat2Imp = DatasetInfo.Options.ResamplingRatio;
        ResMode = DatasetInfo.Options.ResamplingMode;
    end

    SlFeats = DatasetInfo.Options.SelectFeatures;

    RndOuts = DatasetInfo.Options.RandomOuts;
    if RndOuts
        RandType = DatasetInfo.Options.RandomType;
        RndLevel = DatasetInfo.Options.RandomLevel;
    end

    CrssVal = DatasetInfo.Options.CrossDatasets;
    if CrssVal
        kFoldNum = DatasetInfo.Options.kFoldNumber;
    end

    NormVal = DatasetInfo.Options.ValidDatasets;
    if NormVal
        NrValPerc = DatasetInfo.Options.ValidPercentage;
    end

else
    NetModeAns = listdlg2({'Type of outputs?', 'Type of test dataset?'}, ...
                          { {'L-NL classes', '4 risk classes', 'Regression'}, ...
                            {'RandomSplit', 'AfterYear'} });

    OutMode = NetModeAns{1};
    TstMode = NetModeAns{2};

    DatasetAns = checkbox2({'Cross validation (CV)', 'Normal validation (NV)', ...
                            'Selection of features', 'Random outputs', ...
                            'Resampling (except regression)'}, 'OutType','LogInd', 'DefInp',[1, 1, 0, 0, 1]);

    CrssVal = DatasetAns(1);
    NormVal = DatasetAns(2);
    SlFeats = DatasetAns(3);
    RndOuts = DatasetAns(4);
    ResDset = DatasetAns(5);
    
    switch TstMode
        case 'AfterYear'
            LimYear = str2double(inputdlg2('Year above which mantain for test (included):', 'DefInp',{'2015'}));

        case 'RandomSplit'
            TstPerc = str2double(inputdlg2('Percentage of test part:', 'DefInp',{'0.3'}));

        otherwise
            error('Test mode not recognized!')
    end

    if CrssVal
        kFoldNum  = round(str2double(inputdlg2('Number of k-folds (CV):', 'DefInp',{'10'})));
        if kFoldNum <= 1
            error('The number of k-folds must be integer and > 1!')
        end
    end

    if NormVal
        NrValPerc = str2double(inputdlg2('Percentage of valid dataset (NV):', 'DefInp',{'0.2'}));
        if NrValPerc >= .5 || NrValPerc <= 0
            error('The percentage must be in a range from 0 to 0.5, both not included!')
        end
    end
    
    MltClss = false;
    RegrANN = false;
    switch OutMode
        case '4 risk classes'
            MltClss = true;
            ClssThr = inputdlg2({'Max lands num for low risk class:', ...
                                 'Max lands num for medium risk class:'}, ...
                                'DefInp',{'4', '15'});
    
        case 'L-NL classes'
            MinLandsClassL = str2double(inputdlg2('Min number of lands for landslide class?', 'DefInp',{'1'}));
    
        case 'Regression'
            RegrANN = true;
            ResDset = false;
    
        otherwise
            error('OutMode choice not recognized!')
    end

    if ResDset
        RatInps = str2double(inputdlg2({'Part of unstable (resampling):', ...
                                        'Part of stable (resampling):'}, 'DefInp',{'1', '1'}));
        Rat2Imp = RatInps(1) / RatInps(2);
        ResMode = listdlg2({'Resampling approach?'}, {'Undersampling', 'Oversampling', 'SMOTE'});
    end

    if RndOuts
        RandType = listdlg2({'What type of random outputs?'}, {'Chaos','Switch'});
        switch RandType
            case 'Chaos'
                RndLevel = str2double(listdlg2({'Random chaos level:'}, string(1:6)))/10;

            case 'Switch'
                RndLevel = str2double(listdlg2({'Random switch amount [%]:'}, string(25:25:100)))/100;

            otherwise
                error('Random output type not recognized!')
        end
    end
end

%% Creating DatasetInfo
DatasetInfo = struct();
DatasetInfo.FullFilePaths = struct('Rainfall',FilenameRainRec, ...
                                   'RainSource',RainDataSource, ...
                                   'Temperature',FilenameTempRec, ...
                                   'TempSource',TempDataSource, ...
                                   'GeneralLandslideSummary',FilenameLndInfo, ...
                                   'LandslidesPerMunicipality',FilenameLndInfo, ...
                                   'AverageNDVI',FilenameAverage);

DatasetInfo.MatchEventsRules = struct('DeltaTimeMatch',ApproximationDays, ...
                                      'JustLookForward',JustForward, ...
                                      'SingleMatch',SingleMatch);

DatasetInfo.EventsThresholds = struct('MinimumRainfall',MinTrsh, ...
                                      'MinimumTime',MinDays, ...
                                      'MaximumTime',MaxDays, ...
                                      'MinimumSeparationTime',MinSpdT);

DatasetInfo.Options = struct('TestMode',TstMode, ...
                             'DaysForCauseQuantities',DaysForCause, ...
                             'StartDate',StartDateFilter, ...
                             'EndDate',EndDateFilter, ...
                             'OutputType',OutMode, ...
                             'Resampling',ResDset, ...
                             'CrossDatasets',CrssVal, ...
                             'ValidDatasets',NormVal, ...
                             'SelectFeatures',SlFeats, ...
                             'SynthetizedLandslides',SynthLands, ...
                             'RandomOuts',RndOuts);

% Optional part
if SingleMatch
    DatasetInfo.MatchEventsRules.SingleMatchType = SingleChoice;
end

switch TstMode
    case 'AfterYear'
        DatasetInfo.Options.StartTestYear = LimYear;

    case 'RandomSplit'
        DatasetInfo.Options.TestPercentage = TstPerc;

    otherwise
        error('TestMode to insert in ModelInfo not recognized!')
end

if SynthLands
    DatasetInfo.FullFilePaths.GeneralLandslideSummary   = 'Synthetized!';
    DatasetInfo.FullFilePaths.LandslidesPerMunicipality = 'Synthetized!';

    DatasetInfo.Options.SynthLandsMetrics = struct('MinCauseRain10d',MinCauseRain10dds, ...
                                                   'MinCauseRain20d',MinCauseRain20dds, ...
                                                   'MinTriggerRain',MinTriggeringRain, ...
                                                   'RngAvgCsTemp20d',RngAvgCsTemp20dds);
end

if ResDset
    DatasetInfo.Options.ResamplingRatio = Rat2Imp;
    DatasetInfo.Options.ResamplingMode  = ResMode;
end

if CrssVal
    DatasetInfo.Options.kFoldNumber = kFoldNum;
end

if NormVal
    DatasetInfo.Options.ValidPercentage = NrValPerc;
end

if RndOuts
    DatasetInfo.Options.RandomType  = RandType;
    DatasetInfo.Options.RandomLevel = RndLevel;
end

% Metrics for datasets according to OutMode
switch OutMode
    case '4 risk classes'
        DatasetInfo.Options.ThresholdsMC = cellfun(@str2num, ClssThr);

    case 'L-NL classes'
        DatasetInfo.Options.MinLandsNumClassL = MinLandsClassL;

    case 'Regression'

    otherwise
        error('OutMode choice not recognized while writing ModelInfo!')
end

%% Rainfall processing
DltaTimeRain = hours(24); % In hours!!!
AggrModeRain = {'sum'};

switch RainDataSource
    case 'RainGauges'
        FileSheets = sheetnames(FilenameRainRec);
        Sheets2Use = listdlg2({'Data table:', 'Stations table:'}, FileSheets);
        ReadOption = listdlg2({'Auto fill (missing data):', 'Filter to stations:'}, ...
                              { {'OtherSta','Zeros','AverageYr','AverageLNE','NaN'}, ...
                                {'Yes','No'} });
        AutFllMode = ReadOption{1};
        if strcmp(ReadOption{2}, 'Yes'); StatFilt = true; else; StatFilt = false; end
    
        [RecRainDatesStartsPerSta, ...
            RecRainDatesEndsPerSta, RecRainNumDataPerSta, ...
                RainGauges] = readtimesenscell(FilenameRainRec, 'AutoFill',AutFllMode, ...
                                                                'StatsFilt',StatFilt, ...
                                                                'DataSheet',Sheets2Use{1}, ...
                                                                'StationSheet',Sheets2Use{2});

        if size(RecRainNumDataPerSta{1}, 2) ~= 1
            error('The columns of rainfall must be just one!')
        end

        StationsRain = RainGauges{1};

        [GnrlDatesStr, GnrlDatesEnd, ...
                GnrlRainProp] = adjustrecords(RecRainDatesStartsPerSta, ...
                                              RecRainDatesEndsPerSta, ...
                                              RecRainNumDataPerSta, 'DeltaTime',DltaTimeRain, ...
                                                                    'AggrMode',AggrModeRain, ...
                                                                    'ReplaceVal',[nan, 0; -999, 0]);
    
        %%%% Update ModelInfo %%%%
        DatasetInfo.Gauges.Rain = RainGauges;

    case {'Satellite', 'Synthetized'}
        GnrlDatesStr = RainTable.StartDate;
        GnrlDatesEnd = RainTable.EndDate;
    
        CheckLength = isequal(length(min(GnrlDatesStr):days(1):max(GnrlDatesStr)), length(GnrlDatesStr));
        if not(CheckLength)
            error('There is a problem of inconsistency in your recording (some datetimes are missed)!')
        end
    
        StationsRainFilter = uiconfirm(Fig, 'Do you want to select rainfall area?', ...
                                            'Filter Station', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
        if strcmp(StationsRainFilter, 'Yes')
            ColsNmsRain = RainTable.Properties.VariableNames;
            Ind2RemRain = strcmpi(ColsNmsRain, 'StartDate') | strcmpi(ColsNmsRain, 'EndDate');
            RainAreaSel = checkbox2(ColsNmsRain(not(Ind2RemRain)), 'Title',{'Select area:'});
        else
            RainAreaSel = {'StudyArea'};
        end

        if numel(RainAreaSel) < 1
            error('At least one column must be selected!')
        end
    
        StationsRain = RainAreaSel';

        [GnrlDatesStr, GnrlDatesEnd, ...
            GnrlRainProp] = newdeltarecords(GnrlDatesStr, GnrlDatesEnd, ...
                                                {RainTable{:,RainAreaSel}}, DltaTimeRain, 'AggrMode',AggrModeRain);
    
        %%%% Update ModelInfo %%%%
        DatasetInfo.SatelliteArea.Rain = RainAreaSel;

    otherwise
        error('Rainfall data source type not recognized!')
end

%% Temperature Processing
DltaTimeTemp = DltaTimeRain; % In hours!!!
AggrModeTemp = {'avg', 'min', 'max'};

switch TempDataSource
    case 'TempGauges'
        FileSheets = sheetnames(FilenameTempRec);
        Sheets2Use = listdlg2({'Data table:', 'Stations table:'}, FileSheets);
        ReadOption = listdlg2({'Auto fill (missing data):', 'Filter to stations:'}, ...
                              { {'OtherSta','Zeros','AverageYr','AverageLNE','NaN'}, ...
                                {'Yes','No'} });
        AutFllMode = ReadOption{1};
        if strcmp(ReadOption{2}, 'Yes'); StatFilt = true; else; StatFilt = false; end
    
        [RecTempDatesStartsPerSta, ...
            RecTempDatesEndsPerSta, RecTempNumDataPerSta, ...
                TempGauges] = readtimesenscell(FilenameTempRec, 'AutoFill',AutFllMode, ...
                                                                'StatsFilt',StatFilt, ...
                                                                'DataSheet',Sheets2Use{1}, ...
                                                                'StationSheet',Sheets2Use{2});

        if size(RecTempNumDataPerSta{1}, 2) ~= 3
            error('The columns of temperature must be 3 (average, min, max)!')
        end

        [GeneralDtTempStart, GeneralDtTempEnd, ...
                GeneralTempProp] = adjustrecords(RecTempDatesStartsPerSta, ...
                                                 RecTempDatesEndsPerSta, ...
                                                 RecTempNumDataPerSta, 'DeltaTime',DltaTimeTemp, ...
                                                                       'AggrMode',AggrModeTemp, ...
                                                                       'ReplaceVal',[nan, 0; -999, 0], ...
                                                                       'StartDate',GnrlDatesStr(1), ...
                                                                       'EndDate',GnrlDatesEnd(end));
    
        %%%% Update ModelInfo %%%%
        DatasetInfo.Gauges.Temperature = TempGauges;

    case 'Satellite'
        StatsTempFilter = uiconfirm(Fig, 'Do you want to select temperature area?', ...
                                         'Filter Station', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
        if strcmp(StatsTempFilter, 'Yes')
            ColsNmsTemp = TempTable{1}.Properties.VariableNames;
            Ind2RemTemp = strcmpi(ColsNmsTemp, 'StartDate') | strcmpi(ColsNmsTemp, 'EndDate');
            TempAreaSel = checkbox2(ColsNmsTemp(not(Ind2RemTemp)), 'Title',{'Select area:'});
        else
            TempAreaSel = {'StudyArea'}; % The average column must be call StudyArea!
        end

        if numel(TempAreaSel) < 1
            error('At least one column must be selected!')
        end

        [GenTmpStrDates, GenTmpEndDates, GenTmpPropData] = deal(cell(1, numel(TempTable)));
        for i1 = 1:numel(TempTable)
            GenTmpStrDates{i1} = TempTable{i1}.StartDate;
            GenTmpEndDates{i1} = TempTable{i1}.EndDate;
            GenTmpPropData{i1} = TempTable{i1}{:, TempAreaSel};
        end

        CommStrDate = max(cellfun(@min, GenTmpStrDates));
        CommEndDate = min(cellfun(@max, GenTmpStrDates));
        IndsUseDate = cellfun(@(x) find(CommStrDate == x) : find(CommEndDate == x), GenTmpStrDates, 'UniformOutput',false);

        if not(isscalar(unique(cellfun(@numel, IndsUseDate))))
            error('Dates between properties do not match! Please check AverageValues variable.')
        end

        GenTmpStrDates = GenTmpStrDates{1}(IndsUseDate{1});
        GenTmpEndDates = GenTmpEndDates{1}(IndsUseDate{1});
        GenTmpPropData = cellfun(@(x,y) x(y,:), GenTmpPropData, IndsUseDate, 'UniformOutput',false);

        [GeneralDtTempStart, GeneralDtTempEnd, ...
            GeneralTempProp] = newdeltarecords(GenTmpStrDates, GenTmpEndDates, ...
                                               GenTmpPropData, DltaTimeTemp, 'AggrMode',AggrModeTemp, ...
                                                                             'StartDate',GnrlDatesStr(1), ...
                                                                             'EndDate',GnrlDatesEnd(end));

        StationsTemp = TempAreaSel';
    
        %%%% Update ModelInfo %%%%
        DatasetInfo.SatelliteArea.Rain = TempAreaSel;

    otherwise
        error('Temperature data source type not recognized!')
end

%% Rainfall and temperature match
EqlDtes = isequal(GeneralDtTempStart, GnrlDatesStr) && ...
          isequal(GeneralDtTempEnd, GnrlDatesEnd);
if not(EqlDtes)
    warning(['After adjustment, dates of temperature are less ', ...
             'than rainfall! Records will be further reduced!'])
    Recs2Mant = ismember(GnrlDatesStr, GeneralDtTempStart);
    GnrlDatesStr = GnrlDatesStr(Recs2Mant);
    GnrlDatesEnd = GnrlDatesEnd(Recs2Mant);
    GnrlRainProp = cellfun(@(x) x(Recs2Mant,:), GnrlRainProp, 'UniformOutput',false);
end

%% General data
if numel(GnrlRainProp) ~= 1
    error('Something went wrong during the adjusment of records!')
else
    GeneralRainData = GnrlRainProp{1}'; % GeneralRainProp must be 1x1 cell!
end

if numel(GeneralTempProp) ~= 3
    error('Something went wrong during the adjusment of temperature records!')
else
    GeneralAvgTempData = GeneralTempProp{1}'; % 1st element must be average!
    GeneralMinTempData = GeneralTempProp{2}'; % 2nd element must be minimum!
    GeneralMaxTempData = GeneralTempProp{3}'; % 3rd element must be maximum!
end

%% Elaboration of data and selection of dates for rainfall events
RecDatesEndCommon = GnrlDatesEnd;
[IndsRecs4Ev, RecDates4Ev, Duration4Ev, ...
    IndsCseRecs4Ev] = rainevents(GeneralRainData, ...
                                 RecDatesEndCommon, 'MinThreshold',MinTrsh, ...
                                                    'MinDays',MinDays, ...
                                                    'MaxDays',MaxDays, ...
                                                    'MinSeparation',MinSpdT, ...
                                                    'CauseDays',DaysForCause);

StrDates4Ev = cellfun(@min, RecDates4Ev);
EndDates4Ev = cellfun(@max, RecDates4Ev); % This is not actually the end but the start day of the end (if it is equal to StrDates4Ev it means that the duration is just 24h)

%% Computation of cause quantities
% Rainfall
CauseRain4EvSta = cellfun(@(x) sum(GeneralRainData(:, x), 2), IndsCseRecs4Ev, 'UniformOutput',false);

CauseRain4Ev = cellfun(@max, CauseRain4EvSta');

ClNmsCauseRain = strcat('CauseRain',cellstr(string(days(DaysForCause))),'d');
CauseRainTable = array2table(CauseRain4Ev, 'VariableNames',ClNmsCauseRain);

% Temperature
CauseTempAvg4EvSta = cellfun(@(x) mean(GeneralAvgTempData(:, x), 2), IndsCseRecs4Ev, 'UniformOutput',false);
CauseTempMin4EvSta = cellfun(@(x) min(GeneralMinTempData(:, x), [], 2), IndsCseRecs4Ev, 'UniformOutput',false);
CauseTempMax4EvSta = cellfun(@(x) max(GeneralMaxTempData(:, x), [], 2), IndsCseRecs4Ev, 'UniformOutput',false);

CauseTempAvg4Ev = cellfun(@mean, CauseTempAvg4EvSta');
CauseTempMin4Ev = cellfun(@min, CauseTempMin4EvSta');
CauseTempMax4Ev = cellfun(@min, CauseTempMax4EvSta');

ClNmsCauseAvgTemp = strcat('AvgCsTmp',cellstr(string(days(DaysForCause))),'d');
ClNmsCauseMinTemp = strcat('MinCsTmp',cellstr(string(days(DaysForCause))),'d');
ClNmsCauseMaxTemp = strcat('MaxCsTmp',cellstr(string(days(DaysForCause))),'d');

CauseAvgTempTable = array2table(CauseTempAvg4Ev, 'VariableNames',ClNmsCauseAvgTemp);
CauseMinTempTable = array2table(CauseTempMin4Ev, 'VariableNames',ClNmsCauseMinTemp);
CauseMaxTempTable = array2table(CauseTempMax4Ev, 'VariableNames',ClNmsCauseMaxTemp);

%% Computation of trigger quantities
% Rainfall
TrigRain4EvSta = cellfun(@(x) sum(GeneralRainData(:, x), 2),     IndsRecs4Ev, 'UniformOutput',false);
PkTrRain4EvSta = cellfun(@(x) max(GeneralRainData(:, x), [], 2), IndsRecs4Ev, 'UniformOutput',false);

TrigRain4Ev = cellfun(@max, TrigRain4EvSta);
PkTrRain4Ev = cellfun(@max, PkTrRain4EvSta);

StaTrigRain = cellfun(@(x, y) StationsRain(find(x==y, 1)), TrigRain4EvSta, num2cell(TrigRain4Ev));
StaPkTrRain = cellfun(@(x, y) StationsRain(find(x==y, 1)), PkTrRain4EvSta, num2cell(PkTrRain4Ev));

% Temperature
TrigAvgTemp4EvSta = cellfun(@(x) mean(GeneralAvgTempData(:, x), 2),    IndsRecs4Ev, 'UniformOutput',false);
TrigMinTemp4EvSta = cellfun(@(x) min(GeneralMinTempData(:, x), [], 2), IndsRecs4Ev, 'UniformOutput',false);
TrigMaxTemp4EvSta = cellfun(@(x) max(GeneralMaxTempData(:, x), [], 2), IndsRecs4Ev, 'UniformOutput',false);

TrigAvgTemp4Ev = cellfun(@mean, TrigAvgTemp4EvSta);
TrigMinTemp4Ev = cellfun(@min , TrigMinTemp4EvSta);
TrigMaxTemp4Ev = cellfun(@max , TrigMaxTemp4EvSta);

%% Filtering of GeneralLandslidesSummary
if not(SynthLands)
    GeneralLandsSummAllMuns = GeneralLandslidesSummary;

else
    IndSynthEvs = find(( (CauseRainTable{:,1} >= MinCauseRain10dds) | ...
                         (CauseRainTable{:,2} >= MinCauseRain20dds) | ...
                         (TrigRain4Ev >= MinTriggeringRain)' ) & ...
                       ( CauseAvgTempTable{:,2} >= RngAvgCsTemp20dds(1) & ...
                         CauseAvgTempTable{:,2} <= RngAvgCsTemp20dds(2) ));

    SntLndDates = NaT(size(IndSynthEvs));
    for i1 = 1:numel(SntLndDates)
        PossibleDates = RecDates4Ev{IndSynthEvs(i1)};
        IndForRainfls = ismember(RecDatesEndCommon, PossibleDates, 'rows');
        
        [~, RelIndDay] = max( max(GeneralRainData(:,IndForRainfls), [], 1) );

        SntLndDates(i1) = PossibleDates(RelIndDay)-days(1); % -days(1) because otherwise it would be the end date!
    end

    LandsMuns = cellstr(repmat("Synthetized", size(IndSynthEvs)));
    LandsNums = ones(size(IndSynthEvs));

    GeneralLandslidesSummary = table(SntLndDates, LandsNums, LandsMuns, ...
                                                        'VariableNames',{'Datetime', ...
                                                                         'NumOfLandsllides', ...
                                                                         'Municipalities'});
    GeneralLandsSummAllMuns  = GeneralLandslidesSummary;
    LandslidesCountPerMun    = GeneralLandslidesSummary(:,{'Datetime', 'NumOfLandsllides'});
    LandslidesCountPerMun.Properties.VariableNames = {'Datetime', 'Synthetized'};
end

%% Filtering of GeneralLandslidesSummary
RngDates = [min(StrDates4Ev), max(StrDates4Ev)];
Rows2Dlt = ( GeneralLandslidesSummary.Datetime < (RngDates(1)-days(5)) ) | ( GeneralLandslidesSummary.Datetime > (RngDates(2)+days(5)) );
GeneralLandslidesSummary(Rows2Dlt, :) = [];
GeneralLandsSummAllMuns(Rows2Dlt, :)  = [];
LandslidesCountPerMun(Rows2Dlt, :)    = [];

MunsFilter = uiconfirm(Fig, 'Do you want to filter municipalities in General landslide data?', ...
                            'Filter Municiplities', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
if strcmp(MunsFilter, 'Yes') % Remember to modify also column of Municipalities!
    MunsInGen = unique(cellstr(cat(1, GeneralLandslidesSummary.Municipalities{:})));
    IndsMuns  = checkbox2(MunsInGen, 'Title',{'Municipalities to use:'}, 'OutType','NumInd');
    MunsSlctd = MunsInGen(IndsMuns);

    NewLandsNum = sum(LandslidesCountPerMun{:,MunsSlctd}, 2);
    GeneralLandslidesSummary.NumOfLandsllides = NewLandsNum; % To overwrite number of landslides contained only in your municipalities!

    RowsWithMunsSel = cellfun(@(x) any(ismember(MunsSlctd, x)), GeneralLandslidesSummary.Municipalities);
    GeneralLandslidesSummary(not(RowsWithMunsSel), :) = [];
    GeneralLandsSummAllMuns(not(RowsWithMunsSel), :)  = [];
    LandslidesCountPerMun(not(RowsWithMunsSel), :)    = [];
end

% Update of DatasetInfo
DatasetInfo.LandslidesMunicipalities = MunsSlctd;

%% Creation of arrays for table of GeneralEventsRainfall
[Landslides4Ev, LandsTotIO4Ev] = deal(zeros(size(StrDates4Ev)));
[Municipals4Ev, DateInGenLnds] = deal(cell(size(StrDates4Ev)));
if SingleMatch
    for i1 = 1:size(GeneralLandslidesSummary,1)
        if JustForward
            IndsEvsREGenLnds = (GeneralLandslidesSummary.Datetime(i1) >= StrDates4Ev) & ...
                               (GeneralLandslidesSummary.Datetime(i1) <= EndDates4Ev+days(ApproximationDays));
        else
            IndsEvsREGenLnds = (GeneralLandslidesSummary.Datetime(i1) >= StrDates4Ev-days(ApproximationDays)) & ...
                               (GeneralLandslidesSummary.Datetime(i1) <= EndDates4Ev+days(ApproximationDays));
        end
        if sum(IndsEvsREGenLnds) >= 1
            IndNumEvent = find(IndsEvsREGenLnds);
            if numel(IndNumEvent) > 1
                switch SingleChoice
                    case 'MaxAmount'
                        MaxAmountTemp     = TrigRain4Ev(IndsEvsREGenLnds);
                        [~, RelIndToTake] = max(MaxAmountTemp);
                        IndNumEvent       = IndNumEvent(RelIndToTake);

                    case 'LastEvent'
                        IndNumEvent = IndNumEvent(end);

                    case 'Nearest'
                        DiffTimeTemp = min(abs([StrDates4Ev(IndsEvsREGenLnds); ...
                                                EndDates4Ev(IndsEvsREGenLnds)]' - ...
                                                       GeneralLandslidesSummary.Datetime(i1)), [], 2);
                        [~, RelIndToTake] = min(DiffTimeTemp);
                        IndNumEvent       = IndNumEvent(RelIndToTake);

                    otherwise
                        error('SingleChoice not recognized')
                end
            end
            Landslides4Ev(IndNumEvent) = sum([Landslides4Ev(IndNumEvent), GeneralLandslidesSummary.NumOfLandsllides(i1)]);
            LandsTotIO4Ev(IndNumEvent) = sum([LandsTotIO4Ev(IndNumEvent), GeneralLandsSummAllMuns.NumOfLandsllides(i1)]);
            MunicipalsTmp              = [Municipals4Ev(IndNumEvent); GeneralLandslidesSummary.Municipalities(i1)];
            Municipals4Ev{IndNumEvent} = cat(1, MunicipalsTmp{:});
            DateInGenLnds{IndNumEvent} = [DateInGenLnds{IndNumEvent}; GeneralLandslidesSummary.Datetime(i1)];
        end
    end

else
    for i1 = 1:length(StrDates4Ev)
        if JustForward
            IndsInEv = (GeneralLandslidesSummary.Datetime >= min(RecDates4Ev{i1})) & ...
                       (GeneralLandslidesSummary.Datetime <= max(RecDates4Ev{i1})+days(ApproximationDays));
        else
            IndsInEv = (GeneralLandslidesSummary.Datetime >= min(RecDates4Ev{i1})-days(ApproximationDays)) & ...
                       (GeneralLandslidesSummary.Datetime <= max(RecDates4Ev{i1})+days(ApproximationDays));
        end
        if any(IndsInEv)
            Landslides4Ev(i1) = sum(GeneralLandslidesSummary.NumOfLandsllides(IndsInEv));
            LandsTotIO4Ev(i1) = sum(GeneralLandsSummAllMuns.NumOfLandsllides(IndsInEv));
            MunicipalsTmp     = GeneralLandslidesSummary.Municipalities(IndsInEv);
            Municipals4Ev{i1} = cat(1, MunicipalsTmp{:});
            DateInGenLnds{i1} = GeneralLandslidesSummary.Datetime(IndsInEv);
        end
    end
end

TotLandsNum  = sum(GeneralLandslidesSummary.NumOfLandsllides);
TotLandsAttr = sum(Landslides4Ev);

if TotLandsAttr < TotLandsNum
    warning('Not all landslides matched a rainfall event')
elseif TotLandsAttr > TotLandsNum
    warning('Some landslides matched multiple rainfall events')
end

%% NDVI association
IndNDVI2T = contains(ReqAverageProps, 'NDVI', 'IgnoreCase',true);
if sum(IndNDVI2T) ~= 1; error('The column of NDVI must have just one match!'); end
NDVITable = AverageValues{'Content', PropsSelAverage(IndNDVI2T)}{:};

ColsNmsNDVI = NDVITable.Properties.VariableNames;
Ind2RemNDVI = strcmpi(ColsNmsNDVI, 'StartDate') | strcmpi(ColsNmsNDVI, 'EndDate');
NDVIAreaSel = checkbox2(ColsNmsNDVI(not(Ind2RemNDVI)), 'Title',{'Select area (multiple choice will be averaged):'});

NDVI4Ev = nan(size(StrDates4Ev));
for i1 = 1:length(StrDates4Ev)
    IndMatchNDVI = (StrDates4Ev(i1) >= NDVITable.StartDate) & (StrDates4Ev(i1) <= NDVITable.EndDate);
    if sum(IndMatchNDVI) == 0
        warning(['Event n. ',num2str(i1),' has no math with Average NDVI!'])
    elseif sum(IndMatchNDVI > 1)
        error(['Event n. ',num2str(i1),' has more than 1 mathes with Average NDVI!'])
    else
        NDVI4Ev(i1) = mean(NDVITable{IndMatchNDVI, NDVIAreaSel}, 2);
    end
end

%% Durations from last event
Time2LstRE = [NaN, StrDates4Ev(2:end) - EndDates4Ev(1:end-1)];

IndFrstLnd = find(Landslides4Ev,1);
Time2LstLE = NaT(size(StrDates4Ev)) - NaT(size(StrDates4Ev));
TimeDurPrg = hours(0);
for i1 = IndFrstLnd+1 : length(StrDates4Ev)
    TimeDurPrg     = TimeDurPrg + (StrDates4Ev(i1) - EndDates4Ev(i1-1));
    Time2LstLE(i1) = TimeDurPrg;
    if Landslides4Ev(i1) >= 1
        TimeDurPrg = hours(0);
    end
end

%% Writing of table and file
GnREVrNms = {'Start', 'End', 'DurRE', 'Time2LstRE', 'Time2LstLE', 'AvgNDVI', ...
             'LandsDates', 'LandsNum', 'LandsNumIO', 'Municipalities', ...
             'TrigRain', 'PkTrgRain', 'AvgTrgTmp', 'MinTrgTmp', 'MaxTrgTmp'};
GeneralRE = table(StrDates4Ev', EndDates4Ev', hours(Duration4Ev'), ...
                  hours(Time2LstRE'), hours(Time2LstLE'), NDVI4Ev', ...
                  DateInGenLnds', Landslides4Ev', LandsTotIO4Ev', ...
                  Municipals4Ev', TrigRain4Ev', PkTrRain4Ev', ...
                  TrigAvgTemp4Ev', TrigMinTemp4Ev', TrigMaxTemp4Ev', 'VariableNames',GnREVrNms);

GeneralRE = [GeneralRE, CauseRainTable, CauseAvgTempTable, CauseMinTempTable, CauseMaxTempTable];

GeneralRE = sortrows(GeneralRE, 'Start','ascend');

% Filtering
IndsOutDates = (GeneralRE.Start < StartDateFilter) | (GeneralRE.Start > EndDateFilter);
GeneralRE(IndsOutDates,:) = [];

if any(isnan(GeneralRE.AvgNDVI))
    warning('After filtering, some events still not have match with average NDVI!')
end

save([fold_var,sl,'GenInfoRainfallEvents.mat'], 'GeneralRE')

%% Neural Network Dataset
PossFeats = GeneralRE.Properties.VariableNames;
PtFtsInds = contains(PossFeats, {'Rain','Tmp','Temp','Dur','Time','NDVI'}, 'IgnoreCase',true); % Please update it in case of changes in feats names!
DatesInds = {'Start', 'End', 'LandsNum'};

if not(all(ismember(DatesInds, PossFeats)))
    error('Indices of Start, End, amd LandsNum not found in GeneralRE')
end

Feats2Mnt = PossFeats(PtFtsInds);
if AddToExistingDataset
    Feats2Mnt = DsetInfoOld(end).Datasets.Feats; % Overwriting in case of add to old datasets
elseif not(AddToExistingDataset) && SlFeats
    Feats2Mnt = checkbox2(PossFeats, 'Title',{'Features to mantain:'}, 'DefInp',PtFtsInds); % Overwriting in case of new dataset where you want to select features
end

DatasetEvsDates = GeneralRE(:, DatesInds);
DatasetEvsFeats = GeneralRE(:, Feats2Mnt);

% Random feature
DatasetEvsFeats.RandFeat = rand(size(DatasetEvsFeats, 1), 1);

DatasetFeatsNms = DatasetEvsFeats.Properties.VariableNames; % REMEMBER: It must be after DatasetEvsFeats.RandFeat = ..., otherwise it will miss the RandFeat!

switch OutMode
    case 'L-NL classes'
        IndClss = [(GeneralRE.(DatesInds{3}) == 0), (GeneralRE.(DatesInds{3}) >= MinLandsClassL)]; % Attention! DatesInds{3} must be the column where the number of landslides is stored!
        Ind2Mnt = any(IndClss, 2);

        DatasetEvsDates(not(Ind2Mnt),:) = [];
        DatasetEvsFeats(not(Ind2Mnt),:) = [];

        ExpectedOutputs = zeros(size(DatasetEvsFeats,1), 1);
        ExpectedOutputs(IndClss(:,2)) = 1;

    case '4 risk classes'
        IndClss = false(length(GeneralRE.(DatesInds{3})), 4);
        IndClss(:,1) = (GeneralRE.(DatesInds{3}) == 0);
        IndClss(:,2) = (GeneralRE.(DatesInds{3}) >= 1) & (GeneralRE.(DatesInds{3}) < str2double(ClssThr{1}));
        IndClss(:,3) = (GeneralRE.(DatesInds{3}) >= str2double(ClssThr{1})) & (GeneralRE.(DatesInds{3}) < str2double(ClssThr{2}));
        IndClss(:,4) = (GeneralRE.(DatesInds{3}) >= str2double(ClssThr{2}));

        if not(all(sum(IndClss,2) == 1))
            error('There is a multiple class for some observations!')
        end

        ExpectedOutputs = zeros(size(GeneralRE.(DatesInds{3})));
        ExpectedOutputs(IndClss(:,2)) = 1;
        ExpectedOutputs(IndClss(:,3)) = 2;
        ExpectedOutputs(IndClss(:,4)) = 3;

        if length(unique(ExpectedOutputs)) < 4
            warning('Some classes did not contain any observations!')
        end

    case 'Regression'
        IndClss = [(GeneralRE.(DatesInds{3}) == 0), (GeneralRE.(DatesInds{3}) >= 1)];
        ExpectedOutputs = GeneralRE.(DatesInds{3});

    otherwise
        error('Type of output desired not recognized!')
end

%% Randomness amount (just for research purposes)
if RndOuts
    if not(strcmp(OutMode,'L-NL classes'))
        error(['To randomize output you must use binary classes! ', ...
               'Please contact the support.'])
    end

    rng(12)

    switch RandType
        case 'Chaos'
            RndVector  = rand(size(ExpectedOutputs));
            RndExpOutP = ExpectedOutputs.*RndVector;
            RndExpOutN = (1-ExpectedOutputs).*RndVector;
            
            Ind2Chng = find( (RndExpOutP + RndExpOutN) < RndLevel );

        case 'Switch'
            NumIndsOutP = find(ExpectedOutputs);
            NumIndsOutN = find(1-ExpectedOutputs);

            NumOfObs2Change = ceil(numel(NumIndsOutP)*RndLevel);
            RelIndOutP2Chng = randperm(numel(NumIndsOutP), NumOfObs2Change);
            RelIndOutN2Chng = randperm(numel(NumIndsOutN), NumOfObs2Change);

            Ind2Chng = [NumIndsOutP(RelIndOutP2Chng), NumIndsOutN(RelIndOutN2Chng)];

        otherwise
            error('Random type not recognized!')
    end

    ExpectedOutputsOrg = ExpectedOutputs;
    ExpectedOutputs(Ind2Chng) = 1 - ExpectedOutputsOrg(Ind2Chng); % To invert values just in the indices to change!

    OrigRatio  = sum(ExpectedOutputsOrg == 1) / numel(ExpectedOutputs);
    PercChnged = sum(abs(ExpectedOutputs - ExpectedOutputsOrg)) / numel(ExpectedOutputs);
    warning(['The ',num2str(PercChnged*100),' % of the dataset changed! ', ...
             'The original ratio Unstable:Stable was ',num2str(OrigRatio*100),' %'])
end

%% Test-Training split of dataset
rng(7) % For reproducibility of the model
switch TstMode
    case 'RandomSplit'
        PrtDataset = cvpartition(ExpectedOutputs, 'Holdout',TstPerc);
        IndsTrnLog = training(PrtDataset); % Indices for the training set
        IndsTstLog = test(PrtDataset);     % Indices for the test set

    case 'AfterYear'        
        IndsTrnLog = year(DatasetEvsDates.Start) < LimYear;
        IndsTstLog = not(IndsTrnLog);

    otherwise
        error('Test mode not recognized!')
end

DatasetEvsDatesTrn = DatasetEvsDates(IndsTrnLog, :);
DatasetEvsDatesTst = DatasetEvsDates(IndsTstLog, :);
DatasetEvsFeatsTrn = DatasetEvsFeats(IndsTrnLog, :);
DatasetEvsFeatsTst = DatasetEvsFeats(IndsTstLog, :);
ExpectedOutputsTrn = ExpectedOutputs(IndsTrnLog, :);
ExpectedOutputsTst = ExpectedOutputs(IndsTstLog, :);

%% Derived datasets
if CrssVal
    PartCross = cvpartition(ExpectedOutputsTrn, 'KFold',kFoldNum); % It is correct to take from Train partition because Test must be unseen!

    [DatasetDatesCrossVal, DatasetFeatsCrossVal, ExpOutputsCrossVal, ...
        DatasetDatesCrossTrn, DatasetFeatsCrossTrn, ExpOutputsCrossTrn] = deal(cell(1, kFoldNum));
    for i1 = 1:kFoldNum
        DatasetDatesCrossTrn{i1} = DatasetEvsDatesTrn(PartCross.training(i1),:);
        DatasetFeatsCrossTrn{i1} = DatasetEvsFeatsTrn(PartCross.training(i1),:);
        ExpOutputsCrossTrn{i1}   = ExpectedOutputsTrn(PartCross.training(i1),:);

        DatasetDatesCrossVal{i1} = DatasetEvsDatesTrn(PartCross.test(i1),:); % It is correct to use Train because Cross validation should be inside training part!
        DatasetFeatsCrossVal{i1} = DatasetEvsFeatsTrn(PartCross.test(i1),:);
        ExpOutputsCrossVal{i1}   = ExpectedOutputsTrn(PartCross.test(i1),:);
    end
end

if NormVal
    PartValid = cvpartition(ExpectedOutputsTrn, 'Holdout',NrValPerc); % It is correct to take from Train partition because Test must be unseen!

    IndsTrnRdLogical = training(PartValid); % Indices for the training set when you use validation
    IndsValidLogical = test(PartValid);     % Indices for the validation set

    DatasetEvsDatesTrnRd = DatasetEvsDatesTrn(IndsTrnRdLogical, :);
    DatasetEvsDatesValid = DatasetEvsDatesTrn(IndsValidLogical, :);
    DatasetEvsFeatsTrnRd = DatasetEvsFeatsTrn(IndsTrnRdLogical, :);
    DatasetEvsFeatsValid = DatasetEvsFeatsTrn(IndsValidLogical, :);
    ExpectedOutputsTrnRd = ExpectedOutputsTrn(IndsTrnRdLogical, :);
    ExpectedOutputsValid = ExpectedOutputsTrn(IndsValidLogical, :);
end

%% Resampling of datasets
if ResDset
    DsetsDatesToRes = {DatasetEvsDatesTrn, DatasetEvsDatesTst}; % Here you put first Train and after Test!
    DsetsFeatsToRes = {DatasetEvsFeatsTrn, DatasetEvsFeatsTst};
    ExpctdOutsToRes = {ExpectedOutputsTrn, ExpectedOutputsTst};
    
    [DtsetDatesOut, DtsetFeatsOut, ExpOutsOut] = dataset_rebalance(DsetsDatesToRes, ...
                                                                   DsetsFeatsToRes, ...
                                                                   ExpctdOutsToRes, ...
                                                                   Rat2Imp, ...
                                                                   ResMode);

    DatasetEvsDatesTrn = DtsetDatesOut{1}; % Remember that 1 is Train and 2 Test!
    DatasetEvsDatesTst = DtsetDatesOut{2};
    DatasetEvsFeatsTrn = DtsetFeatsOut{1};
    DatasetEvsFeatsTst = DtsetFeatsOut{2};
    ExpectedOutputsTrn = ExpOutsOut{1};
    ExpectedOutputsTst = ExpOutsOut{2};

    clear('DtsetDatesOut', 'DtsetFeatsOut', 'ExpOutsOut')

    if CrssVal
        [DatasetDatesCrossTrn, DatasetFeatsCrossTrn, ...
            ExpOutputsCrossTrn] = dataset_rebalance(DatasetDatesCrossTrn, ...
                                                    DatasetFeatsCrossTrn, ...
                                                    ExpOutputsCrossTrn, ...
                                                    Rat2Imp, ...
                                                    ResMode);

        [DatasetDatesCrossVal, DatasetFeatsCrossVal, ...
            ExpOutputsCrossVal] = dataset_rebalance(DatasetDatesCrossVal, ...
                                                    DatasetFeatsCrossVal, ...
                                                    ExpOutputsCrossVal, ...
                                                    Rat2Imp, ...
                                                    ResMode);
    end

    if NormVal
        [DtsetDatesOut, DtsetFeatsOut, ExpOutsOut] = dataset_rebalance({DatasetEvsDatesTrnRd, DatasetEvsDatesValid}, ...
                                                                       {DatasetEvsFeatsTrnRd, DatasetEvsFeatsValid}, ...
                                                                       {ExpectedOutputsTrnRd, ExpectedOutputsValid}, ...
                                                                       Rat2Imp, ...
                                                                       ResMode);

        DatasetEvsDatesTrnRd = DtsetDatesOut{1}; % Remember that 1 is Train and 2 Test!
        DatasetEvsDatesValid = DtsetDatesOut{2};
        DatasetEvsFeatsTrnRd = DtsetFeatsOut{1};
        DatasetEvsFeatsValid = DtsetFeatsOut{2};
        ExpectedOutputsTrnRd = ExpOutsOut{1};
        ExpectedOutputsValid = ExpOutsOut{2};

        clear('DtsetDatesOut', 'DtsetFeatsOut', 'ExpOutsOut')
    end
end

%% Update of DatasetInfo
DatasetInfo.Datasets.Feats = DatasetFeatsNms;

DatasetInfo.Datasets.Total = struct('Dates',DatasetEvsDates   , 'Features',DatasetEvsFeats   , 'Outputs',ExpectedOutputs   );
DatasetInfo.Datasets.Train = struct('Dates',DatasetEvsDatesTrn, 'Features',DatasetEvsFeatsTrn, 'Outputs',ExpectedOutputsTrn);
DatasetInfo.Datasets.Test  = struct('Dates',DatasetEvsDatesTst, 'Features',DatasetEvsFeatsTst, 'Outputs',ExpectedOutputsTst);

if CrssVal
    DatasetInfo.Datasets.CvTrain = struct('Dates',DatasetDatesCrossTrn, 'Features',DatasetFeatsCrossTrn, 'Outputs',ExpOutputsCrossTrn);
    DatasetInfo.Datasets.CvValid = struct('Dates',DatasetDatesCrossVal, 'Features',DatasetFeatsCrossVal, 'Outputs',ExpOutputsCrossVal);
end

if NormVal
    DatasetInfo.Datasets.NvTrain = struct('Dates',DatasetEvsDatesTrnRd, 'Features',DatasetEvsFeatsTrnRd, 'Outputs',ExpectedOutputsTrnRd);
    DatasetInfo.Datasets.NvValid = struct('Dates',DatasetEvsDatesValid, 'Features',DatasetEvsFeatsValid, 'Outputs',ExpectedOutputsValid);
end

%% Saving Dataset
ProgressBar.Message = "Saving files...";
if AddToExistingDataset
    DatasetInfo = [DsetInfoOld, DatasetInfo];
end

VariablesDset = {'DatasetInfo'};

saveswitch([fold_var,sl,'DatasetMLA.mat'], VariablesDset)