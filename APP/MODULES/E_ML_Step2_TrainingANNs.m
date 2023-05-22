% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

rng(10) % For reproducibility of the model

%% Loading data and initialization of AnalysisInformation


%% Loop for ANN models (different rainfall time)
ProgressBar.Indeterminate = 'off';

if MultipleDayAnalysis
    ProgressBar.Message = "Starting ANNs creation...";

    if ModifyRatio
        Options = {'Yes', 'No'};
        MantainUnstabChoice  = uiconfirm(Fig, ['Do you want to mantain points where there is instability ' ...
                                               'even in the day when all points are stable? ' ...
                                               '(these points will be mantained during the merge and ' ...
                                               'the subsequent ratio adjustment)'], ...
                                               'Mantain unstable points', 'Options',Options, 'DefaultOption',1);
        if strcmp(MantainUnstabChoice,'Yes'); MantainPointsUnstab = true; else; MantainPointsUnstab = false; end

        AnalysisInformation.UnstablePointsMantainedInDayOfStable = MantainPointsUnstab;
    end
end

Options = {'SeparateDailyCumulate', 'SingleCumulate'};
RainfallMethod  = uiconfirm(Fig, 'How do you want to built the topology of your neural network?', ...
                                 'Neural network topology', 'Options',Options, 'DefaultOption',2);
