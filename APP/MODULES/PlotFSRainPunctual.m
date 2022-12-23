%% File loading
cd(fold_var)
load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips')
load('GeneralRainfall.mat', 'RainfallDates');

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'best';
end

%% Data extraction and manipulation
Municipalities = InfoDetectedSoilSlips(:,1);
Locations = InfoDetectedSoilSlips(:,2);
DTMIncludingPoint = [InfoDetectedSoilSlips{:,3}]';
NearestPoint = [InfoDetectedSoilSlips{:,4}]';

cd(fold_res_fs)
foldFS = uigetdir('open');
[~, namefoldFS] = fileparts(foldFS);
cd(foldFS)
load('AnalysisInformation.mat');

ExtremeDates = StabilityAnalysis{3};
DateRain = RainfallDates(ExtremeDates(1):ExtremeDates(2));
NumberAnalysis = StabilityAnalysis{1};
DateAnalysis = StabilityAnalysis{2};

IndRainAnalysis = zeros(1,length(DateAnalysis));
for i1 = 1:length(DateAnalysis)
    IndRainAnalysis(i1) = find( DateRain==DateAnalysis(i1) );
end

if ~exist('PunctualData.mat', 'file') % If you overwrite Fs matrices and mantain PunctualData in the same folder you'll skip this part and you'll be wrong. Pay attention!
    load('FS1.mat');
    Fs = cell(NumberAnalysis, length(FactorSafety));
    for i1 = 1:NumberAnalysis
        load( strcat('Fs',num2str(i1)) );
        Fs(i1,:) = FactorSafety;
    end

    cd(fold_var)
    % Fig = uifigure; % Remember to comment this line if is app version
    ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Loading rainfall data...', 'Indeterminate','on');
    drawnow
    load('RainInterpolated.mat');
    close(ProgressBar) % ProgressBar instead of Fig if on the app version
    
    Rain = cell(1, size(DTMIncludingPoint,1)); % Initializing
    FsAll = cell(size(Fs,1), size(DTMIncludingPoint,1)); % Initializing
    for i1=1:size(DTMIncludingPoint,1)
        Rain{i1} = cellfun(@(x) full(x(NearestPoint(i1),1)), ...
                                    RainInterpolated(:,DTMIncludingPoint(i1)), 'UniformOutput',false); % full is to convert sparse in normal matrix

        FsAll(:,i1) = cellfun(@(x) x(NearestPoint(i1),1), Fs(:,DTMIncludingPoint(i1)), 'UniformOutput',false); % Every column is referred to a different point. Rows indicate hours of the same point
    end

    cd(foldFS)
    save('PunctualData.mat', 'Rain','FsAll')
else
    load('PunctualData.mat')
end

% Select location to plot
MunUnique = unique(Municipalities);
IndMun = cell(1, size(MunUnique,2));
for i1 = 1:size(MunUnique,2)
    IndMun{i1} = cellfun(@(x) strcmp(x,MunUnique{i1}), Municipalities);
end

MunUnique = string(MunUnique);
ChoiceMun = listdlg('PromptString',{'Select Municipality:',''}, 'ListString',MunUnique);

Locations = string(Locations);
ChoiceLoc = listdlg('PromptString',{'Select Location:',''}, 'ListString',Locations(IndMun{ChoiceMun}));
SelectedLoc = Locations(ChoiceLoc);

Ind = cellfun(@(x) strcmp(x,SelectedLoc), InfoDetectedSoilSlips(:,2), 'UniformOutput',false); % Maybe a double strcmp would be better but it doesn't work
Ind = cell2mat(Ind);

Fs2Plot = [FsAll{:,Ind}];
IndFsUnstab = Fs2Plot < 1;

%% Plot
filename1 = strcat("FS ",SelectedLoc);
f1 = figure(1);
ax1 = axes('Parent',f1);
hold(ax1,'on');

set(f1, 'Name',filename1);

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
bar(DateRain, cell2mat(Rain{Ind}), 'FaceColor',[0 127 255]./255);
ylabel('{\it h_w} [mm]', 'FontName',SelectedFont)

set(gca, ...
    'XLim'        , [min(DateAnalysis) max(DateAnalysis)], ...
    'YLim'        , [0 max(cell2mat(Rain{Ind}(IndRainAnalysis)))+2], ...
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
    'YTick'       , 0:1:max(cell2mat(Rain{Ind}(IndRainAnalysis)))+2, ...
    'FontSize'    , SelectedFontSize, ...
    'FontName'    , SelectedFont,...
    'LineWidth'   , .5)

title(SelectedLoc, SelectedMun, 'FontName',SelectedFont, 'FontSize',SelectedFontSize);

exportgraphics(f1, strcat(filename1,'.png'), 'Resolution',600);