% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
cd(fold_var)
load('StudyAreaVariables.mat', 'StudyAreaPolygon')
load('GridCoordinates.mat',    'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load('HRUs.mat',               'CombinationsAll','HRUsAll','InfoLegLandUse','InfoLegSlope','InfoLegSoil')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'Best';
end

InfoDetectedExist = false;
if exist('InfoDetectedSoilSlips.mat', 'file')
    load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetectedExist = true;
end

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
cd(fold_res_ml_curr)
load('TrainedANNs.mat',               'TotPolUncStable','TotPolUnstabPoints')
cd(fold0)

%% Plot settings
ProgressBar.Message = 'Plot settings...';
Options  = {'Study Area', 'Stable and Unstable'};
AreaType = uiconfirm(Fig, 'What area do you want to plot?', ...
                          'Area Type', 'Options',Options);

Options  = {'HRUs', 'Combinations'};
InfoType = uiconfirm(Fig, 'What information do you want to plot?', ...
                          'HRUs', 'Options',Options);

Options   = {'Yes', 'No'};
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',Options, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

RefStudyArea = 0.0417;
ExtentStudyArea = area(StudyAreaPolygon);
% ExtentStudyArea = prod(MaxExtremes-MinExtremes);
RatioRef     = ExtentStudyArea/RefStudyArea;
PixelSize    = .028/RatioRef;
PixelSizeEnt = PixelSize;
DetPixelSize = 7.5*PixelSize;
LineExtSize  = 1.5;

rng(13) % Change the seed to have different colors

if strcmp(AreaType, 'Study Area')
    PixelSize    = 3.5*PixelSize;
    DetPixelSize = 4*PixelSize;
    ExportRes    = 1200;
elseif strcmp(AreaType, 'Stable and Unstable')
    Options = {'Yes', 'No'};
    ShowPixelsInUndecisionArea = uiconfirm(Fig, 'Do you want to show pixels in undecision area?', ...
                                                'Show pixels in undecision area', 'Options',Options, 'DefaultOption',2);
    if strcmp(ShowPixelsInUndecisionArea,'Yes'); ShowPixelsInUndecisionArea = true; else; ShowPixelsInUndecisionArea = false; end

    ExportRes = 600;
end

%% Definition of area to plot
ProgressBar.Message = 'Defining area to plot...';
switch AreaType
    case 'Study Area'
        AreaToPlot = StudyAreaPolygon;
        IndToPlot  = IndexDTMPointsInsideStudyArea;

    case 'Stable and Unstable'
        TotPolStableSplit   = regions(TotPolUncStable);
        TotPolWithoutHoles  = rmholes(TotPolStableSplit);
        TotPolUnstableSplit = arrayfun(@(x) intersect(x, TotPolUnstabPoints), TotPolWithoutHoles);
        
        AreaToPlot = arrayfun(@(x,y) union(x, y), TotPolStableSplit, TotPolUnstableSplit);
        IndToPlot  = cell(length(AreaToPlot), size(xLongAll,2));
        for i1 = 1:length(AreaToPlot)
            if ShowPixelsInUndecisionArea
                [pp1, ee1] = getnan2([TotPolWithoutHoles(i1).Vertices; nan, nan]);
            else
                [pp1, ee1] = getnan2([AreaToPlot(i1).Vertices; nan, nan]);
            end
            IndToPlot(i1,:) = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp1,ee1)), xLongAll, yLatAll, 'UniformOutput',false);
        end
end

%% Creation of matrices with colors
ProgressBar.Message = 'Creation of colors...';
CombinationsAllCatPerDTM = cellfun(@(x) [x(:)], CombinationsAll, 'UniformOutput',false);
[CombinationsAllUnique, ~, IndCombsAllUnique] = unique(cat(1, CombinationsAllCatPerDTM{:}));
CombsColorsUnique  = arrayfun(@(x) rand(1, 3), CombinationsAllUnique, 'UniformOutput',false);
CombsColorPerPixel = CombsColorsUnique(IndCombsAllUnique);

IndStart = 1;
CombsColorsAll = cellfun(@(x) cell(size(x)), CombinationsAll, 'UniformOutput',false);
for i1 = 1:length(CombinationsAll)
    NumEl = numel(CombsColorsAll{i1});
    CombsColorsAll{i1}(:) = CombsColorPerPixel(IndStart : IndStart+NumEl-1);
    IndStart = IndStart+NumEl;
end

HRUsAllCatPerDTM = cellfun(@(x) [x(:)], HRUsAll, 'UniformOutput',false);
[HRUsAllUnique, ~, IndHRUsAllUnique] = unique(cat(1, HRUsAllCatPerDTM{:}));
HRUsColorsUnique  = arrayfun(@(x) rand(1, 3), HRUsAllUnique, 'UniformOutput',false);
HRUsColorPerPixel = HRUsColorsUnique(IndHRUsAllUnique);

IndStart = 1;
HRUsColorsAll = cellfun(@(x) cell(size(x)), HRUsAll, 'UniformOutput',false);
for i1 = 1:length(HRUsAll)
    NumEl = numel(HRUsColorsAll{i1});
    HRUsColorsAll{i1}(:) = HRUsColorPerPixel(IndStart : IndStart+NumEl-1);
    IndStart = IndStart+NumEl;
end

%% Extraction of data
ProgressBar.Message = 'Extraction of data...';
[xLongToPlot, yLatToPlot, CombsToPlot, CombsColorsToPlot, HRUsToPlot, HRUsColorsToPLot] = deal(cell(size(IndToPlot)));
[xLongCatPerAreaToPlot, yLatCatPerAreaToPlot, ...
        CombsCatPerAreaToPlot, CombsUniquePerArea, CombsIndPerArea, CombsColorsPerArea, ...
        HRUsCatPerAreaToPlot,  HRUsUniquePerArea,  HRUsIndPerArea,  HRUsColorsPerArea] = deal(cell(1, length(AreaToPlot)));
