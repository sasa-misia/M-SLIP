% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
cd(fold_var)
load('TrainedANNs.mat', 'ANNModels','AnalysisInformation')
cd(fold0)

%% Feature importance choice
Options = {'FeaturePermutation', 'Weights'};
FeatImpChoice = uiconfirm(Fig, 'Which method do you want to use?', ...
                               'Feature importance', 'Options',Options, 'DefaultOption',1);

switch FeatImpChoice
    case 'FeaturePermutation'
        %% Feature Permutation
        AnalysisInformation.FeatureImportanceMode = FeatImpChoice;
        ANNModels{'FeatureImportance',:} = {missing};
        ProgressBar.Indeterminate = 'off';
        for IndCurrMdl = 1:size(ANNModels,2)
            ProgressBar.Value   = IndCurrMdl/size(ANNModels,2);
            ProgressBar.Message = strcat("Evaluating feature importance for model n. ", string(IndCurrMdl)," of ", string(size(ANNModels,2)));
        
            CurrModel       = ANNModels{'Model',IndCurrMdl}{:};
            CurrPredictors  = ANNModels{'ConditioningFactorsNames',IndCurrMdl}{:};
            
            DatasetToUse    = [ANNModels{'DatasetTrain',IndCurrMdl}{:}; ANNModels{'DatasetTest',IndCurrMdl}{:}];
            RealOutputToUse = [ANNModels{'OutputTrain',IndCurrMdl}{:};  ANNModels{'OutputTest',IndCurrMdl}{:}];
            
            [~, CurrPredProb] = predict(CurrModel, DatasetToUse);
            CurrPredProb = CurrPredProb(:,2);
            
            CurrLoss = loss(CurrModel, DatasetToUse, RealOutputToUse);
            CurrMSE  = mse(RealOutputToUse, CurrPredProb);
            
            rng(17) % To control the randomization process
            NumOfTimeToRand = 5;
            IndRand  = zeros(size(DatasetToUse, 1), NumOfTimeToRand);
            [PermLoss, PermMSE] = deal(zeros(NumOfTimeToRand, length(CurrPredictors)));
            for i1 = 1:NumOfTimeToRand
                IndRand(:,i1) = randperm(size(DatasetToUse, 1));
                for i2 = 1:length(CurrPredictors)
                    DatasetPerm = DatasetToUse;
                    DatasetPerm{:,CurrPredictors{i2}} = DatasetPerm{IndRand(:,i1),CurrPredictors{i2}};
            
                    [~, PredProbPerm] = predict(CurrModel, DatasetPerm);
                    PredProbPerm = PredProbPerm(:,2);
            
                    PermLoss(i1,i2) = loss(CurrModel, DatasetPerm, RealOutputToUse);
                    PermMSE(i1,i2)  = mse(RealOutputToUse, PredProbPerm);
                end
            end
        
            MeanPermLoss  = mean(PermLoss,1);
            MeanPermMSE   = mean(PermMSE,1);
        
            StDevPermLoss = std(PermLoss,1,1);
            StDevPermMSE  = std(PermMSE,1,1);
        
            FeatImpDiffLoss = MeanPermLoss-CurrLoss;
            FeatImpDiffMSE  = MeanPermMSE-CurrMSE;
        
            FeatImpPercLoss = max(FeatImpDiffLoss,0)/sum(max(FeatImpDiffLoss,0));
            FeatImpPercMSE  = max(FeatImpDiffMSE,0)/sum(max(FeatImpDiffMSE,0));
        
            TableFeatImp = array2table([FeatImpDiffLoss; FeatImpPercLoss; FeatImpDiffMSE; FeatImpPercMSE], ...
                                       'RowNames',{'LossDifferences', 'PercentagesLoss', 'MSEDifferences', 'PercentagesMSE'});
            TableFeatImp.Properties.VariableNames = CurrPredictors;
            
            ANNModels{'FeatureImportance',IndCurrMdl} = {TableFeatImp};
        end
        ProgressBar.Indeterminate = 'on';

    case 'Weights'
        %% Feature Importance Weights (available for single layer ANNs)
        AnalysisInformation.FeatureImportanceMode = FeatImpChoice;
        ANNModels{'FeatureImportance',:} = {missing};
        ProgressBar.Indeterminate = 'off';
        for IndCurrMdl = 1:size(ANNModels,2)
            ProgressBar.Value   = IndCurrMdl/size(ANNModels,2);
            ProgressBar.Message = ['Evaluating feature importance for model n. ', num2str(IndCurrMdl),' of ', num2str(size(ANNModels,2))];
        
            CurrModel       = ANNModels{'Model',IndCurrMdl}{:};
            CurrPredictors  = ANNModels{'ConditioningFactorsNames',IndCurrMdl}{:};
        
            if length(CurrModel.LayerSizes) > 1
                warning(['Hidden layers of model n. ',num2str(IndCurrMdl),' are more than 1. This model will be skipped!'])
                continue % To skip this cycle if hiddens are > 1
            end
        
            WeightsInpToHid = CurrModel.LayerWeights{1, 1}; % Weights between input and hidden layers
            WeightsHidToOut = CurrModel.LayerWeights{1, 2}'; % Weights between hidden and output layers
            NumOfInputs     = size(WeightsInpToHid,2); % number of input varables
            NumOfOutputs    = size(WeightsHidToOut,2); % number of output neurons
        
            FeatImpWeights = zeros(NumOfOutputs, NumOfInputs);
            for i1 = 1:NumOfOutputs
                FeatPartImp = zeros(1, NumOfInputs);
                for i2 = 1:NumOfInputs
                    FeatPartImp(i2) = sum((abs(WeightsInpToHid(:,i2))./sum(abs(WeightsInpToHid),2)).*abs(WeightsHidToOut(:,i1)), 'all');
                end
        
                for i2 = 1:NumOfInputs
                    FeatImpWeights(i1,i2) = (FeatPartImp(i2)/sum(FeatPartImp)); % Percentages if you multiply by 100
                end
            end
        
            RowTableNames = arrayfun(@(x) ['PercentagesOutput-',num2str(x)], 1:NumOfOutputs, 'UniformOutput',false);
        
            TableFeatImp = array2table(FeatImpWeights, 'RowNames',RowTableNames);
            TableFeatImp.Properties.VariableNames = CurrPredictors;
            
            ANNModels{'FeatureImportance',IndCurrMdl} = {TableFeatImp};
        end
end

%% Saving...
cd(fold_var)
VariablesToUpdate = {'ANNModels', 'AnalysisInformation'};
save('TrainedANNs.mat', VariablesToUpdate{:}, '-append');
cd(fold0)