function [] = merge_dems(PolyMask, LongRasters, LatRasters, ElevRasters, varargin)
% CREATE MERGED DEM
%   
% Outputs:
%  -
%   
% Required arguments:
%   Arguments MUST be in geographic coordinates!!!
%   
%   - PolyMask : is a polyshape containing the mask you want to apply. It
%   must be in geographic coordinates!
%   
%   - LongRasters : is the cell array containing in each cell the matrix grid 
%   with longitude values for each pixel...
%   
%   - LatRasters : is the cell array containing in each cell the matrix grid 
%   with latitude values for each pixel...
%   
%   - ElevRasters : is the cell array containing in each cell the matrix grid 
%   with elevation values for each pixel...
%   
% Optional arguments:
%   - 'DEMSize', numerical : is the size, in meters, that identify the
%   spacing of the grid. If no value is specified, it will be applied the
%   same spacing of the input DEMs.
%   
%   - 'Buffer', numerical : is the size, in meters, that identify the
%   buffer from the PolyMask. If no value is specified, then 80 m will be
%   take as default.
%   
%   - 'PlanEPSG', numerical : is the EPSG number that control the conversion 
%   of the mask polygon in planar coordinates (in order to apply the buffer).
%   If no value is specified, then 25832 will be applied.
%   
%   - 'ElevAttr', string/char : is to define the option based on which the
%   elevation grid will be build. The possible values are 'Opt1', 'Opt2',
%   'Opt3', and 'Opt4'. These options are respectively: 'Nearest point P2G', 
%   'Nearest point G2P', 'Nearest point G2P (red)', 'Interpolation'. If no
%   value is specified, then 'Opt4' (Interpolation) will be take as default.
%   
%   - 'SavePath', string/char : is to define the path where to save the
%   merged DEM. If no value is specified, then the current folder will be
%   selected.
%   
%   - 'Interp', string/char : is to define the type of interpolation that
%   you want with the Opt4 of ElevAttr. It can be 'linear', 'nearest', or 
%   'natural'. It is not necessary in case you do not have Opt4 as ElevAttr.
%   If no value is specified, then 'nearest' will be take as default.
%   
%   - 'OutCoords', string/char : is to define the type of output to use in
%   writing the merged DEM. It can be 'Geographic' or 'Planar'. If 'Planar'
%   is set, then it will be used the CRS defined in 'PlanEPSG'. If no value
%   is specified, then 'Geographic' will be take as default.
%   
%   - 'OutFormat', string/char : is to define the type of output you want
%   for the export files. It can be 'ASCII' or 'Tiff'. If no value is
%   specified, then 'Tiff' will be take as default.

%% Input Check
if not(iscell(LongRasters) && iscell(LatRasters) && iscell(ElevRasters))
    error('2nd, 3rd, and 4th inputs must be cell arrays!')
end

if not(isequal(size(LongRasters), size(LatRasters), size(ElevRasters)))
    error('2nd, 3rd, and 4th inputs must be have same dimensions!')
end

for i1 = 1:numel(ElevRasters)
    if not(isnumeric(LongRasters{i1}) && isnumeric(LatRasters{i1}) && isnumeric(ElevRasters{i1}))
        error('2nd, 3rd, and 4th inputs must contain numerical matrices in every cell array!')
    end
    if not(isequal(size(LongRasters{i1}), size(LatRasters{i1}), size(ElevRasters{i1})))
        error(['2nd, 3rd, and 4th inputs must contain numerical matrices of same ' ...
               'sizes (each i-th element of cells must agree with the other i-th element)!'])
    end
end

if not(isa(PolyMask, 'polyshape'))
    error('1st input must be a polyshape!')
end

%% Settings
sl = filesep;

DEMSize = round(deg2rad(abs(LatRasters{1}(1) - ...
                            LatRasters{1}(2)))*earthRadius); % Default
