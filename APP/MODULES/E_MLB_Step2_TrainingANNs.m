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

%% Dataset options
DsetTbl = dataset_extraction(DatasetInfo);

DsetTpe = char(listdlg2({'Dataset to consider?'}, {'1T', '2T', 'All', 'Manual'}));
switch DsetTpe
    case '1T'
        DatesToMantain = DatasetInfo.EventDate(DatasetInfo.LandslideEvent);

    case '2T'
        DatesToMantain = [ DatasetInfo.EventDate(DatasetInfo.LandslideEvent)
                           DatasetInfo.BeforeEventDate(DatasetInfo.LandslideEvent) ];

    case 'All'
        DatesToMantain = unique(DsetTbl{'Total','Dates'}{:}{:,'Datetime'});

    case 'Manual'
        DatesChoosable = unique(DsetTbl{'Total','Dates'}{:}{:,'Datetime'});
        IndsDatesChose = checkbox2(DatesChoosable, 'Title',{'Choose dates: '}, 'OutType','NumInd');
        DatesToMantain = DatesChoosable(IndsDatesChose);
end

IndsToMantain = cell(size(DsetTbl,1), 1);
for i1 = 1:numel(IndsToMantain)
    if iscell(DsetTbl{i1,'Dates'}{:})
        IndsToMantain{i1} = cell(1, numel(DsetTbl{i1,'Dates'}{:}));
        for i2 = 1:numel(DsetTbl{i1,'Dates'}{:})
            IndsToMantTmp = arrayfun(@(x) DsetTbl{i1,'Dates'}{:}{i2}{:,'Datetime'} == x, DatesToMantain, 'UniformOutput',false);
            IndsToMantain{i1}{i2} = any([IndsToMantTmp{:}], 2);
            for i3 = 1:size(DsetTbl,2)
                DsetTbl{i1,i3}{:}{i2}(not(IndsToMantain{i1}{i2}), :) = []; % Cleaning of dates not to maintain
            end
        end
    else
        IndsToMantTmp = arrayfun(@(x) DsetTbl{i1,'Dates'}{:}{:,'Datetime'} == x, DatesToMantain, 'UniformOutput',false);
        IndsToMantain{i1} = any([IndsToMantTmp{:}], 2);
        for i2 = 1:size(DsetTbl,2)
            DsetTbl{i1,i2}{:}(not(IndsToMantain{i1}), :) = []; % Cleaning of dates not to maintain
        end
    end
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

    if strcmpi(ANNMode, 'Deep (V)') || contains(ANNMode, 'Validation', 'IgnoreCase',true)
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
    MaxAutoEvs = str2double(inputdlg2({'Maximum number of evaluations:'}, 'DefInp',{'20'}));
end

BstThrMthd = char(listdlg2({'Optimal threshold mode?'}, ...
                           {'MATLAB', 'MaximizeRatio-TPR-FPR', 'MaximizeArea-TPR-TNR'}));

%% Adding vars to ModelInfo
ModelInfo.ANNMode  = ANNMode;
ModelInfo.TimeSensMode = TmSensMode;
if not(strcmp(ANNMode, 'Auto'))
    ModelInfo.ActivationFunUsed = LyrAct;
    ModelInfo.StandardizedInput = StdInp;
    % ModelInfo.ANNsStructures = array2table(MdlNeurCmbs, 'VariableNames',strcat(string(1:length(MdlNeurCmbs)),"Layers"));
end
ModelInfo.BestThrMethod = BstThrMthd;
ModelInfo.RangesForNorm = {Rngs4Norm};

%% Initialization of variables for loops
ANNsRows = {'Model', 'FeatsConsidered', 'Structure'}; % If you touch these, please modify row below when you write ANNs
ANNs     = table('RowNames',ANNsRows);

ANNsResRows = {'ProbsTrain', 'ProbsTest'}; % If you touch these, please modify row below when you write ANNsRes
ANNsRes     = table('RowNames',ANNsResRows);

