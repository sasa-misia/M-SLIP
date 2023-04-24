% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Processing DTM of Study Area', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Import and elaboration of data
tic
cd(fold_var)
load('StudyAreaVariables.mat', 'StudyAreaPolygon','StudyAreaPolygonExcluded')

cd(fold_raw_dtm)
% Import tif and tfw file names
switch DTMType
    case 0
        NameFile1 = FileName_DTM(contains(FileName_DTM,'tif'));
        NameFile2 = FileName_DTM(contains(FileName_DTM,'tfw'));
    case 1
        NameFile1 = FileName_DTM;
    case 2
        NameFile1 = FileName_DTM;
end

% Initializing of cells in for loop to increase speed
[xLongAll, yLatAll, ElevationAll, RasterInfoGeoAll, ...
    AspectAngleAll, SlopeAll, GradNAll, GradEAll, OriginalProjCRS] = deal(cell(1,length(NameFile1)));

ProgressBar.Indeterminate = 'off';
for i1 = 1:length(NameFile1)
    ProgressBar.Message = strcat("Analyzing DTM n. ",num2str(i1)," of ", num2str(length(NameFile1)));
    ProgressBar.Value = i1/length(NameFile1);

    switch DTMType
        case 0
            RasterData = imread(NameFile1(i1));
            RasterInfo = worldfileread(NameFile2(i1), 'planar', size(RasterData));
        case 1
            % [A,R] = readgeoraster(NameFile1(i1), 'OutputType','double');
            [RasterData,RasterInfo] = readgeoraster(NameFile1(i1), 'OutputType','native');
        case 2
            [RasterData,RasterInfo] = readgeoraster(NameFile1(i1), 'OutputType','double');
    end
        
    if strcmp(RasterInfo.CoordinateSystemType,"planar")
        if isempty(RasterInfo.ProjectedCRS) && i1==1
            EPSG = str2double(inputdlg({["Set DTM EPSG"
                                         "For Example:"
                                         "Sicily -> 32633"
                                         "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
            RasterInfo.ProjectedCRS = projcrs(EPSG);
        elseif isempty(RasterInfo.ProjectedCRS) && i1>1
            RasterInfo.ProjectedCRS = projcrs(EPSG);
        end

        OriginalProjCRS{i1} = RasterInfo.ProjectedCRS;
        [xTBS,yTBS] = worldGrid(RasterInfo);
        dX = RasterInfo.CellExtentInWorldX;
        dY = RasterInfo.CellExtentInWorldY;

    elseif strcmp(RasterInfo.CoordinateSystemType,"geographic")
        if isempty(RasterInfo.GeographicCRS)
            RasterInfo.GeographicCRS = geocrs(4326); % It will be applied the standard
        end

        [yTBS, xTBS] = geographicGrid(RasterInfo);
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
    
    if strcmp(RasterInfo.CoordinateSystemType,"planar")
        [yLat,xLong] = projinv(RasterInfo.ProjectedCRS, xScaled, yScaled);
        [yLatExt, xLongExt] = projinv(RasterInfo.ProjectedCRS, RasterInfo.XWorldLimits, RasterInfo.YWorldLimits);
        RastInfoGeo = georefcells(yLatExt, xLongExt, size(Elevation), 'ColumnsStartFrom','north'); % Remember to automatize this parameter (ColumnsStartFrom) depending on emisphere!
        RastInfoGeo.GeographicCRS = RasterInfo.ProjectedCRS.GeographicCRS;

    elseif strcmp(RasterInfo.CoordinateSystemType,"geographic")

        xLong = xScaled;
        yLat  = yScaled;
        RastInfoGeo  = RasterInfo;
    end

    clear('xScaled', 'yScaled', 'RasterInfo')

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
cd(fold0)

OriginallyProjected = false;
SameCRSForAll       = true;
if exist('OriginalProjCRS', 'var')
    OriginallyProjected = true;
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

    cd(fold_raw_sat)
    FileID = fopen('UrlMap.txt','r');
    UrlMap = fscanf(FileID,'%s');
    fclose(FileID);

    if isempty(UrlMap)
        Choice = inputdlg({'Enter WMS Url:'},'',1,{''});
        UrlMap = string(Choice{1});
    end

    ServerMap  = WebMapServer(UrlMap);
    Info       = wmsinfo(UrlMap);
    OrthoLayer = Info.Layer(1);
    
    LimMap    = cellfun(@(x) [x.LongitudeLimits; x.LatitudeLimits], RasterInfoGeoAll, 'UniformOutput',false);
    LimLatMap = cellfun(@(x) x(2,:), LimMap, 'UniformOutput',false);
    LimLonMap = cellfun(@(x) x(1,:), LimMap, 'UniformOutput',false);
    
    SamplesPerInterval = [km2deg(0.005), km2deg(0.005)] ;

    [ZOrtho, ROrtho] = cellfun(@(x,y) wmsread(OrthoLayer, 'LatLim',x, 'LonLim',y, ...
                                      'CellSize',SamplesPerInterval),...
                                      LimLatMap, LimLonMap, 'UniformOutput',false);

    fig_ortho = figure(1);
    ax_ortho  = axes('Parent',fig_ortho); 
    hold(ax_ortho,'on');

    % cellfun(@(x,y) geoshow(x,y),ZOrtho,ROrtho);

    LatGridOrtho = cellfun(@(x) x.LatitudeLimits(2)-x.CellExtentInLatitude/2 : ...
                           -x.CellExtentInLatitude : ...
                           x.LatitudeLimits(1)+x.CellExtentInLatitude/2, ...
                           ROrtho, 'UniformOutput',false);

    LongGridOrtho = cellfun(@(x) x.LongitudeLimits(1)+x.CellExtentInLongitude/2 : ...
                            x.CellExtentInLongitude : ...
                            x.LongitudeLimits(2)-x.CellExtentInLongitude/2, ...
                            ROrtho, 'UniformOutput',false);

    [xLongOrtho, yLatOrtho] = cellfun(@(x,y) meshgrid(x,y), ...
                                      LongGridOrtho, LatGridOrtho, ...
                                      'UniformOutput',false);

    OrthoRGB = cellfun(@(x) reshape(x(:), [size(x,1)*size(x,2), 3]), ...
                       ZOrtho, 'UniformOutput',false);

    IndexOrthoPointsInsideStudyArea = cell(1,length(xLongOrtho));
    for i2 = 1:length(xLongOrtho)
        [pp,ee] = getnan2([StudyAreaPolygon.Vertices; nan nan]);
        IndexOrthoPointsInsideStudyArea{i2} = find(inpoly([xLongOrtho{i2}(:),yLatOrtho{i2}(:)],pp,ee)==1);
    end

    for i = 1:length(xLongOrtho)
        scatter(xLongOrtho{i}(IndexOrthoPointsInsideStudyArea{i}), ...
                yLatOrtho{i}(IndexOrthoPointsInsideStudyArea{i}), ...
                2, double(OrthoRGB{i}(IndexOrthoPointsInsideStudyArea{i},:))./255, ... % Note that it is important to convert OrthoRGB in double!
                's', 'filled', 'MarkerEdgeColor','none') % , 'MarkerFaceAlpha',0.5)
        % hold on
    end
    daspect([1, 1, 1])
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
                                       'OrthoRGB', 'IndexOrthoPointsInsideStudyArea'}; end

VegAttribution = false;
VariablesAnswerVeg = {'VegAttribution'};

%% Saving...
ProgressBar.Message = 'Saving...';
cd(fold_var)
if OrthophotoAnswer; save('Orthophoto.mat', VariablesOrtho{:}); end
save('UserMorph_Answers.mat', VariablesAnswerMorph{:})
save('UserVeg_Answers.mat', VariablesAnswerVeg{:})
save('MorphologyParameters.mat', VariablesMorph{:})
save('GridCoordinates', VariablesGridCoord{:})
save('SoilParameters.mat', VariablesSoilPar{:})
save('VegetationParameters.mat', VariablesVegPar{:})
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version