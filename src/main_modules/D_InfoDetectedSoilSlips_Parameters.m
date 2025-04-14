if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading...
sl = filesep;

load([fold_var,sl,'MorphologyParameters.mat' ], 'AspectAngleAll','ElevationAll','SlopeAll')
load([fold_var,sl,'SoilParameters.mat'       ], 'AAll','CohesionAll','KtAll','PhiAll','nAll')
load([fold_var,sl,'VegetationParameters.mat' ], 'BetaStarAll','RootCohesionAll')
load([fold_var,sl,'GridCoordinates.mat'      ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','SubArea','IndDefInfoDet')
load([fold_var,sl,'UserSoil_Answers.mat'     ], 'AnswerAttributionSoilParameter')
load([fold_var,sl,'UserVeg_Answers.mat'      ], 'VegAttribution')

if SubArea
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoPointsNearDetectedSoilSlips','InfoDetectedSoilSlipsAverage')
end

AnswerAttributionVegetationParameter = -1;
if (VegAttribution ~= 0)
    load([fold_var,sl,'UserVeg_Answers.mat'], 'AnswerAttributionVegetationParameter')
end

if all(AnswerAttributionVegetationParameter ~= [-1, 0])
    load([fold_var,sl,'VegPolygonsStudyArea.mat'], 'VegetationAllUnique','VegPolygonsStudyArea')
end

if AnswerAttributionSoilParameter ~= 0
    load([fold_var,sl,'LithoPolygonsStudyArea.mat'], 'LithoAllUnique','LithoPolygonsStudyArea')
end

AnswerLandUseAttribution = 0;
if exist([fold_var,sl,'LandUsesVariables.mat'], 'file')
    load([fold_var,sl,'LandUsesVariables.mat'], 'AllLandUnique','LandUsePolygonsStudyArea','FileNameLandUsesAssociation')

    Sheet_Ass   = readcell([fold_user,sl,FileNameLandUsesAssociation],'Sheet','Association');
    AllLndUnAbb = Sheet_Ass(2:end,2)';
    EmptyCells  = any(cellfun(@(x) all(ismissing(x)), AllLndUnAbb));
    if EmptyCells; AllLndUnAbb = AllLandUnique; end

    AnswerLandUseAttribution = 1;
end

%% Option to show or not tables
ShowTable = uiconfirm(Fig, 'Do you want to show tables?', ...
                           'Tables plot', 'Options',{'Yes', 'No'});
if strcmp(ShowTable,'Yes'); ShowTable = true; else; ShowTable = false; end

%% Extraction of points in Study Area and Detected points
ProgressBar.Message = 'Data extraction...';

xLongStudy          = cellfun(@(x,y) x(y), xLongAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudy           = cellfun(@(x,y) x(y), yLatAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('yLatAll')

ElevationStudy      = cellfun(@(x,y) x(y), ElevationAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('ElevationAll')

SlopeStudy          = cellfun(@(x,y) x(y), SlopeAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('SlopeAll')

AspectStudy         = cellfun(@(x,y) x(y), AspectAngleAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('AspectAngleAll')

CohesionStudy       = cellfun(@(x,y) x(y), CohesionAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('CohesionAll')

PhiStudy            = cellfun(@(x,y) x(y), PhiAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('PhiAll')

nStudy              = cellfun(@(x,y) x(y), nAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('nAll')

kStudy              = cellfun(@(x,y) x(y), KtAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('KtAll')

AStudy              = cellfun(@(x,y) x(y), AAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('AAll')

BetaStarStudy       = cellfun(@(x,y) x(y), BetaStarAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('BetaStarAll')

RootStudy           = cellfun(@(x,y) x(y), RootCohesionAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('RootCohesionAll')

%% Creation of variables to save
VariablesInfoDet = {'InfoDetectedSoilSlips'};
if SubArea
    VariablesInfoDet = [VariablesInfoDet, {'InfoPointsNearDetectedSoilSlips', 'InfoDetectedSoilSlipsAverage'}];
end

%% Start of the loop for each detected point
ProgressBar.Message = 'Processing...';

for i1 = 1:length(InfoDetectedSoilSlips)
    DTMIncludingPoint = [InfoDetectedSoilSlips{i1}{:,3}]';
    NearestPoint      = [InfoDetectedSoilSlips{i1}{:,4}]';
    
    for i2 = 1:numel(DTMIncludingPoint) 
        InfoDetectedSoilSlips{i1}{i2,7} = ElevationStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
        InfoDetectedSoilSlips{i1}{i2,8} = SlopeStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
        InfoDetectedSoilSlips{i1}{i2,9} = AspectStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
    
        % Intersection of detected point with litho
        if AnswerAttributionSoilParameter == 0
            InfoDetectedSoilSlips{i1}{i2,10} = "Uniform";
        else
            [pp_lit, ee_lit] = arrayfun(@(x) getnan2(x.Vertices), LithoPolygonsStudyArea, 'UniformOutput',false); % In every cell a different polygon or mulrypolygon of the same litho
            LithoPolygon = find(cellfun(@(x,y) inpoly( [xLongStudy{DTMIncludingPoint(i2)}(NearestPoint(i2)), ...
                                                        yLatStudy{DTMIncludingPoint(i2)}(NearestPoint(i2))], x, y ), pp_lit, ee_lit));
            if isempty(LithoPolygon)
                InfoDetectedSoilSlips{i1}{i2,10} = "No Litho";
            else
                InfoDetectedSoilSlips{i1}{i2,10} = string(LithoAllUnique{LithoPolygon});
            end
        end
    
        InfoDetectedSoilSlips{i1}{i2,11} = CohesionStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
        InfoDetectedSoilSlips{i1}{i2,12} = PhiStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
        InfoDetectedSoilSlips{i1}{i2,13} = kStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
        InfoDetectedSoilSlips{i1}{i2,14} = AStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
        InfoDetectedSoilSlips{i1}{i2,15} = nStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
    
        % Intersection of detected point with veg
        if AnswerAttributionVegetationParameter == -1
            InfoDetectedSoilSlips{i1}{i2,16} = "Vegetation not processed";
        elseif AnswerAttributionVegetationParameter == 0
            InfoDetectedSoilSlips{i1}{i2,16} = "Uniform";
        else
            [pp_veg, ee_veg] = arrayfun(@(x) getnan2(x.Vertices), VegPolygonsStudyArea, 'UniformOutput',false);
            VegPolygon = find(cellfun(@(x,y) inpoly( [xLongStudy{DTMIncludingPoint(i2)}(NearestPoint(i2)), ...
                                                      yLatStudy{DTMIncludingPoint(i2)}(NearestPoint(i2))], x, y ), pp_veg, ee_veg));
            if isempty(VegPolygon)
                InfoDetectedSoilSlips{i1}{i2,16} = "No Vegetation";
            else
                InfoDetectedSoilSlips{i1}{i2,16} = string(VegetationAllUnique{VegPolygon});
            end
        end
    
        InfoDetectedSoilSlips{i1}{i2,17} = BetaStarStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
        InfoDetectedSoilSlips{i1}{i2,18} = RootStudy{DTMIncludingPoint(i2)}(NearestPoint(i2));
    
        % Intersection of detected point with land use
        if AnswerLandUseAttribution == 0
            InfoDetectedSoilSlips{i1}{i2,19} = "Land Use not processed";
        else
            [pp_lu, ee_lu] = arrayfun(@(x) getnan2(x.Vertices), LandUsePolygonsStudyArea, 'UniformOutput',false);
            LUPolygon = find(cellfun(@(x,y) inpoly( [xLongStudy{DTMIncludingPoint(i2)}(NearestPoint(i2)), ...
                                                      yLatStudy{DTMIncludingPoint(i2)}(NearestPoint(i2))], x, y ), pp_lu, ee_lu));
            if isempty(LUPolygon)
                InfoDetectedSoilSlips{i1}{i2,19} = "Land Use not specified";
            else
                InfoDetectedSoilSlips{i1}{i2,19} = string(AllLndUnAbb{LUPolygon});
            end
        end
    
        %% Parameter attribution for every sub area of each detected soil slip
        if SubArea
            DTMNP = unique([InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}{:,1}]);
            for i3 = 1:length(DTMNP)
                RowWithDTMNP = find([InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}{:,1}] == DTMNP(i3));
                NearestPoints = [InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}{RowWithDTMNP,2}];
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,3) = num2cell(xLongStudy{DTMNP(i3)}(NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,4) = num2cell(yLatStudy{DTMNP(i3)}(NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,5) = num2cell(ElevationStudy{DTMNP(i3)}(NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,6) = num2cell(SlopeStudy{DTMNP(i3)}(NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,7) = num2cell(AspectStudy{DTMNP(i3)}(NearestPoints));
        
                % Intersection of detected point with soil
                if AnswerAttributionSoilParameter == 0
                    InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,8) = cellstr( repmat("Uniform", size(NearestPoints)) );
                else
                    [pp_lit, ee_lit] = arrayfun(@(x) getnan2(x.Vertices), LithoPolygonsStudyArea, 'UniformOutput',false);
                    SoilPlys = cell2mat(cellfun(@(x,y) inpoly( [xLongStudy{DTMNP(i3)}(NearestPoints), ...
                                                                yLatStudy{DTMNP(i3)}(NearestPoints)  ], x, y ), ... 
                                                            pp_lit, ee_lit, 'UniformOutput',false));
                    for i4 = 1:length(NearestPoints)
                        SoilPlyInd = find(SoilPlys(i4,:));
                        if isempty(SoilPlyInd)
                            InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP(i4),8) = {"No Litho"};
                        else
                            InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP(i4),8) = {string(LithoAllUnique(SoilPlyInd))};
                        end
                    end
                end
        
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,9 ) = num2cell(CohesionStudy{DTMNP(i3)}(NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,10) = num2cell(PhiStudy{DTMNP(i3)}(NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,11) = num2cell(kStudy{DTMNP(i3)}(NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,12) = num2cell(AStudy{DTMNP(i3)}(NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,13) = num2cell(nStudy{DTMNP(i3)}(NearestPoints));
        
                % Intersection of detected point with veg
                if AnswerAttributionVegetationParameter == -1
                    InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,14) = cellstr( repmat("Vegetation not processed", size(NearestPoints)) );
                elseif AnswerAttributionVegetationParameter == 0
                    InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,14) = cellstr( repmat("Uniform", size(NearestPoints)) );
                else
                    [pp_veg, ee_veg] = arrayfun(@(x) getnan2(x.Vertices), VegPolygonsStudyArea, 'UniformOutput',false);
                    VegtPlys = cell2mat(cellfun(@(x,y) inpoly( [xLongStudy{DTMNP(i3)}(NearestPoints), ...
                                                                yLatStudy{DTMNP(i3)}(NearestPoints)  ], x, y ), ...
                                                          pp_veg, ee_veg, 'UniformOutput',false));
                    for i4 = 1:length(NearestPoints)
                        VegtPlyInd = find(VegtPlys(i4,:));
                        if isempty(VegtPlyInd)
                            InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP(i4),14) = {"No Vegetation"};
                        else
                            InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP(i4),14) = {string(VegetationAllUnique(VegtPlyInd))};
                        end
                    end
                end
        
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,15) = num2cell(BetaStarStudy{DTMNP(i3)}(NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,16) = num2cell(RootStudy{DTMNP(i3)}(NearestPoints));
        
                % Intersection of detected point with land use
                if AnswerLandUseAttribution == 0
                    InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP,17) = cellstr( repmat("Land Use not processed", size(NearestPoints)) );
                else
                    [pp_lu, ee_lu] = arrayfun(@(x) getnan2(x.Vertices), LandUsePolygonsStudyArea, 'UniformOutput',false);
                    LdUsPlys = cell2mat(cellfun(@(x,y) inpoly( [xLongStudy{DTMNP(i3)}(NearestPoints), ...
                                                                yLatStudy{DTMNP(i3)}(NearestPoints)  ], x, y ), ...
                                                          pp_lu, ee_lu, 'UniformOutput',false));
                    for i4 = 1:length(NearestPoints)
                        LdUsPlyInd = find(LdUsPlys(i4,:), 1); % Sometimes it can happen that you have multiple classes, the first will be taken
                        if isempty(LdUsPlyInd)
                            InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP(i4),17) = {"Land Use not specified"};
                        else
                            InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}(RowWithDTMNP(i4),17) = {string(AllLndUnAbb(LdUsPlyInd))};
                        end
                    end
                end

            end % end of DTMNP
        end % end of SubArea
    
    end % end of DTMIncludingPoint
end % end of InfoDetectedSoilSlips

%% Creation of table
if ShowTable
    ProgressBar.Message = 'Creating tables...';

    % ColumnNames = {'Municipality', 'Location', 'N. DTM', 'Pos Elem', 'Long (°)', 'Lat (°)', ...
    %                'Elevation (m)', 'beta (°)', 'Aspect (°)', 'Soil type', 'c''(kPa)', 'phi (°)', ...
    %                'kt(1/h)', 'A (kPa)', 'n (-)', 'Vegetation type', 'beta* (-)', 'cr (kPa)', 'Land use'};

    FigTbl = uifigure('Name','Tab Parameters', 'WindowStyle','modal', 'Color',[0.97, 0.73, 0.58]);
    ObjTbl = uitable(FigTbl, 'Data',InfoDetectedSoilSlips{IndDefInfoDet}, 'Units','normalized', 'Position',[0.01 0.01 0.98 0.98]);
end

%% Creation of table with mean or mode values for every sub area
if SubArea
    ProgressBar.Message = 'Attributing averaged porperties...';
    for i1 = 1:length(InfoDetectedSoilSlips)

        for i2 = 1:size(InfoPointsNearDetectedSoilSlips{i1},1)
            ColNmsClss = {'Classes', 'N. of Points', 'Percentage'};

            [SoilCount, SoilClasses] = histcounts(categorical(InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}{:,'Soil'}));
            [VegtCount, VegtClasses] = histcounts(categorical(InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}{:,'Vegetation'}));
            [LndUCount, LndUClasses] = histcounts(categorical(InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}{:,'Land use'}));
    
            InfoPointsNearDetectedSoilSlips{i1}{i2,5} = {cell2table([SoilClasses', num2cell(SoilCount'), num2cell(SoilCount'/sum(SoilCount)*100)], 'VariableNames',ColNmsClss)};
            InfoPointsNearDetectedSoilSlips{i1}{i2,6} = {cell2table([VegtClasses', num2cell(VegtCount'), num2cell(VegtCount'/sum(VegtCount)*100)], 'VariableNames',ColNmsClss)};
            InfoPointsNearDetectedSoilSlips{i1}{i2,7} = {cell2table([LndUClasses', num2cell(LndUCount'), num2cell(LndUCount'/sum(LndUCount)*100)], 'VariableNames',ColNmsClss)};
        end

        InfDetAvgSCell = cell(size(InfoPointsNearDetectedSoilSlips{i1}, 1), size(InfoPointsNearDetectedSoilSlips{i1}{1,4}{:}, 2));
        for i2 = 1:size(InfDetAvgSCell,2)
            if isnumeric(InfoPointsNearDetectedSoilSlips{i1}{1,4}{:}{1,i2})
                InfDetAvgSCell(:,i2) = cellfun(@(x) mean([x{:,i2}]), InfoPointsNearDetectedSoilSlips{i1}{:,4}, 'UniformOutput',false);
            else
                InfDetAvgSCell(:,i2) = cellfun(@(x) string(mode(categorical(x{:,i2}))), InfoPointsNearDetectedSoilSlips{i1}{:,4}, 'UniformOutput',false);
            end
        end
        InfDetSlSlpAvg = cell2table(InfDetAvgSCell(:,5:end), 'VariableNames',InfoDetectedSoilSlips{i1}.Properties.VariableNames(7:19));

        InfoDetectedSoilSlipsAverage{i1}{2} = [InfoDetectedSoilSlips{i1}(:,1:6), ...
                                               InfDetSlSlpAvg, InfoDetectedSoilSlips{i1}(:,20)];
                                               
    end
    
    if ShowTable
        % ColumnNamesAverage = {'Municipality', 'Location', 'N. DTM', 'Pos Elem', 'Long (°)', ...
        %                       'Lat (°)', 'Av. Elevation (m)', 'Av. beta (°)', 'Av. Aspect (°)', ...
        %                       'Prevalent Soil type', 'Av. c''(kPa)', 'Av. phi (°)', 'Av. kt(1/h)', ...
        %                       'Av. A (kPa)', 'Av. n (-)', 'Prevalent Vegetation type', ...
        %                       'Av. beta* (-)', 'Av. cr (kPa)', 'Prevalent Land use'};

        FigTblAvg = uifigure('Name','Average Tab Parameters', 'WindowStyle','modal', 'Color',[0.97, 0.73, 0.58]);
        ObjTblAvg = uitable(FigTblAvg, 'Data',InfoDetectedSoilSlipsAverage{IndDefInfoDet}{2}, 'Units','normalized', 'Position',[0.01 0.01 0.98 0.98]);
    end
end

%% Saving...
ProgressBar.Message = 'Saving...';

saveswitch([fold_var,sl,'InfoDetectedSoilSlips.mat'], VariablesInfoDet, '-append')