function interpolatedRaster = raster_interpolation(xLonAll, yLatAll, filePath, interpMet, Options)

% Creation of a new cell array containing value interpolated for all original
% raster files with your new one.
%
% Syntax
%
%     interpolatedRaster = raster_interpolation(xCoordAll, yCoordAll, fileNamePath, interpMethod)

arguments
    xLonAll (1,:) cell
    yLatAll (1,:) cell
    filePath (1,:) char {mustBeFile}
    interpMet (1,:) char
    Options.replaceMiss (1,1) logical = true
    Options.val2Replace (1,1) double = 0
end

repMiss = Options.replaceMiss;
val2Rep = Options.val2Replace;

rastInfo = georasterinfo(filePath);
[rastVals, rastRef] = readgeoraster(filePath, 'OutputType','native');

if isempty(rastRef)
    switch class(rastInfo.CoordinateReferenceSystem)
        case 'geocrs'
            rngInps = inputdlg( ["Latitude limits (no info in tif file):  "
                                     "Longitude limits (no info in tif file): "], '', 1, ...
                                    {'[-90, 90]'
                                     '[-180, 180]'} );
            latLims = str2num(rngInps{1});
            lonLims = str2num(rngInps{2});
        
            rastRef = georefcells(latLims, lonLims, size(rastVals), 'ColumnsStartFrom','north');

        case 'projcrs'
            rngInps = inputdlg( ["x projected limits (no info in tif file):  "
                                     "y projected limits (no info in tif file): "], '', 1, ...
                                    {'[40000, 45000]'
                                     '[50000, 55000]'} );
            xLimits = str2num(rngInps{1});
            yLimits = str2num(rngInps{2});

            rastRef = maprefcells(xLimits, yLimits, size(rastVals), 'ColumnsStartFrom','north');
    end
end

if isfield(rastRef, 'ProjectedCRS') && isempty(rastRef.ProjectedCRS)
    EPSG = str2double(inputdlg({["Set DTM EPSG"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
    rastRef.ProjectedCRS = projcrs(EPSG);
end
    
if rastRef.CoordinateSystemType == "planar"
    [xPlnRaster, yPlnRaster] = worldGrid(rastRef);
    [yLatRaster, xLonRaster] = projinv(rastRef.ProjectedCRS, xPlnRaster, yPlnRaster);
    clear('xPlnRaster', 'yPlnRaster')

elseif rastRef.CoordinateSystemType == "geographic"
    [yLatRaster, xLonRaster] = geographicGrid(rastRef);
end

if isempty(rastInfo.MissingDataIndicator)
    noDataVal = min(rastVals, [], 'all'); % Sometimes it could be the biggest! Please find a solution
else
    noDataVal = rastInfo.MissingDataIndicator;
end

if repMiss
    rastVals(rastVals(:) == noDataVal) = val2Rep;
end

xLonMin = min(cellfun(@(x) min(x, [], 'all'), xLonAll));
xLonMax = max(cellfun(@(x) max(x, [], 'all'), xLonAll));
yLatMin = min(cellfun(@(x) min(x, [], 'all'), yLatAll));
yLatMax = max(cellfun(@(x) max(x, [], 'all'), yLatAll));

studyBounds = polyshape([xLonMin, xLonMax, xLonMax, xLonMin], ...
                        [yLatMin, yLatMin, yLatMax, yLatMax ]);

[pp1, ee1] = getnan2([studyBounds.Vertices; nan, nan]);
indPntsVal = find( (rastVals(:) ~= noDataVal) & ...
                   (inpoly([xLonRaster(:), yLatRaster(:)], pp1, ee1)) );

xRawRast = xLonRaster(indPntsVal);
yRawRast = yLatRaster(indPntsVal);
vRawRast = double(rastVals(indPntsVal));
clear('xLonRaster', 'yLatRaster', 'rastVals')

if isempty(indPntsVal) || numel(indPntsVal) < 3
    interpolatedRaster = cell(size(xLonAll));
else
    interpFunVals = scatteredInterpolant(xRawRast, yRawRast, vRawRast, interpMet);
    
    interpolatedRaster = cellfun(@(x) zeros(size(x)), xLonAll, 'UniformOutput',false);
    for i1 = 1:numel(xLonAll)
        interpolatedRaster{i1}(:) = interpFunVals(xLonAll{i1}(:), yLatAll{i1}(:));
    end
end

end