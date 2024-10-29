if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Options
FldCont = {dir(fold_res_ml).name};
IdSbFld = [dir(fold_res_ml).isdir];
PssFlds = FldCont([false, false, IdSbFld(3:end)]); % To remove not folders and first 2 hidden folders!
Flds2Rd = checkbox2(PssFlds);

PltInps = str2double(inputdlg2({'Days to plot:', 'Margin Y', 'Margin X'}, 'DefInp',{'30', '2', '1'}));
Dys2Plt = PltInps(1);
MrgPtsY = PltInps(2);
MrgPtsX = PltInps(3);

if Dys2Plt < 2
    error('Days to plot must be at least 2!')
end

PltOpts = checkbox2({'Show plots', 'Show all events', 'Comparison plot'}, 'DefInp',[0, 1, 0], 'OutType','LogInd');
ShowPlt = PltOpts(1);
ShowEvs = PltOpts(2);
CompPlt = PltOpts(3);

if (isscalar(Flds2Rd) && CompPlt) || numel(Flds2Rd)>6
    error('The comparison plot requires more than 1 model, but less than 6!')
end

%% Loading files
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

%% Creation of folder where saving plots
fold_fig_hist = [fold_fig,sl,'PPR vs NPR'];
if not(exist(fold_fig_hist, 'dir'))
    mkdir(fold_fig_hist)
end

%% Loop for plots
ProgressBar.Message = 'Plotting...';

Dys2Sh = unique([1, 5:5:Dys2Plt, Dys2Plt-1, Dys2Plt]);
DysLbl = string(-(Dys2Plt - Dys2Sh));

[PPRAvg, NPRAvg] = deal(cell(numel(Thresholds), numel(Flds2Rd)));
for i1 = 1:numel(Flds2Rd)
    fold_res_ml_curr = [fold_res_ml,sl,Flds2Rd{i1}];
    load([fold_res_ml_curr,sl,'TimeScoreIndex.mat'], 'TimeScore','Thresholds')

    [~, MdlNme, ~] = fileparts(fold_res_ml_curr);
    MdlNmRp = strrep(MdlNme, '_', '-');

    % Figure
    CurrNme = [MdlNme,'_PPR_vs_NPR'];
    CurrFig = figure('Position',[200, 100, 550, 700], 'Name',CurrNme, 'Visible','off');

    SelANN = listdlg2('Model to use:', TimeScore.Properties.VariableNames);
    PPRThr = TimeScore{'PPR', SelANN}{:};
    NPRThr = TimeScore{'NPR', SelANN}{:};

    CurrAxs = cell(1, numel(Thresholds));
    for i2 = 1:numel(Thresholds)
        CurrAxs{i2} = subplot(numel(Thresholds), 1, i2, 'Parent',CurrFig);
        hold(CurrAxs{i2}, 'on')

        subtitle(['Threshold: ',num2str(Thresholds(i2)),'%'], 'FontName',SelFnt, 'FontSize',SelFSz)

        % Landslide line
        PPRTrgt = plot(1:Dys2Plt, [zeros(1, Dys2Plt-1), 100], 'Marker','none', 'LineWidth',3, 'Color','#5e1914');

        [PPREvs, PPRVls] = deal(cell(1, size(PPRThr,2)));
        for i3 = 1:size(PPRThr,2)
            if numel(PPRThr{i2,i3}{:}) < Dys2Plt
                error(['You do not have enough days for the series n.',num2str(i3),' of ',MdlNme])
            end
            PPRVls{i3} = PPRThr{i2,i3}{:}(end-Dys2Plt+1:end);
            if ShowEvs
                PPREvs{i3} = plot(1:Dys2Plt, PPRVls{i3}, '--' , 'Color','#D95319', 'LineWidth',.6);
            end
        end

        PPRAvg{i2, i1} = mean(cat(1, PPRVls{:}), 1);
        PPRMnL = plot(1:Dys2Plt, PPRAvg{i2, i1}, 'Marker','none', 'LineWidth',1.5, 'Color','#A2142F');

        % Not-landslide line
        NPRTrgt = plot(1:Dys2Plt, ones(1, Dys2Plt).*100, 'Marker','none', 'LineWidth',3, 'Color','#276221');

        [NPREvs, NPRVls] = deal(cell(1, size(NPRThr,2)));
        for i3 = 1:size(NPRThr,2)
            NPRVls{i3} = NPRThr{i2,i3}{:}(end-Dys2Plt+1:end);
            if ShowEvs
                NPREvs{i3} = plot(1:Dys2Plt, NPRVls{i3}, '--' , 'Color','#77AC30', 'LineWidth',.6);
            end
        end

        NPRAvg{i2, i1} = mean(cat(1, NPRVls{:}), 1);
        NPRMnL = plot(1:Dys2Plt, NPRAvg{i2, i1}, 'Marker','none', 'LineWidth',1.5, 'Color','#6f9f00');

        % Axis
        xlabel('Time [day]', 'FontName',SelFnt, 'FontSize',.7*SelFSz)

        yyaxis(CurrAxs{i2}, 'left');
        ylabel('{\it NPR} (%)', 'FontName',SelFnt, 'FontSize',.7*SelFSz, 'Color','#276221')
        set(CurrAxs{i2}, 'FontName',SelFnt, ...
                         'FontSize',.8*SelFSz, ...
                         'XTick',Dys2Sh, ...
                         'YTick',0:20:100, ... 
                         'XTicklabels',DysLbl, ... % 'XTickLabelRotation',90, ...
                         'YGrid','on', ...
                         'XGrid','on', ...
                         'XLim',[1-MrgPtsX, Dys2Plt+MrgPtsX], ...
                         'YLim',[-MrgPtsY , 100+MrgPtsY], ...
                         'YColor','#276221')

        yyaxis(CurrAxs{i2}, 'right');
        ylabel('{\it PPR} (%)', 'FontName',SelFnt, 'FontSize',.7*SelFSz, 'Color','#5e1914')
        set(CurrAxs{i2}, 'FontName',SelFnt, ...
                         'FontSize',.8*SelFSz, ...
                         'XTick',Dys2Sh, ...
                         'YTick',0:20:100, ... 
                         'XTicklabels',DysLbl, ... % 'XTickLabelRotation',90, ...
                         'YGrid','on', ...
                         'XGrid','on', ...
                         'XLim',[1-MrgPtsX, Dys2Plt+MrgPtsX], ...
                         'YLim',[-MrgPtsY , 100+MrgPtsY], ...
                         'YColor','#5e1914')

    end

    title(CurrAxs{1}, ['PPR vs NPR | ',MdlNmRp,' | ',SelANN{:}], 'FontName',SelFnt, 'FontSize',SelFSz)

    % Export
    ProgressBar.Message = 'Export...';
    exportgraphics(CurrFig, [fold_fig_hist,sl,CurrNme,'.png'], 'Resolution',400);
    
    if ShowPlt
        set(CurrFig, 'visible','on');
    else
        close(CurrFig)
    end