AnalysisInformation.RainfallMethod = RainfallMethod;
switch RainfallMethod
    case 'SeparateDailyCumulate'
        Options = {'With Validation Data', 'Auto', 'Normal'};
        ANNMode  = uiconfirm(Fig, 'How do you want to built your neural network?', ...
                                  'Neural network choice', 'Options',Options, 'DefaultOption',2);

        LayerActivation = 'sigmoid'; % CHOICE TO USER!
        Standardize     = true;      % CHOICE TO USER!

        StructureInput  = inputdlg("Number of nuerons in each hidden: ", '', 1, {'[60, 20]'});
        LayerSize       = str2num(StructureInput{1});

        NumOfDayToConsider = 15; % CHOICE TO USER!!!
        ANNModels = cell(12, NumOfDayToConsider);
        AnalysisInformation.MaxDaysConsidered = NumOfDayToConsider;
        AnalysisInformation.ANNMode           = ANNMode;
        for i1 = 1:NumOfDayToConsider
            ProgressBar.Value = i1/NumOfDayToConsider;
            ProgressBar.Message = strcat("Training model n. ", string(i1)," of ", string(NumOfDayToConsider));
        
            %% Addition in table of time sensitive parameters
            ConditioningFactorToAdd  = cellfun(@(x) [x,'-',num2str(i1)], TimeSensitiveParam, 'UniformOutput',false);
            FeaturesNames = [FeaturesNames, ConditioningFactorToAdd];

            RowToTake   = find(TimeSensitiveDate == EventDate)-i1+1;
            ColumnToAdd = cellfun(@(x) cat(1,x{RowToTake,:}), TimeSensitiveDataInterpStudy, 'UniformOutput',false);

            RangesForNorm = [ RangesForNorm  ;      % Pre-existing
                               0    ,   120  ;      % Cumulative daily rainfall (to discuss this value, max was 134 mm in a day for Emilia Romagna)
                              -10   ,   40    ];    % Mean daily temperature (to discuss this value)

            ColumnToAddTable     = table( ColumnToAdd{:}, 'VariableNames',FeaturesNames(end-length(TimeSensitiveParam)+1 : end) );
            ColumnToAddTableNorm = array2table(rescale([ColumnToAdd{:}], ...
                                                        'InputMin',RangesForNorm(end-length(TimeSensitiveParam)+1 : end,1)', ...  % Must be a row
                                                        'InputMax',RangesForNorm(end-length(TimeSensitiveParam)+1 : end,2)'), ... % Must be a row
                                                    'VariableNames',FeaturesNames(end-length(TimeSensitiveParam)+1 : end));

            DatasetFeatsStudyNotNorm = [DatasetFeatsStudyNotNorm, ColumnToAddTable    ]; % Horizontal concatenation
            DatasetFeatsStudyNorm    = [DatasetFeatsStudyNorm,    ColumnToAddTableNorm]; % Horizontal concatenation

            ColumnToAddTable = ColumnToAddTable(IndicesTrainDataset,:);
            ColumnToAddTableNorm = ColumnToAddTableNorm(IndicesTrainDataset,:);

            DatasetMLNotNorm = [DatasetMLNotNorm, ColumnToAddTable    ];
            DatasetMLNorm    = [DatasetMLNorm,    ColumnToAddTableNorm];

            %% Addition of points at different time
            if MultipleDayAnalysis
                RowToTakeAtDiffTime = RowToTake-DaysBeforeEventWhenStable;
                ColumnToAddAtDiffTime = cellfun(@(x) cat(1,x{RowToTakeAtDiffTime,:}), TimeSensitiveDataInterpStudy, 'UniformOutput',false);
                
                ColumnToAddTableAtDiffTime     = table( ColumnToAddAtDiffTime{:}, 'VariableNames',FeaturesNames(end-length(TimeSensitiveParam)+1 : end) );
                ColumnToAddTableAtDiffTimeNorm = array2table(rescale([ColumnToAddAtDiffTime{:}], ...
                                                                      'InputMin',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 1)', ...  % Must be a row
                                                                      'InputMax',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 2)'), ... % Must be a row
                                                                  'VariableNames',FeaturesNames(end-length(TimeSensitiveParam)+1 : end));

                ColumnToAddTableAtDiffTime(IndToRemove1,:)     = [];
                ColumnToAddTableAtDiffTimeNorm(IndToRemove1,:) = [];
                if ModifyRatio
                    ColumnToAddTableAtDiffTime(IndToRemove2,:)     = []; 
                    ColumnToAddTableAtDiffTimeNorm(IndToRemove2,:) = []; 
                end

                DatasetMLNotNormToAdd = [DatasetMLNotNormToAdd, ColumnToAddTableAtDiffTime    ];
                DatasetMLNormToAdd    = [DatasetMLNormToAdd   , ColumnToAddTableAtDiffTimeNorm];

                DatasetMLNotNormToUse = [DatasetMLNotNorm; DatasetMLNotNormToAdd];
                DatasetMLNormToUse    = [DatasetMLNorm;    DatasetMLNormToAdd   ];
                ExpectedOutToUse      = [ExpectedOut;      ExpectedOutToAdd     ];
                DatasetMLCoordsToUse  = [DatasetMLCoords;  DatasetMLCoordsToAdd ];

                if ModifyRatio
                    IndOutPos   = find(ExpectedOutToUse==1);
                    IndOutNeg   = find(ExpectedOutToUse==0);
                    RatioPosNeg = length(IndOutPos)/length(IndOutNeg);

                    PercToRemove = 1-RatioPosNeg/OptimalRatio;

                    if MantainPointsUnstab
                        [pp3, ee3] = getnan2([StablePolyMrgd.Vertices; nan, nan]);
                        IndPointStable = find(inpoly([DatasetMLCoordsToUse.Longitude,DatasetMLCoordsToUse.Latitude], pp3,ee3));

                        IndOfIndPointUncStableToRemove = randperm(numel(IndPointStable), ...
                                                                  ceil(numel(IndOutNeg)*PercToRemove)); % ceil(numel(IndOutNeg)*PercToRemove) remain because you have in any case to remove that number of points
                        IndToRemove3 = IndPointStable(IndOfIndPointUncStableToRemove);
                    else
                        IndOfIndOutNegToRemove = randperm(numel(IndOutNeg), ceil(numel(IndOutNeg)*PercToRemove));
                        IndToRemove3 = IndOutNeg(IndOfIndOutNegToRemove);
                    end

                    DatasetMLNotNormToUse(IndToRemove3,:) = [];
                    DatasetMLNormToUse(IndToRemove3,:)    = [];
                    ExpectedOutToUse(IndToRemove3)        = [];
                    DatasetMLCoordsToUse(IndToRemove3,:)  = [];
                
                    IndOutPosNew   = find(ExpectedOutToUse==1);
                    IndOutNegNew   = find(ExpectedOutToUse==0);
                    RatioPosNegNew = length(IndOutPosNew)/length(IndOutNegNew);
                    if (numel(IndOutPosNew) ~= numel(IndOutPos)) || (round(OptimalRatio, 1) ~= round(RatioPosNegNew, 1))
                        error("Something went wrong in re-attributing the correct ratio between positive and negative outputs!")
                    end
                end
            else
                DatasetMLNotNormToUse = DatasetMLNotNorm;
                DatasetMLNormToUse    = DatasetMLNorm;
                ExpectedOutToUse      = ExpectedOut;
                DatasetMLCoordsToUse  = DatasetMLCoords;
            end
            
            %% Model creation and prediction
            rng(7) % For reproducibility of the model
            PartitionTrain = cvpartition(ExpectedOutToUse, 'Holdout',0.20);
        
            IndTrainLogical = training(PartitionTrain); % Indices for the training set
            IndTrain = find(IndTrainLogical);
            
            IndTestLogical = test(PartitionTrain); % Indices for the test set
            IndTest = find(IndTestLogical);
            
            DatasetTrain = DatasetMLNormToUse(IndTrainLogical,:);
            DatasetTest  = DatasetMLNormToUse(IndTestLogical,:);
            
            OutputTrain = ExpectedOutToUse(IndTrainLogical);
            OutputTest  = ExpectedOutToUse(IndTestLogical);
            
            switch ANNMode
                case 'With Validation Data'
                    Model = fitcnet(DatasetTrain, OutputTrain, 'ValidationData',{DatasetTest, OutputTest}, ...
                                                               'ValidationFrequency',5, 'ValidationPatience',20, ...
                                                               'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                               'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',5e4);

                    FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                    if FailedConvergence
                        warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
                    end

                case 'Auto'
                    Model = fitcnet(DatasetTrain, OutputTrain, 'OptimizeHyperparameters','all', ...
                                                               'MaxObjectiveEvaluations',20);
                case 'Normal'
                    Model = fitcnet(DatasetTrain, OutputTrain, 'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                               'Standardize',Standardize, 'Lambda',1.2441e-09);
            end

            FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
            if FailedConvergence
                warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
            end
            
            [PredictionTrain, ProbabilityTrain] = predict(Model, DatasetTrain);
            [PredictionTest,  ProbabilityTest]  = predict(Model, DatasetTest);
        
            DatasetTestMSE = loss(Model, DatasetTest, OutputTest);

            R2 = corrcoef(table2array(DatasetMLNormToUse));
        
            % General matrix creation 
            ANNModels(:, i1) = {Model; DatasetTrain; DatasetTest; OutputTrain; OutputTest; ...
                                PredictionTrain; ProbabilityTrain; PredictionTest; ...
                                ProbabilityTest; DatasetTestMSE; R2; FeaturesNames};
        end

    case 'SingleCumulate'
        %% Table rainfall addition
        ConditioningFactorOper = repmat({'Averaged'}, 1, length(TimeSensitiveParam));
        ConditioningFactorOper(CumulableParam) = {'Cumulated'};

        ConditioningFactorToAdd  = cellfun(@(x, y) [x,y,num2str(DaysToCumulate),'d'], TimeSensitiveParam, ConditioningFactorOper, 'UniformOutput',false);
        FeaturesNames = [FeaturesNames, ConditioningFactorToAdd];
    
        RowToTake   = length(TimeSensitiveDate);
        ColumnToAdd = cell(1, length(TimeSensitiveParam));
        for i1 = 1:length(TimeSensitiveParam)
            ColumnToAddTemp = cell(1, size(TimeSensitiveDataInterpStudy{i1}, 2));
            for i2 = 1:size(TimeSensitiveDataInterpStudy{i1}, 2)
                if CumulableParam(i1)
                    ColumnToAddTemp{i2} = sum([TimeSensitiveDataInterpStudy{i1}{RowToTake : -1 : (RowToTake-DaysToCumulate+1), i2}], 2);
                else
                    ColumnToAddTemp{i2} = mean([TimeSensitiveDataInterpStudy{i1}{RowToTake : -1 : (RowToTake-DaysToCumulate+1), i2}], 2);
                end
            end
            ColumnToAdd{i1} = cat(1,ColumnToAddTemp{:});
        end

        MaxDailyRain  = 30; % To discuss this value (max in Emilia was 134 mm in a day)
        MaxRangeRain  = MaxDailyRain*DaysToCumulate;

        RangesForNorm = [ RangesForNorm         ;      % Pre-existing
                           0    ,   MaxRangeRain;      % Cumulative daily rainfall (to discuss this value, max was 134 mm in a day for Emilia Romagna)
                          -10   ,   40           ];    % Mean daily temperature (to discuss this value)

        ColumnToAddTable     = table( ColumnToAdd{:}, 'VariableNames',FeaturesNames(end-length(TimeSensitiveParam)+1 : end) );
        ColumnToAddTableNorm = array2table(rescale([ColumnToAdd{:}], ...
                                                    'InputMin',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 1)', ...  % Must be a row
                                                    'InputMax',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 2)'), ... % Must be a row
                                                'VariableNames',FeaturesNames(end-length(TimeSensitiveParam)+1 : end));

        DatasetFeatsStudyNotNorm = [DatasetFeatsStudyNotNorm, ColumnToAddTable    ]; % Horizontal concatenation
        DatasetFeatsStudyNorm    = [DatasetFeatsStudyNorm   , ColumnToAddTableNorm]; % Horizontal concatenation

        ColumnToAddTable(IndToRemove1,:)     = [];
        ColumnToAddTableNorm(IndToRemove1,:) = [];
        if ModifyRatio
            ColumnToAddTable(IndToRemove2,:)     = []; 
            ColumnToAddTableNorm(IndToRemove2,:) = []; 
        end

        DatasetMLNotNorm     = [DatasetMLNotNorm    , ColumnToAddTable    ];
        DatasetMLNorm = [DatasetMLNorm, ColumnToAddTableNorm];

        %% Addition of point at different time
        if MultipleDayAnalysis
            RowToTakeAtDiffTime = RowToTake-DaysBeforeEventWhenStable;
            ColumnToAddAtDiffTime = cell(1, length(TimeSensitiveParam));
            for i1 = 1:length(TimeSensitiveParam)
                ColumnToAddAtDiffTimeTemp = cell(1, size(TimeSensitiveDataInterpStudy{i1}, 2));
                for i2 = 1:size(TimeSensitiveDataInterpStudy{i1}, 2)
                    if CumulableParam(i1)
                        ColumnToAddAtDiffTimeTemp{i2} = sum([TimeSensitiveDataInterpStudy{i1}{RowToTakeAtDiffTime : -1 : (RowToTakeAtDiffTime-DaysToCumulate+1), i2}], 2);
                    else
                        ColumnToAddAtDiffTimeTemp{i2} = mean([TimeSensitiveDataInterpStudy{i1}{RowToTakeAtDiffTime : -1 : (RowToTakeAtDiffTime-DaysToCumulate+1), i2}], 2);
                    end
                end
                ColumnToAddAtDiffTime{i1} = cat(1,ColumnToAddAtDiffTimeTemp{:});
            end
            
            ColumnToAddTableAtDiffTime     = table( ColumnToAddAtDiffTime{:}, 'VariableNames',FeaturesNames(end-length(TimeSensitiveParam)+1 : end) );
            ColumnToAddTableAtDiffTimeNorm = array2table(rescale([ColumnToAddAtDiffTime{:}], ...
                                                                  'InputMin',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 1)', ...  % Must be a row
                                                                  'InputMax',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 2)'), ... % Must be a row
                                                              'VariableNames',FeaturesNames(end-length(TimeSensitiveParam)+1 : end));

            ColumnToAddTableAtDiffTime(IndToRemove1,:)     = [];
            ColumnToAddTableAtDiffTimeNorm(IndToRemove1,:) = [];
            if ModifyRatio
                ColumnToAddTableAtDiffTime(IndToRemove2,:)     = []; 
                ColumnToAddTableAtDiffTimeNorm(IndToRemove2,:) = []; 
            end

            DatasetMLNotNormToAdd     = [DatasetMLNotNormToAdd    , ColumnToAddTableAtDiffTime    ];
            DatasetMLNormToAdd = [DatasetMLNormToAdd, ColumnToAddTableAtDiffTimeNorm];

            DatasetMLNotNormToUse = [DatasetMLNotNorm; DatasetMLNotNormToAdd];
            DatasetMLNormToUse    = [DatasetMLNorm;    DatasetMLNormToAdd   ];
            ExpectedOutToUse      = [ExpectedOut;      ExpectedOutToAdd     ];
            DatasetMLCoordsToUse  = [DatasetMLCoords;  DatasetMLCoordsToAdd ];

            if ModifyRatio
                IndOutPos   = find(ExpectedOutToUse==1);
                IndOutNeg   = find(ExpectedOutToUse==0);
                RatioPosNeg = length(IndOutPos)/length(IndOutNeg);

                PercToRemove = 1-RatioPosNeg/OptimalRatio;

                if MantainPointsUnstab
                    [pp3, ee3] = getnan2([StablePolyMrgd.Vertices; nan, nan]);
                    IndPointUncStable = find(inpoly([DatasetMLCoordsToUse.Longitude,DatasetMLCoordsToUse.Latitude], pp3,ee3));

                    IndOfIndPointUncStableToRemove = randperm(numel(IndPointUncStable), ...
                                                              ceil(numel(IndOutNeg)*PercToRemove)); % ceil(numel(IndOutNeg)*PercToRemove) remain because you have in any case to remove that number of points
                    IndToRemove3 = IndPointUncStable(IndOfIndPointUncStableToRemove);
                else
                    IndOfIndOutNegToRemove = randperm(numel(IndOutNeg), ceil(numel(IndOutNeg)*PercToRemove));
                    IndToRemove3 = IndOutNeg(IndOfIndOutNegToRemove);
                end

                DatasetMLNotNormToUse(IndToRemove3,:) = [];
                DatasetMLNormToUse(IndToRemove3,:)    = [];
                ExpectedOutToUse(IndToRemove3)        = [];
                DatasetMLCoordsToUse(IndToRemove3,:)  = [];
            
                IndOutPosNew   = find(ExpectedOutToUse==1);
                IndOutNegNew   = find(ExpectedOutToUse==0);
                RatioPosNegNew = length(IndOutPosNew)/length(IndOutNegNew);
                if (numel(IndOutPosNew) ~= numel(IndOutPos)) || (round(OptimalRatio, 1) ~= round(RatioPosNegNew, 1))
                    error("Something went wrong in re-attributing the correct ratio between positive and negative outputs!")
                end
            end
        else
            DatasetMLNotNormToUse = DatasetMLNotNorm;
            DatasetMLNormToUse    = DatasetMLNorm;
            ExpectedOutToUse      = ExpectedOut;
            DatasetMLCoordsToUse  = DatasetMLCoords;
        end

        %% ANN Settings
        R2 = corrcoef(table2array(DatasetMLNormToUse));

        Options = {'With Validation Data', 'Cross Validation (K-Fold)', 'Normal'};
        ANNMode  = uiconfirm(Fig, 'How do you want to built your neural network?', ...
                                  'Neural network choice', 'Options',Options, 'DefaultOption',1);

        LayerActivation = 'sigmoid'; % CHOICE TO USER!
        Standardize     = true;      % CHOICE TO USER!

        AnalysisInformation.ANNMode           = ANNMode;
        AnalysisInformation.ActivationFunUsed = LayerActivation;
        AnalysisInformation.StandardizedInput = Standardize;
        
        StructureInput = inputdlg(["Max number of hiddens: "
                                   "Max number of nuerons in each hidden: "
                                   "Increase of neurons for each model: "], ...
                                   '', 1, {'6', '[100, 200, 100, 50, 20, 10]', '10'});

        MaxNumOfHiddens   = str2double(StructureInput{1});
        MaxNumOfNeurons   = str2num(StructureInput{2});
        NeurToAddEachStep = str2double(StructureInput{3});

        if MaxNumOfHiddens > numel(MaxNumOfNeurons)
            error('You have to select the max number of neurons for each hidden layers (Format: [NumNeuronsHid1, NumNeuronsHid2, ...])')
        end

        AnalysisInformation.MaxNumOfHiddens   = {MaxNumOfHiddens};
        AnalysisInformation.MaxNumOfNeurons   = {MaxNumOfNeurons};
        AnalysisInformation.NeurToAddEachStep = {NeurToAddEachStep};

        [NumOfNeuronToTrainEachHidden, ModelNeurCombs] = deal(cell(1, MaxNumOfHiddens));
        for i1 = 1:MaxNumOfHiddens
            NumOfNeuronToTrainEachHidden{i1} = [1, NeurToAddEachStep:NeurToAddEachStep:MaxNumOfNeurons(i1)];
            if NeurToAddEachStep == 1; NumOfNeuronToTrainEachHidden{i1}(1) = []; end
            ModelNeurCombs{i1} = combvec(NumOfNeuronToTrainEachHidden{1:i1});
        end

        NumberOfANNs = sum(cellfun(@(x) size(x, 2), ModelNeurCombs));
        ANNModels = cell(12, NumberOfANNs);
        i3 = 0;
        for i1 = 1:MaxNumOfHiddens
            for i2 = 1:size(ModelNeurCombs{i1}, 2)
                i3 = i3+1;
                ProgressBar.Value = i2/size(ModelNeurCombs{i1}, 2);
                ProgressBar.Message = strcat("Training model n. ", string(i2)," of ", ...
                                             string(size(ModelNeurCombs{i1}, 2)), ". Num of Hiddens: ", string(i1));
                
                %% Model creation and prediction
                rng(7) % For reproducibility of the model
                PartitionTrain = cvpartition(ExpectedOutToUse, 'Holdout',0.20);
            
                IndTrainLogical = training(PartitionTrain); % Indices for the training set
                IndTrain = find(IndTrainLogical);
                
                IndTestLogical = test(PartitionTrain); % Indices for the test set
                IndTest = find(IndTestLogical);
                
                DatasetTrain = DatasetMLNormToUse(IndTrainLogical,:);
                DatasetTest  = DatasetMLNormToUse(IndTestLogical,:);
                
                OutputTrain = ExpectedOutToUse(IndTrainLogical);
                OutputTest  = ExpectedOutToUse(IndTestLogical);

                LayerSize = ModelNeurCombs{i1}(:,i2)';

                switch ANNMode
                    case 'With Validation Data'
                        Model = fitcnet(DatasetTrain, OutputTrain, 'ValidationData',{DatasetTest, OutputTest}, ...
                                                                   'ValidationFrequency',5, 'ValidationPatience',30, ...
                                                                   'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                                   'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',5e4);

                        FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                        if FailedConvergence
                            warning(strcat("ATTENTION! Model n. ", string(i3), " failed to converge! Please analyze it."))
                        end

                    case 'Cross Validation (K-Fold)'
                        ModelCV = fitcnet(DatasetTrain, OutputTrain, 'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                                     'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',5e4, ...
                                                                     'LossTolerance',1e-6, 'StepTolerance',1e-6, ...
                                                                     'Crossval','on', 'KFold',10); % Remember that instead of 'KFold' you can use for example: 'Holdout',0.1

                        % [PredictionOfModelCV, ProbabilitiesOfModelCV] = kfoldPredict(ModelCV); % To have the predictions of the cross validated model
                        % ConfusionTrain = confusionchart(OutputTrain, PredictionOfModelCV); % To see visually how well the cross validated model predict

                        LossesOfModels = kfoldLoss(ModelCV, 'Mode','individual');
                        [~, IndBestModel] = min(LossesOfModels);
                        Model = ModelCV.Trained{IndBestModel};
                    case 'Normal'
                        Model = fitcnet(DatasetTrain, OutputTrain, 'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                                   'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',5e4, ...
                                                                   'LossTolerance',1e-5, 'StepTolerance',1e-6);

                        FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                        if FailedConvergence
                            warning(strcat("ATTENTION! Model n. ", string(i3), " failed to converge! Please analyze it."))
                        end
                end
                
                [PredictionTrain, ProbabilityTrain] = predict(Model, DatasetTrain);
                [PredictionTest,  ProbabilityTest]  = predict(Model, DatasetTest);
            
                DatasetTestMSE = loss(Model, DatasetTest, OutputTest);
            
                % General matrix creation
                ANNModels(:, i3) = {Model; DatasetTrain; DatasetTest; OutputTrain; OutputTest; ...
                                    PredictionTrain; ProbabilityTrain; PredictionTest; ...
                                    ProbabilityTest; DatasetTestMSE; R2; FeaturesNames};
            end
        end
end

%% Evaluation of prediction quality by means of ROC
ProgressBar.Indeterminate = 'on';
ProgressBar.Message       = "Analyzing quality of models...";

Options = {'MATLAB', 'MaximizeRatio-TPR-FPR', 'MaximizeArea-TPR-TNR'};
MethodBestThreshold = uiconfirm(Fig, 'How do you want to find the optimal threshold for ROC curves?', ...
                                     'Optimal ratio ROC', 'Options',Options, 'DefaultOption',1);

AnalysisInformation.MethodForSelectingOptimalThresholdInROCs = MethodBestThreshold;

NumberOfANNs        = size(ANNModels, 2);
ANNModelsROCTest    = cell(5, NumberOfANNs);
ANNModelsROCTrain   = cell(5, NumberOfANNs);
for i1 = 1:NumberOfANNs
    OutputTest       = ANNModels{5, i1};
    OutputTrain      = ANNModels{4, i1};
    ProbabilityTest  = ANNModels{9, i1};
    ProbabilityTrain = ANNModels{7, i1};

    % Test performance
    [FPR4ROC_Test, TPR4ROC_Test, ThresholdsROC_Test, AUC_Test, OptPoint_Test] = perfcurve(OutputTest, ProbabilityTest(:,2), 1);
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
    [FPR4ROC_Train, TPR4ROC_Train, ThresholdsROC_Train, AUC_Train, OptPoint_Train] = perfcurve(OutputTrain, ProbabilityTrain(:,2), 1);
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
    ANNModelsROCTest(:, i1)  = {FPR4ROC_Test,  TPR4ROC_Test,  AUC_Test,  BestThreshold_Test,  IndBest_Test};
    ANNModelsROCTrain(:, i1) = {FPR4ROC_Train, TPR4ROC_Train, AUC_Train, BestThreshold_Train, IndBest_Train};
end

%% Conversion in tables
ProgressBar.Message = "Creation of tables...";
ANNModels = cell2table(ANNModels);
ANNModels.Properties.RowNames = {'Model', 'DatasetTrain', 'DatasetTest', 'OutputTrain', ...
                                 'OutputTest', 'PredictionTrain', 'ProbabilityTrain', ...
                                 'PredictionTest', 'ProbabilityTest', 'DatasetTestMSE', ...
                                 'R2', 'FeaturesNames'};

ANNModelsROCTest = cell2table(ANNModelsROCTest);
ANNModelsROCTest.Properties.RowNames = {'FPR-Test', 'TPR-Test', 'AUC-Test', 'BestThreshold-Test', 'Index of Best Thr-Test'};

ANNModelsROCTrain = cell2table(ANNModelsROCTrain);
ANNModelsROCTrain.Properties.RowNames = {'FPR-Train', 'TPR-Train', 'AUC-Train', 'BestThreshold-Train', 'Index of Best Thr-Train'};

RangesForNorm = table(RangesForNorm(:,1), RangesForNorm(:,2), 'VariableNames',["Min value", "Max value"]);
RangesForNorm.Properties.RowNames = FeaturesNames;

%% Plot for check (the last one, that is the one with 30 days of rainfall)
ProgressBar.Message = "Plotting results...";

[~, BestModelForTest]  = max(cell2mat(ANNModelsROCTest{3,:}));
[~, BestModelForTrain] = max(cell2mat(ANNModelsROCTrain{3,:}));
ModelToPlot = str2double(inputdlg({["Which model do you want to plot?"
                                    strcat("From 1 to ", string(size(ANNModels,2)))
                                    strcat("Best for Test is: ", string(BestModelForTest))
                                    strcat("Best for Train is: ", string(BestModelForTrain))]}, '', 1, {'1'}));

PlotOption = 1;
if MultipleDayAnalysis
    Options = {'Day of the event', [num2str(DaysBeforeEventWhenStable), ' days before the event']};
    PlotChoice = uiconfirm(Fig, 'What event do you want to plot?', ...
                                'Figure to plot', 'Options',Options, 'DefaultOption',1);
    switch PlotChoice
        case 'Day of the event'
            PlotOption = 2;
        case [num2str(DaysBeforeEventWhenStable), ' days before the event']
            PlotOption = 3;
    end
end

fig_check = figure(3);
ax_check = axes(fig_check);
hold(ax_check,'on')

BestThresholdTrain  = ANNModelsROCTrain{4,ModelToPlot}{:};
BestThresholdTest   = ANNModelsROCTest{4,ModelToPlot}{:};
IndexOfBestThrTrain = ANNModelsROCTrain{5,ModelToPlot}{:};
IndexOfBestThrTest  = ANNModelsROCTest{5,ModelToPlot}{:};

BestThrTPRTrain = ANNModelsROCTrain{2,ModelToPlot}{:}(IndexOfBestThrTrain);
BestThrTPRTest  = ANNModelsROCTest{2,ModelToPlot}{:}(IndexOfBestThrTest);
BestThrFPRTrain = ANNModelsROCTrain{1,ModelToPlot}{:}(IndexOfBestThrTrain);
BestThrFPRTest  = ANNModelsROCTest{1,ModelToPlot}{:}(IndexOfBestThrTest);

disp(strcat("Your TPR relative to the best threshold are (train - test): ", string(BestThrTPRTrain), " - ", string(BestThrTPRTest)))
disp(strcat("Your FPR relative to the best threshold are (train - test): ", string(BestThrFPRTrain), " - ", string(BestThrFPRTest)))

ModelSelected = ANNModels{1,ModelToPlot}{:};

switch PlotOption
    case 1
        ProbabilityTrain      = ANNModels{7,ModelToPlot}{:};
        ProbabilityTest       = ANNModels{9,ModelToPlot}{:};
        PredictionTrainWithBT = ProbabilityTrain(:,2) >= BestThresholdTrain;
        PredictionTestWithBT  = ProbabilityTest(:,2)  >= BestThresholdTest;

    case 2
        DatasetForPlot = DatasetMLNorm;
        OutputForPlot  = ExpectedOut;
        [~, ProbabilityForPlot] = predict(ModelSelected, DatasetForPlot);
        PredictionWithBTForPlot = ProbabilityForPlot(:,2) >= BestThresholdTrain; % Please keep attention to 0.9 of the Best Threshold

    case 3
        DatasetForPlot = DatasetMLNormToAdd;
        OutputForPlot  = ExpectedOutToAdd;
        [~, ProbabilityForPlot] = predict(ModelSelected, DatasetForPlot);
        PredictionWithBTForPlot = ProbabilityForPlot(:,2) >= BestThresholdTrain; % Please keep attention to 0.9 of the Best Threshold
end

plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1.5)

