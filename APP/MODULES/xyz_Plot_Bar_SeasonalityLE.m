if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading
sl = filesep;
load([fold_var,sl,'GenInfoRainfallEvents.mat'], 'GeneralRE')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize')
    SelFont = Font;
    SelFnSz = FontSize;
else
    SelFont = 'Calibri';
    SelFnSz = 8;
end

%% Options
ProgressBar.Message = 'Options...';

ShowPlt = uiconfirm(Fig, 'Do you want to show plots?', ...
                         'Show plots', 'Options',{'Yes', 'No'}, 'DefaultOption',2);
if strcmp(ShowPlt,'Yes'); ShowPlt = true; else; ShowPlt = false; end

Opt2Plt = {'Number of RE', 'Average rain amount', 'Number of LE', ...
           'Average temperature', 'Average NDVI'};
Var2Plt = checkbox2(Opt2Plt, 'Title',{'Select what to plot:'});

PssMnth = 1:12;
MnthSht = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'};

MnthCtg = categorical(MnthSht);
MnthCtg = reordercats(MnthCtg, MnthSht); % DON'T DELETE THIS ROW!!!

BarWdth = .6;

%% Core
EventYear  = year(GeneralRE.Start);
LandsCount = GeneralRE.LandsNum;
TrgRainAmt = GeneralRE.TrigRain;
TrgTempAmt = GeneralRE.AvgTrgTmp;
TrgNDVIAmt = GeneralRE.AvgNDVI;
NumOfYears = numel(unique(EventYear));
EventMonth = month(GeneralRE.Start);
EventXMnth = arrayfun(@(x) sum(EventMonth == x), PssMnth);
LandsXMnth = arrayfun(@(x) sum(LandsCount(EventMonth == x)), PssMnth);
RainAmXMnt = arrayfun(@(x) mean(TrgRainAmt(EventMonth == x)), PssMnth);
TempAmXMnt = arrayfun(@(x) mean(TrgTempAmt(EventMonth == x)), PssMnth);
NDVIAmXMnt = arrayfun(@(x) mean(TrgNDVIAmt(EventMonth == x)), PssMnth);

%% Plot
ProgressBar.Message = 'Plot...';

CurrNme = 'Seasonality of RE';
NumCols = 2 - rem(numel(Var2Plt),2); % Max 2 columns
NumRows = numel(Var2Plt) / NumCols;
xSizePx = 560;
ySizePx = 220;
CurrFig = figure('Position',[20, 20, xSizePx*NumCols, ySizePx*NumRows], ...
                 'Name',CurrNme, 'Visible','off');
CurrLay = tiledlayout(NumRows, NumCols, 'Parent',CurrFig);
CurrAxs = deal(cell(1, numel(Var2Plt)));
xLabTxt = 'Month';

if any(strcmpi(Var2Plt, 'Number of RE'))
    CurrAxs{1} = nexttile([1, 1]);
    hold(CurrAxs{1}, 'on')
    set(CurrAxs{1}, 'FontName',SelFont, 'FontSize',SelFnSz)
    xlabel(CurrAxs{1}, xLabTxt, 'FontName',SelFont, 'FontSize',SelFnSz)
    ylabel(CurrAxs{1}, 'Number of RE [-]', 'FontName',SelFont, 'FontSize',SelFnSz)
    title(CurrAxs{1}, ['RE (from ',num2str(min(EventYear)),' to ',num2str(max(EventYear)),')'], 'FontName',SelFont, 'FontSize',SelFnSz)
    RENumPlt = bar(CurrAxs{1}, MnthCtg, EventXMnth, 'FaceColor','#717171', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    pbaspect([3,1,1])
end

if any(strcmpi(Var2Plt, 'Average rain amount'))
    CurrAxs{2} = nexttile([1, 1]);
    hold(CurrAxs{2}, 'on')
    set(CurrAxs{2}, 'FontName',SelFont, 'FontSize',SelFnSz)
    xlabel(CurrAxs{2}, xLabTxt, 'FontName',SelFont, 'FontSize',SelFnSz)
    ylabel(CurrAxs{2}, 'Average rain amount [mm]', 'FontName',SelFont, 'FontSize',SelFnSz)
    title(CurrAxs{2}, ['RE average amount (',num2str(min(EventYear)),' - ',num2str(max(EventYear)),')'], 'FontName',SelFont, 'FontSize',SelFnSz)
    RERnAmPlt = bar(CurrAxs{2}, MnthCtg, RainAmXMnt, 'FaceColor','#185e9f', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    pbaspect([3,1,1])
end

if any(strcmpi(Var2Plt, 'Number of LE'))
    CurrAxs{3} = nexttile([1, 1]);
    hold(CurrAxs{3}, 'on')
    set(CurrAxs{3}, 'FontName',SelFont, 'FontSize',SelFnSz)
    xlabel(CurrAxs{3}, xLabTxt, 'FontName',SelFont, 'FontSize',SelFnSz)
    ylabel(CurrAxs{3}, 'Number of LE [-]', 'FontName',SelFont, 'FontSize',SelFnSz)
    title(CurrAxs{3}, ['LE (from ',num2str(min(EventYear)),' to ',num2str(max(EventYear)),')'], 'FontName',SelFont, 'FontSize',SelFnSz)
    LENumPlt = bar(CurrAxs{3}, MnthCtg, LandsXMnth, 'FaceColor','#b11771', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    pbaspect([3,1,1])
end

if any(strcmpi(Var2Plt, 'Average temperature'))
    CurrAxs{4} = nexttile([1, 1]);
    hold(CurrAxs{4}, 'on')
    set(CurrAxs{4}, 'FontName',SelFont, 'FontSize',SelFnSz)
    xlabel(CurrAxs{4}, xLabTxt, 'FontName',SelFont, 'FontSize',SelFnSz)
    ylabel(CurrAxs{4}, 'Average temperature [°C]', 'FontName',SelFont, 'FontSize',SelFnSz)
    title(CurrAxs{4}, ['RE average temperature (',num2str(min(EventYear)),' - ',num2str(max(EventYear)),')'], 'FontName',SelFont, 'FontSize',SelFnSz)
    RETmAmPlt = bar(CurrAxs{4}, MnthCtg, TempAmXMnt, 'FaceColor','#ffc262', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    pbaspect([3,1,1])
end

if any(strcmpi(Var2Plt, 'Average NDVI'))
    CurrAxs{5} = nexttile([1, 1]);
    hold(CurrAxs{5}, 'on')
    set(CurrAxs{5}, 'FontName',SelFont, 'FontSize',SelFnSz)
    xlabel(CurrAxs{5}, xLabTxt, 'FontName',SelFont, 'FontSize',SelFnSz)
    ylabel(CurrAxs{5}, 'Average NDVI [-]', 'FontName',SelFont, 'FontSize',SelFnSz)
    title(CurrAxs{5}, ['RE average NDVI (',num2str(min(EventYear)),' - ',num2str(max(EventYear)),')'], 'FontName',SelFont, 'FontSize',SelFnSz)
    RENVAmPlt = bar(CurrAxs{5}, MnthCtg, NDVIAmXMnt, 'FaceColor','#a0db8e', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    pbaspect([3,1,1])
end

% Showing plot and saving...
exportgraphics(CurrFig, [fold_fig,sl,CurrNme,'.png'], 'Resolution',600);

if ShowPlt
    set(CurrFig, 'visible','on')
    pause
end

close(CurrFig)