% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Machine Learning application
cd(fold_var)
load('InfoDetectedSoilSlips.mat') % Remember that you have to run the script that made it everytime because you could have old values!
load('RainInterpolated.mat')
load('GridCoordinates.mat')
load('MorphologyParameters.mat')
load('SoilParameters.mat')
load('VegetationParameters.mat')
load('DmCum.mat')
load('AnalysisInformation.mat')
load('UserA_Answers.mat', 'MunSel')
load('UserB_Answers.mat', 'ScaleFactorX','ScaleFactorY')
load('UserD_Answers.mat', 'VegAttribution')
load('UserE_Answers.mat')
if exist('LandUsesVariables.mat', 'file')
    load('LandUsesVariables.mat', 'AllLandUnique','IndexLandUsesToRemove')
    LandUsesRemoved = string(AllLandUnique(IndexLandUsesToRemove));
end

%% Selection of time in which to calibrate
EventsAnalysed = string(StabilityAnalysis{:,2});
Choice = listdlg('PromptString',{'Select time when you want to calibrate the model:',''}, ...
                 'ListString',EventsAnalysed);
EventSelForTrain = datetime(EventsAnalysed(Choice), 'InputFormat','dd/MM/yyyy HH:mm:ss');
RowFromLast = hours(StabilityAnalysis{2}(end)-EventSelForTrain);
RainEndEvent = size(RainInterpolated,1)-RowFromLast;
cd(fold0)

%% Calculating DmCum
BetaStarStudyArea = cellfun(@(x,y) x(y), BetaStarAll, ...
                                         IndexDTMPointsInsideStudyArea, ...
                                         'UniformOutput',false);

nStudyArea = cellfun(@(x,y) x(y), nAll, ...
                                  IndexDTMPointsInsideStudyArea, ...
                                  'UniformOutput',false);

DmCum = cellfun(@(x,y,z) min(x.*y./(z.*H.*(1-Sr0)), 1), DmCumPar, ...
                                                        repmat(BetaStarStudyArea, StabilityAnalysis{1}, 1), ...
                                                        repmat(nStudyArea, StabilityAnalysis{1}, 1), ...
                                                        'UniformOutput',false);

%% Extract Slope of Study Area
SlopeStudy = cellfun(@(x,y) x(y), SlopeAll, ...
                                  IndexDTMPointsInsideStudyArea, ...
                                  'UniformOutput',false);

%% Calculating unconditionally stable points
if ~all(cellfun(@isempty, IndexDTMPointsExcludedInStudyArea))
    StablePointsOptions = {'With slope angle'
                           'With a previous SLIP analysis'};
else
    StablePointsOptions = {'With slope angle'};
end

StableOption = listdlg('PromptString',{'How do you want to define unconditionally stable area?',''}, ...
                       'ListString',StablePointsOptions, 'SelectionMode','single');

switch StableOption
    case 1
        SlopeUncStab = str2double(inputdlg("Set Critical Slope Angle", '', 1, {'10'}));
        SlopeUnstab = 40;
    case 2
        cd(fold_res_fs)
        fold_res_fs_an = uigetdir('open');

        cd(fold_res_fs_an)
        FSLoadIndex = hours(EventSelForTrain-StabilityAnalysis{2}(1))+1;
        load(strcat('Fs',num2str(FSLoadIndex),'.mat'));
end

%% Calculate cumulate rainfall
rng(1) % For reproducibility

if StableOption == 2
    FSForInstability = 1.2;
    FSForStability = 9;
    RealFS = zeros(TrainingSamples,1);
end

RatioNegToPos = 2;
ConditioningFactors = 10;
PercentageOfDatset = 0.7;
PositiveSamples = uint64(size(InfoDetectedSoilSlips,1)*PercentageOfDatset);
RandomIndexing = randperm(size(InfoDetectedSoilSlips,1));
ResamplePositive = false;
TrainingSamples = uint64((1+RatioNegToPos)*PositiveSamples);
NegativeSamples = TrainingSamples-PositiveSamples;
ResampleNegative = true;

