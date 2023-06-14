% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Options
fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
% Options = {'Yes', 'No, I want to use the current'};
% TrainDatasetAns = uiconfirm(Fig, ['Do you want to use the dataset of the entire ' ...
%                                   'study area created while training the ANNs?'], ...
%                                  'Train dataset use', 'Options',Options, 'DefaultOption',1);
% if strcmp(TrainDatasetAns,'Yes'); UseTrainDataset = true; else; UseTrainDataset = false; end

ParallelizeAns = uiconfirm(Fig, 'Do you want to parallelize prediction computation?', ...
                                'Parallelize', 'Options',{'Yes', 'No'}, 'DefaultOption',2);
if strcmp(ParallelizeAns,'Yes'); Parallelize = true; else; Parallelize = false; end

%% Loading files
load([fold_var,sl,'StudyAreaVariables.mat'],   'StudyAreaPolygon')
load([fold_var,sl,'GridCoordinates.mat'],      'xLongAll','yLatAll')
load([fold_var,sl,'MorphologyParameters.mat'], 'OriginallyProjected','SameCRSForAll')
load([fold_var,sl,'DatasetStudy.mat'],         'DatasetStudyFeats','DatasetStudyFeatsNotNorm', ...
                                               'DatasetStudyCoords','StablePolygons','UnstablePolygons')
load([fold_res_ml_curr,sl,'TrainedANNs.mat'],  'ModelInfo','ANNs','ANNsPerf')

if exist([fold_res_ml_curr,sl,'PredictionsStudy.mat'], 'file')
    load([fold_res_ml_curr,sl,'PredictionsStudy.mat'], 'PredictionProbabilities','LandslidesPolygons')
else
    PredictionProbabilities = table;
    LandslidesPolygons      = table;
end

DatasetToPredCoords       = DatasetStudyCoords;
DatasetToPredFeats        = DatasetStudyFeats;
DatasetToPredFeatsNotNorm = DatasetStudyFeatsNotNorm;

FeatsUsed     = ModelInfo{1,'DatasetInfo'}{:}{1,'FeaturesNames'}{:};
NormData      = ModelInfo{1,'DatasetInfo'}{:}{1,'NormalizedData'};
TimeSensMode  = ModelInfo.TimeSensMode;
RangesForNorm = ModelInfo.RangesForNorm{:};
LandslideDay  = true;

clear('DatasetStudyCoords', 'DatasetStudyFeats', 'DatasetStudyFeatsNotNorm')

