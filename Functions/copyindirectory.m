function [] = copyindirectory(FileType, DestinationPath, varargin)
%CopyInDirectory Select a file and copy it in a sirectory
%
%       FileType = you can specify the extension as string. Examples:
%       'shp', 'xlsx', etc. 
%       If you want to have multiple types simoultaneously you can write 
%       a cell array of strings. Example: {'shp','xlsx'}
%
%       DestinationPath = You have to specify path where you want to save
%       files. Example: C:\Users\name\.....
%       
%       Optional arguments ('key','value')
%       'mode' can be 'single' or 'multiple'. In the first case you will
%       copy only selected file, in the second one you will copy all files
%       that contain that name, no matter the extension of the file.

if not(( (isstring(FileType) && isscalar(FileType))    || ...
         (ischar(FileType)   && size(FileType,1)==1) ) || ...
          iscell(FileType))
    error("First argument must be a scalar string, a 1 row char or a cell vector of strings/char")
end

if not(isstring(DestinationPath) || ischar(DestinationPath))
    error("Second argument must be a scalar string or a 1 row char")
end

if isempty(varargin)
    varargin = {'mode','single', 'title','Choose your file'};
end

convert = cellfun(@ischar, varargin);
varargin(convert) = cellfun(@(x) lower(string(x)), varargin(convert), 'Uniform',false);

InputMode = find(cellfun(@(x) strcmpi(x, "mode"), varargin));
if InputMode; Mode = varargin{InputMode+1}; else; Mode = 'single'; end

InputTitle = find(cellfun(@(x) strcmpi(x, "title"), varargin));
if InputTitle; Title = varargin{InputTitle+1}; else; Title = 'Choose your file'; end

if isvector(FileType) && iscell(FileType)
    if isrow(FileType); FileType = FileType'; end
end
Extension = char(FileType);
if ~strcmp(Extension(1:2), '*.'); Extension = strcat('*.',Extension); end
if size(Extension,1)>1; Extension = join(cellstr(Extension),"; "); end

[FileName, FilePath] = uigetfile(Extension, Title, 'MultiSelect','on');

switch Mode
    case "single"
        FileToCopy = fullfile(FilePath, FileName);
        copyfile(FileToCopy, DestinationPath);
    case "multiple"
        Files = string({dir(FilePath).name});
        [~, FileName] = fileparts(FileName);
        IndFilesToCopy = contains(Files,FileName);
        FilesToCopy = strcat(FilePath,Files(IndFilesToCopy));
        arrayfun(@(x) copyfile(x, DestinationPath), FilesToCopy);
    otherwise
        error("'mode' must be 'single'or 'multiple'")
end