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
    varargin = {'mode','single', 'title','Choose your file', 'file2copy',''};
end

convert = cellfun(@ischar, varargin) | cellfun(@isstring, varargin);
vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
vararginCp(convert) = cellfun(@(x) lower(string(x)), varargin(convert),  'Uniform',false);

InputMode = find(cellfun(@(x) strcmpi(x, "mode"), vararginCp));
if InputMode; Mode = vararginCp{InputMode+1}; else; Mode = 'single'; end

InputTitle = find(cellfun(@(x) strcmpi(x, "title"), vararginCp));
if InputTitle; Title = varargin{InputTitle+1}; else; Title = 'Choose your file'; end

InputFile2Copy = find(cellfun(@(x) strcmpi(x, "file2copy"), vararginCp));
if InputFile2Copy; PreExFiles = varargin{InputFile2Copy+1}; else; PreExFiles = ''; end

if isvector(FileType) && iscell(FileType)
    if isrow(FileType); FileType = FileType'; end
end

Extension = char(FileType);
if ~strcmp(Extension(1:2), '*.'); Extension = strcat('*.',Extension); end
if size(Extension,1)>1; Extension = join(cellstr(Extension),"; "); end

if isempty(PreExFiles)
    [FileName, FilePath] = uigetfile(Extension, Title, 'MultiSelect','on');
else
    [FilePathM, FileNamePr, FileNameExt] = fileparts(PreExFiles);
    FilePath = [char(unique(FilePathM)),filesep];
    FileName = strcat(FileNamePr,FileNameExt);
end

switch Mode
    case "single"
        FilesToCopy = cellstr(fullfile(FilePath, FileName));

    case "multiple"
        Files = string({dir(FilePath).name});
        [~, FileName] = fileparts(FileName);
        IndFilesToCopy = contains(Files,FileName);
        FilesToCopy = cellstr(strcat(FilePath,Files(IndFilesToCopy)));

    otherwise
        error("'mode' must be 'single'or 'multiple'")
end

FlIndInDestPath = not([dir(DestinationPath).isdir]);
CntntInDestPath = {dir(DestinationPath).name};
FilesInDestPath = CntntInDestPath(FlIndInDestPath);

Inds2Copy = true(1, numel(FilesToCopy));
if not(isempty(FilesInDestPath))
    for i1 = 1:numel(FilesToCopy)
        [~, TempFlNm, TempFlExt] = fileparts(FilesToCopy{i1});
        TempFile2Chck = [TempFlNm,TempFlExt];
        Inds2Copy(i1) = not(any(strcmp(TempFile2Chck, FilesInDestPath)));
    end
end

if all(not(Inds2Copy))
    warning('All these files are already present in the destination folder!')
else
    cellfun(@(x) copyfile(x, DestinationPath), FilesToCopy(Inds2Copy));
end