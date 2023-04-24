% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', 'Indeterminate','on');
drawnow

%% File loading...
cd(fold_var)
load('GridCoordinates.mat', 'xLongAll','yLatAll')
cd(fold0)

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

FullNamesToCopy = {FullNameClay, FullNameSand, FullNameNDVI};
NamesOfRaseters = {FileNameClay, FileNameSand, FileNameNDVI};

%% Creation of a new folder
fold_raw_sg_rast = [fold_raw,sl,'SoilGrids Rasters'];
if ~exist(fold_raw_sg_rast, 'dir')
    mkdir(fold_raw_sg_rast)
end

cellfun(@(x) copyfile(x, fold_raw_sg_rast), FullNamesToCopy);

%% Saving...
ProgressBar.Message = 'Saving...';
cd(fold_var)
VariablesSoilGrids = {'ClayContentAll', 'SandContentAll', 'NdviAll', 'NamesOfRaseters'};
save('SoilGrids.mat', VariablesSoilGrids{:})
cd(fold0)
save('os_folders.mat', 'fold_raw_sg_rast', '-append')

close(ProgressBar)