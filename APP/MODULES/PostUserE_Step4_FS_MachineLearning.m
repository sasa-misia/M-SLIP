%% Machine Learning application
cd(fold_var)
load('InfoDetectedSoilSlips.mat')
load('RainInterpolated.mat')
load('GridCoordinates.mat')
load('MorphologyParameters.mat')
load('SoilParameters.mat')
load('VegetationParameters.mat')
load('DmCum.mat')
load('UserE_Answers.mat')

cd(fold_res_fs)
fold_res_fs_an = uigetdir('open');

cd(fold_res_fs_an)
load('AnalysisInformation.mat');
EventsAnalysed = string(StabilityAnalysis{:,2});
Choice = listdlg('PromptString',{'Select event analysed to plot:',''}, 'ListString',EventsAnalysed);
EventFS = datetime(EventsAnalysed(Choice), 'InputFormat','dd/MM/yyyy HH:mm:ss');
FSLoadIndex = hours(EventFS-StabilityAnalysis{2}(1))+1;
RowFromLast = hours(StabilityAnalysis{2}(end)-EventFS);
EndEvent = size(RainInterpolated,1)-RowFromLast;
load(strcat('Fs',num2str(FSLoadIndex),'.mat'));
cd(fold0)

%% Calculating DmCum
BetaStarStudyArea = cellfun(@(x,y) x(y), BetaStarAll, ...
                                         IndexDTMPointsInsideStudyArea, ...
                                         'UniformOutput',false);

nStudyArea = cellfun(@(x,y) x(y), nAll, ...
                                  IndexDTMPointsInsideStudyArea, ...
                                  'UniformOutput',false);

DmCum = cellfun(@(x,y,z) min(x.*y./(z.*H.*(1-Sr0)), 1), DmCumPar, ...
                                                        repmat(BetaStarStudyArea, 24, 1), ...
                                                        repmat(nStudyArea, 24, 1), ...
                                                        'UniformOutput',false);

%% Calculate cumulate rainfall
rng(1) % For reproducibility
FSForInstability = 1.2;
FSForStability = 6;
RatioNegToPos = 2;
ConditioningFactors = 11;
PositiveSamples = size(InfoDetectedSoilSlips,1);
ResamplePositive = false;
TrainingSamples = uint64((1+RatioNegToPos)*PositiveSamples);
NegativeSamples = TrainingSamples-PositiveSamples;
ResampleNegative = true;

TrainingCell = cell(TrainingSamples,ConditioningFactors); % Initializing cells and arrays
RealFS = zeros(TrainingSamples,1);
TrainingDTMPoints = zeros(TrainingSamples,3);

if ~ResamplePositive
    for i1 = 1:size(InfoDetectedSoilSlips,1)
        DTMi = InfoDetectedSoilSlips{i1,3};
        Indexi = InfoDetectedSoilSlips{i1,4};
        IndexAlli = IndexDTMPointsInsideStudyArea{DTMi}(Indexi);
        TrainingCell(i1,:) = [InfoDetectedSoilSlips(i1,[8, 9, 11:15, 17, 18]), {sum(cellfun(@(x) full(x(Indexi)), ...
                              RainInterpolated(EndEvent-23:EndEvent,DTMi)))}, {DmCum{end-RowFromLast, DTMi}(Indexi)}];
        TrainingDTMPoints(i1,:) = [DTMi, Indexi, IndexAlli];
        RealFS(i1) = FactorSafety{DTMi}(Indexi);
    end
else
    i1 = 1;
    while i1 <= PositiveSamples
        DTMi = max(uint64(rand*length(IndexDTMPointsInsideStudyArea)),1);
        Indexi = max(uint64(rand*length(IndexDTMPointsInsideStudyArea{DTMi})),1);
        IndexAlli = IndexDTMPointsInsideStudyArea{DTMi}(Indexi);
        if FactorSafety{DTMi}(Indexi) < FSForInstability && CohesionAll{DTMi}(IndexAlli) ~= 999
            TrainingCell(i1,:) = {SlopeAll{DTMi}(IndexAlli), AspectAngleAll{DTMi}(IndexAlli), ...
                                  CohesionAll{DTMi}(IndexAlli), PhiAll{DTMi}(IndexAlli), ...
                                  KtAll{DTMi}(IndexAlli), AAll{DTMi}(IndexAlli), nAll{DTMi}(IndexAlli), ...
                                  BetaStarAll{DTMi}(IndexAlli), RootCohesionAll{DTMi}(IndexAlli), ...
                                  sum(cellfun(@(x) full(x(Indexi)), RainInterpolated(EndEvent-23:EndEvent,DTMi))), ...
                                  DmCum{end-RowFromLast, DTMi}(Indexi)};
            TrainingDTMPoints(i1,:) = [DTMi, Indexi, IndexAlli];
            RealFS(i1) = FactorSafety{DTMi}(Indexi);
            i1 = i1+1;
        end
    end
end

