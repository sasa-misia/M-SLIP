if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files and options
sl = filesep;

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');

MdlType = find([exist([fold_res_ml_curr,sl,'ANNsMdlA.mat'], 'file'), ...
                exist([fold_res_ml_curr,sl,'ANNsMdlB.mat'], 'file')]);
if not(isscalar(MdlType)); error('More than one model found in your folder!'); end
switch MdlType
    case 1
        Fl2LdMdl = 'ANNsMdlA.mat';
        load([fold_res_ml_curr,sl,Fl2LdMdl], 'ANNs','ANNsPerf','ModelInfo')
        ANNMode = ModelInfo.ANNsOptions.TrainMode;
        DsetInf = ModelInfo.Dataset;
        CrssVal = ModelInfo.Dataset(end).Options.CrossDatasets;
        NormVal = ModelInfo.Dataset(end).Options.ValidDatasets; % Not used!
        HistMtr = ModelInfo.ANNsOptions.ModelHistory;
        OutMode = DsetInf(end).Options.OutputType;

    case 2
        Fl2LdMdl = 'ANNsMdlB.mat';
        load([fold_res_ml_curr,sl,Fl2LdMdl], 'ANNs','ANNsPerf','ModelInfo')
        ANNMode = ModelInfo.ANNMode;
        DsetInf = ModelInfo.DatasetInfo{:};
        CrssVal = ModelInfo.DatasetInfo{:}{end,'CrossValidSet'};
        NormVal = ModelInfo.DatasetInfo{:}{end,'NormValidSet' };
        HistMtr = false;
        OutMode = 'L-NL classes';

    otherwise
        error('No trained ModelA or B found!')
end

DsetTbl = dataset_extraction(DsetInf);

QlExtOpts = checkbox2({'Best threshold', 'Fill empty hist models', ...
                       'RandFeat imp CV/Hist'}, 'DefInp',[1, 1, 0], 'OutType','LogInd');
UseBstThr = QlExtOpts(1);
FllMptMdl = QlExtOpts(2);
EvalRndFI = QlExtOpts(3);

if EvalRndFI
    if isfield(ModelInfo, 'FeatureImportance') || (istable(ModelInfo) && ...
            ismember('FeatureImportance',ModelInfo.Properties.VariableNames))
        DsetFITyp = ModelInfo.FeatureImportance.Dataset;
        RndFtIdPs = find(contains(DsetTbl{'Total', 'Feats'}{:}.Properties.VariableNames, 'Rand', 'IgnoreCase',true));
        if isscalar(RndFtIdPs)
            RndFtName = DsetTbl{'Total', 'Feats'}{:}.Properties.VariableNames(RndFtIdPs);
        else
            warning(['No random feature (or multiple) found in your ', ...
                     'dataset! RandFeat importance will be skipped.'])
            EvalRndFI = false;
        end
    end
end

ColsNms = ANNs.Properties.VariableNames;

RegrANN = false;
switch OutMode
    case {'4 risk classes', 'L-NL classes'}

    case 'Regression'
        RegrANN = true;
        warning('Regression not yet tested, be careful!')

    otherwise
        error('OutMode choice not recognized!')
end

DoubleOut = true;
switch ANNMode
    case {'Classic (L)', 'Cross Validation (K-Fold M)', ...
            'Classic (V)', 'Cross Validation (K-Fold V)'}

    case {'Deep (L)', 'Deep (V)', 'Logistic Regression'}
        DoubleOut = false;

    case 'Sensitivity Analysis'

    case 'Auto'

    otherwise
        error('ANN Mode not recognized!')
end

if RegrANN
    DoubleOut = false;
end

if CrssVal
    load([fold_res_ml_curr,sl,Fl2LdMdl], 'CrossInfo')

    if exist('CrossInfo', 'var')
        CrossModels = CrossInfo.Models;
    else
        warning(['A cross validation dataset is present but no ', ...
                 'cross-models were found in TrainedMacroANNs!'])
        CrssVal = false;
    end
