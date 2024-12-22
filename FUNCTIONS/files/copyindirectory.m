function [] = copyindirectory(fileType, destinationPath, varargin)
%CopyInDirectory Select a file and copy it in a sirectory
%
%       fileType = you can specify the extension as string. Examples:
%       'shp', 'xlsx', etc. 
%       If you want to have multiple types simoultaneously you can write 
%       a cell array of strings. Example: {'shp','xlsx'}
%
%       destinationPath = You have to specify path where you want to save
%       files. Example: C:\Users\name\.....
%       
%       Optional arguments ('key','value')
%       'mode' can be 'single' or 'multiple'. In the first case you will
%       copy only selected file, in the second one you will copy all files
%       that contain that name, no matter the extension of the file.

%% Input check
if not(( (isstring(fileType) && isscalar(fileType))    || ...
         (ischar(fileType)   && size(fileType,1)==1) ) || ...
          iscell(fileType))
    error("First argument must be a scalar string, a 1 row char or a cell vector of strings/char")
end

if not(isstring(destinationPath) || ischar(destinationPath))
    error("Second argument must be a scalar string or a 1 row char")
end

if isempty(varargin)
    varargin = {'mode','single', 'title','Choose your file', 'file2copy',''};
end

%% Variable args
convert = cellfun(@ischar, varargin) | cellfun(@isstring, varargin);
vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
vararginCp(convert) = cellfun(@(x) lower(string(x)), varargin(convert),  'Uniform',false);

InputMode = find(cellfun(@(x) strcmpi(x, "mode"), vararginCp));
if InputMode; Mode = vararginCp{InputMode+1}; else; Mode = 'single'; end

InputTitle = find(cellfun(@(x) strcmpi(x, "title"), vararginCp));
if InputTitle; Title = varargin{InputTitle+1}; else; Title = 'Choose your file'; end

InputFile2Copy = find(cellfun(@(x) strcmpi(x, "file2copy"), vararginCp));
if InputFile2Copy; preSelFiles = cellstr(varargin{InputFile2Copy+1}); else; preSelFiles = {}; end

if isvector(fileType) && iscell(fileType)
    if isrow(fileType); fileType = fileType'; end
end

%% Core
extsType = char(fileType);
if not(strcmp(extsType(1:2), '*.')); extsType = strcat('*.',extsType); end
if size(extsType,1) > 1; extsType = join(cellstr(extsType),"; "); end

if isempty(preSelFiles)
    [fileName, filePath] = uigetfile(extsType, Title, 'MultiSelect','on');
else
    [filePathM, fileNamePr, fileNameExt] = fileparts(preSelFiles);
    filePath = [char(unique(filePathM)),filesep];
    fileName = strcat(fileNamePr,fileNameExt);
end

switch Mode
    case "single"
        files2Copy = cellstr(fullfile(filePath, fileName));

    case "multiple"
        possFiles  = string({dir(filePath).name});
        [~, fileName] = fileparts(fileName);
        indFilesCp = contains(possFiles,fileName);
        files2Copy = cellstr(strcat(filePath,possFiles(indFilesCp)));

    otherwise
        error("'mode' must be 'single'or 'multiple'")
end

isFldInDestPath = not([dir(destinationPath).isdir]);
cntntInDestPath = {dir(destinationPath).name};
filesInDestPath = cntntInDestPath(isFldInDestPath);

inds2Copy = true(1, numel(files2Copy));
if not(isempty(filesInDestPath)) % Check of pre-existing files
    for i1 = 1:numel(files2Copy)
        [~, tempFlNm, tempFlExt] = fileparts(files2Copy{i1});
        tempFile2Chck = [tempFlNm,tempFlExt];
        inds2Copy(i1) = not(any(strcmp(tempFile2Chck, filesInDestPath)));
    end
end

if any(inds2Copy)
    cellfun(@(x) copyfile(x, destinationPath), files2Copy(inds2Copy));
end

if all(not(inds2Copy))
    warning('All these files are already present in the destination folder!')
end