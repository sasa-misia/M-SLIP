function [] = forested_areas(FilePaths, LongRasters, LatRasters, RefRasters, varargin)
% CREATE FORESTED AREAS RASTER
%   
% Outputs:
%  -
%  
% Required functions:
%   - listdlg2 (Salvatore Misiano)
%   - checkbox2 (Salvatore Misiano)
%   - inputdlg2 (Salvatore Misiano)
% 
% Required arguments:
%   Arguments MUST be in geographic coordinates!!!
%   
%   - FilePaths : is the cell array containing in each cell the filepath to
%   read (each cell must contain a string/char with the path). Files can be 
%   tif or shp type and filepaths must be full (C:/...)!
%   
%   - LongRasters : is the cell array containing in each cell the matrix grid 
%   with longitude values for each pixel..
%   
%   - LatRasters : is the cell array containing in each cell the matrix grid 
%   with latitude values for each pixel..
%   
%   - RefRasters : is the cell array containing in each cell the spatial 
%   reference object (GeographicCellsReference object | GeographicPostingsReference 
%   object | MapCellsReference object | MapPostingsReference object)
%   
% Optional arguments:
%   - 'PolyMask', polyshape : is a polyshape containing the mask you want to 
%   apply. If no value is specified, then it will be created a rectangle
%   polyshape containing the extremes of the DEMs files given.
%   
%   - 'Buffer', numerical : is the size, in meters, that identify the
%   buffer from the PolyMask. If no value is specified, then 80 m will be
%   take as default.
%   
%   - 'PlanEPSG', numerical : is the EPSG number that control the conversion 
%   of the mask polygon in planar coordinates (in order to apply the buffer).
%   If no value is specified, then 25832 will be applied.
%   
%   - 'FieldNames', cellstr or cell array containing string/char : is to 
%   define the names of the field to use with the eventual shapefiles specified 
%   in FilePaths. It must have the same dimensions of FilePaths and if in you
%   have also tif files, just leave the cell empty (in any case it will not 
%   be read). If no value is specified, then an empty cell array will be created.
%   
%   - 'SavePath', string/char : is to define the path where to save the
%   merged DEM. If no value is specified, then the current folder will be
%   selected.
%   
%   - 'Interp', string/char : is to define the type of interpolation that
%   you want to apply in creating rasters. It can be 'linear', 'nearest', or 
%   'natural'. If no value is specified, then 'nearest' will be take as default.
%   
%   - 'OutCoords', string/char : is to define the type of output to use in
%   writing the merged DEM. It can be 'Geographic' or 'Planar'. If 'Planar'
%   is set, then it will be used the CRS defined in 'PlanEPSG'. If no value
%   is specified, then 'Geographic' will be take as default.
%   
%   - 'SimplifyGeom', logical : is to define if you want or not to simplify
%   geometries. If no value is selected, then 'true' will be take as default.
%   
%   - 'OutFormat', string/char : is to define the type of output you want
%   for the export files. It can be 'ASCII' or 'Tiff'. If no value is
%   specified, then 'Tiff' will be take as default.

%% Input Check
if not(iscell(FilePaths) && iscell(LongRasters) && iscell(LatRasters) && iscell(RefRasters))
    error('1st, 2nd, 3rd, and 4th inputs must be cell arrays!')
end

if not(isequal(size(LongRasters), size(LatRasters), size(RefRasters)))
    error('2nd, 3rd, and 4th inputs must be have same dimensions!')
end

for i1 = 1:numel(FilePaths)
    if not(isstring(FilePaths{i1}) || ischar(FilePaths{i1}))
        error('1st input must contain string or char in every cell of the array!')
    end
    if isstring(FilePaths{i1})
        FilePaths{i1} = char(FilePaths{i1});
    end
end

for i1 = 1:numel(RefRasters)
    if not(isnumeric(LongRasters{i1}) && isnumeric(LatRasters{i1}))
        error('2nd and 3rd inputs must contain numerical matrices in every cell array!')
    end
    if not(contains(class(RefRasters{i1}), 'map.rasterref.GeographicCellsReference'))
        error('4th input must be a map.rasterref object, in geographic coordinates!')
    end
    if not(isequal(size(LongRasters{i1}), size(LatRasters{i1})))
        error(['2nd and 3rd inputs must contain numerical matrices of same ' ...
               'sizes (each i-th element of cells must agree with the other i-th element)!'])
    end
