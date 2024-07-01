if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Processing DTM of Study Area', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Import and elaboration of data
sl = filesep;

tic
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon','StudyAreaPolygonExcluded','MaxExtremes','MinExtremes')

cd(fold_raw_dtm)
% Import tif and tfw file names
SepWrldFl = false;
switch DTMType
    case 0
        SepWrldFl = true;
        NameFile1 = FileName_DTM(contains(FileName_DTM,'tif'));
        NameFile2 = FileName_DTM(contains(FileName_DTM,'tfw'));

    case 1
        NameFile1 = FileName_DTM;

    case 2
        NameFile1 = FileName_DTM;
end

% Initializing of cells in for loop to increase speed
[xLongAll, yLatAll, ElevationAll, RasterInfoGeoAll, ...
    AspectAngleAll, SlopeAll, GradNAll, GradEAll, OriginalProjCRS] = deal(cell(1, length(NameFile1)));

ProgressBar.Indeterminate = 'off';
for i1 = 1:length(NameFile1)
    ProgressBar.Message = strcat("Analyzing DTM n. ",num2str(i1)," of ", num2str(length(NameFile1)));
    ProgressBar.Value   = i1/length(NameFile1);

    [RasterData, RasterRef] = readgeorast2([fold_raw_dtm,sl,char(NameFile1(i1))], 'SeparateWorldFile',SepWrldFl);
        
    if strcmp(RasterRef.CoordinateSystemType,"planar")
        OriginalProjCRS{i1} = RasterRef.ProjectedCRS;
        [xTBS,yTBS] = worldGrid(RasterRef);
        dX = RasterRef.CellExtentInWorldX;
        dY = RasterRef.CellExtentInWorldY;

    elseif strcmp(RasterRef.CoordinateSystemType,"geographic")
        [yTBS, xTBS] = geographicGrid(RasterRef);
        dX = acos(sind(yTBS(1,1))*sind(yTBS(1,2))+cosd(yTBS(1,1))*cosd(yTBS(1,2))*cosd(xTBS(1,2)-xTBS(1,1)))*earthRadius;
        dY = acos(sind(yTBS(1,1))*sind(yTBS(2,1))+cosd(yTBS(1,1))*cosd(yTBS(2,1))*cosd(xTBS(2,1)-xTBS(1,1)))*earthRadius;
    end

    if AnswerChangeDTMResolution == 1
        ScaleFactorX = int64(NewDx/dX);
        ScaleFactorY = int64(NewDy/dY);
    else
        ScaleFactorX = 1;
        ScaleFactorY = 1;
    end

    xScaled = xTBS(1:ScaleFactorX:end, 1:ScaleFactorY:end);
    yScaled = yTBS(1:ScaleFactorX:end, 1:ScaleFactorY:end);

    Elevation = max(RasterData(1:ScaleFactorX:end, 1:ScaleFactorY:end), 0); % Sometimes raster have big negative elevation values for sea
    clear('RasterData')
    
    if strcmp(RasterRef.CoordinateSystemType,"planar")
        [yLat   , xLong   ] = projinv(RasterRef.ProjectedCRS, xScaled, yScaled);
        [yLatExt, xLongExt] = projinv(RasterRef.ProjectedCRS, RasterRef.XWorldLimits, RasterRef.YWorldLimits);
        RastInfoGeo = georefcells(yLatExt, xLongExt, size(Elevation), 'ColumnsStartFrom','north'); % Remember to automatize this parameter (ColumnsStartFrom) depending on emisphere!
        RastInfoGeo.GeographicCRS = RasterRef.ProjectedCRS.GeographicCRS;

    elseif strcmp(RasterRef.CoordinateSystemType,"geographic")
        xLong = xScaled;
        yLat  = yScaled;
        RastInfoGeo  = RasterRef;
    end

    clear('xScaled', 'yScaled', 'RasterRef')

    xLongAll{i1} = xLong;
    clear('xLong')

    yLatAll{i1} = yLat;
    clear('yLat')

    [AspectDTM, SlopeDTM, GradNDTM, GradEDTM] = gradientm(Elevation, RastInfoGeo);
    
    ElevationAll{i1} = Elevation;
    clear('Elevation')

    RasterInfoGeoAll{i1} = RastInfoGeo;
    clear('RastInfoGeo')

    AspectAngleAll{i1} = AspectDTM;
    clear('AspectDTM')

    SlopeAll{i1} = SlopeDTM;
    clear('SlopeDTM')

    GradNAll{i1} = GradNDTM;
    clear('GradNDTM')

    GradEAll{i1} = GradEDTM;
    clear('GradEDTM')