end

if HistMtr
    load([fold_res_ml_curr,sl,Fl2LdMdl], 'HistInfo')

    if exist('HistMdls', 'var')
        HistMdls = HistInfo.Models;
        if FllMptMdl && any(cellfun(@isempty, HistMdls), 'all')
            warning('Some models in history are empty and will be filled with the last available!')
            for i1 = 1:size(HistMdls, 2)
                for i2 = 2:size(HistMdls, 1)
                    if isempty(HistMdls{i2, i1})
                        HistMdls{i2, i1} = HistMdls{i2-1, i1};

                        HistInfo.Models{i2, i1} = HistMdls{i2-1, i1};
                        HistInfo.AUROC.Train(i2, i1) = HistInfo.AUROC.Train(i2-1, i1);
                        HistInfo.AUROC.Valid(i2, i1) = HistInfo.AUROC.Valid(i2-1, i1);
                        HistInfo.AUROC.Test( i2, i1) = HistInfo.AUROC.Test( i2-1, i1);
                    end
                end
            end
        end
    else
        warning(['A cross validation dataset is present but no ', ...
                 'cross-models were found in TrainedMacroANNs!'])
        HistMtr = false;
    end
end

%% Processing
ANNsPerfRows = {'Reca', 'Prec', 'AUC', 'BestThr', 'BestThrInd'};
ANNsPerf{{'PRC', 'PRGC'}, {'Train','Test'}} = {table('RowNames',ANNsPerfRows)};

[Thr4Trn, Thr4Tst, PrecTrn, ReclTrn, PrecTst, ReclTst, ...
    FScrTrn, FScrTst, PosMSETrn, NegMSETrn, PosMSETst, NegMSETst] = deal(nan(1, size(ANNs,2)));
