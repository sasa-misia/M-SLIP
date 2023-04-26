% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
cd(fold_var)
load('GridCoordinates.mat',      'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load('StudyAreaVariables.mat',   'MaxExtremes','MinExtremes','StudyAreaPolygon')
load('MorphologyParameters.mat', 'OriginallyProjected','SameCRSForAll')
cd(fold0)

%% Conversion in planar coordinates
ProgressBar.Message = "Conversion in planar coordinates...";

if OriginallyProjected && SameCRSForAll
    cd(fold_var)
    load('MorphologyParameters.mat', 'OriginalProjCRS')
    cd(fold0)

    ProjCRS = OriginalProjCRS;
else
    EPSG = str2double(inputdlg({["Set DTM EPSG (to calculate distances)"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
    ProjCRS = projcrs(EPSG);
end

[xPlanAll, yPlanAll] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    [xPlanAll{i1}, yPlanAll{i1}] = projfwd(ProjCRS, yLatAll{i1}, xLongAll{i1});
end

xPlanStudy = cellfun(@(x,y) x(y), xPlanAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yPlanStudy = cellfun(@(x,y) x(y), yPlanAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy  = cellfun(@(x,y) x(y), yLatAll,  IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

VariablesDistance = {};

%% Distances to roads (dedicated shapefile)
if FileRoadSelected
    %% Reading shapefile
    cd(fold_raw_road)
    ProgressBar.Message = "Reading shapefile...";
    ShapeInfo_Road = shapeinfo(FileName_Road);
    
    EB = 1000*180/pi/earthRadius; % ExtraBounding Lat/Lon increment for a respective 1000 m length, necessary due to conversion errors
    [BoundingBoxX, BoundingBoxY] = projfwd(ShapeInfo_Road.CoordinateReferenceSystem, ...
                                           [MinExtremes(2)-EB, MaxExtremes(2)+EB], ...
                                           [MinExtremes(1)-EB, MaxExtremes(1)+EB]);

    ReadShape_Road = shaperead(FileName_Road, 'BoundingBox',[BoundingBoxX(1) BoundingBoxY(1)
                                                             BoundingBoxX(2) BoundingBoxY(2)]);
    cd(fold0)
        
    %% Creation of polygons
    ProgressBar.Message = "Creation of road polygons...";
    RoadCell = struct2cell(ReadShape_Road);
    RoadCell = RoadCell';

    FieldOptions  = fieldnames(ReadShape_Road);
    FieldSelected = listdlg('PromptString',{'Select the field where are stored names of your roads: ',''}, ...
                            'ListString',FieldOptions, 'SelectionMode','single');
    drawnow % Remember to remove if in Standalone version
    figure(Fig) % Remember to remove if in Standalone version
    
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
    RoadNames                    = RoadCell(ExcludeEmptyIntersection,FieldSelected);
    RoadPolyStudyArea            = RoadPolyStudyArea(ExcludeEmptyIntersection);
    RoadPolyStudyAreaPlan        = RoadPolyStudyAreaPlan(ExcludeEmptyIntersection);
    RoadPolyStudyAreaUnified     = union([RoadPolyStudyArea{:}]);
    RoadPolyStudyAreaPlanUnified = union([RoadPolyStudyAreaPlan{:}]);

    %% Calculating distances
    ProgressBar.Message = "Calculating distances...";
    dX = abs(mean(diff(xPlanAll{1}, 1, 2), 'all'));
    dY = abs(mean(diff(yPlanAll{1}, 1, 1), 'all'));

    DistanceMethod = 1;
    if ceil(dX) ~= ceil(dY)
        DistanceChoice = uiconfirm(Fig, ['Distances in direction X are different from Y, ' ...
                                         'if you continue the process will be EXTREMELY slow. ' ...
                                         'Do you want to continue?'], 'Different distances X Y', ...
                                        'Options',{'Yes', 'No, I will use another DTM raster'}, 'DefaultOption',2);
        if strcmp(DistanceChoice,'Yes'); DistanceMethod = 2; else; return; end
    end

    ProgressBar.Indeterminate = 'off';
    if DistanceMethod == 1
        %% Distance transform of binary image
        Options  = {'MergedDTM', 'SeparateDTMs'};
        DistMode = uiconfirm(Fig, 'How do you want to define distances?', ...
                                  'Distances', 'Options',Options);
        SeparateRoadsMode = false; % CHOICE TO USER!
        switch DistMode
            case 'SeparateDTMs'
                if SeparateRoadsMode
                    RasterDistForEachRoad  = repmat(cellfun(@(x) zeros(size(x)), xPlanAll, 'UniformOutput',false), length(RoadPolyStudyArea), 1);
                    IndOfSingleRoad        = cell(length(RoadPolyStudyArea), size(xLongAll,2));
                    MinDistToSingleRoadsAll = cell(length(RoadPolyStudyArea), size(xLongAll,2));
                    for i1 = 1:length(RoadPolyStudyArea)
                        ProgressBar.Value = i1/length(RoadPolyStudyArea);
                        ProgressBar.Message = strcat("Calculating distances to road n. ", string(i1)," (of ", string(length(RoadPolyStudyArea)),")");
    
                        [pp1, ee1] = getnan2([RoadPolyStudyAreaPlan{i1}.Vertices; nan, nan]);
                        IndOfSingleRoad(i1,:) = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp1,ee1)), xPlanAll, yPlanAll, 'UniformOutput',false);
                        for i2 = 1:size(xLongAll,2)
                            RasterDistForEachRoad{i1,i2}(IndOfSingleRoad{i1}) = 1;
                            MinDistToSingleRoadsAll{i1,i2} = dX*bwdist(RasterDistForEachRoad{i1,i2});
                        end
                    end
                end
            
                [pp2, ee2] = getnan2([RoadPolyStudyAreaPlanUnified.Vertices; nan, nan]);
                IndexOfRoads = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp2,ee2)), xPlanAll, yPlanAll, 'UniformOutput',false);
                RasterDistForMergedRoad = cellfun(@(x) zeros(size(x)), xPlanAll, 'UniformOutput',false);
                MinDistToRoadAll = cell(1, length(xPlanAll));
                for i1 = 1:length(MinDistToRoadAll)
                    ProgressBar.Value = i1/length(MinDistToRoadAll);
                    ProgressBar.Message = strcat("Calculating distances to merged road for DTM n. ", string(i1)," of ", string(length(MinDistToRoadAll)));

                    RasterDistForMergedRoad{i1}(IndexOfRoads{i1}) = 1;
                    MinDistToRoadAll{i1} = dX*bwdist(RasterDistForMergedRoad{i1});
                end
                
            case 'MergedDTM'
                % Creation of a single merged raster
                xPlanMin = min(cellfun(@(x) min(x, [], 'all'), xPlanAll));
                xPlanMax = max(cellfun(@(x) max(x, [], 'all'), xPlanAll));
                yPlanMin = min(cellfun(@(x) min(x, [], 'all'), yPlanAll));
                yPlanMax = max(cellfun(@(x) max(x, [], 'all'), yPlanAll));
                [xPlanAllMerged, yPlanAllMerged] = meshgrid(xPlanMin:dX:xPlanMax, yPlanMax:-dY:yPlanMin);

                if SeparateRoadsMode
                    RasterDistForEachRoad  = repmat({zeros(size(xPlanAllMerged))}, length(RoadPolyStudyArea), 1);
                    IndOfSingleRoad        = cell(length(RoadPolyStudyArea), 1);
                    MinDistToSingleRoadsAll = repmat(cellfun(@(x) zeros(size(x)), xPlanAll, 'UniformOutput',false), length(RoadPolyStudyArea), 1);
                    for i1 = 1:length(RoadPolyStudyArea)
                        ProgressBar.Value = i1/length(RoadPolyStudyArea);
                        ProgressBar.Message = strcat("Calculating distances to road n. ", string(i1)," (of ", string(length(RoadPolyStudyArea)),")");
    
                        [pp1, ee1] = getnan2([RoadPolyStudyAreaPlan{i1}.Vertices; nan, nan]);
                        IndOfSingleRoad{i1} = find(inpoly([xPlanAllMerged(:),yPlanAllMerged(:)], pp1,ee1));
                        RasterDistForEachRoad{i1}(IndOfSingleRoad{i1}) = 1;
                        MinDistanceTemp = dX*bwdist(RasterDistForEachRoad{i1});
                        MinDistInterpModel = scatteredInterpolant(xPlanAllMerged(:), yPlanAllMerged(:), double(MinDistanceTemp(:)), 'natural');
                        for i2 = 1:size(xLongAll,2)
                            MinDistToSingleRoadsAll{i1,i2}(:) = MinDistInterpModel(xPlanAll{i2}(:), yPlanAll{i2}(:));
                        end
                    end
                end
            
                [pp2, ee2] = getnan2([RoadPolyStudyAreaPlanUnified.Vertices; nan, nan]);
                IndexOfRoads = find(inpoly([xPlanAllMerged(:),yPlanAllMerged(:)], pp2,ee2));
                RasterDistForMergedRoad = zeros(size(xPlanAllMerged));
                RasterDistForMergedRoad(IndexOfRoads) = 1;
                MinDistanceTemp = dX*bwdist(RasterDistForMergedRoad);
                MinDistInterpModel = scatteredInterpolant(xPlanAllMerged(:), yPlanAllMerged(:), double(MinDistanceTemp(:)), 'natural');
                MinDistToRoadAll = cellfun(@(x) zeros(size(x)), xPlanAll, 'UniformOutput',false);
                for i1 = 1:length(MinDistToRoadAll)
                    ProgressBar.Value = i1/length(MinDistToRoadAll);
                    ProgressBar.Message = strcat("Calculating distances to merged road for DTM n. ", string(i1)," of ", string(length(MinDistToRoadAll)));

                    MinDistToRoadAll{i1}(:) = MinDistInterpModel(xPlanAll{i1}(:), yPlanAll{i1}(:));
                end
        end

    elseif DistanceMethod == 2
        %% Distance from point to poly (extremely slow)
        MinDistToSingleRoadsAll = cell(length(RoadPolyStudyArea), size(xLongAll,2));
        for i1 = 1:length(RoadPolyStudyArea)
            ProgressBar.Value = i1/length(RoadPolyStudyArea);
            ProgressBar.Message = strcat("Calculating distances from road n. ", string(i1)," (of ", string(length(RoadPolyStudyArea)),")");
    
            if numel(RoadPolyStudyAreaPlan{i1}.Vertices(:,1)) < 8000
                MinDistToSingleRoadsAll(i1,:) = cellfun(@(x,y) p_poly_dist( x,y, ...
                                                                           RoadPolyStudyAreaPlan{i1}.Vertices(:,1), ...
                                                                           RoadPolyStudyAreaPlan{i1}.Vertices(:,2) ), ...
                                                            xPlanStudy, yPlanStudy, 'UniformOutput',false);
            else
                % This is necessary because otherwise you will get "Out of memory" error
                % RoadPartitioned = regions(RoadPolyStudyAreaPlan{i1});
                RoadPartitioned = divide_poly_grids(RoadPolyStudyAreaPlan{i1}, 5, 6);
                NumOfParts = 1;
                ElementsPerPart = cellfun(@(x) ceil(numel(x)/NumOfParts), xPlanStudy, 'UniformOutput',false);
                MinDistToSingleRoadsAllPartitioned = cell(NumOfParts, size(xLongAll,2));
                for i2 = 1:(NumOfParts)
                    if i2 < NumOfParts
                        xPlanStudyPartitioned = cellfun(@(x,y) x( ((i2-1)*y+1) : i2*y ), xPlanStudy, ElementsPerPart, 'UniformOutput',false);
                        yPlanStudyPartitioned = cellfun(@(x,y) x( ((i2-1)*y+1) : i2*y ), yPlanStudy, ElementsPerPart, 'UniformOutput',false);
                    else
                        xPlanStudyPartitioned = cellfun(@(x,y) x( ((i2-1)*y+1) : end ),  xPlanStudy, ElementsPerPart, 'UniformOutput',false);
                        yPlanStudyPartitioned = cellfun(@(x,y) x( ((i2-1)*y+1) : end ),  yPlanStudy, ElementsPerPart, 'UniformOutput',false);
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
    
        MinDistToRoadAll = cell(1, size(xLongAll,2));
        for i1 = 1:size(xLongAll,2)
            MinDistToRoadAll{i1} = min([MinDistToSingleRoadsAll{:,i1}], [], 2);
        end
    end
    ProgressBar.Indeterminate = 'on';

    %% Plot for check
    ProgressBar.Message = "Plot for check...";
    fig_check = figure(2);
    ax_check = axes(fig_check);
    hold(ax_check,'on')
    
    DistRoadsStudy = cellfun(@(x,y) x(y), MinDistToRoadAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    for i1 = 1:length(xLongAll)
        fastscatter(xLongStudy{i1}(:), yLatStudy{i1}(:), DistRoadsStudy{i1}(:))
    end
    colormap(ax_check, flipud(colormap('turbo')))
    
    plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5);

    plot(RoadPolyStudyAreaUnified, 'FaceColor','none', 'LineWidth',1);

    title('Distances to roads check plot')
    
    fig_settings(fold0, 'AxisTick');

    %% Variables to save
    VariablesDistance = [VariablesDistance, {'MinDistToRoadAll'}];
    if SeparateRoadsMode
        VariablesDistance = [VariablesDistance, {'MinDistToSingleRoadsAll'}];
    end
end

%% Distances to land uses selected
if FileLandUseSelected
    cd(fold_var)
    load('LandUsesVariables.mat', 'AllLandUnique','LandUsePolygonsStudyArea')
    cd(fold0)

    IndLU4Dist = cellfun(@(x) find(strcmp(AllLandUnique,x)), SelectedLU4Dist);

    PolygonsSelLandUse = LandUsePolygonsStudyArea(IndLU4Dist);

    NumRegions = arrayfun(@regions, PolygonsSelLandUse, 'UniformOutput',false);
    [xLongCentroid,yLatCentroid] = cellfun(@centroid, NumRegions, 'UniformOutput',false);

    CoordCentroid = cellfun(@(x,y) [x,y], xLongCentroid, yLatCentroid, 'UniformOutput',false);

    NearCentrLU = cell(length(CoordCentroid), size(xLongStudy,2));
    for i1 = 1:length(CoordCentroid)
        NearCentrLU(i1,:) = cellfun(@(x,y) deg2km(min(pdist2(CoordCentroid{i1}, [x,y], 'euclidean'), [], 1)),...
                                            xLongStudy, yLatStudy, 'UniformOutput',false);
    end

    MinDistanceLU = cell(1, length(xLongStudy));
    for i2 = 1:length(xLongStudy)
        MinDistance = min(cat(1,NearCentrLU{:,i2}),[],1);
        MinDistanceLU{i2} = MinDistance';
    end

    VariablesDistance = [VariablesDistance, {'MinDistanceLU', 'SelectedLU4Dist'}];
end

%% Saving...
ProgressBar.Message = "Saving...";
cd(fold_var)
VariablesPolygons = {'RoadPoly', 'RoadNames', 'RoadPolyStudyArea', 'RoadPolyStudyAreaUnified'};
save('Distances.mat', VariablesDistance{:})
save('PolygonsDistances.mat', VariablesPolygons{:})
cd(fold0)
close(ProgressBar) % Fig instead of ProgressBar if in standalone version