CrssVal = false;
if contains(ANNMode, 'Cross Validation', 'IgnoreCase',true)
    CrssVal = true;
    % ANNsCrossRows = {'Models', 'MSE', 'AUC', 'BestModel', 'Convergence', 'ProbsTest'}; % If you touch these, please modify row below when you write ANNsCross
    % ANNsCross     = table('RowNames',ANNsCrossRows);
end

%% feats to consider for each model
switch TmSensMode
    case 'SeparateDays'
        %% Separate Days
        ANNsNumber = Days4TmSns*length(LaySizeRw); % DaysForTS because you repeat the same structure n times as are the number of days that I can consider independently.
        [FeatsCnsid, LayerSizes] = deal(cell(1, ANNsNumber));
        i3 = 0;
        for i1 = 1:length(LaySizeRw)
            for i2 = 1:Days4TmSns
                i3 = i3 + 1;
                ProgressBar.Value = i3/ANNsNumber;
                ProgressBar.Message = ['Training model n. ',num2str(i3),' of ',num2str(ANNsNumber)];

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

    ANNs{ANNsRows, i1} = {Model; FeatsCnsid{i1}; LayerSizes{i1}}; % Pay attention to the order!
    ANNsRes{ANNsResRows, i1} = {PrdPrbsTrn; PrdPrbsTst}; % Pay attention to the order!
end

ANNsCols = strcat("ANN",string(1:ANNsNumber));
ANNs.Properties.VariableNames    = ANNsCols;
ANNsRes.Properties.VariableNames = ANNsCols;

%% Evaluation of prediction quality by means of ROC
ProgressBar.Indeterminate = 'on';
ProgressBar.Message       = 'Analyzing quality of models...';

ANNsPrfR = {'FPR', 'TPR', 'AUC', 'BestThreshold', 'BestThrInd'};
ANNsPerf = table('RowNames',{'ROC','Err'});
ANNsPerf{'Err','Train'} = {array2table([TrnMSE; TrnLss], ...
                                            'VariableNames',ANNsCols, ...
                                            'RowNames',{'MSE','Loss'})};
ANNsPerf{'Err','Test' } = {array2table([TstMSE; TstLss], ...
                                            'VariableNames',ANNsCols, ...
                                            'RowNames',{'MSE','Loss'})};
ANNsPerf{'ROC',{'Train','Test'}} = {table('RowNames',ANNsPrfR)};