end

%% Settings
sl = filesep;

PlyMask = [];                    % Default
BffVal  = 80;                    % Default [m]
PlnEPSG = 25832;                 % Default
ShpFlds = cell(size(FilePaths)); % Default
SavePth = pwd;                   % Default
Interp  = 'nearest';             % Default
OutCrds = 'Geographic';          % Default
SmpGeom = true;                  % Default
OutFrmt = 'Tiff';                % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputPlyMsk = find(cellfun(@(x) all(strcmpi(x, "polymask"    )), vararginCp));
    InputBuffer = find(cellfun(@(x) all(strcmpi(x, "buffer"      )), vararginCp));
    InputPlEPSG = find(cellfun(@(x) all(strcmpi(x, "planepsg"    )), vararginCp));
    InputFields = find(cellfun(@(x) all(strcmpi(x, "fieldnames"  )), vararginCp));
    InputSavPth = find(cellfun(@(x) all(strcmpi(x, "savepath"    )), vararginCp));
    InputInterp = find(cellfun(@(x) all(strcmpi(x, "interp"      )), vararginCp));
    InputOutCrd = find(cellfun(@(x) all(strcmpi(x, "outcoords"   )), vararginCp));
    InputSmpGmt = find(cellfun(@(x) all(strcmpi(x, "simplifygeom")), vararginCp));
    InputOutFrm = find(cellfun(@(x) all(strcmpi(x, "outformat"   )), vararginCp));

    if InputPlyMsk; PlyMask = varargin{InputPlyMsk+1}; end
    if InputBuffer; BffVal  = varargin{InputBuffer+1}; end
    if InputPlEPSG; PlnEPSG = varargin{InputPlEPSG+1}; end
    if InputFields; ShpFlds = varargin{InputFields+1}; end
    if InputSavPth; SavePth = varargin{InputSavPth+1}; end
    if InputInterp; Interp  = varargin{InputInterp+1}; end
    if InputOutCrd; OutCrds = varargin{InputOutCrd+1}; end
    if InputSmpGmt; SmpGeom = varargin{InputSmpGmt+1}; end
    if InputOutFrm; OutFrmt = varargin{InputOutFrm+1}; end
end

if isempty(PlyMask)
    MinPlyLat = min(cellfun(@(x) min(min(x)), LatRasters));
    MaxPlyLat = max(cellfun(@(x) max(max(x)), LatRasters));
    MinPlyLon = min(cellfun(@(x) min(min(x)), LongRasters));
    MaxPlyLon = max(cellfun(@(x) max(max(x)), LongRasters));

    PlyMask = polyshape([MinPlyLon, MaxPlyLon, MaxPlyLon, MinPlyLon], ...
                        [MinPlyLat, MinPlyLat, MaxPlyLat, MaxPlyLat]);
end

if not(isa(PlyMask, 'polyshape'))
    error('The PolyMask input must be a polyshape!')
end

for i1 = 1:numel(ShpFlds)
    if not(isstring(ShpFlds{i1}) || ischar(ShpFlds{i1}) || isempty(ShpFlds{i1}))
        error(['Element n. ',num2str(i1),' of FieldNames cell array is not a string, a char, or empty'])
    end
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

if not(islogical(SmpGeom))
    error('SimplifyGeom must be a logical value!')
end

if not(any(strcmp(OutFrmt, {'ASCII', 'Tiff'})))
    error('OutFormat must be "ASCII" or "Tiff" (case sensitive)!')
end

%% Buffered boundary of mask polygon
MinCrdPly = min(PlyMask.Vertices);
MaxCrdPly = max(PlyMask.Vertices);

EBMet = 500;
EBLat = rad2deg(EBMet/earthRadius); % See my notes for more information (Sa)
EBLon = rad2deg(acos( (cos(EBMet/earthRadius) - ...
                       sind((MinCrdPly(2)+MaxCrdPly(2))/2)^2) / ...
                       cosd((MinCrdPly(2)+MaxCrdPly(2))/2)^2    )); % See my notes for more information (Sa)