end

NumEmptyCRS = sum(cellfun(@isempty, OriginalProjCRS));
if NumEmptyCRS == numel(OriginalProjCRS)
    clear('OriginalProjCRS');
elseif NumEmptyCRS < numel(OriginalProjCRS) && NumEmptyCRS > 0
    error(['Some of your files are in geographic coordinates and others ' ...
           'are in planar, this feature is not yet supported!'])
end

OriginallyProjected = false;
SameCRSForAll       = true;
if exist('OriginalProjCRS', 'var')
    OriginallyProjected  = true;
    NamesOriginalProjCRS = strings(1, length(OriginalProjCRS));
    for i1 = 1:length(OriginalProjCRS)
        NamesOriginalProjCRS(i1) = OriginalProjCRS{i1}.Name;
    end

    if numel(unique(NamesOriginalProjCRS)) == 1
        OriginalProjCRS = OriginalProjCRS{1};
    else
        SameCRSForAll = false;
        clear('OriginalProjCRS');
    end
end

ProgressBar.Indeterminate = 'on';
ProgressBar.Message = 'Indexing of points inside Study Area...';

[IndexDTMPointsInsideStudyArea, IndexDTMPointsExcludedInStudyArea] = deal(cell(1,length(xLongAll)));
for i2 = 1:length(xLongAll)
    [pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
    IndexDTMPointsInsideStudyArea{i2} = find(inpoly([xLongAll{i2}(:), yLatAll{i2}(:)], pp1, ee1)==1);

    if ~isempty(StudyAreaPolygonExcluded.Vertices)
        [pp2, ee2] = getnan2([StudyAreaPolygonExcluded.Vertices; nan, nan]);
        IndexDTMPointsExcludedInStudyArea{i2} = find(inpoly([xLongAll{i2}(:), yLatAll{i2}(:)], pp2, ee2)==1);
    end
end

%% Cleaning of DTM with no intersection (or only a single point)
ProgressBar.Message = 'Cleaning of DTMs...';
EmptyIndexDTMPointsInsideStudyArea = cellfun(@(x) numel(x)<=1,IndexDTMPointsInsideStudyArea);
NameFileIntersecated = NameFile1(~EmptyIndexDTMPointsInsideStudyArea);

IndexDTMPointsInsideStudyArea(EmptyIndexDTMPointsInsideStudyArea)      = [];
IndexDTMPointsExcludedInStudyArea(EmptyIndexDTMPointsInsideStudyArea)  = [];
xLongAll(EmptyIndexDTMPointsInsideStudyArea)                           = [];
yLatAll(EmptyIndexDTMPointsInsideStudyArea)                            = [];
ElevationAll(EmptyIndexDTMPointsInsideStudyArea)                       = [];
RasterInfoGeoAll(EmptyIndexDTMPointsInsideStudyArea)                   = [];
AspectAngleAll(EmptyIndexDTMPointsInsideStudyArea)                     = [];
SlopeAll(EmptyIndexDTMPointsInsideStudyArea)                           = [];
GradNAll(EmptyIndexDTMPointsInsideStudyArea)                           = [];
GradEAll(EmptyIndexDTMPointsInsideStudyArea)                           = [];
toc

%% Orthophoto
if OrthophotoAnswer
    ProgressBar.Message = 'Creation of Ortophoto...';

    LimLatMap = [MinExtremes(2), MaxExtremes(2)];
    LimLonMap = [MinExtremes(1), MaxExtremes(1)];

    [ZOrtho, xLongOrtho, yLatOrtho, ROrtho] = deal(cell(1,1));
    [ZOrtho{1}, xLongOrtho{1}, yLatOrtho{1}, ROrtho{1}] = readortophoto([fold_raw_sat,sl,'UrlMap.txt'], LimLonMap, LimLatMap, Resolution=8192);

    fig_ort = figure(1);
    axs_ort = axes('Parent',fig_ort);
    hold(axs_ort,'on');

    [pp, ee] = getnan2([StudyAreaPolygon.Vertices; nan nan]);
    [OrthoRGB, IndOrthoInStudyArea] = deal(cell(size(ZOrtho)));
    for i1 = 1:numel(ZOrtho)
        OrthoRGB{i1} = double(reshape(ZOrtho{i1}(:), [size(ZOrtho{i1},1)*size(ZOrtho{i1},2), 3]));
    
        IndOrthoInStudyArea{i1} = find(inpoly([xLongOrtho{i1}(:),yLatOrtho{i1}(:)], pp, ee)==1);

        fastscattergrid(ZOrtho{i1}, xLongOrtho{i1}, yLatOrtho{i1}, 'Mask',StudyAreaPolygon, 'Alpha',.7, 'Parent',axs_ort);
    end

    plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1);

    title('Ortophoto')
    fig_settings(fold0, 'AxisTick');