BffVal  = 80;           % Default [m]
PlnEPSG = 25832;        % Default
AttrOpt = 'Opt4';       % Default
SavePth = pwd;          % Default
Interp  = 'nearest';    % Default
OutCrds = 'Geographic'; % Default
OutFrmt = 'Tiff';       % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputDTMSz  = find(cellfun(@(x) all(strcmpi(x, "demsize"  )), vararginCp));
    InputBuffer = find(cellfun(@(x) all(strcmpi(x, "buffer"   )), vararginCp));
    InputPlEPSG = find(cellfun(@(x) all(strcmpi(x, "planepsg" )), vararginCp));
    InputAtOpt  = find(cellfun(@(x) all(strcmpi(x, "elevattr" )), vararginCp));
    InputSavPth = find(cellfun(@(x) all(strcmpi(x, "savepath" )), vararginCp));
    InputInterp = find(cellfun(@(x) all(strcmpi(x, "interp"   )), vararginCp));
    InputOutCrd = find(cellfun(@(x) all(strcmpi(x, "outcoords")), vararginCp));
    InputOutFrm = find(cellfun(@(x) all(strcmpi(x, "outformat"   )), vararginCp));

    if InputDTMSz ; DEMSize = varargin{InputDTMSz+1 }; end
    if InputBuffer; BffVal  = varargin{InputBuffer+1}; end
    if InputPlEPSG; PlnEPSG = varargin{InputPlEPSG+1}; end
    if InputAtOpt ; AttrOpt = varargin{InputAtOpt+1 }; end
    if InputSavPth; SavePth = varargin{InputSavPth+1}; end
    if InputInterp; Interp  = varargin{InputInterp+1}; end
    if InputOutCrd; OutCrds = varargin{InputOutCrd+1}; end
    if InputOutFrm; OutFrmt = varargin{InputOutFrm+1}; end
end

switch AttrOpt
    case 'Opt1' % Nearest point P2G
        ElvAttr = 1;

    case 'Opt2' % Nearest point G2P
        ElvAttr = 2;

    case 'Opt3' % Nearest point G2P (red)
        ElvAttr = 3;

    case 'Opt4' % Interpolation
        ElvAttr = 4;

    otherwise
        error('Elevation attribution option (ElevAttr) not recognized!')
end

if not(any(strcmp(Interp, {'linear', 'nearest', 'natural'})))
    error('Interp method not recognized!')
end

if not(any(strcmp(OutCrds, {'Geographic', 'Planar'})))
    error('OutCoords type not recognized!')
end

if not(exist(SavePth, 'dir'))
    mkdir(SavePth)
end

if not(any(strcmp(OutFrmt, {'ASCII', 'Tiff'})))
    error('OutFormat must be "ASCII" or "Tiff" (case sensitive)!')
end

%% Buffered boundary of mask polygon
MinCrdPly = min(PolyMask.Vertices);
MaxCrdPly = max(PolyMask.Vertices);

EBMet = 500;
EBLat = rad2deg(EBMet/earthRadius); % See my notes for more information (Sa)
EBLon = rad2deg(acos( (cos(EBMet/earthRadius) - ...
                       sind((MinCrdPly(2)+MaxCrdPly(2))/2)^2) / ...
                       cosd((MinCrdPly(2)+MaxCrdPly(2))/2)^2    )); % See my notes for more information (Sa)
BBox  = [ MinCrdPly(2)-EBLat, MaxCrdPly(2)+EBLat;
          MinCrdPly(1)-EBLon, MaxCrdPly(1)+EBLon ];
BBPly = polyshape([BBox(2), BBox(4), BBox(4), BBox(2)], ...
                  [BBox(1), BBox(1), BBox(3), BBox(3)]);

PlyMskPln = projfwdpoly(PolyMask, projcrs(PlnEPSG));
BffPlyPln = polybuffer(PlyMskPln, BffVal);
BffPly    = projinvpoly(BffPlyPln, projcrs(PlnEPSG));

%% Indexing of grid points
[IndDEMInBffPly, IndDEMInBBPly, ...
    xLonBffPly, yLatBffPly, ElevBffPly] = deal(cell(1,length(LongRasters)));
for i1 = 1:length(LongRasters)
    [pp1, ee1] = getnan2([BffPly.Vertices; nan, nan]);
    [pp2, ee2] = getnan2([BBPly.Vertices; nan, nan]);
    IndDEMInBffPly{i1} = find(inpoly([LongRasters{i1}(:), LatRasters{i1}(:)], pp1, ee1)==1);
    IndDEMInBBPly{i1}  = find(inpoly([LongRasters{i1}(:), LatRasters{i1}(:)], pp2, ee2)==1);

    xLonBffPly{i1} = LongRasters{i1}(IndDEMInBffPly{i1});
    yLatBffPly{i1} = LatRasters{i1}(IndDEMInBffPly{i1});
    ElevBffPly{i1} = ElevRasters{i1}(IndDEMInBffPly{i1});
end

%% Creation of merged DTM (empty elevation)
LongRastersCat = cellfun(@(x) x(:), LongRasters, 'UniformOutput', false);
LongRastersCat = vertcat(LongRastersCat{:});
LatRastersCat  = cellfun(@(x) x(:), LatRasters, 'UniformOutput', false);
LatRastersCat  = vertcat(LatRastersCat{:});

xLonBffPlyCat  = vertcat(xLonBffPly{:});
yLatBffPlyCat  = vertcat(yLatBffPly{:});
ElevBffPlyCat  = vertcat(ElevBffPly{:});