BBox  = [ MinCrdPly(2)-EBLat, MaxCrdPly(2)+EBLat;
          MinCrdPly(1)-EBLon, MaxCrdPly(1)+EBLon ];
BBPly = polyshape([BBox(2), BBox(4), BBox(4), BBox(2)], ...
                  [BBox(1), BBox(1), BBox(3), BBox(3)]);

PlyMskPln = projfwdpoly(PlyMask, projcrs(PlnEPSG));
BffPlyPln = polybuffer(PlyMskPln, BffVal);
BffPly    = projinvpoly(BffPlyPln, projcrs(PlnEPSG));

%% File type
[~, FileNameVeg, FileExtVeg] = fileparts(FilePaths);
[ForestedSep, ForsPntsSep] = deal(cell(numel(FilePaths), numel(LongRasters)));
[VegAllAttr, VegSelAttr, VegPolys, ...
    VegSinglePolys, FileType] = deal(cell(1, numel(FilePaths)));
for i1 = 1:numel(FileType)
    if strcmp(FileExtVeg{i1}, '.shp')
        FileType{i1} = {[num2str(i1), ' - Shapefile']};

    elseif strcmp(FileExtVeg{i1}, '.tif')
        FileType{i1} = {[num2str(i1), ' - Raster']};

    else
        error('Unknown FileType of file for vegetation, please contact the support.')
    end
end

