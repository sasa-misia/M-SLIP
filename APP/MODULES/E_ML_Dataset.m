% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

rng(10) % For reproducibility of the model

%% Loading data and initialization of AnalysisInformation
Options = {'Elevation', 'Slope', 'Aspect Angle', 'Main Curvature', 'Profile Curvature', ...
           'Planform Curvature', 'Contributing Area (log)', 'TWI', 'Clay Content', ...
           'Sand Content', 'NDVI', 'Sub Soil Class', 'Top Soil Class', };

cd(fold_var)
load('InfoDetectedSoilSlips.mat',    'InfoDetectedSoilSlips','SubArea','FilesDetectedSoilSlip')
load('GridCoordinates.mat',          'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load('StudyAreaVariables.mat',       'StudyAreaPolygon')

load('MorphologyParameters.mat',     'AspectAngleAll','ElevationAll','SlopeAll', ...
                                     'MeanCurvatureAll','ProfileCurvatureAll','PlanformCurvatureAll', ...
                                     'OriginallyProjected','SameCRSForAll')
load('FlowRouting.mat',              'ContributingAreaAll','TwiAll')
load('SoilGrids.mat',                'ClayContentAll','SandContentAll','NdviAll')
load('LithoPolygonsStudyArea.mat',   'LithoAllUnique','LithoPolygonsStudyArea')
load('TopSoilPolygonsStudyArea.mat', 'TopSoilAllUnique','TopSoilPolygonsStudyArea')
load('LandUsesVariables.mat',        'AllLandUnique','LandUsePolygonsStudyArea')
load('VegPolygonsStudyArea.mat',     'VegetationAllUnique','VegPolygonsStudyArea')
load('Distances.mat',                'MinDistToRoadAll')
load('RainInterpolated.mat',         'RainInterpolated','RainDateInterpolationStarts')
load('TempInterpolated.mat',         'TempInterpolated','TempDateInterpolationStarts')

if length(FilesDetectedSoilSlip) == 1
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{1};
else
    IndDetToUse = listdlg('PromptString',{'Choose dataset you want to use: ',''}, ...
                          'ListString',FilesDetectedSoilSlip, 'SelectionMode','single');
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDetToUse};
end

if OriginallyProjected && SameCRSForAll
    load('MorphologyParameters.mat', 'OriginalProjCRS')
    ProjCRS = OriginalProjCRS;
else
    EPSG = str2double(inputdlg({["Set DTM EPSG (to calculate polygons)"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
    ProjCRS = projcrs(EPSG);
end
cd(fold0)

DatasetType = "Dataset generated with M-SLIP";
DatasetInformation = table(DatasetType);

%% Date check and uniformization for time sensitive part (rain rules the others)