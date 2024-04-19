function [RastVals, RastRef, RastInfo, EPSGNum, SelFlds] = readgeorast2(FileToRead, varargin)

% Function to read georaster values, reference object and info.
%   
%   [RastVals, RastRef, RastInfo] = readgeorast2(FilesToRead, varargin)
%
%   [RastVals, RastRef, RastInfo, EPSGNum, SelFlds] = readgeorast2(FilesToRead, varargin)
%   
%   Dependencies: inputdlg2 and listdlg2 from M-SLIP toolbox (only if missing values)
%   
% Outputs:
%   RastVals : is the matrix contain the values of the raster file!
%   
%   RastRef : is the reference object containing general info about the raster!
%   
%   RastInfo : is the matrix contain the infos about the file!
%   
%   EPSGNum : is the number that represent the EPSG code used. It will be
%   empty if not selected during the function, or equal to EPSG specified in 
%   optional arguments.
%   
%   SelFlds : is the cell array containing the attributes used to read the 
%   .nc file. It will be empty if nothing is selected during the function,
%   or equal to FieldNC specified in optional arguments.
%   
% Required arguments:
%   - FileToRead : the fullname of the file to be read! It can be also
%   just name.ext but in this case your current working directory must
%   be the one where the file is stored.
%   
% Optional arguments:
%   - 'OutputType', string/char : is to define the typoe of output you want
%   in RastVals. It can be set to 'native', 'single', 'double', 'int16', 
%   'int32', 'int64', 'uint8', 'uint16', 'uint32', 'uint64', or 'logical'.
%   By default 'native' is applied.
%   
%   - 'EPSG', numeric : is to define the EPSG to use in case it is not
%   detected in the file to read. It will be effective just in case the
%   coordinates system is planar and there is no info about it. In this 
%   case, if nothing is specified, then a prompt will ask you what is the 
%   EPSG number.
%   
%   - 'SeparateWorldFile', logical : is to define if it is present a
%   secondary world file to be read in order to obtain geospatial info. By
%   default it is set to 'false'!
%   
%   - 'FieldNC', cellstr : is to define the names of the attributes to
%   extract from the .nc file. It must be a 1x3 or 3x1 cell string,
%   containing longitude, latitude, and data fieldnames respectively. 
%   Ex: {'lon', 'lat', 'precipitation'}. If nothing is specified, then a
%   prompt will ask you for these fields, in case of a .nc filetype!

%% Input check
if not(ischar(FileToRead) || isstring(FileToRead) || iscellstr(FileToRead))
    error('FileToRead (1st input) must be a char or a string!')
end

FileToRead = string(FileToRead); % To have consistency!

SuppFiles = {'.tif', '.tiff', '.asc', '.img', '.jp2', '.grd', '.adf', '.nc'};
[BasePath, BaseName, BaseExt] = fileparts(FileToRead);
if not(any(strcmpi(BaseExt, SuppFiles)))
    error(['File of type "',char(BaseExt),'" not supported. Please make ' ...
           'shure your extension is: ',char(join(SuppFiles, '; ')),'!'])
end

if numel(FileToRead) > 1
    error(['You specified more than one file to read! Please ' ...
           'open a for cycle that call this function instead.'])
end

