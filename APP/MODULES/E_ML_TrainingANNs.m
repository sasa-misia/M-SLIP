% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

rng(10) % For reproducibility of the model

%% Loading data and initialization of AnalysisInformation
cd(fold_var)
load('InfoDetectedSoilSlips.mat',    'InfoDetectedSoilSlips','SubArea','FilesDetectedSoilSlip')
load('GridCoordinates.mat',          'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load('StudyAreaVariables.mat',       'StudyAreaPolygon')
load('MorphologyParameters.mat',     'AspectAngleAll','ElevationAll','SlopeAll', ...
                                     'MeanCurvatureAll','ProfileCurvatureAll','PlanformCurvatureAll')
load('FlowRouting.mat',              'ContributingAreaAll','TwiAll')
load('SoilGrids.mat',                'ClayContentAll','SandContentAll','NdviAll')
load('LithoPolygonsStudyArea.mat',   'LithoAllUnique','LithoPolygonsStudyArea')
load('TopSoilPolygonsStudyArea.mat', 'TopSoilAllUnique','TopSoilPolygonsStudyArea')
load('LandUsesVariables.mat',        'AllLandUnique','LandUsePolygonsStudyArea')
load('VegPolygonsStudyArea.mat',     'VegetationAllUnique','VegPolygonsStudyArea')
load('Distances.mat',                'MinDistToRoadAll')
load('RainInterpolated.mat',         'RainInterpolated','RainDateInterpolationStarts')
load('TempInterpolated.mat',         'TempInterpolated','TempDateInterpolationStarts')

if length(FileDetectedSoilSlip) == 1
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{1};
else
    IndDetToUse = listdlg('PromptString',{'Choose dataset you want to use: ',''}, ...
                          'ListString',FilesDetectedSoilSlip, 'SelectionMode','single');
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDetToUse};
end
cd(fold0)

AnalysisType = "ANN Trained in TrainingANNs script";
AnalysisInformation = table(AnalysisType);

ContributingAreaLogAll = cellfun(@(x) log(x), ContributingAreaAll, 'UniformOutput',false);

%% Date check and uniformization for time sensitive part (rain rules the others) MANUAL!
TimeSensitiveParam = {'Rainfall', 'Temperature'}; % First must be always Rainfall!
CumulableParam     = [true      , false        ];
TimeSensitiveData  = {RainInterpolated, TempInterpolated};
TimeSensitiveDate  = {RainDateInterpolationStarts, TempDateInterpolationStarts};
clear('RainInterpolated', 'TempInterpolated')

IndEvent  = listdlg('PromptString',{'Select the date of the instability event:',''}, ...
                    'ListString',RainDateInterpolationStarts, 'SelectionMode','single');
EventDate = RainDateInterpolationStarts(IndEvent);

StartDateCommon = max(cellfun(@min, TimeSensitiveDate));

if length(TimeSensitiveParam) > 1
    for i1 = 1 : length(TimeSensitiveParam)
        IndStartTemp = find(StartDateCommon == TimeSensitiveDate{i1}); % You should put an equal related to days and not exact timing
        IndEventTemp = find(EventDate == TimeSensitiveDate{i1}); % You should put an equal related to days and not exact timing
        TimeSensitiveData{i1} = TimeSensitiveData{i1}(IndStartTemp:IndEventTemp,:);
        TimeSensitiveDate{i1} = TimeSensitiveDate{i1}(IndStartTemp:IndEventTemp);
    end
    if length(TimeSensitiveDate)>1 && ~isequal(TimeSensitiveDate{:})
        error('After uniformization dates of time sensitive data do not match, please check it in the script')
    end
end

TimeSensitiveDate = TimeSensitiveDate{1};

AnalysisInformation.TimeSensitiveParameters = TimeSensitiveParam;
AnalysisInformation.TimeSensitiveCumulableParameters = CumulableParam;
AnalysisInformation.TimeSensitiveDates = TimeSensitiveDate;

