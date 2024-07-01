if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Folder to load
FldCntn = {dir(fold_res_ml).name};
IndSbFl = [dir(fold_res_ml).isdir];
PssFlds = FldCntn([false, false, IndSbFl(3:end)]); % To remove not folders and first 2 hidden folders!
Flds2Rd = checkbox2(PssFlds);

%% Loading
sl = filesep;
if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SelFnt = Font;
    SelFSz = FontSize;
    if exist('LegendPosition', 'var')
        LegPos = LegendPosition;
    end
else
    SelFnt = 'Calibri';
    SelFSz = 10;
    LegPos = 'best';
end

%% Options
PltOpts = checkbox2({'Manual limit X', 'Show plot'}, 'DefInp',[0, 0], 'OutType','LogInd');
ManualX = PltOpts(1);
ShowPlt = PltOpts(2);

if ManualX
    LimsAns = inputdlg2({'Max model:', 'Min model:'}, 'DefInp',{'50', '1'});
    MaxCols = str2double(LimsAns{1});
    MinCols = str2double(LimsAns{2});
else
    LimRngs = str2double(inputdlg2({'Range around best model for Test QCI:'}, 'DefInp',{'50'}));
end

%% Creation of folder where saving plots
fold_fig_perf = [fold_fig,sl,'ML Perf'];
if not(exist(fold_fig_perf, 'dir'))
    mkdir(fold_fig_perf)
end