TrainingCell = cell(TrainingSamples,ConditioningFactors); % Initializing cells and arrays
TrainingDTMPoints = zeros(TrainingSamples,3);

if ~ResamplePositive
    for i1 = 1:PositiveSamples
        DTMi = InfoDetectedSoilSlips{RandomIndexing(i1),3};
        Indexi = InfoDetectedSoilSlips{RandomIndexing(i1),4};
        IndexAlli = IndexDTMPointsInsideStudyArea{DTMi}(Indexi);
        TrainingCell(i1,:) = [InfoDetectedSoilSlips( RandomIndexing(i1), [8, 9, 11:15, 17, 18] ), ...
                              {DmCumPar{end-RowFromLast, DTMi}(Indexi)}];
        TrainingDTMPoints(i1,:) = [DTMi, Indexi, IndexAlli];
        if StableOption == 2; RealFS(i1) = FactorSafety{DTMi}(Indexi); end
    end
else
    i1 = 1;
    while i1 <= PositiveSamples
        DTMi = max(uint64(rand*length(IndexDTMPointsInsideStudyArea)),1);
        Indexi = max(uint64(rand*length(IndexDTMPointsInsideStudyArea{DTMi})),1);
        IndexAlli = IndexDTMPointsInsideStudyArea{DTMi}(Indexi);
        GoodPoint = false;

        switch StableOption
            case 1
                if SlopeStudy{DTMi}(Indexi) > SlopeUnstab && ~isnan(CohesionAll{DTMi}(IndexAlli))
                    GoodPoint = true;
                end
            case 2
                if FactorSafety{DTMi}(Indexi) < FSForInstability && CohesionAll{DTMi}(IndexAlli) ~= 999 && ~isnan(CohesionAll{DTMi}(IndexAlli))
                    GoodPoint = true;
                end
        end

        if GoodPoint
            TrainingCell(i1,:) = {SlopeAll{DTMi}(IndexAlli), AspectAngleAll{DTMi}(IndexAlli), ...
                                  CohesionAll{DTMi}(IndexAlli), PhiAll{DTMi}(IndexAlli), ...
                                  KtAll{DTMi}(IndexAlli), AAll{DTMi}(IndexAlli), nAll{DTMi}(IndexAlli), ...
                                  BetaStarAll{DTMi}(IndexAlli), RootCohesionAll{DTMi}(IndexAlli), ...
                                  DmCumPar{end-RowFromLast, DTMi}(Indexi)};
            TrainingDTMPoints(i1,:) = [DTMi, Indexi, IndexAlli];
            if StableOption == 2; RealFS(i1) = FactorSafety{DTMi}(Indexi); end
            i1 = i1+1;
        end
    end
end

i2 = PositiveSamples+1;
while i2 <= TrainingSamples
    DTMi = max(uint64(rand*length(IndexDTMPointsInsideStudyArea)),1);
    Indexi = max(uint64(rand*length(IndexDTMPointsInsideStudyArea{DTMi})),1);
    IndexAlli = IndexDTMPointsInsideStudyArea{DTMi}(Indexi);
    GoodPoint = false;

    switch StableOption
            case 1
                if SlopeStudy{DTMi}(Indexi) < SlopeUncStab && ~isnan(CohesionAll{DTMi}(IndexAlli))
                    GoodPoint = true;
                end
            case 2
                if FactorSafety{DTMi}(Indexi) > FSForStability && CohesionAll{DTMi}(IndexAlli) ~= 999 && ~isnan(CohesionAll{DTMi}(IndexAlli))
                    GoodPoint = true;
                end
    end

    if GoodPoint
        TrainingCell(i2,:) = {SlopeAll{DTMi}(IndexAlli), AspectAngleAll{DTMi}(IndexAlli), ...
                              CohesionAll{DTMi}(IndexAlli), PhiAll{DTMi}(IndexAlli), ...
                              KtAll{DTMi}(IndexAlli), AAll{DTMi}(IndexAlli), nAll{DTMi}(IndexAlli), ...
                              BetaStarAll{DTMi}(IndexAlli), RootCohesionAll{DTMi}(IndexAlli), ...
                              DmCumPar{end-RowFromLast, DTMi}(Indexi)};
        TrainingDTMPoints(i2,:) = [DTMi, Indexi, IndexAlli];
        if StableOption == 2; RealFS(i2) = FactorSafety{DTMi}(Indexi); end
        i2 = i2+1;
    end
