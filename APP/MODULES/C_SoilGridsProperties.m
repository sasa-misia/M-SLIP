if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading...
sl = filesep;
load([fold_var,sl,'GridCoordinates.mat'], 'xLongAll','yLatAll')

%% Options
Options = {'linear', 'nearest', 'natural'};
InterpMethod = uiconfirm(Fig, 'What interpolation method do you want to use?', ...
                              'Interpolation methods', 'Options',Options);

FileType = checkbox2({'Clay content', 'Sand content', ...
                      'NDVI', 'Vegetation species'}, 'DefInp',[1, 1, 1, 1], ...
                                                     'Title','File type to load:', 'OutType','LogInd');

%% Initializing
FilenamesUsed = {};
VarsSoilGrids = {};

%% Clay content
if FileType(1)
    ProgressBar.Message = 'Clay content interpolation...';
    waitAns1 = uiconfirm(Fig, 'Now you will search for clay content raster file!', 'Search file', 'Options',{'Ok, come on!'});
    [FileNameClay, FilePathClay] = uigetfile('*.tif', 'Choose your raster for clay content', 'MultiSelect','off');
    figure(Fig) % To bring front the ProgressBar
    FullnameClay = [FilePathClay,FileNameClay];
    ClayContentAll = raster_interpolation(xLongAll, yLatAll, FullnameClay, InterpMethod);
    FilenamesUsed = [FilenamesUsed, {FullnameClay}];
    VarsSoilGrids = [VarsSoilGrids, {'ClayContentAll'}];
end

%% Sand content
if FileType(2)
    ProgressBar.Message = 'Sand content interpolation...';
    waitAns2 = uiconfirm(Fig, 'Now you will search for sand content raster file!', 'Search file', 'Options',{'Ok, come on!'});
    [FileNameSand, FilePathSand] = uigetfile('*.tif', 'Choose your raster for sand content', 'MultiSelect','off');
    figure(Fig) % To bring front the ProgressBar
    FullnameSand = [FilePathSand,FileNameSand];
    SandContentAll = raster_interpolation(xLongAll, yLatAll, FullnameSand, InterpMethod);
    FilenamesUsed = [FilenamesUsed, {FullnameSand}];
    VarsSoilGrids = [VarsSoilGrids, {'SandContentAll'}];
end

%% NDVI
if FileType(3)
    ProgressBar.Message = 'NDVI values interpolation...';
    waitAns3 = uiconfirm(Fig, 'Now you will search for NDVI raster file!', 'Search file', 'Options',{'Ok, come on!'});
    [FileNameNDVI, FilePathNDVI] = uigetfile('*.tif', 'Choose your raster for NDVI', 'MultiSelect','off');
    figure(Fig) % To bring front the ProgressBar
    FullnameNDVI = [FilePathNDVI,FileNameNDVI];
    NdviAll = raster_interpolation(xLongAll, yLatAll, FullnameNDVI, InterpMethod);
    FilenamesUsed = [FilenamesUsed, {FullnameNDVI}];
    VarsSoilGrids = [VarsSoilGrids, {'NdviAll'}];
end

%% Vegetation probabilities
if FileType(4)
    ProgressBar.Message = 'Vegetation probabilities values interpolation...';
    waitAns4 = uiconfirm(Fig, 'Now you will search for vegetation probability files!', 'Search file', 'Options',{'Ok, come on!'});
    [FileNameVgPr, FilePathVgPr] = uigetfile('*.tif', 'Choose your rasters for vegetation probabilities', 'MultiSelect','on');
    figure(Fig) % To bring front the ProgressBar
    FullnameVgPr = strcat(FilePathVgPr,FileNameVgPr);
    VgPrAll = cell(numel(FileNameVgPr), numel(xLongAll));
    for i1 = 1:length(FileNameVgPr)
        VgPrAll(i1,:) = raster_interpolation(xLongAll, yLatAll, FullnameVgPr{i1}, InterpMethod);
    end
    
    RowToDel = any(cellfun(@isempty, VgPrAll), 2);
    FileNameVgPr(RowToDel) = [];
    FilePathVgPr(RowToDel) = [];
    FullnameVgPr(RowToDel) = [];
    VgPrAll(RowToDel, :)   = [];
    
    RowNames = inputdlg2(FileNameVgPr);
    VgPrAll  = array2table(VgPrAll, 'RowNames',RowNames);

    FilenamesUsed = [FilenamesUsed, {FullnameVgPr}];
    VarsSoilGrids = [VarsSoilGrids, {'VgPrAll'}];
end

%% Creation of a new folder
ProgressBar.Message = 'Copying files...';

rel_fold_sgrid = 'SoilGrids';
fold_raw_sgrid = [fold_raw,sl,rel_fold_sgrid];

SourceFiles = FilenamesUsed;
for i1 = 1:numel(FilenamesUsed)
    if ischar(FilenamesUsed{i1})
        SourceTemp = copy_in_raw(fold_raw, rel_fold_sgrid, FilenamesUsed(i1));
        SourceFiles(i1) = SourceTemp;
    else
        SourceTemp = copy_in_raw(fold_raw, rel_fold_sgrid, FilenamesUsed{i1});
        SourceFiles{i1} = SourceTemp;
    end
end

VarsSoilGrids = [VarsSoilGrids, {'SourceFiles'}];

%% Saving...
ProgressBar.Message = 'Saving...';

Overwrite = true;
if exist([fold_var,sl,'SoilGrids.mat'], 'file')
    OverAns = uiconfirm(Fig, 'SoilGrids.mat file already exist. Overwrite or update?', ...
                             'Overwrite', 'Options',{'Overwrite', 'Update'});
    if strcmp(OverAns,'Update'); Overwrite = false; end
end

if Overwrite
    saveswitch([fold_var,sl,'SoilGrids.mat'], VarsSoilGrids)
else
    saveswitch([fold_var,sl,'SoilGrids.mat'], VarsSoilGrids, '-append')
end
save([fold0,sl,'os_folders.mat'        ], 'fold_raw_sgrid', '-append')