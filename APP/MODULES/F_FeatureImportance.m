if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data
sl = filesep;
fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');

MdlType = find([exist([fold_res_ml_curr,sl,'ANNsMdlA.mat'], 'file'), ...
                exist([fold_res_ml_curr,sl,'ANNsMdlB.mat'], 'file')]);
if not(isscalar(MdlType)); error('More than one model found in your folder!'); end
switch MdlType
    case 1
        Fl2LdMdl = 'ANNsMdlA.mat';
        load([fold_res_ml_curr,sl,Fl2LdMdl], 'ANNs','ModelInfo')
        NormData = false;
        DsetInfo = ModelInfo.Dataset;

    case 2
        Fl2LdMdl = 'ANNsMdlB.mat';
        load([fold_res_ml_curr,sl,Fl2LdMdl], 'ANNs','ModelInfo')
        NormData = ModelInfo.DatasetInfo{:}{1,'NormalizedData'};
        DsetInfo = ModelInfo.DatasetInfo{:};

    otherwise
        error('No trained ModelA or B found!')
end

%% Feature importance choice
FeatImpAns = listdlg2({'Method', 'Dataset'}, {{'FeaturePermutation', 'Weights'}, ...
                                              {'Only Train', 'Only Test', 'Train + Test'}});
FeatImpChc = FeatImpAns{1};
FeatImpDst = FeatImpAns{2};

if strcmp(FeatImpChc, 'FeaturePermutation')
    PermType = char(listdlg2({'Permutation values'}, {'Shuffle', 'AllRange'}));
    if not(NormData) && strcmp(PermType, 'AllRange')
        error('You can not use AllRange permutation if your dataset is not normalized!')
    end

    Time2Rand = int64(str2double(inputdlg2({'Permutation times'}, 'DefInp',{'5'})));
    Vals2UseN = linspace(0, 1, Time2Rand);
end

% Update Model Info
ModelInfo.FeatureImportance = struct('Method',FeatImpChc, 'Dataset',FeatImpDst);
if strcmp(FeatImpChc, 'FeaturePermutation')
    ModelInfo.FeatureImportance.PermType = PermType;
end

%% Extraction of datasets
DsetTbl = dataset_extraction(DsetInfo);
switch FeatImpDst
    case 'Only Train'
        DsetFtIm2Use = DsetTbl{'Train','Feats'  }{:};
        ExOtFtIm2Use = DsetTbl{'Train','ExpOuts'}{:};

    case 'Only Test'
        DsetFtIm2Use = DsetTbl{'Test','Feats'  }{:};
        ExOtFtIm2Use = DsetTbl{'Test','ExpOuts'}{:};

    case 'Train + Test'
        DsetFtIm2Use = DsetTbl{'Total','Feats'  }{:};
        ExOtFtIm2Use = DsetTbl{'Total','ExpOuts'}{:};
end

%% Features importance computation
switch FeatImpChc
    case 'FeaturePermutation'
        %% Feature Permutation
        ANNs{'FeatsImportance',:} = {missing};
        ProgressBar.Indeterminate = 'off';
        for IndCurrMdl = 1:size(ANNs,2)
            ProgressBar.Value   = IndCurrMdl/size(ANNs,2);
            ProgressBar.Message = strcat("Evaluating feature importance for model n. ", string(IndCurrMdl)," of ", string(size(ANNs,2)));
        
            CurrModel = ANNs{'Model',IndCurrMdl}{:};
            CurrFeats = ANNs{'FeatsConsidered',IndCurrMdl}{:};
            
            DatasetToUse = DsetFtIm2Use(:,CurrFeats);

            TableFeatImp = feature_permutation(CurrModel, DatasetToUse, ExOtFtIm2Use, 'PermType',PermType, 'RandIters',Time2Rand);
            
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
save([fold_res_ml_curr,sl,Fl2LdMdl], VariablesToUpdate{:}, '-append');