%% Creation of forested maps rasters
for i1 = 1:length(FilePaths)
    %% Reading of files
    if contains(FileType{i1}, 'Raster')
        % REMEMBER TO IMPLEMENT MULTIPLE FILES, DIFFERENT TYPES, AND THE POSSIBILITY OF HAVING NO GEOREFERENCED FILE
        [ARastVeg, RRastVeg] = readgeoraster(FilePaths{i1}, 'OutputType','native');

        if strcmp(RRastVeg.CoordinateSystemType, 'planar')
            [LatLimits, LonLimits] = projinv(RRastVeg.ProjectedCRS, RRastVeg.XWorldLimits, RRastVeg.YWorldLimits);
            RRastVeg = georefcells(LatLimits, LonLimits, RRastVeg.RasterSize, ...
                                            'ColumnsStartFrom',RRastVeg.ColumnsStartFrom, ...
                                            'RowsStartFrom',RRastVeg.RowsStartFrom);
        end

        [ARastVeg, RRastVeg] = geocrop(ARastVeg, RRastVeg, BBox(1,:), BBox(2,:));

        if isempty(RRastVeg.GeographicCRS)
            RRastVeg.GeographicCRS = geocrs(4326);
        end

        MinValueVegRaster = min(min(ARastVeg));
        MaxValueVegRaster = max(max(ARastVeg));

        if MinValueVegRaster < 0
            error(['Min value of veg must not be below 0! Please contact ', ...
                   'the support! Current file is n. ',num2str(i1)])
        end

        [yLatVeg, xLongVeg] = geographicGrid(RRastVeg);
        VegRasterSize = int16(deg2km(RRastVeg.CellExtentInLatitude)*1000);
        OutRasterSize = int16(deg2km(abs(LatRasters{1}(1) - LatRasters{1}(2)))*1000);

        if OutRasterSize < VegRasterSize
            warning(['Veg raster size is: ',num2str(VegRasterSize),'; output raster will be: ', ...
                     num2str(OutRasterSize),'. This is not optimal (repetition of data)! ', ...
                     'Current file is n. ',num2str(i1)])
        end

    elseif contains(FileType{i1}, 'Shapefile')
        % Reading shapefile in bounding box
        ShpInfoVeg = shapeinfo(FilePaths{i1});
        
        if ShpInfoVeg.NumFeatures == 0
            error(['Shapefile in ',num2str(i1),' row of FilePaths is empty'])
        end
        
        [BBoxX, BBoxY] = projfwd(ShpInfoVeg.CoordinateReferenceSystem, BBox(1,:), BBox(2,:));
        ShpContVeg = shaperead(FilePaths{i1}, ...
                                         'BoundingBox',[ BBoxX(1), BBoxY(1);
                                                         BBoxX(2), BBoxY(2) ]);
        
        if size(ShpContVeg, 1) < 1
            error(['Shapefile in ',num2str(i1),' row of FilePaths is not empty ', ...
                   'but have no element in bounding box!'])
        end
        
        % Extract vegetation name abbreviations
        if isempty(ShpFlds{i1})
            ShpFlds{i1} = char(listdlg2({'Field with vegetation info'}, {ShpInfoVeg.Attributes.Name}));
        end

        VegAllAttr{i1} = extractfield(ShpContVeg, ShpFlds{i1});
        VegUnqAttr     = unique(VegAllAttr{i1});
        VegSelAttr{i1} = checkbox2(VegUnqAttr, 'Title',{'Choose forested areas:'});
        
        IndVeg = cell(1, length(VegSelAttr{i1}));
        for i2 = 1:length(VegSelAttr{i1})
            IndVeg{i2} = find(strcmp(VegAllAttr{i1}, VegSelAttr{i1}(i2)));
        end
        
        % Poligons creation
        VegPolys{i1} = repmat(polyshape, 1, length(IndVeg));
        for i2 = 1:length(IndVeg)
            [VegVertexLat,VegVertexLon] = projinv(ShpInfoVeg.CoordinateReferenceSystem,...
                                                  [ShpContVeg(IndVeg{i2}).X],...
                                                  [ShpContVeg(IndVeg{i2}).Y]);
            VegPolys{i1}(i2) = polyshape([VegVertexLon',VegVertexLat'], 'Simplify',SmpGeom);
        end
        
        VegSinglePolys{i1} = union(VegPolys{i1});
        VegSinglePolys{i1} = intersect(VegSinglePolys{i1}, BffPly);

    else
        error('FileType not recognized while reading files!')
    end
    
    %% Forested raster creation
    for i2 = 1:numel(LongRasters)
        ForestedSep{i1, i2} = zeros(size(LongRasters{i2})); % Zero is the default value with no info or not veg!
        if contains(FileType{i1}, 'Raster')
            ForestedTemp = ForestedSep{i1, i2};
            [pp1, ee1]   = getnan2([BffPly.Vertices; nan, nan]);
            IndRsVgInBff = find(inpoly([xLongVeg(:), yLatVeg(:)], pp1, ee1)==1);
            IndOutInBff  = find(inpoly([LongRasters{i2}(:), LatRasters{i2}(:)], pp1, ee1)==1);
    
            InterpVeget  = scatteredInterpolant(xLongVeg(IndRsVgInBff), ...
                                                yLatVeg(IndRsVgInBff), ...
                                                double(ARastVeg(IndRsVgInBff)), ...
                                                Interp);
    
            ForestedTemp(IndOutInBff) = InterpVeget(LongRasters{i2}(IndOutInBff), ...
                                                    LatRasters{i2}(IndOutInBff) );

            ForestedThreshold = str2double(inputdlg2({['Threshold for vegetated areas (min is ', ...
                                                       num2str(MinValueVegRaster),'; max is ',num2str(MaxValueVegRaster),')']}, ...
                                                     'DefInp',{num2str((MaxValueVegRaster-MinValueVegRaster)/2)}));
            IndDEMWithVeg = find(ForestedTemp(:) >= ForestedThreshold);
    
        elseif contains(FileType{i1}, 'Shapefile')
            [pp1, ee1] = getnan2([VegSinglePolys{i1}.Vertices; nan, nan]);
            IndDEMWithVeg = find(inpoly([LongRasters{i2}(:), LatRasters{i2}(:)], pp1, ee1)==1);
    
        else
            error('FileType not recognized while indexing points!')
        end
        
        ForestedSep{i1, i2}(IndDEMWithVeg) = 1; % IT MUST BE 1 IN ORDER TO LET WORK RIGHT THE NEXT SECTIONS!
    
        ForsPntsSep{i1, i2} = sum(ForestedSep{i1, i2}(:)==1);
    end
end

