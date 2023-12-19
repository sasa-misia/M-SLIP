if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
load([fold_var,sl,'GeneralRainfall.mat'],       'RecDatesEndCommon');

InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDefInfoDet};

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SelectedFont     = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont     = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition   = 'best';
end

%% Options
ProgressBar.Message = 'Options...';

ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

%% Data extraction and manipulation
ProgressBar.Message = 'Data extraction...';

Municipalities    = InfoDetectedSoilSlipsToUse(:,1);
Locations         = InfoDetectedSoilSlipsToUse(:,2);
DTMIncludingPoint = [InfoDetectedSoilSlipsToUse{:,3}]';
NearestPoint      = [InfoDetectedSoilSlipsToUse{:,4}]';

foldFS = uigetdir(fold_res_fs, 'Select the folder');
[~, namefoldFS] = fileparts(foldFS);

figure(Fig)
drawnow

load([foldFS,sl,'AnalysisInformation.mat'], 'StabilityAnalysis');

NumberAnalysis = StabilityAnalysis{1};
DateAnalysis   = StabilityAnalysis{2};
ExtremeDates   = StabilityAnalysis{3};
DateRain       = RecDatesEndCommon(ExtremeDates(1):ExtremeDates(2));

IndRainAnalysis = zeros(1, length(DateAnalysis));
for i1 = 1:length(DateAnalysis)
    IndRainAnalysis(i1) = find( DateRain==DateAnalysis(i1) );
end

if exist([foldFS,sl,'PunctualData.mat'], 'file') % Pay attention: If you overwrite Fs files and mantain old PunctualData, you load old one!!!
    load([foldFS,sl,'PunctualData.mat'], 'Rain','FsAll')

else
    load([foldFS,sl,'Fs1.mat'], 'FactorSafety');

    FS = cell(NumberAnalysis, length(FactorSafety));
    for i1 = 1:NumberAnalysis
        load([foldFS,sl,'Fs',num2str(i1),'.mat'], 'FactorSafety');
        FS(i1,:) = FactorSafety;
    end

    ProgressBar.Message = 'Reading rainfall data...';
    load([fold_var,sl,'RainInterpolated.mat'], 'RainInterpolated');

    ProgressBar.Message = 'Data extraction...';
    Rain  = cell(1,          size(DTMIncludingPoint,1)); % Initializing
    FsAll = cell(size(FS,1), size(DTMIncludingPoint,1)); % Initializing
    for i1 = 1:size(DTMIncludingPoint,1)
        Rain{i1}    = cellfun(@(x) full(x(NearestPoint(i1),1)), ...
                                            RainInterpolated(:,DTMIncludingPoint(i1)), 'UniformOutput',false); % full is to convert sparse in normal matrix

        FsAll(:,i1) = cellfun(@(x) x(NearestPoint(i1),1), FS(:,DTMIncludingPoint(i1)), 'UniformOutput',false); % Every column is referred to a different point. Rows indicate hours of the same point
    end

    save([foldFS,sl,'PunctualData.mat'], 'Rain','FsAll')
end

% Select location to plot
MunUnique = unique(Municipalities);
IndMun    = cell(1, length(MunUnique));
for i1 = 1:length(MunUnique)
    IndMun{i1} = cellfun(@(x) strcmp(x,MunUnique{i1}), Municipalities);
end

MunUnique   = string(MunUnique);
ChoiceMun   = listdlg2({'Select Municipality:'}, MunUnique, 'OutType','NumInd');
SelectedMun = MunUnique(ChoiceMun);

Locations   = strcat(string(Locations), " ", string(1:length(Locations))');
PossLocats  = Locations(IndMun{ChoiceMun});
SelectedLoc = char(listdlg2({'Select Location:'}, PossLocats));
IndLocation = strcmp(SelectedLoc, Locations);

Fs2Plot     = [FsAll{:,IndLocation}];
IndFsUnstab = Fs2Plot < 1;

%% Plot
ProgressBar.Message = 'Plotting...';

filename1 = ['FS History for ',SelectedLoc];
f1  = figure(1);
ax1 = axes('Parent',f1);
hold(ax1,'on');

set(f1, 'Name',filename1, 'Visible','off');

yyaxis left
line(DateAnalysis, Fs2Plot, 'Marker','^', 'MarkerSize',2, 'Color','k')
plot([DateAnalysis(1), DateAnalysis(end)], [1 1], '--r', 'LineWidth',0.5);
scatter(DateAnalysis(IndFsUnstab), Fs2Plot(IndFsUnstab), 'or')
ylabel('{\it F_s}', 'FontName',SelectedFont)

set(gca, ...
    'XLim'        , [min(DateAnalysis) max(DateAnalysis)], ...
    'YLim'        , [0.5 max(Fs2Plot)], ...
    'Box'         , 'on', ...
    'TickDir'     , 'in', ...
    'TickLength'  , [.01 .01], ...
    'XMinorTick'  , 'on', ...
    'YMinorTick'  , 'on', ...
    'XGrid'       , 'off', ...
    'YGrid'       , 'off', ...
    'XColor'      , [0 0 0], ...
    'YColor'      , [0 0 0], ...
    'XTick'       , DateAnalysis(1):hours(6):DateAnalysis(end), ...
    'YTick'       , 0:0.2:max(Fs2Plot), ...
    'FontSize'    , SelectedFontSize, ...
    'FontName'    , SelectedFont, ...
    'LineWidth'   , .5, ...
    'SortMethod'  , 'depth')

yyaxis right
bar(DateRain, cell2mat(Rain{IndLocation}), 'FaceColor',[0 127 255]./255);
ylabel('{\it h_w} [mm]', 'FontName',SelectedFont)

set(gca, ...
    'XLim'        , [min(DateAnalysis) max(DateAnalysis)], ...
    'YLim'        , [0 max(cell2mat(Rain{IndLocation}(IndRainAnalysis)))+2], ...
    'Box'         , 'on', ...
    'TickDir'     , 'in', ...
    'TickLength'  , [.01 .01], ...
    'XMinorTick'  , 'off', ...
    'YMinorTick'  , 'off', ...
    'XGrid'       , 'off', ...
    'YGrid'       , 'off', ...
    'XColor'      , [0 0 0], ...
    'YColor'      , [0 127 255]./255, ...
    'XTick'       , DateAnalysis(1):hours(6):DateAnalysis(end), ...
    'YTick'       , 0:1:max(cell2mat(Rain{IndLocation}(IndRainAnalysis)))+2, ...
    'FontSize'    , SelectedFontSize, ...
    'FontName'    , SelectedFont,...
    'LineWidth'   , .5)

title(SelectedLoc, SelectedMun, 'FontName',SelectedFont, 'FontSize',SelectedFontSize);

%% Saving...
ProgressBar.Message = 'Saving...';
exportgraphics(f1, [fold_fig,sl,namefoldFS,sl,filename1,'.png'], 'Resolution',600);

%% Show Fig
if ShowPlots
    set(f1, 'Visible','on');
else
    close(f1)
end