for i1 = 1:size(ANNs,2)
    CurrMdl = ANNs{'Model', i1}{:};

    if UseBstThr
        Thr4Trn(i1) = ANNsPerf{'ROC','Train'}{:}{'BestThreshold',i1}{:};
        Thr4Tst(i1) = ANNsPerf{'ROC','Test' }{:}{'BestThreshold',i1}{:};
    else
        Thr4Trn(i1) = 0.5;
        Thr4Tst(i1) = 0.5;
    end

    PredsTrn  = mdlpredict(CurrMdl, DsetTbl{'Train', 'Feats'}{:}, 'SecondOut',DoubleOut);
    PredsTst  = mdlpredict(CurrMdl, DsetTbl{'Test' , 'Feats'}{:}, 'SecondOut',DoubleOut);

    ExpOutTrn = double(DsetTbl{'Train', 'ExpOuts'}{:} >= 1);
    ExpOutTst = double(DsetTbl{'Test' , 'ExpOuts'}{:} >= 1);

    % Separate MSE
    [PosMSETrn(i1), NegMSETrn(i1)] = mse_sep(ExpOutTrn, PredsTrn);
    [PosMSETst(i1), NegMSETst(i1)] = mse_sep(ExpOutTst, PredsTst);

    % F1 Scores
    [FScrTrn(i1), PrecTrn(i1), ReclTrn(i1)] = f1score(ExpOutTrn, PredsTrn, 'Threshold',Thr4Trn(i1));
    [FScrTst(i1), PrecTst(i1), ReclTst(i1)] = f1score(ExpOutTst, PredsTst, 'Threshold',Thr4Tst(i1));

    if isnan(FScrTrn(i1)) || isnan(FScrTst(i1))
        FScrTrn(i1) = 0;
        FScrTst(i1) = 0;
    end

    % Precision Recall curves
    [RcTrn, PrTrn, ThTrn, ...
        AUPRCTrn, OptThPRCTrn] = perfcurve(ExpOutTrn, PredsTrn, 1, ...
                                                        'XCrit','reca', ...
                                                        'YCrit','prec'); % OptThPRCTrn should be not available for AUPRC

    [RcTst, PrTst, ThTst, ...
        AUPRCTst, OptThPRCTst] = perfcurve(ExpOutTst, PredsTst, 1, ...
                                                        'XCrit','reca', ...
                                                        'YCrit','prec'); % OptThPRCTst should be not available for AUPRC

    if isnan(AUPRCTrn) || isnan(AUPRCTst)
        AUPRCTrn = 0;
        AUPRCTst = 0;
    end

    IndBstTrn = find(ismember([RcTrn, PrTrn], OptThPRCTrn, 'rows'));
    BstThrTrn = ThTrn(IndBstTrn);

    IndBstTst = find(ismember([RcTst, PrTst], OptThPRCTst, 'rows'));
    BstThrTst = ThTst(IndBstTst);

    % Precision Recall Gain curves
    PRGCrvTrn = create_prg_curve2(ExpOutTrn, PredsTrn);
    PRGCrvTst = create_prg_curve2(ExpOutTst, PredsTst);

    RcGainTrn = single(PRGCrvTrn.recall_gain);
    PrGainTrn = single(PRGCrvTrn.precision_gain);

    RcGainTst = single(PRGCrvTst.recall_gain);
    PrGainTst = single(PRGCrvTst.precision_gain);

    AUPRGCTrn = calc_auprg(PRGCrvTrn);
    AUPRGCTst = calc_auprg(PRGCrvTst);

    % Update ANNsPerf
    ANNsPerf{'PRC', 'Train'}{:}{ANNsPerfRows, i1} = {RcTrn; PrTrn; AUPRCTrn; BstThrTrn; IndBstTrn}; % Pay attention to the order!
    ANNsPerf{'PRC', 'Test' }{:}{ANNsPerfRows, i1} = {RcTst; PrTst; AUPRCTst; BstThrTst; IndBstTst}; % Pay attention to the order!

    ANNsPerf{'PRGC','Train'}{:}{ANNsPerfRows, i1} = {RcGainTrn; PrGainTrn; AUPRGCTrn; nan; nan}; % Pay attention to the order!
    ANNsPerf{'PRGC','Test' }{:}{ANNsPerfRows, i1} = {RcGainTst; PrGainTst; AUPRGCTst; nan; nan}; % Pay attention to the order!
end

% Update ANNsPerf
ANNsPerf{'PRC','Train'}{:}.Properties.VariableNames = ColsNms;
ANNsPerf{'PRC','Test' }{:}.Properties.VariableNames = ColsNms;

ANNsPerf{'PRGC','Train'}{:}.Properties.VariableNames = ColsNms;
ANNsPerf{'PRGC','Test' }{:}.Properties.VariableNames = ColsNms;

ANNsPerf{'Err','Train'}{:}{{'PosMSE','NegMSE'},ColsNms} = [PosMSETrn; NegMSETrn];
ANNsPerf{'Err','Test' }{:}{{'PosMSE','NegMSE'},ColsNms} = [PosMSETst; NegMSETst];

ANNsPerf{'F1S',{'Train','Test'}} = {array2table(num2cell([Thr4Trn; PrecTrn; ReclTrn; FScrTrn]), ...
                                                        'RowNames',{'Threshold','Precision','Recall','F1S'}, ...
                                                        'VariableNames',ColsNms), ...
                                    array2table(num2cell([Thr4Tst; PrecTst; ReclTst; FScrTst]), ...
                                                        'RowNames',{'Threshold','Precision','Recall','F1S'}, ...
                                                        'VariableNames',ColsNms)};