%% Extraction of data in study area
ProgressBar.Message      = "Data extraction in study area...";
xLongStudy               = cellfun(@(x,y) x(y), xLongAll                , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy                = cellfun(@(x,y) x(y), yLatAll                 , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
ElevationStudy           = cellfun(@(x,y) x(y), ElevationAll            , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
SlopeStudy               = cellfun(@(x,y) x(y), SlopeAll                , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
AspectStudy              = cellfun(@(x,y) x(y), AspectAngleAll          , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
MeanCurvatureStudy       = cellfun(@(x,y) x(y), MeanCurvatureAll        , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
ProfileCurvatureStudy    = cellfun(@(x,y) x(y), ProfileCurvatureAll     , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
PlanformCurvatureStudy   = cellfun(@(x,y) x(y), PlanformCurvatureAll    , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
ContributingAreaLogStudy = cellfun(@(x,y) x(y), ContributingAreaLogAll  , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
TwiStudy                 = cellfun(@(x,y) x(y), TwiAll                  , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
MinDistToRoadStudy       = cellfun(@(x,y) x(y), MinDistToRoadAll        , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
ClayContentStudy         = cellfun(@(x,y) x(y), ClayContentAll          , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
SandContentStudy         = cellfun(@(x,y) x(y), SandContentAll          , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
NdviStudy                = cellfun(@(x,y) x(y), NdviAll                 , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('ElevationAll', 'SlopeAll', 'AspectAngleAll', 'MeanCurvatureAll', ...
      'ProfileCurvatureAll', 'PlanformCurvatureAll', 'ContributingAreaLogAll', ...
      'TwiAll', 'MinDistToRoadAll', 'ClayContentAll', 'SandContentAll', 'NdviAll')

% Time sensitive part (remember to check index of TimeSensitiveData if you made changes)
TimeSensitiveDataInterpStudy = cell(1, length(TimeSensitiveParam));
for i1 = 1:length(TimeSensitiveParam)
    TimeSensitiveDataInterpStudy{i1} = cellfun(@full, TimeSensitiveData{i1}, 'UniformOutput',false);
end
clear('TimeSensitiveData')

% Concatenation of coordinates
xLongTotCat = cat(1, xLongStudy{:});
yLatTotCat  = cat(1, yLatStudy{:});

yLatMean = mean(yLatTotCat);

%% Creation of classes
Options = {'Categorical classes', 'Numbered classes'};
CategoricalChoice = uiconfirm(Fig, 'How do you want to define classes?', ...
                                   'Classes type', 'Options',Options, 'DefaultOption',2);
if strcmp(CategoricalChoice,'Categorical classes'); CategoricalClasses = true; else; CategoricalClasses = false; end

% Matrices initialization
if CategoricalClasses
    LithoStudy   = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    TopSoilStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    LandUseStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    VegStudy     = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
else
    LithoStudy   = cellfun(@(x) zeros(size(x)), xLongStudy, 'UniformOutput',false);
    TopSoilStudy = cellfun(@(x) zeros(size(x)), xLongStudy, 'UniformOutput',false);
    LandUseStudy = cellfun(@(x) zeros(size(x)), xLongStudy, 'UniformOutput',false);
    VegStudy     = cellfun(@(x) zeros(size(x)), xLongStudy, 'UniformOutput',false);
end

% Litho classes association
ProgressBar.Message = "Associating subsoil classes...";
LithoClasses = readcell('ClassesML.xlsx', 'Sheet','Litho');
for i1 = 1:size(LithoAllUnique,2)
    IndClassLitho = find(strcmp(LithoAllUnique{i1}, string(LithoClasses(:,1))));
    if CategoricalClasses
        if isempty(IndClassLitho); ClassLitho = ""; else; ClassLitho = string(LithoClasses(IndClassLitho, 1)); end
    else
        if isempty(IndClassLitho); ClassLitho = 0; else; ClassLitho = LithoClasses{IndClassLitho, 2}; end
    end
    LUPolygon = LithoPolygonsStudyArea(i1);
    [pp,ee] = getnan2([LUPolygon.Vertices; nan, nan]);
    for i2 = 1:size(xLongAll,2)  
        IndexInsideLithoPolygon = find(inpoly([xLongStudy{i2},yLatStudy{i2}],pp,ee)==1);
        LithoStudy{i2}(IndexInsideLithoPolygon) = ClassLitho;
    end
end

% Top-soil classes association
ProgressBar.Message = "Associating topsoil classes...";
TopSoilClasses = readcell('ClassesML.xlsx', 'Sheet','Top soil');
for i1 = 1:size(TopSoilAllUnique,2)
    IndClassTopSoil = find(strcmp(TopSoilAllUnique{i1}, string(TopSoilClasses(:,1))));
    if CategoricalClasses
        if isempty(IndClassTopSoil); ClassTopSoil = ""; else; ClassTopSoil = string(TopSoilClasses(IndClassTopSoil, 1)); end
    else
        if isempty(IndClassTopSoil); ClassTopSoil = 0; else; ClassTopSoil = TopSoilClasses{IndClassTopSoil, 2}; end
    end
    TSUPolygon = TopSoilPolygonsStudyArea(i1);
    [pp,ee] = getnan2([TSUPolygon.Vertices; nan, nan]);
    for i2 = 1:size(xLongAll,2)  
        IndexInsideTopSoilPolygon = find(inpoly([xLongStudy{i2},yLatStudy{i2}],pp,ee)==1);
        TopSoilStudy{i2}(IndexInsideTopSoilPolygon) = ClassTopSoil;
    end
end

% Land use classes association
ProgressBar.Message = "Associating land use classes...";
LandUseClasses = readcell('ClassesML.xlsx', 'Sheet','Land use');
for i1 = 1:size(AllLandUnique,2)
    IndClassLand = find(strcmp(AllLandUnique{i1}, string(LandUseClasses(:,1))));
    if CategoricalClasses
        if isempty(IndClassLand); ClassLandUse = ""; else; ClassLandUse = string(LandUseClasses(IndClassLand, 1)); end
    else
        if isempty(IndClassLand); ClassLandUse = 0; else; ClassLandUse = LandUseClasses{IndClassLand, 2}; end
    end
    LandUsePolygon = LandUsePolygonsStudyArea(i1);
    [pp,ee] = getnan2([LandUsePolygon.Vertices; nan, nan]);
    for i2 = 1:size(xLongAll,2)  
        IndexInsideLandUsePolygon = find(inpoly([xLongStudy{i2},yLatStudy{i2}],pp,ee)==1);
        LandUseStudy{i2}(IndexInsideLandUsePolygon) = ClassLandUse;
    end
end

% Veg classes association
ProgressBar.Message = "Associating vegetation classes...";
VegClasses = readcell('ClassesML.xlsx', 'Sheet','Veg');
for i1 = 1:size(VegetationAllUnique,2)
    IndClassVeg = find(strcmp(VegetationAllUnique{i1}, string(VegClasses(:,1))));
    if CategoricalClasses
        if isempty(IndClassVeg); ClassVeg = ""; else; ClassVeg = string(VegClasses(IndClassVeg, 1)); end
    else
        if isempty(IndClassVeg); ClassVeg = 0; else; ClassVeg = VegClasses{IndClassVeg, 2}; end
    end
    VUPolygon = VegPolygonsStudyArea(i1);
    [pp_veg,ee_veg] = getnan2([VUPolygon.Vertices; nan, nan]);
    for i2 = 1:size(xLongAll,2)  
        IndexInsideVegPolygon = find(inpoly([xLongStudy{i2},yLatStudy{i2}],pp_veg,ee_veg)==1);
        VegStudy{i2}(IndexInsideVegPolygon) = ClassVeg;
    end
end

AnalysisInformation.CategoricalClasses = CategoricalClasses;

%% Table soil creation
ProgressBar.Message = "Creating table normalized...";
ConditioningFactorsNames = {'Slope', 'Aspect', 'Elevation', 'MeanCurvature', 'ProfileCurvature', 'PlanformCurvature', ...
                            'ContributingAreaLog', 'Twi', 'MinDistanceRoads', 'ClayContent', 'SandContent', 'NDVI', ...
                            'Lithology', 'TopSoil', 'LandUse', 'Vegetation'};

NonCategorizablePart = 12; % TO CHANGE MANUALLY!

DatasetTable = table( cat(1,SlopeStudy{:})               , ...
                      cat(1,AspectStudy{:})              , ...
                      cat(1,ElevationStudy{:})           , ...
                      cat(1,MeanCurvatureStudy{:})       , ...
                      cat(1,ProfileCurvatureStudy{:})    , ...
                      cat(1,PlanformCurvatureStudy{:})   , ...
                      cat(1,ContributingAreaLogStudy{:}) , ...
                      cat(1,TwiStudy{:})                 , ...
                      cat(1,MinDistToRoadStudy{:})       , ...
                      cat(1,ClayContentStudy{:})         , ...
                      cat(1,SandContentStudy{:})         , ...
                      cat(1,NdviStudy{:})                , ...
                      cat(1,LithoStudy{:})               , ...
                      cat(1,TopSoilStudy{:})             , ...
                      cat(1,LandUseStudy{:})             , ...
                      cat(1,VegStudy{:})                 , ...
                      'VariableNames',ConditioningFactorsNames );

DatasetQuants   = cell(1, size(DatasetTable, 2));
DatasetExtremes = cell(2, size(DatasetTable, 2));
for i1 = 1:size(DatasetTable, 2)
    DatasetQuants{i1}       = quantile(DatasetTable{:,i1},[0.25, 0.75]);
    DatasetExtremes(:,i1)   = {min(DatasetTable{:,i1}); max(DatasetTable{:,i1})};
end

ShowSummaryFig = false;
BoxsForPlot = [4, 3]; % TO CHANGE MANUALLY!
if ShowSummaryFig
    fig_boxplot = figure(1);
    for i1 = 1:NonCategorizablePart
        ax_boxplot = subplot(BoxsForPlot(1),BoxsForPlot(2),i1);
        boxplot(ax_boxplot, DatasetTable{:,i1}, ConditioningFactorsNames(i1), ...
                                'Notch','on', 'OutlierSize',4, 'Symbol',['.'; 'm']);
    end
    
    fig_cdf = figure(2);
    for i1 = 1:NonCategorizablePart
        subplot(BoxsForPlot(1),BoxsForPlot(2),i1);
        cdfplot(DatasetTable{:,i1});
        xline(DatasetQuants{i1}(1), '--r', num2str(round(DatasetQuants{i1}(1), 3)), ...
                            'LabelVerticalAlignment','bottom', 'LabelHorizontalAlignment','left');
        xline(DatasetQuants{i1}(2), '--r', num2str(round(DatasetQuants{i1}(2), 3)), ...
                            'LabelVerticalAlignment','top', 'LabelHorizontalAlignment','right');
        xlabel('Values')
        ylabel('Cum. freq.')
        title(ConditioningFactorsNames(i1))
    end
end

%% Normalized Table soil creation
RangesInput = inputdlg( ["Ranges for slope:                 "
                         "Ranges for aspect:                "
                         "Ranges for elevation:             "
                         "Ranges for mean curvature:        "
                         "Ranges for profile curvature:     "
                         "Ranges for planform curvature:    "
                         "Ranges for contributing area log: "
                         "Ranges for twi:                   "
                         "Ranges for min distance to roads: "
                         "Ranges for clay content:          "
                         "Ranges for sand content:          "
                         "Ranges for NDVI:                  "], '', 1, ...
                        {'[0, 80]'
                         '[0, 360]'
                         '[0, 2000]'
                         '[-0.03, 0.03]'
                         '[-0.03, 0.03]'
                         '[-0.03, 0.03]'
                         '[4, 20]'
                         '[3, 28]'
                         '[0, 5000]'
                         '[0, 1000]'
                         '[0, 1000]'
                         '[-10000, 10000]'} );

RangesForNorm = [ str2num(RangesInput{1})       % Slope
                  str2num(RangesInput{2})       % Aspect
                  str2num(RangesInput{3})       % Elevation
                  str2num(RangesInput{4})       % Mean Curvature
                  str2num(RangesInput{5})       % Profile Curvature
                  str2num(RangesInput{6})       % Planform Curvature
                  str2num(RangesInput{7})       % Contributing Area Log
                  str2num(RangesInput{8})       % Twi
                  str2num(RangesInput{9})       % Min Distance to road
                  str2num(RangesInput{10})      % Clay content
                  str2num(RangesInput{11})      % Sand content
                  str2num(RangesInput{12}) ];   % NDVI

DatasetTableNorm = table( rescale(cat(1,SlopeStudy{:})               , 'InputMin',RangesForNorm(1 ,1),    'InputMax',RangesForNorm(1 ,2)), ...
                          rescale(cat(1,AspectStudy{:})              , 'InputMin',RangesForNorm(2 ,1),    'InputMax',RangesForNorm(2 ,2)), ...
                          rescale(cat(1,ElevationStudy{:})           , 'InputMin',RangesForNorm(3 ,1),    'InputMax',RangesForNorm(3 ,2)), ...
                          rescale(cat(1,MeanCurvatureStudy{:})       , 'InputMin',RangesForNorm(4 ,1),    'InputMax',RangesForNorm(4 ,2)), ...
                          rescale(cat(1,ProfileCurvatureStudy{:})    , 'InputMin',RangesForNorm(5 ,1),    'InputMax',RangesForNorm(5 ,2)), ...
                          rescale(cat(1,PlanformCurvatureStudy{:})   , 'InputMin',RangesForNorm(6 ,1),    'InputMax',RangesForNorm(6 ,2)), ...
                          rescale(cat(1,ContributingAreaLogStudy{:}) , 'InputMin',RangesForNorm(7 ,1),    'InputMax',RangesForNorm(7 ,2)), ...
                          rescale(cat(1,TwiStudy{:})                 , 'InputMin',RangesForNorm(8 ,1),    'InputMax',RangesForNorm(8 ,2)), ...
                          rescale(cat(1,MinDistToRoadStudy{:})       , 'InputMin',RangesForNorm(9 ,1),    'InputMax',RangesForNorm(9 ,2)), ...
                          rescale(cat(1,ClayContentStudy{:})         , 'InputMin',RangesForNorm(10,1),    'InputMax',RangesForNorm(10,2)), ...
                          rescale(cat(1,SandContentStudy{:})         , 'InputMin',RangesForNorm(11,1),    'InputMax',RangesForNorm(11,2)), ...
                          rescale(cat(1,NdviStudy{:})                , 'InputMin',RangesForNorm(12,1),    'InputMax',RangesForNorm(12,2)), ...
                          'VariableNames',ConditioningFactorsNames(1:NonCategorizablePart) );

if size(RangesForNorm, 1) ~= NonCategorizablePart || size(DatasetTableNorm, 2) ~= NonCategorizablePart
    error('Sizes of RangesForNorm or DatasetTableNorm do not match with the non categorizable part')
end

if CategoricalClasses   
    RangesForNorm = [ RangesForNorm  ;      % Pre-existing
                      nan    ,   nan ;      % Litho (Subsoil) classes
                      nan    ,   nan ;      % Topsoil classes
                      nan    ,   nan ;      % Land Use classes
                      nan    ,   nan  ];    % Vegetation classes

    DatasetTableNorm = [ DatasetTableNorm, ...
                         table( cat(1,LithoStudy{:})   , ...
                                cat(1,TopSoilStudy{:}) , ...
                                cat(1,LandUseStudy{:}) , ...
                                cat(1,VegStudy{:})     , ...
                                'VariableNames',ConditioningFactorsNames(NonCategorizablePart+1 : end) ) ]; % Horizontal concatenation
else
    RangesForNorm = [ RangesForNorm  ;      % Pre-existing
                      0      ,   12  ;      % Litho (Subsoil) classes
                      0      ,   120 ;      % Topsoil classes
                      0      ,   70  ;      % Land Use classes
                      0      ,   80   ];    % Vegetation classes

    DatasetTableNorm = [ DatasetTableNorm, ...
                         table( rescale(cat(1,LithoStudy{:})   , 'InputMin',RangesForNorm(13,1), 'InputMax',RangesForNorm(13,2)), ...
                                rescale(cat(1,TopSoilStudy{:}) , 'InputMin',RangesForNorm(14,1), 'InputMax',RangesForNorm(14,2)), ...
                                rescale(cat(1,LandUseStudy{:}) , 'InputMin',RangesForNorm(15,1), 'InputMax',RangesForNorm(15,2)), ...
                                rescale(cat(1,VegStudy{:})     , 'InputMin',RangesForNorm(16,1), 'InputMax',RangesForNorm(16,2)), ...
                                'VariableNames',ConditioningFactorsNames(NonCategorizablePart+1 : end) ) ]; % Horizontal concatenation
end

%% Categorical vector if you mantain string classes
if CategoricalClasses
    DatasetTableNorm.Lithology  = categorical(DatasetTableNorm.Lithology, ...
                                              string(LithoClasses(:,1)), 'Ordinal',true);

    DatasetTableNorm.TopSoil    = categorical(DatasetTableNorm.TopSoil, ...
                                              string(TopSoilClasses(:,1)), 'Ordinal',true);
    
    DatasetTableNorm.Vegetation = categorical(DatasetTableNorm.Vegetation, ...
                                              string(VegClasses(:,1)), 'Ordinal',true);

    DatasetTableNorm.LandUse    = categorical(DatasetTableNorm.LandUse, ...
                                              string(LandUseClasses(:,1)), 'Ordinal',true);
end

%% Creation of a copy at different time and copy to mantain with all points
DatasetTableStudy     = DatasetTable;
DatasetTableStudyNorm = DatasetTableNorm;
DatasetCoordinates    = table(xLongTotCat, yLatTotCat);
DatasetCoordinates.Properties.VariableNames = {'Longitude', 'Latitude'};

Options = {'Yes', 'No, only a single day'};
MultipleDayChoice = uiconfirm(Fig, 'Do you want to perform analyses in different days?', ...
                                   'Time sensitive analyses', 'Options',Options, 'DefaultOption',2);
if strcmp(MultipleDayChoice,'Yes'); MultipleDayAnalysis = true; else; MultipleDayAnalysis = false; end

AnalysisInformation.MultipleDayAnalysis = MultipleDayAnalysis;

if MultipleDayAnalysis
    xLongTotCatToAdd      = xLongTotCat;
    yLatTotCatToAdd       = yLatTotCat;
    DatasetTableToAdd     = DatasetTable;
    DatasetTableNormToAdd = DatasetTableNorm;
end

%% Creation of positive points (landslide occurred)
if SubArea
    Options = {'PolygonsDetSS', 'Manual'};
    PolyCreationMode = uiconfirm(Fig, 'How do you want to define polygons where a landslide is detected?', ...
                                      'Soil Slip Polygons', 'Options',Options, 'DefaultOption',1);
else
    PolyCreationMode = 'Manual';
end

AnalysisInformation.PolygonCreationMode   = PolyCreationMode;

switch PolyCreationMode
    case 'PolygonDetSS'
        load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlipsAverage')

        InputsSizeWindows = str2double(inputdlg(["Size of the buffer to define indecision area [m]"
                                                 "Size of the buffer to define stable area [m]"    ], ...
                                                 '', 1, {'50', '250'}));

        BufferIndecision = InputsSizeWindows(1);
        BufferMaxExt     = InputsSizeWindows(2);

        PolUnstabPoints = InfoDetectedSoilSlipsAverage{IndDetToUse}{1};
        clear('InfoDetectedSoilSlipsAverage')

        [PolUnstabCoordPlanX, PolUnstabCoordPlanY] = arrayfun(@(x) projfwd(ProjCRS,x.Vertices(:,2),x.Vertices(:,1)), PolUnstabPoints, 'UniformOutput',false);
        PolUnstabPointsPlan = cellfun(@(x,y) polyshape(x,y, 'Simplify',false), PolUnstabCoordPlanX, PolUnstabCoordPlanY); % This conversion is necessary because otherwise buffer is not correct (Long is different from Lat)
        PolIndecisionAroundDetGrossPlan = polybuffer(PolUnstabPointsPlan, BufferIndecision);
        PolMaxExtAroundDetPlan          = polybuffer(PolUnstabPointsPlan, BufferMaxExt);

        [PolIndecisionGrossLat, PolIndecisionGrossLong] = arrayfun(@(x) projinv(ProjCRS,x.Vertices(:,1),x.Vertices(:,2)), ...
                                                                        PolIndecisionAroundDetGrossPlan, 'UniformOutput',false);
        [PolMaxExtLat,          PolMaxExtLong         ] = arrayfun(@(x) projinv(ProjCRS,x.Vertices(:,1),x.Vertices(:,2)), ...
                                                                        PolMaxExtAroundDetPlan, 'UniformOutput',false);

        PolIndecisionAroundDetGross = cellfun(@(x,y) polyshape(x,y, 'Simplify',false), PolIndecisionGrossLong, PolIndecisionGrossLat);
        PolMaxExtAroundDet          = cellfun(@(x,y) polyshape(x,y, 'Simplify',false), PolMaxExtLong,          PolMaxExtLat);

        AnalysisInformation.BufferForIndecisionArea = BufferIndecision;
        AnalysisInformation.BufferForMaxAreaVisible = BufferMaxExt;

    case 'Manual'
        ProgressBar.Message = "Defining polygon sizes for stable and unstable areas...";
        InputsSizeWindows = str2double(inputdlg(["Size of the window side where are located unstable points"
                                                 "Size of the window side to define indecision area"
                                                 "Size of the window side to define stable area"            ], ...
                                                 '', 1, {'45', '200', '300'}));

        PolyCreationCoordType = 'Planar'; % CHOICE TO USER!!!       
        switch PolyCreationCoordType
            case 'Geographic'
                % Polygons around detected soil slips (you will attribute certain event)
                SizeForUnstPoints = InputsSizeWindows(1); % This is the size in meters around the detected soil slip
                dLatUnstPoints    = rad2deg(SizeForUnstPoints/2/earthRadius); % /2 to have half of the size from the centre
                dLongUnstPoints   = rad2deg(acos( (cos(SizeForUnstPoints/2/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % /2 to have half of the size from the centre
                BoundUnstabPoints = [cellfun(@(x) x-dLongUnstPoints, InfoDetectedSoilSlipsToUse(:,5)), ...
                                     cellfun(@(x) x-dLatUnstPoints,  InfoDetectedSoilSlipsToUse(:,6)), ...
                                     cellfun(@(x) x+dLongUnstPoints, InfoDetectedSoilSlipsToUse(:,5)), ...
                                     cellfun(@(x) x+dLatUnstPoints,  InfoDetectedSoilSlipsToUse(:,6))];
                
                % Polygons around detected soil slips (polygon where you are uncertain because landslide could be greater than 45x45)
                SizeForIndecisionAroundDet  = InputsSizeWindows(2); % This is the size in meters around the detected soil slip
                dLatIndecisionAround        = rad2deg(SizeForIndecisionAroundDet/2/earthRadius); % /2 to have half of the size from the centre
                dLongIndecisionAround       = rad2deg(acos( (cos(SizeForIndecisionAroundDet/2/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % /2 to have half of the size from the centre
                BoundIndecisionAroundDet    = [cellfun(@(x) x-dLongIndecisionAround, InfoDetectedSoilSlipsToUse(:,5)), ...
                                               cellfun(@(x) x-dLatIndecisionAround,  InfoDetectedSoilSlipsToUse(:,6)), ...
                                               cellfun(@(x) x+dLongIndecisionAround, InfoDetectedSoilSlipsToUse(:,5)), ...
                                               cellfun(@(x) x+dLatIndecisionAround,  InfoDetectedSoilSlipsToUse(:,6))];
                
                % Polygons around detected soil slips (max polygon visible by human)
                SizeForMaxExtAroundDet = InputsSizeWindows(3); % This is the size in meters around the detected soil slip
                dLatMaxAround          = rad2deg(SizeForMaxExtAroundDet/2/earthRadius); % /2 to have half of the size from the centre
                dLongMaxAround         = rad2deg(acos( (cos(SizeForMaxExtAroundDet/2/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % /2 to have half of the size from the centre
                BoundMaxExtAroundDet   = [cellfun(@(x) x-dLongMaxAround, InfoDetectedSoilSlipsToUse(:,5)), ...
                                          cellfun(@(x) x-dLatMaxAround,  InfoDetectedSoilSlipsToUse(:,6)), ...
                                          cellfun(@(x) x+dLongMaxAround, InfoDetectedSoilSlipsToUse(:,5)), ...
                                          cellfun(@(x) x+dLatMaxAround,  InfoDetectedSoilSlipsToUse(:,6))];
        
            case 'Planar'
                InfoDetectedSoilSlipsToUsePlan = zeros(size(InfoDetectedSoilSlipsToUse,1), 2);    
                [InfoDetectedSoilSlipsToUsePlan(:,1), InfoDetectedSoilSlipsToUsePlan(:,2)] = ...
                                projfwd(ProjCRS, [InfoDetectedSoilSlipsToUse{:,6}]', [InfoDetectedSoilSlipsToUse{:,5}]');
                InfoDetectedSoilSlipsToUsePlan = num2cell(InfoDetectedSoilSlipsToUsePlan);
        
                % Polygons around detected soil slips (you will attribute certain event)
                SizeForUnstPoints     = InputsSizeWindows(1); % This is the size in meters around the detected soil slip
                dXUnstPoints          = SizeForUnstPoints/2; % /2 to have half of the size from the centre
                dYUnstPoints          = dXUnstPoints;
                BoundUnstabPointsPlan = [cellfun(@(x) x-dXUnstPoints, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                         cellfun(@(x) x-dYUnstPoints, InfoDetectedSoilSlipsToUsePlan(:,2)), ...
                                         cellfun(@(x) x+dXUnstPoints, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                         cellfun(@(x) x+dYUnstPoints, InfoDetectedSoilSlipsToUsePlan(:,2))];
                [BoundUnstabPoints(:,2), BoundUnstabPoints(:,1)] = projinv(ProjCRS, BoundUnstabPointsPlan(:,1), BoundUnstabPointsPlan(:,2));
                [BoundUnstabPoints(:,4), BoundUnstabPoints(:,3)] = projinv(ProjCRS, BoundUnstabPointsPlan(:,3), BoundUnstabPointsPlan(:,4));
                
                % Polygons around detected soil slips (polygon where you are uncertain because landslide could be greater than 45x45)
                SizeForIndecisionAroundDet   = InputsSizeWindows(2); % This is the size in meters around the detected soil slip
                dXIndecisionAround           = SizeForIndecisionAroundDet/2; % /2 to have half of the size from the centre
                dYIndecisionAround           = dXIndecisionAround;
                BoundIndecisionAroundDetPlan = [cellfun(@(x) x-dXIndecisionAround, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                                cellfun(@(x) x-dYIndecisionAround, InfoDetectedSoilSlipsToUsePlan(:,2)), ...
                                                cellfun(@(x) x+dXIndecisionAround, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                                cellfun(@(x) x+dYIndecisionAround, InfoDetectedSoilSlipsToUsePlan(:,2))];
                [BoundIndecisionAroundDet(:,2), BoundIndecisionAroundDet(:,1)] = projinv(ProjCRS, BoundIndecisionAroundDetPlan(:,1), BoundIndecisionAroundDetPlan(:,2));
                [BoundIndecisionAroundDet(:,4), BoundIndecisionAroundDet(:,3)] = projinv(ProjCRS, BoundIndecisionAroundDetPlan(:,3), BoundIndecisionAroundDetPlan(:,4));
                
                % Polygons around detected soil slips (max polygon visible by human)
                SizeForMaxExtAroundDet   = InputsSizeWindows(3); % This is the size in meters around the detected soil slip
                dXMaxAround              = SizeForMaxExtAroundDet/2; % /2 to have half of the size from the centre
                dYMaxAround              = dXMaxAround;
                BoundMaxExtAroundDetPlan = [cellfun(@(x) x-dXMaxAround, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                            cellfun(@(x) x-dYMaxAround, InfoDetectedSoilSlipsToUsePlan(:,2)), ...
                                            cellfun(@(x) x+dXMaxAround, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                            cellfun(@(x) x+dYMaxAround, InfoDetectedSoilSlipsToUsePlan(:,2))];
                [BoundMaxExtAroundDet(:,2), BoundMaxExtAroundDet(:,1)] = projinv(ProjCRS, BoundMaxExtAroundDetPlan(:,1), BoundMaxExtAroundDetPlan(:,2));
                [BoundMaxExtAroundDet(:,4), BoundMaxExtAroundDet(:,3)] = projinv(ProjCRS, BoundMaxExtAroundDetPlan(:,3), BoundMaxExtAroundDetPlan(:,4));
        end
        
        % Polygons around detected soil slips (you will attribute certain event)
        PolUnstabPoints             = arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]), ...
                                                                 BoundUnstabPoints(:,1), ...
                                                                 BoundUnstabPoints(:,3), ...
                                                                 BoundUnstabPoints(:,2), ...
                                                                 BoundUnstabPoints(:,4));
        
        % Polygons around detected soil slips (polygon where you are uncertain because landslide could be greater than 45x45)
        PolIndecisionAroundDetGross = arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]), ...
                                                                 BoundIndecisionAroundDet(:,1), ...
                                                                 BoundIndecisionAroundDet(:,3), ...
                                                                 BoundIndecisionAroundDet(:,2), ...
                                                                 BoundIndecisionAroundDet(:,4));
        
        % Polygons around detected soil slips (max polygon visible by human)
        PolMaxExtAroundDet          = arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]), ...
                                                                 BoundMaxExtAroundDet(:,1), ...
                                                                 BoundMaxExtAroundDet(:,3), ...
                                                                 BoundMaxExtAroundDet(:,2), ...
                                                                 BoundMaxExtAroundDet(:,4));
        
        AnalysisInformation.PolyCreationCoordType = PolyCreationCoordType;
        AnalysisInformation.SizeForUnstablePoints = SizeForUnstPoints;
        AnalysisInformation.SizeForIndecisionArea = SizeForIndecisionAroundDet;
        AnalysisInformation.SizeForMaxAreaVisible = SizeForMaxExtAroundDet;
end

%% Union and subtraction of polygons
TotPolUnstabPoints             = union(PolUnstabPoints);
TotPolIndecisionAroundDetGross = union(PolIndecisionAroundDetGross);
TotPolMaxExtAroundDet          = union(PolMaxExtAroundDet);
TotPolIndecision               = subtract(TotPolIndecisionAroundDetGross, TotPolUnstabPoints);
TotPolUncStable                = subtract(TotPolMaxExtAroundDet, TotPolIndecisionAroundDetGross);

%% Index of study area points inside polygons
[pp1, ee1] = getnan2([TotPolUnstabPoints.Vertices; nan, nan]);
IndFrstPartPoint = cellfun(@(x,y) find(inpoly([x,y], pp1,ee1)), xLongStudy, yLatStudy, 'UniformOutput',false);

[pp2, ee2] = getnan2([TotPolUncStable.Vertices; nan, nan]);
IndStabPartPoint = cellfun(@(x,y) find(inpoly([x,y], pp2,ee2)), xLongStudy, yLatStudy, 'UniformOutput',false);

%% Definition of unconditionally stable points and reduction of tables
ProgressBar.Message = "Defining unconditionally stable areas...";
Options = {'Slope', 'VisibleWindow'};
UncondStablePointsApproach  = uiconfirm(Fig, 'How do you want to define unconditionally stable points?', ...
                                             'Unconditionally stable', 'Options',Options, 'DefaultOption',2);
switch UncondStablePointsApproach
    case 'Slope'
        CriticalSlope = str2double(inputdlg({["Choose the critical slope below which"
                                              "you have unconditionally stable points."]}, '', 1, {'10'}));
        CriticalSlopeScaled = rescale(CriticalSlope, 'InputMin',0, 'InputMax',80);
        LogIndPointsAboveCriticalSlope = DatasetTableNorm{:,1} > CriticalSlopeScaled; % Index of column 1 because slope in in the first column

        OutputStudy = cellfun(@(x) zeros(size(x)), xLongStudy, 'UniformOutput',false);
        for i2 = 1:size(OutputStudy,2)
            OutputStudy{i2}(IndFrstPartPoint{i2}) = 1;
        end

        OutputCat = cat(1,OutputStudy{:});

        IndToRemove1 = find(LogIndPointsAboveCriticalSlope & not(OutputCat));
        
    case 'VisibleWindow'
        OutputStudy = cellfun(@(x) nan(size(x)), xLongStudy, 'UniformOutput',false);
        for i2 = 1:size(OutputStudy,2)
            OutputStudy{i2}(IndFrstPartPoint{i2}) = 1;
            OutputStudy{i2}(IndStabPartPoint{i2}) = 0;
        end

        OutputCat = cat(1,OutputStudy{:});

        IndToRemove1 = find(isnan(OutputCat));
end

AnalysisInformation.UnconditionallyStableApproach = UncondStablePointsApproach;

DatasetTable(IndToRemove1,:)       = [];
DatasetTableNorm(IndToRemove1,:)   = [];
OutputCat(IndToRemove1)            = [];
xLongTotCat(IndToRemove1)          = [];
yLatTotCat(IndToRemove1)           = [];

Options = {'Yes', 'No'};
ModifyRatioChoice  = uiconfirm(Fig, 'Do you want to modify ratio of positive and negative points?', ...
                                    'Ratio Pos to Neg', 'Options',Options, 'DefaultOption',1);
if strcmp(ModifyRatioChoice,'Yes'); ModifyRatioPosNeg = true; else; ModifyRatioPosNeg = false; end

AnalysisInformation.RatioPosToNegModified = ModifyRatioPosNeg;

if ModifyRatioPosNeg
    IndOutPos   = find(OutputCat==1);
    IndOutNeg   = find(OutputCat==0);
    RatioPosNeg = length(IndOutPos)/length(IndOutNeg);

    RatioInputs  = str2double(inputdlg(["Choose part of positive: ", "Choose part of negative: "], '', 1, {'1', '2'}));
    OptimalRatio = RatioInputs(1)/RatioInputs(2);
    PercToRemove = 1-RatioPosNeg/OptimalRatio;

    IndOfIndOutNegToRemove = randperm(numel(IndOutNeg), ceil(numel(IndOutNeg)*PercToRemove));
    IndToRemove2 = IndOutNeg(IndOfIndOutNegToRemove);

    DatasetTable(IndToRemove2,:)       = [];
    DatasetTableNorm(IndToRemove2,:)   = [];
    OutputCat(IndToRemove2)            = [];
    xLongTotCat(IndToRemove2)          = [];
    yLatTotCat(IndToRemove2)           = [];

    IndOutPosNew   = find(OutputCat==1);
    IndOutNegNew   = find(OutputCat==0);
    RatioPosNegNew = length(IndOutPosNew)/length(IndOutNegNew);
    if (numel(IndOutPosNew) ~= numel(IndOutPos)) || (round(OptimalRatio, 1) ~= round(RatioPosNegNew, 1))
        error("Something went wrong in re-attributing the correct ratio between positive and negative outputs!")
    end

    AnalysisInformation.RatioPosToNeg = RatioPosNegNew;
end

%% Creation of a copy at different time
if MultipleDayAnalysis
    DatasetTableToAdd(IndToRemove1,:)     = [];
    DatasetTableNormToAdd(IndToRemove1,:) = [];
    OutputCatToAdd                        = zeros(size(OutputCat)); % At this particular timing prediction should be 0! (no landslide)
    xLongTotCatToAdd(IndToRemove1)        = [];
    yLatTotCatToAdd(IndToRemove1)         = [];
    if ModifyRatioPosNeg
        DatasetTableToAdd(IndToRemove2,:)     = [];
        DatasetTableNormToAdd(IndToRemove2,:) = [];
        OutputCatToAdd                        = zeros(size(OutputCat));
        xLongTotCatToAdd(IndToRemove2)        = [];
        yLatTotCatToAdd(IndToRemove2)         = [];
    end
end

%% Loop for ANN models (different rainfall time)
ProgressBar.Indeterminate = 'off';

if MultipleDayAnalysis
    ProgressBar.Message = "Starting ANNs creation...";
    DaysBeforeEventWhenStable = str2double(inputdlg({["Please specify how many days before the event you want "
                                                      "to consider all points as stable."
                                                      strcat("(You have ",string(length(TimeSensitiveDate))," days of cumulate rainfalls)")]}, ...
                                                      '', 1, {'10'}));

    if (length(TimeSensitiveDate)-DaysBeforeEventWhenStable) <= 0
        error('You have to select another day for stable points, more forward in time than the start of your dataset')
    end

    AnalysisInformation.DayBeforeEventForStablePoints = DaysBeforeEventWhenStable;

    if ModifyRatioPosNeg
        Options = {'Yes', 'No'};
        MantainUnstabChoice  = uiconfirm(Fig, ['Do you want to mantain points where there is instability ' ...
                                               'even in the day when all points are stable? ' ...
                                               '(these points will be mantained during the merge and ' ...
                                               'the subsequent ratio adjustment)'], ...
                                               'Mantain unstable points', 'Options',Options, 'DefaultOption',1);
        if strcmp(MantainUnstabChoice,'Yes'); MantainPointsUnstab = true; else; MantainPointsUnstab = false; end

        AnalysisInformation.UnstablePointsMantainedInDayOfStable = MantainPointsUnstab;
    end
end

Options = {'SeparateDailyCumulate', 'SingleCumulate'};
RainfallMethod  = uiconfirm(Fig, 'How do you want to built the topology of your neural network?', ...
                                 'Neural network topology', 'Options',Options, 'DefaultOption',2);
AnalysisInformation.RainfallMethod = RainfallMethod;
switch RainfallMethod
    case 'SeparateDailyCumulate'
        Options = {'With Validation Data', 'Auto', 'Normal'};
        ANNMode  = uiconfirm(Fig, 'How do you want to built your neural network?', ...
                                  'Neural network choice', 'Options',Options, 'DefaultOption',2);

        LayerActivation = 'sigmoid'; % CHOICE TO USER!
        Standardize     = true;      % CHOICE TO USER!

        StructureInput  = inputdlg("Number of nuerons in each hidden: ", '', 1, {'[60, 20]'});
        LayerSize       = str2num(StructureInput{1});

        NumOfDayToConsider = 15; % CHOICE TO USER!!!
        ANNModels = cell(12, NumOfDayToConsider);
        AnalysisInformation.MaxDaysConsidered = NumOfDayToConsider;
        AnalysisInformation.ANNMode           = ANNMode;
        for i1 = 1:NumOfDayToConsider
            ProgressBar.Value = i1/NumOfDayToConsider;
            ProgressBar.Message = strcat("Training model n. ", string(i1)," of ", string(NumOfDayToConsider));
        
            %% Addition in table of time sensitive parameters
            ConditioningFactorToAdd  = cellfun(@(x) [x,'-',num2str(i1)], TimeSensitiveParam, 'UniformOutput',false);
            ConditioningFactorsNames = [ConditioningFactorsNames, ConditioningFactorToAdd];

            RowToTake   = length(TimeSensitiveDate)-i1+1;
            ColumnToAdd = cellfun(@(x) cat(1,x{RowToTake,:}), TimeSensitiveDataInterpStudy, 'UniformOutput',false);

            RangesForNorm = [ RangesForNorm  ;      % Pre-existing
                               0    ,   120  ;      % Cumulative daily rainfall (to discuss this value, max was 134 mm in a day for Emilia Romagna)
                              -10   ,   40    ];    % Mean daily temperature (to discuss this value)

            ColumnToAddTable     = table( ColumnToAdd{:}, 'VariableNames',ConditioningFactorsNames(end-length(TimeSensitiveParam)+1 : end) );
            ColumnToAddTableNorm = array2table(rescale([ColumnToAdd{:}], ...
                                                        'InputMin',RangesForNorm(end-length(TimeSensitiveParam)+1 : end,1)', ...  % Must be a row
                                                        'InputMax',RangesForNorm(end-length(TimeSensitiveParam)+1 : end,2)'), ... % Must be a row
                                                    'VariableNames',ConditioningFactorsNames(end-length(TimeSensitiveParam)+1 : end));

            DatasetTableStudy     = [DatasetTableStudy    , ColumnToAddTable    ]; % Horizontal concatenation
            DatasetTableStudyNorm = [DatasetTableStudyNorm, ColumnToAddTableNorm]; % Horizontal concatenation

            ColumnToAddTable(IndToRemove1,:)     = [];
            ColumnToAddTableNorm(IndToRemove1,:) = [];
            if ModifyRatioPosNeg
                ColumnToAddTable(IndToRemove2,:)     = []; 
                ColumnToAddTableNorm(IndToRemove2,:) = []; 
            end

            DatasetTable     = [DatasetTable    , ColumnToAddTable    ];
            DatasetTableNorm = [DatasetTableNorm, ColumnToAddTableNorm];

            %% Addition of points at different time
            if MultipleDayAnalysis
                RowToTakeAtDiffTime = RowToTake-DaysBeforeEventWhenStable;
                ColumnToAddAtDiffTime = cellfun(@(x) cat(1,x{RowToTakeAtDiffTime,:}), TimeSensitiveDataInterpStudy, 'UniformOutput',false);
                
                ColumnToAddTableAtDiffTime     = table( ColumnToAddAtDiffTime{:}, 'VariableNames',ConditioningFactorsNames(end-length(TimeSensitiveParam)+1 : end) );
                ColumnToAddTableAtDiffTimeNorm = array2table(rescale([ColumnToAddAtDiffTime{:}], ...
                                                                      'InputMin',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 1)', ...  % Must be a row
                                                                      'InputMax',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 2)'), ... % Must be a row
                                                                  'VariableNames',ConditioningFactorsNames(end-length(TimeSensitiveParam)+1 : end));

                ColumnToAddTableAtDiffTime(IndToRemove1,:)     = [];
                ColumnToAddTableAtDiffTimeNorm(IndToRemove1,:) = [];
                if ModifyRatioPosNeg
                    ColumnToAddTableAtDiffTime(IndToRemove2,:)     = []; 
                    ColumnToAddTableAtDiffTimeNorm(IndToRemove2,:) = []; 
                end

                DatasetTableToAdd     = [DatasetTableToAdd    , ColumnToAddTableAtDiffTime    ];
                DatasetTableNormToAdd = [DatasetTableNormToAdd, ColumnToAddTableAtDiffTimeNorm];

                DatasetTableToUse     = [DatasetTable;     DatasetTableToAdd];
                DatasetTableNormToUse = [DatasetTableNorm; DatasetTableNormToAdd];
                OutputCatToUse        = [OutputCat;        OutputCatToAdd];
                xLongTotCatToUse      = [xLongTotCat;      xLongTotCatToAdd];
                yLatTotCatToUse       = [yLatTotCat;       yLatTotCatToAdd];

                if ModifyRatioPosNeg
                    IndOutPos   = find(OutputCatToUse==1);
                    IndOutNeg   = find(OutputCatToUse==0);
                    RatioPosNeg = length(IndOutPos)/length(IndOutNeg);

                    PercToRemove = 1-RatioPosNeg/OptimalRatio;

                    if MantainPointsUnstab
                        [pp3, ee3] = getnan2([TotPolUncStable.Vertices; nan, nan]);
                        IndPointUncStable = find(inpoly([xLongTotCatToUse,yLatTotCatToUse], pp3,ee3));

                        IndOfIndPointUncStableToRemove = randperm(numel(IndPointUncStable), ...
                                                                  ceil(numel(IndOutNeg)*PercToRemove)); % ceil(numel(IndOutNeg)*PercToRemove) remain because you have in any case to remove that number of points
                        IndToRemove3 = IndPointUncStable(IndOfIndPointUncStableToRemove);
                    else
                        IndOfIndOutNegToRemove = randperm(numel(IndOutNeg), ceil(numel(IndOutNeg)*PercToRemove));
                        IndToRemove3 = IndOutNeg(IndOfIndOutNegToRemove);
                    end

                    DatasetTableToUse(IndToRemove3,:)     = [];
                    DatasetTableNormToUse(IndToRemove3,:) = [];
                    OutputCatToUse(IndToRemove3)          = [];
                    xLongTotCatToUse(IndToRemove3)        = [];
                    yLatTotCatToUse(IndToRemove3)         = [];
                
                    IndOutPosNew   = find(OutputCatToUse==1);
                    IndOutNegNew   = find(OutputCatToUse==0);
                    RatioPosNegNew = length(IndOutPosNew)/length(IndOutNegNew);
                    if (numel(IndOutPosNew) ~= numel(IndOutPos)) || (round(OptimalRatio, 1) ~= round(RatioPosNegNew, 1))
                        error("Something went wrong in re-attributing the correct ratio between positive and negative outputs!")
                    end
                end
            else
                DatasetTableToUse     = DatasetTable;
                DatasetTableNormToUse = DatasetTableNorm;
                OutputCatToUse        = OutputCat;
                xLongTotCatToUse      = xLongTotCat;
                yLatTotCatToUse       = yLatTotCat;
            end
            
            %% Model creation and prediction
            rng(7) % For reproducibility of the model
            PartitionTrain = cvpartition(OutputCatToUse, 'Holdout',0.20);
        
            IndTrainLogical = training(PartitionTrain); % Indices for the training set
            IndTrain = find(IndTrainLogical);
            
            IndTestLogical = test(PartitionTrain); % Indices for the test set
            IndTest = find(IndTestLogical);
            
            DatasetTrain = DatasetTableNormToUse(IndTrainLogical,:);
            DatasetTest  = DatasetTableNormToUse(IndTestLogical,:);
            
            OutputTrain = OutputCatToUse(IndTrainLogical);
            OutputTest  = OutputCatToUse(IndTestLogical);
            
            switch ANNMode
                case 'With Validation Data'
                    Model = fitcnet(DatasetTrain, OutputTrain, 'ValidationData',{DatasetTest, OutputTest}, ...
                                                               'ValidationFrequency',5, 'ValidationPatience',20, ...
                                                               'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                               'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',5e4);

                    FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                    if FailedConvergence
                        warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
                    end

                case 'Auto'
                    Model = fitcnet(DatasetTrain, OutputTrain, 'OptimizeHyperparameters','all', ...
                                                               'MaxObjectiveEvaluations',20);
                case 'Normal'
                    Model = fitcnet(DatasetTrain, OutputTrain, 'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                               'Standardize',Standardize, 'Lambda',1.2441e-09);
            end

            FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
            if FailedConvergence
                warning(strcat("ATTENTION! Model n. ", string(i1), " failed to converge! Please analyze it."))
            end
            
            [PredictionTrain, ProbabilityTrain] = predict(Model, DatasetTrain);
            [PredictionTest,  ProbabilityTest]  = predict(Model, DatasetTest);
        
            DatasetTestMSE = loss(Model, DatasetTest, OutputTest);

            R2 = corrcoef(table2array(DatasetTableNormToUse));
        
            % General matrix creation 
            ANNModels(:, i1) = {Model; DatasetTrain; DatasetTest; OutputTrain; OutputTest; ...
                                PredictionTrain; ProbabilityTrain; PredictionTest; ...
                                ProbabilityTest; DatasetTestMSE; R2; ConditioningFactorsNames};
        end

    case 'SingleCumulate'
        %% Table rainfall addition
        if MultipleDayAnalysis
            MaxDaysToCumulate = length(TimeSensitiveDate)-DaysBeforeEventWhenStable;
        else
            MaxDaysToCumulate = length(TimeSensitiveDate);
        end

        DaysToCumulate = str2double(inputdlg({["Please specify how many days you want to cumulate: "
                                               strcat("(Max possible with your dataset:  ",string(MaxDaysToCumulate)," days")]}, ...
                                               '', 1, {num2str(MaxDaysToCumulate)}));

        if (MaxDaysToCumulate-DaysToCumulate) <= 0
            error('You have to select fewer days than the maximum possible (or you have to change matrix of daily rainfalls)')
        end

        AnalysisInformation.DaysCumulated = DaysToCumulate;

        ConditioningFactorOper = repmat({'Averaged'}, 1, length(TimeSensitiveParam));
        ConditioningFactorOper(CumulableParam) = {'Cumulated'};

        ConditioningFactorToAdd  = cellfun(@(x, y) [x,y,num2str(DaysToCumulate),'d'], TimeSensitiveParam, ConditioningFactorOper, 'UniformOutput',false);
        ConditioningFactorsNames = [ConditioningFactorsNames, ConditioningFactorToAdd];
    
        RowToTake   = length(TimeSensitiveDate);
        ColumnToAdd = cell(1, length(TimeSensitiveParam));
        for i1 = 1:length(TimeSensitiveParam)
            ColumnToAddTemp = cell(1, size(TimeSensitiveDataInterpStudy{i1}, 2));
            for i2 = 1:size(TimeSensitiveDataInterpStudy{i1}, 2)
                if CumulableParam(i1)
                    ColumnToAddTemp{i2} = sum([TimeSensitiveDataInterpStudy{i1}{RowToTake : -1 : (RowToTake-DaysToCumulate+1), i2}], 2);
                else
                    ColumnToAddTemp{i2} = mean([TimeSensitiveDataInterpStudy{i1}{RowToTake : -1 : (RowToTake-DaysToCumulate+1), i2}], 2);
                end
            end
            ColumnToAdd{i1} = cat(1,ColumnToAddTemp{:});
        end

        MaxDailyRain  = 30; % To discuss this value (max in Emilia was 134 mm in a day)
        MaxRangeRain  = MaxDailyRain*DaysToCumulate;

        RangesForNorm = [ RangesForNorm         ;      % Pre-existing
                           0    ,   MaxRangeRain;      % Cumulative daily rainfall (to discuss this value, max was 134 mm in a day for Emilia Romagna)
                          -10   ,   40           ];    % Mean daily temperature (to discuss this value)

        ColumnToAddTable     = table( ColumnToAdd{:}, 'VariableNames',ConditioningFactorsNames(end-length(TimeSensitiveParam)+1 : end) );
        ColumnToAddTableNorm = array2table(rescale([ColumnToAdd{:}], ...
                                                    'InputMin',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 1)', ...  % Must be a row
                                                    'InputMax',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 2)'), ... % Must be a row
                                                'VariableNames',ConditioningFactorsNames(end-length(TimeSensitiveParam)+1 : end));

        DatasetTableStudy     = [DatasetTableStudy    , ColumnToAddTable    ]; % Horizontal concatenation
        DatasetTableStudyNorm = [DatasetTableStudyNorm, ColumnToAddTableNorm]; % Horizontal concatenation

        ColumnToAddTable(IndToRemove1,:)     = [];
        ColumnToAddTableNorm(IndToRemove1,:) = [];
        if ModifyRatioPosNeg
            ColumnToAddTable(IndToRemove2,:)     = []; 
            ColumnToAddTableNorm(IndToRemove2,:) = []; 
        end

        DatasetTable     = [DatasetTable    , ColumnToAddTable    ];
        DatasetTableNorm = [DatasetTableNorm, ColumnToAddTableNorm];

        %% Addition of point at different time
        if MultipleDayAnalysis
            RowToTakeAtDiffTime = RowToTake-DaysBeforeEventWhenStable;
            ColumnToAddAtDiffTime = cell(1, length(TimeSensitiveParam));
            for i1 = 1:length(TimeSensitiveParam)
                ColumnToAddAtDiffTimeTemp = cell(1, size(TimeSensitiveDataInterpStudy{i1}, 2));
                for i2 = 1:size(TimeSensitiveDataInterpStudy{i1}, 2)
                    if CumulableParam(i1)
                        ColumnToAddAtDiffTimeTemp{i2} = sum([TimeSensitiveDataInterpStudy{i1}{RowToTakeAtDiffTime : -1 : (RowToTakeAtDiffTime-DaysToCumulate+1), i2}], 2);
                    else
                        ColumnToAddAtDiffTimeTemp{i2} = mean([TimeSensitiveDataInterpStudy{i1}{RowToTakeAtDiffTime : -1 : (RowToTakeAtDiffTime-DaysToCumulate+1), i2}], 2);
                    end
                end
                ColumnToAddAtDiffTime{i1} = cat(1,ColumnToAddAtDiffTimeTemp{:});
            end
            
            ColumnToAddTableAtDiffTime     = table( ColumnToAddAtDiffTime{:}, 'VariableNames',ConditioningFactorsNames(end-length(TimeSensitiveParam)+1 : end) );
            ColumnToAddTableAtDiffTimeNorm = array2table(rescale([ColumnToAddAtDiffTime{:}], ...
                                                                  'InputMin',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 1)', ...  % Must be a row
                                                                  'InputMax',RangesForNorm(end-length(TimeSensitiveParam)+1 : end, 2)'), ... % Must be a row
                                                              'VariableNames',ConditioningFactorsNames(end-length(TimeSensitiveParam)+1 : end));

            ColumnToAddTableAtDiffTime(IndToRemove1,:)     = [];
            ColumnToAddTableAtDiffTimeNorm(IndToRemove1,:) = [];
            if ModifyRatioPosNeg
                ColumnToAddTableAtDiffTime(IndToRemove2,:)     = []; 
                ColumnToAddTableAtDiffTimeNorm(IndToRemove2,:) = []; 
            end

            DatasetTableToAdd     = [DatasetTableToAdd    , ColumnToAddTableAtDiffTime    ];
            DatasetTableNormToAdd = [DatasetTableNormToAdd, ColumnToAddTableAtDiffTimeNorm];

            DatasetTableToUse     = [DatasetTable;     DatasetTableToAdd];
            DatasetTableNormToUse = [DatasetTableNorm; DatasetTableNormToAdd];
            OutputCatToUse        = [OutputCat;        OutputCatToAdd];
            xLongTotCatToUse      = [xLongTotCat;      xLongTotCatToAdd];
            yLatTotCatToUse       = [yLatTotCat;       yLatTotCatToAdd];

            if ModifyRatioPosNeg
                IndOutPos   = find(OutputCatToUse==1);
                IndOutNeg   = find(OutputCatToUse==0);
                RatioPosNeg = length(IndOutPos)/length(IndOutNeg);

                PercToRemove = 1-RatioPosNeg/OptimalRatio;

                if MantainPointsUnstab
                    [pp3, ee3] = getnan2([TotPolUncStable.Vertices; nan, nan]);
                    IndPointUncStable = find(inpoly([xLongTotCatToUse,yLatTotCatToUse], pp3,ee3));

                    IndOfIndPointUncStableToRemove = randperm(numel(IndPointUncStable), ...
                                                              ceil(numel(IndOutNeg)*PercToRemove)); % ceil(numel(IndOutNeg)*PercToRemove) remain because you have in any case to remove that number of points
                    IndToRemove3 = IndPointUncStable(IndOfIndPointUncStableToRemove);
                else
                    IndOfIndOutNegToRemove = randperm(numel(IndOutNeg), ceil(numel(IndOutNeg)*PercToRemove));
                    IndToRemove3 = IndOutNeg(IndOfIndOutNegToRemove);
                end

                DatasetTableToUse(IndToRemove3,:)     = [];
                DatasetTableNormToUse(IndToRemove3,:) = [];
                OutputCatToUse(IndToRemove3)          = [];
                xLongTotCatToUse(IndToRemove3)        = [];
                yLatTotCatToUse(IndToRemove3)         = [];
            
                IndOutPosNew   = find(OutputCatToUse==1);
                IndOutNegNew   = find(OutputCatToUse==0);
                RatioPosNegNew = length(IndOutPosNew)/length(IndOutNegNew);
                if (numel(IndOutPosNew) ~= numel(IndOutPos)) || (round(OptimalRatio, 1) ~= round(RatioPosNegNew, 1))
                    error("Something went wrong in re-attributing the correct ratio between positive and negative outputs!")
                end
            end
        else
            DatasetTableToUse     = DatasetTable;
            DatasetTableNormToUse = DatasetTableNorm;
            OutputCatToUse        = OutputCat;
            xLongTotCatToUse      = xLongTotCat;
            yLatTotCatToUse       = yLatTotCat;
        end

        %% ANN Settings
        R2 = corrcoef(table2array(DatasetTableNormToUse));

        Options = {'With Validation Data', 'Cross Validation (K-Fold)', 'Normal'};
        ANNMode  = uiconfirm(Fig, 'How do you want to built your neural network?', ...
                                  'Neural network choice', 'Options',Options, 'DefaultOption',1);

        LayerActivation = 'sigmoid'; % CHOICE TO USER!
        Standardize     = true;      % CHOICE TO USER!

        AnalysisInformation.ANNMode           = ANNMode;
        AnalysisInformation.ActivationFunUsed = LayerActivation;
        AnalysisInformation.StandardizedInput = Standardize;
        
        StructureInput = inputdlg(["Max number of hiddens: "
                                   "Max number of nuerons in each hidden: "
                                   "Increase of neurons for each model: "], ...
                                   '', 1, {'6', '[100, 200, 100, 50, 20, 10]', '10'});

        MaxNumOfHiddens   = str2double(StructureInput{1});
        MaxNumOfNeurons   = str2num(StructureInput{2});
        NeurToAddEachStep = str2double(StructureInput{3});

        if MaxNumOfHiddens > numel(MaxNumOfNeurons)
            error('You have to select the max number of neurons for each hidden layers (Format: [NumNeuronsHid1, NumNeuronsHid2, ...])')
        end

        AnalysisInformation.MaxNumOfHiddens   = {MaxNumOfHiddens};
        AnalysisInformation.MaxNumOfNeurons   = {MaxNumOfNeurons};
        AnalysisInformation.NeurToAddEachStep = {NeurToAddEachStep};

        [NumOfNeuronToTrainEachHidden, ModelNeurCombs] = deal(cell(1, MaxNumOfHiddens));
        for i1 = 1:MaxNumOfHiddens
            NumOfNeuronToTrainEachHidden{i1} = [1, NeurToAddEachStep:NeurToAddEachStep:MaxNumOfNeurons(i1)];
            if NeurToAddEachStep == 1; NumOfNeuronToTrainEachHidden{i1}(1) = []; end
            ModelNeurCombs{i1} = combvec(NumOfNeuronToTrainEachHidden{1:i1});
        end

        NumberOfANNs = sum(cellfun(@(x) size(x, 2), ModelNeurCombs));
        ANNModels = cell(12, NumberOfANNs);
        i3 = 0;
        for i1 = 1:MaxNumOfHiddens
            for i2 = 1:size(ModelNeurCombs{i1}, 2)
                i3 = i3+1;
                ProgressBar.Value = i2/size(ModelNeurCombs{i1}, 2);
                ProgressBar.Message = strcat("Training model n. ", string(i2)," of ", ...
                                             string(size(ModelNeurCombs{i1}, 2)), ". Num of Hiddens: ", string(i1));
                
                %% Model creation and prediction
                rng(7) % For reproducibility of the model
                PartitionTrain = cvpartition(OutputCatToUse, 'Holdout',0.20);
            
                IndTrainLogical = training(PartitionTrain); % Indices for the training set
                IndTrain = find(IndTrainLogical);
                
                IndTestLogical = test(PartitionTrain); % Indices for the test set
                IndTest = find(IndTestLogical);
                
                DatasetTrain = DatasetTableNormToUse(IndTrainLogical,:);
                DatasetTest  = DatasetTableNormToUse(IndTestLogical,:);
                
                OutputTrain = OutputCatToUse(IndTrainLogical);
                OutputTest  = OutputCatToUse(IndTestLogical);

                LayerSize = ModelNeurCombs{i1}(:,i2)';

                switch ANNMode
                    case 'With Validation Data'
                        Model = fitcnet(DatasetTrain, OutputTrain, 'ValidationData',{DatasetTest, OutputTest}, ...
                                                                   'ValidationFrequency',5, 'ValidationPatience',20, ...
                                                                   'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                                   'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',5e4);

                        FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                        if FailedConvergence
                            warning(strcat("ATTENTION! Model n. ", string(i3), " failed to converge! Please analyze it."))
                        end

                    case 'Cross Validation (K-Fold)'
                        ModelCV = fitcnet(DatasetTrain, OutputTrain, 'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                                     'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',5e4, ...
                                                                     'LossTolerance',1e-6, 'StepTolerance',1e-6, ...
                                                                     'Crossval','on', 'KFold',10); % Remember that instead of 'KFold' you can use for example: 'Holdout',0.1

                        % [PredictionOfModelCV, ProbabilitiesOfModelCV] = kfoldPredict(ModelCV); % To have the predictions of the cross validated model
                        % ConfusionTrain = confusionchart(OutputTrain, PredictionOfModelCV); % To see visually how well the cross validated model predict

                        LossesOfModels = kfoldLoss(ModelCV, 'Mode','individual');
                        [~, IndBestModel] = min(LossesOfModels);
                        Model = ModelCV.Trained{IndBestModel};
                    case 'Normal'
                        Model = fitcnet(DatasetTrain, OutputTrain, 'LayerSizes',LayerSize, 'Activations',LayerActivation, ...
                                                                   'Standardize',Standardize, 'Lambda',1e-9, 'IterationLimit',5e4, ...
                                                                   'LossTolerance',1e-5, 'StepTolerance',1e-6);

                        FailedConvergence = contains(Model.ConvergenceInfo.ConvergenceCriterion, 'Solver failed to converge.');
                        if FailedConvergence
                            warning(strcat("ATTENTION! Model n. ", string(i3), " failed to converge! Please analyze it."))
                        end
                end
                
                [PredictionTrain, ProbabilityTrain] = predict(Model, DatasetTrain);
                [PredictionTest,  ProbabilityTest]  = predict(Model, DatasetTest);
            
                DatasetTestMSE = loss(Model, DatasetTest, OutputTest);
            
                % General matrix creation
                ANNModels(:, i3) = {Model; DatasetTrain; DatasetTest; OutputTrain; OutputTest; ...
                                    PredictionTrain; ProbabilityTrain; PredictionTest; ...
                                    ProbabilityTest; DatasetTestMSE; R2; ConditioningFactorsNames};
            end
        end
end

%% Evaluation of prediction quality by means of ROC
ProgressBar.Indeterminate = 'on';
ProgressBar.Message       = "Analyzing quality of models...";

Options = {'MATLAB', 'MaximizeRatio-TPR-FPR', 'MaximizeArea-TPR-TNR'};
MethodBestThreshold = uiconfirm(Fig, 'How do you want to find the optimal threshold for ROC curves?', ...
                                     'Optimal ratio ROC', 'Options',Options, 'DefaultOption',1);

AnalysisInformation.MethodForSelectingOptimalThresholdInROCs = MethodBestThreshold;

NumberOfANNs        = size(ANNModels, 2);
ANNModelsROCTest    = cell(5, NumberOfANNs);
ANNModelsROCTrain   = cell(5, NumberOfANNs);
for i1 = 1:NumberOfANNs
    OutputTest       = ANNModels{5, i1};
    OutputTrain      = ANNModels{4, i1};
    ProbabilityTest  = ANNModels{9, i1};
    ProbabilityTrain = ANNModels{7, i1};

    % Test performance
    [FPR4ROC_Test, TPR4ROC_Test, ThresholdsROC_Test, AUC_Test, OptPoint_Test] = perfcurve(OutputTest, ProbabilityTest(:,2), 1);
    switch MethodBestThreshold
        case 'MATLAB'
            % Method integrated in MATLAB
            IndBest_Test = find(ismember([FPR4ROC_Test, TPR4ROC_Test], OptPoint_Test, 'rows'));
            BestThreshold_Test = ThresholdsROC_Test(IndBest_Test);
        case 'MaximizeRatio-TPR-FPR'
            % Method max ratio TPR/FPR
            RatioTPR_FPR_Test = TPR4ROC_Test./FPR4ROC_Test;
            RatioTPR_FPR_Test(isinf(RatioTPR_FPR_Test)) = nan;
            [~, IndBest_Test]  = max(RatioTPR_FPR_Test);
            BestThreshold_Test = ThresholdsROC_Test(IndBest_Test);
        case 'MaximizeArea-TPR-TNR'
            % Method max product TPR*TNR
            AreaTPR_TNR_Test   = TPR4ROC_Test.*(1-FPR4ROC_Test);
            [~, IndBest_Test]  = max(AreaTPR_TNR_Test);
            BestThreshold_Test = ThresholdsROC_Test(IndBest_Test);
    end
    
    % Train performance
    [FPR4ROC_Train, TPR4ROC_Train, ThresholdsROC_Train, AUC_Train, OptPoint_Train] = perfcurve(OutputTrain, ProbabilityTrain(:,2), 1);
    switch MethodBestThreshold
        case 'MATLAB'
            % Method integrated in MATLAB
            IndBest_Train = find(ismember([FPR4ROC_Train, TPR4ROC_Train], OptPoint_Train, 'rows'));
            BestThreshold_Train = ThresholdsROC_Train(IndBest_Train);
        case 'MaximizeRatio-TPR-FPR'
            % Method max ratio TPR/FPR
            RatioTPR_FPR_Train = TPR4ROC_Train./FPR4ROC_Train;
            RatioTPR_FPR_Train(isinf(RatioTPR_FPR_Train)) = nan;
            [~, IndBest_Train]  = max(RatioTPR_FPR_Train);
            BestThreshold_Train = ThresholdsROC_Train(IndBest_Train);
        case 'MaximizeArea-TPR-TNR'
            % Method max product TPR*TNR
            AreaTPR_TNR_Train   = TPR4ROC_Train.*(1-FPR4ROC_Train);
            [~, IndBest_Train]  = max(AreaTPR_TNR_Train);
            BestThreshold_Train = ThresholdsROC_Train(IndBest_Train);
    end
    
    % General matrices creation
    ANNModelsROCTest(:, i1)  = {FPR4ROC_Test,  TPR4ROC_Test,  AUC_Test,  BestThreshold_Test,  IndBest_Test};
    ANNModelsROCTrain(:, i1) = {FPR4ROC_Train, TPR4ROC_Train, AUC_Train, BestThreshold_Train, IndBest_Train};
end

%% Conversion in tables
ProgressBar.Message = "Creation of tables...";
ANNModels = cell2table(ANNModels);
ANNModels.Properties.RowNames = {'Model', 'DatasetTrain', 'DatasetTest', 'OutputTrain', ...
                                 'OutputTest', 'PredictionTrain', 'ProbabilityTrain', ...
                                 'PredictionTest', 'ProbabilityTest', 'DatasetTestMSE', ...
                                 'R2', 'ConditioningFactorsNames'};

ANNModelsROCTest = cell2table(ANNModelsROCTest);
ANNModelsROCTest.Properties.RowNames = {'FPR-Test', 'TPR-Test', 'AUC-Test', 'BestThreshold-Test', 'Index of Best Thr-Test'};

ANNModelsROCTrain = cell2table(ANNModelsROCTrain);
ANNModelsROCTrain.Properties.RowNames = {'FPR-Train', 'TPR-Train', 'AUC-Train', 'BestThreshold-Train', 'Index of Best Thr-Train'};

RangesForNorm = table(RangesForNorm(:,1), RangesForNorm(:,2), 'VariableNames',["Min value", "Max value"]);
RangesForNorm.Properties.RowNames = ConditioningFactorsNames;

%% Plot for check (the last one, that is the one with 30 days of rainfall)
ProgressBar.Message = "Plotting results...";

[~, BestModelForTest]  = max(cell2mat(ANNModelsROCTest{3,:}));
[~, BestModelForTrain] = max(cell2mat(ANNModelsROCTrain{3,:}));
ModelToPlot = str2double(inputdlg({["Which model do you want to plot?"
                                    strcat("From 1 to ", string(size(ANNModels,2)))
                                    strcat("Best for Test is: ", string(BestModelForTest))
                                    strcat("Best for Train is: ", string(BestModelForTrain))]}, '', 1, {'1'}));

PlotOption = 1;
if MultipleDayAnalysis
    Options = {'Day of the event', [num2str(DaysBeforeEventWhenStable), ' days before the event']};
    PlotChoice = uiconfirm(Fig, 'What event do you want to plot?', ...
                                'Figure to plot', 'Options',Options, 'DefaultOption',1);
    switch PlotChoice
        case 'Day of the event'
            PlotOption = 2;
        case [num2str(DaysBeforeEventWhenStable), ' days before the event']
            PlotOption = 3;
    end
end

fig_check = figure(3);
ax_check = axes(fig_check);
hold(ax_check,'on')

BestThresholdTrain  = ANNModelsROCTrain{4,ModelToPlot}{:};
BestThresholdTest   = ANNModelsROCTest{4,ModelToPlot}{:};
IndexOfBestThrTrain = ANNModelsROCTrain{5,ModelToPlot}{:};
IndexOfBestThrTest  = ANNModelsROCTest{5,ModelToPlot}{:};

BestThrTPRTrain = ANNModelsROCTrain{2,ModelToPlot}{:}(IndexOfBestThrTrain);
BestThrTPRTest  = ANNModelsROCTest{2,ModelToPlot}{:}(IndexOfBestThrTest);
BestThrFPRTrain = ANNModelsROCTrain{1,ModelToPlot}{:}(IndexOfBestThrTrain);
BestThrFPRTest  = ANNModelsROCTest{1,ModelToPlot}{:}(IndexOfBestThrTest);

disp(strcat("Your TPR relative to the best threshold are (train - test): ", string(BestThrTPRTrain), " - ", string(BestThrTPRTest)))
disp(strcat("Your FPR relative to the best threshold are (train - test): ", string(BestThrFPRTrain), " - ", string(BestThrFPRTest)))

ModelSelected = ANNModels{1,ModelToPlot}{:};

switch PlotOption
    case 1
        ProbabilityTrain      = ANNModels{7,ModelToPlot}{:};
        ProbabilityTest       = ANNModels{9,ModelToPlot}{:};
        PredictionTrainWithBT = ProbabilityTrain(:,2) >= BestThresholdTrain;
        PredictionTestWithBT  = ProbabilityTest(:,2)  >= BestThresholdTest;

    case 2
        DatasetForPlot = DatasetTableNorm;
        OutputForPlot  = OutputCat;
        [~, ProbabilityForPlot] = predict(ModelSelected, DatasetForPlot);
        PredictionWithBTForPlot = ProbabilityForPlot(:,2) >= BestThresholdTrain; % Please keep attention to 0.9 of the Best Threshold

    case 3
        DatasetForPlot = DatasetTableNormToAdd;
        OutputForPlot  = OutputCatToAdd;
        [~, ProbabilityForPlot] = predict(ModelSelected, DatasetForPlot);
        PredictionWithBTForPlot = ProbabilityForPlot(:,2) >= BestThresholdTrain; % Please keep attention to 0.9 of the Best Threshold
end

plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1.5)

if strcmp(UncondStablePointsApproach,'VisibleWindow')
    switch PlotOption
        case {1, 2}
            plot(TotPolUnstabPoints, 'FaceAlpha',.5, 'FaceColor',"#d87e7e");
        case 3
            plot(TotPolUnstabPoints, 'FaceAlpha',.5, 'FaceColor',"#5aa06b");
    end
    plot(TotPolIndecision, 'FaceAlpha',.5, 'FaceColor',"#fff2cc");
    plot(TotPolUncStable,  'FaceAlpha',.5, 'FaceColor',"#5aa06b");
end

hdetected = cellfun(@(x,y) scatter(x, y, '^k', 'Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));

switch PlotOption
    case 1
        hUnstableTest  = scatter(xLongTotCatToUse(IndTest(PredictionTestWithBT)), ...
                                 yLatTotCatToUse(IndTest(PredictionTestWithBT)), ...
                                 30, 'Marker','s', 'MarkerFaceColor',"#318ce7", 'MarkerEdgeColor','none');
        
        hUnstableTrain = scatter(xLongTotCatToUse(IndTrain(PredictionTrainWithBT)), ...
                                 yLatTotCatToUse(IndTrain(PredictionTrainWithBT)), ...
                                 30, 'Marker','d', 'MarkerFaceColor',"#33E6FF", 'MarkerEdgeColor','none');

    case {2, 3}
        hUnstableForPlot = scatter(xLongTotCat(PredictionWithBTForPlot), ...
                                   yLatTotCat(PredictionWithBTForPlot), ...
                                   30, 'Marker','s', 'MarkerFaceColor',"#318ce7", 'MarkerEdgeColor','none');
end

switch PlotOption
    case 1
        xPointUnstab = xLongTotCatToUse(logical(OutputCatToUse));
        yPointUnstab = yLatTotCatToUse(logical(OutputCatToUse));

        xPointStab   = xLongTotCatToUse(not(logical(OutputCatToUse)));
        yPointStab   = yLatTotCatToUse(not(logical(OutputCatToUse)));

    case 2
        xPointUnstab = xLongTotCat(logical(OutputCat));
        yPointUnstab = yLatTotCat(logical(OutputCat));

        xPointStab   = xLongTotCat(not(logical(OutputCat)));
        yPointStab   = yLatTotCat(not(logical(OutputCat)));

    case 3
        xPointUnstab = xLongTotCatToAdd(logical(OutputCatToAdd));
        yPointUnstab = yLatTotCatToAdd(logical(OutputCatToAdd));

        xPointStab   = xLongTotCatToAdd(not(logical(OutputCatToAdd)));
        yPointStab   = yLatTotCatToAdd(not(logical(OutputCatToAdd)));
end

hUnstabOutputReal = scatter(xPointUnstab, yPointUnstab, ...
                            15, 'Marker',"hexagram", 'MarkerFaceColor',"#ff0c01", ...
                            'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.5);

hStableOutputReal = scatter(xPointStab, yPointStab, ...
                            15, 'Marker',"hexagram", 'MarkerFaceColor',"#77AC30", ...
                            'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.5);

switch PlotOption
    case {1, 2}
        title("Day of the event")
    case 3
        title([num2str(DaysBeforeEventWhenStable), ' days before the event'])
    otherwise
        error('Plot option not defined')
end

dLat1Meter  = rad2deg(1/earthRadius); % 1 m in lat
dLong1Meter = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long

RatioLatLong = dLat1Meter/dLong1Meter;
daspect([1, RatioLatLong, 1])

%% Saving...
ProgressBar.Message = "Saving files...";
cd(fold_var)
VariablesML = {'ANNModels', 'ANNModelsROCTrain', 'ANNModelsROCTest', ...
               'DatasetTableStudy', 'DatasetTableStudyNorm', 'DatasetCoordinates', ...
               'PolUnstabPoints', 'PolMaxExtAroundDet', 'PolIndecisionAroundDetGross', ...
               'TotPolUnstabPoints', 'TotPolIndecision', 'TotPolUncStable', ...
               'RangesForNorm', 'CategoricalClasses', 'AnalysisInformation'};
save('TrainedANNs.mat', VariablesML{:})
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in standalone version