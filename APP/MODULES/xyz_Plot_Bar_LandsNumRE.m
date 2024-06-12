if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files
sl = filesep;

load([fold_var,sl,'LandslidesInfo.mat'       ], 'GeneralLandslidesSummary')
load([fold_var,sl,'GenInfoRainfallEvents.mat'], 'GeneralRE')
load([fold_var,sl,'DatasetMLA.mat'           ], 'DatasetInfo')

%% Plots common options
if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize')
    SelFont = Font;
    SelFnSz = FontSize;
else
    SelFont = 'Calibri';
    SelFnSz = 8;
end

ShowPlt = uiconfirm(Fig, 'Do you want to show plots?', ...
                         'Show Plots', 'Options',{'Yes', 'No'}, 'DefaultOption',2);
if strcmp(ShowPlt,'Yes'); ShowPlt = true; else; ShowPlt = false; end

MunsSlc = DatasetInfo.LandslidesMunicipalities;

%% Plots (RE and landslides number)
ProgressBar.Message = 'Event overviews plots...';

EventsYear = year(GeneralRE.Start);
EventsYrUn = unique(EventsYear);

MunsLbls = MunsSlc;
if numel(MunsLbls) > 8
    MunsLbls = [MunsLbls(1:7); {'...'}];
end

fold_mun = [fold_fig,sl,'RE Overview'];
if ~exist(fold_mun, 'dir')
    mkdir(fold_mun)
end

% MunicipsUn = unique(cat(1, GeneralLandslidesSummary.Municipalities{:}));
% Muns2Check = checkbox2(MunicipsUn, 'Title',{'Municipalities (plotted in green):'});
% MunsAreIns = false(size(GeneralRE.Start));
% for i1 = 1:length(MunsAreIns)
%     if isempty(GeneralRE.Municipalities{i1}); continue; end
%     MunsAreIns(i1) = any(ismember(GeneralRE.Municipalities{i1}, Muns2Check));
% end

for i1 = 1:length(EventsYrUn)
    CurrNme = ['RE - yr ',num2str(EventsYrUn(i1))];
    CurrFig = figure(i1);
    CurrAxs = axes(CurrFig);

    set(CurrFig, 'Name',CurrNme, 'visible','off')

    IndsEventsInYear = (EventsYrUn(i1) == EventsYear);
    StartDatesToPlot = categorical(string(datetime(GeneralRE.Start(IndsEventsInYear), 'Format','dd-MMM-yyyy')));
    StartDatesToPlot = reordercats(StartDatesToPlot, string(datetime(GeneralRE.Start(IndsEventsInYear), 'Format','dd-MMM-yyyy'))); % DON'T DELETE THIS ROW!!! Is necessary even if FeaturesNames is already in the correct order!
    LandsNumInToPlot = GeneralRE.LandsNum(IndsEventsInYear);
    LandsNumIOToPlot = GeneralRE.LandsNumIO(IndsEventsInYear);
    LandsNumOuToPlot = LandsNumIOToPlot-LandsNumInToPlot;

    BarPlot = bar(CurrAxs, StartDatesToPlot, [LandsNumInToPlot, LandsNumOuToPlot], 'stacked', 'FaceColor','flat', 'BarWidth',1, 'EdgeColor','k');
    BarPlot(1).CData = repmat([.2, .6, .5], length(LandsNumInToPlot), 1);

    UpYLim = max(ceil(1.15*max(LandsNumIOToPlot)), 5);

    ylim([0, UpYLim])
    ylabel('Number of landslides', 'FontName',SelFont, 'FontSize',SelFnSz)

    xtickangle(CurrAxs, 90)
    xlabel('Dates of rainfall events', 'FontName',SelFont, 'FontSize',SelFnSz)
    
    pbaspect([3,1,1])

    xTick = get(CurrAxs,'XTickLabel');
    set(CurrAxs, 'XTickLabel',xTick, 'FontName',SelFont,'FontSize',0.8*SelFnSz)

    yTick = get(CurrAxs,'YTickLabel');
    set(CurrAxs, 'YTickLabel',yTick, 'FontName',SelFont,'FontSize',0.8*SelFnSz)

    title('Generall view of RE', 'FontName',SelFont, 'FontSize',1.5*SelFnSz)
    subtitle(['Green bars for sel muns (',strjoin(MunsLbls, '; '),')'], 'FontName',SelFont, 'FontSize',SelFnSz)

    % Showing plot and saving...
    if ShowPlt
        set(CurrFig, 'visible','on');
        pause
    end

    exportgraphics(CurrFig, [fold_mun,sl,CurrNme,'.png'], 'Resolution',600);
    close(CurrFig)
end