end

TrainingFs = [true(PositiveSamples,1); false(NegativeSamples,1)];

TrainingTable = cell2table(TrainingCell); % Not array2table because in that way they remain cells

ConditioningFactorsNames = {'Slope (°)', 'Aspect (°)', 'c''(kPa)', 'phi (°)', 'kt(1/h)', ...
                            'A (kPa)', 'n (-)', 'beta* (-)', 'cr (kPa)', 'cum par m (-)'};

TrainingTable.Properties.VariableNames = ConditioningFactorsNames;

% TrainingTable = removevars(TrainingTable, 'Aspect (°)');
% ConditioningFactorsNames(2) = [];

%% Creation of table with all point to pass through model
CumRainStudyArea = cell(1,size(RainInterpolated,2));
for i1 = 1:size(RainInterpolated,2)
    CumRainStudyArea{i1} = full(sum([RainInterpolated{RainEndEvent-23:RainEndEvent,i1}],2));
end

AnalysisTable = [cellfun(@(x,y) x(y), SlopeAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false)
                 cellfun(@(x,y) x(y), AspectAngleAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false)
                 cellfun(@(x,y) x(y), CohesionAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false)
                 cellfun(@(x,y) x(y), PhiAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false)
                 cellfun(@(x,y) x(y), KtAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false)
                 cellfun(@(x,y) x(y), AAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false)
                 cellfun(@(x,y) x(y), nAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false)
                 cellfun(@(x,y) x(y), BetaStarAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false)
                 cellfun(@(x,y) x(y), RootCohesionAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false)
                 DmCumPar(end-RowFromLast,:)]';

%% Cleaning procedure NOT NECESSARY IN NEW ANALYSIS, BECAUSE THEY ALREADY HAD NaN
AnalysisTableIndex999 = cellfun(@(x) x==999, AnalysisTable, 'UniformOutput',false);

if any(cellfun(@any, AnalysisTableIndex999), 'all')
    for i1 = 1:size(AnalysisTable,1)*size(AnalysisTable,2)
        AnalysisTable{i1}(AnalysisTableIndex999{i1}) = NaN;
    end

    for i1 = 1:size(AnalysisTable,1)
        AnalysisTable{i1,end}(AnalysisTableIndex999{i1,3}) = NaN; % Third column because in the thirs there is Choesion and could have 999
        for i2 = 1:size(DmCumPar,1)
            DmCumPar{i2, i1}(AnalysisTableIndex999{i1,3}) = NaN;
        end
    end

    if StableOption == 2
        FactorSafetyIndex999 = AnalysisTableIndex999(:,3)'; % Third column because in the thirs there is Choesion and could have 999
        FactorSafetyIndexTooBig = cellfun(@(x) x>80, FactorSafety, 'UniformOutput',false);
        FactorSafetyIndexNotGood = cellfun(@(x,y) x|y, FactorSafetyIndex999, FactorSafetyIndexTooBig, 'UniformOutput',false);
        for i1 = 1:length(FactorSafety)
            FactorSafety{i1}(FactorSafetyIndexNotGood{i1}) = NaN;
        end
    end
end

%% Normalizaion of table for training
Minimum = [min(cellfun(@min, AnalysisTable(:,1:end-1)), [], 1), min(min(cellfun(@min, DmCumPar)))];
Maximum = [max(cellfun(@max, AnalysisTable(:,1:end-1)), [], 1), max(max(cellfun(@max, DmCumPar)))];

