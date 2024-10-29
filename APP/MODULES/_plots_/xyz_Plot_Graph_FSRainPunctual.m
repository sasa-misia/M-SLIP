if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
load([fold_var,sl,'GeneralRainfall.mat'      ], 'RecDatesEndCommon');

InfoDet2Use = InfoDetectedSoilSlips{IndDefInfoDet};

[SlFont, SlFnSz] = load_plot_settings(fold_var);

%% Options
ProgressBar.Message = 'Options...';

ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

%% Data extraction and manipulation
ProgressBar.Message = 'Data extraction...';

Municipal = InfoDet2Use{:,1};
Locations = InfoDet2Use{:,2};
DTMwPoint = InfoDet2Use{:,3};
NearPoint = InfoDet2Use{:,4};

foldFS = uigetdir(fold_res_fs, 'Select the folder');
[~, foldNameFS] = fileparts(foldFS);

figure(Fig)
drawnow

load([foldFS,sl,'AnalysisInformation.mat'], 'StabilityAnalysis');

NmbrAnalyses = StabilityAnalysis{1};
DateAnalysis = StabilityAnalysis{2};
ExtremeDates = StabilityAnalysis{3};
DateRainfall = RecDatesEndCommon(ExtremeDates(1):ExtremeDates(2));

IndRainAnalysis = zeros(1, length(DateAnalysis));
for i1 = 1:length(DateAnalysis)
    IndRainAnalysis(i1) = find( DateRainfall==DateAnalysis(i1) );
end

if exist([foldFS,sl,'PunctualData.mat'], 'file') % Pay attention: If you overwrite Fs files and mantain old PunctualData, you load old one!!!
    load([foldFS,sl,'PunctualData.mat'], 'Rain','FsAll')
    warning(['PunctualData.mat already exist in your FS folder. ', ...
             'If something has changed, please delete this file, ', ...
             'otherwise you are now loading the old one!'])

else
    load([foldFS,sl,'Fs1.mat'], 'FactorSafety');

    FS = cell(NmbrAnalyses, length(FactorSafety));
    for i1 = 1:NmbrAnalyses
        load([foldFS,sl,'Fs',num2str(i1),'.mat'], 'FactorSafety');
        FS(i1,:) = FactorSafety;
    end

    ProgressBar.Message = 'Reading rainfall data...';
    load([fold_var,sl,'RainInterpolated.mat'], 'RainInterpolated');

    ProgressBar.Message = 'Data extraction...';
    Rain  = cell(1,          size(DTMwPoint,1)); % Initializing
    FsAll = cell(size(FS,1), size(DTMwPoint,1)); % Initializing
    for i1 = 1:size(DTMwPoint,1)
        Rain{i1}    = cellfun(@(x) full(x(NearPoint(i1),1)), ...
                                            RainInterpolated(:,DTMwPoint(i1)), 'UniformOutput',false); % full is to convert sparse in normal matrix

        FsAll(:,i1) = cellfun(@(x) x(NearPoint(i1),1), FS(:,DTMwPoint(i1)), 'UniformOutput',false); % Every column is referred to a different point. Rows indicate hours of the same point
    end

    save([foldFS,sl,'PunctualData.mat'], 'Rain','FsAll')
end

% Select location to plot
MunUnq = unique(Municipal);
IndMun = cell(1, length(MunUnq));
for i1 = 1:length(MunUnq)
    IndMun{i1} = strcmp(Municipal, MunUnq(i1));
end

MunUnq = string(MunUnq);
ChcMun = listdlg2({'Select Municipality:'}, MunUnq, 'OutType','NumInd');
SelMun = MunUnq(ChcMun);

Locations = strcat(string(Locations), " ", string(1:length(Locations))');
PossLctns = Locations(IndMun{ChcMun});
SelLctns  = char(listdlg2({'Select Location:'}, PossLctns));
IndLctns  = strcmp(SelLctns, Locations);

Fs2Plot = [FsAll{:,IndLctns}];
IndUnst = Fs2Plot < 1;

%% Plot
ProgressBar.Message = 'Plotting...';

CurrFln = ['FS History for ',SelLctns];
CurrFig = figure(1);
CurrAxs = axes('Parent',CurrFig);
hold(CurrAxs,'on');

set(CurrFig, 'Name',CurrFln, 'Visible','off');

yyaxis left
line(DateAnalysis, Fs2Plot, 'Marker','^', 'MarkerSize',2, 'Color','k')
plot([DateAnalysis(1), DateAnalysis(end)], [1 1], '--r', 'LineWidth',0.5);
scatter(DateAnalysis(IndUnst), Fs2Plot(IndUnst), 'or')
ylabel('{\it F_s}', 'FontName',SlFont)

set(gca, ...
    'XLim'        , [min(DateAnalysis), max(DateAnalysis)], ...
    'YLim'        , [0.5, max(Fs2Plot)], ...
    'Box'         , 'on', ...
    'TickDir'     , 'in', ...
    'TickLength'  , [.01, .01], ...
    'XMinorTick'  , 'on', ...
    'YMinorTick'  , 'on', ...
    'XGrid'       , 'off', ...
    'YGrid'       , 'off', ...
    'XColor'      , [0, 0, 0], ...
    'YColor'      , [0, 0, 0], ...
    'XTick'       , DateAnalysis(1) : hours(6) : DateAnalysis(end), ...
    'YTick'       , 0 : 0.2 : max(Fs2Plot), ...
    'FontSize'    , SlFnSz, ...
    'FontName'    , SlFont, ...
    'LineWidth'   , .5, ...
    'SortMethod'  , 'depth')

yyaxis right
bar(DateRainfall, cell2mat(Rain{IndLctns}), 'FaceColor',[0 127 255]./255);
ylabel('{\it h_w} [mm]', 'FontName',SlFont)

set(gca, ...
    'XLim'        , [min(DateAnalysis), max(DateAnalysis)], ...
    'YLim'        , [0, max(cell2mat(Rain{IndLctns}(IndRainAnalysis)))+2], ...
    'Box'         , 'on', ...
    'TickDir'     , 'in', ...
    'TickLength'  , [.01, .01], ...
    'XMinorTick'  , 'off', ...
    'YMinorTick'  , 'off', ...
    'XGrid'       , 'off', ...
    'YGrid'       , 'off', ...
    'XColor'      , [0, 0, 0], ...
    'YColor'      , [0, 127, 255]./255, ...
    'XTick'       , DateAnalysis(1) : hours(6) : DateAnalysis(end), ...
    'YTick'       , 0 : 1 : max(cell2mat(Rain{IndLctns}(IndRainAnalysis)))+2, ...
    'FontSize'    , SlFnSz, ...
    'FontName'    , SlFont,...
    'LineWidth'   , .5)

title(SelLctns, SelMun, 'FontName',SlFont, 'FontSize',SlFnSz);

%% Saving...
ProgressBar.Message = 'Saving...';
exportgraphics(CurrFig, [fold_fig,sl,foldNameFS,sl,CurrFln,'.png'], 'Resolution',600);

%% Show Fig
if ShowPlots
    set(CurrFig, 'Visible','on');
else
    close(CurrFig)
end