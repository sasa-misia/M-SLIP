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

PssMnth = 1:12;
MnthSht = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'};

MnthCtg = categorical(MnthSht);
MnthCtg = reordercats(MnthCtg, MnthSht); % DON'T DELETE THIS ROW!!!

BarWdth = .6;

%% Core
EventYear  = year(GeneralRE.Start);
LandsCount = GeneralRE.LandsNum;
TrgRainAmt = GeneralRE.TrigRain;
NumOfYears = numel(unique(EventYear));
EventMonth = month(GeneralRE.Start);
EventXMnth = arrayfun(@(x) sum(EventMonth == x), PssMnth);
LandsXMnth = arrayfun(@(x) sum(LandsCount(EventMonth == x)), PssMnth);
AmntXMnth  = arrayfun(@(x) mean(TrgRainAmt(EventMonth == x)), PssMnth);

%% Plot
ProgressBar.Message = 'Plot...';

CurrNme = 'Seasonality of RE and LE';
CurrFig = figure('Position',[20, 20, 550, 700], 'Name',CurrNme, 'Visible','off');
CurrLay = tiledlayout(3, 1, 'Parent',CurrFig);
CurrAxs = deal(cell(1, 3));
xLabTxt = 'Month';

CurrAxs{1} = nexttile([1, 1]);
hold(CurrAxs{1}, 'on')
set(CurrAxs{1}, 'FontName',SelFont, 'FontSize',SelFnSz)
xlabel(CurrAxs{1}, xLabTxt, 'FontName',SelFont, 'FontSize',SelFnSz)
ylabel(CurrAxs{1}, 'Number of RE [-]', 'FontName',SelFont, 'FontSize',SelFnSz)
title(CurrAxs{1}, ['RE (from ',num2str(min(EventYear)),' to ',num2str(max(EventYear)),')'], 'FontName',SelFont, 'FontSize',SelFnSz)
RENumPlt = bar(CurrAxs{1}, MnthCtg, EventXMnth, 'FaceColor','#717171', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
pbaspect([3,1,1])

CurrAxs{2} = nexttile([1, 1]);
hold(CurrAxs{2}, 'on')
set(CurrAxs{2}, 'FontName',SelFont, 'FontSize',SelFnSz)
xlabel(CurrAxs{2}, xLabTxt, 'FontName',SelFont, 'FontSize',SelFnSz)
ylabel(CurrAxs{2}, 'Average rain amount [mm]', 'FontName',SelFont, 'FontSize',SelFnSz)
title(CurrAxs{2}, ['RE average amount (',num2str(min(EventYear)),' - ',num2str(max(EventYear)),')'], 'FontName',SelFont, 'FontSize',SelFnSz)
REAmnPlt = bar(CurrAxs{2}, MnthCtg, AmntXMnth, 'FaceColor','#185e9f', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
pbaspect([3,1,1])

CurrAxs{3} = nexttile([1, 1]);
hold(CurrAxs{3}, 'on')
set(CurrAxs{3}, 'FontName',SelFont, 'FontSize',SelFnSz)
xlabel(CurrAxs{3}, xLabTxt, 'FontName',SelFont, 'FontSize',SelFnSz)
ylabel(CurrAxs{3}, 'Number of LE [-]', 'FontName',SelFont, 'FontSize',SelFnSz)
title(CurrAxs{3}, ['LE (from ',num2str(min(EventYear)),' to ',num2str(max(EventYear)),')'], 'FontName',SelFont, 'FontSize',SelFnSz)
LENumPlt = bar(CurrAxs{3}, MnthCtg, LandsXMnth, 'FaceColor','#b11771', 'EdgeColor','#000000', 'LineWidth',.7, 'BarWidth',BarWdth);
pbaspect([3,1,1])

% Showing plot and saving...
exportgraphics(CurrFig, [fold_fig,sl,CurrNme,'.png'], 'Resolution',600);

if ShowPlt
    set(CurrFig, 'visible','on');
    pause
end

close(CurrFig)