end

%% Plot to check the Study Area
ProgressBar.Message = 'Plotting to check...';

fig_check = figure(2);
ax_check  = axes(fig_check);
hold(ax_check,'on')

for i3 = 1:length(xLongAll)
    fastscatter(xLongAll{i3}(IndexDTMPointsInsideStudyArea{i3}), ...
                yLatAll{i3}(IndexDTMPointsInsideStudyArea{i3}), ...
                ElevationAll{i3}(IndexDTMPointsInsideStudyArea{i3}))
end

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1);

if ~isempty(StudyAreaPolygonExcluded.Vertices)
    plot(StudyAreaPolygonExcluded, 'FaceColor','r', 'FaceAlpha',0.5, 'LineWidth',0.5);
end

title('Study Area Polygon Check')
fig_settings(fold0, 'AxisTick');

%% Creation of empty parameter matrices
ProgressBar.Message = 'Creation of parameter matrices...';

SizeGridInCell  = cellfun(@size, xLongAll, 'UniformOutput',false);
CohesionAll     = cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
PhiAll          = cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
KtAll           = cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
AAll            = cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
nAll            = cellfun(@(x) NaN(x), SizeGridInCell, 'UniformOutput',false);
BetaStarAll     = cellfun(@cosd, SlopeAll, 'UniformOutput',false); % If Vegetation is not associated, betastar will depends on slope
RootCohesionAll = cellfun(@zeros, SizeGridInCell, 'UniformOutput',false); % If Vegetation is not associated, root cohesion will be zero


% Creatings string names of variables in cell arrays to save at the end
VariablesMorph       = {'ElevationAll', 'RasterInfoGeoAll', 'AspectAngleAll', 'SlopeAll', 'GradNAll', 'GradEAll', ...
                        'OriginallyProjected', 'SameCRSForAll'};
if OriginallyProjected && SameCRSForAll; VariablesMorph = [VariablesMorph, {'OriginalProjCRS'}]; end
VariablesGridCoord   = {'xLongAll', 'yLatAll', 'IndexDTMPointsInsideStudyArea', 'IndexDTMPointsExcludedInStudyArea'};
VariablesSoilPar     = {'CohesionAll', 'PhiAll', 'KtAll', 'AAll', 'nAll'};
VariablesVegPar      = {'RootCohesionAll', 'BetaStarAll'};
VariablesAnswerMorph = {'AnswerChangeDTMResolution', 'DTMType', 'FileName_DTM', 'AnswerChangeDTMResolution', ...
                        'OrthophotoAnswer', 'ScaleFactorX', 'ScaleFactorY', 'NameFileIntersecated'};
if AnswerChangeDTMResolution == 1; VariablesAnswerMorph = [VariablesAnswerMorph, {'NewDx', 'NewDy'}]; end
if OrthophotoAnswer; VariablesOrtho = {'ZOrtho', 'ROrtho', 'xLongOrtho', 'yLatOrtho', ...
                                       'OrthoRGB', 'IndOrthoInStudyArea'}; end

VegAttribution = false;
VariablesAnswerVeg = {'VegAttribution'};

%% Saving...
ProgressBar.Message = 'Saving...';

if OrthophotoAnswer; save([fold_var,sl,'Orthophoto.mat'], VariablesOrtho{:}); end
save([fold_var,sl,'UserMorph_Answers.mat'   ], VariablesAnswerMorph{:})
save([fold_var,sl,'UserVeg_Answers.mat'     ], VariablesAnswerVeg{:})
save([fold_var,sl,'MorphologyParameters.mat'], VariablesMorph{:})
save([fold_var,sl,'GridCoordinates'         ], VariablesGridCoord{:})
save([fold_var,sl,'SoilParameters.mat'      ], VariablesSoilPar{:})
save([fold_var,sl,'VegetationParameters.mat'], VariablesVegPar{:})

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version