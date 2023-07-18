% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

rng(10) % For reproducibility of the model

%% Loading data, extraction and initialization of variables
load([fold_var,sl,'DatasetML.mat'],    'DatasetMLInfo','DatasetMLCoords','DatasetMLFeats', ...
                                       'DatasetMLClasses','DatasetMLDates','RangesForNorm')
load([fold_var,sl,'DatasetStudy.mat'], 'UnstablePolygons','IndecisionPolygons','StablePolygons')

TimeSensMode  = 'NoTimeSens';
TimeSensExist = any(strcmp('TimeSensitive', DatasetMLInfo{1,'FeaturesTypes'}{:}));
if TimeSensExist
    EventDates   = DatasetMLInfo.EventDate;
    TimeSensMode = DatasetMLInfo{1,'TimeSensitiveMode'};
    TSParameters = DatasetMLInfo{1,'TSParameters'}{:};
    DaysForTS    = DatasetMLInfo{1,'DaysForTS'};
    if DatasetMLInfo{1,'MultipleDayAnalysis'}
        DaysBeforeEventWhenStable = DatasetMLInfo{1,'DayBeforeEventForStablePoints'};
    end
end

ExpectedOutputs = double(DatasetMLClasses.ExpectedOutput);
FeaturesNames   = DatasetMLInfo{1,'FeaturesNames'}{:};
FeaturesNotTS   = not(strcmp('TimeSensitive', DatasetMLInfo{1,'FeaturesTypes'}{:}));
ResampleMode    = DatasetMLInfo.ResampleModeDatasetML;

ModelInfo = table("ANN FF FC", 'VariableNames',{'Type'});

%% ANN Options
ProgressBar.Message = "ANN options...";

if strcmp(ResampleMode, 'Oversampling') % You should fix also random split because if you have just one polygon it will not work!
    TestMode = 'PolySplit';
else
    Options  = {'RandomSplit', 'PolySplit'};
    TestMode = uiconfirm(Fig, 'How do you want to define test dataset?', ...
                              'Test dataset', 'Options',Options, 'DefaultOption',1);
end

switch TestMode
    case 'RandomSplit'
        TrainPerc = str2double(inputdlg("Specify the percentage to be used for training (0 - 1) : ", '', 1, {'0.8'}));
        if TrainPerc <= 0 || TrainPerc >= 1
            error('You have to specify a number between 0 and 1! (extremes not included)')
        end

    case 'PolySplit'
        if (numel(UnstablePolygons) == 1) || (numel(UnstablePolygons) ~= numel(StablePolygons))
            error(['You can not apply this approach with your polygons ' ...
                   '(they should be multi-polys and same numbers between Stables and Unstables)!'])
        end
        IndsTestPolys = listdlg('PromptString',{'Choose polygons to use for test dataset: ',''}, ...
                                'ListString',string(1:numel(UnstablePolygons)), 'SelectionMode','multiple');
        IndsLogicTestPolys = false(1, numel(UnstablePolygons));
        IndsLogicTestPolys(IndsTestPolys) = true;

        figure(Fig)
        drawnow

        TestPoly  = union([UnstablePolygons(IndsLogicTestPolys) ; StablePolygons(IndsLogicTestPolys)] );
        TrainPoly = union([UnstablePolygons(~IndsLogicTestPolys); StablePolygons(~IndsLogicTestPolys)]);
end

