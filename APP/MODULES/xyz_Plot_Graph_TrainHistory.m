if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files
sl = filesep;

fold_res_ml_curr = uigetdir(pwd, 'Chose your analysis folder');
load([fold_res_ml_curr,sl,'MLMdlA.mat'], 'HistInfo','MLMdl')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SelFont = Font;
    SelFnSz = FontSize;
    if exist('LegendPosition', 'var'); LgndPos = LegendPosition; else; LgndPos = 'eastoutside'; end
else
    SelFont = 'Calibri';
    SelFnSz = 6;
    LgndPos = 'eastoutside';
end

HistTrnAUROC  = HistInfo.AUROC.Train;
HistValAUROC  = HistInfo.AUROC.Valid;
HistTstAUROC  = HistInfo.AUROC.Test;
HistTrnAUPRGC = HistInfo.AUPRGC.Train;
HistValAUPRGC = HistInfo.AUPRGC.Valid;
HistTstAUPRGC = HistInfo.AUPRGC.Test;
HistTrnLoss   = HistInfo.Loss.Train;
HistValLoss   = HistInfo.Loss.Valid;
HistTstLoss   = HistInfo.Loss.Test;
HistTrnMSE    = HistInfo.MSE.Train;
HistValMSE    = HistInfo.MSE.Valid;
HistTstMSE    = HistInfo.MSE.Test;

MdlNames = MLMdl.Properties.VariableNames;
MdlStrct = MLMdl{'Structure',:};

MdlNames = inputdlg2(strcat({'New name for '},MdlNames), 'DefInp',MdlNames);
MLMdl.Properties.VariableNames = MdlNames;

%% Options
ProgressBar.Message = 'Options...';

DsetPrt = {'Trn','Val','Tst'};

PltOpts = checkbox2({'Show plots', 'Remove NaNs cols', 'Smooth curves'}, 'OutType','LogInd');
ShowPlt = PltOpts(1);
RmvNanC = PltOpts(2);
SmthCrv = PltOpts(3);

if SmthCrv
    CrvType = 'Smooth';
else
    CrvType = 'Raw';
end

LnWidth = .8;

Plt2Shw = checkbox2({'Separate metrics', 'Difference between metrics', ...
                     'Unique metrics'}, 'Title',{'Figures to plot:'}, ...
                                        'OutType','LogInd');
SepMtrc = Plt2Shw(1);
DffMtrc = Plt2Shw(2);
UnqMtrc = Plt2Shw(3);

if SepMtrc
    PltExtr = checkbox2({'All models in 1', 'Diff colors dset'}, ...
                        'Title',{'Extra options:'}, 'OutType','LogInd', 'DefInp',[1, 1]);
    CompMdl = PltExtr(1);
    DiffClr = PltExtr(2);
    Mdl2Plt = checkbox2(MdlNames, 'Title',{'Models to plot:'});
end

if DffMtrc
    GenCapt = {'Val-Tst', 'Trn-Tst'};
    AxRatio = eval(char(inputdlg2('Specify ratio:', 'DefInp',{'[3, 1, 1]'})));
    FigCont = checkbox2({'AUROC', 'AUPRGC', 'Loss', 'MSE'}, 'Title',{'Select metrics to plot:'});
    ClrCont = {'#739373', '#d3643c', '#0097df'};
end

if UnqMtrc
    Mdl     = 1:numel(MdlNames); % It can be also an array but it must be horizontal (ex: Mdl = 1:10;)
    TbIdUsd = checkbox2(DsetPrt, 'Title',{'Select datasets:'});
    DsetLbl = inputdlg2(strcat("Label name for ",TbIdUsd), 'DefInp',TbIdUsd);
    AxRatio = eval(char(inputdlg2('Axis ratio:', 'DefInp',{'[1.5, 1, 1]'})));
    FigCont = {{'AUROC', 'AUPRGC'}, {'Loss'}};
    Colors  = {{'#739373', '#d3643c'}, {'#0097df'}}; % Colors
    yLmCont = cellfun(@eval, inputdlg2( cellfun(@(x) strjoin(x, '; '), FigCont, 'UniformOutput',false), ...
                                                        'DefInp',repmat({'[0, 1]'}, 1, numel(FigCont)) ), 'UniformOutput',false);