% QCI
MaxQCI = sqrt(4); % You have the maximum when you reach 1 in each metric! (square root of (1+1+1)). In this particular case you evaluate the Root mean square for QCITrn and QCITst
QCITrn = sqrt([ANNsPerf{'ROC' , 'Train'}{:}{'AUC', :}{:}].^2 + ...
              [ANNsPerf{'PRC' , 'Train'}{:}{'AUC', :}{:}].^2 + ...
              [ANNsPerf{'F1S' , 'Train'}{:}{'F1S', :}{:}].^2 + ...
              [ANNsPerf{'PRGC', 'Train'}{:}{'AUC', :}{:}].^2) ./ MaxQCI;

QCITst = sqrt([ANNsPerf{'ROC' , 'Test' }{:}{'AUC', :}{:}].^2 + ...
              [ANNsPerf{'PRC' , 'Test' }{:}{'AUC', :}{:}].^2 + ...
              [ANNsPerf{'F1S' , 'Test' }{:}{'F1S', :}{:}].^2 + ...
              [ANNsPerf{'PRGC', 'Test' }{:}{'AUC', :}{:}].^2) ./ MaxQCI;

ANNsPerf{'QCI',{'Train','Test'}} = {array2table(num2cell(QCITrn), 'RowNames',{'QCI'}, 'VariableNames',ColsNms), ...
                                    array2table(num2cell(QCITst), 'RowNames',{'QCI'}, 'VariableNames',ColsNms)};

