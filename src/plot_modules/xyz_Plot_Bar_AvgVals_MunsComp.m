if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;
load([fold_var,sl,'AverageValues.mat'], 'AvgValsTimeSens')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize')
    SelFont  = Font;
    SelFntSz = FontSize;
else
    SelFont  = 'Calibri';
    SelFntSz = 8;
end

%% Options
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

%% Plot Average
Prp2Plt = listdlg2({'Property to plot:'}, AvgValsTimeSens.Properties.VariableNames);
AvgVlTb = AvgValsTimeSens{'Content',Prp2Plt}{:};
ColNms  = AvgVlTb.Properties.VariableNames;
ColNmsF = ColNms(not(contains(ColNms, {'Start','End'}, 'IgnoreCase',true)));
ColSel  = checkbox2(ColNmsF, 'Title',{'Select column to plot:'});

CurrFln = ['Comparison ',Prp2Plt{:}];
CurrFig = figure('Position',[50, 30, 1000, numel(ColSel)*150], 'Visible','on');
set(CurrFig, 'Name',CurrFln, 'visible','off')

GrdSPlt = [numel(ColSel), 1];
AxRatio = [numel(AvgVlTb.StartDate)/10, 1, 1];

[CurrAxs, BarPltOb] = deal(cell(1, numel(ColSel)));
for i1 = 1:numel(ColSel)
    CurrAxs{i1} = subplot(GrdSPlt(1), GrdSPlt(2), i1, 'Parent',CurrFig);
    hold(CurrAxs{i1},'on');

    CurrVals = AvgVlTb.(ColSel{i1});

    StrtDtes = categorical(string(AvgVlTb.StartDate));
    StrtDtes = reordercats(StrtDtes, string(AvgVlTb.StartDate));

    BarPltOb = bar(CurrAxs{i1}, StrtDtes, CurrVals, 'FaceColor','flat', 'BarWidth',1, ...
                                                    'CData',[0, 0.5, 0.5], 'EdgeColor','k');

    ylim([0.95*min(AvgVlTb{:,ColSel{i1}}, [], 'all'), 1.02*max(AvgVlTb{:,ColSel{i1}}, [], 'all')])
    ylabel([Prp2Plt{:},' values'], 'FontName',SelFont, 'FontSize',SelFntSz)

    xtickangle(CurrAxs{i1}, 90)
    xlabel('Start Dates', 'FontName',SelFont, 'FontSize',SelFntSz)
    
    pbaspect(CurrAxs{i1}, AxRatio)
    box on

    xTick = get(CurrAxs{i1},'XTickLabel');
    set(CurrAxs{i1}, 'XTickLabel',xTick, 'FontName',SelFont,'FontSize',0.8*SelFntSz)

    yTick = get(CurrAxs{i1},'YTickLabel');
    set(CurrAxs{i1}, 'YTickLabel',yTick, 'FontName',SelFont,'FontSize',0.8*SelFntSz)

    title([Prp2Plt{:},' ',ColSel{i1}], 'FontName',SelFont, 'FontSize',1.5*SelFntSz)
end

%% Showing plot and saving...
if ShowPlots
    set(CurrFig, 'visible','on');
    pause
end

exportgraphics(CurrFig, [fold_fig,sl,CurrFln,'.png'], 'Resolution',600);
close(CurrFig)