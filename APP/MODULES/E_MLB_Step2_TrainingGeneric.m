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
    Days4TmSns = DatasetInfo{1,'DaysForTS'}{:};
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

ModelInfo = table("Generic AI", {DatasetInfo}, 'VariableNames',{'Type', 'DatasetInfo'});

%% Dataset extraction and filtering
DsetTpe = char(listdlg2({'Dataset to consider?'}, {'1T', '2T', 'All', 'Manual'}));
DsetTbl = dataset_extr_filtr(DatasetInfo, fltrCase=DsetTpe);

if numel(unique(DsetTbl{'Total','ExpOuts'}{:})) ~= 2
    error('You must have just 2 output classes for this script!');
end

if not(isequal(unique(DsetTbl{'Total','ExpOuts'}{:})', [0,1]))
    error('The two output classes must be 0 and 1, not anything else!'); % Otherwise please mod the script for compatibility (ex: WgObTrn(ExOtTrn ~= 0) = WgPObs)
end

%% ANN Options
ProgressBar.Message = 'ANN options...';

switch TmSensMode
    case 'SeparateDays'
        FeatsNmsTS = cellfun(@(x) strcat(x,'-',string(1:Days4TmSns)','daysBefore'), TmSnParams, 'UniformOutput',false); % Remember to change this line if you change feats names in datasetstudy_creation function!

    case {'CondensedDays', 'TriggerCausePeak', 'NoTimeSens'}

    otherwise
        error('Time sensitive mode not recognized!')
end

MdlOpt = checkbox2({'Compact models', 'Check plot'}, 'DefInp',[1, 0], 'OutType','LogInd');
CmpMdl = MdlOpt(1);
ChkPlt = MdlOpt(2);

MdSzRw = {nan}; % Default, when you have for example 'Auto' mode!
WgPObs = 1; % Default weigth of positive observations against negative (no landslides)

MdlOps = {'KAN (L)', 'KAN (V)', 'Random Forest (L)', 'Bagging (L)', ...
          'AdaBoost (L)', 'Logit Boost (L)', 'Gentle Boost (L)', ...
          'Total Boost (L)', 'SVM (L)', 'Auto ML (L)'};
MLMode = char(listdlg2('Type of train?', MdlOps));
switch MLMode
    case {'KAN (L)', 'KAN (V)'}
        St2Use = inputdlg2({'Specify structure n.1 (2 layers):'}, 'Extendable',true, 'DefInp',{'[7, 7]'});
        MdSzRw = cellfun(@str2num, St2Use, 'UniformOutput',false);
        if not(all(cellfun(@numel, MdSzRw) == 2))
            error('All the structures must have only 2 layers, not more, not less!')
        end

        TunPar = inputdlg2({'Iterations limit:', 'Learn rate:', 'LossTolerance:'}, 'DefInp',{'500', '.1', '1e-3'});
        ItrLim = str2double(TunPar{1});
        LrngRt = str2double(TunPar{2});
        LssTol = str2double(TunPar{3});

    case 'Random Forest (L)'
        St2Use = inputdlg2({'Specify the number of trees:'}, 'Extendable',true, 'DefInp',{'50'});
        MdSzRw = cellfun(@str2num, St2Use, 'UniformOutput',false);
        if not(all(cellfun(@numel, MdSzRw) == 1))
            error('All the models must have only a single number, representing the trees, not more, not less!')
        end

    case {'Bagging (L)', 'AdaBoost (L)', 'Logit Boost (L)', ...
            'Gentle Boost (L)', 'Total Boost (L)'}
        TunPar = inputdlg2({'Iterations limit:', 'Learn rate:', 'NL weight:'}, 'DefInp',{'500', '.1', '1'});
        ItrLim = str2double(TunPar{1});
        LrngRt = str2double(TunPar{2});
        WgPObs = str2double(TunPar{3}); % Weigths of positive observations against negative (no landslides)
        ScrTrn = 'none';
        SpltCr = 'gdi';

        if any(strcmp(MLMode, {'Logit Boost (L)', 'Gentle Boost (L)'}))
            TrLrns = templateTree('Reproducible',true, 'MinLeafSize',1, 'Surrogate','on', ...
                                  'Type','classification', 'NumVariablesToSample','all'); % 'MaxNumSplits',10
        else
            TrLrns = templateTree('Reproducible',true, 'MinLeafSize',1, 'Surrogate','on', ...
                                  'Type','classification', 'SplitCriterion',SpltCr, ...
                                  'AlgorithmForCategorical','Exact', 'NumVariablesToSample','all'); % 'MaxNumSplits',10
        end

    case 'SVM (L)'
        SVMPar = listdlg2({'Kernel function', 'Solver'}, {{'linear', 'gaussian', 'rbf', 'polynomial'}, {'ISDA', 'L1QP', 'SMO'}});
        KrnSVM = SVMPar{1};
        SlvSVM = SVMPar{2};

    case 'Auto ML (L)'
        MaxEvA = str2double(inputdlg2({'Maximum number of evaluations:'}, 'DefInp',{'25'}));
end

if contains(MLMode, '(V)', 'IgnoreCase',true)
    TunPr2 = inputdlg2({'Validation patience:'}, 'DefInp',{'20'});
    ValPat = str2double(TunPr2{1});
end

BstThrMthd = char(listdlg2({'Optimal threshold mode?'}, ...
                           {'MATLAB', 'MaximizeRatio-TPR-FPR', 'MaximizeArea-TPR-TNR'}));

%% Adding vars to ModelInfo
ModelInfo.MdlMode       = MLMode;
ModelInfo.TimeSensMode  = TmSensMode;
ModelInfo.BestThrMethod = BstThrMthd;
ModelInfo.RangesForNorm = {Rngs4Norm};

%% Initialization of variables for loops
MLRws = {'Model', 'FeatsConsidered', 'Structure'}; % If you touch these, please modify row below when you write ML
MLMdl = table('RowNames',MLRws);

MLRsR = {'ProbsTrain', 'ProbsTest'}; % If you touch these, please modify row below when you write MLRes
MLRes = table('RowNames',MLRsR);

CrssVal = false;
if contains(MLMode, '(CV)', 'IgnoreCase',true)
    CrssVal = true;
end

%% Feats to consider for each model
switch TmSensMode
    case 'SeparateDays'
        %% Separate Days
        MdlsNumber = Days4TmSns*length(MdSzRw); % DaysForTS because you repeat the same structure n times as are the number of days that I can consider independently.
        [FeatsCnsid, LayerSizes] = deal(cell(1, MdlsNumber));
        i3 = 0;
        for i1 = 1:length(MdSzRw)
            for i2 = 1:Days4TmSns
                i3 = i3 + 1;

                TSFeatsToTake = cellfun(@(x) x(1:i2)', FeatsNmsTS, 'UniformOutput',false); % WRONG!
                TSFeatsToTake = cellstr(cat(2, TSFeatsToTake{:}));

                FeatsCnsid{i3} = [FeatsNms(FeatsNTS), TSFeatsToTake];
                LayerSizes{i3} = MdSzRw{i1}; % Structures must be repeated because you have different inputs!
            end
        end

    case {'CondensedDays', 'TriggerCausePeak', 'NoTimeSens'}
        MdlsNumber = length(MdSzRw);
        LayerSizes = MdSzRw;
        FeatsCnsid = repmat({FeatsNms}, 1, MdlsNumber);

    otherwise
        error('Time Sensitive mode not recognized while defining features to take!')
end

%% Training loops
[TrnLss, TrnMSE, TstLss, TstMSE] = deal(zeros(1,MdlsNumber));
if ExistCrV
    [CrossMdls, CrossTrnInd, CrossValInd] = deal(cell(kFldNm, MdlsNumber));
    [CrossTrnMSE, CrossValMSE, CrossTstMSE, ...
        CrossTrnAUC, CrossValAUC, CrossTstAUC] = deal(zeros(kFldNm, MdlsNumber));
end

ProgressBar.Indeterminate = 'off';
for i1 = 1:MdlsNumber
    ProgressBar.Value = i1/MdlsNumber;
    ProgressBar.Message = ['Training model n. ',num2str(i1),' of ',num2str(MdlsNumber)];

    DsetTrn = DsetTbl{'Train','Feats'}{:}(:, FeatsCnsid{i1});
    DsetTst = DsetTbl{'Test' ,'Feats'}{:}(:, FeatsCnsid{i1});

    ExOtTrn = DsetTbl{'Train','ExpOuts'}{:};
    ExOtTst = DsetTbl{'Test' ,'ExpOuts'}{:};

    WgObTrn = ones(size(DsetTrn,1), 1);
    WgObTrn(ExOtTrn ~= 0) = WgPObs; % 0 is for not landslides!

    if ExistNrV
        DsetNvT = DsetTbl{'NvTrain','Feats'}{:}(:, FeatsCnsid{i1});
        DsetNvV = DsetTbl{'NvValid','Feats'}{:}(:, FeatsCnsid{i1});

        ExOtNvT = DsetTbl{'NvTrain','ExpOuts'}{:};
        ExOtNvV = DsetTbl{'NvValid','ExpOuts'}{:};

        WgObNvT = ones(size(DsetNvT,1), 1);
        WgObNvT(ExOtNvT ~= 0) = WgPObs; % 0 is for not landslides!
    end

    if ExistCrV
        DsetCvT = cellfun(@(x) x(:, FeatsCnsid{i1}), DsetTbl{'CvTrain','Feats'}{:}, 'UniformOutput',false);
        DsetCvV = cellfun(@(x) x(:, FeatsCnsid{i1}), DsetTbl{'CvValid','Feats'}{:}, 'UniformOutput',false);
        
        ExOtCvT = DsetTbl{'CvTrain','ExpOuts'}{:};
        ExOtCvV = DsetTbl{'CvValid','ExpOuts'}{:};

        WgObCvT = cellfun(@(x) ones(size(x,1), 1), DsetCvT, 'UniformOutput',false);
        for i2 = 1:numel(WgObCvT)
            WgObCvT{i2}(ExOtCvT{i2} ~= 0) = WgPObs; % 0 is for not landslides!
        end
    end

    switch MLMode
        case 'KAN (L)'
            Model = trainKAN(DsetTrn, ExOtTrn, trainEpochs=ItrLim, learningRate=LrngRt, ...
                                               netStrLayers=LayerSizes{i1}, lossTolerance=LssTol);

        case 'KAN (V)'
            Model = trainKAN(DsetNvT, ExOtNvT, validationData={DsetNvV, ExOtNvV}, ...
                                               trainEpochs=ItrLim, learningRate=LrngRt, ...
                                               netStrLayers=LayerSizes{i1}, validPatience=ValPat, ...
                                               lossTolerance=LssTol);

        case 'Random Forest (L)'
            Model = TreeBagger(LayerSizes{i1}, DsetTrn, ExOtTrn, OOBPrediction='on', ...
                                                                 OOBPredictorImportance='on', ...
                                                                 InBagFraction=.8, MinLeafSize=1, ...
                                                                 SampleWithReplacement='on');
    
        case 'Bagging (L)'
            Model = fitcensemble(DsetTrn, ExOtTrn, 'Method','Bag', 'Learners',TrLrns, ...
                                                   'Resample','on', 'FResample',1, ...
                                                   'Replace','on', 'ScoreTransform',ScrTrn, ...
                                                   'NumLearningCycles',ItrLim, ...
                                                   'Weights',WgObTrn);
    
        case 'AdaBoost (L)'
            Model = fitcensemble(DsetTrn, ExOtTrn, 'Method','AdaBoostM1', 'Learners',TrLrns, ...
                                                   'NumLearningCycles',ItrLim, 'ScoreTransform',ScrTrn, ...
                                                   'Weights',WgObTrn, 'LearnRate',LrngRt);
    
        case 'Logit Boost (L)'
            Model = fitcensemble(DsetTrn, ExOtTrn, 'Method','LogitBoost', 'Learners',TrLrns, ...
                                                   'NumLearningCycles',ItrLim, 'ScoreTransform',ScrTrn, ...
                                                   'Weights',WgObTrn, 'LearnRate',LrngRt);
    
        case 'Gentle Boost (L)'
            Model = fitcensemble(DsetTrn, ExOtTrn, 'Method','GentleBoost', 'Learners',TrLrns, ...
                                                   'NumLearningCycles',ItrLim, 'ScoreTransform',ScrTrn, ...
                                                   'Weights',WgObTrn, 'LearnRate',LrngRt);
    
        case 'Total Boost (L)'
            Model = fitcensemble(DsetTrn, ExOtTrn, 'Method','TotalBoost', 'Learners',TrLrns, ...
                                                   'NumLearningCycles',ItrLim, 'ScoreTransform',ScrTrn, ...
                                                   'Weights',WgObTrn, 'MarginPrecision',LrngRt);

        case 'SVM (L)'
            Model = fitcsvm(DsetTrn, ExOtTrn, 'KernelFunction',KrnSVM, 'Solver',SlvSVM);
    
        case 'Auto ML (L)'
            Model = fitcensemble(DsetTrn, ExOtTrn, 'OptimizeHyperparameters','all', ...
                                                   'HyperparameterOptimizationOptions', struct('MaxObjectiveEvaluations',MaxEvA, ...
                                                                                               'Optimizer','bayesopt', 'MaxTime',Inf, ...
                                                                                               'AcquisitionFunctionName','expected-improvement-plus', ...
                                                                                               'ShowPlots',true, 'Verbose',1, 'Kfold',kFldNm, ...
                                                                                               'UseParallel',false, 'Repartition',true));

        otherwise
            error('AIMode not recognized in training!')
    end
    
    PrdPrbsTrn = mdlpredict(Model, DsetTrn);
    PrdPrbsTst = mdlpredict(Model, DsetTst);

    TrnLss(i1) = crossentropy2(PrdPrbsTrn, ExOtTrn); % 'crossentropy' is appropriate only for neural network models.
    TstLss(i1) = crossentropy2(PrdPrbsTst, ExOtTst); % 'crossentropy' is appropriate only for neural network models.

    TrnMSE(i1) = mse(PrdPrbsTrn, ExOtTrn);
    TstMSE(i1) = mse(PrdPrbsTst, ExOtTst);

    if CmpMdl && not(contains(class(Model), 'Compact', 'IgnoreCase',true))
        Model = compact(Model); % To eliminate training dataset and reduce size of the object!
    end

    MLMdl{MLRws, i1} = {Model; FeatsCnsid{i1}; LayerSizes{i1}}; % Pay attention to the order!
    MLRes{MLRsR, i1} = {PrdPrbsTrn; PrdPrbsTst}; % Pay attention to the order!
end

MLCls = strcat("ML",string(1:MdlsNumber));
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

for i1 = 1:MdlsNumber
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
    CrossInfo = struct('CrossType',MLMode, 'Models',{CrossMdls}, ...
                       'Indices',struct('Train',CrossTrnInd, 'Valid',CrossValInd), ...
                       'MSE',struct('Train',CrossTrnMSE, 'Valid',CrossValMSE, 'Test',CrossTstMSE), ...
                       'AUROC',struct('Train',CrossTrnAUC, 'Valid',CrossValAUC, 'Test',CrossTstAUC));
end

%% Creation of a folder where save model and future predictions
EventDates.Format = 'dd-MM-yyyy'; % You can also remove it, not useful!
switch MLMode
    case {'KAN (L)', 'KAN (V)'}
        TrnType = 'KAN';

    case 'Random Forest (L)'
        TrnType = 'RF';

    case 'Bagging (L)'
        TrnType = 'Bag';

    case 'AdaBoost (L)'
        TrnType = 'AdaB';

    case 'Logit Boost (L)'
        TrnType = 'LB';

    case 'Gentle Boost (L)'
        TrnType = 'GB';

    case 'Total Boost (L)'
        TrnType = 'TB';

    case 'Auto ML (L)'
        TrnType = 'AutoML';

    case {'SVM (L)'}
        TrnType = 'SVM';

    otherwise
        error('Train type not recognized!')
end

SuggFldNme = [DsetTpe,'_',char(join(string(Days4TmSns), '-')),'d_',TrnType];
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

close(ProgressBar) % Fig instead of ProgressBar if in standalone version