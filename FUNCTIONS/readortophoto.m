function [ColorsGrid, xGrid, yGrid] = readortophoto(PathWithURLsTxt, LonLimits, LatLimits)
% Create a ortophoto grid
%   
% Outputs:
%   [ColorsGrid, xGrid, yGrid] : matrix of colors, matrix of longitude
%   values, matrix of latitude values
%   
% Required arguments:
%   - PathWithURLsTxt : is a char or a string, containing the path where is
%   stored the txt file that contains all the possible links that you would
%   like to use.
%   
%   - LonLimits : is a 1x2 array containing respectively the minimum and the 
%   maximum longitude values.
%   
%   - LatLimits : is a 1x2 array containing respectively the minimum and the 
%   maximum latitude values.

%% Core
sl     = filesep;
UrFlEx = exist(PathWithURLsTxt, 'file');
if (UrFlEx)
    FileID = fopen(PathWithURLsTxt,'r');
    UrlMaps = cell(1, 12);
    for i1 = 1:numel(UrlMaps)
        TmpLne = fgetl(FileID);
        if TmpLne == -1; break; end
        UrlMaps{i1} = TmpLne;
    end
    fclose(FileID);
    EmptyInd = cellfun(@isempty, UrlMaps);
    UrlMaps(EmptyInd) = [];

    UrlMap = char(listdlg2('Ortophoto source:', UrlMaps));
end

if not(UrFlEx) || isempty(UrlMap)
    UrlMap = char(inputdlg2({'Enter WMS Url:'}));
end

Info       = wmsinfo(UrlMap);
LayerNames = {Info.Layer(:).LayerName};
IndLyr     = 1;
if numel(LayerNames) > 1
    IndLyr = listdlg2('Layer to use:', LayerNames, 'OutType','NumInd');
end
OrthoLayer = Info.Layer(IndLyr);

yLatMean = mean(LatLimits);
dyMetLat = deg2rad(diff(LatLimits))*earthRadius; % diff of lat in meters
dxMetLon = acos(cosd(diff(LonLimits))*cosd(yLatMean)^2 + sind(yLatMean)^2)*earthRadius; % diff of lon in meters
RtLatLon = dyMetLat/dxMetLon;

if RtLatLon <= 1
    ImWidth  = 2048;
    ImHeight = int64(ImWidth*RtLatLon);
elseif RtLatLon > 1
    ImHeight = 2048;
    ImWidth  = int64(ImHeight/RtLatLon);
end

[ColorsGrid, ROrtho] = wmsread(OrthoLayer, 'LatLim',LatLimits, 'LonLim',LonLimits, ...
                                           'ImageHeight',ImHeight, 'ImageWidth',ImWidth);

LatGridOrtho = ROrtho.LatitudeLimits(2)-ROrtho.CellExtentInLatitude/2 : ...
               -ROrtho.CellExtentInLatitude : ...
               ROrtho.LatitudeLimits(1)+ROrtho.CellExtentInLatitude/2;

LonGridOrtho = ROrtho.LongitudeLimits(1)+ROrtho.CellExtentInLongitude/2 : ...
               ROrtho.CellExtentInLongitude : ...
               ROrtho.LongitudeLimits(2)-ROrtho.CellExtentInLongitude/2;

[xGrid, yGrid] = meshgrid(LonGridOrtho, LatGridOrtho);

end