AnalysisTableIndexNan = cellfun(@isnan, AnalysisTable, 'UniformOutput',false);
ExcludedValues = [Minimum(1:2), Maximum(3:9), Minimum(10)];

if any(cellfun(@any, AnalysisTableIndexNan), 'all')
    for i2 = 1:size(AnalysisTable,1)
        for i3 = 1:size(AnalysisTable,2)
            AnalysisTable{i2,i3}(AnalysisTableIndexNan{i2,3}) = ExcludedValues(i3);
        end
    end
end

AnalysisTableNorm = [cellfun(@(x) (x-Minimum(1))./(Maximum(1)-Minimum(1)), AnalysisTable(:,1), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(2))./(Maximum(2)-Minimum(2)), AnalysisTable(:,2), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(3))./(Maximum(3)-Minimum(3)), AnalysisTable(:,3), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(4))./(Maximum(4)-Minimum(4)), AnalysisTable(:,4), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(5))./(Maximum(5)-Minimum(5)), AnalysisTable(:,5), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(6))./(Maximum(6)-Minimum(6)), AnalysisTable(:,6), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(7))./(Maximum(7)-Minimum(7)), AnalysisTable(:,7), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(8))./(Maximum(8)-Minimum(8)), AnalysisTable(:,8), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(9))./(Maximum(9)-Minimum(9)), AnalysisTable(:,9), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(10))./(Maximum(10)-Minimum(10)), AnalysisTable(:,10), 'UniformOutput',false)];

TrainingCellNorm = num2cell((cell2mat(TrainingCell)-Minimum)./(Maximum-Minimum));
NanIntoTrCellNorm = cellfun(@isnan, TrainingCellNorm);
TrainingCellNorm(NanIntoTrCellNorm) = {0}; % To remove value consistant that normalized give NaNs

TrainingTableNorm = cell2table(TrainingCellNorm);
TrainingTableNorm.Properties.VariableNames = ConditioningFactorsNames;

if StableOption == 2
    MinFS = min(cellfun(@min, FactorSafety));
    MaxFS = max(cellfun(@max, FactorSafety));

    FactorSafetyNorm = cellfun(@(x) (x-MinFS)./(MaxFS-MinFS), ...
                                    FactorSafety, 'UniformOutput',false);

    RealFSNorm = (RealFS-MinFS)./(MaxFS-MinFS);
end

%% Machine / Deep Learning
ProgressBar.Message = 'Training of ML models...';
LearningOptions = {'Artificial Neural Network', 'Random Forest', 'Bag', ...
                   'Adaptive Boosting', 'Logit Boost', 'Gentle Boost', ...
                   'Total Boost', 'Auto Machine Learning', 'Auto ANN'};
Choice = listdlg('PromptString', {'Choose the algoritm:', ''}, 'ListString', ...
                 LearningOptions, 'SelectionMode', 'single');
LearnChoice = string(LearningOptions{Choice});

