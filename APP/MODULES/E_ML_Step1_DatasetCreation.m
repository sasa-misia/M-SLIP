% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

rng(10) % For reproducibility of the model

%% Loading data and initialization of variables
load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','SubArea','FilesDetectedSoilSlip')
load([fold_var,sl,'GridCoordinates.mat'],       'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load([fold_var,sl,'StudyAreaVariables.mat'],    'StudyAreaPolygon')

if length(FilesDetectedSoilSlip) == 1
    IndDetToUse = 1;
else
    IndDetToUse = listdlg('PromptString',{'Choose dataset you want to use: ',''}, ...
                          'ListString',FilesDetectedSoilSlip, 'SelectionMode','single');
end

DatasetStudyInfo = table;
LandslideDay     = true;
CriticalSlope    = nan;
EventDate        = nan;
DaysForTS        = nan;
TimeSensMode     = nan;
UseRanges        = false;
RangesForNorm    = nan;
CauseMode        = nan;

%% Pre existing DatasetML check
[AddToExistingDataset, OldSettings] = deal(false);
if exist([fold_var,sl,'DatasetML.mat'], 'file')
    Options = {'Yes, add this to the old one.', 'No, overwite it!'};
    MergeDataAns = uiconfirm(Fig, ['A pre-existing dataset for ML has been found. ' ...
                                   'Do you want to merge this new one with the old?'], ...
                                  'Merge datasets', 'Options',Options, 'DefaultOption',1);
    if strcmp(MergeDataAns, 'Yes, add this to the old one.')
        AddToExistingDataset = true;
        UseRanges            = true;

        load([fold_var,sl,'DatasetStudy.mat'], 'DatasetStudyInfo','RangesForNorm')
        load([fold_var,sl,'DatasetML.mat'],    'DatasetMLInfo','DatasetMLCoords','DatasetMLFeats', ...
                                               'DatasetMLFeatsNotNorm','DatasetMLClasses','DatasetMLDates')
        DatasetMLInfoOld         = DatasetMLInfo;
        DatasetMLCoordsOld       = DatasetMLCoords;
        DatasetMLFeatsOld        = DatasetMLFeats;
        DatasetMLFeatsNotNormOld = DatasetMLFeatsNotNorm;
        DatasetMLClassesOld      = DatasetMLClasses;
        DatasetMLDatesOld        = DatasetMLDates;

        Options = {'Yes, please', 'No, use different settings'};
        OldSettingsAns = uiconfirm(Fig, 'Do you want to mantain settings of the old one?', ...
                                        'Dataset settings', 'Options',Options, 'DefaultOption',1);
        if strcmp(OldSettingsAns, 'Yes, please'); OldSettings = true; end
    end
end

%% Dataset options
ProgressBar.Message = "Dataset options...";

if AddToExistingDataset
    FeaturesChosed = DatasetStudyInfo.Parameters;
else
    FeaturesOptions = {'Elevation', 'Slope', 'Aspect Angle', 'Mean Curvature', 'Profile Curvature', ...
                       'Planform Curvature', 'Contributing Area (log)', 'TWI', 'Clay Content', ...
                       'Sand Content', 'NDVI', 'Sub Soil', 'Top Soil', 'Land Use', 'Vegetation', ...
                       'Distance To Roads', 'Random', 'Rainfall', 'Temperature'};
    IndFeatsChosed  = listdlg('PromptString',{'Select features to use:',''}, ...
                              'ListString',FeaturesOptions, 'SelectionMode','multiple');
    FeaturesChosed  = FeaturesOptions(IndFeatsChosed);
end

TimeSensExist = false;
if any(strcmp(FeaturesChosed, 'Rainfall')) || any(strcmp(FeaturesChosed, 'Temperature'))
    if AddToExistingDataset
        TimeSensMode = DatasetStudyInfo.TimeSensitiveMode;
    else
        Options = {'SeparateDays', 'CondensedDays', 'TriggerCausePeak'};
        TimeSensMode = uiconfirm(Fig, 'How do you want to built the time sensitive data?', ...
                                      'Time sensitive structure', 'Options',Options, 'DefaultOption',2);
    end

    if AddToExistingDataset && OldSettings
        MultipleDayAnalysis = DatasetStudyInfo.MultipleDayAnalysis;
    else
        MultipleDayChoice = uiconfirm(Fig, 'Do you want to add a different day in dataset?', ...
                                           'Time sensitive analyses', 'Options',{'Yes', 'No, only a single day'}, 'DefaultOption',2);
        if strcmp(MultipleDayChoice,'Yes'); MultipleDayAnalysis = true; else; MultipleDayAnalysis = false; end
    end

    TimeSensExist = true;
end

if AddToExistingDataset
    NormData    = DatasetStudyInfo.NormalizedData;
    CategsExist = DatasetStudyInfo.CategoricalClasses;
else
    Options = {'Yes', 'No'};
    NormalizeChoice = uiconfirm(Fig, 'Do you want to normalize data?', ...
                                     'Normalization', 'Options',Options, 'DefaultOption',1);
    if strcmp(NormalizeChoice,'Yes'); NormData = true; else; NormData = false; end

    Options = {'Categorical classes', 'Numbered classes'};
    CategoricalChoice = uiconfirm(Fig, 'How do you want to define classes?', ...
                                       'Classes type', 'Options',Options, 'DefaultOption',2);
    if strcmp(CategoricalChoice,'Categorical classes'); CategsExist = true; else; CategsExist = false; end
end

if SubArea
    Options = {'PolygonsOfInfoDetected', 'ManualSquares'};
    PolyUnstableMode = uiconfirm(Fig, 'How do you want to define unstable polygons where a landslide was detected?', ...
                                      'Unstable Area', 'Options',Options, 'DefaultOption',1);
else
    PolyUnstableMode = 'ManualSquares';
end

if AddToExistingDataset && OldSettings
    StablePointsApproach = DatasetStudyInfo.StableAreaApproach;
    if strcmp(StablePointsApproach, 'SlopeOutsideUnstable')
        CriticalSlope = DatasetStudyInfo.CriticalSlope;
    end
    InpBufferSizes = DatasetStudyInfo.InputBufferSizes;
    ModifyRatio    = DatasetStudyInfo.ModifyRatioClasses;
    if ModifyRatio
        RatioInputs   = table2array(DatasetStudyInfo.RatioClasses);
        RatioToImpose = RatioInputs(1)/RatioInputs(2);
        ResampleMode  = DatasetStudyInfo.ResampleModeDatasetML;
        if exist('MultipleDayAnalysis', 'var') && MultipleDayAnalysis && strcmp(ResampleMode,'Undersampling')
            MantainPointsUnstab = DatasetStudyInfo.UnstablePointsMantainedInDayOfStable;
        end
    end

else
    Options = {'SlopeOutsideUnstable', 'AllOutsideUnstable', 'BufferedUnstablePolygons'};
    StablePointsApproach  = uiconfirm(Fig, 'How do you want to define stable points?', ...
                                           'Stable Area', 'Options',Options, 'DefaultOption',3);

    if strcmp(StablePointsApproach, 'SlopeOutsideUnstable')
        CriticalSlope  = str2double(inputdlg({"Choose the critical slope below which you have stable points."}, '', 1, {'8'}));
    end
    
    if strcmp(PolyUnstableMode, 'PolygonsOfInfoDetected')
        PromptBuffer = ["Size of the buffer to define indecision area [m]"
                        "Size of the buffer to define stable area [m]"    ];
        SuggBuffVals = {'100', '250'};
    else
        PromptBuffer = ["Size of the window side where are located unstable points"
                        "Size of the window side to define indecision area"
                        "Size of the window side to define stable area"            ];
        SuggBuffVals = {'45', '200', '300'};
    end
    
    if any(strcmp(StablePointsApproach, {'SlopeOutsideUnstable','AllOutsideUnstable'}))
        PromptBuffer(end) = [];
        SuggBuffVals(end) = [];
    end
    
    InpBufferSizes = str2double(inputdlg(PromptBuffer, '', 1, SuggBuffVals));
    
    Options = {'Yes', 'No'};
    ModifyRatioChoice  = uiconfirm(Fig, 'Do you want to modify ratio of positive and negative points?', ...
                                        'Ratio Pos to Neg', 'Options',Options, 'DefaultOption',1);
    if strcmp(ModifyRatioChoice,'Yes'); ModifyRatio = true; else; ModifyRatio = false; end
    
    if ModifyRatio
        RatioInputs = str2double(inputdlg(["Choose part of unstable: ", "Choose part of stable: "], '', 1, {'1', '2'}));
        RatioToImpose = RatioInputs(1)/RatioInputs(2);
    
        Options = {'Undersampling', 'Oversampling'};
        ResampleMode = uiconfirm(Fig, 'What approach do you want to use in resampling data?', ...
                                      'Resampling technique', 'Options',Options, 'DefaultOption',1);
    
        if exist('MultipleDayAnalysis', 'var') && MultipleDayAnalysis && strcmp(ResampleMode,'Undersampling')
            Options = {'Yes', 'No'};
            MantainUnstabChoice  = uiconfirm(Fig, ['Do you want to mantain points where there is instability ' ...
                                                   'also in the day when all points are stable? ' ...
                                                   '(these points will be mantained during the merge and ' ...
                                                   'the subsequent ratio adjustment)'], ...
                                                   'Mantain unstable points', 'Options',Options, 'DefaultOption',1);
            if strcmp(MantainUnstabChoice,'Yes'); MantainPointsUnstab = true; else; MantainPointsUnstab = false; end
        end
    end
end

switch StablePointsApproach
    case {'SlopeOutsideUnstable'}
        PolyStableMode = 'AllOutside';
        StableMethod   = 'Slope';

    case {'AllOutsideUnstable'}
        PolyStableMode = 'AllOutside';
        StableMethod   = 'EntireStable';

    case {'BufferedUnstablePolygons'}
        PolyStableMode = 'Buffer';
        StableMethod   = 'EntireStable';
end

%% Writing DatasetStudyInfo
DatasetStudyInfo.FullPathInfoDetUsed  = [fold_raw_det_ss,sl,char(FilesDetectedSoilSlip(IndDetToUse))];
DatasetStudyInfo.Parameters           = {FeaturesChosed};
DatasetStudyInfo.NormalizedData       = NormData;
DatasetStudyInfo.CategoricalClasses   = CategsExist;
DatasetStudyInfo.UnstablePolygonsMode = PolyUnstableMode;
DatasetStudyInfo.StableAreaApproach   = StablePointsApproach;
if strcmp(StablePointsApproach,'SlopeOutsideUnstable')
    DatasetStudyInfo.CriticalSlope = CriticalSlope;
end
DatasetStudyInfo.InputBufferSizes     = {InpBufferSizes};
DatasetStudyInfo.ModifyRatioClasses   = ModifyRatio;
if ModifyRatio
    DatasetStudyInfo.RatioClasses = {array2table(RatioInputs', 'VariableNames',{'UnstablePart','StablePart'})};
    DatasetStudyInfo.ResampleModeDatasetML = ResampleMode;
    if MultipleDayAnalysis && strcmp(ResampleMode,'Undersampling')
        DatasetStudyInfo.UnstablePointsMantainedInDayOfStable = MantainPointsUnstab;
    end
end

%% ANN time sensitive additional options
if TimeSensExist
    TimeSensitiveDate = {};
    
    % Rainfall
    if any(strcmp(FeaturesChosed, 'Rainfall'))
        load([fold_var,sl,'RainInterpolated.mat'], 'RainDateInterpolationStarts')
        TimeSensitiveDate = [TimeSensitiveDate, {RainDateInterpolationStarts}];
        TimeSensExist = true;
    end
    
    % Temperature
    if any(strcmp(FeaturesChosed, 'Temperature'))
        load([fold_var,sl,'TempInterpolated.mat'], 'TempDateInterpolationStarts')
        TimeSensitiveDate = [TimeSensitiveDate, {TempDateInterpolationStarts}];
        TimeSensExist = true;
    end
    
    % Uniformization of time sensitive part
    StartDateCommon = max(cellfun(@min, TimeSensitiveDate)); % Start in end dates
    EndDateCommon   = min(cellfun(@max, TimeSensitiveDate)); % End in end dates
    
    if EndDateCommon < StartDateCommon
        error('Time sensitive part has no datetime in common! Please re-interpolate time sensitive part.')
    end
    
    if length(TimeSensitiveDate) > 1
        for i1 = 1 : length(TimeSensitiveDate)
            IndStartCommon = find(StartDateCommon == TimeSensitiveDate{i1}); % You should put an equal related to days and not exact timing
            IndEventCommon = find(EndDateCommon   == TimeSensitiveDate{i1}); % You should put an equal related to days and not exact timing
            TimeSensitiveDate{i1} = TimeSensitiveDate{i1}(IndStartCommon:IndEventCommon);
        end
        if length(TimeSensitiveDate)>1 && ~isequal(TimeSensitiveDate{:})
            error('After uniformization of dates in time sensitive part, number of elements is not consistent! Please check it in the script.')
        end
    end
    
    TimeSensitiveDate = TimeSensitiveDate{1}; % Taking only the first one since they are identical!
    
    IndEvent = listdlg('PromptString',{'Select the date to consider for event (start times of 24 h):',''}, ...
                       'ListString',TimeSensitiveDate, 'SelectionMode','single');
    EventDate = TimeSensitiveDate(IndEvent);

    LandslideDayAns = uiconfirm(Fig, 'Is this a landslide day?', ...
                                     'Landslide day', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
    if strcmp(LandslideDayAns,'No'); LandslideDay = false; end

    % User choice about days to consider
    MaxDaysPossible = IndEvent;
    if MultipleDayAnalysis
        if AddToExistingDataset && OldSettings
            DaysBeforeEventWhenStable = DatasetStudyInfo.DayBeforeEventForStablePoints;

            if (IndEvent-DaysBeforeEventWhenStable) <= 0
                error(['Since you want to add this dataset to the old one, ', ...
                       'you need more recording datetimes for TS. You need', ...
                       num2str(-IndEvent+DaysBeforeEventWhenStable),' more days in recs!'])
            end
        else
            DaysBeforeEventWhenStable = str2double(inputdlg({["Please specify how many days before the event you want "
                                                              "to consider all points as stable."
                                                              strcat("(You have ",string(IndEvent), ...
                                                                     " days of cumulate rainfalls to your event)")]}, '', 1, {'10'}));

            if (IndEvent-DaysBeforeEventWhenStable) <= 0
                error(['You have to select another day for stable points, ', ...
                       'more forward in time than the start of your dataset'])
            end
        end

        MaxDaysPossible = IndEvent-DaysBeforeEventWhenStable;
        BeforeEventDate = EventDate-days(DaysBeforeEventWhenStable);
    end

    if AddToExistingDataset % Important: do not add OldSettings because, even if you don't want the OldSettings, this parameter MUST BE the same!
        DaysForTS = DatasetStudyInfo.DaysForTS;
        if (MaxDaysPossible-DaysForTS) < 0
            error(['Since you want to add this dataset to the old one, you need more ', ...
                   num2str(-MaxDaysPossible+DaysForTS),' days in recs!'])
        end
        if strcmp(TimeSensMode,'TriggerCausePeak')
            CauseMode = DatasetStudyInfo.CauseMode;
        end

    else
        switch TimeSensMode
            case 'SeparateDays'
                DaysForTS = str2double(inputdlg({['Please specify the max number of day (max ', ...
                                                  num2str(MaxDaysPossible),') you want to consider:']}, '', 1, {num2str(MaxDaysPossible)}));
        
            case 'CondensedDays'
                DaysForTS = str2double(inputdlg({[ "Please specify how many days you want to cumulate (or average): "
                                                   strcat("(Max possible:  ",string(MaxDaysPossible)," days") ]}, '', 1, {num2str(MaxDaysPossible)}));

            case 'TriggerCausePeak'
                DaysForTS = str2double(inputdlg({[ "Please specify how many days you want to consider for cause rainfall amount: "
                                                   strcat("(Max possible:  ",string(MaxDaysPossible-2)," days") ]}, '', 1, {num2str(MaxDaysPossible-2)})); % -2 because script is set to search an event in a time window of max 2 days before or after

                Options   = {'DailyCumulate', 'EventsCumulate'};
                CauseMode = uiconfirm(Fig, 'How do you want to define cause rainfall?', ...
                                           'Cause Rainfall', 'Options',Options, 'DefaultOption',2);
        end

        if (MaxDaysPossible-DaysForTS) < 0
            error('You have to select fewer days than the maximum possible (or you have to change matrix of daily rainfalls)')
        end
    end

    % Continuing to write DatasetStudyInfo
    DatasetStudyInfo.EventDate           = EventDate;
    DatasetStudyInfo.LandslideEvent      = LandslideDay;
    DatasetStudyInfo.TimeSensitiveMode   = TimeSensMode;
    if strcmp(TimeSensMode,'TriggerCausePeak')
        DatasetStudyInfo.CauseMode       = CauseMode;
    end
    DatasetStudyInfo.MultipleDayAnalysis = MultipleDayAnalysis;
    if MultipleDayAnalysis
        DatasetStudyInfo.BeforeEventDate = BeforeEventDate;
        DatasetStudyInfo.DayBeforeEventForStablePoints = DaysBeforeEventWhenStable;
    end
    DatasetStudyInfo.DaysForTS = DaysForTS;
end

%% Datasets creation
[DatasetStudyFeats, DatasetStudyCoords, RangesForNorm, TimeSensPart, DatasetStudyFeatsNotNorm, ...
        FeaturesType, ClassPolys] = datasetstudy_creation( fold0, 'Features',FeaturesChosed, ...
                                                                  'Categorical',CategsExist, ...
                                                                  'Normalize',NormData, ...
                                                                  'TargetFig',Fig, ...
                                                                  'DayOfEvent',EventDate, ...
                                                                  'DaysForTS',DaysForTS, ...
                                                                  'TimeSensMode',TimeSensMode, ...
                                                                  'CauseMode',CauseMode, ...
                                                                  'UseRanges',UseRanges, ...
                                                                  'Ranges',RangesForNorm);

FeaturesNames = DatasetStudyFeats.Properties.VariableNames;

if TimeSensExist
    TimeSensitiveParam = TimeSensPart.ParamNames;
    CumulableParam     = TimeSensPart.Cumulable;
    TimeSensitiveDate  = TimeSensPart.Datetimes;
    TimeSensitiveDataInterpStudy = TimeSensPart.Data;
    if strcmp(TimeSensMode,'TriggerCausePeak')
        TimeSensitiveTrigg = TimeSensPart.TriggAmountPerEvent;
        TimeSensitivePeaks = TimeSensPart.PeaksPerEvent;
        TimeSensEventDates = TimeSensPart.DatesPerEvent;
        StartDateEventTrig = TimeSensPart.StartDateTriggering;
        HoursDiff = abs(EventDate-StartDateEventTrig);
        if HoursDiff >= hours(1)
            warning(['There is a difference of ',num2str(hours(HoursDiff)), ...
                     ' between data you chosed and the start of the triggering!', ...
                     ' Event date will be overwrite.'])
        end
    end

    if not(isequal(EventDate, TimeSensPart.EventTime))
        error('Datetime of DatasetStudy and the one you chosed do not match! Please check "datasetstudy_creation" function')
    end
end

%% Continuing to write DatasetStudyInfo
DatasetStudyInfo.FeaturesNames = {FeaturesNames};
DatasetStudyInfo.FeaturesTypes = {FeaturesType};
DatasetStudyInfo.ClassPolygons = {ClassPolys};
if TimeSensExist
    DatasetStudyInfo.TSParameters = {TimeSensitiveParam};
    DatasetStudyInfo.TSCumulable  = {CumulableParam};
end

%% R2 Correlation coefficients for Study Area
ProgressBar.Message = "Creation of correlation matrix...";

DatasetStudyFeatsTemp        = DatasetStudyFeats;
DatasetStudyFeatsNotNormTemp = DatasetStudyFeatsNotNorm;
if any(strcmp(FeaturesType, "Categorical"))
    ColumnsToConvert = find(strcmp(FeaturesType, "Categorical"));
    for i1 = ColumnsToConvert % ColumnsToConvert must be always horizontal!
        DatasetStudyFeatsTemp.(FeaturesNames{i1})        = grp2idx(DatasetStudyFeatsTemp{:, i1});
        DatasetStudyFeatsNotNormTemp.(FeaturesNames{i1}) = grp2idx(DatasetStudyFeatsNotNormTemp{:, i1});
    end
end

DatasetStudyFeatsTemp        = table2array(DatasetStudyFeatsTemp);
DatasetStudyFeatsNotNormTemp = table2array(DatasetStudyFeatsNotNormTemp);

DatasetStudyFeatsTemp(isnan(DatasetStudyFeatsTemp))               = -9999; % To replace NaNs with -9999 because otherwise you will have NaNs in R2 matrix.
DatasetStudyFeatsNotNormTemp(isnan(DatasetStudyFeatsNotNormTemp)) = -9999; % To replace NaNs with -9999 because otherwise you will have NaNs in R2 matrix.

R2ForDatasetStudyFeats        = array2table(corrcoef(DatasetStudyFeatsTemp), ...
                                            'VariableNames',FeaturesNames, 'RowNames',FeaturesNames);
R2ForDatasetStudyFeatsNotNorm = array2table(corrcoef(DatasetStudyFeatsNotNormTemp), ...
                                            'VariableNames',FeaturesNames, 'RowNames',FeaturesNames);

%% Statistics of study area
ProgressBar.Message = "Statistics of study area...";

[TempNormStats, TempNotNormStats] = deal(array2table(nan(size(DatasetStudyFeats,2), 4), ...
                                                                'VariableNames',{'1stQuantile','3rdQuantile','MinExtreme','MaxExtreme'}, ...
                                                                'RowNames',FeaturesNames));
for i1 = 1:length(FeaturesNames)
    if strcmp(FeaturesType(i1),'Categorical'); continue; end
    TempNormStats{FeaturesNames{i1}, 1:2} = quantile(DatasetStudyFeats.(FeaturesNames{i1}), [0.25, 0.75]);
    TempNormStats{FeaturesNames{i1}, 3:4} = [min(DatasetStudyFeats.(FeaturesNames{i1})), ...
                                                     max(DatasetStudyFeats.(FeaturesNames{i1}))];

    TempNotNormStats{FeaturesNames{i1}, 1:2} = quantile(DatasetStudyFeatsNotNorm.(FeaturesNames{i1}), [0.25, 0.75]);
    TempNotNormStats{FeaturesNames{i1}, 3:4} = [min(DatasetStudyFeatsNotNorm.(FeaturesNames{i1})), ...
                                                        max(DatasetStudyFeatsNotNorm.(FeaturesNames{i1}))];
end

DatasetStudyStats = table({TempNormStats}, {TempNotNormStats}, 'VariableNames',{'Normalized', 'NotNormalized'});

%% Creation of landslides, indecision, and stable polygons
[UnstablePolygons, StablePolygons, ...
        IndecisionPolygons] = polygons_landslides(fold0, 'StableMode',PolyStableMode, ...
                                                         'UnstableMode',PolyUnstableMode, ...
                                                         'BufferSizes',InpBufferSizes, ...
                                                         'CreationCoordinates','Planar', ...
                                                         'PolyOutputMode','Multi', ...
                                                         'IndOfInfoDetToUse',IndDetToUse);

UnstablePolyMrgd = union(UnstablePolygons);
IndecisPolyMrgd  = union(IndecisionPolygons);
StablePolyMrgd   = union(StablePolygons);

%% Rebalance of dataset
[IndicesMLDataset, ExpectedOut] = datasetml_indexing(DatasetStudyCoords, DatasetStudyFeatsNotNorm, ...
                                                     UnstablePolyMrgd, StablePolyMrgd, 'StableMethod',StableMethod, ...
                                                                                       'ModifyRatio',ModifyRatio, ...
                                                                                       'RatioToImpose',RatioToImpose, ...
                                                                                       'ResampleMode',ResampleMode, ...
                                                                                       'DayOfLandslide',LandslideDay, ...
                                                                                       'CriticalSlope',CriticalSlope);

DatasetMLCoordsPart1       = DatasetStudyCoords(IndicesMLDataset,:);
DatasetMLFeatsNotNormPart1 = DatasetStudyFeatsNotNorm(IndicesMLDataset,:);
DatasetMLFeatsPart1        = DatasetStudyFeats(IndicesMLDataset,:);
DatasetMLClassesPart1      = table(ExpectedOut, 'VariableNames',{'ExpectedOutput'});
DatasetMLDatesPart1        = table(repmat(EventDate, size(DatasetMLCoordsPart1,1), 1), ...
                                   repmat(LandslideDay, size(DatasetMLCoordsPart1,1), 1), 'VariableNames',{'Datetime','LandslideEvent'});

%% Creation of a copy to use in analysis (could be made of 2 different days)
if not(MultipleDayAnalysis)
    DatasetMLCoords       = DatasetMLCoordsPart1;
    DatasetMLFeatsNotNorm = DatasetMLFeatsNotNormPart1;
    DatasetMLFeats        = DatasetMLFeatsPart1;
    DatasetMLClasses      = DatasetMLClassesPart1;
    DatasetMLDates        = DatasetMLDatesPart1;

elseif MultipleDayAnalysis
    ProgressBar.Message = 'Addition of points in the day of stability';

    DatasetMLCoordsPart2       = DatasetMLCoordsPart1;
    DatasetMLFeatsNotNormPart2 = DatasetMLFeatsNotNormPart1; % To overwrite TS part (rows below)
    DatasetMLFeatsPart2        = DatasetMLFeatsPart1; % To overwrite TS part (rows below)
    DatasetMLClassesPart2      = table(false(size(ExpectedOut)), 'VariableNames',{'ExpectedOutput'}); % At this particular timing prediction should be 0! (no landslide)
    DatasetMLDatesPart2        = table(repmat(BeforeEventDate, size(DatasetMLCoordsPart1,1), 1), ...
                                       false(size(DatasetMLCoordsPart1,1), 1), 'VariableNames',{'Datetime','LandslideEvent'});

    switch TimeSensMode
        case 'SeparateDays'
            FeatsNamesToChange = cellfun(@(x) strcat(x,'-',string(1:DaysForTS)','daysBefore'), TimeSensitiveParam, 'UniformOutput',false); % Remember to change this line if you change feats names in datasetstudy_creation function!

            for i1 = 1:length(TimeSensitiveParam)
                for i2 = 1:DaysForTS
                    RowToTakeAtDiffTime = IndEvent - DaysBeforeEventWhenStable - i2 + 1;
                    TSStableTimeNotNorm = cat(1,TimeSensitiveDataInterpStudy{i1}{RowToTakeAtDiffTime,:});
                    if NormData
                        TSStableTime = rescale(TSStableTimeNotNorm, ...
                                               'InputMin',RangesForNorm{FeatsNamesToChange{i1}(i2), 'Min value'}, ...
                                               'InputMax',RangesForNorm{FeatsNamesToChange{i1}(i2), 'Max value'});
                    else
                        TSStableTime = TSStableTimeNotNorm;
                    end

                    DatasetMLFeatsNotNormPart2.(FeatsNamesToChange{i1}(i2)) = TSStableTimeNotNorm(IndicesMLDataset);
                    DatasetMLFeatsPart2.(FeatsNamesToChange{i1}(i2))        = TSStableTime(IndicesMLDataset);
                end
            end

        case 'CondensedDays'
            TimeSensitiveOper = repmat({'Averaged'}, 1, length(TimeSensitiveParam));
            TimeSensitiveOper(CumulableParam) = {'Cumulated'};
        
            FeatsNamesToChange  = cellfun(@(x, y) [x,y,num2str(DaysForTS),'d'], TimeSensitiveParam, TimeSensitiveOper, 'UniformOutput',false);

            RowToTakeAtDiffTime = IndEvent-DaysBeforeEventWhenStable;
            for i1 = 1:length(TimeSensitiveParam)
                ColumnToChangeAtDiffTimeTemp = cell(1, size(TimeSensitiveDataInterpStudy{i1}, 2));
                for i2 = 1:size(TimeSensitiveDataInterpStudy{i1}, 2)
                    if CumulableParam(i1)
                        ColumnToChangeAtDiffTimeTemp{i2} = sum([TimeSensitiveDataInterpStudy{i1}{RowToTakeAtDiffTime : -1 : (RowToTakeAtDiffTime-DaysForTS+1), i2}], 2);
                    else
                        ColumnToChangeAtDiffTimeTemp{i2} = mean([TimeSensitiveDataInterpStudy{i1}{RowToTakeAtDiffTime : -1 : (RowToTakeAtDiffTime-DaysForTS+1), i2}], 2);
                    end
                end
                TSStableTimeNotNorm = cat(1,ColumnToChangeAtDiffTimeTemp{:});
                if NormData
                    TSStableTime = rescale(TSStableTimeNotNorm, ...
                                           'InputMin',RangesForNorm{FeatsNamesToChange{i1}, 'Min value'}, ...
                                           'InputMax',RangesForNorm{FeatsNamesToChange{i1}, 'Max value'});
                else
                    TSStableTime = TSStableTimeNotNorm;
                end

                DatasetMLFeatsNotNormPart2.(FeatsNamesToChange{i1}) = TSStableTimeNotNorm(IndicesMLDataset);
                DatasetMLFeatsPart2.(FeatsNamesToChange{i1})        = TSStableTime(IndicesMLDataset);
            end
           
        case 'TriggerCausePeak'
            TimeSensType = ["Trigger"; strcat("Cause",num2str(DaysForTS),"d"); "TriggPeak"];
            FeatsNamesToChange = cellfun(@(x) strcat(x,TimeSensType), TimeSensitiveParam, 'UniformOutput',false);

            DesiredDateStableTrigg = EventDate - days(DaysBeforeEventWhenStable);
            for i1 = 1:length(TimeSensitiveParam)
                TSStableTimeNotNorm = cell(1, 3); % 3 because you will have Trigger, cause, and peak
                TSStableTime        = cell(1, 3);
                if not(exist('StartDateNoTrigg', 'var'))
                    [HoursDiff, IndStableToTake] = min(cellfun(@(x) abs(DesiredDateStableTrigg-min(x)), TimeSensEventDates{i1}));
                    if HoursDiff >= hours(1)
                        warning(['There is a difference of ',num2str(hours(HoursDiff)), ...
                                 ' between data you chosed and the start of the stable event!', ...
                                 ' Stable event date will be overwrite.'])
                    end
                else
                    IndStableToTake = find(cellfun(@(x) min(abs(StartDateNoTrigg-x)) < minutes(1), TimeSensEventDates{i1}));
                    if isempty(IndStableToTake) || (numel(IndStableToTake) > 1)
                        error(['Triggering event is not present in ',TimeSensitiveParam{i1},' or there are multiple possibilities. Please check it!'])
                    end
                end
                StartDateNoTrigg = min(TimeSensEventDates{i1}{IndStableToTake});
    
                TSStableTimeNotNorm{1} = full(cat(1, TimeSensitiveTrigg{i1}{IndStableToTake,:})); % Pay attention to order! 1st row is Trigger
    
                switch CauseMode
                    case 'DailyCumulate'
                        RowToTake = find( abs(TimeSensitiveDate - StartDateNoTrigg) < days(1), 1 ) - 1; % Overwriting of RowToTake with the first date before your event! I want only the first one. -1 to take the day before the start of the event!
                        ColumnToAddTemp = cell(1, size(TimeSensitiveDataStudy{i1}, 2));
                        for i2 = 1:size(TimeSensitiveDataStudy{i1}, 2)
                            if CumulableParam(i1)
                                ColumnToAddTemp{i2} = sum([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                            else
                                ColumnToAddTemp{i2} = mean([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                            end
                        end
                        TSStableTimeNotNorm{2} = cat(1,ColumnToAddTemp{:}); % Pay attention to order! 2nd row is Cause
    
                    case 'EventsCumulate'
                        StartDateCause  = StartDateNoTrigg - days(DaysForTS);
                        IndsCauseEvents = find(cellfun(@(x) any(StartDateCause < x) && all(StartDateNoTrigg > x), TimeSensEventDates{i1})); % With any(StartDateCause < x) you could go before StartDateCause. change with all if you don't want (that event will be excluded)

                        MinDateEvents = min(cellfun(@min, TimeSensEventDates{i1}));
                        if StartDateCause < min(MinDateEvents)
                            warning('Some events could not be included (start date of Cause is before the minimum date of events)')
                        elseif isempty(IndsCauseEvents)
                            error('No events in the time period from start cause to start trigger!')
                        end

                        ColumnToAddTemp = zeros(size(TSStableTimeNotNorm{1},1), length(IndsCauseEvents));
                        for i2 = 1:length(IndsCauseEvents)
                            ColumnToAddTemp(:,i2) = full(cat(1, TimeSensitiveTrigg{i1}{IndsCauseEvents(i2),:}));
                        end
                        if CumulableParam(i1)
                            TSStableTimeNotNorm{2} = sum(ColumnToAddTemp, 2); % Pay attention to order! 2nd row is Cause
                        else
                            TSStableTimeNotNorm{2} = mean(ColumnToAddTemp, 2); % Pay attention to order! 2nd row is Cause
                        end
                end
    
                TSStableTimeNotNorm{3} = full(cat(1, TimeSensitivePeaks{i1}{IndStableToTake,:})); % Pay attention to order! 3rd row is Peak

                for i2 = 1:length(FeatsNamesToChange{i1})
                    if NormData
                        TSStableTime{i2} = rescale(TSStableTimeNotNorm{i2}, ...
                                                   'InputMin',RangesForNorm{FeatsNamesToChange{i1}(i2), 'Min value'}, ...
                                                   'InputMax',RangesForNorm{FeatsNamesToChange{i1}(i2), 'Max value'});
                    else
                        TSStableTime{i2} = TSStableTimeNotNorm{i2};
                    end

                    DatasetMLFeatsNotNormPart2.(FeatsNamesToChange{i1}(i2)) = TSStableTimeNotNorm{i2}(IndicesMLDataset);
                    DatasetMLFeatsPart2.(FeatsNamesToChange{i1}(i2))        = TSStableTime{i2}(IndicesMLDataset);
                end
            end
    end

    DatasetMLCoords       = [DatasetMLCoordsPart1;       DatasetMLCoordsPart2      ];
    DatasetMLFeatsNotNorm = [DatasetMLFeatsNotNormPart1; DatasetMLFeatsNotNormPart2];
    DatasetMLFeats        = [DatasetMLFeatsPart1;        DatasetMLFeatsPart2       ];
    DatasetMLClasses      = [DatasetMLClassesPart1;      DatasetMLClassesPart2     ];
    DatasetMLDates        = [DatasetMLDatesPart1;        DatasetMLDatesPart2       ];

    if ModifyRatio
        IndsOfUnstable = (DatasetMLClasses.ExpectedOutput==1);
        IndsOfStable   = (DatasetMLClasses.ExpectedOutput==0);

        RatioBeforeResampling = sum(IndsOfUnstable)/sum(IndsOfStable);

        switch ResampleMode % NOTE THAT WORKS ONLY IF STABLES > UNSTABLES, PLEASE MODIFY IT!
            case 'Undersampling'
                IndsNumsStable = find(IndsOfStable);

                PercToRemove = 1-RatioBeforeResampling/RatioToImpose; % Think about this formula please!

                if MantainPointsUnstab
                    [pp3, ee3] = getnan2([StablePolyMrgd.Vertices; nan, nan]);
                    IndsPointsInStable = find(inpoly([DatasetMLCoords.Longitude,DatasetMLCoords.Latitude], pp3,ee3));

                    RelIndOfStabToChange = randperm(numel(IndsPointsInStable), ...
                                                              min(ceil(numel(IndsNumsStable)*PercToRemove), numel(IndsPointsInStable))); % ceil(numel(IndsNumsStable)*PercToRemove) remain because you have in any case to remove that number of points and not IndsPointsInStable. 
                    IndsToChange = IndsPointsInStable(RelIndOfStabToChange);
                else
                    RelIndOfStabToChange = randperm(numel(IndsNumsStable), ceil(numel(IndsNumsStable)*PercToRemove));
                    IndsToChange = IndsNumsStable(RelIndOfStabToChange);
                end
    
                IndsOfStable(IndsToChange) = false;

                RelIndsMLDatasetToUse = [find(IndsOfUnstable); find(IndsOfStable)];

                RatioAfterResampling = sum(IndsOfUnstable)/sum(IndsOfStable);
                if (any(IndsOfUnstable & IndsOfStable)) || (round(RatioToImpose, 1) ~= round(RatioAfterResampling, 1))
                    error("Something went wrong in re-attributing the correct ratio between positive and negative outputs!")
                end

            case 'Oversampling'
                IndsNumsUnstable = find(IndsOfUnstable);
                IndsNumsStable   = find(IndsOfStable);
    
                PercToAdd = RatioToImpose/RatioBeforeResampling; % Think about this formula please!
    
                NumOfReps = fix(PercToAdd);
    
                RelIndOfUntabToAdd   = randperm(numel(IndsNumsUnstable), ceil(numel(IndsNumsUnstable)*(PercToAdd-NumOfReps)));
                IndsUnstableRepeated = [repmat(IndsNumsUnstable, NumOfReps, 1); IndsNumsUnstable(RelIndOfUntabToAdd)];

                RelIndsMLDatasetToUse = [IndsUnstableRepeated; IndsNumsStable];

                RatioAfterResampling = numel(IndsUnstableRepeated)/numel(IndsNumsStable);
                if (not(isempty(intersect(IndsUnstableRepeated,IndsNumsStable)))) || (round(RatioToImpose, 1) ~= round(RatioAfterResampling, 1))
                    error("Something went wrong in re-attributing the correct ratio between positive and negative outputs!")
                end
        end

        DatasetMLCoords       = DatasetMLCoords(RelIndsMLDatasetToUse,:);
        DatasetMLFeatsNotNorm = DatasetMLFeatsNotNorm(RelIndsMLDatasetToUse,:);
        DatasetMLFeats        = DatasetMLFeats(RelIndsMLDatasetToUse,:);
        DatasetMLClasses      = DatasetMLClasses(RelIndsMLDatasetToUse,:);
        DatasetMLDates        = DatasetMLDates(RelIndsMLDatasetToUse,:);
    end
end

%% Overwriting of dates in DatasetStudyInfo and DatasetMLDates (if TriggerCausePeak)
if TimeSensExist && strcmp(TimeSensMode,'TriggerCausePeak')
    DatasetStudyInfo.EventDate = StartDateEventTrig;
    DatasetMLDates.Datetime(DatasetMLDates.Datetime == EventDate) = StartDateEventTrig;
    if MultipleDayAnalysis
        DatasetStudyInfo.BeforeEventDate = StartDateNoTrigg;
        DatasetStudyInfo.DayBeforeEventForStablePoints = ceil(days(StartDateEventTrig-StartDateNoTrigg));
        DatasetMLDates.Datetime(DatasetMLDates.Datetime == BeforeEventDate) = StartDateNoTrigg;
    end
end
DatasetMLInfo = DatasetStudyInfo;

%% Aggregation of DatasetML
if AddToExistingDataset
    ProgressBar.Message   = "Merge of datasets...";
    DatasetMLInfo         = [DatasetMLInfoOld         ; DatasetMLInfo        ];
    DatasetMLCoords       = [DatasetMLCoordsOld       ; DatasetMLCoords      ];
    DatasetMLFeats        = [DatasetMLFeatsOld        ; DatasetMLFeats       ];
    DatasetMLFeatsNotNorm = [DatasetMLFeatsNotNormOld ; DatasetMLFeatsNotNorm];
    DatasetMLClasses      = [DatasetMLClassesOld      ; DatasetMLClasses     ];
    DatasetMLDates        = [DatasetMLDatesOld        ; DatasetMLDates       ];
end

if size(DatasetMLInfo, 1) == 1
    AdviceAns = uiconfirm(Fig, ['If you want o add other events/areas to your dataset for ML, ' ...
                                'Please consider to run again all previous scripts with new ' ...
                                'data (different study area, recordings, etc...)'], ...
                               'Merge datasets', 'Options',{'Ok, I understand!'});
end

%% Saving...
ProgressBar.Message = "Saving files...";
VariablesDatasetStudy = {'DatasetStudyInfo', 'UnstablePolygons', 'IndecisionPolygons', 'StablePolygons', ...
                         'DatasetStudyCoords', 'DatasetStudyFeats', 'DatasetStudyFeatsNotNorm', 'DatasetStudyStats', ...
                         'RangesForNorm', 'R2ForDatasetStudyFeats', 'R2ForDatasetStudyFeatsNotNorm'};

VariablesDatasetML = {'DatasetMLInfo', 'DatasetMLCoords', 'DatasetMLFeats', 'DatasetMLFeatsNotNorm', ...
                      'DatasetMLClasses', 'DatasetMLDates', 'RangesForNorm'};

save([fold_var,sl,'DatasetStudy.mat'], VariablesDatasetStudy{:})
save([fold_var,sl,'DatasetML.mat'],    VariablesDatasetML{:})

close(ProgressBar) % Fig instead of ProgressBar if in standalone version