%% Creation of final unified forest map
[ForestedUnion, ForsPntsUnion] = deal(cell(1, numel(LongRasters)));
DiffMatrix = cellfun(@(x) zeros(size(x)), ForestedSep(1, :), 'UniformOutput',false);
for i1 = 1:numel(DiffMatrix)
    for i2 = 1:numel(FilePaths)
        DiffMatrix{i1} = DiffMatrix{i1} + abs(ForestedSep{i2, i1});
    end
    DiffMatrix{i1} = DiffMatrix{i1} - numel(FilePaths); % Pixels that agree between files are 0, otherwise < 0

    ForestedUnion{i1} = max(ForestedSep{1, i1}-abs(DiffMatrix{i1}), 0); % Taking ForestedSep{1, i1} or ForestedSep{n, i1} makes no difference
    ForsPntsUnion{i1} = sum(ForestedUnion{i1}(:)==1);
end

%% Plot to check the Study Area
for i1 = 1:size(ForestedSep, 1)
    figure(i1);
    hold on

    for i2 = 1:size(ForestedSep, 2)
        fastscatter(LongRasters{i2}(:), LatRasters{i2}(:), ForestedSep{i1, i2}(:))
        
        plot(BffPly, 'FaceColor','none', 'LineWidth',1  );
        plot(BBPly , 'FaceColor','none', 'LineWidth',1.5);
        
        title(['Forested check: ', FileNameVeg{i1}])
    end
end

figure(size(ForestedSep, 1) + 1);
hold on
for i1 = 1:size(ForestedUnion, 2)
    fastscatter(LongRasters{i1}(:), LatRasters{i1}(:), ForestedUnion{i1}(:))
    
    plot(BffPly, 'FaceColor','none', 'LineWidth',1  );
    plot(BBPly , 'FaceColor','none', 'LineWidth',1.5);
    
    title('Forested check: Unified')
end

%% Writing files
CRS = projcrs(PlnEPSG);
[MinX, MinY, MaxX, MaxY, SizeY, SizeX, DEMSz, RTiff] = deal(cell(1, size(ForestedSep, 2)));
for i1 = 1:size(ForestedSep, 2)
    if strcmp(OutCrds, 'Geographic')
        MinX{i1}  = sprintf('%.6f', min(RefRasters{i1}.LongitudeLimits));
        MinY{i1}  = sprintf('%.6f', min(RefRasters{i1}.LatitudeLimits));
        SizeY{i1} = RefRasters{i1}.CellExtentInLatitude;
        SizeX{i1} = RefRasters{i1}.CellExtentInLongitude;
        DEMSz{i1} = int16(deg2km(SizeY{i1})*1000); % In meters, just for the title
        RTiff{i1} = RefRasters{i1};
    else
        yLatMean  = mean(RefRasters{i1}.LatitudeLimits);
        [MinX{i1}, MinY{i1}] = projfwd(CRS, min(RefRasters{i1}.LatitudeLimits), min(RefRasters{i1}.LongitudeLimits));
        [MaxX{i1}, MaxY{i1}] = projfwd(CRS, max(RefRasters{i1}.LatitudeLimits), max(RefRasters{i1}.LongitudeLimits));
        SizeY{i1} = int64(deg2km(RefRasters{i1}.CellExtentInLatitude)*1000); % diff of lat in meters
        SizeX{i1} = int64(acos(cosd(RefRasters{i1}.CellExtentInLongitude)*cosd(yLatMean)^2 + sind(yLatMean)^2)*earthRadius); % diff of lon in meters
        DEMSz{i1} = int16(SizeY{i1});
        RTiff{i1} = maprefcells([MinX, MaxX], [MinY, MaxY], size(LongRasters{i1}), 'ColumnsStartFrom','north'); % Please, make it automatic also starting from south!
        RTiff{i1}.ProjectedCRS = CRS;
    end
end

FoldNameSep = 'Original Converted In Rasters';
FoldExpSep  = [SavePth,sl,FoldNameSep];
if not(exist(FoldExpSep, 'dir'))
    mkdir(FoldExpSep)
end

FoldNameUnion = 'Unified Rasters';
FoldExpUnion  = [SavePth,sl,FoldNameUnion];
if not(exist(FoldExpUnion, 'dir'))
    mkdir(FoldExpUnion)
end

