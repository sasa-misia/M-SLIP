function [ColorsGrid, xGrid, yGrid, RGrid] = readortophoto(PathTxtURLs, LonLimits, LatLimits, Options)
% Create a ortophoto grid
%   
% Outputs:
%   [ColorsGrid, xGrid, yGrid, RGrid] : matrix of colors, matrix of longitude
%   values, matrix of latitude values, georeference object
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
%   
% Optional arguments:
%   - 'Resolution', numeric: output image resolution

%% Check inputs
arguments
    PathTxtURLs (1,:) char
    LonLimits (:,:) double {mustBeVector}
    LatLimits (:,:) double {mustBeVector}
    Options.Resolution (1,1) double = 2048
end

OutRes = Options.Resolution;

if OutRes > 8192; error('Please select a lower resolution!'); end

%% Core
UrFlEx = exist(PathTxtURLs, 'file');
if (UrFlEx)
    FileID = fopen(PathTxtURLs,'r');
    UrlMaps = cell(1, 12);
    for i1 = 1:numel(UrlMaps)
        TmpLne = fgetl(FileID);
        if TmpLne == -1; break; end
        UrlMaps{i1} = TmpLne;
    end
    fclose(FileID);
    EmptyInd = cellfun(@isempty, UrlMaps);
    UrlMaps(EmptyInd) = [];

    if numel(UrlMaps) > 1
        UrlMap = char(listdlg2('Ortophoto source:', UrlMaps));
    elseif isscalar(UrlMaps)
        UrlMap = char(UrlMaps);
    else
        UrlMap = '';
    end
end

if not(UrFlEx) || isempty(UrlMap)
    UrlMap = char(inputdlg2({'Enter WMS Url:'}));
end

InfLyr = wmsinfo(UrlMap);
LyrNms = {InfLyr.Layer(:).LayerName};
IndLyr = 1;
if numel(LyrNms) > 1
    IndLyr = listdlg2('Layer to use:', LyrNms, 'OutType','NumInd');
end
OrthoLyr = InfLyr.Layer(IndLyr);

yLatMean = mean(LatLimits);
dyMetLat = deg2rad(diff(LatLimits))*earthRadius; % diff of lat in meters
dxMetLon = acos(cosd(diff(LonLimits))*cosd(yLatMean)^2 + sind(yLatMean)^2)*earthRadius; % diff of lon in meters
RtLatLon = dyMetLat/dxMetLon;

if RtLatLon <= 1
    ImWidth = OutRes;
    ImHeigh = int64(ImWidth*RtLatLon);
elseif RtLatLon > 1
    ImHeigh = OutRes;
    ImWidth = int64(ImHeigh/RtLatLon);
end

[ColorsGrid, RGrid] = wmsread(OrthoLyr, 'LatLim',LatLimits, 'LonLim',LonLimits, ...
                                           'ImageHeight',ImHeigh, 'ImageWidth',ImWidth);

LatGridOrtho = RGrid.LatitudeLimits(2)-RGrid.CellExtentInLatitude/2 : ...
               -RGrid.CellExtentInLatitude : ...
               RGrid.LatitudeLimits(1)+RGrid.CellExtentInLatitude/2;

LonGridOrtho = RGrid.LongitudeLimits(1)+RGrid.CellExtentInLongitude/2 : ...
               RGrid.CellExtentInLongitude : ...
               RGrid.LongitudeLimits(2)-RGrid.CellExtentInLongitude/2;

[xGrid, yGrid] = meshgrid(LonGridOrtho, LatGridOrtho);

end