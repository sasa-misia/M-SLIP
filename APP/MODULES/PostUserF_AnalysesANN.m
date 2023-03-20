Fig = uifigure; % Remember to comment this line if is app version
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
load('RainInterpolated.mat',         'RainInterpolated')
load('InfoDetectedSoilSlips.mat',    'InfoDetectedSoilSlips')
load('StudyAreaVariables.mat',       'StudyAreaPolygon')
load('TrainedANNs.mat',              'ANNModels','ANNModelsROCTrain','ANNModelsROCTest','RangesForNorm', ...
                                     'TotPolUncStable','TotPolIndecision','TotPolUnstabPoints', ...
                                     'CategoricalClasses','DatasetTableStudy','DatasetTableStudyNorm')
cd(fold0)

CreateNewDataset = false;
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
    
    yLatMean    = mean(yLatTotCat);
    
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
end