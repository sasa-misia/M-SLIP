if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

rng(10) % For reproducibility of the model

%% Loading data, extraction and initialization of variables
sl = filesep;
load([fold_var,sl,'DatasetMLB.mat'], 'DatasetInfo','Rngs4Norm')

UnstabPolygons = cat(1, DatasetInfo.PolysUnstable{:});
IndecnPolygons = cat(1, DatasetInfo.PolysIndecision{:});
StablePolygons = cat(1, DatasetInfo.PolysStable{:});

TmSensMode = 'NoTimeSens';
TimeSensEx = any(strcmp('TimeSensitive', DatasetInfo{1,'FeaturesTypes'}{:}));
if TimeSensEx
    EventDates = DatasetInfo.EventDate;
    TmSensMode = DatasetInfo{1,'TimeSensMode'};
    TmSnParams = DatasetInfo{1,'TSParameters'}{:};
    Days4TmSns = DatasetInfo{1,'DaysForTS'};
    if DatasetInfo{1,'MultipleDays'}
        DaysBeforeEventWhenStable = DatasetInfo{1,'DayBeforeEvent'};
    end
end

ExistNrV = DatasetInfo{1,'NormValidSet' };
ExistCrV = DatasetInfo{1,'CrossValidSet'};

if ExistCrV
    kFldNm = DatasetInfo{1, 'DsetSplitMetr'}.CVFolds;
end

FeatsNms = DatasetInfo{1,'FeaturesNames'}{:};
FeatsNTS = not(strcmp('TimeSensitive', DatasetInfo{1,'FeaturesTypes'}{:}));

ModelInfo = table("ANN FF FC", {DatasetInfo}, 'VariableNames',{'Type', 'DatasetInfo'});

%% Dataset extraction and filtering
DsetTpe = char(listdlg2({'Dataset to consider?'}, {'1T', '2T', 'All', 'Manual'}));
DsetTbl = dataset_extr_filtr(DatasetInfo, fltrCase=DsetTpe);

%% ANN Options
ProgressBar.Message = 'ANN options...';

