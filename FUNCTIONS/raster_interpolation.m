function InterpolatedRaster = raster_interpolation(xLongAll, yLatAll, FileNamePath, InterpMethod)

% Creation of a new cell array containing value interpolated for all original
% raster files with your new one.
%
% Syntax
%
%     InterpolatedRaster = raster_interpolation(xCoordAll, yCoordAll, FileNamePath, InterpMethod)

RasterInfo = georasterinfo(FileNamePath);
[RastValues, RastRef] = readgeoraster(FileNamePath, 'OutputType','native');

if isempty(RastRef)
    switch class(RasterInfo.CoordinateReferenceSystem)
        case 'geocrs'
            RangesInput = inputdlg( ["Latitude limits (no info in tif file):  "
                                     "Longitude limits (no info in tif file): "], '', 1, ...
                                    {'[-90, 90]'
                                     '[-180, 180]'} );
            LatLimits = str2num(RangesInput{1});
            LonLimits = str2num(RangesInput{2});
        
            RastRef = georefcells(LatLimits, LonLimits, size(RastValues), 'ColumnsStartFrom','north');

        case 'projcrs'
            RangesInput = inputdlg( ["x projected limits (no info in tif file):  "
                                     "y projected limits (no info in tif file): "], '', 1, ...
                                    {'[40000, 45000]'
                                     '[50000, 55000]'} );
            xLimits = str2num(RangesInput{1});
            yLimits = str2num(RangesInput{2});

            RastRef = maprefcells(xLimits, yLimits, size(RastValues), 'ColumnsStartFrom','north');
    end
end

if isfield(RastRef, 'ProjectedCRS') && isempty(RastRef.ProjectedCRS)
    EPSG = str2double(inputdlg({["Set DTM EPSG"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
    RastRef.ProjectedCRS = projcrs(EPSG);
end
    
if RastRef.CoordinateSystemType == "planar"
    [xPlanRaster, yPlanRaster] = worldGrid(RastRef);
    [yLatRaster,  xLongRaster] = projinv(RastRef.ProjectedCRS, xPlanRaster, yPlanRaster);
elseif RastRef.CoordinateSystemType == "geographic"
    [yLatRaster,  xLongRaster] = geographicGrid(RastRef);
end

if isempty(RasterInfo.MissingDataIndicator)
    NoDataValue = min(RastValues, [], 'all');
else
    NoDataValue = RasterInfo.MissingDataIndicator;
end

xLongMin = min(cellfun(@(x) min(x, [], 'all'), xLongAll));
xLongMax = max(cellfun(@(x) max(x, [], 'all'), xLongAll));
yLatMin  = min(cellfun(@(x) min(x, [], 'all'), yLatAll));
yLatMax  = max(cellfun(@(x) max(x, [], 'all'), yLatAll));

StudyBounds = polyshape([xLongMin, xLongMax, xLongMax, xLongMin], ...
                        [yLatMin , yLatMin , yLatMax , yLatMax ]);

[pp1, ee1]  = getnan2([StudyBounds.Vertices; nan, nan]);
IndOfPointsWithVal = find( (RastValues(:) ~= NoDataValue) & ...
                           (inpoly([xLongRaster(:), yLatRaster(:)], pp1,ee1)) );

InterpFunValues = scatteredInterpolant(xLongRaster(IndOfPointsWithVal), ...
                                       yLatRaster(IndOfPointsWithVal), ...
                                       double(RastValues(IndOfPointsWithVal)), ...
                                       InterpMethod);

InterpolatedRaster = cellfun(@(x) zeros(size(x)), xLongAll, 'UniformOutput',false);
for i1 = 1:length(xLongAll)
    InterpolatedRaster{i1}(:) = InterpFunValues(xLongAll{i1}(:), yLatAll{i1}(:));
end

end