i2 = PositiveSamples+1;
while i2 <= TrainingSamples
    DTMi = max(uint64(rand*length(IndexDTMPointsInsideStudyArea)),1);
    Indexi = max(uint64(rand*length(IndexDTMPointsInsideStudyArea{DTMi})),1);
    IndexAlli = IndexDTMPointsInsideStudyArea{DTMi}(Indexi);
    if FactorSafety{DTMi}(Indexi) > FSForStability && CohesionAll{DTMi}(Indexi) ~= 999
        TrainingCell(i2,:) = {SlopeAll{DTMi}(IndexAlli), AspectAngleAll{DTMi}(IndexAlli), ...
                              CohesionAll{DTMi}(IndexAlli), PhiAll{DTMi}(IndexAlli), ...
                              KtAll{DTMi}(IndexAlli), AAll{DTMi}(IndexAlli), nAll{DTMi}(IndexAlli), ...
                              BetaStarAll{DTMi}(IndexAlli), RootCohesionAll{DTMi}(IndexAlli), ...
                              sum(cellfun(@(x) full(x(Indexi)), RainInterpolated(EndEvent-23:EndEvent,DTMi))), ...
                              DmCum{end-RowFromLast, DTMi}(Indexi)};
        TrainingDTMPoints(i2,:) = [DTMi, Indexi, IndexAlli];
        RealFS(i2) = FactorSafety{DTMi}(Indexi);
        i2 = i2+1;
    end
end

TrainingFs = [true(PositiveSamples,1); false(NegativeSamples,1)];

TrainingTable = cell2table(TrainingCell); % Not array2table because in that way they remain cells

ConditioningFactorsNames = {'Slope (°)', 'Aspect (°)', 'c''(kPa)', 'phi (°)', 'kt(1/h)', ...
                            'A (kPa)', 'n (-)', 'beta* (-)', 'cr (kPa)', 'cum rain (mm)', 'cum m (-)'};

TrainingTable.Properties.VariableNames = ConditioningFactorsNames;

% TrainingTable = removevars(TrainingTable, 'Aspect (°)');
% ConditioningFactorsNames(2) = [];

%% Creation of table with all point to pass through model
CumRainStudyArea = cell(1,size(RainInterpolated,2));
for i1 = 1:size(RainInterpolated,2)
    CumRainStudyArea{i1} = full(sum([RainInterpolated{EndEvent-23:EndEvent,i1}],2));
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
                 CumRainStudyArea
                 DmCum]';

AnalysisTableIndex999 = cellfun(@(x) x==999, AnalysisTable, 'UniformOutput',false);

if any(cellfun(@any, AnalysisTableIndex999), 'all')
    for i1 = 1:size(AnalysisTable,1)*size(AnalysisTable,2)
        AnalysisTable{i1}(AnalysisTableIndex999{i1}) = NaN;
    end

    FactorSafetyIndex999 = AnalysisTableIndex999(:,3)';
    FactorSafetyIndexTooBig = cellfun(@(x) x>80, FactorSafety, 'UniformOutput',false);
    FactorSafetyIndexNotGood = cellfun(@(x,y) x|y, FactorSafetyIndex999, FactorSafetyIndexTooBig, 'UniformOutput',false);
    for i1 = 1:length(FactorSafety)
        FactorSafety{i1}(FactorSafetyIndexNotGood{i1}) = NaN;
    end
end

%% Normalizaion of table for training
Minimum = min(cellfun(@min, AnalysisTable), [], 1);
Maximum = max(cellfun(@max, AnalysisTable), [], 1);
MinFS = min(cellfun(@min, FactorSafety));
MaxFS = max(cellfun(@max, FactorSafety));

AnalysisTableNorm = [cellfun(@(x) (x-Minimum(1))./(Maximum(1)-Minimum(1)), AnalysisTable(:,1), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(2))./(Maximum(2)-Minimum(2)), AnalysisTable(:,2), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(3))./(Maximum(3)-Minimum(3)), AnalysisTable(:,3), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(4))./(Maximum(4)-Minimum(4)), AnalysisTable(:,4), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(5))./(Maximum(5)-Minimum(5)), AnalysisTable(:,5), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(6))./(Maximum(6)-Minimum(6)), AnalysisTable(:,6), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(7))./(Maximum(7)-Minimum(7)), AnalysisTable(:,7), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(8))./(Maximum(8)-Minimum(8)), AnalysisTable(:,8), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(9))./(Maximum(9)-Minimum(9)), AnalysisTable(:,9), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(10))./(Maximum(10)-Minimum(10)), AnalysisTable(:,10), 'UniformOutput',false), ...
                     cellfun(@(x) (x-Minimum(11))./(Maximum(11)-Minimum(11)), AnalysisTable(:,11), 'UniformOutput',false)];

TrainingCellNorm = num2cell((cell2mat(TrainingCell)-Minimum)./(Maximum-Minimum));

TrainingTableNorm = cell2table(TrainingCellNorm);
TrainingTableNorm.Properties.VariableNames = ConditioningFactorsNames;

FactorSafetyNorm = cellfun(@(x) (x-MinFS)./(MaxFS-MinFS), FactorSafety, 'UniformOutput',false);