%% Cross validation
if CrssVal
    [CrossTrnLoss, CrossValLoss, CrossTstLoss, ...
        CrossTrnMSE, CrossValMSE, CrossTstMSE, ...
            CrossTrnAUPRC, CrossValAUPRC, CrossTstAUPRC, ...
                CrossTrnAUPRGC, CrossValAUPRGC, CrossTstAUPRGC, CrossRndFeatImp] = deal(nan(size(CrossModels)));
    CrossFeatsRank = deal(cell(size(CrossModels)));
    for i1 = 1:size(CrossModels, 2)
        for i2 = 1:size(CrossModels, 1)
            disp(['Cross dataset n. ',num2str(i2),' of model n. ',num2str(i1)])
            
            PredsCrossTrnTemp = mdlpredict(CrossModels{i2,i1}, DsetTbl{'CvTrain','Feats'}{:}{i2}, 'SecondOut',DoubleOut);
            PredsCrossValTemp = mdlpredict(CrossModels{i2,i1}, DsetTbl{'CvValid','Feats'}{:}{i2}, 'SecondOut',DoubleOut);
            PredsCrossTstTemp = mdlpredict(CrossModels{i2,i1}, DsetTbl{'Test'   ,'Feats'}{:}    , 'SecondOut',DoubleOut);
        
            ExpOutCrssTrnTemp = double(DsetTbl{'CvTrain','ExpOuts'}{:}{i2} >= 1);
            ExpOutCrssValTemp = double(DsetTbl{'CvValid','ExpOuts'}{:}{i2} >= 1);
            ExpOutCrssTstTemp = double(DsetTbl{'Test'   ,'ExpOuts'}{:}     >= 1);

            % AUPRC
            [~, ~, ~, CrossTrnAUPRC(i2, i1), ~] = perfcurve(ExpOutCrssTrnTemp, PredsCrossTrnTemp, 1, 'XCrit','reca', 'YCrit','prec');
            [~, ~, ~, CrossValAUPRC(i2, i1), ~] = perfcurve(ExpOutCrssValTemp, PredsCrossValTemp, 1, 'XCrit','reca', 'YCrit','prec');
            [~, ~, ~, CrossTstAUPRC(i2, i1), ~] = perfcurve(ExpOutCrssTstTemp, PredsCrossTstTemp, 1, 'XCrit','reca', 'YCrit','prec');

            % AUPRGC
            PRGCrvCrossTrnTemp = create_prg_curve2(ExpOutCrssTrnTemp, PredsCrossTrnTemp);
            PRGCrvCrossValTemp = create_prg_curve2(ExpOutCrssValTemp, PredsCrossValTemp);
            PRGCrvCrossTstTemp = create_prg_curve2(ExpOutCrssTstTemp, PredsCrossTstTemp);

            CrossTrnAUPRGC(i2, i1) = calc_auprg(PRGCrvCrossTrnTemp);
            CrossValAUPRGC(i2, i1) = calc_auprg(PRGCrvCrossValTemp);
            CrossTstAUPRGC(i2, i1) = calc_auprg(PRGCrvCrossTstTemp);

            % Loss
            CrossTrnLoss(i2, i1) = crossentropy2(PredsCrossTrnTemp, ExpOutCrssTrnTemp);
            CrossValLoss(i2, i1) = crossentropy2(PredsCrossValTemp, ExpOutCrssValTemp);
            CrossTstLoss(i2, i1) = crossentropy2(PredsCrossTstTemp, ExpOutCrssTstTemp);

            % MSE
            CrossTrnMSE(i2, i1) = mse(PredsCrossTrnTemp, ExpOutCrssTrnTemp);
            CrossValMSE(i2, i1) = mse(PredsCrossValTemp, ExpOutCrssValTemp);
            CrossTstMSE(i2, i1) = mse(PredsCrossTstTemp, ExpOutCrssTstTemp);

            % Rand Feat Importance
            if EvalRndFI
                switch DsetFITyp
                    case 'Only Train'
                        IndTrnPrt = ismember(DsetTbl{'Total','Feats'}{:}, DsetTbl{'CvTrain','Feats'}{:}{i2}, 'rows');
                        DatasetFI = DsetTbl{'Total','Feats'  }{:}(IndTrnPrt, :); % It is important to do like this because DatasetEvsFeatsTrn could contain repetitions (overfitting)!
                        ExpOutsFI = DsetTbl{'Total','ExpOuts'}{:}(IndTrnPrt, :);
                
                    case 'Only Test'
                        IndTstPrt = ismember(DsetTbl{'Total','Feats'}{:}, DsetTbl{'Test'   ,'Feats'}{:}    , 'rows');
                        IndValPrt = ismember(DsetTbl{'Total','Feats'}{:}, DsetTbl{'CvValid','Feats'}{:}{i2}, 'rows');
                        if any(IndTstPrt & IndValPrt)
                            error(['Some observations is Test part are also in ' ...
                                   'Validation part! Please check the datasets!'])
                        else
                            IndTotTstPrt = IndTstPrt | IndValPrt;
                        end
                        DatasetFI = DsetTbl{'Total','Feats'  }{:}(IndTotTstPrt, :); % It is important to do like this because DatasetEvsFeatsTst could contain repetitions (overfitting)!
                        ExpOutsFI = DsetTbl{'Total','ExpOuts'}{:}(IndTotTstPrt, :);
                
                    case 'Train + Test'
                        DatasetFI = DsetTbl{'Total','Feats'  }{:};
                        ExpOutsFI = DsetTbl{'Total','ExpOuts'}{:};
                end
    
                CrossFeatsRank{i2, i1}  = feature_importance(CrossModels{i2,i1}, DatasetFI, ExpOutsFI);
                CrossRndFeatImp(i2, i1) = CrossFeatsRank{i2, i1}{'PercentagesMSE',RndFtName};
            end

        end
    end

    CrossInfo.Loss   = struct('Train',CrossTrnLoss  , 'Valid',CrossValLoss  , 'Test',CrossTstLoss  );
    CrossInfo.MSE    = struct('Train',CrossTrnMSE   , 'Valid',CrossValMSE   , 'Test',CrossTstMSE   );
    CrossInfo.AUPRC  = struct('Train',CrossTrnAUPRC , 'Valid',CrossValAUPRC , 'Test',CrossTstAUPRC );
    CrossInfo.AUPRGC = struct('Train',CrossTrnAUPRGC, 'Valid',CrossValAUPRGC, 'Test',CrossTstAUPRGC);
    if EvalRndFI
        CrossInfo.FeatImp = struct('Ranking',CrossFeatsRank, 'RandFeat',CrossRndFeatImp);
    end
