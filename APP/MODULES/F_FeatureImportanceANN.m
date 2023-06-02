% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
load([fold_res_ml_curr,sl,'TrainedANNs.mat'], 'ANNs','ANNsPerf', 'ModelInfo')

%% Feature importance choice
Options = {'FeaturePermutation', 'Weights'};
FeatImpChoice = uiconfirm(Fig, 'Which method do you want to use?', ...
                               'Feature importance', 'Options',Options, 'DefaultOption',1);

Options = {'Only Train', 'Only Test', 'Train + Test'};
DatasetChoice = uiconfirm(Fig, 'What dataset do you want to use to define feature importance?', ...
                               'Feature imp dataset', 'Options',Options, 'DefaultOption',1);

ModelInfo.FeatsImportanceMethod  = FeatImpChoice;
ModelInfo.FeatsImportanceDataset = DatasetChoice;

%% Definition of dataset
switch DatasetChoice
    case 'Only Train'
        DatasetFullToUse = ModelInfo.DatasetFeatsTrain{:};
        ExpOutsToUse     = ModelInfo.ExpextedOutsTrain{:};

    case 'Only Test'
        DatasetFullToUse = ModelInfo.DatasetFeatsTest{:};
        ExpOutsToUse     = ModelInfo.ExpextedOutsTest{:};

    case 'Train + Test'
        DatasetFullToUse = [ModelInfo.DatasetFeatsTrain{:}; ModelInfo.DatasetFeatsTest{:}];
        ExpOutsToUse     = [ModelInfo.ExpextedOutsTrain{:}; ModelInfo.ExpextedOutsTest{:}];
end

%% Features importance computation
switch FeatImpChoice
    case 'FeaturePermutation'
        %% Feature Permutation
        ANNs{'FeatsImportance',:} = {missing};
        ProgressBar.Indeterminate = 'off';
        for IndCurrMdl = 1:size(ANNs,2)
            ProgressBar.Value   = IndCurrMdl/size(ANNs,2);
            ProgressBar.Message = strcat("Evaluating feature importance for model n. ", string(IndCurrMdl)," of ", string(size(ANNs,2)));
        
            CurrModel = ANNs{'Model',IndCurrMdl}{:};
            CurrFeats = ANNs{'FeatsConsidered',IndCurrMdl}{:};
            
            DatasetToUse = DatasetFullToUse(:,CurrFeats);
            
            [~, CurrPredProb] = predict(CurrModel, DatasetToUse);
            CurrPredProb = CurrPredProb(:,2);
            
            CurrLoss = loss(CurrModel, DatasetToUse, ExpOutsToUse);
            CurrMSE  = mse(ExpOutsToUse, CurrPredProb);
            
            rng(17) % To control the randomization process
            NumOfTimeToRand = 5;
            IndRand  = zeros(size(DatasetToUse, 1), NumOfTimeToRand);
            [PermLoss, PermMSE] = deal(zeros(NumOfTimeToRand, length(CurrFeats)));
            for i1 = 1:NumOfTimeToRand
                IndRand(:,i1) = randperm(size(DatasetToUse, 1));
                for i2 = 1:length(CurrFeats)
                    DatasetPerm = DatasetToUse;
                    DatasetPerm{:,CurrFeats{i2}} = DatasetPerm{IndRand(:,i1),CurrFeats{i2}};
            
                    [~, PredProbPerm] = predict(CurrModel, DatasetPerm);
                    PredProbPerm = PredProbPerm(:,2);
            
                    PermLoss(i1,i2) = loss(CurrModel, DatasetPerm, ExpOutsToUse);
                    PermMSE(i1,i2)  = mse(ExpOutsToUse, PredProbPerm);
                end
            end
        
            MeanPermLoss  = max(PermLoss, [], 1); % You can also average values: mean(PermLoss,1);
            MeanPermMSE   = max(PermMSE, [], 1);  % You can also average values: mean(PermLoss,1);
        
            % StDevPermLoss = std(PermLoss,1,1);
            % StDevPermMSE  = std(PermMSE,1,1);
        
            FeatImpDiffLoss = MeanPermLoss-CurrLoss;
            FeatImpDiffMSE  = MeanPermMSE-CurrMSE;
        
            FeatImpPercLoss = max(FeatImpDiffLoss,0)/sum(max(FeatImpDiffLoss,0));
            FeatImpPercMSE  = max(FeatImpDiffMSE,0)/sum(max(FeatImpDiffMSE,0));
        
            TableFeatImp = array2table([FeatImpDiffLoss; FeatImpDiffMSE; FeatImpPercLoss; FeatImpPercMSE], ...
                                       'RowNames',{'LossDifferences', 'MSEDifferences', 'PercentagesLoss', 'PercentagesMSE'}, ...
                                       'VariableNames',CurrFeats);
            
            ANNs{'FeatsImportance',IndCurrMdl} = {TableFeatImp};
        end
        ProgressBar.Indeterminate = 'on';

    case 'Weights'
        %% Feature Importance Weights (available for single layer ANNs)
        ANNs{'FeatsImportance',:} = {missing};
        ProgressBar.Indeterminate = 'off';
        for IndCurrMdl = 1:size(ANNs,2)
            ProgressBar.Value   = IndCurrMdl/size(ANNs,2);
            ProgressBar.Message = ['Evaluating feature importance for model n. ', num2str(IndCurrMdl),' of ', num2str(size(ANNs,2))];
        
            CurrModel = ANNs{'Model',IndCurrMdl}{:};
            CurrFeats = ANNs{'FeatsConsidered',IndCurrMdl}{:};
        
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
        
            TableFeatImp = array2table(FeatImpWeights, 'RowNames',RowTableNames, 'VariableNames',CurrFeats);
            
            ANNs{'FeatsImportance',IndCurrMdl} = {TableFeatImp};
        end
end

%% Saving...
VariablesToUpdate = {'ANNs', 'ModelInfo'};
save([fold_res_ml_curr,sl,'TrainedANNs.mat'], VariablesToUpdate{:}, '-append');