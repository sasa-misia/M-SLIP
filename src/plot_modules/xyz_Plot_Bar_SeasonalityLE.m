if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading
sl = filesep;
load([fold_var,sl,'GenInfoRainfallEvents.mat'], 'GeneralRE')

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

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
EventXMnth = arrayfun(@(x) sum(EventMonth == x, 'omitnan'), PssMnth);
LandsXMnth = arrayfun(@(x) sum(LandsCount(EventMonth == x ), 'omitnan'), PssMnth);
RainAmXMnt = arrayfun(@(x) mean(TrgRainAmt(EventMonth == x), 'omitnan'), PssMnth);
TempAmXMnt = arrayfun(@(x) mean(TrgTempAmt(EventMonth == x), 'omitnan'), PssMnth);
NDVIAmXMnt = arrayfun(@(x) mean(TrgNDVIAmt(EventMonth == x), 'omitnan'), PssMnth);

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

iF = 1;

if any(strcmpi(Var2Plt, 'Number of LE'))
    CurrAxs{iF} = nexttile([1, 1]);
    hold(CurrAxs{iF}, 'on')
    set(CurrAxs{iF}, 'FontName',SlFont, 'FontSize',SlFnSz)
    xlabel(CurrAxs{iF}, xLabTxt, 'FontName',SlFont, 'FontSize',SlFnSz)
    ylabel(CurrAxs{iF}, 'Number of LE [-]', 'FontName',SlFont, 'FontSize',SlFnSz)
    title(CurrAxs{iF}, ['LE (from ',num2str(min(EventYear)),' to ',num2str(max(EventYear)),')'], 'FontName',SlFont, 'FontSize',SlFnSz)
    LENumPlt = bar(CurrAxs{iF}, MnthCtg, LandsXMnth, 'FaceColor','#b11771', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    pbaspect([4,1,1])
    iF = iF + 1;
end

if any(strcmpi(Var2Plt, 'Number of RE'))
    CurrAxs{iF} = nexttile([1, 1]);
    hold(CurrAxs{iF}, 'on')
    set(CurrAxs{iF}, 'FontName',SlFont, 'FontSize',SlFnSz)
    xlabel(CurrAxs{iF}, xLabTxt, 'FontName',SlFont, 'FontSize',SlFnSz)
    ylabel(CurrAxs{iF}, 'Number of RE [-]', 'FontName',SlFont, 'FontSize',SlFnSz)
    title(CurrAxs{iF}, ['RE (from ',num2str(min(EventYear)),' to ',num2str(max(EventYear)),')'], 'FontName',SlFont, 'FontSize',SlFnSz)
    RENumPlt = bar(CurrAxs{iF}, MnthCtg, EventXMnth, 'FaceColor','#717171', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    pbaspect([4,1,1])
    iF = iF + 1;
end

if any(strcmpi(Var2Plt, 'Average rain amount'))
    CurrAxs{iF} = nexttile([1, 1]);
    hold(CurrAxs{iF}, 'on')
    set(CurrAxs{iF}, 'FontName',SlFont, 'FontSize',SlFnSz)
    xlabel(CurrAxs{iF}, xLabTxt, 'FontName',SlFont, 'FontSize',SlFnSz)
    ylabel(CurrAxs{iF}, 'Average rain amount [mm]', 'FontName',SlFont, 'FontSize',SlFnSz)
    title(CurrAxs{iF}, ['RE avg rain (',num2str(min(EventYear)),' - ',num2str(max(EventYear)),')'], 'FontName',SlFont, 'FontSize',SlFnSz)
    RERnAmPlt = bar(CurrAxs{iF}, MnthCtg, RainAmXMnt, 'FaceColor','#185e9f', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    pbaspect([4,1,1])
    iF = iF + 1;
end

if any(strcmpi(Var2Plt, 'Average temperature'))
    CurrAxs{iF} = nexttile([1, 1]);
    hold(CurrAxs{iF}, 'on')
    set(CurrAxs{iF}, 'FontName',SlFont, 'FontSize',SlFnSz)
    xlabel(CurrAxs{iF}, xLabTxt, 'FontName',SlFont, 'FontSize',SlFnSz)
    ylabel(CurrAxs{iF}, 'Average temperature [°C]', 'FontName',SlFont, 'FontSize',SlFnSz)
    title(CurrAxs{iF}, ['RE avg temperature (',num2str(min(EventYear)),' - ',num2str(max(EventYear)),')'], 'FontName',SlFont, 'FontSize',SlFnSz)
    RETmAmPlt = bar(CurrAxs{iF}, MnthCtg, TempAmXMnt, 'FaceColor','#ffc262', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    pbaspect([4,1,1])
    iF = iF + 1;
end

if any(strcmpi(Var2Plt, 'Average NDVI'))
    CurrAxs{iF} = nexttile([1, 1]);
    hold(CurrAxs{iF}, 'on')
    set(CurrAxs{iF}, 'FontName',SlFont, 'FontSize',SlFnSz)
    xlabel(CurrAxs{iF}, xLabTxt, 'FontName',SlFont, 'FontSize',SlFnSz)
    ylabel(CurrAxs{iF}, 'Average NDVI [-]', 'FontName',SlFont, 'FontSize',SlFnSz)
    title(CurrAxs{iF}, ['RE avg NDVI (',num2str(min(EventYear)),' - ',num2str(max(EventYear)),')'], 'FontName',SlFont, 'FontSize',SlFnSz)
    RENVAmPlt = bar(CurrAxs{iF}, MnthCtg, NDVIAmXMnt, 'FaceColor','#a0db8e', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
    ylim([140, 180])
    pbaspect([4,1,1])
    iF = iF + 1;
end

% Showing plot and saving...
exportgraphics(CurrFig, [fold_fig,sl,CurrNme,'.png'], 'Resolution',600);

if ShowPlt
    set(CurrFig, 'visible','on')
    pause
end

close(CurrFig)