for i1 = 1:ANNsNumber
    PrdPrbsTrn = ANNsRes{'ProbsTrain', i1}{:};
    PrdPrbsTst = ANNsRes{'ProbsTest' , i1}{:};

    ExpOutsTrn = DsetTbl{'Train','ExpOuts'}{:};
    ExpOutsTst = DsetTbl{'Test' ,'ExpOuts'}{:};

    % Train performance
    [FPR4ROC_Trn, TPR4ROC_Trn, ThresholdsROC_Trn, AUC_Trn, OptPoint_Trn] = perfcurve(ExpOutsTrn, PrdPrbsTrn, 1);
    switch BstThrMthd
        case 'MATLAB'
            % Method integrated in MATLAB
            IndBest_Trn = find(ismember([FPR4ROC_Trn, TPR4ROC_Trn], OptPoint_Trn, 'rows'));
            BestThr_Trn = ThresholdsROC_Trn(IndBest_Trn);
        case 'MaximizeRatio-TPR-FPR'
            % Method max ratio TPR/FPR
            RatTPR_FPR_Trn = TPR4ROC_Trn./FPR4ROC_Trn;
            RatTPR_FPR_Trn(isinf(RatTPR_FPR_Trn)) = nan;
            [~, IndBest_Trn]  = max(RatTPR_FPR_Trn);
            BestThr_Trn = ThresholdsROC_Trn(IndBest_Trn);
        case 'MaximizeArea-TPR-TNR'
            % Method max product TPR*TNR
            AreaTPR_TNR_Trn = TPR4ROC_Trn.*(1-FPR4ROC_Trn);
            [~, IndBest_Trn] = max(AreaTPR_TNR_Trn);
            BestThr_Trn = ThresholdsROC_Trn(IndBest_Trn);
    end

    % Test performance
    [FPR4ROC_Tst, TPR4ROC_Tst, ThresholdsROC_Tst, AUC_Tst, OptPoint_Tst] = perfcurve(ExpOutsTst, PrdPrbsTst, 1); % To adjust ExpectedOutputsTest
    switch BstThrMthd
        case 'MATLAB'
            % Method integrated in MATLAB
            IndBest_Tst = find(ismember([FPR4ROC_Tst, TPR4ROC_Tst], OptPoint_Tst, 'rows'));
            BestThr_Tst = ThresholdsROC_Tst(IndBest_Tst);
        case 'MaximizeRatio-TPR-FPR'
            % Method max ratio TPR/FPR
            RatTPR_FPR_Tst = TPR4ROC_Tst./FPR4ROC_Tst;
            RatTPR_FPR_Tst(isinf(RatTPR_FPR_Tst)) = nan;
            [~, IndBest_Tst] = max(RatTPR_FPR_Tst);
            BestThr_Tst = ThresholdsROC_Tst(IndBest_Tst);
        case 'MaximizeArea-TPR-TNR'
            % Method max product TPR*TNR
            AreaTPR_TNR_Tst = TPR4ROC_Tst.*(1-FPR4ROC_Tst);
            [~, IndBest_Tst] = max(AreaTPR_TNR_Tst);
            BestThr_Tst = ThresholdsROC_Tst(IndBest_Tst);
    end
    
    % General matrices creation
    ANNsPerf{'ROC','Train'}{:}{ANNsPrfR, i1} = {FPR4ROC_Trn; TPR4ROC_Trn; AUC_Trn; BestThr_Trn; IndBest_Trn}; % Pay attention to the order!
    ANNsPerf{'ROC','Test' }{:}{ANNsPrfR, i1} = {FPR4ROC_Tst; TPR4ROC_Tst; AUC_Tst; BestThr_Tst; IndBest_Tst}; % Pay attention to the order!
end

ANNsPerf{'ROC','Train'}{:}.Properties.VariableNames = ANNsCols;
ANNsPerf{'ROC','Test' }{:}.Properties.VariableNames = ANNsCols;