switch LearnChoice
    case "Artificial Neural Network"
        Model = fitcnet(TrainingTableNorm, TrainingFs);
        LearnMethod = LearnChoice;

    case "Random Forest"
        Model = TreeBagger(50, TrainingTableNorm, TrainingFs);
        LearnMethod = LearnChoice;

    case "Bag"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'Method','Bag', ...
                             'Learners',templateTree('Reproducible', true), ...
                             'Resample','on', 'NumLearningCycles',50);
        LearnMethod = LearnChoice;

    case "Adaptive Boosting"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'Method','AdaBoostM1', ...
                             'Learners',templateTree('Reproducible', true), ...
                             'LearnRate',0.1, 'NumLearningCycles',50);
        LearnMethod = LearnChoice;

    case "Logit Boost"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'Method','LogitBoost', ...
                             'Learners',templateTree('Reproducible', true), ...
                             'LearnRate',0.1, 'NumLearningCycles',50);
        LearnMethod = LearnChoice;

    case "Gentle Boost"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'Method','GentleBoost', ...
                             'Learners',templateTree('Reproducible', true), ...
                             'LearnRate',0.1, 'NumLearningCycles',50);
        LearnMethod = LearnChoice;

    case "Total Boost"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'Method','TotalBoost', ...
                             'Learners',templateTree('Reproducible', true), ...
                             'MarginPrecision',0.4, 'NumLearningCycles',50);
        LearnMethod = LearnChoice;

    case "Auto Machine Learning"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'OptimizeHyperparameters','auto');
        switch Model.Method
            case 'Bag'
                LearnMethod = "Bag";

            case 'AdaBoostM1'
                LearnMethod = "Adaptive Boosting";

            case 'GentleBoost'
                LearnMethod = "Gentle Boost";

            case 'LogitBoost'
                LearnMethod = "Logit Boost";

            case 'TotalBoost'
                LearnMethod = "Total Boost";
        end

    case "Auto ANN"
        Model = fitcnet(TrainingTableNorm,TrainingFs,'OptimizeHyperparameters','auto');
        LearnMethod = LearnChoice;
end

[FsTrainingPrediction, FsTrainingScores] = predict(Model,TrainingTableNorm);
if LearnMethod == "Random Forest"; [~, ~, FsTrainingCost] = predict(Model,TrainingTableNorm); end
if any(strcmp(LearnMethod, ["Adaptive Boosting", "Logit Boost", "Total Boost", "Gentle Boost"]))
    FsTrainingScores = exp(FsTrainingScores)./(exp(FsTrainingScores)+1); % from log(odds) to probability
    if LearnMethod == "Total Boost"
        FsTrainingScores = rescale(FsTrainingScores);
    end
end

%% Prediction of all events in AnalysisInformation
% Cretion of folder
cd(fold_res_fs)
EventSelForTrain.Format = 'dd-MM-yyyy-HH-mm';
FsFolderName = string(inputdlg({'Choose analysis folder name (inside Results->Factors of Safety):'}, ...
                                '',1, strcat('MachineLearning','-Event-',string(EventSelForTrain))));

if exist(FsFolderName,'dir')
    Options = {'Yes, thanks', 'No, for God!'};
    Answer = uiconfirm(Fig, strcat(FsFolderName, " is an existing folder. " + ...
                                   "Do you want to overwrite it?"), ...
                            'Window type', 'Options',Options);
    switch Answer
        case 'Yes, thanks.'
            rmdir(FsFolderName,'s')
            mkdir(FsFolderName)
        case 'No, for God!'
            return
    end
else
    mkdir(FsFolderName)
end

% Saving of AnalysisInformation
cd(strcat(fold_res_fs,sl,FsFolderName))
StabilityAnalysis{4} = ["Machine Learning", LearnChoice];
AnalysisParameters = table(EventSelForTrain, ScaleFactorX, ScaleFactorY, VegAttribution);
AnalysisParameters.MunSelected = {string(MunSel)};
AnalysisParameters.TrainingCellUsed = {TrainingCell};
if exist('LandUsesRemoved', 'var'); AnalysisParameters.LandUsesRemoved = {LandUsesRemoved}; end
StabilityAnalysis{5} = AnalysisParameters;

save('AnalysisInformation.mat','StabilityAnalysis');

Steps = size(DmCumPar,1)*size(AnalysisTable,1);