end

%% History
if HistMtr
    [HistTrnLoss, HistValLoss, HistTstLoss, ...
        HistTrnMSE, HistValMSE, HistTstMSE, ...
            HistTrnAUPRC, HistValAUPRC, HistTstAUPRC, ...
                HistTrnAUPRGC, HistValAUPRGC, HistTstAUPRGC] = deal(nan(size(HistMdls)));
    for i1 = 1:size(HistMdls, 2)
        for i2 = 1:size(HistMdls, 1)
            disp(['Model n. ',num2str(i1),' at ireation ',num2str(i2)])

            if isempty(HistMdls{i2,i1})
                warning(['Model in row n. ',num2str(i2), ...
                         ' and column n. ',num2str(i1),' is empty!'])
                continue
            end
            
            PredsHistTrnTemp = mdlpredict(HistMdls{i2,i1}, DsetTbl{'NvTrain','Feats'}{:}, 'SecondOut',DoubleOut);
            PredsHistValTemp = mdlpredict(HistMdls{i2,i1}, DsetTbl{'NvValid','Feats'}{:}, 'SecondOut',DoubleOut);
            PredsHistTstTemp = mdlpredict(HistMdls{i2,i1}, DsetTbl{'Test'   ,'Feats'}{:}, 'SecondOut',DoubleOut);
        
            ExpOutHstTrnTemp = double(DsetTbl{'NvTrain','ExpOuts'}{:} >= 1);
            ExpOutHstValTemp = double(DsetTbl{'NvValid','ExpOuts'}{:} >= 1);
            ExpOutHstTstTemp = double(DsetTbl{'Test'   ,'ExpOuts'}{:} >= 1);

            % AUPRC
            [~, ~, ~, HistTrnAUPRC(i2, i1), ~] = perfcurve(ExpOutHstTrnTemp, PredsHistTrnTemp, 1, 'XCrit','reca', 'YCrit','prec');
            [~, ~, ~, HistValAUPRC(i2, i1), ~] = perfcurve(ExpOutHstValTemp, PredsHistValTemp, 1, 'XCrit','reca', 'YCrit','prec');
            [~, ~, ~, HistTstAUPRC(i2, i1), ~] = perfcurve(ExpOutHstTstTemp, PredsHistTstTemp, 1, 'XCrit','reca', 'YCrit','prec');

            % AUPRGC
            PRGCrvHistTrnTemp = create_prg_curve2(ExpOutHstTrnTemp, PredsHistTrnTemp);
            PRGCrvHistValTemp = create_prg_curve2(ExpOutHstValTemp, PredsHistValTemp);
            PRGCrvHistTstTemp = create_prg_curve2(ExpOutHstTstTemp, PredsHistTstTemp);

            HistTrnAUPRGC(i2, i1) = calc_auprg(PRGCrvHistTrnTemp);
            HistValAUPRGC(i2, i1) = calc_auprg(PRGCrvHistValTemp);
            HistTstAUPRGC(i2, i1) = calc_auprg(PRGCrvHistTstTemp);

            % Loss
            HistTrnLoss(i2, i1) = crossentropy2(PredsHistTrnTemp, ExpOutHstTrnTemp);
            HistValLoss(i2, i1) = crossentropy2(PredsHistValTemp, ExpOutHstValTemp);
            HistTstLoss(i2, i1) = crossentropy2(PredsHistTstTemp, ExpOutHstTstTemp);

            % MSE
            HistTrnMSE(i2, i1) = mse(PredsHistTrnTemp, ExpOutHstTrnTemp);
            HistValMSE(i2, i1) = mse(PredsHistValTemp, ExpOutHstValTemp);
            HistTstMSE(i2, i1) = mse(PredsHistTstTemp, ExpOutHstTstTemp);
        end
    end

    % Rand Feat Importance
    if EvalRndFI
        switch DsetFITyp
            case 'Only Train'
                IndTrnPrt = ismember(DsetTbl{'Total','Feats'}{:}, DsetTbl{'NvTrain','Feats'}{:}, 'rows');
                DatasetFI = DsetTbl{'Total','Feats'  }{:}(IndTrnPrt, :); % It is important to do like this because DatasetEvsFeatsTrn could contain repetitions (overfitting)!
                ExpOutsFI = DsetTbl{'Total','ExpOuts'}{:}(IndTrnPrt, :);
        
            case 'Only Test'
                IndTstPrt = ismember(DsetTbl{'Total','Feats'}{:}, DsetTbl{'Test'   ,'Feats'}{:}, 'rows');
                IndValPrt = ismember(DsetTbl{'Total','Feats'}{:}, DsetTbl{'NvValid','Feats'}{:}, 'rows');
                if any(IndTstPrt & IndValPrt)
                    error(['Some observations is Test part are also in ' ...
                           'Validation part! Please check the datasets!'])
                else
                    IndTotTstPrt = IndTstPrt | IndValPrt;
                end
                DatasetFI = DsetTbl{'Total','Feats'  }{:}(IndTotTstPrt, :); % It is important to do like this because DatasetEvsFeatsTst could contain repetitions (overfitting)!
                ExpOutsFI = DsetTbl{'Total','ExpOuts'}{:}(IndTotTstPrt, :);
        
            case 'Train + Test'
                DatasetFI = DsetTbl{'Total','Feats'  }{:};
                ExpOutsFI = DsetTbl{'Total','ExpOuts'}{:};
        end

        HistRndFeatImp = deal(nan(size(HistMdls)));
        HistFeatsRank  = deal(cell(size(HistMdls)));
        for i1 = 1:size(HistMdls, 2)
            for i2 = 1:size(HistMdls, 1)
                disp(['Rand feat of model n. ',num2str(i1),' at ireation ',num2str(i2)])

                if isempty(HistMdls{i2,i1})
                    warning(['Model in row n. ',num2str(i2), ...
                             ' and column n. ',num2str(i1),' is empty!'])
                    continue
                end

                HistFeatsRank{i2, i1}  = feature_importance(HistMdls{i2,i1}, DatasetFI, ExpOutsFI);
                HistRndFeatImp(i2, i1) = HistFeatsRank{i2, i1}{'PercentagesMSE',RndFtName};
            end
        end
    end
    
    HistInfo.Loss   = struct('Train',HistTrnLoss  , 'Valid',HistValLoss  , 'Test',HistTstLoss  );
    HistInfo.MSE    = struct('Train',HistTrnMSE   , 'Valid',HistValMSE   , 'Test',HistTstMSE   );
    HistInfo.AUPRC  = struct('Train',HistTrnAUPRC , 'Valid',HistValAUPRC , 'Test',HistTstAUPRC );
    HistInfo.AUPRGC = struct('Train',HistTrnAUPRGC, 'Valid',HistValAUPRGC, 'Test',HistTstAUPRGC);
    if EvalRndFI
        HistInfo.FeatImp = struct('Ranking',HistFeatsRank, 'RandFeat',HistRndFeatImp);
    end