if strcmp(StablePointsApproach,'VisibleWindow')
    switch PlotOption
        case {1, 2}
            plot(UnstablePolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#d87e7e");
        case 3
            plot(UnstablePolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#5aa06b");
    end
    plot(IndecisPolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#fff2cc");
    plot(StablePolyMrgd,  'FaceAlpha',.5, 'FaceColor',"#5aa06b");
end

hdetected = cellfun(@(x,y) scatter(x, y, '^k', 'Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));

switch PlotOption
    case 1
        hUnstableTest  = scatter(DatasetMLCoordsToUse.Longitude(IndTest(PredictionTestWithBT)), ...
                                 DatasetMLCoordsToUse.Latitude(IndTest(PredictionTestWithBT)), ...
                                 30, 'Marker','s', 'MarkerFaceColor',"#318ce7", 'MarkerEdgeColor','none');
        
        hUnstableTrain = scatter(DatasetMLCoordsToUse.Longitude(IndTrain(PredictionTrainWithBT)), ...
                                 DatasetMLCoordsToUse.Latitude(IndTrain(PredictionTrainWithBT)), ...
                                 30, 'Marker','d', 'MarkerFaceColor',"#33E6FF", 'MarkerEdgeColor','none');

    case {2, 3}
        hUnstableForPlot = scatter(DatasetMLCoords.Longitude(PredictionWithBTForPlot), ...
                                   DatasetMLCoords.Latitude(PredictionWithBTForPlot), ...
                                   30, 'Marker','s', 'MarkerFaceColor',"#318ce7", 'MarkerEdgeColor','none');
end

switch PlotOption
    case 1
        xPointUnstab = DatasetMLCoordsToUse.Longitude(logical(ExpectedOutToUse));
        yPointUnstab = DatasetMLCoordsToUse.Latitude(logical(ExpectedOutToUse));

        xPointStab   = DatasetMLCoordsToUse.Longitude(not(logical(ExpectedOutToUse)));
        yPointStab   = DatasetMLCoordsToUse.Latitude(not(logical(ExpectedOutToUse)));

    case 2
        xPointUnstab = DatasetMLCoords.Longitude(logical(ExpectedOut));
        yPointUnstab = DatasetMLCoords.Latitude(logical(ExpectedOut));

        xPointStab   = DatasetMLCoords.Longitude(not(logical(ExpectedOut)));
        yPointStab   = DatasetMLCoords.Latitude(not(logical(ExpectedOut)));

    case 3
        xPointUnstab = DatasetMLCoordsToAdd.Longitude(logical(ExpectedOutToAdd));
        yPointUnstab = DatasetMLCoordsToAdd.Latitude(logical(ExpectedOutToAdd));

        xPointStab   = DatasetMLCoordsToAdd.Longitude(not(logical(ExpectedOutToAdd)));
        yPointStab   = DatasetMLCoordsToAdd.Latitude(not(logical(ExpectedOutToAdd)));
end

hUnstabOutputReal = scatter(xPointUnstab, yPointUnstab, ...
                            15, 'Marker',"hexagram", 'MarkerFaceColor',"#ff0c01", ...
                            'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.5);

hStableOutputReal = scatter(xPointStab, yPointStab, ...
                            15, 'Marker',"hexagram", 'MarkerFaceColor',"#77AC30", ...
                            'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.5);

switch PlotOption
    case {1, 2}
        title("Day of the event")
    case 3
        title([num2str(DaysBeforeEventWhenStable), ' days before the event'])
    otherwise
        error('Plot option not defined')
end

dLat1Meter  = rad2deg(1/earthRadius); % 1 m in lat
dLong1Meter = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long

RatioLatLong = dLat1Meter/dLong1Meter;
daspect([1, RatioLatLong, 1])

%% Creation of a folder where save model and future predictions
cd(fold_res_ml)
EventDate.Format = 'dd-MM-yyyy';
MLFolderName = char(inputdlg({'Choose a folder name (inside Results->ML Models and Predictions):'}, ...
                                '', 1, {['ML-ANNs-Event-',char(EventDate)]} ));

if exist(MLFolderName, 'dir')
    Options = {'Yes, thanks', 'No, for God!'};
    Answer  = uiconfirm(Fig, strcat(MLFolderName, " is an existing folder. Do you want to overwrite it?"), ...
                             'Existing ML Folder', 'Options',Options, 'DefaultOption',2);
    switch Answer
        case 'Yes, thanks.'
            rmdir(MLFolderName,'s')
            mkdir(MLFolderName)
        case 'No, for God!'
            return
    end
else
    mkdir(MLFolderName)
end

fold_res_ml_curr = [fold_res_ml,sl,MLFolderName];

%% Saving...
ProgressBar.Message = "Saving files...";
cd(fold_res_ml_curr)
VariablesML = {'ANNModels', 'ANNModelsROCTrain', 'ANNModelsROCTest', ...
               'DatasetFeatsStudyNotNorm', 'DatasetFeatsStudyNorm', 'DatasetCoordinatesStudy', ...
               'UnstablePolygons', 'IndecisPolygons', 'StablePolygons', ...
               'UnstablePolyMrgd', 'IndecisPolyMrgd', 'StablePolyMrgd', ...
               'RangesForNorm', 'Categs', 'AnalysisInformation', ...
               'R2ForDatasetFeatsStudyNorm', 'R2ForDatasetFeatsStudyNotNorm'};
save('TrainedANNs.mat', VariablesML{:})
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in standalone version