[~, IndMaxLat] = min((LatRastersCat  - BBox(3)).^2);
[~, IndMaxLon] = min((LongRastersCat - BBox(4)).^2);
[~, IndMinLat] = min((LatRastersCat  - BBox(1)).^2);
[~, IndMinLon] = min((LongRastersCat - BBox(2)).^2);

MaxLat  = LatRastersCat(IndMaxLat);
MinLat  = LatRastersCat(IndMinLat);
MaxLong = LongRastersCat(IndMaxLon);
MinLong = LongRastersCat(IndMinLon);

dLong = rad2deg(acos( (cos(DEMSize/earthRadius) - sind((MaxLat+MinLat)/2)^2) / cosd((MaxLat+MinLat)/2)^2 )); % See my notes for more information (Sa)
dLat  = rad2deg(DEMSize/earthRadius); % See my notes for more information (Sa)

SizeX = int64((MaxLong-MinLong)/dLong);
SizeY = int64((MaxLat-MinLat)/dLat);
MaxLong = MinLong + double(SizeX)*dLong;
MaxLat  = MinLat  + double(SizeY)*dLat;
RGeoTot = georefcells([MinLat, MaxLat], [MinLong, MaxLong], [SizeY, SizeX]);
[yLatGeoTot, xLonGeoTot] = geographicGrid(RGeoTot);
ElevTot = zeros(size(xLonGeoTot));

%% Writing of elevation in merged grid
switch ElvAttr
    case 1
        %% Elevation of merged DTM attribution OPT1
        DoublePointCount = 0;
        PointsDoubledInd = [];
        for i1 = 1:length(ElevBffPlyCat)
            [~, IndBffPlyTmp] = sort( (xLonGeoTot(:)-xLonBffPlyCat(i1)).^2 + ...
                                      (yLatGeoTot(:)-yLatBffPlyCat(i1)).^2 );
            IndBffPlyTmp = IndBffPlyTmp(1:4);
            if ElevTot(IndBffPlyTmp(1)) == 0
                ElevTot(IndBffPlyTmp(1)) = ElevBffPlyCat(i1);
            elseif ElevTot(IndBffPlyTmp(2)) == 0
                ElevTot(IndBffPlyTmp(2)) = ElevBffPlyCat(i1);
            elseif ElevTot(IndBffPlyTmp(3)) == 0
                ElevTot(IndBffPlyTmp(3)) = ElevBffPlyCat(i1);
            elseif ElevTot(IndBffPlyTmp(4)) == 0
                ElevTot(IndBffPlyTmp(4)) = ElevBffPlyCat(i1);
            else
                ElevTot(IndBffPlyTmp(1)) = (ElevTot(IndBffPlyTmp(1))+ElevBffPlyCat(i1))/2;
                DoublePointCount = DoublePointCount+1;
                PointsDoubledInd = [PointsDoubledInd; i1];
            end
        end

    case 2
        %% Elevation of merged DTM attribution OPT2
        [pp3, ee3] = getnan2([BffPly.Vertices; nan, nan]);
        IndTotInBffPly = find(inpoly([xLonGeoTot(:), yLatGeoTot(:)], pp3, ee3)==1);
        for i1 = 1:length(IndTotInBffPly)
            [~, IndBffPlyTmp] = min(( (xLonBffPlyCat(:)-xLonGeoTot(IndTotInBffPly(i1))).^2 + ...
                                      (yLatBffPlyCat(:)-yLatGeoTot(IndTotInBffPly(i1))).^2   ));
            ElevTot(IndTotInBffPly(i1)) = ElevBffPlyCat(IndBffPlyTmp);
        end

    case 3
        %% Elevation of merged DTM attribution OPT3
        [pp3, ee3] = getnan2([BffPly.Vertices; nan, nan]);
        IndTotInBffPly = find(inpoly([xLonGeoTot(:), yLatGeoTot(:)], pp3, ee3)==1);
        xLongSASToRemove = xLonBffPlyCat;
        yLatSASToRemove  = yLatBffPlyCat;
        ElevaSASToRemove = ElevBffPlyCat;
        
        EmptyPointCount = 0;
        EmptyPointIndex = [];
        for i1 = 1:length(IndTotInBffPly)
            [MinDist, IndBffPlyTmp] = min(( (xLongSASToRemove(:)-xLonGeoTot(IndTotInBffPly(i1))).^2 + ...
                                            (yLatSASToRemove(:)-yLatGeoTot(IndTotInBffPly(i1))).^2   ));
            if MinDist < 0.7*(dLong^2+dLat^2)^0.5
                ElevTot(IndTotInBffPly(i1)) = ElevaSASToRemove(IndBffPlyTmp);
            else
                EmptyPointCount = EmptyPointCount+1;
                EmptyPointIndex = [EmptyPointIndex; IndTotInBffPly(i1)];
            end
        
            xLongSASToRemove(IndBffPlyTmp) = [];
            yLatSASToRemove(IndBffPlyTmp)  = [];
            ElevaSASToRemove(IndBffPlyTmp) = [];
        end

    case 4
        %% Elevation of merged DTM attribution OPT4
        [pp3, ee3] = getnan2([BffPly.Vertices; nan, nan]);
        IndTotInBffPly = find(inpoly([xLonGeoTot(:), yLatGeoTot(:)], pp3, ee3)==1);
        
        InterpolationDTM = scatteredInterpolant(xLonBffPlyCat(:), ...
                                                yLatBffPlyCat(:), ...
                                                double(ElevBffPlyCat(:)), ...
                                                Interp);
        
        ElevTot(IndTotInBffPly) = InterpolationDTM(xLonGeoTot(IndTotInBffPly), ...
                                                   yLatGeoTot(IndTotInBffPly));