%% Plot loops
for i1 = 1:numel(Flds2Rd)
    fold_res_ml_curr = [fold_res_ml,sl,Flds2Rd{i1}];

    MdlType = find([exist([fold_res_ml_curr,sl,'ANNsMdlA.mat'], 'file'), ...
                    exist([fold_res_ml_curr,sl,'ANNsMdlB.mat'], 'file')]);
    if isempty(MdlType)
        error('No trained model found in your folder!')
    elseif numel(MdlType) > 1
        MdlType = listdlg2({'Model to use'}, {'Model A', 'Model B'}, 'OutType','NumInd'); 
    end
    switch MdlType
        case 1
            Fl2LdMdl = 'ANNsMdlA.mat';
    
        case 2
            Fl2LdMdl = 'ANNsMdlB.mat';

        otherwise
            error('No trained ModelA or B found!')
    end

    load([fold_res_ml_curr,sl,Fl2LdMdl], 'ANNsPerf')

    [~, MdlName, ~] = fileparts(fold_res_ml_curr);
    MdlNameRep = strrep(MdlName, '_', '-');

    %% Data extraction
    ProgressBar.Message = 'Data extraction...';

    TrnROC = [ANNsPerf{'ROC', 'Train'}{:}{'AUC', :}{:}];
    TstROC = [ANNsPerf{'ROC', 'Test' }{:}{'AUC', :}{:}];
    TrnPRC = [ANNsPerf{'PRC', 'Train'}{:}{'AUC', :}{:}];
    TstPRC = [ANNsPerf{'PRC', 'Test' }{:}{'AUC', :}{:}];
    TrnF1S = [ANNsPerf{'F1S', 'Train'}{:}{'F1S', :}{:}];
    TstF1S = [ANNsPerf{'F1S', 'Test' }{:}{'F1S', :}{:}];
    TrnQCI = [ANNsPerf{'QCI', 'Train'}{:}{'QCI', :}{:}];
    TstQCI = [ANNsPerf{'QCI', 'Test' }{:}{'QCI', :}{:}];

    TrnBstROC = ANNsPerf{'ROC', 'BstMdlTrn'}{:}; % Wrong because if MaxCols is not enough large you do not have this value!!!
    TstBstROC = ANNsPerf{'ROC', 'BstMdlTst'}{:};
    TrnBstPRC = ANNsPerf{'PRC', 'BstMdlTrn'}{:};
    TstBstPRC = ANNsPerf{'PRC', 'BstMdlTst'}{:};
    TrnBstF1S = ANNsPerf{'F1S', 'BstMdlTrn'}{:};
    TstBstF1S = ANNsPerf{'F1S', 'BstMdlTst'}{:};
    TrnBstQCI = ANNsPerf{'QCI', 'BstMdlTrn'}{:};
    TstBstQCI = ANNsPerf{'QCI', 'BstMdlTst'}{:};

    MaxMdl = max([TrnBstROC, TstBstROC, TrnBstPRC, TstBstPRC, ...
                  TrnBstF1S, TstBstF1S, TrnBstQCI, TstBstQCI]);
    MinMdl = min([TrnBstROC, TstBstROC, TrnBstPRC, TstBstPRC, ...
                  TrnBstF1S, TstBstF1S, TrnBstQCI, TstBstQCI]);

    if not(ManualX)
        MaxPoss = numel(TrnROC);
        MaxCols = min(TstBstQCI + LimRngs, MaxPoss);
        MinCols = max(TstBstQCI - LimRngs, 1);
    end

    if MaxCols > numel(TrnROC)
        error('You have a maximum column greater than the number of models!')
    end

    if MaxMdl > MaxCols || MinMdl < MinCols
        warning('Some best models are out of plot ranges and will not be visible!')
    end
    
    %% Plot
    CurrNme = ['ANN Perf ',MdlName];
    CurrFig = figure('Position',[400, 20, 700, 800], 'Visible','off', 'Name',CurrNme);
    CurrAxs = cell(1, 3);

    CurrAxs{1} = subplot(4, 1, 1, 'Parent',CurrFig);
    CurrAxs{2} = subplot(4, 1, 2, 'Parent',CurrFig);
    CurrAxs{3} = subplot(4, 1, 3, 'Parent',CurrFig);
    CurrAxs{4} = subplot(4, 1, 4, 'Parent',CurrFig);
    
    hold(CurrAxs{1}, 'on')
    hold(CurrAxs{2}, 'on')
    hold(CurrAxs{3}, 'on')
    hold(CurrAxs{4}, 'on')
    
    xLabTxt = 'Number of model';
    xlabel(CurrAxs{1}, xLabTxt, 'FontName',SelFnt, 'FontSize',SelFSz)
    xlabel(CurrAxs{2}, xLabTxt, 'FontName',SelFnt, 'FontSize',SelFSz)
    xlabel(CurrAxs{3}, xLabTxt, 'FontName',SelFnt, 'FontSize',SelFSz)
    xlabel(CurrAxs{4}, xLabTxt, 'FontName',SelFnt, 'FontSize',SelFSz)
    
    ylabel(CurrAxs{1}, 'AUROC [%]'   , 'FontName',SelFnt, 'FontSize',SelFSz)
    ylabel(CurrAxs{2}, 'AUPRC [%]'   , 'FontName',SelFnt, 'FontSize',SelFSz)
    ylabel(CurrAxs{3}, 'F1-Score [-]', 'FontName',SelFnt, 'FontSize',SelFSz)
    ylabel(CurrAxs{4}, 'QCI [%]'     , 'FontName',SelFnt, 'FontSize',SelFSz)
    
    title(CurrAxs{1}, ['Models of ',MdlNameRep], 'FontName',SelFnt, 'FontSize',SelFSz)
    % title(CurrAxs{1}, ['Models AUC ('    ,MdlNameRep,')'], 'FontName',SelFont, 'FontSize',SelFntSz)
    % title(CurrAxs{2}, ['Models AUPRC ('  ,MdlNameRep,')'], 'FontName',SelFont, 'FontSize',SelFntSz)
    % title(CurrAxs{3}, ['Models F-Score (',MdlNameRep,')'], 'FontName',SelFont, 'FontSize',SelFntSz)
    
    % AUC
    LnTrnROC = plot(CurrAxs{1}, MinCols:MaxCols, TrnROC(MinCols:MaxCols)*100, '--', 'LineWidth',1.5, 'Color','#0072BD');
    LnTstROC = plot(CurrAxs{1}, MinCols:MaxCols, TstROC(MinCols:MaxCols)*100, '-' , 'LineWidth',1.5, 'Color','#0072BD');
    
    scatter(CurrAxs{1}, TrnBstROC, TrnROC(TrnBstROC)*100, 20, 'LineWidth',1.5, 'MarkerEdgeColor','#242732', 'Marker','diamond')
    scatter(CurrAxs{1}, TstBstROC, TstROC(TstBstROC)*100, 20, 'LineWidth',1.5, 'MarkerEdgeColor','#242732', 'Marker','diamond')
    
    text(CurrAxs{1}, TrnBstROC-2, TrnROC(TrnBstROC)*100, num2str(TrnBstROC), 'FontName',SelFnt, 'FontSize',SelFSz, 'FontWeight','bold', 'Color','#242732')
    text(CurrAxs{1}, TstBstROC-2, TstROC(TstBstROC)*100, num2str(TstBstROC), 'FontName',SelFnt, 'FontSize',SelFSz, 'FontWeight','bold', 'Color','#242732')
    
    xlim(CurrAxs{1}, [MinCols, MaxCols+0.5])
    ylim(CurrAxs{1}, [50, 100])
    
    legend([LnTrnROC, LnTstROC], {'Train', 'Test'}, 'Location',LegPos, 'FontName',SelFnt, 'FontSize',SelFSz*.7)
    
    % AUPRC
    LnTrnPRC = plot(CurrAxs{2}, MinCols:MaxCols, TrnPRC(MinCols:MaxCols)*100, '--', 'LineWidth',1.5, 'Color','#D95319');
    LnTstPRC = plot(CurrAxs{2}, MinCols:MaxCols, TstPRC(MinCols:MaxCols)*100, '-' , 'LineWidth',1.5, 'Color','#D95319');
    
    scatter(CurrAxs{2}, TrnBstPRC, TrnPRC(TrnBstPRC)*100, 20, 'LineWidth',1.5, 'MarkerEdgeColor','#242732', 'Marker','diamond')
    scatter(CurrAxs{2}, TstBstPRC, TstPRC(TstBstPRC)*100, 20, 'LineWidth',1.5, 'MarkerEdgeColor','#242732', 'Marker','diamond')
    
    text(CurrAxs{2}, TrnBstPRC-2, TrnPRC(TrnBstPRC)*100, num2str(TrnBstPRC), 'FontName',SelFnt, 'FontSize',SelFSz, 'FontWeight','bold', 'Color','#242732')
    text(CurrAxs{2}, TstBstPRC-2, TstPRC(TstBstPRC)*100, num2str(TstBstPRC), 'FontName',SelFnt, 'FontSize',SelFSz, 'FontWeight','bold', 'Color','#242732')
    
    xlim(CurrAxs{2}, [MinCols, MaxCols+0.5])
    ylim(CurrAxs{2}, [10, 100])
    
    legend([LnTrnPRC, LnTstPRC], {'Train', 'Test'}, 'Location',LegPos, 'FontName',SelFnt, 'FontSize',SelFSz*.7)
    
    % F1-Score
    LnTrnF1S = plot(CurrAxs{3}, MinCols:MaxCols, TrnF1S(MinCols:MaxCols), '--', 'LineWidth',1.5, 'Color','#77AC30');
    LnTstF1S = plot(CurrAxs{3}, MinCols:MaxCols, TstF1S(MinCols:MaxCols), '-' , 'LineWidth',1.5, 'Color','#77AC30');
    
    scatter(CurrAxs{3}, TrnBstF1S, TrnF1S(TrnBstF1S), 20, 'LineWidth',1.5, 'MarkerEdgeColor','#242732', 'Marker','diamond')
    scatter(CurrAxs{3}, TstBstF1S, TstF1S(TstBstF1S), 20, 'LineWidth',1.5, 'MarkerEdgeColor','#242732', 'Marker','diamond')
    
    text(CurrAxs{3}, TrnBstF1S-2, TrnF1S(TrnBstF1S), num2str(TrnBstF1S), 'FontName',SelFnt, 'FontSize',SelFSz, 'FontWeight','bold', 'Color','#242732')
    text(CurrAxs{3}, TstBstF1S-2, TstF1S(TstBstF1S), num2str(TstBstF1S), 'FontName',SelFnt, 'FontSize',SelFSz, 'FontWeight','bold', 'Color','#242732')
    
    xlim(CurrAxs{3}, [MinCols, MaxCols+0.5])
    ylim(CurrAxs{3}, [.5, 1])
    
    legend([LnTrnF1S, LnTstF1S], {'Train', 'Test'}, 'Location',LegPos, 'FontName',SelFnt, 'FontSize',SelFSz*.7)
    
    % QCI
    LnTrnQCI = plot(CurrAxs{4}, MinCols:MaxCols, TrnQCI(MinCols:MaxCols), '--', 'LineWidth',1.5, 'Color','#A2142F');
    LnTstQCI = plot(CurrAxs{4}, MinCols:MaxCols, TstQCI(MinCols:MaxCols), '-' , 'LineWidth',1.5, 'Color','#A2142F');
    
    scatter(CurrAxs{4}, TrnBstQCI, TrnQCI(TrnBstQCI), 20, 'LineWidth',1.5, 'MarkerEdgeColor','#242732', 'Marker','diamond')
    scatter(CurrAxs{4}, TstBstQCI, TstQCI(TstBstQCI), 20, 'LineWidth',1.5, 'MarkerEdgeColor','#242732', 'Marker','diamond')
    
    TxtTstQCI = num2str(round(TstQCI(TstBstQCI), 3));
    text(CurrAxs{4}, TrnBstQCI-2, TrnQCI(TrnBstQCI), num2str(TrnBstQCI), 'FontName',SelFnt, 'FontSize',SelFSz, 'FontWeight','bold', 'Color','#242732')
    text(CurrAxs{4}, TstBstQCI-2, TstQCI(TstBstQCI), num2str(TstBstQCI), 'FontName',SelFnt, 'FontSize',SelFSz, 'FontWeight','bold', 'Color','#242732')
    text(CurrAxs{4}, TstBstQCI+1, TstQCI(TstBstQCI), num2str(TxtTstQCI), 'FontName',SelFnt, 'FontSize',SelFSz, 'FontWeight','bold', 'Color','#242732')
    
    xlim(CurrAxs{4}, [MinCols, MaxCols+0.5])
    ylim(CurrAxs{4}, [.5, 1])
    
    legend([LnTrnQCI, LnTstQCI], {'Train', 'Test'}, 'Location',LegPos, 'FontName',SelFnt, 'FontSize',SelFSz*.7)
    
    %% Export
    ProgressBar.Message = 'Export...';
    
    exportgraphics(CurrFig, [fold_fig_perf,sl,CurrNme,'.png'], 'Resolution',400);
    
    if ShowPlt
        set(CurrFig, 'visible','on');
    else
        close(CurrFig)
    end
end