end

%% Best mdls
AUROCTrn  = cell2mat(ANNsPerf{'ROC','Train'}{:}{'AUC',:});
AUROCTst  = cell2mat(ANNsPerf{'ROC','Test' }{:}{'AUC',:});

LssMSETrn = ANNsPerf{'Err','Train'}{:}{'MSE',:};
LssMSETst = ANNsPerf{'Err','Test' }{:}{'MSE',:};

AUPRCTrn  = cell2mat(ANNsPerf{'PRC','Train'}{:}{'AUC',:});
AUPRCTst  = cell2mat(ANNsPerf{'PRC','Test' }{:}{'AUC',:});

AUPRGCTrn = cell2mat(ANNsPerf{'PRGC','Train'}{:}{'AUC',:});
AUPRGCTst = cell2mat(ANNsPerf{'PRGC','Test' }{:}{'AUC',:});

% The best one is always the first!
[~, RankAUROCTrn]  = sort(AUROCTrn, 'descend');
[~, RankAUROCTst]  = sort(AUROCTst, 'descend');

[~, RankLssMSETrn] = sort(LssMSETrn); % The best one is already the first, no need to invert order!
[~, RankLssMSETst] = sort(LssMSETst); % The best one is already the first, no need to invert order!

[~, RankAUPRCTrn]  = sort(AUPRCTrn, 'descend');
[~, RankAUPRCTst]  = sort(AUPRCTst, 'descend');