end

%% Plot to check the Study Area
fig_check = figure(2);
ax_check  = axes(fig_check);
hold(ax_check,'on')

fastscatter(xLonGeoTot(:), yLatGeoTot(:), ElevTot(:))

plot(BffPly, 'FaceColor','none', 'LineWidth',1  );
plot(BBPly , 'FaceColor','none', 'LineWidth',1.5);

title('Study Area Scaled Polygon Check')

%% Writing ASCII file & GeoTiff
if strcmp(OutCrds, 'Geographic')
    MinX  = sprintf('%.6f', MinLong);
    MinY  = sprintf('%.6f', MinLat);
    SizeY = RGeoTot.CellExtentInLatitude;
    SizeX = RGeoTot.CellExtentInLongitude;
    DEMSz = int16(deg2km(SizeY)*1000); % In meters, just for the title
    RTiff = RGeoTot;
else
    LatMn = mean(RGeoTot.LatitudeLimits);
    CRS   = projcrs(PlnEPSG);
    [MinX, MinY] = projfwd(CRS, MinLat, MinLong);
    [MaxX, MaxY] = projfwd(CRS, MaxLat, MaxLong);
    SizeY = deg2km(RGeoTot.CellExtentInLatitude)*1000; % diff of lat in meters
    SizeX = acos(cosd(RGeoTot.CellExtentInLongitude)*cosd(LatMn)^2 + sind(LatMn)^2)*earthRadius; % diff of lon in meters
    DEMSz = int16(SizeY);
    RTiff = maprefcells([MinX, MaxX], [MinY, MaxY], size(ElevTot), 'ColumnsStartFrom','north'); % Please, make it automatic also starting from south!
    RTiff.ProjectedCRS = CRS;
end

switch OutFrmt
    case 'ASCII'
        % Writing txt...
        if round(SizeX{i1}, 2, 'significant') ~= round(SizeY{i1}, 2, 'significant')
            warning('File not written because pixels must agree in sizes (squares)!')
        else
            DataToWriteHead = {'ncols'; 'nrows'; 'xllcorner'; 'yllcorner'; 'cellsize'; 'NODATA_value'};
            DataToWriteCont = {size(ElevTot,2); size(ElevTot,1); MinX; MinY; SizeY; sprintf('%.2f', 0)};
            DataToWrite1 = [char(DataToWriteHead), repmat(' ', 6, 1), char(string(DataToWriteCont))];
            DataToWrite2 = sprintf('% .2f', ElevTot(:));
            
            MergedTxtName = ['Merged-DTM-',num2str(DEMSz),'-',OutCrds,'.txt'];
            writelines([string(DataToWrite1); string(DataToWrite2)], [SavePth,sl,MergedTxtName])
        end

    case 'Tiff'
        % Writing GeoTiff...
        MergedTifName = ['Merged-DTM-',num2str(DEMSz),'-',OutCrds,'.tif'];
        if strcmp(OutCrds, 'Geographic')
            geotiffwrite([SavePth,sl,MergedTifName], ElevTot, RTiff)
        else
            geotiffwrite([SavePth,sl,MergedTifName], ElevTot, RTiff, 'CoordRefSysCode',PlnEPSG)
        end

    otherwise
        error('OutFormat not recognized in writing files!')
end

%% Saving...
VariablesStudyAreaDTM = {'BffPly', 'BBPly', 'RGeoTot', ...
                         'xLonGeoTot', 'yLatGeoTot', 'ElevTot'};
saveswitch([SavePth,sl,'MergedDTM.mat'], VariablesStudyAreaDTM);

end