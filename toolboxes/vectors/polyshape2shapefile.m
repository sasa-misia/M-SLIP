function polyshape2shapefile(PolyshapeToConvert, varargin)
% polyshape2shapefile TO TEST!!!!
%
%       polyshape2shapefile(PolyshapeToConvert, varargin)
%       convert a polyshape (first column long, second lat) in a shapefile.
%       'IDs', var (must be a string vector)
%       'SavePath', var (must be a string or a char containing destination path)
%       'FileName', var (must be a string vector)

curr_path = pwd;
if isempty(varargin)
    save_path = curr_path;
    % IDs = ; % TO CONTINUE!
    FileName = 'PolyshapeConverted';
else
    convert = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    vararginlow = varargin;
    vararginlow(convert) = cellfun(@(x) lower(string(x)), vararginlow(convert), 'Uniform',false); % In this vector even paths are in lower and you don't want this.

    InputSavePath = find(cellfun(@(x) all(strcmpi(x, "savepath")), vararginlow));
    if InputSavePath
        save_path = varargin{InputSavePath+1}; 
    else
        save_path = curr_path;
    end

    InputIDs = find(cellfun(@(x) all(strcmpi(x, "ids")), vararginlow));
    if InputIDs
        IDs = varargin{InputIDs+1};
    else
        % IDs = ; % TO CONTINUE!
    end

    InputFileName = find(cellfun(@(x) all(strcmpi(x, "filename")), vararginlow));
    if InputFileName
        FileName = varargin{InputFileName+1};
    else
        FileName = 'PolyshapeConverted';
    end
end

% ShapeToWrite = repmat(geoshape, 1, length(IDs)); % Not working
ShapeToWrite = geoshape(PolyshapeToConvert(1).Vertices(:,2), PolyshapeToConvert(1).Vertices(:,1), 'Geometry','polygon', 'IDs',IDs(1));
for i1 = 2:length(IDs)
    ShapeToWrite(i1) = geoshape(PolyshapeToConvert(i1).Vertices(:,2), PolyshapeToConvert(i1).Vertices(:,1), 'Geometry','polygon', 'IDs',IDs(i1));
end

cd(save_path)
shapewrite(ShapeToWrite, FileName)
cd(curr_path)

end