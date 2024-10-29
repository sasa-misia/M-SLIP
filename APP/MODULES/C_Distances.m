if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'   ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'StudyAreaVariables.mat'], 'MaxExtremes','MinExtremes','StudyAreaPolygon')

ProjCRS = load_prjcrs(fold_var);

%% Conversion in planar coordinates
ProgressBar.Message = 'Conversion in planar coordinates...';

[xPlanAll, yPlanAll] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    [xPlanAll{i1}, yPlanAll{i1}] = projfwd(ProjCRS, yLatAll{i1}, xLongAll{i1});
end

xPlnStudy = cellfun(@(x,y) x(y), xPlanAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yPlnStudy = cellfun(@(x,y) x(y), yPlanAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

xLonStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy = cellfun(@(x,y) x(y), yLatAll , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

VarDstnc = {};

%% Distances to roads (dedicated shapefile)
if FileRoadSelected
    %% Reading shapefile
    ProgressBar.Message = 'Reading shapefile...';
    ShapeInfo_Road = shapeinfo(strcat(fold_raw_road,sl,FileName_Road));
    
    [EBLon, EBLat] = meters2lonlat( 1000, mean([MinExtremes(2), MaxExtremes(2)]) ); % ExtraBounding Lat/Lon increment for a respective 1000 m length, necessary due to conversion errors
    [BoundingBoxX, BoundingBoxY] = projfwd(ShapeInfo_Road.CoordinateReferenceSystem, ...
                                           [MinExtremes(2)-EBLat, MaxExtremes(2)+EBLat], ...
                                           [MinExtremes(1)-EBLon, MaxExtremes(1)+EBLon]);

    ReadShape_Road = shaperead(strcat(fold_raw_road,sl,FileName_Road), ...
                                        'BoundingBox',[BoundingBoxX(1) BoundingBoxY(1);
                                                       BoundingBoxX(2) BoundingBoxY(2)]);
        
    %% Creation of polygons
    ProgressBar.Message = 'Creation of road polygons...';
    RoadCell = struct2cell(ReadShape_Road);
    RoadCell = RoadCell';

    FieldOptions = fieldnames(ReadShape_Road);
    FieldSlctInd = listdlg2({'Field with names of roads: '}, FieldOptions, 'OutType','NumInd');
    
    [RoadCellLat, RoadCellLon] = cellfun(@(x,y) projinv(ShapeInfo_Road.CoordinateReferenceSystem,x,y), ...
                                                    RoadCell(:,3), RoadCell(:,4), 'UniformOutput',false);

    [RoadCellX,   RoadCellY]   = cellfun(@(x,y) projfwd(ProjCRS,x,y), ...
                                                    RoadCellLat, RoadCellLon, 'UniformOutput',false);
    
    RoadPoly     = cellfun(@(x,y) polyshape(x,y, 'Simplify',false), RoadCellLon, RoadCellLat, 'UniformOutput',false);
    RoadPolyPlan = cellfun(@(x,y) polyshape(x,y, 'Simplify',false), RoadCellX,   RoadCellY,   'UniformOutput',false);
    
    RoadPolyStudyArea = cellfun(@(x) intersect(x,StudyAreaPolygon), RoadPoly, 'UniformOutput',false);

    RoadPolyStudyAreaPlan = RoadPolyStudyArea;
    for i1 = 1:length(RoadPolyStudyAreaPlan)
        [RoadPolyVertX, RoadPolyVertY] = ...
                projfwd(ProjCRS,RoadPolyStudyAreaPlan{i1}.Vertices(:,2),RoadPolyStudyAreaPlan{i1}.Vertices(:,1));

        RoadPolyStudyAreaPlan{i1}.Vertices = [RoadPolyVertX, RoadPolyVertY];
    end

    ExcludeEmptyIntersection = cellfun(@(x) ~isempty(x.Vertices), RoadPolyStudyArea);

    RoadPoly                     = RoadPoly(ExcludeEmptyIntersection);
    RoadNames                    = RoadCell(ExcludeEmptyIntersection, FieldSlctInd);
    RoadPolyStudyArea            = RoadPolyStudyArea(ExcludeEmptyIntersection);
    RoadPolyStudyAreaPlan        = RoadPolyStudyAreaPlan(ExcludeEmptyIntersection);
    RoadPolyStudyAreaUnified     = union([RoadPolyStudyArea{:}]);
    RoadPolyStudyAreaPlanUnified = union([RoadPolyStudyAreaPlan{:}]);

    %% Calculating distances
    ProgressBar.Message = 'Calculating distances...';
    dX = abs(mean(diff(xPlanAll{1}, 1, 2), 'all'));
    dY = abs(mean(diff(yPlanAll{1}, 1, 1), 'all'));

    DistMet = 1;
    if ceil(round(dX)) ~= ceil(round(dY))
        DistChc = uiconfirm(Fig, ['Distances in direction X are different from Y, ' ...
                                  'if you continue the process will be EXTREMELY slow. ' ...
                                  'Do you want to continue?'], 'Different distances X Y', ...
                                 'Options',{'Yes', 'No, I will use another DEM'}, 'DefaultOption',2);
        if strcmp(DistChc,'Yes'); DistMet = 2; else; return; end
    end

    ProgressBar.Indeterminate = 'off';
    if DistMet == 1
        %% Distance transform of binary image
        if numel(xPlanAll) > 1
            DistMode = uiconfirm(Fig, 'How do you want to define distances?', ...
                                      'Distances', 'Options',{'MergedDTM', 'SeparateDTMs'});
        else
            DistMode = 'SeparateDTMs';
        end
        SepRoadMode = false; % CHOICE TO USER!
        switch DistMode
            case 'SeparateDTMs'
                if SepRoadMode
                    RastDist2Road   = repmat(cellfun(@(x) zeros(size(x)), xPlanAll, 'UniformOutput',false), length(RoadPolyStudyArea), 1);
                    IndSingleRoad         = cell(length(RoadPolyStudyArea), size(xLongAll,2));
                    MinDistToSingleRoadsAll = cell(length(RoadPolyStudyArea), size(xLongAll,2));
                    for i1 = 1:length(RoadPolyStudyArea)
                        ProgressBar.Value = i1/length(RoadPolyStudyArea);
                        ProgressBar.Message = ['Calculating distances to road n. ',num2str(i1),' (of ',num2str(length(RoadPolyStudyArea)),')'];
    
                        [pp1, ee1] = getnan2([RoadPolyStudyAreaPlan{i1}.Vertices; nan, nan]);
                        IndSingleRoad(i1,:) = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp1,ee1)), xPlanAll, yPlanAll, 'UniformOutput',false);
                        for i2 = 1:size(xLongAll,2)
                            RastDist2Road{i1,i2}(IndSingleRoad{i1}) = 1;
                            MinDistToSingleRoadsAll{i1,i2} = dX*bwdist(RastDist2Road{i1,i2});
                        end
                    end
                end
            
                [pp2, ee2] = getnan2([RoadPolyStudyAreaPlanUnified.Vertices; nan, nan]);
                IndRoads = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp2,ee2)), xPlanAll, yPlanAll, 'UniformOutput',false);
                RstDst4MgRd = cellfun(@(x) zeros(size(x)), xPlanAll, 'UniformOutput',false);
                MnDst2RdAll = cell(1, length(xPlanAll));
                for i1 = 1:length(MnDst2RdAll)
                    ProgressBar.Value = i1/length(MnDst2RdAll);
                    ProgressBar.Message = ['Calculating distances to merged road for DTM n. ',num2str(i1),' of ', num2str(length(MnDst2RdAll))];

                    RstDst4MgRd{i1}(IndRoads{i1}) = 1;
                    MnDst2RdAll{i1} = dX*bwdist(RstDst4MgRd{i1});
                end
                
            case 'MergedDTM'
                % Creation of a single merged raster
                xPlanMin = min(cellfun(@(x) min(x, [], 'all'), xPlanAll));
                xPlanMax = max(cellfun(@(x) max(x, [], 'all'), xPlanAll));
                yPlanMin = min(cellfun(@(x) min(x, [], 'all'), yPlanAll));
                yPlanMax = max(cellfun(@(x) max(x, [], 'all'), yPlanAll));
                [xPlanAllMerged, yPlanAllMerged] = meshgrid(xPlanMin:dX:xPlanMax, yPlanMax:-dY:yPlanMin);

                if SepRoadMode
                    RastDist2Road = repmat({zeros(size(xPlanAllMerged))}, length(RoadPolyStudyArea), 1);
                    IndSingleRoad = cell(length(RoadPolyStudyArea), 1);
                    MinDistToSingleRoadsAll = repmat(cellfun(@(x) zeros(size(x)), xPlanAll, 'UniformOutput',false), length(RoadPolyStudyArea), 1);
                    for i1 = 1:length(RoadPolyStudyArea)
                        ProgressBar.Value = i1/length(RoadPolyStudyArea);
                        ProgressBar.Message = ['Calculating distances to road n. ',num2str(i1),' (of ',num2str(length(RoadPolyStudyArea)),')'];
    
                        [pp1, ee1] = getnan2([RoadPolyStudyAreaPlan{i1}.Vertices; nan, nan]);
                        IndSingleRoad{i1} = find(inpoly([xPlanAllMerged(:),yPlanAllMerged(:)], pp1,ee1));
                        RastDist2Road{i1}(IndSingleRoad{i1}) = 1;
                        MinDistTemp = dX*bwdist(RastDist2Road{i1});
                        MinDstItMdl = scatteredInterpolant(xPlanAllMerged(:), yPlanAllMerged(:), double(MinDistTemp(:)), 'natural');
                        for i2 = 1:size(xLongAll,2)
                            MinDistToSingleRoadsAll{i1,i2}(:) = MinDstItMdl(xPlanAll{i2}(:), yPlanAll{i2}(:));
                        end
                    end
                end
            
                [pp2, ee2] = getnan2([RoadPolyStudyAreaPlanUnified.Vertices; nan, nan]);
                IndRoads = find(inpoly([xPlanAllMerged(:),yPlanAllMerged(:)], pp2,ee2));
                RstDst4MgRd = zeros(size(xPlanAllMerged));
                RstDst4MgRd(IndRoads) = 1;
                MinDistTemp = dX*bwdist(RstDst4MgRd);
                MinDstItMdl = scatteredInterpolant(xPlanAllMerged(:), yPlanAllMerged(:), double(MinDistTemp(:)), 'natural');
                MnDst2RdAll = cellfun(@(x) zeros(size(x)), xPlanAll, 'UniformOutput',false);
                for i1 = 1:length(MnDst2RdAll)
                    ProgressBar.Value = i1/length(MnDst2RdAll);
                    ProgressBar.Message = ['Calculating distances to merged road for DTM n. ',num2str(i1),' of ',num2str(length(MnDst2RdAll))];

                    MnDst2RdAll{i1}(:) = MinDstItMdl(xPlanAll{i1}(:), yPlanAll{i1}(:));
                end
        end

    elseif DistMet == 2
        %% Distance from point to poly (extremely slow)
        MinDistToSingleRoadsAll = cell(length(RoadPolyStudyArea), size(xLongAll,2));
        for i1 = 1:length(RoadPolyStudyArea)
            ProgressBar.Value = i1/length(RoadPolyStudyArea);
            ProgressBar.Message = ['Calculating distances from road n. ',num2str(i1),' (of ',num2str(length(RoadPolyStudyArea)),')'];
    
            if numel(RoadPolyStudyAreaPlan{i1}.Vertices(:,1)) < 8000
                MinDistToSingleRoadsAll(i1,:) = cellfun(@(x,y) p_poly_dist( x,y, ...
                                                                           RoadPolyStudyAreaPlan{i1}.Vertices(:,1), ...
                                                                           RoadPolyStudyAreaPlan{i1}.Vertices(:,2) ), ...
                                                            xPlnStudy, yPlnStudy, 'UniformOutput',false);
            else
                % This is necessary because otherwise you will get "Out of memory" error
                % RoadPartitioned = regions(RoadPolyStudyAreaPlan{i1});
                RoadPartitioned = divide_poly_grids(RoadPolyStudyAreaPlan{i1}, 5, 6);
                NumOfParts = 1;
                ElementsPerPart = cellfun(@(x) ceil(numel(x)/NumOfParts), xPlnStudy, 'UniformOutput',false);
                MinDistToSingleRoadsAllPartitioned = cell(NumOfParts, size(xLongAll,2));
                for i2 = 1:(NumOfParts)
                    if i2 < NumOfParts
                        xPlanStudyPartitioned = cellfun(@(x,y) x( ((i2-1)*y+1) : i2*y ), xPlnStudy, ElementsPerPart, 'UniformOutput',false);
                        yPlanStudyPartitioned = cellfun(@(x,y) x( ((i2-1)*y+1) : i2*y ), yPlnStudy, ElementsPerPart, 'UniformOutput',false);
                    else
                        xPlanStudyPartitioned = cellfun(@(x,y) x( ((i2-1)*y+1) : end ),  xPlnStudy, ElementsPerPart, 'UniformOutput',false);
                        yPlanStudyPartitioned = cellfun(@(x,y) x( ((i2-1)*y+1) : end ),  yPlnStudy, ElementsPerPart, 'UniformOutput',false);
                    end
    
                    MinDistToSingleRoadsAllPartitionedTemp = cell(length(RoadPartitioned), size(xPlanStudyPartitioned,2));
                    for i3 = 1:length(RoadPartitioned)
                        MinDistToSingleRoadsAllPartitionedTemp(i3,:) = cellfun(@(x,y) p_poly_dist( x,y, ...
                                                                                                  RoadPartitioned(i3).Vertices(:,1), ...
                                                                                                  RoadPartitioned(i3).Vertices(:,2) ), ...
                                                                                   xPlanStudyPartitioned, yPlanStudyPartitioned, 'UniformOutput',false);
                    end
    
                    for i3 = 1:size(xLongAll,2)
                        MinDistToSingleRoadsAllPartitioned{i2,i3} = min([MinDistToSingleRoadsAllPartitionedTemp{:,i3}], [], 2);
                    end
                end
    
            end
        end
    
        MnDst2RdAll = cell(1, size(xLongAll,2));
        for i1 = 1:size(xLongAll,2)
            MnDst2RdAll{i1} = min([MinDistToSingleRoadsAll{:,i1}], [], 2);
        end
    end
    ProgressBar.Indeterminate = 'on';

    %% Plot for check
    ProgressBar.Message = 'Plot for check...';
    fig_check = figure(2);
    ax_check = axes(fig_check);
    hold(ax_check,'on')
    
    DistRoadsStudy = cellfun(@(x,y) x(y), MnDst2RdAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    for i1 = 1:length(xLongAll)
        fastscatter(xLonStudy{i1}(:), yLatStudy{i1}(:), DistRoadsStudy{i1}(:))
    end
    colormap(ax_check, flipud(colormap('turbo')))
    
    plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',ax_check);
    plot(RoadPolyStudyAreaUnified, 'FaceColor','none', 'LineWidth',1, 'Parent',ax_check);

    title('Distances to roads check plot')
    
    fig_settings(fold0, 'AxisTick');

    %% Variables to save
    VarDstnc = [VarDstnc, {'MinDistToRoadAll'}];
    if SepRoadMode
        VarDstnc = [VarDstnc, {'MinDistToSingleRoadsAll'}];
    end
end

%% Distances to land uses selected
if FileLandUseSelected
    load([fold_var,sl,'LandUsesVariables.mat'], 'AllLandUnique','LandUsePolygonsStudyArea')

    IndLU4Dist = cellfun(@(x) find(strcmp(AllLandUnique,x)), SelectedLU4Dist);

    PolygonsSelLandUse = LandUsePolygonsStudyArea(IndLU4Dist);

    NumRegions = arrayfun(@regions, PolygonsSelLandUse, 'UniformOutput',false);
    [xLongCentroid,yLatCentroid] = cellfun(@centroid, NumRegions, 'UniformOutput',false);

    CoordCentroid = cellfun(@(x,y) [x,y], xLongCentroid, yLatCentroid, 'UniformOutput',false);

    NearCentrLU = cell(length(CoordCentroid), size(xLonStudy,2));
    for i1 = 1:length(CoordCentroid)
        NearCentrLU(i1,:) = cellfun(@(x,y) deg2km(min(pdist2(CoordCentroid{i1}, [x,y], 'euclidean'), [], 1)),...
                                            xLonStudy, yLatStudy, 'UniformOutput',false);
    end

    MinDistanceLU = cell(1, length(xLonStudy));
    for i2 = 1:length(xLonStudy)
        MinDistance = min(cat(1,NearCentrLU{:,i2}),[],1);
        MinDistanceLU{i2} = MinDistance';
    end

    VarDstnc = [VarDstnc, {'MinDistanceLU', 'SelectedLU4Dist'}];
end

%% Saving...
ProgressBar.Message = 'Saving...';

VarPolys = {'RoadPoly', 'RoadNames', 'RoadPolyStudyArea', 'RoadPolyStudyAreaUnified'};
save([fold_var,sl,'Distances.mat'        ], VarDstnc{:})
save([fold_var,sl,'PolygonsDistances.mat'], VarPolys{:})

close(ProgressBar) % Fig instead of ProgressBar if in standalone version