switch TmSensMode
    case 'SeparateDays'
        FeatsNmsTS = cellfun(@(x) strcat(x,'-',string(1:Days4TmSns)','daysBefore'), TmSnParams, 'UniformOutput',false); % Remember to change this line if you change feats names in datasetstudy_creation function!

    case {'CondensedDays', 'TriggerCausePeak', 'NoTimeSens'}

    otherwise
        error('Time sensitive mode not recognized!')
end

MdlOpt = checkbox2({'Compact models', 'Structures filter', 'Standardize inputs', ...
                    'Manual structures', 'Check plot', 'Modified cost', 'DeepPlot'}, ...
                                'DefInp',[1, 0, 1, 0, 0, 0, 0], 'OutType','LogInd');
CmpMdl = MdlOpt(1);
StrFlt = MdlOpt(2); % To implement! Look Model A!
StdInp = MdlOpt(3);
MnStrc = MdlOpt(4);
ChkPlt = MdlOpt(5);
CstMod = MdlOpt(6);
DpPlot = MdlOpt(7);

LaySizeRw = {nan}; % Default, when you have for example 'Auto' mode!

Options = {'Classic (V)', 'Classic (L)', 'Auto', ...
           'Cross Validation (K-Fold M)', ...
           'Cross Validation (K-Fold V)', ...
           'Deep (L)', 'Deep (V)'};
ANNMode = char(listdlg2('Type of train?', Options));
if not(contains(ANNMode, 'Auto', 'IgnoreCase',true))
    if MnStrc
        Strct2Use = inputdlg2({'Specify structure n.1:'}, 'Extendable',true, 'DefInp',{'[1, 1, 1, 1]'});
        LaySizeRw = cellfun(@str2num, Strct2Use, 'UniformOutput',false);
        HiddenNum = max(cellfun(@numel, LaySizeRw));

    else 
        StructInp = inputdlg2({'Max neurons per layer:', 'Increase of neurons:'}, 'DefInp',{'[100, 200]', '20'});
        
        MaxNmNeur = str2num(StructInp{1});
        Nr2Add4St = str2double(StructInp{2});

        HiddenNum = numel(MaxNmNeur);
    
        % Creation of permutations for possible structures
        [Neur2Trn4Mdl, MdlNeurCmbs] = deal(cell(1, HiddenNum));
        for i1 = 1:HiddenNum
            Neur2Trn4Mdl{i1} = [1, Nr2Add4St:Nr2Add4St:MaxNmNeur(i1)];
            if Nr2Add4St == 1; Neur2Trn4Mdl{i1}(1) = []; end
            MdlNeurCmbs{i1} = combvec(Neur2Trn4Mdl{1:i1});
        end
    
        CmbntsNum = sum(cellfun(@(x) size(x, 2), MdlNeurCmbs));
        LaySizeRw = cell(1, CmbntsNum);
        i3 = 1;
        for i1 = 1:HiddenNum
            for i2 = 1:size(MdlNeurCmbs{i1}, 2)
                LaySizeRw{i3} = MdlNeurCmbs{i1}(:,i2)';
                i3 = i3+1;
            end
        end

        if StrFlt
            if numel(LaySizeRw) > 1000
                StrHidd = str2double(inputdlg2('Min num of hidden layers:', 'DefInp',{'2'}));
                if StrHidd > numel(MaxNmNeur)
                    error(['You can not select a minimum number of hidden ', ...
                           'greater than your structure defined earlier!'])
                end
                IdLyr2Mnt = cellfun(@(x) numel(x)>=StrHidd, LaySizeRw);
                LaySizeRw = LaySizeRw(IdLyr2Mnt);
            else
                PrmptsFlt = cellfun(@(x) join(string(x),'_'), LaySizeRw);
                IdLyr2Mnt = checkbox2(PrmptsFlt, 'OutType','NumInd');
                LaySizeRw = LaySizeRw(IdLyr2Mnt);
            end
        end
    end

    LayOpt = {'sigmoid', 'relu', 'tanh', 'none'};
    if contains(ANNMode, 'Deep', 'IgnoreCase',true)
        LayOpt = [LayOpt, {'elu','gelu','softplus'}];
    end
    LyrPrm = strcat({'Activation fn layer '},string(1:HiddenNum));
    LyrAct = listdlg2(LyrPrm, LayOpt);

    if contains(ANNMode, 'Deep', 'IgnoreCase',true)
        HypParDp1 = listdlg2({'Solver:', 'Final model:', 'Drop learn rate:', 'Weights initializer:', 'Droput?'}, ...
                             { {'sgdm','rmsprop','adam','lbfgs'}, ...
                               {'last-iteration','best-validation'}, ...
                               {'No','Yes'}, ...
                               {'glorot','he','zeros','orthogonal'}, ...
                               {'No', 'Yes'} });
        DeepSolvr = HypParDp1{1};
        FinOutNet = HypParDp1{2};
        DropSched = HypParDp1{3};
        WghtsInit = HypParDp1{4};
        UseDrpOut = HypParDp1{5};

        if strcmp(DropSched,'Yes'); DropSched = true; else; DropSched = false; end
        if strcmp(UseDrpOut,'Yes'); UseDrpOut = true; else; UseDrpOut = false; end

        HypParDp2 = inputdlg2({'Initial learn rate:'}, 'DefInp',{'0.015'});
        InitLrnRt = str2double(HypParDp2{1});

        if DpPlot
            DpMetr = checkbox2({'auc', 'fscore', 'precision', 'recall'}, ...
                               'Title',{'Metrics to plot with deep net:'}, 'DefInp',[1, 1, 1, 1]);
        end
    end

    TunPar = inputdlg2({'Iterations limit:', 'L2 Regularization:', ...
                        'Gradient tolerance:', 'LossTolerance:', ...
                        'Step tolerance:'}, 'DefInp',{'300', '1e-7', '1e-8', '1e-5', '1e-7'});
    ItrLim = str2double(TunPar{1});
    RegStg = str2double(TunPar{2});
    GrdTol = str2double(TunPar{3});
    LssTol = str2double(TunPar{4});
    StpTol = str2double(TunPar{5});

    if contains(ANNMode, '(V)', 'IgnoreCase',true) || contains(ANNMode, 'Validation', 'IgnoreCase',true)
        TunPr2 = inputdlg2({'Validation frequency:', 'Validation patience:'}, 'DefInp',{'4', '8'});
        ValFrq = str2double(TunPr2{1});
        ValPat = str2double(TunPr2{2});
    end
    
    ClssNum = unique(DsetTbl{'Total','ExpOuts'}{:});
    CostMat = ones(numel(ClssNum), numel(ClssNum)) - eye(numel(ClssNum), numel(ClssNum));
    if CstMod
        NewCost = str2double(inputdlg2({'New cost for landslide class:'}, 'DefInp',{'3'}));
        IndRows = ClssNum ~= 0;
        CostMat(IndRows, :) = NewCost.*CostMat(IndRows,:);
    end
end

if contains(ANNMode, 'Auto', 'IgnoreCase',true)
    MaxEvA = str2double(inputdlg2({'Maximum number of evaluations:'}, 'DefInp',{'20'}));
end

BstThrMthd = char(listdlg2({'Optimal threshold mode?'}, ...
                           {'MATLAB', 'MaximizeRatio-TPR-FPR', 'MaximizeArea-TPR-TNR'}));

%% Adding vars to ModelInfo
ModelInfo.MdlMode      = ANNMode;
ModelInfo.TimeSensMode = TmSensMode;
if not(strcmp(ANNMode, 'Auto'))
    ModelInfo.ActivationFunUsed = LyrAct;
    ModelInfo.StandardizedInput = StdInp;
    % ModelInfo.ANNsStructures = array2table(MdlNeurCmbs, 'VariableNames',strcat(string(1:length(MdlNeurCmbs)),"Layers"));
end
ModelInfo.BestThrMethod = BstThrMthd;
ModelInfo.RangesForNorm = {Rngs4Norm};

%% Initialization of variables for loops
MLRws = {'Model', 'FeatsConsidered', 'Structure'}; % If you touch these, please modify row below when you write ANNs
MLMdl = table('RowNames',MLRws);

MLRsR = {'ProbsTrain', 'ProbsTest'}; % If you touch these, please modify row below when you write ANNsRes
MLRes = table('RowNames',MLRsR);

CrssVal = false;
if contains(ANNMode, 'Cross Validation', 'IgnoreCase',true)
    CrssVal = true;
end

%% Feats to consider for each model
switch TmSensMode
    case 'SeparateDays'
        %% Separate Days
        ANNsNumber = Days4TmSns*length(LaySizeRw); % DaysForTS because you repeat the same structure n times as are the number of days that I can consider independently.
        [FeatsCnsid, LayerSizes] = deal(cell(1, ANNsNumber));
        i3 = 0;
        for i1 = 1:length(LaySizeRw)
            for i2 = 1:Days4TmSns
                i3 = i3 + 1;

                TSFeatsToTake = cellfun(@(x) x(1:i2)', FeatsNmsTS, 'UniformOutput',false); % WRONG!
                TSFeatsToTake = cellstr(cat(2, TSFeatsToTake{:}));

                FeatsCnsid{i3} = [FeatsNms(FeatsNTS), TSFeatsToTake];
                LayerSizes{i3} = LaySizeRw{i1}; % Structures must be repeated because you have different inputs!
            end
        end

    case {'CondensedDays', 'TriggerCausePeak', 'NoTimeSens'}
        ANNsNumber = length(LaySizeRw);
        LayerSizes = LaySizeRw;
        FeatsCnsid = repmat({FeatsNms}, 1, ANNsNumber);

    otherwise
        error('Time Sensitive mode not recognized while defining features to take!')
end

%% Training loops
[TrnLss, TrnMSE, TstLss, TstMSE] = deal(zeros(1,ANNsNumber));
if ExistCrV
    [CrossMdls, CrossTrnInd, CrossValInd] = deal(cell(kFldNm, ANNsNumber));
    [CrossTrnMSE, CrossValMSE, CrossTstMSE, ...
        CrossTrnAUC, CrossValAUC, CrossTstAUC] = deal(zeros(kFldNm, ANNsNumber));
end

ProgressBar.Indeterminate = 'off';
for i1 = 1:ANNsNumber
    ProgressBar.Value = i1/ANNsNumber;
    ProgressBar.Message = ['Training model n. ',num2str(i1),' of ',num2str(ANNsNumber)];

    DsetTrn = DsetTbl{'Train','Feats'}{:}(:, FeatsCnsid{i1});
    DsetTst = DsetTbl{'Test' ,'Feats'}{:}(:, FeatsCnsid{i1});

    ExOtTrn = DsetTbl{'Train','ExpOuts'}{:};
    ExOtTst = DsetTbl{'Test' ,'ExpOuts'}{:};

    if ExistNrV
        DsetNvT = DsetTbl{'NvTrain','Feats'}{:}(:, FeatsCnsid{i1});
        DsetNvV = DsetTbl{'NvValid','Feats'}{:}(:, FeatsCnsid{i1});

        ExOtNvT = DsetTbl{'NvTrain','ExpOuts'}{:};
        ExOtNvV = DsetTbl{'NvValid','ExpOuts'}{:};
    end

    if ExistCrV
        DsetCvT = cellfun(@(x) x(:, FeatsCnsid{i1}), DsetTbl{'CvTrain','Feats'}{:}, 'UniformOutput',false);
        DsetCvV = cellfun(@(x) x(:, FeatsCnsid{i1}), DsetTbl{'CvValid','Feats'}{:}, 'UniformOutput',false);
        
        ExOtCvT = DsetTbl{'CvTrain','ExpOuts'}{:};
        ExOtCvV = DsetTbl{'CvValid','ExpOuts'}{:};
    end

    CLN = numel(LayerSizes{i1});

    switch ANNMode
        case 'Auto'
            Model = fitcnet(DsetTrn, ExOtTrn, 'OptimizeHyperparameters','all', ...
                                      'HyperparameterOptimizationOptions', struct('MaxObjectiveEvaluations',MaxEvA, ...
                                                                                  'Optimizer','bayesopt', 'MaxTime',Inf, ...
                                                                                  'AcquisitionFunctionName','expected-improvement-plus', ...
                                                                                  'ShowPlots',true, 'Verbose',1, 'Kfold',kFldNm, ...
                                                                                  'UseParallel',false, 'Repartition',true));
            LayerSizes{i1} = Model.LayerSizes;

        case 'Classic (L)'
            Model = fitcnet(DsetTrn, ExOtTrn, 'LayerSizes',LayerSizes{i1}, 'Activations',LyrAct(1:CLN), ...
                                              'Standardize',StdInp, 'Lambda',RegStg, ...
                                              'IterationLimit',ItrLim, 'GradientTolerance',GrdTol, ...
                                              'LossTolerance',LssTol, 'StepTolerance',StpTol);

            FailCg = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
            if FailCg
                warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
            end

        case 'Classic (V)'
            Model = fitcnet(DsetNvT, ExOtNvT, 'ValidationData',{DsetNvV, ExOtNvV}, ...
                                              'ValidationFrequency',ValFrq, 'ValidationPatience',ValPat, ...
                                              'LayerSizes',LayerSizes{i1}, 'Activations',LyrAct(1:CLN), ...
                                              'Standardize',StdInp, 'Lambda',RegStg, ...
                                              'IterationLimit',ItrLim, 'Cost',CostMat);

            FailCg = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
            if FailCg
                warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
            end

        case 'Cross Validation (K-Fold M)'
            ModelCV = fitcnet(DsetTrn, ExOtTrn, 'LayerSizes',LayerSizes{i1}, 'Activations',LyrAct(1:CLN), ...
                                                'Standardize',StdInp, 'Lambda',RegStg, ...
                                                'IterationLimit',ItrLim, 'GradientTolerance',GrdTol, ...
                                                'LossTolerance',LssTol, 'StepTolerance',StpTol, ...
                                                'Crossval','on', 'KFold',kFldNm, 'Cost',CostMat); % Remember that instead of 'KFold' you can use for example: 'Holdout',0.1

            for i2 = 1:kFldNm
                CrossMdls{i2, i1} = ModelCV.Trained{i2};
                % if CmpMdl; CrossMdls{i2, i1} = compact(CrossMdls{i2, i1}); end % Already compact!

                CrossTrnInd{i2, i1} = training(ModelCV.Partition, i2);
                CrossValInd{i2, i1} = test(ModelCV.Partition, i2);

                DsetTrnTmp = DsetTrn(CrossTrnInd{i2, i1}, :);
                DsetValTmp = DsetTrn(CrossValInd{i2, i1}, :);

                ExOtTrnTmp = ExOtTrn(CrossTrnInd{i2, i1}, :);
                ExOtValTmp = ExOtTrn(CrossValInd{i2, i1}, :);

                PredsCrossTrnTmp = mdlpredict(ModelCV.Trained{i2}, DsetTrnTmp, 'SingleCol',true); % Thanks to SingleCol, outputs are always in 1 column!
                PredsCrossValTmp = mdlpredict(ModelCV.Trained{i2}, DsetValTmp, 'SingleCol',true);
                PredsCrossTstTmp = mdlpredict(ModelCV.Trained{i2}, DsetTst   , 'SingleCol',true);

                CrossTrnMSE(i2, i1) = mse(PredsCrossTrnTmp, double(ExOtTrnTmp >= 1));
                CrossValMSE(i2, i1) = mse(PredsCrossValTmp, double(ExOtValTmp >= 1));
                CrossTstMSE(i2, i1) = mse(PredsCrossTstTmp, double(ExOtTst    >= 1));
    
                [~, ~, ~, CrossTrnAUC(i2, i1), ~] = perfcurve(double(ExOtTrnTmp >= 1), PredsCrossTrnTmp, 1);
                [~, ~, ~, CrossValAUC(i2, i1), ~] = perfcurve(double(ExOtValTmp >= 1), PredsCrossValTmp, 1);
                [~, ~, ~, CrossTstAUC(i2, i1), ~] = perfcurve(double(ExOtTst    >= 1), PredsCrossTstTmp, 1);
            end

            LossesOfModels = kfoldLoss(ModelCV, 'Mode','individual');
            [~, IndBstMdl] = min(LossesOfModels);
            Model = ModelCV.Trained{IndBstMdl};
        
        case 'Cross Validation (K-Fold V)'
            FailCg = false(1, numel(DsetTst));
            for i2 = 1:kFldNm
                CurrMdlCV = fitcnet(DsetCvT{i2}, ExOtCvT{i2}, 'ValidationData',{DsetCvV{i2}, ExOtCvV{i2}}, ...
                                                              'ValidationFrequency',ValFrq, 'ValidationPatience',ValPat, ...
                                                              'LayerSizes',LayerSizes{i1}, 'Activations',LyrAct(1:CLN), ...
                                                              'GradientTolerance',GrdTol, 'Standardize',StdInp, ...
                                                              'Lambda',RegStg, 'IterationLimit',ItrLim, ...
                                                              'LossTolerance',LssTol, 'Cost',CostMat);

                FailCg(i2) = contains(CurrMdlCV.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');

                CrossMdls{i2, i1} = CurrMdlCV;
                if CmpMdl; CrossMdls{i2, i1} = compact(CrossMdls{i2, i1}); end

                DsetTrnTmp = DsetCvT{i2};
                DsetValTmp = DsetCvV{i2};

                ExOtTrnTmp = ExOtCvT{i2};
                ExOtValTmp = ExOtCvV{i2};

                PredsCrossTrnTmp = mdlpredict(CurrMdlCV, DsetTrnTmp, 'SingleCol',true); % Thanks to SingleCol, outputs are always in 1 column!
                PredsCrossValTmp = mdlpredict(CurrMdlCV, DsetValTmp, 'SingleCol',true);
                PredsCrossTstTmp = mdlpredict(CurrMdlCV, DsetTst   , 'SingleCol',true);

                CrossTrnMSE(i2, i1) = mse(PredsCrossTrnTmp, double(ExOtTrnTmp >= 1));
                CrossValMSE(i2, i1) = mse(PredsCrossValTmp, double(ExOtValTmp >= 1));
                CrossTstMSE(i2, i1) = mse(PredsCrossTstTmp, double(ExOtTst    >= 1));
    
                [~, ~, ~, CrossTrnAUC(i2, i1), ~] = perfcurve(double(ExOtTrnTmp >= 1), PredsCrossTrnTmp, 1);
                [~, ~, ~, CrossValAUC(i2, i1), ~] = perfcurve(double(ExOtValTmp >= 1), PredsCrossValTmp, 1);
                [~, ~, ~, CrossTstAUC(i2, i1), ~] = perfcurve(double(ExOtTst    >= 1), PredsCrossTstTmp, 1);
            end

            if any(FailCg)
                warning(['ATTENTION! Some models in cross n. ',num2str(i1),' failed to converge! Please analyze it.'])
            end

            [~, IndBstMdl] = min(CrossValMSE(:, i1));
            Model = CrossMdls{IndBstMdl, i1};

        case 'Deep (L)'
            Model = trainann2(DsetTrn, ExOtTrn, 'Solver',DeepSolvr, 'LayerSizes',LayerSizes{i1}, ...
                                                'ShowTrainPlot',DpPlot, 'MetricsToUse',DpMetr, ...
                                                'LayerActivations',LyrAct(1:CLN), 'IterationLimit',ItrLim, ...
                                                'L2Regularization',RegStg, 'StandardizeInput',StdInp, ...
                                                'ObjTolerance',LssTol, 'FinalNetwork',FinOutNet, ...
                                                'WeightsInit',WghtsInit, 'Dropout',UseDrpOut, ...
                                                'InitialLearnRate',InitLrnRt, 'LRDropSchedule',DropSched, ...
                                                'GradTolerance',GrdTol, 'StepTolerance',StpTol);

        case 'Deep (V)'
            Model = trainann2(DsetNvT, ExOtNvT, 'Solver',DeepSolvr, 'LayerSizes',LayerSizes{i1}, ...
                                                'ShowTrainPlot',DpPlot, 'MetricsToUse',DpMetr, ...
                                                'LayerActivations',LyrAct(1:CLN), 'IterationLimit',ItrLim, ...
                                                'L2Regularization',RegStg, 'StandardizeInput',StdInp, ...
                                                'ObjTolerance',LssTol, 'FinalNetwork',FinOutNet, ...
                                                'ValidationData',{DsetNvV, ExOtNvV}, ...
                                                'ValidFrequency',ValFrq, 'ValidPatience',ValPat, ...
                                                'WeightsInit',WghtsInit, 'Dropout',UseDrpOut, ...
                                                'InitialLearnRate',InitLrnRt, 'LRDropSchedule',DropSched, ...
                                                'GradTolerance',GrdTol, 'StepTolerance',StpTol);

        otherwise
            error('ANNMode not recognized in training!')
    end
    
    PrdPrbsTrn = mdlpredict(Model, DsetTrn);
    PrdPrbsTst = mdlpredict(Model, DsetTst);

    TrnLss(i1) = crossentropy2(PrdPrbsTrn, ExOtTrn); % 'crossentropy' is appropriate only for neural network models.
    TstLss(i1) = crossentropy2(PrdPrbsTst, ExOtTst); % 'crossentropy' is appropriate only for neural network models.

    TrnMSE(i1) = mse(PrdPrbsTrn, ExOtTrn);
    TstMSE(i1) = mse(PrdPrbsTst, ExOtTst);

    if CmpMdl && not(contains(ANNMode, 'Deep', 'IgnoreCase',true)) && not(contains(class(Model), 'Compact', 'IgnoreCase',true))
        Model = compact(Model); % To eliminate training dataset and reduce size of the object!
    end

    MLMdl{MLRws, i1} = {Model; FeatsCnsid{i1}; LayerSizes{i1}}; % Pay attention to the order!
    MLRes{MLRsR, i1} = {PrdPrbsTrn; PrdPrbsTst}; % Pay attention to the order!
end

MLCls = strcat("ANN",string(1:ANNsNumber));
MLMdl.Properties.VariableNames = MLCls;
MLRes.Properties.VariableNames = MLCls;

%% Evaluation of prediction quality by means of ROC
ProgressBar.Indeterminate = 'on';
ProgressBar.Message       = 'Analyzing quality of models...';

MLPrfR = {'FPR', 'TPR', 'AUC', 'BestThreshold', 'BestThrInd', 'Class'};
MLPerf = table('RowNames',{'ROC','Err'});
MLPerf{'Err','Train'} = {array2table([TrnMSE; TrnLss], ...
                                            'VariableNames',MLCls, ...
                                            'RowNames',{'MSE','Loss'})};
MLPerf{'Err','Test' } = {array2table([TstMSE; TstLss], ...
                                            'VariableNames',MLCls, ...
                                            'RowNames',{'MSE','Loss'})};
MLPerf{'ROC',{'Train','Test'}} = {table('RowNames',MLPrfR)};

for i1 = 1:ANNsNumber
    PrdPrbsTrn = MLRes{'ProbsTrain', i1}{:};
    PrdPrbsTst = MLRes{'ProbsTest' , i1}{:};

    ExpOutsTrn = DsetTbl{'Train','ExpOuts'}{:};
    ExpOutsTst = DsetTbl{'Test' ,'ExpOuts'}{:};

    MLPerf{'ROC','Train'}{:}(:, i1) = roccurve2(PrdPrbsTrn, ExpOutsTrn, bestThrMethod=BstThrMthd);
    MLPerf{'ROC','Test' }{:}(:, i1) = roccurve2(PrdPrbsTst, ExpOutsTst, bestThrMethod=BstThrMthd);
end

MLPerf{'ROC','Train'}{:}.Properties.VariableNames = MLCls;
MLPerf{'ROC','Test' }{:}.Properties.VariableNames = MLCls;

%% Plot for check % Finish to adjust for PlotOption 1 (or maybe delete it)
if ChkPlt
    ProgressBar.Message = 'Check plot for predictions...';

    check_plot_mdlb(MLMdl, MLPerf, DsetTbl, {UnstabPolygons, IndecnPolygons, StablePolygons}, false, 30, DatasetInfo{1,'MultipleDays'}, fold0);
end

%% Creation of CrossInfo structure
if CrssVal
    CrossInfo = struct('CrossType',ANNMode, 'Models',{CrossMdls}, ...
                       'Indices',struct('Train',CrossTrnInd, 'Valid',CrossValInd), ...
                       'MSE',struct('Train',CrossTrnMSE, 'Valid',CrossValMSE, 'Test',CrossTstMSE), ...
                       'AUROC',struct('Train',CrossTrnAUC, 'Valid',CrossValAUC, 'Test',CrossTstAUC));
end

%% Creation of a folder where save model and future predictions
EventDates.Format = 'dd-MM-yyyy'; % You can also remove it, not useful!
switch ANNMode
    case 'Classic (V)'
        TrnType = 'Val';

    case 'Classic (L)'
        TrnType = 'Loss';

    case {'Cross Validation (K-Fold M)', 'Cross Validation (K-Fold V)'}
        TrnType = 'KFold';

    case {'Deep (L)', 'Deep (V)'}
        TrnType = 'Deep';

    otherwise
        error('Train type not recognized!')
end

AcFnAbb = cell(1, numel(LyrAct));
for i1 = 1:numel(LyrAct)
    switch LyrAct{i1}
        case 'sigmoid'
            AcFnAbb{i1} = 'Sigm';
    
        case 'relu'
            AcFnAbb{i1} = 'ReLU';
    
        case 'tanh'
            AcFnAbb{i1} = 'Tanh';

        case 'none'
            AcFnAbb{i1} = 'None';

        case 'elu'
            AcFnAbb{i1} = 'ELU';

        case 'gelu'
            AcFnAbb{i1} = 'GeLU';

        case 'softplus'
            AcFnAbb{i1} = 'Sft+';
    
        otherwise
            error('Layer activation function not recognized!')
    end
end

SuggFldNme = [DsetTpe,'_',char(join(string(Days4TmSns{:}), '-')),'d_',TrnType,'_',strjoin(unique(AcFnAbb), '_')];
MLFoldName = [char(inputdlg2({'Folder name (Results->ML Models and Predictions):'}, 'DefInp',{SuggFldNme}))];

fold_res_ml_curr = [fold_res_ml,sl,MLFoldName];

if exist(fold_res_ml_curr, 'dir')
    Options = {'Yes, thanks', 'No, for God!'};
    Answer  = uiconfirm(Fig, strcat(fold_res_ml_curr, " is an existing folder. Do you want to overwrite it?"), ...
                             'Existing ML Folder', 'Options',Options, 'DefaultOption',2);
    switch Answer
        case 'Yes, thanks.'
            rmdir(fold_res_ml_curr,'s')
            mkdir(fold_res_ml_curr)
        case 'No, for God!'
            fold_res_ml_curr = [fold_res_ml_curr,'-new'];
    end
else
    mkdir(fold_res_ml_curr)
end

%% Saving...
ProgressBar.Message = 'Saving files...';

VariablesML = {'MLMdl', 'MLRes', 'MLPerf', 'ModelInfo'};
if CrssVal
    VariablesML = [VariablesML, {'CrossInfo'}];
end
saveswitch([fold_res_ml_curr,sl,'MLMdlB.mat'], VariablesML)