for i1 = 1:length(AreaToPlot)
    xLongToPlot(i1,:) = cellfun(@(x,y) x(y), xLongAll       , IndToPlot(i1,:), 'UniformOutput',false);
    yLatToPlot(i1,:)  = cellfun(@(x,y) x(y), yLatAll        , IndToPlot(i1,:), 'UniformOutput',false);
    CombsToPlot(i1,:) = cellfun(@(x,y) x(y), CombinationsAll, IndToPlot(i1,:), 'UniformOutput',false);
    HRUsToPlot(i1,:)  = cellfun(@(x,y) x(y), HRUsAll        , IndToPlot(i1,:), 'UniformOutput',false);

    CombsColorsToPlot(i1,:) = cellfun(@(x,y) x(y), CombsColorsAll, IndToPlot(i1,:), 'UniformOutput',false);
    HRUsColorsToPLot(i1,:)  = cellfun(@(x,y) x(y), HRUsColorsAll,  IndToPlot(i1,:), 'UniformOutput',false);

    xLongCatPerAreaToPlot{i1} = cat(1, xLongToPlot{i1,:});
    yLatCatPerAreaToPlot{i1}  = cat(1, yLatToPlot{i1,:});
    CombsCatPerAreaToPlot{i1} = cat(1, CombsToPlot{i1,:});
    HRUsCatPerAreaToPlot{i1}  = cat(1, HRUsToPlot{i1,:});

    CombsColorsPerArea{i1} = cell2mat(cat(1, CombsColorsToPlot{i1,:}));
    HRUsColorsPerArea{i1}  = cell2mat(cat(1, HRUsColorsToPLot{i1,:}));

    [CombsUniquePerArea{i1}, ~, CombsIndPerArea{i1}] = unique(CombsCatPerAreaToPlot{i1});
    [HRUsUniquePerArea{i1},  ~, HRUsIndPerArea{i1} ] = unique(HRUsCatPerAreaToPlot{i1});
end
% clear('xLongAll', 'yLatAll', 'CombinationsAll', 'HRUsAll')

%% Plot (preliminary operations)
ProgressBar.Message = 'Preliminary operations for plots...';
switch AreaType
    case 'Study Area'
        fold_fig_curr = fold_fig;

    case 'Stable and Unstable'
        fold_fig_curr = [fold_fig,sl,'HRUs & Combs for Detected Landslides'];
end

if ~exist(fold_fig_curr, 'dir')
    mkdir(fold_fig_curr)
end

switch InfoType
    case 'Combinations'
        ClassesToUse  = CombsUniquePerArea;
        % ClassIndToUse    = CombsIndPerArea;
        ClassesColors = CombsColorsPerArea;

    case 'HRUs'
        ClassesToUse  = HRUsUniquePerArea;
        % ClassIndToUse    = HRUsIndPerArea;
        ClassesColors = HRUsColorsPerArea;
end

%% Plot
for i1 = 1:length(AreaToPlot)
    ProgressBar.Message = ['Plotting fig. n. ',num2str(i1),'...'];

    if strcmp(AreaType, 'Study Area')
        filename_curr = [InfoType,' for Study Area'];
    elseif strcmp(AreaType, 'Stable and Unstable')
        filename_curr = [InfoType,' for Area n-',num2str(i1)];

        ExtentNewSA  = area(AreaToPlot(i1));
        NewRatioRef  = ExtentNewSA/ExtentStudyArea;
        PixelSize    = 0.6*PixelSizeEnt/NewRatioRef;
        DetPixelSize = 0.7*PixelSize;
    end

    fig_curr = figure(i1);
    ax_curr  = axes('Parent',fig_curr); 
    hold(ax_curr,'on');
    set(fig_curr, 'Visible','off')

    plot(AreaToPlot(i1), 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_curr)

    hclasses = scatter(xLongCatPerAreaToPlot{i1}, yLatCatPerAreaToPlot{i1}, PixelSize, ClassesColors{i1}, ...
                                        'Filled', 'Marker','s', 'Parent',ax_curr);

    if InfoDetectedExist
        hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled', 'Parent',ax_curr), ...
                                    InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
        uistack(hdetected,'top')
    end

    Extremes = [ min(xLongCatPerAreaToPlot{i1}), min(yLatCatPerAreaToPlot{i1})
                 max(xLongCatPerAreaToPlot{i1}), min(yLatCatPerAreaToPlot{i1})
                 max(xLongCatPerAreaToPlot{i1}), max(yLatCatPerAreaToPlot{i1})
                 min(xLongCatPerAreaToPlot{i1}), max(yLatCatPerAreaToPlot{i1}) ]; % From bottom left to top left

    fig_settings(fold0, 'SetExtremes',Extremes)

    if strcmp(AreaType, 'Study Area')
        title([InfoType,' for ',AreaType], 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize)
    elseif strcmp(AreaType, 'Stable and Unstable')
        title([InfoType,' for ',AreaType,' areas n. ',num2str(i1)], 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize)
    end

    set(ax_curr, 'visible','off') % To hide axis (but it will hide also titles)
    set(findall(ax_curr, 'type', 'text'), 'visible', 'on') % To show again titles

    %% Showing plot and saving...
    ProgressBar.Message = ['Saving fig. n. ',num2str(i1),'...'];
    if ShowPlots
        set(fig_curr, 'visible','on');
        pause
    end

    cd(fold_fig_curr)
    exportgraphics(fig_curr, [filename_curr,'.png'], 'Resolution',ExportRes);
    close(fig_curr)
end
cd(fold0)

close(ProgressBar)