end

%% Comparison plot
if CompPlt
    IndThr = listdlg2({'Threshold to use for comparison:'}, string(Thresholds), 'OutType','NumInd');

    LnStls = {'--', '-', '-.', '--', '-', '-.'};
    LnMrks = {'o' , 'o', 'o' , '*' , '*', '*' };

    CurrNme = [strjoin(Flds2Rd,' - '),'_PPR_vs_NPR'];
    CurrFgC = figure('Position',[200, 100, 550, 250], 'Name',CurrNme, 'Visible','off');
    
    CurrAxs = subplot(1, 1, 1, 'Parent',CurrFgC);
    hold(CurrAxs, 'on')
    
    subtitle(['Threshold: ',num2str(Thresholds(IndThr)),'%'], 'FontName',SelFnt, 'FontSize',SelFSz)
    title(CurrAxs, 'PPR - NPR comparison', 'FontName',SelFnt, 'FontSize',SelFSz)

    PPRTrgt = plot(1:Dys2Plt, [zeros(1, Dys2Plt-1), 100], 'Marker','none', 'LineWidth',3, ...
                                                          'Color','#5e1914', 'Parent',CurrAxs); % Landslide line
    NPRTrgt = plot(1:Dys2Plt, ones(1, Dys2Plt).*100     , 'Marker','none', 'LineWidth',3, ...
                                                          'Color','#276221', 'Parent',CurrAxs); % Not-landslide line

    [PPRMnC, NPRMnC] = deal(cell(1, numel(Flds2Rd)));
    for i1 = 1:numel(Flds2Rd)
        PPRMnC{i1} = plot(1:Dys2Plt, PPRAvg{IndThr, i1}, 'Marker',LnMrks{i1}, 'MarkerSize',3, 'LineStyle',LnStls{i1}, ...
                                                         'LineWidth',1.5, 'Color','#A2142F', 'Parent',CurrAxs); % Landslide line
        NPRMnC{i1} = plot(1:Dys2Plt, NPRAvg{IndThr, i1}, 'Marker',LnMrks{i1}, 'MarkerSize',3, 'LineStyle',LnStls{i1}, ...
                                                         'LineWidth',1.5, 'Color','#6f9f00', 'Parent',CurrAxs); % Not-landslide line
    end
    
    LgndTtl = strrep([strcat(Flds2Rd, ' PPR'), strcat(Flds2Rd, ' NPR')], '_', '-');
    legend([PPRMnC{:}, NPRMnC{:}], LgndTtl, 'Location',LegPos, 'FontName',SelFnt, 'FontSize',SelFSz*.7)
    
    % Axis
    xlabel('Time [day]', 'FontName',SelFnt, 'FontSize',.7*SelFSz)
    
    yyaxis(CurrAxs, 'left');
    ylabel('{\it NPR} (%)', 'FontName',SelFnt, 'FontSize',.7*SelFSz, 'Color','#276221')
    set(CurrAxs, 'FontName',SelFnt, ...
                 'FontSize',.8*SelFSz, ...
                 'XTick',Dys2Sh, ...
                 'YTick',0:20:100, ... 
                 'XTicklabels',DysLbl, ... % 'XTickLabelRotation',90, ...
                 'YGrid','on', ...
                 'XGrid','on', ...
                 'XLim',[1-MrgPtsX, Dys2Plt+MrgPtsX], ...
                 'YLim',[-MrgPtsY , 100+MrgPtsY], ...
                 'YColor','#276221')
    
    yyaxis(CurrAxs, 'right');
    ylabel('{\it PPR} (%)', 'FontName',SelFnt, 'FontSize',.7*SelFSz, 'Color','#5e1914')
    set(CurrAxs, 'FontName',SelFnt, ...
                 'FontSize',.8*SelFSz, ...
                 'XTick',Dys2Sh, ...
                 'YTick',0:20:100, ... 
                 'XTicklabels',DysLbl, ... % 'XTickLabelRotation',90, ...
                 'YGrid','on', ...
                 'XGrid','on', ...
                 'XLim',[1-MrgPtsX, Dys2Plt+MrgPtsX], ...
                 'YLim',[-MrgPtsY , 100+MrgPtsY], ...
                 'YColor','#5e1914')
    
    % Export
    ProgressBar.Message = 'Export comparison...';
    exportgraphics(CurrFgC, [fold_fig_hist,sl,CurrNme,'.png'], 'Resolution',400);
    
    if ShowPlt
        set(CurrFgC, 'visible','on');
    else
        close(CurrFgC)
    end
end