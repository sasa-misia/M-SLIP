function [shapeInfo, shapeCont, shapeType, shapeUnit] = readshape2(filePath, Options)

arguments
    filePath (1,:) char {mustBeFile}
    Options.polyBound (1,1) polyshape = polyshape()
    Options.extraBound (1,1) double = 1000 % in meters!
end

polyBound  = Options.polyBound;
extraBound = Options.extraBound;

%% Reading
shapeInfo = shapeinfo(filePath);

if shapeInfo.NumFeatures == 0
    error('Shapefile is empty!')
end

switch shapeInfo.ShapeType
    case {'Polygon', 'PolyLine', 'Point', 'MultiPoint'}
        shapeType = shapeInfo.ShapeType;

    otherwise
        error('Shapefile must be of type Polygon, PolyLine, Point, or MultiPoint!')
end

if isempty(shapeInfo.CoordinateReferenceSystem)
    warning('CoordinateReferenceSystem of the shapefile is empty!')
    EPSG = str2double(inputdlg2({['DTM EPSG (Sicily -> 32633, ' ...
                                  'Emilia Romagna -> 25832):']}, 'DefInp',{'25832'}));
    shapeInfo.CoordinateReferenceSystem = projcrs(EPSG);
end

switch class(shapeInfo.CoordinateReferenceSystem)
    case 'geocrs'
        shapeUnit = shapeInfo.CoordinateReferenceSystem.AngleUnit;

    case 'projcrs'
        shapeUnit = shapeInfo.CoordinateReferenceSystem.LengthUnit;

    otherwise
        error('CRS not recognized!')
end

if isempty(polyBound.Vertices)
    shapeCont = shaperead(filePath);

else
    minPolyCrds = min(polyBound.Vertices);
    maxPolyCrds = max(polyBound.Vertices);
    
    [eBLon, eBLat] = meters2lonlat( extraBound, mean([minPolyCrds(2), maxPolyCrds(2)]) ); % extra bounds (Lat/Lon increments), necessary due to conversion errors
    if isa(shapeInfo.CoordinateReferenceSystem, 'geocrs')
        bBoxX = [minPolyCrds(1)-eBLon, maxPolyCrds(1)+eBLon];
        bBoxY = [minPolyCrds(2)-eBLat, maxPolyCrds(2)+eBLat];
    else
        [bBoxX, bBoxY] = projfwd(shapeInfo.CoordinateReferenceSystem, ...
                                       [minPolyCrds(2)-eBLat, maxPolyCrds(2)+eBLat], ...
                                       [minPolyCrds(1)-eBLon, maxPolyCrds(1)+eBLon]);
    end
    shapeCont = shaperead(filePath, 'BoundingBox',[bBoxX(1), bBoxY(1);
                                                   bBoxX(2), bBoxY(2)]);
end

if size(shapeCont, 1) < 1
    error('Shapefile is not empty but has no element in bounding box!')
end

end