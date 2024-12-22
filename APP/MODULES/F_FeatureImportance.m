if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data
sl = filesep;
fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');

MdlType = find([exist([fold_res_ml_curr,sl,'MLMdlA.mat'], 'file'), ...
                exist([fold_res_ml_curr,sl,'MLMdlB.mat'], 'file')]);
if not(isscalar(MdlType)); error('More than one model found in your folder!'); end
switch MdlType
    case 1
        Fl2LdMdl = 'MLMdlA.mat';
        load([fold_res_ml_curr,sl,Fl2LdMdl], 'MLMdl','ModelInfo')
        NormData = false;
        DsetInfo = ModelInfo.Dataset;

    case 2
        Fl2LdMdl = 'MLMdlB.mat';
        load([fold_res_ml_curr,sl,Fl2LdMdl], 'MLMdl','ModelInfo')
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
        warning('It would be better to use AllRange permutation if your dataset is normalized!')
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
ProgressBar.Indeterminate = 'off';
MLMdl{'FeatsImportance',:} = {missing};
for IndCurrMdl = 1:size(MLMdl,2)
    ProgressBar.Value   = IndCurrMdl/size(MLMdl,2);
    ProgressBar.Message = ['Assessing feat imp for model n. ',num2str(IndCurrMdl),' of ',num2str(size(MLMdl,2))];

    CurrModel = MLMdl{'Model',IndCurrMdl}{:};
    CurrFeats = MLMdl{'FeatsConsidered',IndCurrMdl}{:};

    switch FeatImpChc
        case 'FeaturePermutation'
            DatasetToUse = DsetFtIm2Use(:,CurrFeats);
            TableFeatImp = feature_permutation(CurrModel, DatasetToUse, ...
                                               ExOtFtIm2Use, 'PermType',PermType, ...
                                                             'RandIters',Time2Rand);
    
        case 'Weights' % Available just for single layer ANNs          
            if length(CurrModel.LayerSizes) > 1
                warning(['Hidden layers of model n. ',num2str(IndCurrMdl),' are more than 1. This model will be skipped!'])
                continue % To skip this cycle if hiddens are > 1
            end
        
            WgsInp2Hid = CurrModel.LayerWeights{1, 1}; % Weights between input and hidden layers
            WgsHid2Out = CurrModel.LayerWeights{1, 2}'; % Weights between hidden and output layers
            InpsNumber = size(WgsInp2Hid,2); % number of input varables
            OutsNumber = size(WgsHid2Out,2); % number of output neurons
        
            FeatImpWgs = zeros(OutsNumber, InpsNumber);
            for i1 = 1:OutsNumber
                FeatPrtImp = zeros(1, InpsNumber);
                for i2 = 1:InpsNumber
                    FeatPrtImp(i2) = sum((abs(WgsInp2Hid(:,i2))./sum(abs(WgsInp2Hid),2)).*abs(WgsHid2Out(:,i1)), 'all');
                end
        
                for i2 = 1:InpsNumber
                    FeatImpWgs(i1,i2) = (FeatPrtImp(i2)/sum(FeatPrtImp)); % Percentages if you multiply by 100
                end
            end
        
            RowTblNms = arrayfun(@(x) ['PercentagesOut-',num2str(x)], 1:OutsNumber, 'UniformOutput',false);
        
            TableFeatImp = array2table(FeatImpWgs, 'RowNames',RowTblNms, 'VariableNames',CurrFeats);

        otherwise
            error('Method not recognized!')
    end

    MLMdl{'FeatsImportance',IndCurrMdl} = {TableFeatImp};
end
ProgressBar.Indeterminate = 'on';

%% Saving...
VariablesToUpdate = {'MLMdl', 'ModelInfo'};
save([fold_res_ml_curr,sl,Fl2LdMdl], VariablesToUpdate{:}, '-append');