RealFSNorm = (RealFS-MinFS)./(MaxFS-MinFS);

%% Machine \ Deep Learning
LearningOptions = {'Artificial Neural Network', 'Random Forest', 'Bag', ...
                   'Adaptive Boosting', 'Adaptive logistic regression', ...
                   'Totally corrective boosting', 'Auto Machine Learning', 'Auto ANN'};
Choice = listdlg('PromptString', {'Choose the algoritm:', ''}, 'ListString', ...
                 LearningOptions, 'SelectionMode', 'single');
LearnChoice = string(LearningOptions{Choice});

switch LearnChoice
    case "Artificial Neural Network"
        Model = fitcnet(TrainingTableNorm, TrainingFs);

    case "Random Forest"
        Model = TreeBagger(50, TrainingTableNorm, TrainingFs);

    case "Bag"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'Method','Bag', ...
                             'Learners',templateTree('Reproducible', true), ...
                             'Resample','on', 'NumLearningCycles',50);

    case "Adaptive Boosting"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'Method','AdaBoostM1', ...
                             'Learners',templateTree('Reproducible', true), ...
                             'LearnRate',0.1, 'NumLearningCycles',50);

    case "Adaptive logistic regression"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'Method','LogitBoost', ...
                             'Learners',templateTree('Reproducible', true), ...
                             'LearnRate',0.1, 'NumLearningCycles',50);

    case "Totally corrective boosting"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'Method','LogitBoost', ...
                             'Learners',templateTree('Reproducible', true), ...
                             'MarginPrecision',0.4, 'NumLearningCycles',50);

    case "Auto Machine Learning"
        Model = fitcensemble(TrainingTableNorm, TrainingFs, 'OptimizeHyperparameters','auto');

    case "Auto ANN"
        Model = fitcnet(TrainingTableNorm,TrainingFs,'OptimizeHyperparameters','auto');
end

[FsTrainingPrediction, FsTrainingScores] = predict(Model,TrainingTableNorm);
if LearnChoice == "Random Forest"; [~, ~, FsTrainingCost] = predict(Model,TrainingTableNorm); end

%% Prediction of all points in study area
AnalysisTableStudyArea = cell(1,size(AnalysisTableNorm,1));
for i1 = 1:size(AnalysisTableNorm,1)
    AnalysisTableStudyArea{i1} = array2table([AnalysisTableNorm{i1,:}]);
    AnalysisTableStudyArea{i1}.Properties.VariableNames = ConditioningFactorsNames;
end

% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Initializing');
drawnow
Steps = size(AnalysisTableStudyArea,2);
[FsAnalysisPrediction, FsAnalysisScores, FsAnalysisCost] = deal(cell(1,size(AnalysisTableStudyArea,2)));
for i1 = 1:size(AnalysisTableStudyArea,2)
    [FsAnalysisPrediction{i1}, FsAnalysisScores{i1}] = predict(Model,AnalysisTableStudyArea{i1});
    if LearnChoice == "Random Forest"; [~, ~, FsAnalysisCost{i1}] = predict(Model,AnalysisTableStudyArea{i1}); end

    ProgressBar.Value = i1/Steps;
    ProgressBar.Message = strcat("Prediction n. ", string(i1)," of ", string(Steps));
    drawnow
end
close(ProgressBar) % ProgressBar instead of Fig if on the app version

if LearnChoice == "Random Forest"
    FsAnalysisPrediction = cellfun(@(x) str2num(cell2mat(x)), FsAnalysisPrediction, 'UniformOutput',false); % Remember to modify if you don't classify
end

if any(cellfun(@any, AnalysisTableIndex999), 'all')
    for i1 = 1:length(FsAnalysisPrediction)
        FsAnalysisPrediction{i1}(FactorSafetyIndexNotGood{i1}) = 0;
        FsAnalysisScores{i1}(FactorSafetyIndexNotGood{i1},1) = 1;
        FsAnalysisScores{i1}(FactorSafetyIndexNotGood{i1},2) = 0;
    end
end

FactorSafetyMachineLearning = [FsAnalysisPrediction; FsAnalysisScores];

StabilityAnalysis{4} = ["Machine Learning", LearnChoice];

%% Saving
cd(fold_res_fs)
EventFS.Format = 'dd-MM-yyyy-HH-mm';
FsFolderName = string(inputdlg({'Choose analysis folder name (inside Results->Factors of Safety):'}, ...
                                '',1,strcat('MachineLearning','-Event-',string(EventFS))));

if exist(FsFolderName,'dir')
    Answer = questdlg(strcat(FsFolderName," is an existing folder. " + ...
                      "Do you want to overwrite it?"), 'Existing Folder', ...
                	  'Yes, thanks.','No, for God!','No, for God!');
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

cd(strcat(fold_res_fs,sl,FsFolderName))
save(strcat('FsML',num2str(FSLoadIndex),'.mat'),'FactorSafetyMachineLearning')
save('AnalysisInformation.mat','StabilityAnalysis');
cd(fold0)