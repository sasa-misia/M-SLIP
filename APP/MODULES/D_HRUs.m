% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data and initialization of AnalysisInformation
cd(fold_var)
load('GridCoordinates.mat',        'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load('StudyAreaVariables.mat',     'StudyAreaPolygon')
load('MorphologyParameters.mat',   'SlopeAll','OriginallyProjected','SameCRSForAll')
load('LandUsesVariables.mat',      'AllLandUnique','LandUsePolygonsStudyArea')
load('LithoPolygonsStudyArea.mat', 'LithoAllUnique','LithoPolygonsStudyArea')

TopSoilExist = false;
if exist('TopSoilPolygonsStudyArea.mat', 'file')
    load('TopSoilPolygonsStudyArea.mat', 'TopSoilAllUnique','TopSoilPolygonsStudyArea')
    TopSoilExist = true;
end
cd(fold0)

%% Preliminary operations
ProgressBar.Message = 'Preliminary operations...';

if TopSoilExist
    Options = {'TopSoil', 'SubSoil'};
    SoilInfoType = uiconfirm(Fig, 'What information do you want to use for soil classes', ...
                                  'Soil information', 'Options',Options);

    switch SoilInfoType
        case 'TopSoil'
            SoilAllUnique = TopSoilAllUnique;
            SoilPolygonsStudyArea = TopSoilPolygonsStudyArea;

        case 'SubSoil'
            SoilAllUnique = LithoAllUnique;
            SoilPolygonsStudyArea = LithoPolygonsStudyArea;
    end
    clear('LithoPolygonsStudyArea', 'TopSoilPolygonsStudyArea', 'LithoAllUnique', 'TopSoilAllUnique')
else
    SoilAllUnique = LithoAllUnique;
    SoilPolygonsStudyArea = LithoPolygonsStudyArea;

    clear('LithoPolygonsStudyArea', 'LithoAllUnique')
end

[pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
IndexDTMPointsOutsideStudyArea = cellfun(@(x,y) find(~inpoly([x(:),y(:)],pp1,ee1)==1), xLongAll, yLatAll, 'UniformOutput',false);

%% Import of classes of ML
ProgressBar.Message = 'Overwriting of classes with excel info...';

Options = {'As they were imported', 'Classes in excel'};
ClassesChoice = uiconfirm(Fig, 'How do you want to define classes?', ...
                               'Classes type', 'Options',Options, 'DefaultOption',1);
if strcmp(ClassesChoice, 'Classes in excel'); ExcelClasses = true; else; ExcelClasses = false; end

if ExcelClasses % Remember to add union of polygons
    cd(fold_user)
    Sheet_InfoClasses    = readcell('ClassesML.xlsx', 'Sheet','Help');
    Sheet_LithoClasses   = readcell('ClassesML.xlsx', 'Sheet','Litho');
    Sheet_TopSoilClasses = readcell('ClassesML.xlsx', 'Sheet','Top soil');
    Sheet_LandUseClasses = readcell('ClassesML.xlsx', 'Sheet','Land use');
    Sheet_VegClasses     = readcell('ClassesML.xlsx', 'Sheet','Veg');
    cd(fold0)

    NewAssLandUse = cell(size(AllLandUnique));
    for i1 = 1:length(AllLandUnique)
        NumOfClass        = Sheet_LandUseClasses{strcmp(AllLandUnique{i1}, Sheet_LandUseClasses), 2};
        NewAssLandUse(i1) = Sheet_InfoClasses(find(NumOfClass==[Sheet_InfoClasses{2:end,3}])+1, 2);
    end

    AllLandUniqueToUse = unique(NewAssLandUse);
    LandUsePolygonsStudyAreaToUse = repmat(polyshape, 1, length(AllLandUniqueToUse));
    for i1 = 1:length(AllLandUniqueToUse)
        IndToUnify = strcmp(AllLandUniqueToUse{i1}, NewAssLandUse);
        LandUsePolygonsStudyAreaToUse(i1) = union(LandUsePolygonsStudyArea(IndToUnify));
    end
else
    AllLandUniqueToUse = AllLandUnique;
    LandUsePolygonsStudyAreaToUse = LandUsePolygonsStudyArea;
end

%% Attributing slope class to each point of DTM
ProgressBar.Message = 'Creating slope classes...';

SlopeAllCat    = cellfun(@(x) x(:), SlopeAll, 'UniformOutput',false);
SlopeAllCatTot = cat(1, SlopeAllCat{:});

% SlopeValuesForClasses = (0:10:60)';
SlopeValuesForClasses = quantile(SlopeAllCatTot, 0 : 0.10 : 1);

LegInfoSep = '‒';
LegInfoSlope = [ strcat(string(round(SlopeValuesForClasses(1:end-1), 3, 'significant')), ...
                    LegInfoSep, ...
                    string(round(SlopeValuesForClasses(2:end), 3, 'significant')))];
LegSlope = strcat("SL", string(1 : (length(SlopeValuesForClasses)-1)));
InfoLegSlope = [LegSlope; LegInfoSlope];

SlopeClassesIndPoints = cell(length(SlopeValuesForClasses), size(xLongAll,2));
for i1 = 1:length(SlopeValuesForClasses)
    if i1 < length(SlopeValuesForClasses)
        SlopeClassesIndPoints(i1,:) = cellfun(@(x) find(x(:)>=SlopeValuesForClasses(i1) & x(:)<SlopeValuesForClasses(i1+1)),  SlopeAll, 'UniformOutput',false);
    else
        SlopeClassesIndPoints(i1,:) = cellfun(@(x) find(x(:)>=SlopeValuesForClasses(i1-1) & x(:)<=SlopeValuesForClasses(i1)), SlopeAll, 'UniformOutput',false);
    end
end

SlopeClassesAll = cellfun(@(x) repmat("No Class", size(x)), xLongAll, 'UniformOutput',false);
for i1 = 1:length(LegSlope)
    for i2 = 1:size(SlopeClassesIndPoints, 2)
        SlopeClassesAll{i2}(SlopeClassesIndPoints{i1,i2}) = LegSlope(i1);
        SlopeClassesAll{i2}(IndexDTMPointsOutsideStudyArea{i2}) = "Out";
    end
end

%% Attributing land use class to each point of DTM
ProgressBar.Message = 'Creating land use classes...';

LegLandUse = strcat("LU", string(1:length(AllLandUniqueToUse)));
InfoLegLandUse = [LegLandUse; AllLandUniqueToUse];

LandUseClassesIndPoints = cell(length(AllLandUniqueToUse), size(xLongAll,2));
for i1 = 1:length(LandUsePolygonsStudyAreaToUse)
    [pp2,ee2] = getnan2([LandUsePolygonsStudyAreaToUse(i1).Vertices; nan, nan]);
    LandUseClassesIndPoints(i1,:) = cellfun(@(x,y) find(inpoly([x(:),y(:)],pp2,ee2)==1), xLongAll, yLatAll, 'UniformOutput',false);
end

LandUseClassesAll = cellfun(@(x) repmat("No Class", size(x)), xLongAll, 'UniformOutput',false);
for i1 = 1:length(LegLandUse)
    for i2 = 1:size(LandUseClassesIndPoints, 2)
        LandUseClassesAll{i2}(LandUseClassesIndPoints{i1,i2}) = LegLandUse(i1);
        LandUseClassesAll{i2}(IndexDTMPointsOutsideStudyArea{i2}) = "Out";
    end
end

%% Attributing soil class to each point of DTM
ProgressBar.Message = 'Creating soil classes...';

LegSoil = strcat("SO", string(1:length(SoilAllUnique)));
InfoLegSoil = [LegSoil; SoilAllUnique];

SoilClassesIndPoints = cell(length(SoilAllUnique), size(xLongAll,2));
for i1 = 1:length(SoilPolygonsStudyArea)
    [pp3,ee3] = getnan2([SoilPolygonsStudyArea(i1).Vertices; nan, nan]);
    SoilClassesIndPoints(i1,:) = cellfun(@(x,y) find(inpoly([x(:),y(:)],pp3,ee3)==1), xLongAll, yLatAll, 'UniformOutput',false);
end

SoilClassesAll = cellfun(@(x) repmat("No Class", size(x)), xLongAll, 'UniformOutput',false);
for i1 = 1:length(LegSoil)
    for i2 = 1:size(SoilClassesIndPoints, 2)
        SoilClassesAll{i2}(SoilClassesIndPoints{i1,i2}) = LegSoil(i1);
        SoilClassesAll{i2}(IndexDTMPointsOutsideStudyArea{i2}) = "Out";
    end
end

%% Creation of combinations (clusterized)
ProgressBar.Message = 'Defining clusters for combinations...';

CombinationsAll = cellfun(@(x,y,z) strcat(x,"_",y,"_",z), SlopeClassesAll, SoilClassesAll, LandUseClassesAll, 'UniformOutput',false);
for i1 = 1:length(CombinationsAll)
    CombinationsAll{i1}(IndexDTMPointsOutsideStudyArea{i1}) = "Out";
end
CombinationsStudyArea = cellfun(@(x,y) x(y), CombinationsAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

CombsStudyAreaUnique = cellfun(@(x) unique(x), CombinationsStudyArea, 'UniformOutput',false);
CombsStudyAreaUnique = cat(1, CombsStudyAreaUnique{:});
CombsStudyAreaUnique = unique(CombsStudyAreaUnique);

if OriginallyProjected && SameCRSForAll
    cd(fold_var)
    load('MorphologyParameters.mat', 'OriginalProjCRS')
    cd(fold0)

    ProjCRS = OriginalProjCRS;
else
    EPSG = str2double(inputdlg({["Set DTM EPSG (to calculate clusters)"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
    ProjCRS = projcrs(EPSG);
end

[xPlanAll, yPlanAll] = cellfun(@(x,y) projfwd(ProjCRS, y, x), xLongAll, yLatAll, 'UniformOutput',false);

xLongTotCat = cellfun(@(x) x(:), xLongAll, 'UniformOutput',false);
xLongTotCat = cat(1, xLongTotCat{:});
yLatTotCat  = cellfun(@(x) x(:), yLatAll,  'UniformOutput',false);
yLatTotCat  = cat(1, yLatTotCat{:});

xPlanTotCat = cellfun(@(x) x(:), xPlanAll, 'UniformOutput',false);
xPlanTotCat = cat(1, xPlanTotCat{:});
yPlanTotCat = cellfun(@(x) x(:), yPlanAll, 'UniformOutput',false);
yPlanTotCat = cat(1, yPlanTotCat{:});
CombsTotCat = cellfun(@(x) x(:), CombinationsAll, 'UniformOutput',false);
CombsTotCat = cat(1, CombsTotCat{:});

ProgressBar.Indeterminate = 'off';
for i1 = 1:length(CombsStudyAreaUnique)
    ProgressBar.Value = i1/length(CombsStudyAreaUnique);
    ProgressBar.Message = ['Clusterizing class n. ', num2str(i1),' of ', num2str(length(CombsStudyAreaUnique))];

    IndPointsWithComb = find(CombsStudyAreaUnique(i1) == CombsTotCat); % Indices referred to the concatenate vector!
    
    dLat  = abs(yLatAll{1}(1)-yLatAll{1}(4)); % 4 points of distance!
    dYmin = deg2rad(dLat)*earthRadius; % This will be the radius constructed around every point to create clusters. +1 for an extra boundary
    MinPointsForEachCluster = 1; % CHOICE TO USER!
    ClustersCombs = dbscan([xPlanTotCat(IndPointsWithComb), yPlanTotCat(IndPointsWithComb)], dYmin, MinPointsForEachCluster); % Coordinates, min dist, min n. of point for each core point
    
    CombsTotCat(IndPointsWithComb) = strcat(CombsTotCat(IndPointsWithComb), '_C', string(ClustersCombs));
end
ProgressBar.Indeterminate = 'on';

%% Reshaping of combinations
IndStart = 0;
HRUsAll = cellfun(@(x) strings(size(x)), xLongAll, 'UniformOutput',false);
for i1 = 1:length(HRUsAll)
    IndEnd = IndStart + numel(HRUsAll{1});
    HRUsAll{i1}(:) = CombsTotCat(IndStart+1 : IndEnd);
    HRUsAll{i1}(IndexDTMPointsOutsideStudyArea{i1}) = "Out";
    IndStart = IndEnd;
end

HRUsStudyArea = cellfun(@(x,y) x(y), HRUsAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

HRUsStudyAreaUnique = cellfun(@(x) unique(x), HRUsStudyArea, 'UniformOutput',false);
HRUsStudyAreaUnique = cat(1, HRUsStudyAreaUnique{:});
HRUsStudyAreaUnique = unique(HRUsStudyAreaUnique);

%% Creation of polygons (TO CONTINUE, You want polyshapes instead of alphashapes)
PolyCreation = false; % CHOICE TO USER!
if PolyCreation
    ProgressBar.Indeterminate = 'off';
    AlphaPolyOfClass = cell(1, length(CombsStudyAreaUnique));
    for i1 = 1:length(CombsStudyAreaUnique)
        ProgressBar.Value = i1/length(CombsStudyAreaUnique);
        ProgressBar.Message = ['Creation of polygon (comb.) n. ', num2str(i1),' of ', num2str(length(CombsStudyAreaUnique))];
    
        IndPointsInClass = find(contains(CombsTotCat, CombsStudyAreaUnique(i1)));
        AlphaPolyOfClass{i1} = alphaShape(xLongTotCat(IndPointsInClass), yLatTotCat(IndPointsInClass), dLat/2, 'HoleThreshold',dLat);
    end
    
    AlphaPolyOfHRU = cell(1, length(HRUsStudyAreaUnique));
    for i1 = 1:length(HRUsStudyAreaUnique)
        ProgressBar.Value = i1/length(HRUsStudyAreaUnique);
        ProgressBar.Message = ['Creation of polygon (HRU) n. ', num2str(i1),' of ', num2str(length(HRUsStudyAreaUnique))];
    
        IndPointsInHRU = find(CombsTotCat == HRUsStudyAreaUnique(i1));
        AlphaPolyOfHRU{i1} = alphaShape(xLongTotCat(IndPointsInHRU), yLatTotCat(IndPointsInHRU), dLat/2, 'HoleThreshold',dLat);
    end
    ProgressBar.Indeterminate = 'on';
end

%% Plot for check
ProgressBar.Message = 'Plotting to check...';

IndClassSelected = listdlg('PromptString',{'Select the class you want to plot:',''}, ...
                           'ListString',CombsStudyAreaUnique, 'SelectionMode','multiple');

IndPointsInClass = find(contains(CombsTotCat, CombsStudyAreaUnique(IndClassSelected)));

[NameOfClassClust, IndForUniqueClassClust, IndForClassClust] = unique(CombsTotCat(IndPointsInClass));

ColorsUnique     = arrayfun(@(x) rand(1, 3), NameOfClassClust, 'UniformOutput',false);
ColorsForScatter = cell2mat(ColorsUnique(IndForClassClust));

fig_check = figure(1);
ax_check  = axes(fig_check);
hold(ax_check,'on')
title('HRU Classes')

PlotLegend = arrayfun(@(x, y, i) scatter(x, y, 6, ColorsForScatter(i,:), 'filled', 'Marker','o', 'MarkerFaceAlpha',0.7, 'Parent',ax_check), ...
                                    xLongTotCat(IndPointsInClass(IndForUniqueClassClust)), ...
                                    yLatTotCat(IndPointsInClass(IndForUniqueClassClust)), ...
                                    IndForUniqueClassClust);

PlotClusters = scatter(xLongTotCat(IndPointsInClass), yLatTotCat(IndPointsInClass), 6, ColorsForScatter, ...
                                        'filled', 'Marker','o', 'MarkerFaceAlpha',0.7, 'Parent',ax_check);

plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1.5)

fig_settings(fold0, 'AxisTick');

if numel(PlotLegend) <= 18
    leg_check = legend(PlotLegend, ...
                       string(strrep(NameOfClassClust, '_', ' ')), ...
                       'NumColumns',3, ...
                       'Fontsize',5, ...
                       'Location','southoutside', ...
                       'Box','off');
end

%% Saving...
ProgressBar.Message = 'Saving...';
cd(fold_var)
VariablesHRUs = {'HRUsAll', 'CombinationsAll', 'InfoLegSlope', 'InfoLegLandUse', 'InfoLegSoil', 'HRUsStudyAreaUnique', 'CombsStudyAreaUnique'};
save('HRUs.mat', VariablesHRUs{:});
cd(fold0)

close(ProgressBar)