%% Plot for check % Finish to adjust for PlotOption 1 (or maybe delete it)
if ChkPlt
    ProgressBar.Message = 'Loading data...';

    load([fold_var,sl,'StudyAreaVariables.mat'],    'StudyAreaPolygon')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','FilesDetectedSoilSlip')

    StabAreaApproach = DatasetInfo{1, 'StabAreaApproach'};
    MultiDayAnalysis = DatasetInfo{1, 'MultipleDays'};

    if length(UnstabPolygons) > 1
        UnstabPolyMrgd = union(UnstabPolygons);
        IndecsPolyMrgd = union(IndecnPolygons);
        StablePolyMrgd = union(StablePolygons);
    else
        UnstabPolyMrgd = UnstabPolygons;
        IndecsPolyMrgd = IndecnPolygons;
        StablePolyMrgd = StablePolygons;
    end

    ProgressBar.Message = 'Plotting results...';
    
    [~, BestModelForTst] = max(cell2mat(ANNsPerf{'ROC','Test'}{:}{'AUC',:}));
    [~, BestModelForTrn] = max(cell2mat(ANNsPerf{'ROC','Train'}{:}{'AUC',:}));
    ModelToPlot = str2double(inputdlg2({['Model to plot? From 1 to ',num2str(ANNsNumber), ...
                                         ' (Best for Test: ',num2str(BestModelForTst), ...
                                         '. Best for Train: ',num2str(BestModelForTrn),')']}, ...
                                         'DefInp',{num2str(BestModelForTst)}));
    
    PlotOption = 1;
    if MultiDayAnalysis
        PossibleDates = unique(DsetTbl{'Total', 'Dates'}{:}{:,'Datetime'});
        DateChosedInd = listdlg2('Event to plot:', PossibleDates, 'OutType','NumInd');
        DateChosed    = PossibleDates(DateChosedInd);

        IndsEv2Take = (DsetTbl{'Total', 'Dates'}{:}{:,'Datetime'} == DateChosed);

        LandslideEvent = all(DsetTbl{'Total', 'Dates'}{:}{:,'LandslideEvent'}(IndsEv2Take));
        if LandslideEvent; PlotOption = 2; else; PlotOption = 3; end

        DatasetPartChosed = find(any((DateChosed == [DatasetInfo.EventDate, DatasetInfo.BeforeEventDate]), 2), 1);
        
        [~, InfoDetName, InfoDetExt] = fileparts(DatasetInfo{DatasetPartChosed, 'FullPathInfoDet'});
        InfoDetNameToTake = strcat(InfoDetName,InfoDetExt);
    else
        [~, InfoDetName, InfoDetExt] = fileparts(DatasetInfo{end, 'FullPathInfoDet'});
        InfoDetNameToTake = strcat(InfoDetName,InfoDetExt);
    end

    IndDetToUse = contains(FilesDetectedSoilSlip, InfoDetNameToTake);
    if sum(IndDetToUse) > 1 || sum(IndDetToUse) == 0
        error('No match with index to take in InfoDetected!')
    end
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDetToUse};
    
    fig_check = figure(3);
    ax_check  = axes(fig_check);
    hold(ax_check,'on')
    
    BestThresholdTrn = ANNsPerf{'ROC','Train'}{:}{'BestThreshold',ModelToPlot}{:};
    BestThresholdTst = ANNsPerf{'ROC','Test' }{:}{'BestThreshold',ModelToPlot}{:};
    IndexOfBstThrTrn = ANNsPerf{'ROC','Train'}{:}{'BestThrInd',ModelToPlot}{:};
    IndexOfBstThrTst = ANNsPerf{'ROC','Test' }{:}{'BestThrInd',ModelToPlot}{:};
    
    BestThrTPRTrn = ANNsPerf{'ROC','Train'}{:}{'TPR',ModelToPlot}{:}(IndexOfBstThrTrn);
    BestThrTPRTst = ANNsPerf{'ROC','Test' }{:}{'TPR',ModelToPlot}{:}(IndexOfBstThrTst);
    BestThrFPRTrn = ANNsPerf{'ROC','Train'}{:}{'FPR',ModelToPlot}{:}(IndexOfBstThrTrn);
    BestThrFPRTst = ANNsPerf{'ROC','Test' }{:}{'FPR',ModelToPlot}{:}(IndexOfBstThrTst);
    
    disp(strcat("Your TPR relative to the best threshold are (train - test): ", string(BestThrTPRTrn), " - ", string(BestThrTPRTst)))
    disp(strcat("Your FPR relative to the best threshold are (train - test): ", string(BestThrFPRTrn), " - ", string(BestThrFPRTst)))
    
    ModelSelected = ANNs{'Model',ModelToPlot}{:};
    
    switch PlotOption
        case 1
            PrdPrbsTrn = ANNsRes{'ProbsTrain',ModelToPlot}{:};
            PrdPrbsTst = ANNsRes{'ProbsTest', ModelToPlot}{:};
            PrdClTrnBT = PrdPrbsTrn >= BestThresholdTrn;
            PrdClTstBT = PrdPrbsTst >= BestThresholdTst;
    
        case {2, 3}
            Dset4Plt = DsetTbl{'Total', 'Feats'}{:}(IndsEv2Take, :);
            xLon4Plt = DsetTbl{'Total', 'Coordinates'}{:}{IndsEv2Take, 'Longitude'};
            yLat4Plt = DsetTbl{'Total', 'Coordinates'}{:}{IndsEv2Take, 'Latitude' };
            ExOt4Plt = DsetTbl{'Total','ExpOuts'}{:}(IndsEv2Take, :);
            Prbs4Plt = mdlpredict(ModelSelected, Dset4Plt);
            PrBT4Plt = Prbs4Plt >= (BestThresholdTrn + BestThresholdTst)/2;
    end
    
    plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1.5)
    
    switch PlotOption
        case {1, 2}
            plot(UnstabPolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#d87e7e");
        case 3
            plot(UnstabPolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#5aa06b");
    end
    plot(IndecsPolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#fff2cc");
    plot(StablePolyMrgd, 'FaceAlpha',.5, 'FaceColor',"#5aa06b");
    
    hdetected = cellfun(@(x,y) scatter(x, y, '^k', 'Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
    
    switch PlotOption
        case 1
            hUnstableTst = scatter(DsetTbl{'Test', 'Coordinates'}{:}.Longitude(PrdClTstBT), ...
                                   DsetTbl{'Test', 'Coordinates'}{:}.Latitude(PrdClTstBT), 30, 'Marker','d', 'MarkerFaceColor',"#000000", 'MarkerEdgeColor','none');
            
            hUnstableTrn = scatter(DsetTbl{'Train', 'Coordinates'}{:}.Longitude(PrdClTrnBT), ...
                                   DsetTbl{'Train', 'Coordinates'}{:}.Latitude(PrdClTrnBT), 30, 'Marker','s', 'MarkerFaceColor',"#000000", 'MarkerEdgeColor','none');
    
        case {2, 3}
            hUnstable4Plt = scatter(xLon4Plt(PrBT4Plt), ...
                                    yLat4Plt(PrBT4Plt), 30, 'Marker','s', 'MarkerFaceColor',"#000000", 'MarkerEdgeColor','none');
    end
    
    switch PlotOption
        case 1
            ExpcOuts = double(DsetTbl{'Total','ExpOuts'}{:});

            xPointUnstab = DsetTbl{'Total', 'Coordinates'}{:}.Longitude(logical(ExpcOuts));
            yPointUnstab = DsetTbl{'Total', 'Coordinates'}{:}.Latitude(logical(ExpcOuts));
    
            xPointStable = DsetTbl{'Total', 'Coordinates'}{:}.Longitude(not(logical(ExpcOuts)));
            yPointStable = DsetTbl{'Total', 'Coordinates'}{:}.Latitude(not(logical(ExpcOuts)));
    
        case {2, 3}
            xPointUnstab = xLon4Plt(logical(ExOt4Plt));
            yPointUnstab = yLat4Plt(logical(ExOt4Plt));
    
            xPointStable = xLon4Plt(not(logical(ExOt4Plt)));
            yPointStable = yLat4Plt(not(logical(ExOt4Plt)));
    end
    
    hUnstabOutReal = scatter(xPointUnstab, yPointUnstab, 7, 'Marker',"hexagram", ...
                                'MarkerFaceColor',"#ff0c01", 'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.5);
    
    hStableOutReal = scatter(xPointStable, yPointStable, 15, 'Marker',"hexagram", ...
                                'MarkerFaceColor',"#77AC30", 'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.5);
    
    switch PlotOption
        case {1, 2}
            title('Day of the event')
        case 3
            title([num2str(DaysBeforeEventWhenStable), ' days before the event'])
        otherwise
            error('Plot option not defined')
    end
    
    yLatMean = mean(DsetTbl{'Total', 'Coordinates'}{:}.Latitude);
    dLat1Met = rad2deg(1/earthRadius); % 1 m in lat
    dLon1Met = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long
    
    RatLatLong = dLat1Met/dLon1Met;
    daspect([1, RatLatLong, 1])
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

SuggFldNme = [DsetTpe,'_',num2str(Days4TmSns),'d_',TrnType,'_',strjoin(unique(AcFnAbb), '_')];
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

VariablesML = {'ANNs', 'ANNsRes', 'ANNsPerf', 'ModelInfo'};
if CrssVal
    VariablesML = [VariablesML, {'CrossInfo'}];
end
saveswitch([fold_res_ml_curr,sl,'ANNsMdlB.mat'], VariablesML)

close(ProgressBar) % Fig instead of ProgressBar if in standalone version