switch TimeSensMode
    case 'SeparateDays'
        Options = {'With Validation Data', 'With Loss Function', 'Auto [slow]'};
        FeaturesNamesTS = cellfun(@(x) strcat(x,'-',string(1:DaysForTS)','daysBefore'), TSParameters, 'UniformOutput',false); % Remember to change this line if you change feats names in datasetstudy_creation function!

    case {'CondensedDays', 'TriggerCausePeak', 'NoTimeSens'}
        Options = {'With Validation Data', 'With Loss Function', 'Cross Validation (K-Fold) [slow]', 'Cross Validation (Polygons)'};
end

ANNMode = uiconfirm(Fig, 'How do you want to train your neural network?', ...
                         'Neural network choice', 'Options',Options, 'DefaultOption',1);

if not(strcmp(ANNMode, 'Auto'))
    Options = {'sigmoid', 'relu', 'tanh', 'none'};
    LayerActivation = uiconfirm(Fig, 'What activation function do you want to use?', ...
                                     'Activation function', 'Options',Options, 'DefaultOption',1);
    
    Options = {'Yes', 'No'};
    StandardizeAns = uiconfirm(Fig, 'Do you want to standardize inputs?', ...
                                    'Standardize', 'Options',Options, 'DefaultOption',1);
    if strcmp(StandardizeAns,'Yes'); Standardize = true; else; Standardize = false; end
    
    StructureInput = inputdlg(["Max number of hiddens: "
                               "Max number of nuerons in each hidden: "
                               "Increase of neurons for each model: "], '', 1, ...
                              {'6', '[100, 200, 100, 50, 20, 10]', '10'});
    
    MaxNumOfHiddens   = str2double(StructureInput{1});
    MaxNumOfNeurons   = str2num(StructureInput{2});
    NeurToAddEachStep = str2double(StructureInput{3});
    
    if MaxNumOfHiddens > numel(MaxNumOfNeurons)
        error('You have to select the max number of neurons for each hidden layers (Format: [NumNeuronsHid1, NumNeuronsHid2, ...])')
    end

    % Creation of permutations for possible structures
    [NumOfNeuronToTrainEachHidden, ModelNeurCombs] = deal(cell(1, MaxNumOfHiddens));
    for i1 = 1:MaxNumOfHiddens
        NumOfNeuronToTrainEachHidden{i1} = [1, NeurToAddEachStep:NeurToAddEachStep:MaxNumOfNeurons(i1)];
        if NeurToAddEachStep == 1; NumOfNeuronToTrainEachHidden{i1}(1) = []; end
        ModelNeurCombs{i1} = combvec(NumOfNeuronToTrainEachHidden{1:i1});
    end

    NumOfCombs = sum(cellfun(@(x) size(x, 2), ModelNeurCombs));
    LayerSize  = cell(1, NumOfCombs);
    i3 = 1;
    for i1 = 1:MaxNumOfHiddens
        for i2 = 1:size(ModelNeurCombs{i1}, 2)
            LayerSize{i3} = ModelNeurCombs{i1}(:,i2)';
            i3 = i3+1;
        end
    end
end

Options = {'MATLAB', 'MaximizeRatio-TPR-FPR', 'MaximizeArea-TPR-TNR'};
MethodBestThreshold = uiconfirm(Fig, 'How do you want to find the optimal threshold for ROC curves?', ...
                                     'Optimal ratio ROC', 'Options',Options, 'DefaultOption',1);

PlotCheckAns = uiconfirm(Fig, 'Do you want to plot a check figure?', ...
                              'Check plot', 'Options',{'Yes', 'No'}, 'DefaultOption',2);
if strcmp(PlotCheckAns,'Yes'); PlotCheck = true; else; PlotCheck = false; end

%% Adding vars to ModelInfo
ModelInfo.ANNMode      = ANNMode;
ModelInfo.TestMode     = TestMode;
if strcmp(TestMode,'RandomSplit')
    ModelInfo.TrainPerc = TrainPerc;
    ModelInfo.TestPerc  = 1-TrainPerc;
elseif strcmp(TestMode,'PolySplit')
    ModelInfo.TrainPoly = TrainPoly;
    ModelInfo.TestPoly  = TestPoly;
else
    error('Test mode not recognized!')
end
ModelInfo.TimeSensMode = TimeSensMode;
if not(strcmp(ANNMode, 'Auto'))
    ModelInfo.ActivationFunUsed = LayerActivation;
    ModelInfo.StandardizedInput = Standardize;
    ModelInfo.ANNsStructures    = array2table(ModelNeurCombs, 'VariableNames',strcat(string(1:length(ModelNeurCombs)),"Layers"));
end
ModelInfo.MethodForOptThreshold = MethodBestThreshold;
ModelInfo.RangesForNorm         = {RangesForNorm};

%% Partitioning of dataset for ML
rng(7) % For reproducibility of the model
switch TestMode
    case 'RandomSplit'
        PartitionTrain   = cvpartition(ExpectedOutputs, 'Holdout',(1-TrainPerc));

        IndsTrainLogical = training(PartitionTrain); % Indices for the training set
        IndsTestLogical  = test(PartitionTrain); % Indices for the test set

    case 'PolySplit'        
        [pp1, ee1] = getnan2([TrainPoly.Vertices; nan, nan]);
        IndsTrainLogical = inpoly([DatasetMLCoords.Longitude,DatasetMLCoords.Latitude], pp1,ee1);

        [pp2, ee2] = getnan2([TestPoly.Vertices; nan, nan]);
        IndsTestLogical  = inpoly([DatasetMLCoords.Longitude,DatasetMLCoords.Latitude], pp2,ee2);

    otherwise
        error('Test mode not recognized!')
end

IndsTrainNumeric = find(IndsTrainLogical);
IndsTestNumeric  = find(IndsTestLogical);

ExpectedOutputsTrain = ExpectedOutputs(IndsTrainLogical);
ExpectedOutputsTest  = ExpectedOutputs(IndsTestLogical);

DatasetMLFeatsTrain = DatasetMLFeats(IndsTrainLogical,:);
DatasetMLFeatsTest  = DatasetMLFeats(IndsTestLogical,:);

%% Adding vars to ModelInfo
ModelInfo.DatasetInfo        = {DatasetMLInfo};
ModelInfo.DatasetFeatsTrain  = {DatasetMLFeatsTrain};
ModelInfo.DatasetFeatsTest   = {DatasetMLFeatsTest};
ModelInfo.DatasetCoordsTrain = {DatasetMLCoords(IndsTrainLogical,:)};
ModelInfo.DatasetCoordsTest  = {DatasetMLCoords(IndsTestLogical,:)};
ModelInfo.ExpextedOutsTrain  = {ExpectedOutputsTrain};
ModelInfo.ExpextedOutsTest   = {ExpectedOutputsTest};
ModelInfo.DatasetDatesTrain  = {DatasetMLDates(IndsTrainLogical,:)};
ModelInfo.DatasetDatesTest   = {DatasetMLDates(IndsTestLogical,:)};

%% Initialization of variables for loops
ANNsRows = {'Model', 'FeatsConsidered', 'Structure'}; % If you touch these, please modify row below when you write ANNs
ANNs     = table('RowNames',ANNsRows);

ANNsResRows = {'ProbsTrain', 'ProbsTest'}; % If you touch these, please modify row below when you write ANNsRes
ANNsRes     = table('RowNames',ANNsResRows);

if strcmp(ANNMode, 'Cross Validation (Polygons)')
    ANNsCrossRows = {'Models', 'MSE', 'AUC', 'BestModel', 'Convergence', 'ProbsTest'}; % If you touch these, please modify row below when you write ANNsCross
    ANNsCross     = table('RowNames',ANNsCrossRows);

    DatasetsCrossRows = {'Polygons', 'DatasetCrossFeatsTest', 'DatasetCrossFeatsTrain', ...
                         'DatasetCrossCoordsTest', 'DatasetCrossCoordsTrain', ...
                         'ExpOutsCrossTest', 'ExpOutsCrossTrain'}; % If you touch these, please modify row below when you write DatasetsCross
    DatasetsCross     = table('RowNames',DatasetsCrossRows);

    if (numel(UnstablePolygons) <= 1) || (numel(UnstablePolygons) ~= numel(StablePolygons))
        error(['You can not use Cross Validation with Polygons if you have only 1 ' ...
               'polygon or if num of Stable and Unstable polys do not match!'])
    elseif (numel(UnstablePolygons) < 10) && (numel(UnstablePolygons) > 1)
        IndsPolyCross = num2cell(1:numel(UnstablePolygons));
    elseif numel(UnstablePolygons) >= 10
        [StartInd, EndInd] = deal(0);
        CrossParts = 10;
        PolyXCross = int64(numel(UnstablePolygons)/CrossParts);
        IndsCross  = {};
        while EndInd < numel(UnstablePolygons)
            StartInd  = StartInd + 1;
            EndInd    = min(StartInd + PolyXCross - 1, numel(UnstablePolygons));
            IndsCross = [IndsCross, {StartInd : EndInd}];
            StartInd  = EndInd;
        end
    end

    [CrossPoly, DatasetsCrossCoordsTest, DatasetsCrossFeatsTest, ExpOutsCrossTest] = deal(cell(1, numel(IndsCross)));
    for i1 = 1:numel(IndsCross)
        CrossPoly{i1} = union([UnstablePolygons(IndsCross{i1}); StablePolygons(IndsCross{i1})]);

        [pp3, ee3] = getnan2([CrossPoly{i1}.Vertices; nan, nan]);
        IndsCrossLogical = inpoly([DatasetMLCoords.Longitude,DatasetMLCoords.Latitude], pp3,ee3);

        DatasetsCrossCoordsTest{i1} = DatasetMLCoords(IndsCrossLogical,:);
        DatasetsCrossFeatsTest{i1}  = DatasetMLFeats(IndsCrossLogical,:);
        ExpOutsCrossTest{i1}        = ExpectedOutputs(IndsCrossLogical);
    end

    [DatasetsCrossCoordsTrain, DatasetsCrossFeatsTrain, ExpOutsCrossTrain] = deal(cell(1, numel(IndsCross))); % You have to do in this way because not(IndsCrossLogical) is not correct!
    for i1 = 1:numel(IndsCross)
        DatasetCoordsTemp = DatasetsCrossCoordsTest;
        DatasetFeatsTemp  = DatasetsCrossFeatsTest;
        ExpOutTemp        = ExpOutsCrossTest;

        DatasetCoordsTemp(i1) = [];
        DatasetFeatsTemp(i1)  = [];
        ExpOutTemp(i1)        = [];

        DatasetsCrossCoordsTrain{i1} = cat(1, DatasetCoordsTemp{:});
        DatasetsCrossFeatsTrain{i1}  = cat(1, DatasetFeatsTemp{:});
        ExpOutsCrossTrain{i1}        = cat(1, ExpOutTemp{:});
    end

    DatasetsCross{DatasetsCrossRows, 1:numel(IndsCross)} = [CrossPoly; DatasetsCrossFeatsTest; DatasetsCrossFeatsTrain; ...
                                                            DatasetsCrossCoordsTest; DatasetsCrossCoordsTrain; ...
                                                            ExpOutsCrossTest; ExpOutsCrossTrain]; % Pay attention to the order!
end

%% Loop for ANN models
ProgressBar.Indeterminate = 'off';
switch TimeSensMode
    case 'SeparateDays'
        %% Separate Days
        NumberOfANNs = DaysForTS*length(LayerSize); % DaysForTS because you repeat the same structure n times as are the number of days 
                                                    % that I can consider independently.
        [TrainLoss, TrainMSE, TestLoss, TestMSE] = deal(zeros(1,NumberOfANNs));
        i3 = 0;
        for i1 = 1:length(LayerSize)
            for i2 = 1:DaysForTS
                i3 = i3 + 1;
                ProgressBar.Value = i3/NumberOfANNs;
                ProgressBar.Message = strcat("Training model n. ", string(i3)," of ", string(NumberOfANNs));

                TSFeatsToTake = cellfun(@(x) x(1:i2)', FeaturesNamesTS, 'UniformOutput',false);
                TSFeatsToTake = cellstr(cat(2, TSFeatsToTake{:}));

                FeatsConsidered = [FeaturesNames(FeaturesNotTS), TSFeatsToTake];
                 
                DatasetTrain = DatasetMLFeatsTrain(:,FeatsConsidered);
                DatasetTest  = DatasetMLFeatsTest(:,FeatsConsidered);
                
                switch ANNMode
                    case 'With Validation Data'
                        Model = fitcnet(DatasetTrain, ExpectedOutputsTrain, 'ValidationData',{DatasetTest, ExpectedOutputsTest}, ...
                                                                   'ValidationFrequency',5, 'ValidationPatience',35, ...
                                                                   'LayerSizes',LayerSize{i1}, 'Activations',LayerActivation, ...
                                                                   'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',8e3);
    
                        FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                        if FailedConvergence
                            warning(strcat("ATTENTION! Model n. ", string(i3), " failed to converge! Please analyze it."))
                        end
    
                    case 'Auto'
                        Model = fitcnet(DatasetTrain, ExpectedOutputsTrain, 'OptimizeHyperparameters','all', ...
                                                                   'MaxObjectiveEvaluations',20);

                    case 'With Loss Function'
                        Model = fitcnet(DatasetTrain, ExpectedOutputsTrain, 'LayerSizes',LayerSize{i1}, 'Activations',LayerActivation, ...
                                                                   'Standardize',Standardize, 'Lambda',1.2441e-09);
                end
    
                FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                if FailedConvergence
                    warning(strcat("ATTENTION! Model n. ", string(i3), " failed to converge! Please analyze it."))
                end
                
                [PredClassTrain, PredProbsTrain] = predict(Model, DatasetTrain);
                [PredClassTest,  PredProbsTest]  = predict(Model, DatasetTest);

                PredProbsTrain = PredProbsTrain(:,2);
                PredProbsTest  = PredProbsTest(:,2);
            
                TrainLoss(i3) = loss(Model, DatasetTrain, ExpectedOutputsTrain);
                TrainMSE(i3)  = mse(ExpectedOutputsTrain, PredProbsTrain);
                TestLoss(i3)  = loss(Model, DatasetTest, ExpectedOutputsTest);
                TestMSE(i3)   = mse(ExpectedOutputsTest, PredProbsTest);
            
                ANNs{ANNsRows, i3} = {Model; FeatsConsidered; LayerSize{i1}}; % Pay attention to the order!
                ANNsRes{ANNsResRows, i3} = {PredProbsTrain; PredProbsTest}; % Pay attention to the order!
            end
        end

        if (i3) ~= NumberOfANNs
            error('Not all possible models were trained. Check the script!')
        end

    case {'CondensedDays', 'TriggerCausePeak', 'NoTimeSens'}
        %% Condensed Days
        NumberOfANNs = length(LayerSize);
        [TrainLoss, TrainMSE, TestLoss, TestMSE] = deal(zeros(1,NumberOfANNs));
        for i1 = 1:NumberOfANNs
            ProgressBar.Value = i1/NumberOfANNs;
            ProgressBar.Message = strcat("Training model n. ", string(i1)," of ", string(NumberOfANNs));
             
            DatasetTrain = DatasetMLFeatsTrain;
            DatasetTest  = DatasetMLFeatsTest;

            switch ANNMode
                case 'With Validation Data'
                    Model = fitcnet(DatasetTrain, ExpectedOutputsTrain, 'ValidationData',{DatasetTest, ExpectedOutputsTest}, ...
                                                               'ValidationFrequency',5, 'ValidationPatience',35, ...
                                                               'LayerSizes',LayerSize{i1}, 'Activations',LayerActivation, ...
                                                               'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',8e3);

                    FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                    if FailedConvergence
                        warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
                    end

                case 'Cross Validation (K-Fold) [slow]'
                    ModelCV = fitcnet(DatasetTrain, ExpectedOutputsTrain, ...
                                                'LayerSizes',LayerSize{i1}, 'Activations',LayerActivation, ...
                                                'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',8e3, ...
                                                'LossTolerance',1e-6, 'StepTolerance',1e-6, ...
                                                'Crossval','on', 'KFold',10); % Remember that instead of 'KFold' you can use for example: 'Holdout',0.1

                    % [PredictionOfModelCV, ProbabilitiesOfModelCV] = kfoldPredict(ModelCV); % To have the predictions of the cross validated model
                    % ConfusionTrain = confusionchart(ExpectedOutputsTrain, PredictionOfModelCV); % To see visually how well the cross validated model predict

                    LossesOfModels = kfoldLoss(ModelCV, 'Mode','individual');
                    [~, IndBestModel] = min(LossesOfModels);
                    Model = ModelCV.Trained{IndBestModel};

                case 'With Loss Function'
                    Model = fitcnet(DatasetTrain, ExpectedOutputsTrain, 'LayerSizes',LayerSize{i1}, 'Activations',LayerActivation, ...
                                                               'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',8e3, ...
                                                               'LossTolerance',1e-5, 'StepTolerance',1e-6);

                    FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                    if FailedConvergence
                        warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
                    end
                
                case 'Cross Validation (Polygons)'
                    [ModelsCross, ProbsTest] = deal(cell(1, numel(DatasetsCrossFeatsTest)));
                    FailedConv = false(1, numel(DatasetsCrossFeatsTest));
                    [CrossMSE, CrossAUC] = deal(zeros(1, numel(DatasetsCrossFeatsTest)));
                    for i2 = 1:numel(DatasetsCrossFeatsTest)
                        ModelsCross{i2} = fitcnet(DatasetsCrossFeatsTrain{i2}, ExpOutsCrossTrain{i2}, ...
                                                                   'ValidationData',{DatasetsCrossFeatsTest{i2}, ExpOutsCrossTest{i2}}, ...
                                                                   'ValidationFrequency',5, 'ValidationPatience',35, ...
                                                                   'LayerSizes',LayerSize{i1}, 'Activations',LayerActivation, ...
                                                                   'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',8e3);

                        FailedConv(i2)  = contains(ModelsCross{i2}.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');

                        [~, ProbsCrossTest] = predict(ModelsCross{i2}, DatasetsCrossFeatsTest{i2});
                        CrossMSE(i2) = mse(ExpOutsCrossTest{i2}, ProbsCrossTest(:,2));

                        [~, ~, ~, CrossAUC(i2), ~] = perfcurve(ExpOutsCrossTest{i2}, ProbsCrossTest(:,2), 1);

                        ProbsTest{i2} = ProbsCrossTest(:,2);
                    end

                    [~, IndBestModel] = min(CrossMSE);
                    Model = ModelsCross{IndBestModel};

                    DatasetTrain = DatasetsCrossFeatsTrain{IndBestModel};
                    DatasetTest  = DatasetsCrossFeatsTest{IndBestModel};

                    ExpectedOutputsTrain = ExpOutsCrossTrain{IndBestModel};
                    ExpectedOutputsTest  = ExpOutsCrossTest{IndBestModel};

                    ANNsCross{ANNsCrossRows, i1} = {ModelsCross; CrossMSE; CrossAUC; IndBestModel; FailedConv; ProbsTest}; % Pay attention to the order!
                    if any(FailedConv)
                        warning(strcat("ATTENTION! Some models in cross n. ", string(i1), " failed to converge! Please analyze it."))
                    end
            end
            
            [PredClassTrain, PredProbsTrain] = predict(Model, DatasetTrain);
            [PredClassTest,  PredProbsTest]  = predict(Model, DatasetTest);

            PredProbsTrain = PredProbsTrain(:,2);
            PredProbsTest  = PredProbsTest(:,2);
        
            TrainLoss(i1) = loss(Model, DatasetTrain, ExpectedOutputsTrain);
            TrainMSE(i1)  = mse(ExpectedOutputsTrain, PredProbsTrain);
            TestLoss(i1)  = loss(Model, DatasetTest, ExpectedOutputsTest);
            TestMSE(i1)   = mse(ExpectedOutputsTest, PredProbsTest);
        
            ANNs{ANNsRows, i1} = {Model; FeaturesNames; LayerSize{i1}}; % Pay attention to the order!
            ANNsRes{ANNsResRows, i1} = {PredProbsTrain; PredProbsTest}; % Pay attention to the order!
        end
end

ANNsCols = strcat("ANN",string(1:NumberOfANNs));
ANNs.Properties.VariableNames    = ANNsCols;
ANNsRes.Properties.VariableNames = ANNsCols;

%% Evaluation of prediction quality by means of ROC
ProgressBar.Indeterminate = 'on';
ProgressBar.Message       = "Analyzing quality of models...";

ANNsPerfRows   = {'FPR', 'TPR', 'AUC', 'BestThreshold', 'BestThrInd'};
ANNsPerf       = table('RowNames',{'ROC','Err'});
ANNsPerf{'Err','Train'} = {array2table([TrainMSE; TrainLoss], ...
                                            'VariableNames',ANNsCols, ...
                                            'RowNames',{'MSE','Loss'})};
ANNsPerf{'Err','Test'}  = {array2table([TestMSE; TestLoss], ...
                                            'VariableNames',ANNsCols, ...
                                            'RowNames',{'MSE','Loss'})};
ANNsPerf{'ROC',{'Train','Test'}} = {table('RowNames',ANNsPerfRows)};

for i1 = 1:NumberOfANNs
    PredProbsTest  = ANNsRes{'ProbsTest' , i1}{:};
    PredProbsTrain = ANNsRes{'ProbsTrain', i1}{:};

    if strcmp(ANNMode,'Cross Validation (Polygons)')
        MdlToTake = ANNsCross{'BestModel',i1}{:};

        ExpOutsTest  = DatasetsCross{'ExpOutsCrossTest', MdlToTake}{:};
        ExpOutsTrain = DatasetsCross{'ExpOutsCrossTrain',MdlToTake}{:};
    else
        ExpOutsTest  = ExpectedOutputsTest;
        ExpOutsTrain = ExpectedOutputsTrain;
    end

    % Test performance
    [FPR4ROC_Test, TPR4ROC_Test, ThresholdsROC_Test, AUC_Test, OptPoint_Test] = perfcurve(ExpOutsTest, PredProbsTest, 1); % To adjust ExpectedOutputsTest
    switch MethodBestThreshold
        case 'MATLAB'
            % Method integrated in MATLAB
            IndBest_Test = find(ismember([FPR4ROC_Test, TPR4ROC_Test], OptPoint_Test, 'rows'));
            BestThreshold_Test = ThresholdsROC_Test(IndBest_Test);
        case 'MaximizeRatio-TPR-FPR'
            % Method max ratio TPR/FPR
            RatioTPR_FPR_Test = TPR4ROC_Test./FPR4ROC_Test;
            RatioTPR_FPR_Test(isinf(RatioTPR_FPR_Test)) = nan;
            [~, IndBest_Test]  = max(RatioTPR_FPR_Test);
            BestThreshold_Test = ThresholdsROC_Test(IndBest_Test);
        case 'MaximizeArea-TPR-TNR'
            % Method max product TPR*TNR
            AreaTPR_TNR_Test   = TPR4ROC_Test.*(1-FPR4ROC_Test);
            [~, IndBest_Test]  = max(AreaTPR_TNR_Test);
            BestThreshold_Test = ThresholdsROC_Test(IndBest_Test);
    end
    
    % Train performance
    [FPR4ROC_Train, TPR4ROC_Train, ThresholdsROC_Train, AUC_Train, OptPoint_Train] = perfcurve(ExpOutsTrain, PredProbsTrain, 1);
    switch MethodBestThreshold
        case 'MATLAB'
            % Method integrated in MATLAB
            IndBest_Train = find(ismember([FPR4ROC_Train, TPR4ROC_Train], OptPoint_Train, 'rows'));
            BestThreshold_Train = ThresholdsROC_Train(IndBest_Train);
        case 'MaximizeRatio-TPR-FPR'
            % Method max ratio TPR/FPR
            RatioTPR_FPR_Train = TPR4ROC_Train./FPR4ROC_Train;
            RatioTPR_FPR_Train(isinf(RatioTPR_FPR_Train)) = nan;
            [~, IndBest_Train]  = max(RatioTPR_FPR_Train);
            BestThreshold_Train = ThresholdsROC_Train(IndBest_Train);
        case 'MaximizeArea-TPR-TNR'
            % Method max product TPR*TNR
            AreaTPR_TNR_Train   = TPR4ROC_Train.*(1-FPR4ROC_Train);
            [~, IndBest_Train]  = max(AreaTPR_TNR_Train);
            BestThreshold_Train = ThresholdsROC_Train(IndBest_Train);
    end
    
    % General matrices creation
    ANNsPerf{'ROC','Test'}{:}{ANNsPerfRows,  i1} = {FPR4ROC_Test;  TPR4ROC_Test;  AUC_Test;  BestThreshold_Test;  IndBest_Test }; % Pay attention to the order!
    ANNsPerf{'ROC','Train'}{:}{ANNsPerfRows, i1} = {FPR4ROC_Train; TPR4ROC_Train; AUC_Train; BestThreshold_Train; IndBest_Train}; % Pay attention to the order!
end

ANNsPerf{'ROC','Test'}{:}.Properties.VariableNames  = ANNsCols;
ANNsPerf{'ROC','Train'}{:}.Properties.VariableNames = ANNsCols;

%% Plot for check % Finish to adjust for PlotOption 1 (or maybe delete it)
if PlotCheck
    ProgressBar.Message = "Loading data...";

    load([fold_var,sl,'StudyAreaVariables.mat'],    'StudyAreaPolygon')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','FilesDetectedSoilSlip')

    StableAreaApproach  = DatasetMLInfo{1, 'StableAreaApproach'};
    MultipleDayAnalysis = DatasetMLInfo{1, 'MultipleDayAnalysis'};

    if length(UnstablePolygons) > 1
        UnstablePolyMrgd = union(UnstablePolygons);
        IndecisPolyMrgd  = union(IndecisionPolygons);
        StablePolyMrgd   = union(StablePolygons);
    else
        UnstablePolyMrgd = UnstablePolygons;
        IndecisPolyMrgd  = IndecisionPolygons;
        StablePolyMrgd   = StablePolygons;
    end

    ProgressBar.Message = "Plotting results...";
    
    [~, BestModelForTest]  = max(cell2mat(ANNsPerf{'ROC','Test'}{:}{'AUC',:}));
    [~, BestModelForTrain] = max(cell2mat(ANNsPerf{'ROC','Train'}{:}{'AUC',:}));
    ModelToPlot = str2double(inputdlg({["Which model do you want to plot?"
                                        strcat("From 1 to ", string(NumberOfANNs))
                                        strcat("Best for Test is: ", string(BestModelForTest))
                                        strcat("Best for Train is: ", string(BestModelForTrain))]}, '', 1, ...
                                       {num2str(BestModelForTest)}));
    
    PlotOption = 1;
    if MultipleDayAnalysis
        PossibleDatetimes = unique(DatasetMLDates.Datetime);
        DateChosedInd     = listdlg('PromptString',{'Select the event to plot :',''}, ...
                                    'ListString',PossibleDatetimes, 'SelectionMode','single');
        DateChosed = PossibleDatetimes(DateChosedInd);

        figure(Fig)
        drawnow

        IndsEventToTake = (DatasetMLDates.Datetime == DateChosed);

        LandslideEvent = all(DatasetMLDates.LandslideEvent(IndsEventToTake));
        if LandslideEvent; PlotOption = 2; else; PlotOption = 3; end

        DatasetPartChosed = find(any((DateChosed == [DatasetMLInfo.EventDate, DatasetMLInfo.BeforeEventDate]), 2), 1);
        
        [~, InfoDetName, InfoDetExt] = fileparts(DatasetMLInfo{DatasetPartChosed, 'FullPathInfoDetUsed'});
        InfoDetNameToTake = strcat(InfoDetName,InfoDetExt);
    else
        [~, InfoDetName, InfoDetExt] = fileparts(DatasetMLInfo{end, 'FullPathInfoDetUsed'});
        InfoDetNameToTake = strcat(InfoDetName,InfoDetExt);
    end

    IndDetToUse = strcmp(FilesDetectedSoilSlip, InfoDetNameToTake);
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDetToUse};
    
    fig_check = figure(3);
    ax_check  = axes(fig_check);
    hold(ax_check,'on')
    
    BestThresholdTrain  = ANNsPerf{'ROC','Train'}{:}{'BestThreshold',ModelToPlot}{:};
    BestThresholdTest   = ANNsPerf{'ROC','Test'}{:}{'BestThreshold',ModelToPlot}{:};
    IndexOfBestThrTrain = ANNsPerf{'ROC','Train'}{:}{'BestThrInd',ModelToPlot}{:};
    IndexOfBestThrTest  = ANNsPerf{'ROC','Test'}{:}{'BestThrInd',ModelToPlot}{:};
    
    BestThrTPRTrain = ANNsPerf{'ROC','Train'}{:}{'TPR',ModelToPlot}{:}(IndexOfBestThrTrain);
    BestThrTPRTest  = ANNsPerf{'ROC','Test'}{:}{'TPR',ModelToPlot}{:}(IndexOfBestThrTest);
    BestThrFPRTrain = ANNsPerf{'ROC','Train'}{:}{'FPR',ModelToPlot}{:}(IndexOfBestThrTrain);
    BestThrFPRTest  = ANNsPerf{'ROC','Test'}{:}{'FPR',ModelToPlot}{:}(IndexOfBestThrTest);
    
    disp(strcat("Your TPR relative to the best threshold are (train - test): ", string(BestThrTPRTrain), " - ", string(BestThrTPRTest)))
    disp(strcat("Your FPR relative to the best threshold are (train - test): ", string(BestThrFPRTrain), " - ", string(BestThrFPRTest)))
    
    ModelSelected = ANNs{'Model',ModelToPlot}{:};
    
    switch PlotOption
        case 1
            PredProbsTrain       = ANNsRes{'ProbsTrain',ModelToPlot}{:};
            PredProbsTest        = ANNsRes{'ProbsTest', ModelToPlot}{:};
            PredClassTrainWithBT = PredProbsTrain(:,2) >= BestThresholdTrain;
            PredClassTestWithBT  = PredProbsTest(:,2)  >= BestThresholdTest;
    
        case {2, 3}
            DatasetForPlot = DatasetMLFeats(IndsEventToTake, :);
            xLongForPlot   = DatasetMLCoords.Longitude(IndsEventToTake);
            yLatForPlot    = DatasetMLCoords.Latitude(IndsEventToTake);
            ExpOutForPlot  = double(DatasetMLClasses.ExpectedOutput(IndsEventToTake, :));
            [~, ProbabilityForPlot] = predict(ModelSelected, DatasetForPlot);
            PredictionWithBTForPlot = ProbabilityForPlot(:,2) >= (BestThresholdTrain + BestThresholdTest)/2;
    end
    
    plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1.5)
    
    switch PlotOption
        case {1, 2}
            plot(UnstablePolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#d87e7e");
        case 3
            plot(UnstablePolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#5aa06b");
    end
    plot(IndecisPolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#fff2cc");
    plot(StablePolyMrgd,  'FaceAlpha',.5, 'FaceColor',"#5aa06b");
    
    hdetected = cellfun(@(x,y) scatter(x, y, '^k', 'Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
    
    switch PlotOption
        case 1
            hUnstableTest  = scatter(DatasetMLCoords.Longitude(IndsTestNumeric(PredClassTestWithBT)), ...
                                     DatasetMLCoords.Latitude(IndsTestNumeric(PredClassTestWithBT)), ...
                                     30, 'Marker','d', 'MarkerFaceColor',"#000000", 'MarkerEdgeColor','none');
            
            hUnstableTrain = scatter(DatasetMLCoords.Longitude(IndsTrainNumeric(PredClassTrainWithBT)), ...
                                     DatasetMLCoords.Latitude(IndsTrainNumeric(PredClassTrainWithBT)), ...
                                     30, 'Marker','s', 'MarkerFaceColor',"#000000", 'MarkerEdgeColor','none');
    
        case {2, 3}
            hUnstableForPlot = scatter(xLongForPlot(PredictionWithBTForPlot), ...
                                       yLatForPlot(PredictionWithBTForPlot), ...
                                       30, 'Marker','s', 'MarkerFaceColor',"#000000", 'MarkerEdgeColor','none');
    end
    
    switch PlotOption
        case 1
            xPointUnstab = DatasetMLCoords.Longitude(logical(ExpectedOutputs));
            yPointUnstab = DatasetMLCoords.Latitude(logical(ExpectedOutputs));
    
            xPointStab   = DatasetMLCoords.Longitude(not(logical(ExpectedOutputs)));
            yPointStab   = DatasetMLCoords.Latitude(not(logical(ExpectedOutputs)));
    
        case {2, 3}
            xPointUnstab = xLongForPlot(logical(ExpOutForPlot));
            yPointUnstab = yLatForPlot(logical(ExpOutForPlot));
    
            xPointStab   = xLongForPlot(not(logical(ExpOutForPlot)));
            yPointStab   = yLatForPlot(not(logical(ExpOutForPlot)));
    end
    
    hUnstabOutputReal = scatter(xPointUnstab, yPointUnstab, 7, 'Marker',"hexagram", ...
                                'MarkerFaceColor',"#ff0c01", 'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.5);
    
    hStableOutputReal = scatter(xPointStab, yPointStab, 15, 'Marker',"hexagram", ...
                                'MarkerFaceColor',"#77AC30", 'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.5);
    
    switch PlotOption
        case {1, 2}
            title("Day of the event")
        case 3
            title([num2str(DaysBeforeEventWhenStable), ' days before the event'])
        otherwise
            error('Plot option not defined')
    end
    
    yLatMean    = mean(DatasetMLCoords.Latitude);
    dLat1Meter  = rad2deg(1/earthRadius); % 1 m in lat
    dLong1Meter = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long
    
    RatioLatLong = dLat1Meter/dLong1Meter;
    daspect([1, RatioLatLong, 1])
end

%% Creation of a folder where save model and future predictions
cd(fold_res_ml)
EventDates.Format = 'dd-MM-yyyy';
SuggestedFoldName = ['ML-ANNs-TrainEvents-',strjoin(cellstr(char(EventDates)), '_')];
MLFolderName = char(inputdlg({'Choose folder name (in Results->ML Models and Predictions):'}, '', 1, {SuggestedFoldName} ));

if exist(MLFolderName, 'dir')
    Options = {'Yes, thanks', 'No, for God!'};
    Answer  = uiconfirm(Fig, strcat(MLFolderName, " is an existing folder. Do you want to overwrite it?"), ...
                             'Existing ML Folder', 'Options',Options, 'DefaultOption',2);
    switch Answer
        case 'Yes, thanks.'
            rmdir(MLFolderName,'s')
            mkdir(MLFolderName)
        case 'No, for God!'
            MLFolderName = [MLFolderName,'-new'];
    end
else
    mkdir(MLFolderName)
end

fold_res_ml_curr = [fold_res_ml,sl,MLFolderName];

%% Saving...
ProgressBar.Message = "Saving files...";
VariablesML = {'ANNs', 'ANNsRes', 'ANNsPerf', 'ModelInfo'};
if strcmp(ANNMode, 'Cross Validation (Polygons)')
    VariablesML = [VariablesML, {'ANNsCross', 'DatasetsCross'}];
end
saveswitch([fold_res_ml_curr,sl,'TrainedANNs.mat'], VariablesML)

close(ProgressBar) % Fig instead of ProgressBar if in standalone version