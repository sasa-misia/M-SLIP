cd(fold_var)
load('GridCoordinates.mat');
load('StudyAreaVariables.mat');


xLongStudy=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

yLatStudy=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

Distance={};
if IndRoad
    cd(fold_raw_road)
    
    ShapeInfo_Road=shapeinfo(FileName_Road);
        
    [BoundingBoxX,BoundingBoxY]=projfwd(ShapeInfo_Road.CoordinateReferenceSystem,...
                        [MinExtremes(2) MaxExtremes(2)],[MinExtremes(1) MaxExtremes(1)]);
    
    RoadShape=shaperead(FileName_Road,'BoundingBox',...
                [BoundingBoxX(1) BoundingBoxY(1);BoundingBoxX(2) BoundingBoxY(2)]);
        
    
    RoadCell=struct2cell(RoadShape);
    RoadCell=RoadCell';
    
    [RoadCellLat,RoadCellLon]=cellfun(@(x,y) projinv(ShapeInfo_Road.CoordinateReferenceSystem,...
        [x],[y]),RoadCell(:,3),RoadCell(:,4),'UniformOutput',false);
    
    RoadPoly=cellfun(@(x,y) polyshape(x,y,'Simplify',false),...
        RoadCellLon,RoadCellLat,...
        'UniformOutput',false);  
    
    RoadPolyStudyArea=cellfun(@(x) intersect(x,StudyAreaPolygon),RoadPoly,...
        'UniformOutput',false);
    
    ExcludeEmptyIntersection=cellfun(@(x) ~isempty(x.Vertices),RoadPolyStudyArea);
    RoadPolyStudyArea=RoadPolyStudyArea(ExcludeEmptyIntersection);
    RoadPoly=RoadPoly(ExcludeEmptyIntersection);

    NameRoad=RoadCell(ExcludeEmptyIntersection,6);
    
    
    for i1=1:length(RoadPolyStudyArea)
        NearVertexRoad(i1,:)=cellfun(@(x,y) nearestvertex(RoadPoly{i1},x,y),...
            xLongStudy,yLatStudy,'UniformOutput',false);
    
        VertexPol=RoadPoly{i1}.Vertices;
        CoordNearVertex(i1,:)=cellfun(@(x) VertexPol(x,:),NearVertexRoad(i1,:),...
            'UniformOutput',false);
    
        DistanceNearVertex(i1,:)=cellfun(@(x1,x2,y2) deg2km(min(pdist2([x1(:,1) x1(:,2)],[x2 y2]),[],1)),...
            CoordNearVertex(i1,:),xLongStudy,yLatStudy,...
            'UniformOutput',false);
    end
        

    for i2=1:length(xLongStudy)
        MinDistance=min(cat(1,DistanceNearVertex{:,i2}),[],1);
        MinDistanceRoad{i2}=MinDistance';
    end

    Distance=[Distance,{'MinDistanceRoad','NameRoad'}];
end


if IndLandUse
    cd(fold_var)
    load('LandUsesVariables.mat')
    IndLU=cellfun(@(x) find(strcmp(AllLandUnique,x)),SelectedLU4Dist);

    PolygonsSelLandUse=LandUsePolygonsStudyArea(IndLU);

    NumRegions=arrayfun(@regions,PolygonsSelLandUse,'UniformOutput',false);
    [xLongCentroid,yLatCentroid]=cellfun(@centroid,NumRegions,'UniformOutput',false);

    CoordCentroid=cellfun(@(x,y) [x,y],xLongCentroid,yLatCentroid,...
        'UniformOutput',false);

    for i1=1:length(CoordCentroid)
        NearCentrLU(i1,:)=cellfun(@(x,y) deg2km(min(pdist2(CoordCentroid{i1},[x,y]),[],1)),...
            xLongStudy,yLatStudy,'UniformOutput',false);
    end

    for i2=1:length(xLongStudy)
        MinDistance=min(cat(1,NearCentrLU{:,i2}),[],1);
        MinDistanceLU{i2}=MinDistance';
    end
    Distance=[Distance,{'MinDistanceLU','SelectedLU4Dist'}];

end

cd(fold_var)
save('Distance.mat',Distance{:});
save('RoadPolygon.mat','RoadPoly')