end

%% Processing
ProgressBar.Message = 'Processing...';

IterNames = strcat('It ',string(1:size(HistTrnAUROC,1))');
HistNmbr  = numel(IterNames);
MdlsNmbr  = numel(MdlNames);

if RmvNanC
    ColsNotCompl = any(isnan(HistValLoss), 1); % [false, false, false];
    
    MdlNames(:,ColsNotCompl)   = [];
    MdlStrct(:,ColsNotCompl)   = [];
    
    % Raw curves (not smoothed)
    HistTrnAUROC(:,ColsNotCompl)  = [];
    HistTrnAUPRGC(:,ColsNotCompl) = [];
    HistTrnLoss(:,ColsNotCompl)   = [];
    HistTrnMSE(:,ColsNotCompl)    = [];
    
    HistValAUROC(:,ColsNotCompl)  = [];
    HistValAUPRGC(:,ColsNotCompl) = [];
    HistValLoss(:,ColsNotCompl)   = [];
    HistValMSE(:,ColsNotCompl)    = [];
    
    HistTstAUROC(:,ColsNotCompl)  = [];
    HistTstAUPRGC(:,ColsNotCompl) = [];
    HistTstLoss(:,ColsNotCompl)   = [];
    HistTstMSE(:,ColsNotCompl)    = [];
end

% Best models (not smoothed)
[MaxAUROCTrn, EpMaxAUROCTrn] = max(HistTrnAUROC, [], 1);
[MaxAUROCVal, EpMaxAUROCVal] = max(HistValAUROC, [], 1);
[MaxAUROCTst, EpMaxAUROCTst] = max(HistTstAUROC, [], 1);

[MaxAUPRGCTrn, EpMaxAUPRGCTrn] = max(HistTrnAUPRGC, [], 1);
[MaxAUPRGCVal, EpMaxAUPRGCVal] = max(HistValAUPRGC, [], 1);
[MaxAUPRGCTst, EpMaxAUPRGCTst] = max(HistTstAUPRGC, [], 1);

[MinLossTrn, EpMinLossTrn] = min(HistTrnLoss, [], 1);
[MinLossVal, EpMinLossVal] = min(HistValLoss, [], 1);
[MinLossTst, EpMinLossTst] = max(HistTstLoss, [], 1);

[MinMSETrn, EpMinMSETrn] = min(HistTrnMSE, [], 1);
[MinMSEVal, EpMinMSEVal] = min(HistValMSE, [], 1);
[MinMSETst, EpMinMSETst] = min(HistTstMSE, [], 1);

% Difference between best models (not smoothed)
DiffValTstAUROC  = EpMaxAUROCVal  - EpMaxAUROCTst;
DiffValTstAUPRGC = EpMaxAUPRGCVal - EpMaxAUPRGCTst;
DiffValTstLoss   = EpMinLossVal   - EpMinLossTst;
DiffValTstMSE    = EpMinMSEVal    - EpMinMSETst;

DiffTrnTstAUROC  = EpMaxAUROCTrn  - EpMaxAUROCTst;
DiffTrnTstAUPRGC = EpMaxAUPRGCTrn - EpMaxAUPRGCTst;
DiffTrnTstLoss   = EpMinLossTrn   - EpMinLossTst;
DiffTrnTstMSE    = EpMinMSETrn    - EpMinMSETst;

% Smoothed curves
[SmHistTrnAUROC, SmHistTrnAUPRGC, SmHistTrnLoss, SmHistTrnMSE, ...
    SmHistValAUROC, SmHistValAUPRGC, SmHistValLoss, SmHistValMSE, ...
        SmHistTstAUROC, SmHistTstAUPRGC, SmHistTstLoss, SmHistTstMSE] = deal(zeros(size(HistTrnAUROC)));
for i1 = 1:size(HistTrnAUROC, 2)
    SmHistTrnAUROC(:,i1)  = smooth(HistTrnAUROC(:,i1));
    SmHistTrnAUPRGC(:,i1) = smooth(HistTrnAUPRGC(:,i1));
    SmHistTrnLoss(:,i1)   = smooth(HistTrnLoss(:,i1));
    SmHistTrnMSE(:,i1)    = smooth(HistTrnMSE(:,i1));

    SmHistValAUROC(:,i1)  = smooth(HistValAUROC(:,i1));
    SmHistValAUPRGC(:,i1) = smooth(HistValAUPRGC(:,i1));
    SmHistValLoss(:,i1)   = smooth(HistValLoss(:,i1));
    SmHistValMSE(:,i1)    = smooth(HistValMSE(:,i1));

    SmHistTstAUROC(:,i1)  = smooth(HistTstAUROC(:,i1));
    SmHistTstAUPRGC(:,i1) = smooth(HistTstAUPRGC(:,i1));
    SmHistTstLoss(:,i1)   = smooth(HistTstLoss(:,i1));
    SmHistTstMSE(:,i1)    = smooth(HistTstMSE(:,i1));
end

% Best models (smoothed)
[SmMaxAUROCTrn, SmEpMaxAUROCTrn] = max(SmHistTrnAUROC, [], 1);
[SmMaxAUROCVal, SmEpMaxAUROCVal] = max(SmHistValAUROC, [], 1);
[SmMaxAUROCTst, SmEpMaxAUROCTst] = max(SmHistTstAUROC, [], 1);

[SmMaxAUPRGCTrn, SmEpMaxAUPRGCTrn] = max(SmHistTrnAUPRGC, [], 1);
[SmMaxAUPRGCVal, SmEpMaxAUPRGCVal] = max(SmHistValAUPRGC, [], 1);
[SmMaxAUPRGCTst, SmEpMaxAUPRGCTst] = max(SmHistTstAUPRGC, [], 1);

[SmMinLossTrn, SmEpMinLossTrn] = min(SmHistTrnLoss, [], 1);
[SmMinLossVal, SmEpMinLossVal] = min(SmHistValLoss, [], 1);
[SmMinLossTst, SmEpMinLossTst] = min(SmHistTstLoss, [], 1);

[SmMinMSETrn, SmEpMinMSETrn] = min(SmHistTrnMSE, [], 1);
[SmMinMSEVal, SmEpMinMSEVal] = min(SmHistValMSE, [], 1);
[SmMinMSETst, SmEpMinMSETst] = min(SmHistTstMSE, [], 1);

% Difference between best models (smoothed)
SmDiffValTstAUROC  = SmEpMaxAUROCVal  - SmEpMaxAUROCTst;
SmDiffValTstAUPRGC = SmEpMaxAUPRGCVal - SmEpMaxAUPRGCTst;
SmDiffValTstLoss   = SmEpMinLossVal   - SmEpMinLossTst ;
SmDiffValTstMSE    = SmEpMinMSEVal    - SmEpMinMSETst  ;

SmDiffTrnTstAUROC  = SmEpMaxAUROCTrn  - SmEpMaxAUROCTst;
SmDiffTrnTstAUPRGC = SmEpMaxAUPRGCTrn - SmEpMaxAUPRGCTst;
SmDiffTrnTstLoss   = SmEpMinLossTrn   - SmEpMinLossTst ;
SmDiffTrnTstMSE    = SmEpMinMSETrn    - SmEpMinMSETst  ;

%% Creation of table with differences
MLSens = table('RowNames',{'Val-Tst','Trn-Tst'});

MLSens{:,{'Raw','Smooth'}} = {table()};

MLSens{'Val-Tst','Raw'   } = {array2table([DiffValTstAUROC ; ...
                                           DiffValTstAUPRGC; ...
                                           DiffValTstLoss  ; ...
                                           DiffValTstMSE   ], 'RowNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                              'VariableNames',MdlNames)};

MLSens{'Trn-Tst','Raw'   } = {array2table([DiffTrnTstAUROC ; ...
                                           DiffTrnTstAUPRGC; ...
                                           DiffTrnTstLoss  ; ...
                                           DiffTrnTstMSE   ], 'RowNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                              'VariableNames',MdlNames)};

MLSens{'Val-Tst','Smooth'} = {array2table([SmDiffValTstAUROC ; ...
                                           SmDiffValTstAUPRGC; ...
                                           SmDiffValTstLoss  ; ...
                                           SmDiffValTstMSE   ], 'RowNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                                'VariableNames',MdlNames)};

MLSens{'Trn-Tst','Smooth'} = {array2table([SmDiffTrnTstAUROC ; ...
                                           SmDiffTrnTstAUPRGC; ...
                                           SmDiffTrnTstLoss  ; ...
                                           SmDiffTrnTstMSE   ], 'RowNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                                'VariableNames',MdlNames)};

%% Creation of table with history during training
MLHist = table('RowNames',DsetPrt);

MLHist{:,{'Raw','Smooth'}} = {table()};

MLHist{'Trn','Raw'   } = { table({array2table(HistTrnAUROC , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(HistTrnAUPRGC, 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(HistTrnLoss  , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(HistTrnMSE   , 'RowNames',IterNames, 'VariableNames',MdlNames)}, 'VariableNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                                                                               'RowNames',{'Hist'}) };

MLHist{'Val','Raw'   } = { table({array2table(HistValAUROC , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(HistValAUPRGC, 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(HistValLoss  , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(HistValMSE   , 'RowNames',IterNames, 'VariableNames',MdlNames)}, 'VariableNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                                                                               'RowNames',{'Hist'}) };

MLHist{'Tst','Raw'   } = { table({array2table(HistTstAUROC , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(HistTstAUPRGC, 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(HistTstLoss  , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(HistTstMSE   , 'RowNames',IterNames, 'VariableNames',MdlNames)}, 'VariableNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                                                                               'RowNames',{'Hist'}) };

MLHist{'Trn','Smooth'} = { table({array2table(SmHistTrnAUROC , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(SmHistTrnAUPRGC, 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(SmHistTrnLoss  , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(SmHistTrnMSE   , 'RowNames',IterNames, 'VariableNames',MdlNames)}, 'VariableNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                                                                                 'RowNames',{'Hist'}) };

MLHist{'Val','Smooth'} = { table({array2table(SmHistValAUROC , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(SmHistValAUPRGC, 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(SmHistValLoss  , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(SmHistValMSE   , 'RowNames',IterNames, 'VariableNames',MdlNames)}, 'VariableNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                                                                                 'RowNames',{'Hist'}) };

MLHist{'Tst','Smooth'} = { table({array2table(SmHistTstAUROC , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(SmHistTstAUPRGC, 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(SmHistTstLoss  , 'RowNames',IterNames, 'VariableNames',MdlNames)}, ...
                                 {array2table(SmHistTstMSE   , 'RowNames',IterNames, 'VariableNames',MdlNames)}, 'VariableNames',{'AUROC','AUPRGC','Loss','MSE'}, ...
                                                                                                                 'RowNames',{'Hist'}) };

%% Figure 1
ProgressBar.Message = 'Plot fig 1...';

if SepMtrc
    MdlStrc = MdlStrct(ismember(MdlNames, Mdl2Plt)); % The order of arguments is important!
    if CompMdl
        if numel(Mdl2Plt) > 3
            error('You must use this option with a maximum of 3 models!')
        end
        Mdl2Plt = {Mdl2Plt};
        MdlStrc = {MdlStrc};
    else
        Mdl2Plt = num2cell(Mdl2Plt);
        MdlStrc = num2cell(MdlStrc);
    end

    DsetUsd = checkbox2({'Train', 'Validation', 'Test'}, 'Title',{'Select datasets:'});
    TbIdAss = listdlg2(strcat("Row name for ",DsetUsd), MLHist.Properties.RowNames);
    AxRatio = eval(char(inputdlg2('Specify ratio:', 'DefInp',{'[1.5, 1, 1]'})));
    FigCont = checkbox2({'AUROC', 'AUPRGC', 'Loss', 'MSE'}, 'Title',{'Select metrics to plot:'});
    yLmCont = cellfun(@eval, inputdlg2(FigCont, 'DefInp',repmat({'[0, 1]'}, 1, numel(FigCont))), 'UniformOutput',false);

    if DiffClr
        Colors = {'#15355a', '#217fa6', '#abc7d6'; ...
                  '#f10750', '#e07ab9', '#ffc000'; ...
                  '#055351', '#b0c1b3', '#e5d3bb'}; % Colors
    else
        Colors = repmat({'#739373'; '#d3643c'; '#0097df'}, 1, numel(DsetUsd)); % Colors
    end
    LnOpts  = {'-', '--', '-.'}; % Linetype for Train, Validation, and Test
    IndComb = cellfun(@(x) combvec(1:numel(DsetUsd), 1:numel(x)), Mdl2Plt, 'UniformOutput',false);
    TblIdsC = cellfun(@(x,y) y(x(2,:)), IndComb, Mdl2Plt, 'UniformOutput',false);
    MdlsLbl = cellfun(@(x,y) y(x(2,:)), IndComb, MdlStrc, 'UniformOutput',false);
    TblIdsR = cellfun(@(x) TbIdAss(x(1,:)), IndComb, 'UniformOutput',false);
    DsetLbl = cellfun(@(x) DsetUsd(x(1,:)), IndComb, 'UniformOutput',false);
    if CompMdl
        ClrsIds = cellfun(@(x) Colors(sub2ind(size(Colors), x(2,:), x(1,:))), IndComb, 'UniformOutput',false);
        LnType  = cellfun(@(x) LnOpts(x(1,:)), IndComb, 'UniformOutput',false);
    else
        ClrsIds = cellfun(@(x) Colors(sub2ind(size(Colors), x(1,:), x(2,:))), IndComb, 'UniformOutput',false);
        LnType  = cellfun(@(x) LnOpts(x(2,:)), IndComb, 'UniformOutput',false);
    end

    GenLbls = cellfun(@(x,y) strcat(x, {' of '}, y), DsetLbl, TblIdsC, 'UniformOutput',false);
    
    FldName = 'History Plots';
    if ~exist(FldName, 'dir')
        mkdir(FldName)
    end
    
    FldNameSub = cell(1, numel(FigCont));
    for i1 = 1:numel(FigCont)
        FldNameSub{i1} = [FldName,sl,CrvType,sl,FigCont{i1}];
        if ~exist(FldNameSub{i1}, 'dir')
            mkdir(FldNameSub{i1})
        end
    end
    
    for i1 = 1:numel(Mdl2Plt)
        for i2 = 1:numel(FigCont)
            hFlnmFg1 = [FigCont{i2},' history of ',char(join(Mdl2Plt{i1}, '-'))];
            hFigHist = figure(i2);
            hAxsHist = subplot(1, 1, 1, 'FontName',SelFont, 'FontSize',SelFnSz, 'Parent',hFigHist);
            
            set(hFigHist, 'Name',hFlnmFg1, 'visible','off')
            set(hAxsHist, 'FontName',SelFont, 'FontSize',.8*SelFnSz, ...
                          'YGrid','on', 'XGrid','on', ...
                          'YLim',yLmCont{i2}, 'YColor','#000000')
            hold(hAxsHist, 'on')
            
            hLnPlt = cell(1, numel(GenLbls{i1}));
            for i3 = 1:numel(GenLbls{i1})
                hLnPlt{i3} = plot(1:HistNmbr, MLHist{TblIdsR{i1}(i3), ...
                                                       CrvType}{:}{'Hist',FigCont{i2}}{:}{:,TblIdsC{i1}(i3)}, ...
                                                   'Color',ClrsIds{i1}{i3}, 'LineStyle',LnType{i1}{i3}, ...
                                                   'Marker','none', 'LineWidth',LnWidth, 'Parent',hAxsHist);
            end
            
            xlabel('Iteration', 'FontName',SelFont, 'FontSize',SelFnSz)
            ylabel(FigCont{i2}, 'FontName',SelFont, 'FontSize',SelFnSz)
    
            xlim([0, HistNmbr])
            ylim(yLmCont{i2})
    
            SubTxt = join(strcat(Mdl2Plt{i1},{': ['},cellfun(@(x) char(join(string(x),',')), MdlStrc{i1}, 'UniformOutput',false),{'];'}), ' ');
            
            title(hFlnmFg1 , 'FontName',SelFont, 'FontSize',1.5*SelFnSz)
            subtitle(SubTxt, 'FontName',SelFont, 'FontSize',SelFnSz    )
        
            if any(strcmp(FigCont{i2}, {'AUROC', 'AUPRGC'}))
                LgndPosTmp = 'eastoutside';
            else
                LgndPosTmp = LgndPos;
            end
            
            hLeg = legend([hLnPlt{:}], ...
                          [GenLbls{i1}(:)], ...
                          'NumColumns',1, ...
                          'FontName',SelFont, ...
                          'FontSize',0.7*SelFnSz, ...
                          'Location',LgndPosTmp, ...
                          'Box','on');
            
            pbaspect(hAxsHist, AxRatio)

            exportgraphics(hFigHist, [FldNameSub{i2},sl,hFlnmFg1,'.png'], 'Resolution',300);
    
            if ShowPlt
                set(hFigHist, 'visible','on');
                pause
            end
        
            close(hFigHist)
        end
    end
end

%% Figure 2
ProgressBar.Message = 'Plot fig 2...';

if DffMtrc    
    FldName = ['Difference Sens Plots',sl,CrvType];
    if ~exist(FldName, 'dir')
        mkdir(FldName)
    end
    
    for i1 = 1:numel(GenCapt)
        for i2 = 1:numel(FigCont)
            hFlnmFg2 = ['Differences between best models based on ',FigCont{i2},' (',GenCapt{i1},')'];
            hFigDiff = figure(i2+(i1-1)*numel(FigCont));
            hAxsDiff = axes(hFigDiff, 'FontName',SelFont, 'FontSize',SelFnSz);
            
            set(hFigDiff, 'Name',hFlnmFg2, 'Position',[400, 400, 1400, 480], 'visible','off')
            hold(hAxsDiff, 'on')
            
            AvVal = mean(MLSens{GenCapt{i1},CrvType}{:}{FigCont{i2},:});
    
            hLin1 = plot(1:MdlsNmbr, MLSens{GenCapt{i1},CrvType}{:}{FigCont{i2},:}, 'Color',ClrCont{i2}, 'LineWidth',LnWidth, 'Parent',hAxsDiff);
            % hLin2 = plot(1:MdlsNmbr, repmat(AvVal, 1, MdlsNmbr),                       'Color','#b6316c'  , 'LineWidth',1.5, 'Parent',hAxsDiff);
    
            hLin2 = yline(AvVal, '--', num2str(AvVal), 'LabelVerticalAlignment','middle', 'LabelHorizontalAlignment','center', ...
                                                       'FontName',SelFont, 'FontSize',1.5*SelFnSz, 'FontWeight', 'bold', ...
                                                       'Color','#123123', 'LineWidth',1.5, 'Parent',hAxsDiff);
    
            pbaspect(hAxsDiff, AxRatio)
            
            xlabel('ANN Number',           'FontName',SelFont, 'FontSize',SelFnSz, 'Parent',hAxsDiff)
            ylabel('Difference in epochs', 'FontName',SelFont, 'FontSize',SelFnSz, 'Parent',hAxsDiff)
    
            xlim([0, MdlsNmbr])
            ylim([-100, 100])
            
            title(hFlnmFg2, 'FontName',SelFont, 'FontSize',1.5*SelFnSz, 'Parent',hAxsDiff)
            
            TmpCapt = [GenCapt(i1), {'Average'}];
    
            hLeg = legend([hLin1, hLin2], ...
                           TmpCapt, ...
                          'NumColumns',1, ...
                          'FontName',SelFont, ...
                          'FontSize',0.7*SelFnSz, ...
                          'Location',LgndPos, ...
                          'Box','on');

            exportgraphics(hFigDiff, [FldName,sl,hFlnmFg2,'.png'], 'Resolution',400);
    
            if ShowPlt
                set(hFigDiff, 'visible','on');
                pause
            end
    
            close(hFigDiff)
        end
    end
end

%% Figure 3
ProgressBar.Message = 'Plot fig 3...';

if UnqMtrc
    IndComb = cellfun(@(x) combvec(1:numel(DsetLbl), 1:numel(x)), FigCont, 'UniformOutput',false);
    GenLbls = cellfun(@(x,y) strcat(DsetLbl(x(1,:)), {' '}, y(x(2,:))), IndComb, FigCont, 'UniformOutput',false);
    TblIdsR = cellfun(@(x) TbIdUsd(x(1,:)), IndComb, 'UniformOutput',false);
    TblIdsC = cellfun(@(x,y) y(x(2,:)), IndComb, FigCont, 'UniformOutput',false);
    ClrsIds = cellfun(@(x,y) y(x(2,:)), IndComb, Colors , 'UniformOutput',false);
    LnOpts  = {'-', '--', '-.'}; % Linetype for Train, Validation, and Test
    LnType  = cellfun(@(x) LnOpts(x(1,:)) , IndComb, 'UniformOutput',false);

    FldName = 'History Plots';
    if ~exist(FldName, 'dir')
        mkdir(FldName)
    end

    for i1 = Mdl
        hFigCont = strjoin(cellfun(@(x) strjoin(x, '-'), FigCont, 'UniformOutput',false), '-');
        hFlnmFg3 = [hFigCont,' history for mdl n. ',num2str(i1)];
        hFigHist = figure(i1);
        hAxsHist = subplot(1, 1, 1, 'FontName',SelFont, 'FontSize',SelFnSz, 'Parent',hFigHist);
        
        set(hFigHist, 'Name',hFlnmFg3, 'visible','off')
        hold(hAxsHist, 'on')

        SubTxt = ['ANN structure: [',strjoin({num2str(MdlStrct{i1})}),']'];
        
        title(hFlnmFg3 , 'FontName',SelFont, 'FontSize',1.5*SelFnSz)
        subtitle(SubTxt, 'FontName',SelFont, 'FontSize',SelFnSz    )

        xlabel('Iteration', 'FontName',SelFont, 'FontSize',SelFnSz)
        xlim([0, HistNmbr])

        yyaxis(hAxsHist, 'left')
        ylabel(strjoin(FigCont{1}, ' | '), 'FontName',SelFont, 'FontSize',SelFnSz)
        set(hAxsHist, ...
            'FontName',SelFont, ...
            'FontSize',.8*SelFnSz, ...
            'YGrid','on', ...
            'XGrid','on', ...
            'YLim',yLmCont{1}, ...
            'YColor','#000000')
        
        hLnLft = cell(1, numel(GenLbls{1}));
        for i2 = 1:numel(GenLbls{1})
            hLnLft{i2} = plot(1:HistNmbr, MLHist{TblIdsR{1}(i2), ...
                                                   CrvType}{:}{'Hist',TblIdsC{1}{i2}}{:}{:,i1}, ...
                                                'Color',ClrsIds{1}{i2}, 'LineStyle',LnType{1}{i2}, ...
                                                'Marker','none', 'LineWidth',LnWidth, 'Parent',hAxsHist);
        end

        yyaxis(hAxsHist, 'right')
        ylabel(strjoin(FigCont{2}, ' | '), 'FontName',SelFont, 'FontSize',SelFnSz)
        set(hAxsHist, ...
            'FontName',SelFont, ...
            'FontSize',.8*SelFnSz, ...
            'YGrid','on', ...
            'XGrid','on', ...
            'YLim',yLmCont{2}, ...
            'YColor','#000000')

        i3 = 1;
        hLnRgt = cell(1, numel(GenLbls{2}));
        for i2 = 1:numel(GenLbls{2})
            hLnRgt{i2} = plot(1:HistNmbr, MLHist{TblIdsR{2}(i2), ...
                                                   CrvType}{:}{'Hist',TblIdsC{2}{i2}}{:}{:,i1}, ...
                                               'Color',ClrsIds{2}{i2}, 'LineStyle',LnType{2}{i2}, ...
                                               'Marker','none', 'LineWidth',LnWidth, 'Parent',hAxsHist);
        end
        
        LgndPosTmp = 'eastoutside';

        hLeg = legend([hLnLft{:}, hLnRgt{:}], ...
                      [GenLbls{1}, GenLbls{2}], ...
                      'NumColumns',1, ...
                      'FontName',SelFont, ...
                      'FontSize',0.7*SelFnSz, ...
                      'Location',LgndPosTmp, ...
                      'Box','on');
        
        pbaspect(hAxsHist, AxRatio)

        exportgraphics(hFigHist, [FldName,sl,hFlnmFg3,'.png'], 'Resolution',300);

        if ShowPlt
            set(hFigHist, 'visible','on');
            pause
        end

        close(hFigHist)
    end
end