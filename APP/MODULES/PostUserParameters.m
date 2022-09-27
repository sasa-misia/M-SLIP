%% File loading...
cd(fold_var)
load('MorphologyParameters.mat')
load('SoilParameters.mat')
load('VegetationParameters.mat')
load('GridCoordinates.mat')
load('InfoDetectedSoilSlips.mat')
load('UserC_Answers.mat')
load('UserD_Answers.mat')

if (VegAttribution ~= 0) && (AnswerAttributionVegetationParameter ~= 0)
    load('VegPolygonsStudyArea.mat')
else
    AnswerAttributionVegetationParameter = 0;
end

if AnswerAttributionSoilParameter~=0
    load('LithoPolygonsStudyArea.mat')
end

AnswerLandUseAttribution = 0;
if exist('LandUsesVariables.mat', 'file')
    load('LandUsesVariables.mat', 'AllLandUnique','LandUsePolygonsStudyArea')
    AnswerLandUseAttribution = 1;
end

%% Extraction of points in Study Area and Detected points
DTMIncludingPoint = [InfoDetectedSoilSlips{:,3}]';
NearestPoint = [InfoDetectedSoilSlips{:,4}]';

xLongStudy          = cellfun(@(x,y) x(y), xLongAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

yLatStudy           = cellfun(@(x,y) x(y), yLatAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

ElevationStudy      = cellfun(@(x,y) x(y), ElevationAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

SlopeStudy          = cellfun(@(x,y) x(y), SlopeAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

AspectStudy         = cellfun(@(x,y) x(y), AspectAngleAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

CohesionStudy       = cellfun(@(x,y) x(y), CohesionAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

PhiStudy            = cellfun(@(x,y) x(y), PhiAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

nStudy              = cellfun(@(x,y) x(y), nAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

kStudy              = cellfun(@(x,y) x(y), KtAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

AStudy              = cellfun(@(x,y) x(y), AAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

betastarStudy       = cellfun(@(x,y) x(y), BetaStarAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

RootStudy           = cellfun(@(x,y) x(y), RootCohesionAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

%% Creation of variables to save
VariablesInfoDet = {'InfoDetectedSoilSlips', 'ChoiceSubArea'};
if ChoiceSubArea
    VariablesInfoDet = [VariablesInfoDet, {'InfoPointsNearDetectedSoilSlips', 'InfoDetectedSoilSlipsAverage'}];
end

%% Start of the loop for each detected point
for i1 = 1:size(DTMIncludingPoint,1)

    InfoDetectedSoilSlips{i1,7} = ElevationStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,8} = SlopeStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,9} = AspectStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));

    % Intersection of detected point with litho
    if ~AnswerAttributionSoilParameter
        InfoDetectedSoilSlips{i1,10} = 'Uniform';
    else
        [pp_lit, ee_lit] = arrayfun(@(x) getnan2(x.Vertices), LithoPolygonsStudyArea, 'UniformOutput',false); % In every cell a different polygon or mulrypolygon of the same litho
        LithoPolygon = find(cellfun(@(x,y) inpoly( [xLongStudy{DTMIncludingPoint(i1)}(NearestPoint(i1)), ...
                                                    yLatStudy{DTMIncludingPoint(i1)}(NearestPoint(i1))], x, y ), pp_lit, ee_lit));
        if isempty(LithoPolygon)
            InfoDetectedSoilSlips{i1,10} = 'No Litho';
        else
            InfoDetectedSoilSlips{i1,10} = LithoAllUnique{LithoPolygon};
        end
    end

    InfoDetectedSoilSlips{i1,11} = CohesionStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,12} = PhiStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,13} = kStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,14} = AStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,15} = nStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));

    % Intersection of detected point with veg
    if ~AnswerAttributionVegetationParameter
        InfoDetectedSoilSlips{i1,16} = 'Uniform';
    else
        [pp_veg, ee_veg] = arrayfun(@(x) getnan2(x.Vertices), VegPolygonsStudyArea, 'UniformOutput',false);
        VegPolygon = find(cellfun(@(x,y) inpoly( [xLongStudy{DTMIncludingPoint(i1)}(NearestPoint(i1)), ...
                                                  yLatStudy{DTMIncludingPoint(i1)}(NearestPoint(i1))], x, y ), pp_veg, ee_veg));
        if isempty(VegPolygon)
            InfoDetectedSoilSlips{i1,16} = 'No Vegetation';
        else
            InfoDetectedSoilSlips{i1,16} = VegetationAllUnique{VegPolygon};
        end
    end

    InfoDetectedSoilSlips{i1,17} = betastarStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,18} = RootStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));

    % Intersection of detected point with land use
    if ~AnswerLandUseAttribution
        InfoDetectedSoilSlips{i1,19} = 'Land Use not processed';
    else
        [pp_lu, ee_lu] = arrayfun(@(x) getnan2(x.Vertices), LandUsePolygonsStudyArea, 'UniformOutput',false);
        LUPolygon = find(cellfun(@(x,y) inpoly( [xLongStudy{DTMIncludingPoint(i1)}(NearestPoint(i1)), ...
                                                  yLatStudy{DTMIncludingPoint(i1)}(NearestPoint(i1))], x, y ), pp_lu, ee_lu));
        if isempty(LUPolygon)
            InfoDetectedSoilSlips{i1,19} = 'Land Use not specified';
        else
            InfoDetectedSoilSlips{i1,19} = AllLandUnique{LUPolygon};
        end
    end

    %% Parameter attribution for every sub area of each detected soil slip
    if ChoiceSubArea

        NearestPoints = [InfoPointsNearDetectedSoilSlips{i1,4}{:,2}];
        InfoPointsNearDetectedSoilSlips{i1,4}(:,3) = num2cell(xLongStudy{DTMIncludingPoint(i1)}(NearestPoints));
        InfoPointsNearDetectedSoilSlips{i1,4}(:,4) = num2cell(yLatStudy{DTMIncludingPoint(i1)}(NearestPoints));
        InfoPointsNearDetectedSoilSlips{i1,4}(:,5) = num2cell(ElevationStudy{DTMIncludingPoint(i1)}(NearestPoints));
        InfoPointsNearDetectedSoilSlips{i1,4}(:,6) = num2cell(SlopeStudy{DTMIncludingPoint(i1)}(NearestPoints));
        InfoPointsNearDetectedSoilSlips{i1,4}(:,7) = num2cell(AspectStudy{DTMIncludingPoint(i1)}(NearestPoints));

        % Intersection of detected point with litho
        if ~AnswerAttributionSoilParameter
            InfoPointsNearDetectedSoilSlips{i1,4}(:,8) = cellstr( repmat("Uniform", size(NearestPoints))' );
        else
            [pp_lit, ee_lit] = arrayfun(@(x) getnan2(x.Vertices), LithoPolygonsStudyArea, 'UniformOutput',false);
            LithoPolygons = cell2mat(cellfun(@(x,y) inpoly( [xLongStudy{DTMIncludingPoint(i1)}(NearestPoints), ...
                                                             yLatStudy{DTMIncludingPoint(i1)}(NearestPoints)  ], x, y ), ... 
                                                    pp_lit, ee_lit, 'UniformOutput',false));
            for i2 = 1:length(NearestPoints)
                LithoPolygonsInd = find(LithoPolygons(i2,:));
                if isempty(LithoPolygonsInd)
                    InfoPointsNearDetectedSoilSlips{i1,4}(i2,8) = cellstr('No Litho');
                else
                    InfoPointsNearDetectedSoilSlips{i1,4}(i2,8) = LithoAllUnique(LithoPolygonsInd);
                end
            end
        end

        InfoPointsNearDetectedSoilSlips{i1,4}(:,9)  = num2cell(CohesionStudy{DTMIncludingPoint(i1)}(NearestPoints));
        InfoPointsNearDetectedSoilSlips{i1,4}(:,10) = num2cell(PhiStudy{DTMIncludingPoint(i1)}(NearestPoints));
        InfoPointsNearDetectedSoilSlips{i1,4}(:,11) = num2cell(kStudy{DTMIncludingPoint(i1)}(NearestPoints));
        InfoPointsNearDetectedSoilSlips{i1,4}(:,12) = num2cell(AStudy{DTMIncludingPoint(i1)}(NearestPoints));
        InfoPointsNearDetectedSoilSlips{i1,4}(:,13) = num2cell(nStudy{DTMIncludingPoint(i1)}(NearestPoints));

        % Intersection of detected point with veg
        if ~AnswerAttributionVegetationParameter
            InfoPointsNearDetectedSoilSlips{i1,4}(:,14) = cellstr( repmat("Uniform", size(NearestPoints))' );
        else
            [pp_veg, ee_veg] = arrayfun(@(x) getnan2(x.Vertices), VegPolygonsStudyArea, 'UniformOutput',false);
            VegPolygons = cell2mat(cellfun(@(x,y) inpoly( [xLongStudy{DTMIncludingPoint(i1)}(NearestPoints), ...
                                                           yLatStudy{DTMIncludingPoint(i1)}(NearestPoints)  ], x, y ), ...
                                                  pp_veg, ee_veg, 'UniformOutput',false));
            for i2 = 1:length(NearestPoints)
                VegPolygonsInd = find(VegPolygons(i2,:));
                if isempty(VegPolygonsInd)
                    InfoPointsNearDetectedSoilSlips{i1,4}(i2,14) = cellstr('No Vegetation');
                else
                    InfoPointsNearDetectedSoilSlips{i1,4}(i2,14) = VegetationAllUnique(VegPolygonsInd);
                end
            end
        end

        InfoPointsNearDetectedSoilSlips{i1,4}(:,15) = num2cell(betastarStudy{DTMIncludingPoint(i1)}(NearestPoints));
        InfoPointsNearDetectedSoilSlips{i1,4}(:,16) = num2cell(RootStudy{DTMIncludingPoint(i1)}(NearestPoints));

        % Intersection of detected point with land use
        if ~AnswerLandUseAttribution
            InfoPointsNearDetectedSoilSlips{i1,4}(:,17) = cellstr( repmat("Land Use not processed", size(NearestPoints))' );
        else
            [pp_lu, ee_lu] = arrayfun(@(x) getnan2(x.Vertices), LandUsePolygonsStudyArea, 'UniformOutput',false);
            LUPolygons = cell2mat(cellfun(@(x,y) inpoly( [xLongStudy{DTMIncludingPoint(i1)}(NearestPoints), ...
                                                         yLatStudy{DTMIncludingPoint(i1)}(NearestPoints)  ], x, y ), ...
                                                  pp_lu, ee_lu, 'UniformOutput',false));
            for i2 = 1:length(NearestPoints)
                LUPolygonsInd = find(LUPolygons(i2,:));
                if isempty(LUPolygonsInd)
                    InfoPointsNearDetectedSoilSlips{i1,4}(i2,17) = cellstr('Land Use not specified');
                else
                    InfoPointsNearDetectedSoilSlips{i1,4}(i2,17) = AllLandUnique(LUPolygonsInd);
                end
            end
        end

    end

end

%% Option to show or not tables
Options = {'Yes', 'No'};
ShowTable = uiconfirm(Fig, 'Do you want to show tables?', ...
                           'Tables plot', 'Options',Options);
if strcmp(ShowTable,'Yes'); ShowTable = true; else; ShowTable = false; end

%% Creation of table
TabParameters = cell2table(InfoDetectedSoilSlips);

ColumnNames = {'Municipality', 'Location', 'N. DTM', 'Pos Elem', 'Long (°)', 'Lat (°)', ...
               'Elevation (m)', 'beta (°)', 'Aspect (°)', 'Soil type', 'c''(kPa)', 'phi (°)', ...
               'kt(1/h)', 'A (kPa)', 'n (-)', 'Vegetation type', 'beta* (-)', 'cr (kPa)', 'Land use'};

TabParameters.Properties.VariableNames = ColumnNames;

if ShowTable
    FigTable = uifigure('Name','Tab Parameters', 'WindowStyle','modal', 'Color',[0.97, 0.73, 0.58]);
    Tab = uitable(FigTable, 'Data',TabParameters, 'Units','normalized', 'Position',[0.01 0.01 0.98 0.98]);
end

%% Creation of table with mean or mode values for every sub area
if ChoiceSubArea
    for i1 = 1:size(InfoPointsNearDetectedSoilSlips,1)
        [LithoCount,   LithoClasses]   = histcounts(categorical(InfoPointsNearDetectedSoilSlips{i1,4}(:,8)));
        [VegCount,     VegClasses]     = histcounts(categorical(InfoPointsNearDetectedSoilSlips{i1,4}(:,14)));
        [LandUseCount, LandUseClasses] = histcounts(categorical(InfoPointsNearDetectedSoilSlips{i1,4}(:,17)));

        InfoPointsNearDetectedSoilSlips{i1,5} = cell2table([LithoClasses',   num2cell(LithoCount'),   num2cell(LithoCount'/sum(LithoCount)*100)]);
        InfoPointsNearDetectedSoilSlips{i1,6} = cell2table([VegClasses',     num2cell(VegCount'),     num2cell(VegCount'/sum(VegCount)*100)]);
        InfoPointsNearDetectedSoilSlips{i1,7} = cell2table([LandUseClasses', num2cell(LandUseCount'), num2cell(LandUseCount'/sum(LandUseCount)*100)]);
        
        ColumnNamesClasses = {'Classes', 'N. of Points', 'Percentage'};
        InfoPointsNearDetectedSoilSlips{i1,5}.Properties.VariableNames = ColumnNamesClasses;
        InfoPointsNearDetectedSoilSlips{i1,6}.Properties.VariableNames = ColumnNamesClasses;
        InfoPointsNearDetectedSoilSlips{i1,7}.Properties.VariableNames = ColumnNamesClasses;
    end
    InfoDetectedSoilSlipsAverage{2} = [InfoDetectedSoilSlips(:,1:6), ...
                    cellfun(@(x) mean([x{:,5 }]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) mean([x{:,6 }]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) mean([x{:,7 }]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) string(mode(categorical(string(x(:,8 ))))), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) mean([x{:,9 }]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) mean([x{:,10}]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) mean([x{:,11}]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) mean([x{:,12}]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) mean([x{:,13}]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) string(mode(categorical(string(x(:,14))))), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) mean([x{:,15}]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) mean([x{:,16}]), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false), ...
                    cellfun(@(x) string(mode(categorical(string(x(:,17))))), InfoPointsNearDetectedSoilSlips(:,4), 'UniformOutput',false)];

    TabAverageParameters = cell2table(InfoDetectedSoilSlipsAverage{2});
    
    ColumnNamesAverage = {'Municipality', 'Location', 'N. DTM', 'Pos Elem', 'Long (°)', ...
                          'Lat (°)', 'Av. Elevation (m)', 'Av. beta (°)', 'Av. Aspect (°)', ...
                          'Prevalent Soil type', 'Av. c''(kPa)', 'Av. phi (°)', 'Av. kt(1/h)', ...
                          'Av. A (kPa)', 'Av. n (-)', 'Prevalent Vegetation type', ...
                          'Av. beta* (-)', 'Av. cr (kPa)', 'Prevalent Land use'};
    
    TabAverageParameters.Properties.VariableNames = ColumnNamesAverage;
    
    if ShowTable
        FigTableAverage = uifigure('Name','Average Tab Parameters', 'WindowStyle','modal', 'Color',[0.97, 0.73, 0.58]);
        TabAverage = uitable(FigTableAverage, 'Data',TabAverageParameters, 'Units','normalized', 'Position',[0.01 0.01 0.98 0.98]);
    end
end

%% Saving...
save('InfoDetectedSoilSlips.mat', VariablesInfoDet{:})
cd(fold0)