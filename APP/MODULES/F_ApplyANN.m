% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
cd(fold_var)
load('MorphologyParameters.mat',     'AspectAngleAll','ElevationAll','SlopeAll','MeanCurvatureAll')
load('LithoPolygonsStudyArea.mat',   'LithoAllUnique','LithoPolygonsStudyArea')
load('TopSoilPolygonsStudyArea.mat', 'TopSoilAllUnique','TopSoilPolygonsStudyArea')
load('LandUsesVariables.mat',        'AllLandUnique','LandUsePolygonsStudyArea')
load('VegPolygonsStudyArea.mat',     'VegetationAllUnique','VegPolygonsStudyArea')
load('GridCoordinates.mat',          'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load('RainInterpolated.mat',         'RainInterpolated','DateInterpolationStarts')
load('InfoDetectedSoilSlips.mat',    'InfoDetectedSoilSlips')
load('StudyAreaVariables.mat',       'StudyAreaPolygon')
load('TrainedANNs.mat',              'ANNModels','ANNModelsROCTrain','ANNModelsROCTest','RangesForNorm', ...
                                     'TotPolUncStable','TotPolIndecision','TotPolUnstabPoints', ...
                                     'CategoricalClasses','AnalysisInformation')
cd(fold0)

Options = {'Yes', 'No, I want to create a new one'};
NewDatasetChoice = uiconfirm(Fig, ['Do you want to use the dataset of the entire ' ...
                                   'study area created while training the ANNs?'], ...
                                  'New dataset creation', 'Options',Options, 'DefaultOption',1);
if strcmp(NewDatasetChoice,'Yes'); CreateNewDataset = false; else; CreateNewDataset = true; end

%% Creation of dataset
if CreateNewDataset
    %% Extraction of data in study area
    ProgressBar.Message = "Data extraction in study area..."; 
    xLongStudy          = cellfun(@(x,y) x(y), xLongAll        , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    yLatStudy           = cellfun(@(x,y) x(y), yLatAll         , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    ElevationStudy      = cellfun(@(x,y) x(y), ElevationAll    , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    SlopeStudy          = cellfun(@(x,y) x(y), SlopeAll        , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    AspectStudy         = cellfun(@(x,y) x(y), AspectAngleAll  , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    MeanCurvatureStudy  = cellfun(@(x,y) x(y), MeanCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    
    xLongStudyTotCat = cat(1, xLongStudy{:});
    yLatStudyTotCat  = cat(1, yLatStudy{:});
    
    yLatMean = mean(yLatTotCat);
    
    %% Creation of classes
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
    TopSoilClasses = readcell('ClassesML.xlsx', 'Sheet','Top Soil');
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
    
    %% Table soil creation
    ProgressBar.Message = "Creating table normalized...";
    DatasetToPredict = table( cat(1,SlopeStudy{:}), ...
                              cat(1,AspectStudy{:}), ...
                              cat(1,ElevationStudy{:}), ...
                              cat(1,MeanCurvatureStudy{:}), ...
                              cat(1,LithoStudy{:}), ...
                              cat(1,TopSoilStudy{:}), ...
                              cat(1,LandUseStudy{:}), ...
                              cat(1,VegStudy{:})                 );
    
    if CategoricalClasses   
        DatasetToPredictNorm = table( rescale(cat(1,SlopeStudy{:}),         'InputMin',RangesForNorm(1,1),    'InputMax',RangesForNorm(1,2)), ...
                                      rescale(cat(1,AspectStudy{:}),        'InputMin',RangesForNorm(2,1),    'InputMax',RangesForNorm(2,2)), ...
                                      rescale(cat(1,ElevationStudy{:}),     'InputMin',RangesForNorm(3,1),    'InputMax',RangesForNorm(3,2)), ...
                                      rescale(cat(1,MeanCurvatureStudy{:}), 'InputMin',RangesForNorm(4,1),    'InputMax',RangesForNorm(4,2)), ...
                                      cat(1,LithoStudy{:}), ...
                                      cat(1,TopSoilStudy{:}), ...
                                      cat(1,LandUseStudy{:}), ...
                                      cat(1,VegStudy{:})                                                                                           );
    else
        DatasetToPredictNorm = table( rescale(cat(1,SlopeStudy{:}),         'InputMin',RangesForNorm(1,1),    'InputMax',RangesForNorm(1,2)), ...
                                      rescale(cat(1,AspectStudy{:}),        'InputMin',RangesForNorm(2,1),    'InputMax',RangesForNorm(2,2)), ...
                                      rescale(cat(1,ElevationStudy{:}),     'InputMin',RangesForNorm(3,1),    'InputMax',RangesForNorm(3,2)), ...
                                      rescale(cat(1,MeanCurvatureStudy{:}), 'InputMin',RangesForNorm(4,1),    'InputMax',RangesForNorm(4,2)), ...
                                      rescale(cat(1,LithoStudy{:}),         'InputMin',RangesForNorm(5,1),    'InputMax',RangesForNorm(5,2)), ...
                                      rescale(cat(1,TopSoilStudy{:}),       'InputMin',RangesForNorm(6,1),    'InputMax',RangesForNorm(6,2)), ...
                                      rescale(cat(1,LandUseStudy{:}),       'InputMin',RangesForNorm(7,1),    'InputMax',RangesForNorm(7,2)), ...
                                      rescale(cat(1,VegStudy{:}),           'InputMin',RangesForNorm(8,1),    'InputMax',RangesForNorm(8,2))      );
    end
    
    DatasetToPredict.Properties.VariableNames     = ConditioningFactorsNames;
    DatasetToPredictNorm.Properties.VariableNames = ConditioningFactorsNames;
    
    %% Categorical vector if you mantain string classes
    if CategoricalClasses
        DatasetToPredictNorm.Lithology  = categorical(DatasetToPredictNorm.Lithology, ...
                                                      string(LithoClasses(:,1)), 'Ordinal',true);
    
        DatasetToPredictNorm.TopSoil    = categorical(DatasetToPredictNorm.TopSoil, ...
                                                      string(TopSoilClasses(:,1)), 'Ordinal',true);
        
        DatasetToPredictNorm.Vegetation = categorical(DatasetToPredictNorm.Vegetation, ...
                                                      string(VegClasses(:,1)), 'Ordinal',true);
    
        DatasetToPredictNorm.LandUse    = categorical(DatasetToPredictNorm.LandUse, ...
                                                      string(LandUseClasses(:,1)), 'Ordinal',true);
    end
    % TO CONTINUE!!!!!
else
    cd(fold_var)
    load('TrainedANNs.mat', 'DatasetTableStudy','DatasetTableStudyNorm','DatasetCoordinates')
    cd(fold0)

    DatasetToPredict     = DatasetTableStudy;
    DatasetToPredictNorm = DatasetTableStudyNorm;

    RainDailyInterpStudy = cellfun(@full, RainInterpolated, 'UniformOutput',false);

    clear('DatasetTableStudy', 'DatasetTableStudyNorm', 'RainInterpolated')
end

%% Choose of model to use
IndexOfNans = find(isnan(TotPolUncStable.Vertices(:,1)));
EndOfExtPolygons = IndexOfNans(TotPolUncStable.NumRegions);
[TotPolUncStableLongSplit, TotPolUncStableLatSplit] = polysplit(TotPolUncStable.Vertices(1:EndOfExtPolygons,1), TotPolUncStable.Vertices(1:EndOfExtPolygons,2));
TotPolUncStableSplitGross = cellfun(@(x, y) polyshape(x, y), TotPolUncStableLongSplit, TotPolUncStableLatSplit, 'UniformOutput',false);

TotPolStableSplit    = cellfun(@(x) intersect(x, TotPolUncStable), ...
                                        TotPolUncStableSplitGross, 'UniformOutput',false);

TotPolUnstableSplit  = cellfun(@(x) intersect(x, TotPolUnstabPoints), ...
                                        TotPolUncStableSplitGross, 'UniformOutput',false);

[IndexOfPointsUnstable, IndexOfPointsStable] = deal(cell(size(TotPolUnstableSplit)));
for i1 = 1:numel(TotPolUnstableSplit)
    [pp1, ee1] = getnan2([TotPolUnstableSplit{i1}.Vertices; nan, nan]);
    IndexOfPointsUnstable{i1} = find(inpoly([DatasetCoordinates.Longitude,DatasetCoordinates.Latitude], pp1,ee1));

    [pp2, ee2] = getnan2([TotPolStableSplit{i1}.Vertices; nan, nan]);
    IndexOfPointsStable{i1}   = find(inpoly([DatasetCoordinates.Longitude,DatasetCoordinates.Latitude], pp2,ee2));
end

IndexOfPointsUnstableCat = cat(1, IndexOfPointsUnstable{:});
IndexOfPointsStableCat   = cat(1, IndexOfPointsStable{:});

DatasetForQualityNorm = [ DatasetToPredictNorm(IndexOfPointsUnstableCat,:)
                          DatasetToPredictNorm(IndexOfPointsStableCat,:)   ];

RealOutput = [ ones(size(IndexOfPointsUnstableCat))
               zeros(size(IndexOfPointsStableCat))  ];

LossOfModels = cellfun(@(x) loss(x, DatasetForQualityNorm, RealOutput), ANNModels{1,:});

[ProbabilityForQuality, FPR4ROC_ForQuality, TPR4ROC_ForQuality, ...
        ThresholdsROC_ForQuality, AUC_ForQuality, OptPoint_ForQuality] = deal(cell(1, size(ANNModels, 2)));
for i1 = 1:size(ANNModels, 2)
    [~, ProbabilityForQuality{i1}] = predict(ANNModels{1,i1}{:}, DatasetForQualityNorm);
    [FPR4ROC_ForQuality{i1}, TPR4ROC_ForQuality{i1}, ThresholdsROC_ForQuality{i1}, ...
            AUC_ForQuality{i1}, OptPoint_ForQuality{i1}] = perfcurve(RealOutput, ProbabilityForQuality{i1}(:,2), 1);
end

% In terms of loss
[~, BestModelLossForQuality] = min(LossOfModels);
[~, BestModelLossForTrained] = min(cell2mat(ANNModels{10,:}));
% In terms of AUC
[~, BestModelAUCForQuality]  = max(cell2mat(AUC_ForQuality));
[~, BestModelAUCForTrain]    = max(cell2mat(ANNModelsROCTrain{3,:}));
[~, BestModelAUCForTest]     = max(cell2mat(ANNModelsROCTest{3,:}));

IndModelSelected = str2double(inputdlg({["Which model do you want to use?"
                                    strcat("From 1 to ", string(size(ANNModels,2)))
                                    strcat("Best in terms of loss is: ", string(BestModelLossForQuality))
                                    strcat("Best in terms of AUC is: ", string(BestModelAUCForQuality))]}, ...
                                    '', 1, {num2str(BestModelLossForQuality)}));

%% Property extraction of model selected
MethodBestThreshold = AnalysisInformation.MethodForSelectingOptimalThresholdInROCs;
switch MethodBestThreshold
    case 'MATLAB'
        % Method integrated in MATLAB
        IndBestThrForQuality = find(ismember([FPR4ROC_ForQuality{IndModelSelected}, TPR4ROC_ForQuality{IndModelSelected}], OptPoint_ForQuality{IndModelSelected}, 'rows'));
        BestThresholdForQuality = ThresholdsROC_ForQuality{IndModelSelected}(IndBestThrForQuality);
    case 'MaximizeRatio-TPR-FPR'
        % Method max ratio TPR/FPR
        RatioTPR_FPR_ForQuality = TPR4ROC_ForQuality{IndModelSelected}./FPR4ROC_ForQuality{IndModelSelected};
        RatioTPR_FPR_ForQuality(isinf(RatioTPR_FPR_ForQuality)) = nan;
        [~, IndBestThrForQuality]  = max(RatioTPR_FPR_ForQuality);
        BestThresholdForQuality = ThresholdsROC_ForQuality{IndModelSelected}(IndBestThrForQuality);
    case 'MaximizeArea-TPR-TNR'
        % Method max product TPR*TNR
        AreaTPR_TNR_ForQuality   = TPR4ROC_ForQuality{IndModelSelected}.*(1-FPR4ROC_ForQuality{IndModelSelected});
        [~, IndBestThrForQuality]  = max(AreaTPR_TNR_ForQuality);
        BestThresholdForQuality = ThresholdsROC_ForQuality{IndModelSelected}(IndBestThrForQuality);
end

BestThresholdTrain = ANNModelsROCTrain{4,IndModelSelected}{:};
BestThresholdTest  = ANNModelsROCTest{4,IndModelSelected}{:};
IndBestThrTrain    = ANNModelsROCTrain{5,IndModelSelected}{:};
IndBestThrTest     = ANNModelsROCTest{5,IndModelSelected}{:};

%% Selection of event, adjustment of dataset and use
DateInterpolationStarts.Format = 'dd/MM/yyyy';

Method = AnalysisInformation.RainfallMethod;
switch Method
    case 'SingleCumulate'
        DaysToCumulate = AnalysisInformation.DaysCumulated;
        VariableName   = ['RainfallCumulated',num2str(DaysToCumulate),'d'];

        DatePossible   = DateInterpolationStarts((DaysToCumulate):end);

        EventChoice = listdlg('PromptString',{'Select the date of your event:',''}, ...
                              'ListString',DatePossible, 'SelectionMode','single');

        EventInd = find(DatePossible(EventChoice) == DateInterpolationStarts);
        
        RainCumulated = cell(1, size(RainDailyInterpStudy, 2));
        for i1 = 1:size(RainDailyInterpStudy, 2)
            RainCumulated{i1} = sum([RainDailyInterpStudy{EventInd:-1:(EventInd-DaysToCumulate+1), i1}], 2);
        end
        
        ColumnToOverwrite = cat(1,RainCumulated{:});
        
        DatasetToPredict.(VariableName)     = ColumnToOverwrite;
        DatasetToPredictNorm.(VariableName) = rescale(ColumnToOverwrite, ...
                                                                     'InputMin',RangesForNorm{VariableName,1}, ...
                                                                     'InputMax',RangesForNorm{VariableName,2});
    otherwise
        error('Type of ANN not yet implemented. Please contact developers.')
end

ModelSelected = ANNModels{1,IndModelSelected}{:};
[PredictionClasses, PredictionProbabilities] = predict(ModelSelected, DatasetToPredictNorm);

%% Clusterization
ProgressBar.Message = "Defining clusters for unstab points...";
EPSG = str2double(inputdlg({["Set DTM EPSG (to calculate clusters)"
                             "For Example:"
                             "Sicily -> 32633"
                             "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
ProjCRS = projcrs(EPSG);

[xPlanCoord, yPlanCoord] = projfwd(ProjCRS, ...
                                   DatasetCoordinates{:,2}, DatasetCoordinates{:,1});

IndPointsUnstablePredicted = find(round(PredictionProbabilities(:,2),4) >= BestThresholdForQuality); % Indices referred to the database!

dLat  = abs(yLatAll{1}(1)-yLatAll{1}(2));
dYmin = deg2rad(dLat)*earthRadius + 1; % This will be the radius constructed around every point to create clusters. +1 for an extra boundary
MinPointsForEachCluster = 3; % CHOICE TO USER!
ClustersUnstable = dbscan([xPlanCoord(IndPointsUnstablePredicted), yPlanCoord(IndPointsUnstablePredicted)], dYmin, MinPointsForEachCluster); % Coordinates, min dist, min n. of point for each core point

IndNoisyPoints = (ClustersUnstable == -1);
IndPointsUnstablePredictedClean = IndPointsUnstablePredicted(not(IndNoisyPoints));
ClustersUnstableClean           = ClustersUnstable(not(IndNoisyPoints));
ClassesClustUnstClean           = unique(ClustersUnstableClean);

[IndClustersClasses, ClustersCoordinates] = deal(cell(1, length(ClassesClustUnstClean)));
for i1 = 1:length(ClassesClustUnstClean)
    IndClustersClasses{i1}  = IndPointsUnstablePredicted( ClustersUnstable == ClassesClustUnstClean(i1) );
    ClustersCoordinates{i1} = [DatasetCoordinates{IndClustersClasses{i1},1}, DatasetCoordinates{IndClustersClasses{i1},2}];
end

PlotColors = arrayfun(@(x) rand(1, 3), ClassesClustUnstClean', 'UniformOutput',false);

disp(strcat("Identified ",string(length(ClassesClustUnstClean))," landslides in your area."))

%% Plot for check
fig_check1 = figure(1);
ax_check1  = axes(fig_check1);
hold(ax_check1,'on')

% % Too slow
% PlotClusters = cellfun(@(x,z) scatter(x(:,1), x(:,2), 2, 'Marker','o', 'MarkerFaceColor',z, ...
%                                             'MarkerEdgeColor','none', 'MarkerFaceAlpha',0.7, 'Parent',ax_check1), ...
%                                       ClustersCoordinates, PlotColors, 'UniformOutput',false);

fastscatter(DatasetCoordinates{IndPointsUnstablePredictedClean,1}, DatasetCoordinates{IndPointsUnstablePredictedClean,2}, ClustersUnstableClean);

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5);

title('Clusters')

fig_settings(fold0, 'AxisTick');

%% Choose of type of results
AreaMode = 'IndividualWindows'; % CHOICE TO USER!
switch AreaMode
    case 'IndividualWindows'
        %% Results in all the area delimeted by the polygons
        DatasetReduced            = [ DatasetToPredict(IndexOfPointsUnstableCat,:)
                                      DatasetToPredict(IndexOfPointsStableCat,:)   ];

        DatasetReducedNorm        = [ DatasetToPredictNorm(IndexOfPointsUnstableCat,:)
                                      DatasetToPredictNorm(IndexOfPointsStableCat,:)   ];

        DatasetCoordinatesReduced = [ DatasetCoordinates(IndexOfPointsUnstableCat,:)
                                      DatasetCoordinates(IndexOfPointsStableCat,:)   ];

        PredictionClassesReduced       = [ PredictionClasses(IndexOfPointsUnstableCat,:)
                                           PredictionClasses(IndexOfPointsStableCat,:)   ];

        PredictionProbabilitiesReduced = [ PredictionProbabilities(IndexOfPointsUnstableCat,:)
                                           PredictionProbabilities(IndexOfPointsStableCat,:)   ];

        if EventInd == length(DateInterpolationStarts)
            RealOutputReduced = [ ones(size(IndexOfPointsUnstableCat))
                                  zeros(size(IndexOfPointsStableCat))   ];
        else
            RealOutputReduced = [ zeros(size(IndexOfPointsUnstableCat))
                                  zeros(size(IndexOfPointsStableCat))   ];
        end

        Loss_Reduced = loss(ModelSelected, DatasetReducedNorm, RealOutputReduced);

        [FPR4ROC_Reduced, TPR4ROC_Reduced, ThresholdsROC_Reduced, ...
                AUC_Reduced, OptPoint_Reduced] = perfcurve(RealOutputReduced, PredictionProbabilitiesReduced(:,1), 0);

        %% Results splitted based on polygons
        PointsCoordUnstable = cellfun(@(x) table2array(DatasetCoordinates(x,:)), IndexOfPointsUnstable, 'UniformOutput',false);
        PointsCoordStable   = cellfun(@(x) table2array(DatasetCoordinates(x,:)), IndexOfPointsStable,   'UniformOutput',false);

        PointsAttributesUnstable = cellfun(@(x) DatasetToPredict(x,:), IndexOfPointsUnstable, 'UniformOutput',false);
        PointsAttributesStable   = cellfun(@(x) DatasetToPredict(x,:), IndexOfPointsStable,   'UniformOutput',false);

        PointsAttributesUnstableNorm = cellfun(@(x) DatasetToPredictNorm(x,:), IndexOfPointsUnstable, 'UniformOutput',false);
        PointsAttributesStableNorm   = cellfun(@(x) DatasetToPredictNorm(x,:), IndexOfPointsStable,   'UniformOutput',false);

        PredictedClassesEachPolyUnstable = cellfun(@(x) PredictionClasses(x,:), IndexOfPointsUnstable, 'UniformOutput',false);
        PredictedClassesEachPolyStable   = cellfun(@(x) PredictionClasses(x,:), IndexOfPointsStable,   'UniformOutput',false);

        PredictedProbabilitiesEachPolyUnstable = cellfun(@(x) PredictionProbabilities(x,:), IndexOfPointsUnstable, 'UniformOutput',false);
        PredictedProbabilitiesEachPolyStable   = cellfun(@(x) PredictionProbabilities(x,:), IndexOfPointsStable,   'UniformOutput',false);

        AttributesNames      = {'PolygonsStable', 'PolygonsUnstable', 'PointsCoordStable', 'PointsCoordUnstable', ...
                                'PointsAttributesStable', 'PointsAttributesUnstable', ...
                                'PointsAttributesStableNorm', 'PointsAttributesUnstableNorm'};

        ResultsNames         = {'ModelUsed', 'AUC', 'Loss', 'BestThreshold' ...
                                'PredictedClassesEachPolyStable', 'PredictedProbabilitiesEachPolyStable', ...
                                'PredictedClassesEachPolyUnstable', 'PredictedProbabilitiesEachPolyUnstable'};

        AttributesInPolygons = cell2table({TotPolStableSplit, TotPolUnstableSplit, PointsCoordStable, PointsCoordUnstable, ...
                                           PointsAttributesStable, PointsAttributesUnstable, ...
                                           PointsAttributesStableNorm, PointsAttributesUnstableNorm}, 'VariableNames',AttributesNames);

        ResultsInPolygons    = cell2table({ModelSelected, AUC_Reduced, Loss_Reduced, BestThresholdForQuality, ...
                                           PredictedClassesEachPolyStable, PredictedProbabilitiesEachPolyStable, ...
                                           PredictedClassesEachPolyUnstable, PredictedProbabilitiesEachPolyUnstable}, 'VariableNames',ResultsNames);

        %% Plot for check
        ProgressBar.Message = "Plotting results...";

        SelectedPolygon = str2double(inputdlg({["Which polygon do you want to plot?"
                                                strcat("From 1 to ", string(length(AttributesInPolygons.PolygonsStable{1,1})))]}, '', 1, {'1'}));

        Options = {'BestThreshold', 'Manual'};
        ModeUnstable = uiconfirm(Fig, 'How do you want to define the threshold?', ...
                                      'Threshold choice', 'Options',Options, 'DefaultOption',1);
        switch ModeUnstable
            case 'BestThreshold'
                ClassesThreshold = round(Probabilities,4) >= ResultsInPolygons.BestThreshold;
            case 'Manual'
                ThresholdChosed  = str2double(inputdlg({["Which threshold do you want?"
                                                         "If you overpass it, then you will have a landslide. [from 0 to 100 %]"]}, '', 1, {'50'}))/100;
                ClassesThreshold = Probabilities >= ThresholdChosed;
        end

        fig_check2 = figure(2);
        ax_check2  = axes(fig_check2);
        hold(ax_check2,'on')

        plot(AttributesInPolygons.PolygonsStable{1,1}{SelectedPolygon},   'FaceAlpha',.5, 'FaceColor',"#fffcdd");
        plot(AttributesInPolygons.PolygonsUnstable{1,1}{SelectedPolygon}, 'FaceAlpha',.5, 'FaceColor',"#fffcdd");

        PointsCoordinates = [ AttributesInPolygons.PointsCoordStable{1,1}{SelectedPolygon}
                              AttributesInPolygons.PointsCoordUnstable{1,1}{SelectedPolygon} ];

        Probabilities     = [ ResultsInPolygons.PredictedProbabilitiesEachPolyStable{1,1}{SelectedPolygon}(:,2)
                              ResultsInPolygons.PredictedProbabilitiesEachPolyUnstable{1,1}{SelectedPolygon}(:,2) ]; % These are probabilities of having landslide!

        Classes           = [ ResultsInPolygons.PredictedClassesEachPolyStable{1,1}{SelectedPolygon}
                              ResultsInPolygons.PredictedClassesEachPolyUnstable{1,1}{SelectedPolygon} ];

        StablePointsPlot  = scatter(PointsCoordinates(not(ClassesThreshold),1), ...
                                    PointsCoordinates(not(ClassesThreshold),2), ...
                                    20, 'Marker','s', 'MarkerFaceColor',"#5aa06b", 'MarkerEdgeColor','none');

        UnstabPointsPlot  = scatter(PointsCoordinates(ClassesThreshold,1), ...
                                    PointsCoordinates(ClassesThreshold,2), ...
                                    20, 'Marker','s', 'MarkerFaceColor',"#e33900", 'MarkerEdgeColor','none');

        yLatMean    = mean(PointsCoordinates(:,2));
        dLat1Meter  = rad2deg(1/earthRadius); % 1 m in lat
        dLong1Meter = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long

        RatioLatLong = dLat1Meter/dLong1Meter;
        daspect([1, RatioLatLong, 1])

        %% Saving
        cd(fold_var)
        VariablesANNResults = {'AttributesInPolygons', 'ResultsInPolygons'};
        save('ANNResults.mat', VariablesANNResults{:})
        cd(fold0)
end
close(ProgressBar) % Fig instead of ProgressBar if in standalone version