%% Datetime extraction for time sensistive part
TimeSensExist = any(strcmp('TimeSensitive', ModelInfo{1,'DatasetInfo'}{:}{1,'FeaturesTypes'}{:}));
if TimeSensExist
    TimeSensCumulable  = [];
    [TimeSensitiveParam, TimeSensitiveData, TimeSensitiveDate, ...
        TimeSensitiveTrigg, TimeSensitivePeaks, TimeSensEventDates] = deal({});
    
    % Rainfall
    if any(contains(FeatsUsed, 'Rainfall'))
        load([fold_var,sl,'RainInterpolated.mat'], 'RainInterpolated','RainDateInterpolationStarts')
        TimeSensExist      = true;
        TimeSensitiveData  = [TimeSensitiveData,  {RainInterpolated}];
        TimeSensitiveDate  = [TimeSensitiveDate,  {RainDateInterpolationStarts}];
        TimeSensitiveParam = [TimeSensitiveParam, {'Rainfall'}];
        TimeSensCumulable  = [TimeSensCumulable,  1];
        clear('RainInterpolated')
        if strcmpi(TimeSensMode, 'TriggerCausePeak')
            load([fold_var,sl,'RainEvents.mat'], 'RainAmountPerEventInterp','RainMaxPeakPerEventInterp','RainRecDatesPerEvent')
            TimeSensitiveTrigg = [TimeSensitiveTrigg, {RainAmountPerEventInterp} ];
            TimeSensitivePeaks = [TimeSensitivePeaks, {RainMaxPeakPerEventInterp}];
            TimeSensEventDates = [TimeSensEventDates, {RainRecDatesPerEvent}     ];
            clear('RainAmountPerEventInterp', 'RainMaxPeakPerEventInterp', 'RainRecDatesPerEvent')
        end
    end
    
    % Temperature
    if any(contains(FeatsUsed, 'Temperature'))
        load([fold_var,sl,'TempInterpolated.mat'], 'TempInterpolated','TempDateInterpolationStarts')
        TimeSensExist      = true;
        TimeSensitiveData  = [TimeSensitiveData,  {TempInterpolated}];
        TimeSensitiveDate  = [TimeSensitiveDate,  {TempDateInterpolationStarts}];
        TimeSensitiveParam = [TimeSensitiveParam, {'Temperature'}];
        TimeSensCumulable  = [TimeSensCumulable,  0];
        clear('TempInterpolated')
        if strcmpi(TimeSensMode, 'TriggerCausePeak')
            load([fold_var,sl,'TempEvents.mat'], 'TempAmountPerEventInterp','TempMaxPeakPerEventInterp','TempRecDatesPerEvent')
            TimeSensitiveTrigg = [TimeSensitiveTrigg, {TempAmountPerEventInterp} ];
            TimeSensitivePeaks = [TimeSensitivePeaks, {TempMaxPeakPerEventInterp}];
            TimeSensEventDates = [TimeSensEventDates, {TempRecDatesPerEvent}     ];
            clear('TempAmountPerEventInterp', 'TempMaxPeakPerEventInterp', 'TempRecDatesPerEvent')
        end
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
            TimeSensitiveData{i1} = TimeSensitiveData{i1}(IndStartCommon:IndEventCommon,:);
            TimeSensitiveDate{i1} = TimeSensitiveDate{i1}(IndStartCommon:IndEventCommon);
        end
        if length(TimeSensitiveDate)>1 && ~isequal(TimeSensitiveDate{:})
            error('After uniformization of dates in time sensitive part, number of elements is not consistent! Please check it in the script.')
        end
    end
    
    TimeSensitiveDate = TimeSensitiveDate{1}; % Taking only the first one since they are identical!

    DaysForTS = ModelInfo{1,'DatasetInfo'}{:}{1,'DaysForTS'};
    
    IndEvent  = listdlg('PromptString',{'Select the date to consider for event (start times of 24 h):',''}, ...
                        'ListString',TimeSensitiveDate(DaysForTS:end), 'SelectionMode','single');
    EventDate = TimeSensitiveDate(DaysForTS-1+IndEvent);
    DateUsed  = EventDate;

    figure(Fig)
    drawnow

    LandslideDayAns = uiconfirm(Fig, 'Is this a landslide day?', ...
                                     'Landslide day', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
    if strcmp(LandslideDayAns,'Yes'); LandslideDay = true; else; LandslideDay = false; end
end

%% Selection of event and adjustment of dataset
switch TimeSensMode
    case 'CondensedDays'
        TimeSensitiveOper = repmat({'Averaged'}, 1, length(TimeSensitiveParam));
        TimeSensitiveOper(TimeSensCumulable) = {'Cumulated'};
        FeatsNamesToChange = cellfun(@(x, y) [x,y,num2str(DaysForTS),'d'], TimeSensitiveParam, TimeSensitiveOper, 'UniformOutput',false);

        RowToTake = find(EventDate == TimeSensitiveDate);
        for i1 = 1:length(TimeSensitiveParam)
            ColumnToChange = cell(1, size(TimeSensitiveDataInterpStudy{i1}, 2));
            for i2 = 1:size(TimeSensitiveDataInterpStudy{i1}, 2)
                if TimeSensCumulable(i1)
                    ColumnToChange{i2} = sum([TimeSensitiveDataInterpStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                else
                    ColumnToChange{i2} = mean([TimeSensitiveDataInterpStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                end
            end
            TSEventTimeNotNorm = cat(1,ColumnToChange{:});
            if NormData
                TSEventTime = rescale(TSEventTimeNotNorm, ...
                                       'InputMin',RangesForNorm{FeatsNamesToChange{i1}, 'Min value'}, ...
                                       'InputMax',RangesForNorm{FeatsNamesToChange{i1}, 'Max value'});
            else
                TSEventTime = TSEventTimeNotNorm;
            end

            DatasetToPredFeatsNotNorm.(FeatsNamesToChange{i1}) = TSEventTimeNotNorm(IndicesMLDataset);
            DatasetToPredFeats.(FeatsNamesToChange{i1})        = TSEventTime(IndicesMLDataset);
        end

    case 'SeparateDays'
        FeatsNamesToChange = cellfun(@(x) strcat(x,'-',string(1:DaysForTS)','daysBefore'), TimeSensitiveParam, 'UniformOutput',false); % Remember to change this line if you change feats names in datasetstudy_creation function!

        for i1 = 1:length(TimeSensitiveParam)
            for i2 = 1:DaysForTS
                RowToTake = find(EventDate == TimeSensitiveDate) - i2 + 1;
                TSEventTimeNotNorm = cat(1,TimeSensitiveDataInterpStudy{i1}{RowToTake,:});
                if NormData
                    TSEventTime = rescale(TSEventTimeNotNorm, ...
                                           'InputMin',RangesForNorm{FeatsNamesToChange{i1}(i2), 'Min value'}, ...
                                           'InputMax',RangesForNorm{FeatsNamesToChange{i1}(i2), 'Max value'});
                else
                    TSEventTime = TSEventTimeNotNorm;
                end

                DatasetToPredFeatsNotNorm.(FeatsNamesToChange{i1}(i2)) = TSEventTimeNotNorm(IndicesMLDataset);
                DatasetToPredFeats.(FeatsNamesToChange{i1}(i2))        = TSEventTime(IndicesMLDataset);
            end
        end

    case 'TriggerCausePeak'
        TimeSensType = ["Trigger"; strcat("Cause",num2str(DaysForTS),"d"); "TriggPeak"];
        FeatsNamesToChange = cellfun(@(x) strcat(x,TimeSensType), TimeSensitiveParam, 'UniformOutput',false);

        for i1 = 1:length(TimeSensitiveParam)
            TSEventTimeNotNorm = cell(1, 3); % 3 because you will have Trigger, cause, and peak
            TSEventTime        = cell(1, 3);
            if not(exist('StartDateTrigg', 'var'))
                IndsPossEvents = find(cellfun(@(x) min(abs(EventDate-x)) < days(2), TimeSensEventDates{i1}));
                if isempty(IndsPossEvents)
                    error('You have no events in a time window of 2 days around your datetime. Choose another datetime!')
                elseif IndsPossEvents > 1
                    PossEventNames = strcat("Event of ", char(cellfun(@(x) min(x), TimeSensEventDates{i1}(IndsPossEvents))), ' (+', ...
                                            num2str(cellfun(@(x) length(x), TimeSensEventDates{i1}(IndsPossEvents))'), ' h)');
                    RelIndEvent    = listdlg('PromptString',{'Select the rain event to consider:',''}, ...
                                             'ListString',PossEventNames, 'SelectionMode','single');

                    figure(Fig)
                    drawnow
                elseif IndsPossEvents == 1
                    RelIndEvent    = 1;
                end
                IndEventToTake = IndsPossEvents(RelIndEvent);
            else
                IndEventToTake = find(cellfun(@(x) min(abs(StartDateTrigg-x)) < minutes(1), TimeSensEventDates{i1}));
                if isempty(IndEventToTake) || (numel(IndEventToTake) > 1)
                    error(['Triggering event is not present in ',TimeSensitiveParam{i1},' or there are multiple possibilities. Please check it!'])
                end
            end
            StartDateTrigg = min(TimeSensEventDates{i1}{IndEventToTake});

            TSEventTimeNotNorm{1} = full(cat(1, TimeSensitiveTrigg{i1}{IndEventToTake,:})); % Pay attention to order! 1st row is Trigger

            CauseMode = ModelInfo{1,'DatasetInfo'}{:}{1,'CauseMode'};
            switch CauseMode
                case 'DailyCumulate'
                    RowToTake = find( abs(TimeSensitiveDate - StartDateTrigg) < days(1), 1 ) - 1; % Overwriting of RowToTake with the first date before your event! I want only the first one. -1 to take the day before the start of the event!
                    ColumnToAddTemp = cell(1, size(TimeSensitiveDataStudy{i1}, 2));
                    for i2 = 1:size(TimeSensitiveDataStudy{i1}, 2)
                        if TimeSensCumulable(i1)
                            ColumnToAddTemp{i2} = sum([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                        else
                            ColumnToAddTemp{i2} = mean([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                        end
                    end
                    TSEventTimeNotNorm{2} = cat(1,ColumnToAddTemp{:}); % Pay attention to order! 2nd row is Cause

                case 'EventsCumulate'
                    StartDateCause  = StartDateTrigg - days(DaysForTS);
                    IndsCauseEvents = find(cellfun(@(x) any(StartDateCause < x) && all(StartDateTrigg > x), TimeSensEventDates{i1})); % With any(StartDateCause < x) you could go before StartDateCause. change with all if you don't want (that event will be excluded)

                    MinDateEvents = min(cellfun(@min, TimeSensEventDates{i1}));
                    if StartDateCause < min(MinDateEvents)
                        warning('Some events could not be included (start date of Cause is before the minimum date of events)')
                    elseif isempty(IndsCauseEvents)
                        error('No events in the time period from start cause to start trigger!')
                    end

                    ColumnToAddTemp = zeros(size(TSEventTimeNotNorm{1},1), length(IndsCauseEvents));
                    for i2 = 1:length(IndsCauseEvents)
                        ColumnToAddTemp(:,i2) = full(cat(1, TimeSensitiveTrigg{i1}{IndsCauseEvents(i2),:}));
                    end
                    if TimeSensCumulable(i1)
                        TSEventTimeNotNorm{2} = sum(ColumnToAddTemp, 2); % Pay attention to order! 2nd row is Cause
                    else
                        TSEventTimeNotNorm{2} = mean(ColumnToAddTemp, 2); % Pay attention to order! 2nd row is Cause
                    end
            end

            TSEventTimeNotNorm{3} = full(cat(1, TimeSensitivePeaks{i1}{IndEventToTake,:})); % Pay attention to order! 3rd row is Peak

            for i2 = 1:length(FeatsNamesToChange{i1})
                if NormData
                    TSEventTime{i2} = rescale(TSEventTimeNotNorm{i2}, ...
                                               'InputMin',RangesForNorm{FeatsNamesToChange{i1}(i2), 'Min value'}, ...
                                               'InputMax',RangesForNorm{FeatsNamesToChange{i1}(i2), 'Max value'});
                else
                    TSEventTime{i2} = TSEventTimeNotNorm{i2};
                end

                DatasetToPredFeatsNotNorm.(FeatsNamesToChange{i1}(i2)) = TSEventTimeNotNorm{i2};
                DatasetToPredFeats.(FeatsNamesToChange{i1}(i2))        = TSEventTime{i2};
            end
        end

        DateUsed = StartDateTrigg;

    otherwise
        error('Type of ANN not yet implemented. Please contact developers.')
end

%% Prediction of dataset
ProgressBar.Indeterminate = 'off';
PredictionProbabilitiesCell = cell(1, size(ANNs, 2));
if Parallelize
    ProgressBar.Message = 'Predictions of study area with parallelization...';
    ModelsToUse = [ANNs{'Model',:}];
    parfor i1 = 1:size(ANNs, 2)
        CurrMdl = ModelsToUse{i1};
        [PredictionClassesTemp, PredictionProbabilitiesTemp] = predict(CurrMdl, DatasetToPredFeats);
        PredictionProbabilitiesCell{i1} = sparse(double(round(PredictionProbabilitiesTemp(:,2), 2)));
    end
    ModelSelected = ANNs{'Model',i1}{:};
else
    for i1 = 1:size(ANNs, 2)
        ProgressBar.Message = ['Predictions with model n. ',num2str(i1),' of ',num2str(size(ANNs, 2))];
        ProgressBar.Value   = i1/size(ANNs, 2);
    
        CurrMdl = ANNs{'Model',i1}{:};
        [PredictionClassesTemp, PredictionProbabilitiesTemp] = predict(CurrMdl, DatasetToPredFeats);
        PredictionProbabilitiesCell{i1} = sparse(double(round(PredictionProbabilitiesTemp(:,2), 2)));
    
        if IndMdlToUse == i1
            ModelSelected     = CurrMdl;
            PredClassesMdlSel = PredictionClassesTemp;
            PredProbsMdlSel   = PredictionProbabilitiesTemp;
        end
    end
end
ProgressBar.Indeterminate = 'on';

PredictionProbabilities{string(DateUsed), ANNs.Properties.VariableNames} = PredictionProbabilitiesCell;
LandslidesPolygons{string(DateUsed), {'UnstablePolygons','StablePolygons','LandslideDay'}} = {UnstablePolygons, StablePolygons, LandslideDay};

%% Creation of a dataset for quality
if numel(UnstablePolygons) > 1
    StablePolysSplit   = StablePolygons;
    UnstablePolysSplit = UnstablePolygons;
elseif numel(UnstablePolygons) == 1
    IndexOfNans = find(isnan(StablePolygons.Vertices(:,1)));
    EndOfExtPolygons = IndexOfNans(StablePolygons.NumRegions);
    [StablePolygonsLongSplit, StablePolygonsLatSplit] = polysplit(StablePolygons.Vertices(1:EndOfExtPolygons,1), StablePolygons.Vertices(1:EndOfExtPolygons,2));
    StablePolygonsSplitGross = cellfun(@(x, y) polyshape(x, y), StablePolygonsLongSplit, StablePolygonsLatSplit, 'UniformOutput',false);

    StablePolysSplit   = cellfun(@(x) intersect(x, StablePolygons),   StablePolygonsSplitGross);
    UnstablePolysSplit = cellfun(@(x) intersect(x, UnstablePolygons), StablePolygonsSplitGross);
end

IndexOfPointsUnstable = cell(size(UnstablePolysSplit));
for i1 = 1:numel(UnstablePolysSplit)
    [pp1, ee1] = getnan2([UnstablePolysSplit(i1).Vertices; nan, nan]);
    IndexOfPointsUnstable{i1} = find(inpoly([DatasetToPredCoords.Longitude,DatasetToPredCoords.Latitude], pp1,ee1));
end

IndexOfPointsStable = cell(size(StablePolysSplit));
for i1 = 1:numel(StablePolysSplit)
    [pp2, ee2] = getnan2([StablePolysSplit(i1).Vertices; nan, nan]);
    IndexOfPointsStable{i1}   = find(inpoly([DatasetToPredCoords.Longitude,DatasetToPredCoords.Latitude], pp2,ee2));
end

IndexOfPointsUnstableCat = cat(1, IndexOfPointsUnstable{:});
IndexOfPointsStableCat   = cat(1, IndexOfPointsStable{:});

DatasetForQuality = [ DatasetToPredFeats(IndexOfPointsUnstableCat,:)
                      DatasetToPredFeats(IndexOfPointsStableCat,:)   ];

if LandslideDay
    RealOutput = [ ones(size(IndexOfPointsUnstableCat))
                   zeros(size(IndexOfPointsStableCat))  ];
else
    RealOutput = [ zeros(size(IndexOfPointsUnstableCat))
                   zeros(size(IndexOfPointsStableCat))  ];
end

%% Quality of model with your dataset and choice of best model
% LossOfModels = cellfun(@(x) loss(x, DatasetForQuality, RealOutput), ANNs{'Model',:});

[ModelsMSEQ, AUCQ] = deal(zeros(1, size(ANNs, 2)));
[ProbabilityForQuality, FPR4ROC_ForQuality, TPR4ROC_ForQuality, ...
        ThresholdsROC_ForQuality, OptPoint_ForQuality] = deal(cell(1, size(ANNs, 2)));
if Parallelize
    ProgressBar.Message = 'Computing quality for dataset in parallel...';
    % ProgressParallel = ParforProgressbar(size(ANNs, 2));
    parfor i1 = 1:size(ANNs, 2)
        [~, ProbabilityForQuality{i1}] = predict(ANNs{'Model',i1}{:}, DatasetForQuality);
    
        ModelsMSEQ(i1) = mse(RealOutput, ProbabilityForQuality{i1}(:,2));
    
        [FPR4ROC_ForQuality{i1}, TPR4ROC_ForQuality{i1}, ThresholdsROC_ForQuality{i1}, ...
                AUCQ(i1), OptPoint_ForQuality{i1}] = perfcurve(RealOutput, ProbabilityForQuality{i1}(:,2), 1);

        % pause(100/size(ANNs, 2));
        % ProgressParallel.increment();
    end
    delete(ProgressParallel);
else
    for i1 = 1:size(ANNs, 2)
        ProgressBar.Message = ['Predicting dataset for quality n. ',num2str(i1),' of ',num2str(size(ANNs, 2))];
        
        [~, ProbabilityForQuality{i1}] = predict(ANNs{'Model',i1}{:}, DatasetForQuality);
    
        ModelsMSEQ(i1) = mse(RealOutput, ProbabilityForQuality{i1}(:,2));
    
        [FPR4ROC_ForQuality{i1}, TPR4ROC_ForQuality{i1}, ThresholdsROC_ForQuality{i1}, ...
                AUCQ(i1), OptPoint_ForQuality{i1}] = perfcurve(RealOutput, ProbabilityForQuality{i1}(:,2), 1);
    end
end

% In terms of loss
[~, BestModelLossForQuality] = min(ModelsMSEQ);
[~, BestModelLossForTrain  ] = min(ANNsPerf{'Err','Train'}{:}{'Loss',:});
[~, BestModelLossForTest   ] = min(ANNsPerf{'Err','Test' }{:}{'Loss',:});
% In terms of AUC
[~, BestModelAUCForQuality]  = max(cell2mat(AUC_ForQuality));
[~, BestModelAUCForTrain  ]  = max(cell2mat(ANNsPerf{'ROC','Train'}{:}{'AUC',:}));
[~, BestModelAUCForTest   ]  = max(cell2mat(ANNsPerf{'ROC','Test' }{:}{'AUC',:}));

IndMdlToUse = str2double(inputdlg({[ "Which model do you want to use?"
                                     strcat("From 1 to ", string(size(ANNs,2)))
                                     strcat("Best in terms of loss is: ", string(BestModelLossForQuality))
                                     strcat("Best in terms of AUC is: ", string(BestModelAUCForQuality))   ]}, '', 1, ...
                                     {num2str(BestModelLossForQuality)}));

%% Property extraction of model selected
MethodBestThreshold = ModelInfo.MethodForOptThreshold;
switch MethodBestThreshold
    case 'MATLAB'
        % Method integrated in MATLAB
        IndBestThrForQuality    = find(ismember([FPR4ROC_ForQuality{IndMdlToUse}, TPR4ROC_ForQuality{IndMdlToUse}], OptPoint_ForQuality{IndMdlToUse}, 'rows'));
        BestThresholdForQuality = ThresholdsROC_ForQuality{IndMdlToUse}(IndBestThrForQuality);

    case 'MaximizeRatio-TPR-FPR'
        % Method max ratio TPR/FPR
        RatioTPR_FPR_ForQuality = TPR4ROC_ForQuality{IndMdlToUse}./FPR4ROC_ForQuality{IndMdlToUse};
        RatioTPR_FPR_ForQuality(isinf(RatioTPR_FPR_ForQuality)) = nan;
        [~, IndBestThrForQuality] = max(RatioTPR_FPR_ForQuality);
        BestThresholdForQuality   = ThresholdsROC_ForQuality{IndMdlToUse}(IndBestThrForQuality);

    case 'MaximizeArea-TPR-TNR'
        % Method max product TPR*TNR
        AreaTPR_TNR_ForQuality    = TPR4ROC_ForQuality{IndMdlToUse}.*(1-FPR4ROC_ForQuality{IndMdlToUse});
        [~, IndBestThrForQuality] = max(AreaTPR_TNR_ForQuality);
        BestThresholdForQuality   = ThresholdsROC_ForQuality{IndMdlToUse}(IndBestThrForQuality);
end

BestThresholdTrain = ANNsPerf{'ROC','Train'}{:}{'BestThreshold',IndMdlToUse}{:};
BestThresholdTest  = ANNsPerf{'ROC','Test' }{:}{'BestThreshold',IndMdlToUse}{:};
IndBestThrTrain    = ANNsPerf{'ROC','Train'}{:}{'BestThrInd',   IndMdlToUse}{:};
IndBestThrTest     = ANNsPerf{'ROC','Test' }{:}{'BestThrInd',   IndMdlToUse}{:};

%% Clusterization
ProgressBar.Message = "Defining clusters for unstab points...";
if OriginallyProjected && SameCRSForAll
    load([fold_var,sl,'MorphologyParameters.mat'], 'OriginalProjCRS')

    ProjCRS = OriginalProjCRS;
else
    EPSG = str2double(inputdlg({["Set DTM EPSG (to calculate clusters)"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
    ProjCRS = projcrs(EPSG);
end

[xPlanCoord, yPlanCoord] = projfwd(ProjCRS, DatasetToPredCoords{:,2}, DatasetToPredCoords{:,1});

IndPointsUnstablePredicted = find(round(PredProbsMdlSel(:,2),4) >= BestThresholdForQuality); % Indices referred to the database!

dLat  = abs(yLatAll{1}(1)-yLatAll{1}(2));
dYmin = 2*deg2rad(dLat)*earthRadius*1.1; % This will be the radius constructed around every point to create clusters. *1.1 for an extra boundary. CHOICE TO USER!!
MinPointsForEachCluster = 6; % CHOICE TO USER!
ClustersUnstable = dbscan([xPlanCoord(IndPointsUnstablePredicted), ...
                           yPlanCoord(IndPointsUnstablePredicted)], dYmin, MinPointsForEachCluster); % Coordinates, min dist, min n. of point for each core point

IndNoisyPoints = (ClustersUnstable == -1);
IndPointsUnstablePredictedClean = IndPointsUnstablePredicted(not(IndNoisyPoints));
ClustersUnstableClean           = ClustersUnstable(not(IndNoisyPoints));
ClassesClustUnstClean           = unique(ClustersUnstableClean);

[IndClustersClasses, ClustersCoordinates] = deal(cell(1, length(ClassesClustUnstClean)));
for i1 = 1:length(ClassesClustUnstClean)
    IndClustersClasses{i1}  = IndPointsUnstablePredicted( ClustersUnstable == ClassesClustUnstClean(i1) );
    ClustersCoordinates{i1} = [DatasetToPredCoords{IndClustersClasses{i1},1}, DatasetToPredCoords{IndClustersClasses{i1},2}];
end

PlotColors = arrayfun(@(x) rand(1, 3), ClassesClustUnstClean', 'UniformOutput',false);

disp(strcat("Identified ",string(length(ClassesClustUnstClean))," landslides in your area."))

%% Plot for check
fig_check1 = figure(1);
ax_check1  = axes(fig_check1);
hold(ax_check1,'on')

ClusterCoordsCat = cat(1, ClustersCoordinates{:});
PlotColorsCat    = cellfun(@(x,y) repmat(y, size(x,1), 1), ClustersCoordinates, PlotColors, 'UniformOutput',false);
PlotColorsCat    = cat(1, PlotColorsCat{:});
PixelSize        = 2;

PlotClusters = scatter(ClusterCoordsCat(:,1), ClusterCoordsCat(:,2), PixelSize, ...
                                PlotColorsCat, 'Filled', 'Marker','s', 'Parent',ax_check1);

% fastscatter(DatasetToPredCoords{IndPointsUnstablePredictedClean,1}, DatasetToPredCoords{IndPointsUnstablePredictedClean,2}, ClustersUnstableClean);

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5);

title('Clusters')

fig_settings(fold0, 'AxisTick');

%% Choose of type of results
AreaMode = 'IndividualWindows'; % CHOICE TO USER!
switch AreaMode
    case 'IndividualWindows'
        %% Results in all the area delimeted by the polygons
        DatasetReduced                 = [ DatasetToPredFeatsNotNorm(IndexOfPointsUnstableCat,:)
                                           DatasetToPredFeatsNotNorm(IndexOfPointsStableCat,:)   ];

        DatasetReducedNorm             = [ DatasetToPredFeats(IndexOfPointsUnstableCat,:)
                                           DatasetToPredFeats(IndexOfPointsStableCat,:)   ];

        DatasetToPredCoordsReduced     = [ DatasetToPredCoords(IndexOfPointsUnstableCat,:)
                                           DatasetToPredCoords(IndexOfPointsStableCat,:)   ];

        PredClassesMdlSelReduced       = [ PredClassesMdlSel(IndexOfPointsUnstableCat,:)
                                           PredClassesMdlSel(IndexOfPointsStableCat,:)   ];

        PredProbsMdlSelReduced = [ PredProbsMdlSel(IndexOfPointsUnstableCat,:)
                                           PredProbsMdlSel(IndexOfPointsStableCat,:)   ];

        if LandslideDay
            RealOutputReduced = [ ones(size(IndexOfPointsUnstableCat))
                                  zeros(size(IndexOfPointsStableCat))   ];
        else
            RealOutputReduced = [ zeros(size(IndexOfPointsUnstableCat))
                                  zeros(size(IndexOfPointsStableCat))   ];
        end

        Loss_Reduced = loss(ModelSelected, DatasetReducedNorm, RealOutputReduced);

        [FPR4ROC_Reduced, TPR4ROC_Reduced, ThresholdsROC_Reduced, ...
                AUC_Reduced, OptPoint_Reduced] = perfcurve(RealOutputReduced, PredProbsMdlSelReduced(:,1), 0);

        %% Results splitted based on polygons
        PointsCoordUnstable = cellfun(@(x) table2array(DatasetToPredCoords(x,:)), IndexOfPointsUnstable, 'UniformOutput',false);
        PointsCoordStable   = cellfun(@(x) table2array(DatasetToPredCoords(x,:)), IndexOfPointsStable,   'UniformOutput',false);

        PointsAttributesUnstable = cellfun(@(x) DatasetToPredFeatsNotNorm(x,:), IndexOfPointsUnstable, 'UniformOutput',false);
        PointsAttributesStable   = cellfun(@(x) DatasetToPredFeatsNotNorm(x,:), IndexOfPointsStable,   'UniformOutput',false);

        PointsAttributesUnstableNorm = cellfun(@(x) DatasetToPredFeats(x,:), IndexOfPointsUnstable, 'UniformOutput',false);
        PointsAttributesStableNorm   = cellfun(@(x) DatasetToPredFeats(x,:), IndexOfPointsStable,   'UniformOutput',false);

        PredictedClassesEachPolyUnstable = cellfun(@(x) PredClassesMdlSel(x,:), IndexOfPointsUnstable, 'UniformOutput',false);
        PredictedClassesEachPolyStable   = cellfun(@(x) PredClassesMdlSel(x,:), IndexOfPointsStable,   'UniformOutput',false);

        PredictedProbabilitiesEachPolyUnstable = cellfun(@(x) PredProbsMdlSel(x,:), IndexOfPointsUnstable, 'UniformOutput',false);
        PredictedProbabilitiesEachPolyStable   = cellfun(@(x) PredProbsMdlSel(x,:), IndexOfPointsStable,   'UniformOutput',false);

        AttributesNames      = {'PolygonsStable', 'PolygonsUnstable', 'PointsCoordStable', 'PointsCoordUnstable', ...
                                'PointsAttributesStable', 'PointsAttributesUnstable', ...
                                'PointsAttributesStableNorm', 'PointsAttributesUnstableNorm'};

        ResultsNames         = {'ModelUsed', 'AUC', 'Loss', 'BestThreshold' ...
                                'PredictedClassesEachPolyStable', 'PredictedProbabilitiesEachPolyStable', ...
                                'PredictedClassesEachPolyUnstable', 'PredictedProbabilitiesEachPolyUnstable'};

        AttributesInPolygons = cell2table({StablePolysSplit, UnstablePolysSplit, PointsCoordStable, PointsCoordUnstable, ...
                                           PointsAttributesStable, PointsAttributesUnstable, ...
                                           PointsAttributesStableNorm, PointsAttributesUnstableNorm}, 'VariableNames',AttributesNames);

        ResultsInPolygons    = cell2table({ModelSelected, AUC_Reduced, Loss_Reduced, BestThresholdForQuality, ...
                                           PredictedClassesEachPolyStable, PredictedProbabilitiesEachPolyStable, ...
                                           PredictedClassesEachPolyUnstable, PredictedProbabilitiesEachPolyUnstable}, 'VariableNames',ResultsNames);

        %% Plot for check
        ProgressBar.Message = "Plotting results...";

        SelectedPolygon = str2double(inputdlg({["Which polygon do you want to plot?"
                                                strcat("From 1 to ", string(length(AttributesInPolygons.PolygonsStable{1,1})))]}, '', 1, {'1'}));

        Options = {'BestThreshold', 'Manual'};
        ModeUnstable = uiconfirm(Fig, 'How do you want to define the threshold?', ...
                                      'Threshold choice', 'Options',Options, 'DefaultOption',1);
        switch ModeUnstable
            case 'BestThreshold'
                ClassesThreshold = round(Probabilities,4) >= ResultsInPolygons.BestThreshold;
            case 'Manual'
                ThresholdChosed  = str2double(inputdlg({["Which threshold do you want?"
                                                         "If you overpass it, then you will have a landslide. [from 0 to 100 %]"]}, '', 1, {'50'}))/100;
                ClassesThreshold = Probabilities >= ThresholdChosed;
        end

        fig_check2 = figure(2);
        ax_check2  = axes(fig_check2);
        hold(ax_check2,'on')

        plot(AttributesInPolygons.PolygonsStable{1,1}{SelectedPolygon},   'FaceAlpha',.5, 'FaceColor',"#fffcdd");
        plot(AttributesInPolygons.PolygonsUnstable{1,1}{SelectedPolygon}, 'FaceAlpha',.5, 'FaceColor',"#fffcdd");

        PointsCoordinates = [ AttributesInPolygons.PointsCoordStable{1,1}{SelectedPolygon}
                              AttributesInPolygons.PointsCoordUnstable{1,1}{SelectedPolygon} ];

        Probabilities     = [ ResultsInPolygons.PredictedProbabilitiesEachPolyStable{1,1}{SelectedPolygon}(:,2)
                              ResultsInPolygons.PredictedProbabilitiesEachPolyUnstable{1,1}{SelectedPolygon}(:,2) ]; % These are probabilities of having landslide!

        Classes           = [ ResultsInPolygons.PredictedClassesEachPolyStable{1,1}{SelectedPolygon}
                              ResultsInPolygons.PredictedClassesEachPolyUnstable{1,1}{SelectedPolygon} ];

        StablePointsPlot  = scatter(PointsCoordinates(not(ClassesThreshold),1), ...
                                    PointsCoordinates(not(ClassesThreshold),2), ...
                                    20, 'Marker','s', 'MarkerFaceColor',"#5aa06b", 'MarkerEdgeColor','none');

        UnstabPointsPlot  = scatter(PointsCoordinates(ClassesThreshold,1), ...
                                    PointsCoordinates(ClassesThreshold,2), ...
                                    20, 'Marker','s', 'MarkerFaceColor',"#e33900", 'MarkerEdgeColor','none');

        yLatMean    = mean(PointsCoordinates(:,2));
        dLat1Meter  = rad2deg(1/earthRadius); % 1 m in lat
        dLong1Meter = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long

        RatioLatLong = dLat1Meter/dLong1Meter;
        daspect([1, RatioLatLong, 1])
end

%% Saving
ProgressBar.Message = "Saving files...";
VariablesPredictions = {'PredictionProbabilities', 'LandslidesPolygons'};
saveswitch([fold_res_ml_curr,sl,'PredictionsStudy.mat'], VariablesPredictions)

close(ProgressBar) % Fig instead of ProgressBar if in standalone version