[~, RankAUPRGCTrn] = sort(AUPRGCTrn, 'descend');
[~, RankAUPRGCTst] = sort(AUPRGCTst, 'descend');

[~, RankFScoreTrn] = sort(FScrTrn, 'descend');
[~, RankFScoreTst] = sort(FScrTst, 'descend');

[~, RankQCIndTrn]  = sort(QCITrn, 'descend');
[~, RankQCIndTst]  = sort(QCITst, 'descend');

% Best models (all)
BstMdlAUROCTrn  = RankAUROCTrn(1);
BstMdlAUROCTst  = RankAUROCTst(1);

BstMdlLssMSETrn = RankLssMSETrn(1);
BstMdlLssMSETst = RankLssMSETst(1);

BstMdlAUPRCTrn  = RankAUPRCTrn(1);
BstMdlAUPRCTst  = RankAUPRCTst(1);

BstMdlAUPRGCTrn = RankAUPRGCTrn(1);
BstMdlAUPRGCTst = RankAUPRGCTst(1);

BstMdlFScoreTrn = RankFScoreTrn(1);
BstMdlFScoreTst = RankFScoreTst(1);

BstMdlQCIndTrn  = RankQCIndTrn(1);
BstMdlQCIndTst  = RankQCIndTst(1);

% Update ANNsPerf with best mdls
ANNsPerf{{'ROC','Err','PRC','PRGC','F1S','QCI'},'RankTrn'} = {RankAUROCTrn; ...
                                                              RankLssMSETrn; ...
                                                              RankAUPRCTrn; ...
                                                              RankAUPRGCTrn; ...
                                                              RankFScoreTrn; ...
                                                              RankQCIndTrn};

ANNsPerf{{'ROC','Err','PRC','PRGC','F1S','QCI'},'RankTst'} = {RankAUROCTst; ...
                                                              RankLssMSETst; ...
                                                              RankAUPRCTst; ...
                                                              RankAUPRGCTst; ...
                                                              RankFScoreTst; ...
                                                              RankQCIndTst};

ANNsPerf{{'ROC','Err','PRC','PRGC','F1S','QCI'},'BstMdlTrn'} = {BstMdlAUROCTrn; ...
                                                                BstMdlLssMSETrn; ...
                                                                BstMdlAUPRCTrn; ...
                                                                BstMdlAUPRGCTrn; ...
                                                                BstMdlFScoreTrn; ...
                                                                BstMdlQCIndTrn};

ANNsPerf{{'ROC','Err','PRC','PRGC','F1S','QCI'},'BstMdlTst'} = {BstMdlAUROCTst; ...
                                                                BstMdlLssMSETst; ...
                                                                BstMdlAUPRCTst; ...
                                                                BstMdlAUPRGCTst; ...
                                                                BstMdlFScoreTst; ...
                                                                BstMdlQCIndTst};

%% Saving (update)
VariablesToUpdate = {'ANNsPerf'};
if CrssVal
    VariablesToUpdate = [VariablesToUpdate, {'CrossInfo'}];
end

if HistMtr
    VariablesToUpdate = [VariablesToUpdate, {'HistInfo' }];
end

save([fold_res_ml_curr,sl,Fl2LdMdl], VariablesToUpdate{:}, '-append')