%% Settings
OutType = 'native'; % Default
EPSGNum = [];       % Default
SepWrld = false;    % Default
SelFlds = {};       % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputOutType = find(cellfun(@(x) all(strcmpi(x, "outputtype"       )), vararginCp));
    InputEPSGNum = find(cellfun(@(x) all(strcmpi(x, "epsg"             )), vararginCp));
    InputSepWrld = find(cellfun(@(x) all(strcmpi(x, "separateworldfile")), vararginCp));
    InputSelFlds = find(cellfun(@(x) all(strcmpi(x, "fieldnc"          )), vararginCp));

    if InputOutType; OutType = varargin{InputOutType+1}; end
    if InputEPSGNum; EPSGNum = varargin{InputEPSGNum+1}; end
    if InputSepWrld; SepWrld = varargin{InputSepWrld+1}; end
    if InputSelFlds; SelFlds = varargin{InputSelFlds+1}; end

    varargin([ InputOutType, InputOutType+1, ...
               InputEPSGNum, InputEPSGNum+1, ...
               InputSepWrld, InputSepWrld+1 ...
               InputSelFlds, InputSelFlds+1 ]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(any(strcmpi(OutType, {'native','single','double','int16','int32','int64', ...
                             'uint8','uint16','uint32','uint64','logical'})))
    error(['OutputType not recognized! It must be one of the following: native, ' ...
           'single, double, int16, int32, int64, uint8, uint16, uint32, uint64, logical'])
end

if not(isempty(EPSGNum)) && (not(isnumeric(EPSGNum)) || numel(EPSGNum) > 1)
    error('EPSG must be numeric and just a single number!')
end

if not(islogical(SepWrld))
    error('SeparateWorldFile must be a logical value!')
end

if not(isempty(SelFlds)) && not(iscellstr(SelFlds) && numel(SelFlds) == 3)
    error('FieldNC must be a cellstring with dims 1x3 or 3x1!')
end

%% Core
switch BaseExt
    case {'.tif', '.tiff', '.asc', '.img', '.jp2', '.grd', '.adf'}
        RastInfo = georasterinfo(FileToRead);
        [RastVals, RastRef] = readgeoraster(FileToRead, 'OutputType',OutType);

    case {'.nc'}
        FileInfo = ncinfo(FileToRead);
        FileFlds = extractfield(FileInfo.Variables, 'Name');
        if isempty(SelFlds)
            SelFlds = listdlg2({'Longitude field', 'Latitude field', 'Data field'}, FileFlds);
        end

        FileLon  = ncread(FileToRead, SelFlds{1});
        FileLat  = ncread(FileToRead, SelFlds{2});
        FileData = ncread(FileToRead, SelFlds{3});

        FileLonS = unique(FileLon); % To sort values!
        FileLatS = unique(FileLat); % To sort values!
        DeltaLon = abs(FileLonS(2) - FileLonS(1));
        DeltaLat = abs(FileLatS(2) - FileLatS(1));

        RastVals = FileData';

        if not(isequal(size(RastVals), [numel(FileLat), numel(FileLon)]))
            error('Mismatch detected between Data and lat, lon arrays!')
        end

        if (min(FileLon) < -180) || (max(FileLon) > 180)
            error('Longitude coordinates out of ranges! Please check it!')
        end

        if (min(FileLat < -90)) || (max(FileLat > 90))
            error('Latitude coordinates out of ranges! Please check it!')
        end
    
        IndData = find(strcmp(SelFlds{3}, FileFlds));
        RastInfo.MissingDataIndicator = FileInfo.Variables(IndData).FillValue;
        RastInfo.RasterReference.CoordinateSystemType = 'geographic';

        LonLims = min(max([min(FileLon) - DeltaLon/2, max(FileLon) + DeltaLon/2], -180), 180);
        LatLims = min(max([min(FileLat) - DeltaLat/2, max(FileLat) + DeltaLat/2], -90 ), 90 );
    
        if FileLat(1) > FileLat(end)
            StrtCol = 'north';
        else
            StrtCol = 'south';
        end
        RastRef = georefcells(LatLims, LonLims, size(RastVals), 'ColumnsStartFrom',StrtCol);

    otherwise
        error('Extension of file not recognized during reading!')
end

if not(any(strcmp(RastInfo.RasterReference.CoordinateSystemType, {'geographic', 'planar'})))
    CrdType = listdlg2({'File coordinate type not specified!'}, {'geographic', 'planar'});
    RastInfo.RasterReference.CoordinateSystemType = CrdType{:};
end

if SepWrld
    if isempty(RastRef) && exist(strcat(BasePath,filesep,BaseName,'.tfw'), 'file')
        RastRef = worldfileread(strcat(BasePath,filesep,BaseName,'.tfw'), ...
                                RastInfo.RasterReference.CoordinateSystemType, size(RastVals));
    end
end

if isempty(RastRef)
    switch RastInfo.RasterReference.CoordinateSystemType
        case 'geographic'
            RngInps = inputdlg2({'Latitude limits [Ymin, Ymax]: ', ...
                                 'Longitude limits [Xmin, Xmax]: '}, ...
                                'DefInp',{'[-90, 90]', '[-180, 180]'});
            LatLims = str2num(RngInps{1});
            LonLims = str2num(RngInps{2});

            if LonLims(2) <= LonLims(1)
                error('You must specify limits that contain an Xmax > Xmin')
            end

            if LatLims(2) > LatLims(1)
                StrtCol = 'north';
            else
                StrtCol = 'south';
            end
        
            RastRef = georefcells(LatLims, LonLims, size(RastVals), 'ColumnsStartFrom',StrtCol);

        case 'planar'
            RngInps = inputdlg2({'x projected limits [Xmin, Xmax]: ', ...
                                 'y projected limits [Ymin, Ymax]: '}, ...
                                'DefInp',{'[40000, 45000]', '[50000, 55000]'});
            xPlLims = str2num(RngInps{1});
            yPlLims = str2num(RngInps{2});

            if xPlLims(2) <= xPlLims(1)
                error('You must specify limits that contain an Xmax > Xmin')
            end

            if yPlLims(2) > yPlLims(1)
                StrtCol = 'north';
            else
                StrtCol = 'south';
            end

            RastRef = maprefcells(xPlLims, yPlLims, size(RastVals), 'ColumnsStartFrom',StrtCol);

        otherwise
            error('Raster info does not contain info about geographic or projected coordinates!')
    end
end

switch RastRef.CoordinateSystemType
    case 'planar'
        if isempty(RastRef.ProjectedCRS)
            if exist(strcat(BasePath,filesep,BaseName,'.prj'), 'file')
                PrjWKT = fileread(strcat(BasePath,filesep,BaseName,'.prj'));
                RastRef.ProjectedCRS = projcrs(PrjWKT);
            else
                if isempty(EPSGNum)
                    EPSGNum = str2double(inputdlg2({'DTM EPSG (Sicily -> 32633, Emilia Romagna -> 25832):'}, 'DefInp',{'25832'}));
                end
                RastRef.ProjectedCRS = projcrs(EPSGNum);
            end
        end

    case 'geographic'
        if isempty(RastRef.GeographicCRS)
            RastRef.GeographicCRS = geocrs(4326); % It will be applied the standard
        end

    otherwise
        error('CoordinateSystemType not redcognized in RastRef')
end

end