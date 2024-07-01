% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
cd(fold_var)
load('StudyAreaVariables.mat', 'StudyAreaPolygon')
load('GridCoordinates.mat',    'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load('HRUs.mat',               'CombinationsAll','HRUsAll','ClassesForCombsAll','InfoLegLandUse','InfoLegSlope','InfoLegSoil')
load('DatasetStudy.mat',       'StablePolygons','UnstablePolygons')

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

%% Plot settings
ProgressBar.Message = 'Plot settings...';
Options  = {'Study Area', 'Stable and Unstable'};
AreaType = uiconfirm(Fig, 'What area do you want to plot?', ...
                          'Area Type', 'Options',Options);

Options  = {'HRUs', 'Combinations', 'ClassesCombs'};
InfoType = uiconfirm(Fig, 'What information do you want to plot?', ...
                          'HRUs', 'Options',Options);

Options   = {'Yes', 'No'};
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',Options, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon);
PixelSizeEnt = PixelSize;
LineExtSize  = 1.5;

rng(13) % Change the seed to have different colors

if strcmp(AreaType, 'Study Area')
    PixelSize    = 3.5*PixelSize;
    DetPixelSize = 4*PixelSize;
    ExportRes    = 1200;
elseif strcmp(AreaType, 'Stable and Unstable')
    Options = {'Yes', 'No'};
    ShowPixelsInUndecisionArea = uiconfirm(Fig, 'Do you want to show pixels in indecision area?', ...
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
        if isscalar(UnstablePolygons)
            TotPolStableSplit   = regions(StablePolygons);
            TotPolWithoutHoles  = rmholes(TotPolStableSplit);
            TotPolUnstableSplit = arrayfun(@(x) intersect(x, UnstablePolygons), TotPolWithoutHoles);
        else
            TotPolStableSplit   = StablePolygons;
            TotPolWithoutHoles  = rmholes(TotPolStableSplit);
            TotPolUnstableSplit = UnstablePolygons;
        end
        
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

% Combinations
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

% HRUs
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

% Classes for combs
ClassesForCombsColorsAll = cell(1, size(ClassesForCombsAll, 2));
for i1 = 1:size(ClassesForCombsAll, 2)
    Classes4CombsAllCatPerDTM = cellfun(@(x) [x(:)], ClassesForCombsAll{1,i1}{:}, 'UniformOutput',false);
    [Classes4CombsAllUnique, ~, IndClassesAllUnique] = unique(cat(1, Classes4CombsAllCatPerDTM{:}));
    ClassesColorsUnique  = arrayfun(@(x) rand(1, 3), Classes4CombsAllUnique, 'UniformOutput',false);
    ClassesColorPerPixel = ClassesColorsUnique(IndClassesAllUnique);
    
    IndStart = 1;
    ClassesColorsAllTemp = cellfun(@(x) cell(size(x)), ClassesForCombsAll{1,i1}{:}, 'UniformOutput',false);
    for i2 = 1:length(ClassesForCombsAll{1,i1}{:})
        NumEl = numel(ClassesColorsAllTemp{i2});
        ClassesColorsAllTemp{i2}(:) = ClassesColorPerPixel(IndStart : IndStart+NumEl-1);
        IndStart = IndStart+NumEl;
    end
    ClassesForCombsColorsAll{i1} = ClassesColorsAllTemp;
end
ClassesForCombsColorsAll = array2table(ClassesForCombsColorsAll, 'VariableNames',ClassesForCombsAll.Properties.VariableNames);

%% Extraction of data
ProgressBar.Message = 'Extraction of data...';

% Combinations and HRUs
[xLongToPlot, yLatToPlot, CombsToPlot, CombsColorsToPlot, HRUsToPlot, HRUsColorsToPlot] = deal(cell(size(IndToPlot)));
[xLongCatPerAreaToPlot, yLatCatPerAreaToPlot, ...
        CombsCatPerAreaToPlot, CombsUniquePerArea, CombsIndUnique, CombsIndPerArea, CombsColorsPerArea, ...
        HRUsCatPerAreaToPlot,  HRUsUniquePerArea,  HRUsIndUnique,  HRUsIndPerArea,  HRUsColorsPerArea ] = deal(cell(1, length(AreaToPlot)));
for i1 = 1:length(AreaToPlot)
    xLongToPlot(i1,:) = cellfun(@(x,y) x(y), xLongAll       , IndToPlot(i1,:), 'UniformOutput',false);
    yLatToPlot(i1,:)  = cellfun(@(x,y) x(y), yLatAll        , IndToPlot(i1,:), 'UniformOutput',false);
    CombsToPlot(i1,:) = cellfun(@(x,y) x(y), CombinationsAll, IndToPlot(i1,:), 'UniformOutput',false);
    HRUsToPlot(i1,:)  = cellfun(@(x,y) x(y), HRUsAll        , IndToPlot(i1,:), 'UniformOutput',false);

    CombsColorsToPlot(i1,:) = cellfun(@(x,y) x(y), CombsColorsAll, IndToPlot(i1,:), 'UniformOutput',false);
    HRUsColorsToPlot(i1,:)  = cellfun(@(x,y) x(y), HRUsColorsAll,  IndToPlot(i1,:), 'UniformOutput',false);

    xLongCatPerAreaToPlot{i1} = cat(1, xLongToPlot{i1,:});
    yLatCatPerAreaToPlot{i1}  = cat(1, yLatToPlot{i1,:});
    CombsCatPerAreaToPlot{i1} = cat(1, CombsToPlot{i1,:});
    HRUsCatPerAreaToPlot{i1}  = cat(1, HRUsToPlot{i1,:});

    CombsColorsPerArea{i1} = cell2mat(cat(1, CombsColorsToPlot{i1,:}));
    HRUsColorsPerArea{i1}  = cell2mat(cat(1, HRUsColorsToPlot{i1,:}));

    [CombsUniquePerArea{i1}, CombsIndUnique{i1}, CombsIndPerArea{i1}] = unique(CombsCatPerAreaToPlot{i1});
    [HRUsUniquePerArea{i1},  HRUsIndUnique{i1},  HRUsIndPerArea{i1} ] = unique(HRUsCatPerAreaToPlot{i1});
end
% clear('xLongAll', 'yLatAll', 'CombinationsAll', 'HRUsAll')

% Classes for combs
[Class4CombsToPlot, Class4CombsColorsToPlot, Class4CombsCatPerAreaToPlot, ...
    Class4CombsUniquePerArea, Class4CombsIndUnique, ...
    Class4CombsIndPerArea,  Class4CombsColorsPerArea] = deal(cell(size(ClassesForCombsAll)));
for i1 = 1:size(ClassesForCombsAll, 2)
    [Class4CombsToPlot{i1}, Class4CombsColorsToPlot{i1}] = deal(cell(size(IndToPlot)));
    [Class4CombsCatPerAreaToPlot{i1}, Class4CombsUniquePerArea{i1}, Class4CombsIndUnique{i1}, ...
        Class4CombsIndPerArea{i1}, Class4CombsColorsPerArea{i1}] = deal(cell(1, length(AreaToPlot)));
    for i2 = 1:length(AreaToPlot)
        Class4CombsToPlot{i1}(i2,:) = cellfun(@(x,y) x(y), ClassesForCombsAll{1,i1}{:}, IndToPlot(i2,:), 'UniformOutput',false);
    
        Class4CombsColorsToPlot{i1}(i2,:) = cellfun(@(x,y) x(y), ClassesForCombsColorsAll{1,i1}{:}, IndToPlot(i2,:), 'UniformOutput',false);
    
        Class4CombsCatPerAreaToPlot{i1}{i2} = cat(1, Class4CombsToPlot{i1}{i2,:});
    
        Class4CombsColorsPerArea{i1}{i2} = cell2mat(cat(1, Class4CombsColorsToPlot{i1}{i2,:}));
    
        [Class4CombsUniquePerArea{i1}{i2}, Class4CombsIndUnique{i1}{i2}, ...
                Class4CombsIndPerArea{i1}{i2}] = unique(Class4CombsCatPerAreaToPlot{i1}{i2});
    end
end
% clear('ClassesForCombsAll')

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
        ClassesToUse  = {CombsUniquePerArea};
        % ClassIndToUse = {CombsIndPerArea};
        ClassInd4Uniq = {CombsIndUnique};
        ClassesColors = {CombsColorsPerArea};
        ClassesTitles = {InfoType};

    case 'HRUs'
        ClassesToUse  = {HRUsUniquePerArea};
        % ClassIndToUse = {HRUsIndPerArea};
        ClassInd4Uniq = {HRUsIndUnique};
        ClassesColors = {HRUsColorsPerArea};
        ClassesTitles = {InfoType};

    case 'ClassesCombs'
        ClassesToUse  = Class4CombsUniquePerArea;
        % ClassIndToUse = Class4CombsIndPerArea;
        ClassInd4Uniq = Class4CombsIndUnique;
        ClassesColors = Class4CombsColorsPerArea;
        ClassesTitles = ClassesForCombsAll.Properties.VariableNames;
end

%% Plot
for i1 = 1:length(AreaToPlot)
    ProgressBar.Message = ['Plotting fig. n. ',num2str(i1),'...'];

    if strcmp(AreaType, 'Study Area')
        filename_curr = [InfoType,' for Study Area'];
        
    elseif strcmp(AreaType, 'Stable and Unstable')
        filename_curr = [InfoType,' for Area n-',num2str(i1)];
        filename_leg  = [InfoType,' color legend for Area n-',num2str(i1)];

        ExtentNewSA  = area(AreaToPlot(i1));
        NewRatioRef  = ExtentNewSA/ExtentStudyArea;
        PixelSize    = 0.6*PixelSizeEnt/NewRatioRef;
        DetPixelSize = 0.7*PixelSize;
    end

    fig_curr = figure(i1);
    set(fig_curr, 'Visible','off')
    PosFigCurr = get(fig_curr, 'Position');
    GirdSubPlots = [1, length(ClassesColors)];
    PosFigCurr(3) = PosFigCurr(3)*length(ClassesColors);
    set(fig_curr, 'Position',PosFigCurr);

    for i2 = 1:length(ClassesColors)
        ax_curr = subplot(GirdSubPlots(1),GirdSubPlots(2),i2, 'Parent',fig_curr);
        hold(ax_curr,'on');
    
        hclasses = scatter(xLongCatPerAreaToPlot{i1}, yLatCatPerAreaToPlot{i1}, PixelSize, ClassesColors{i2}{i1}, ...
                                            'Filled', 'Marker','s', 'Parent',ax_curr);

        plot(AreaToPlot(i1), 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_curr)
    
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
            title([ClassesTitles{i2},' for ',AreaType], 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize)
        elseif strcmp(AreaType, 'Stable and Unstable')
            title([ClassesTitles{i2},' for ',AreaType,' areas n. ',num2str(i1)], 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize)
        end
    
        set(ax_curr, 'visible','off') % To hide axis (but it will hide also titles)
        set(findall(ax_curr, 'type', 'text'), 'visible', 'on') % To show again titles
    end

    % Showing plot and saving...
    ProgressBar.Message = ['Saving fig. n. ',num2str(i1),'...'];
    if ShowPlots
        set(fig_curr, 'visible','on');
        pause
    end

    exportgraphics(fig_curr, [fold_fig_curr,sl,filename_curr,'.png'], 'Resolution',ExportRes);
    close(fig_curr)

    %% Legend plot
    if strcmp(AreaType, 'Stable and Unstable')
        fig_leg = figure(i1+length(AreaToPlot));
        set(fig_leg, 'Visible','off')
        PosFigLeg = get(fig_leg, 'Position');
        PosFigLeg(3) = int64(PosFigLeg(3)*max(cellfun(@(x) length(x{i1}), ClassesToUse))/35)*length(ClassesColors);
        % PosFigLeg(4) = PosFigLeg(4)*length(ClassesColors);
        set(fig_leg, 'Position',PosFigLeg);

        for i2 = 1:length(ClassesColors)
            ax_leg = subplot(GirdSubPlots(1),GirdSubPlots(2),i2, 'Parent',fig_leg);
            hold(ax_leg,'on');
    
            ColorsLabels = string(strrep(ClassesToUse{i2}{i1}, '_', '-'));
            ColorsUnique = reshape(ClassesColors{i2}{i1}(ClassInd4Uniq{i2}{i1},:), [1, length(ColorsLabels), 3]);
            imagesc(ax_leg, ColorsUnique);
    
            EdgsX = repmat((0:length(ColorsLabels))+0.5, 1+1,1);
            EdgsY = repmat((0:1)+0.5, length(ColorsLabels)+1,1).';
            plot(ax_leg, EdgsX  , EdgsY  , 'k') % Vertical lines of grid
            plot(ax_leg, EdgsX.', EdgsY.', 'k') % Horizontal lines of grid
    
            box on
    
            set(ax_leg, 'XAxisLocation','top')
            set(ax_leg, 'YAxisLocation','left')
    
            xticks(ax_leg, 1:length(ColorsLabels))
            yticks(ax_leg, 1)
            
            xticklabels(ColorsLabels)
            yticklabels(' ')
            
            xtickangle(ax_leg, 90)
            
            xlim(ax_leg, [0.5, length(ColorsLabels)+0.5])
            ylim(ax_leg, [0.5, 1+0.5])
    
            ylabel([ClassesTitles{i2},' color legend'])
            
            daspect([1.25, 1, 1])
        end

        % Saving legend...
        ProgressBar.Message = ['Saving legend fig. n. ',num2str(i1),'...'];
        exportgraphics(fig_leg, [fold_fig_curr,sl,filename_leg,'.png'], 'Resolution',ExportRes);
        close(fig_leg)
    end
end

close(ProgressBar)