switch OutFrmt
    case 'ASCII'
        %% ASCII
        for i1 = 1:size(ForestedSep, 2)
            DataToWriteHead = {'ncols'; 'nrows'; 'xllcorner'; 'yllcorner'; 'cellsize'; 'NODATA_value'};
            DataToWriteCont = {size(ForestedSep{1, i1},2); size(ForestedSep{1, i1},1); MinX{i1}; MinY{i1}; SizeY{i1}; sprintf('%i', 0)}; % ForestedSep{1, i1} because taking the first or second row makes no differences in sizes!
        
            DataToWrite1 = [char(DataToWriteHead), repmat(' ', 6, 1), char(string(DataToWriteCont))];
            for i2 = 1:size(ForestedSep, 1)
                CurrFileName = ['ForestedArea-',num2str(DEMSz{i1}),'m-', ...
                                OutCrds,'-',FileNameVeg{i2},'-DEM',num2str(i1),'.txt'];
                if round(SizeX{i1}, 2, 'significant') ~= round(SizeY{i1}, 2, 'significant')
                    warning(['File ',CurrFileName,' not written because pixels must agree in sizes (squares)!'])
                    continue
                end

                DataToWrite2 = sprintf('% i', ForestedSep{i2, i1}(:));
                
                writelines([string(DataToWrite1); string(DataToWrite2)], ...
                           [FoldExpSep,sl,CurrFileName]);
            end
        end
        
        for i1 = 1:size(ForestedUnion, 2)
            DataToWriteHead = {'ncols'; 'nrows'; 'xllcorner'; 'yllcorner'; 'cellsize'; 'NODATA_value'};
            DataToWriteCont = {size(ForestedUnion{i1},2); size(ForestedUnion{i1},1); MinX{i1}; MinY{i1}; SizeY{i1}; sprintf('%i', 0)};
        
            DataToWrite1 = [char(DataToWriteHead), repmat(' ', 6, 1), char(string(DataToWriteCont))];
            DataToWrite2 = sprintf('% i', ForestedUnion{i1}(:));

            CurrFileName = ['ForestedArea-',num2str(DEMSz{i1}),'m-', ...
                            OutCrds,'-Unified-DEM',num2str(i1),'.txt'];
            if round(SizeX{i1}, 2, 'significant') ~= round(SizeY{i1}, 2, 'significant')
                warning(['File ',CurrFileName,' not written because pixels must agree in sizes (squares)!'])
                continue
            end
            
            writelines([string(DataToWrite1); string(DataToWrite2)], ...
                       [FoldExpUnion,sl,CurrFileName]);
        end

    case 'Tiff'
        %% Tiff
        for i1 = 1:size(ForestedSep, 2)
            for i2 = 1:size(ForestedSep, 1)
                CurrFileName = ['ForestedArea-',num2str(DEMSz{i1}),'m-', ...
                                OutCrds,'-',FileNameVeg{i2},'-DEM',num2str(i1),'.tif'];
                if strcmp(OutCrds, 'Geographic')
                    geotiffwrite([FoldExpSep,sl,CurrFileName], single(ForestedSep{i2, i1}), RTiff{i1})
                else
                    geotiffwrite([FoldExpSep,sl,CurrFileName], single(ForestedSep{i2, i1}), RTiff{i1}, 'CoordRefSysCode',PlnEPSG)
                end
            end
        end

        for i1 = 1:size(ForestedUnion, 2)
            CurrFileName = ['ForestedArea-',num2str(DEMSz{i1}),'m-', ...
                            OutCrds,'-Unified-DEM',num2str(i1),'.tif'];
            if strcmp(OutCrds, 'Geographic')
                geotiffwrite([FoldExpUnion,sl,CurrFileName], single(ForestedUnion{i1}), RTiff{i1})
            else
                geotiffwrite([FoldExpUnion,sl,CurrFileName], single(ForestedUnion{i1}), RTiff{i1}, 'CoordRefSysCode',PlnEPSG)
            end
        end

    otherwise
        error('OutFormat not recognized in writing files!')
end

%% Saving...
VariablesForestedAreaDEM = {'BffPly', 'BBPly', 'RefRasters', ...
                            'LongRasters', 'LatRasters', 'VegAllAttr', ...
                            'VegSelAttr', 'VegPolys', 'VegSinglePolys', ...
                            'ForestedSep', 'ForsPntsSep', 'ForestedUnion', ...
                            'ForsPntsUnion', 'FilePaths', 'FileType'};
saveswitch([SavePth,sl,'ForestedAreaRaster.mat'], VariablesForestedAreaDEM);

end