ProgressBar.Indeterminate = 'off';
% Main loop for all events
for i1 = 1:size(DmCumPar,1)

    %% Creation of table with all point to pass through model
    RowFromLast = StabilityAnalysis{1}-i1;
    RainEndEvent = size(RainInterpolated,1)-RowFromLast;

    CumRainStudyArea = cell(1,size(RainInterpolated,2));
    for i2 = 1:size(RainInterpolated,2)
        CumRainStudyArea{i2} = full(sum([RainInterpolated{RainEndEvent-23:RainEndEvent,i2}],2));
    end
    
    AnalysisTable(:,end) = DmCumPar(end-RowFromLast,:)';
    
    %% Cleaning procedure
    if any(cellfun(@any, AnalysisTableIndex999), 'all')
        for i2 = 1:size(AnalysisTable,1)
            AnalysisTable{i2,end}(AnalysisTableIndex999{i2,3}) = NaN;
        end
    end

    if any(cellfun(@any, AnalysisTableIndexNan), 'all')
        for i2 = 1:size(AnalysisTable,1)
            for i3 = 1:size(AnalysisTable,2)
                AnalysisTable{i2,i3}(AnalysisTableIndexNan{i2,3}) = Maximum(i3);
            end
        end
    end
    
    %% Prediction of all points in study area
    AnalysisTableNorm(:,end) = cellfun(@(x) (x-Minimum(10))./(Maximum(10)-Minimum(10)), ...
                                                        AnalysisTable(:,10), ...
                                                        'UniformOutput',false); % Remember to modify if you add some parameters
    NanIntoAnTblNorm = cellfun(@isnan, AnalysisTableNorm, 'UniformOutput', false);
    for i2 = 1:size(AnalysisTableNorm,1)*size(AnalysisTableNorm,2)
        AnalysisTableNorm{i2}(NanIntoAnTblNorm{i2}) = 0; % To remove value consistant that normalized give NaNs
    end

    AnalysisTableStudyArea = cell(1,size(AnalysisTableNorm,1));
    for i2 = 1:size(AnalysisTableNorm,1)
        AnalysisTableStudyArea{i2} = array2table([AnalysisTableNorm{i2,:}]);
        AnalysisTableStudyArea{i2}.Properties.VariableNames = ConditioningFactorsNames;
    end
    
    [FsAnalysisPrediction, FsAnalysisScores, FsAnalysisCost] = deal(cell(1,size(AnalysisTableStudyArea,2)));
    for i2 = 1:size(AnalysisTableStudyArea,2)
        [FsAnalysisPrediction{i2}, FsAnalysisScores{i2}] = predict(Model,AnalysisTableStudyArea{i2});
        if LearnMethod == "Random Forest"; [~, ~, FsAnalysisCost{i2}] = predict(Model,AnalysisTableStudyArea{i2}); end
        if any(strcmp(LearnMethod, ["Adaptive Boosting", "Logit Boost", "Total Boost", "Gentle Boost"]))
            FsAnalysisScores{i2} = exp(FsAnalysisScores{i2})./(exp(FsAnalysisScores{i2})+1); % from log(odds) to probability
            if LearnMethod == "Total Boost"
                FsAnalysisScores{i2} = rescale(FsAnalysisScores{i2});
            end
        end
    
        ProgressBar.Value = ((i1-1)*size(AnalysisTable,1)+i2)/Steps;
        ProgressBar.Message = strcat("Prediction n. ", string(i1)," of ", string(size(DmCumPar,1)));
        drawnow
    end
    
    if LearnMethod == "Random Forest"
        FsAnalysisPrediction = cellfun(@(x) str2num(cell2mat(x)), FsAnalysisPrediction, 'UniformOutput',false); % Remember to modify if you don't classify
    end
    
    if any(cellfun(@any, AnalysisTableIndex999), 'all')
        for i2 = 1:length(FsAnalysisPrediction)
            FsAnalysisPrediction{i2}(FactorSafetyIndexNotGood{i2}) = 0;
            FsAnalysisScores{i2}(FactorSafetyIndexNotGood{i2},1) = 1;
            FsAnalysisScores{i2}(FactorSafetyIndexNotGood{i2},2) = 0;
        end
    end
    
    FactorSafetyMachineLearning = [FsAnalysisPrediction; FsAnalysisScores];
    
    %% Saving
    save(strcat('FsML',num2str(i1),'.mat'),'FactorSafetyMachineLearning')

end
close(ProgressBar) % ProgressBar instead of Fig if on the app version
cd(fold0)