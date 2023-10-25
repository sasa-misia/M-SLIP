if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', 'Indeterminate','on');
drawnow

%% File loading...
sl = filesep;
load([fold_var,sl,'GridCoordinates.mat'], 'xLongAll','yLatAll')

%% Properties extraction
Options = {'linear', 'nearest', 'natural'};
InterpMethod = uiconfirm(Fig, 'What interpolation method do you want to use?', ...
                              'Interpolation methods', 'Options',Options);

ProgressBar.Message = 'Clay content interpolation...';
WaitAns1 = uiconfirm(Fig, 'Now you will search for clay content raster file!', 'Search file', 'Options',{'Ok, come on!'});
[FileNameClay, FilePathClay] = uigetfile('*.tif', 'Choose your raster for clay content', 'MultiSelect','off');
FullNameClay = [FilePathClay,FileNameClay];
ClayContentAll = raster_interpolation(xLongAll, yLatAll, FullNameClay, InterpMethod);

ProgressBar.Message = 'Sand content interpolation...';
WaitAns2 = uiconfirm(Fig, 'Now you will search for sand content raster file!', 'Search file', 'Options',{'Ok, come on!'});
[FileNameSand, FilePathSand] = uigetfile('*.tif', 'Choose your raster for sand content', 'MultiSelect','off');
FullNameSand = [FilePathSand,FileNameSand];
SandContentAll = raster_interpolation(xLongAll, yLatAll, FullNameSand, InterpMethod);

ProgressBar.Message = 'NDVI values interpolation...';
WaitAns3 = uiconfirm(Fig, 'Now you will search for NDVI raster file!', 'Search file', 'Options',{'Ok, come on!'});
[FileNameNDVI, FilePathNDVI] = uigetfile('*.tif', 'Choose your raster for NDVI', 'MultiSelect','off');
FullNameNDVI = [FilePathNDVI,FileNameNDVI];
NdviAll = raster_interpolation(xLongAll, yLatAll, FullNameNDVI, InterpMethod);

ProgressBar.Message = 'Vegetation probabilities values interpolation...';
WaitAns4 = uiconfirm(Fig, 'Now you will search for vegetation probability files!', 'Search file', 'Options',{'Ok, come on!'});
[FileNameVgPr, FilePathVgPr] = uigetfile('*.tif', 'Choose your rasters for vegetation probabilities', 'MultiSelect','on');
FullNameVgPr = strcat(FilePathVgPr,FileNameVgPr);
VgPrAll = cell(numel(FileNameVgPr), numel(xLongAll));
for i1 = 1:length(FileNameVgPr)
    VgPrAll(i1,:) = raster_interpolation(xLongAll, yLatAll, FullNameVgPr{i1}, InterpMethod);
end

RowToDel = any(cellfun(@isempty, VgPrAll), 2);
FileNameVgPr(RowToDel) = [];
FilePathVgPr(RowToDel) = [];
FullNameVgPr(RowToDel) = [];
VgPrAll(RowToDel, :)   = [];

RowNames = inputdlg2(FileNameVgPr);
VgPrAll  = array2table(VgPrAll, 'RowNames',RowNames);

FullNamesToCopy = [{FullNameClay, FullNameSand, FullNameNDVI}, FullNameVgPr];
NamesOfRaseters = [{FileNameClay, FileNameSand, FileNameNDVI}, FileNameVgPr];

%% Creation of a new folder
fold_raw_sg_rast = [fold_raw,sl,'SoilGrids Rasters'];
if ~exist(fold_raw_sg_rast, 'dir')
    mkdir(fold_raw_sg_rast)
end

PossibleNewFullNames = cellfun(@(x) [fold_raw_sg_rast,sl,x], NamesOfRaseters, 'UniformOutput',false);
for i1 = 1:length(PossibleNewFullNames)
    if not(exist(PossibleNewFullNames{i1}, 'file'))
        cellfun(@(x) copyfile(x, fold_raw_sg_rast), FullNamesToCopy);
    end
end

%% Saving...
ProgressBar.Message = 'Saving...';

VariablesSoilGrids = {'ClayContentAll', 'SandContentAll', 'NdviAll', 'VgPrAll', 'NamesOfRaseters'};
saveswitch([fold_var,sl,'SoilGrids.mat'], VariablesSoilGrids{:})
save([fold0,sl,'os_folders.mat'], 'fold_raw_sg_rast', '-append')

close(ProgressBar)