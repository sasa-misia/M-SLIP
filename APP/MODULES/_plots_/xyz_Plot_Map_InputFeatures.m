 if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% Loading data
sl = filesep;

load([fold_var,sl,'DatasetStudy.mat'      ], 'DatasetStudyInfo','DatasetStudyFeatsNotNorm','RangesForNorm')
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon','MaxExtremes','MinExtremes')
load([fold_var,sl,'GridCoordinates.mat'   ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SelFont  = Font;
    SelFntSz = FontSize;
else
    SelFont  = 'Times New Roman';
    SelFntSz = 4;
end
if exist('LegendPosition', 'var')
    LgndPos = LegendPosition;
else
    LgndPos = 'eastoutside';
end

%% Selection of feats to use
DsetFeats = DatasetStudyFeatsNotNorm.Properties.VariableNames;
FeatsUsed = DatasetStudyInfo.FeaturesNames{:};
FeatsOpts = {'Elevation', 'Slope', 'Aspect Angle', 'Mean Curvature', ...
             'Sub Soil Class', 'Top Soil Class', 'Land Use Class', ...
             'Vegetation Class', 'Rainfall'}; % This represent the features already implemented!
Feats2Mnt = false(size(FeatsOpts));
for i1 = 1:numel(FeatsOpts)
    Str2Anlz  = split(FeatsOpts(i1));
    FtsChkTmp = false(numel(Str2Anlz), numel(FeatsUsed));
    for i2 = 1:numel(Str2Anlz)
        FtsChkTmp(i2, :) = cellfun(@(x) contains(x, Str2Anlz{i2}, 'IgnoreCase',true), FeatsUsed); 
    end
    Feats2Mnt(i1) = any(all(FtsChkTmp, 1));
end
FeatsPoss = FeatsOpts(Feats2Mnt);
Feats2Use = checkbox2(FeatsPoss, 'Title',{'Select features to use:'});

%% Loading features
[ScatterFeats, ScatterDtAll, ScatterUnits, PolygonFeats, PolygonDtStd, ...
    PolygonDtNms, TimeSensFeats, TimeSensDtTm, TimeSensDtAll, TimeSensUnits] = deal({});
TimeSensCmlb = deal(logical([]));

% Elevation
if any(contains(Feats2Use, 'Elev', 'IgnoreCase',true))
    if exist([fold_var,sl,'MorphologyParameters.mat'    ], 'file')
        load([fold_var,sl,'MorphologyParameters.mat'    ], 'ElevationAll')
    end
    if not(exist('ElevationAll', 'var'))
        error('ElevationAll not found in MorphologyParameters.mat')
    end
    ScatterFeats = [ScatterFeats, {'Elevation' }];
    ScatterUnits = [ScatterUnits, {' [m]'      }];
    ScatterDtAll = [ScatterDtAll, {ElevationAll}];
    clear('ElevationAll')
end

% Slope
if any(contains(Feats2Use, 'Slope', 'IgnoreCase',true))
    if exist([fold_var,sl,'MorphologyParameters.mat'    ], 'file')
        load([fold_var,sl,'MorphologyParameters.mat'    ], 'SlopeAll')
    end
    if not(exist('SlopeAll', 'var'))
        error('SlopeAll not found in MorphologyParameters.mat')
    end
    ScatterFeats = [ScatterFeats, {'Slope' }];
    ScatterUnits = [ScatterUnits, {' [°]'  }];
    ScatterDtAll = [ScatterDtAll, {SlopeAll}];
    clear('SlopeAll')
end

% Aspect Angle
if any(contains(Feats2Use, 'Aspect', 'IgnoreCase',true))
    if exist([fold_var,sl,'MorphologyParameters.mat'    ], 'file')
        load([fold_var,sl,'MorphologyParameters.mat'    ], 'AspectAngleAll')
    end
    if not(exist('AspectAngleAll', 'var'))
        error('AspectAngleAll not found in MorphologyParameters.mat')
    end
    ScatterFeats = [ScatterFeats, {'Aspect Angle'}];
    ScatterUnits = [ScatterUnits, {' [°]'        }];
    ScatterDtAll = [ScatterDtAll, {AspectAngleAll}];
    clear('AspectAngleAll')
end

% Mean Curvature
if any(contains(Feats2Use, 'Mean'+wildcardPattern+'Curv', 'IgnoreCase',true))
    if exist([fold_var,sl,'MorphologyParameters.mat'    ], 'file')
        load([fold_var,sl,'MorphologyParameters.mat'    ], 'MeanCurvatureAll')
    end
    if not(exist('MeanCurvatureAll', 'var'))
        error('MeanCurvatureAll not found in MorphologyParameters.mat')
    end
    ScatterFeats = [ScatterFeats, {'Mean Curvature'}];
    ScatterUnits = [ScatterUnits, {' [1/m]'        }];
    ScatterDtAll = [ScatterDtAll, {MeanCurvatureAll}];
    clear('MeanCurvatureAll')
end

% Sub Soil Class
if any(contains(Feats2Use, 'Sub'+wildcardPattern+'Soil', 'IgnoreCase',true))
    if exist([fold_var,sl,'LithoPolygonsStudyArea.mat'  ], 'file')
        load([fold_var,sl,'LithoPolygonsStudyArea.mat'  ], 'LithoPolygonsStudyArea','LithoAllUnique')
    end
    if not(exist('LithoPolygonsStudyArea', 'var'))
        error('LithoPolygonsStudyArea not found in LithoPolygonsStudyArea.mat')
    end
    PolygonFeats = [PolygonFeats, {'Sub Soil Class'}];
    PolygonDtStd = [PolygonDtStd, {LithoPolygonsStudyArea}];
    PolygonDtNms = [PolygonDtNms, {LithoAllUnique}];
    clear('LithoPolygonsStudyArea', 'LithoAllUnique')
end

% Top Soil Class
if any(contains(Feats2Use, 'Top'+wildcardPattern+'Class', 'IgnoreCase',true))
    if exist([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], 'file')
        load([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], 'TopSoilPolygonsStudyArea','TopSoilAllUnique')
    end
    if not(exist('TopSoilPolygonsStudyArea', 'var'))
        error('TopSoilPolygonsStudyArea not found in TopSoilPolygonsStudyArea.mat')
    end
    PolygonFeats = [PolygonFeats, {'Top Soil Class'}];
    PolygonDtStd = [PolygonDtStd, {TopSoilPolygonsStudyArea}];
    PolygonDtNms = [PolygonDtNms, {TopSoilAllUnique}];
    clear('TopSoilPolygonsStudyArea', 'TopSoilAllUnique')
end

% Vegetation Class
if any(contains(Feats2Use, 'Veg'+wildcardPattern+'Class', 'IgnoreCase',true))
    if exist([fold_var,sl,'VegPolygonsStudyArea.mat'    ], 'file')
        load([fold_var,sl,'VegPolygonsStudyArea.mat'    ], 'VegPolygonsStudyArea','VegetationAllUnique')
    end
    if not(exist('VegPolygonsStudyArea', 'var'))
        error('VegPolygonsStudyArea not found in VegPolygonsStudyArea.mat')
    end
    PolygonFeats = [PolygonFeats, {'Vegetation Class'}];
    PolygonDtStd = [PolygonDtStd, {VegPolygonsStudyArea}];
    PolygonDtNms = [PolygonDtNms, {VegetationAllUnique}];
    clear('VegPolygonsStudyArea', 'VegetationAllUnique')
end

% Land Use Class
if any(contains(Feats2Use, 'Land'+wildcardPattern+'Class', 'IgnoreCase',true))
    if exist([fold_var,sl,'LandUsesVariables.mat'       ], 'file')
        load([fold_var,sl,'LandUsesVariables.mat'       ], 'LandUsePolygonsStudyArea','AllLandUnique')
    end
    if not(exist('LandUsePolygonsStudyArea', 'var'))
        error('LandUsePolygonsStudyArea not found in LandUsesVariables.mat')
    end
    PolygonFeats = [PolygonFeats, {'Land Use Class'}];
    PolygonDtStd = [PolygonDtStd, {LandUsePolygonsStudyArea}];
    PolygonDtNms = [PolygonDtNms, {AllLandUnique}];
    clear('LandUsePolygonsStudyArea', 'AllLandUnique')
end

% Rainfall
if any(contains(Feats2Use, 'Rain', 'IgnoreCase',true))
    if exist([fold_var,sl,'RainInterpolated.mat'        ], 'file')
        load([fold_var,sl,'RainInterpolated.mat'        ], 'RainInterpolated','RainDateInterpolationStarts')
    end
    if not(exist('RainInterpolated', 'var'))
        error('RainInterpolated not found in RainInterpolated.mat')
    end
    if not(exist('RainDateInterpolationStarts', 'var'))
        error('RainDateInterpolationStarts not found in RainInterpolated.mat')
    end
    TimeSensFeats = [TimeSensFeats, {'Rainfall'                 }];
    TimeSensUnits = [TimeSensUnits, {' [mm]'                    }];
    TimeSensCmlb  = [TimeSensCmlb , true                         ];
    TimeSensDtTm  = [TimeSensDtTm , {RainDateInterpolationStarts}];
    TimeSensDtAll = [TimeSensDtAll, {RainInterpolated           }];
    clear('RainDateInterpolationStarts', 'RainInterpolated')
end

PlotList = [ScatterFeats, PolygonFeats, TimeSensFeats]; % YOU CAN ALSO CHANGE THIS ORDER TO MODIFY ORDER OF PLOTS! PLEASE INTEGRATE IT!

%% Options
ProgressBar.Message = 'Options...';

PltVals = inputdlg2({'Sepatayor for legend descriptions:', ...
                     'Min area percentage for polygons [%]:', ...
                     'Max num of characters in legend:', ...
                     'Number of colors for TS'}, 'DefInp',{' - ', '2', '25', '8'});
LegSep  = string(PltVals{1});
MinPerc = str2double(PltVals{2}); % This value is expressed in percentage
MaxLnTx = str2double(PltVals{3});
RngsTS  = str2double(PltVals{4}) + 1; % +1 because of the fact that values for ranges are 1 more.

ShowOpt = checkbox2({'Show box', 'Show titles', 'Show plots', ...
                     'Cut ranges', 'Unique ranges TS'}, 'OutType','LogInd', ...
                                                        'DefInp',logical([0, 1, 0, 0, 1]));
ShowBox = ShowOpt(1);
ShowTtl = ShowOpt(2);
ShowPlt = ShowOpt(3);
RngsCut = ShowOpt(4);
EqlRnTS = ShowOpt(5);

EdgeColInt  = 'none';
LineExtSize = 0.8;
LineIntSize = .5;

RainManualColors = true;

DimItemPolyLeg = [3, 3];
DimItemScatLeg = 1.38*DimItemPolyLeg(1);

Options    = {'Unique Figure', 'Separate Figures'};
PlotChoice = uiconfirm(Fig, 'How do you want to plot figures?', ...
                            'Plot choice', 'Options',Options, 'DefaultOption',1);

if strcmp(PlotChoice, 'Separate Figures')
    PlotOpts = num2cell(checkbox2(PlotList, 'Title',{'What do you want to plot?'}, 'OutType','NumInd'));
    SclPxl   = .05;
else
    PlotOpts = {1:numel(PlotList)};
    SclPxl   = .2;
end

%% Date check and uniformization for time sensitive part (rain rules the others)
ProgressBar.Message = 'Defining time sensitive part...';

IndRain   = find(strcmp('Rainfall', TimeSensFeats));
if numel(IndRain) ~= 1; error('Rain time sensitive part must be stored in just one cell!'); end
IndEvent  = listdlg2({'Date of the instability event:'}, TimeSensDtTm{IndRain}, 'OutType','NumInd', ...
                                                                                'DefInp',numel(TimeSensDtTm{IndRain}));
EventDate = TimeSensDtTm{IndRain}(IndEvent);

StartDateCommon = max(cellfun(@min, TimeSensDtTm));

if length(TimeSensFeats) > 1
    for i1 = 1 : length(TimeSensFeats)
        IndStartTemp      = find(StartDateCommon == TimeSensDtTm{i1}); % You should put an equal related to days and not exact timing
        IndEventTemp      = find(EventDate == TimeSensDtTm{i1}); % You should put an equal related to days and not exact timing
        TimeSensDtAll{i1} = TimeSensDtAll{i1}(IndStartTemp:IndEventTemp,:);
        TimeSensDtTm{i1}  = TimeSensDtTm{i1}(IndStartTemp:IndEventTemp);
    end
    if length(TimeSensDtTm)>1 && ~isequal(TimeSensDtTm{:})
        error('After uniformization dates of time sensitive, data do not match! Please check it in the script.')
    end
end

TimeSensDtTm = TimeSensDtTm{1};

%% Data extraction in study area
ProgressBar.Message = 'Extraction of data in study area...';

xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudy = cellfun(@(x,y) x(y), yLatAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('yLatAll')

ScatterDtStd = cell(size(ScatterFeats));
for i1 = 1:numel(ScatterFeats)
    ScatterDtStd{i1} = cellfun(@(x,y) x(y), ScatterDtAll{i1}, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
end
clear('ScatterDtAll')

TimeSensDtStd = cell(1, length(TimeSensFeats));
for i1 = 1:length(TimeSensFeats)
    TimeSensDtStd{i1} = cellfun(@full, TimeSensDtAll{i1}, 'UniformOutput',false);
end
clear('TimeSensDtAll')

%% Ranges & legends for morphology
ProgressBar.Message = 'Defining ranges...';

if RngsCut
    DsetScttNms = listdlg2(ScatterFeats, DsetFeats, 'DefInp',1:numel(ScatterFeats));
end

[ScatterRange, ScatterLegMap] = deal(cell(size(ScatterFeats)));
for i1 = 1:numel(ScatterFeats)
    switch ScatterFeats{i1}
        case 'Elevation'
            EleMin = min(cellfun(@min, ScatterDtStd{i1}));
            EleMax = max(cellfun(@max, ScatterDtStd{i1}));

            if RngsCut
                EleMin = max(EleMin, RangesForNorm{DsetScttNms{i1},'Min value'});
                EleMax = min(EleMax, RangesForNorm{DsetScttNms{i1},'Max value'});
            end

            ScatterRange{i1} = linspace(EleMin, EleMax, 11)';
            
            if EleMax <= 1000
                ValuesEle = round(ScatterRange{i1}, 2, 'significant');
            else
                ValuesEle = round(ScatterRange{i1}, 3, 'significant');
            end
            
            ScatterLegMap{i1} = cellstr([strcat(string(ValuesEle(1:end-1)), ...
                                         LegSep, string(ValuesEle(2:end)))]);

        case 'Slope'
            ScatterRange{i1} = [(0:10:60)'; 90];
            if RngsCut
                ScatterRange{i1} = linspace(RangesForNorm{DsetScttNms{i1},'Min value'}, ...
                                            RangesForNorm{DsetScttNms{i1},'Max value'}, 5)';
            end

            ScatterLegMap{i1} = cellstr([strcat(string(ScatterRange{i1}(1:end-1)), ...
                                         LegSep, string(ScatterRange{i1}(2:end)))]);

        case 'Aspect Angle'
            ScatterRange{i1} = (0:90:360)';
            if RngsCut
                ScatterRange{i1} = linspace(RangesForNorm{DsetScttNms{i1},'Min value'}, ...
                                            round(2/3*RangesForNorm{DsetScttNms{i1},'Max value'}, -1), 5)';
                ScatterRange{i1} = [ScatterRange{i1}; RangesForNorm{DsetScttNms{i1},'Max value'}];
            end
            
            ScatterLegMap{i1} = cellstr([strcat(string(ScatterRange{i1}(1:end-1)), ...
                                         LegSep, string(ScatterRange{i1}(2:end)))]);

        case 'Mean Curvature'
            MeanCurvMin   = min(cellfun(@min, ScatterDtStd{i1}));
            MeanCurvMax   = max(cellfun(@max, ScatterDtStd{i1}));

            if RngsCut
                MeanCurvMin = max(MeanCurvMin, RangesForNorm{DsetScttNms{i1},'Min value'});
                MeanCurvMax = min(MeanCurvMax, RangesForNorm{DsetScttNms{i1},'Max value'});
            end

            ScatterRange{i1}  = linspace(MeanCurvMin, MeanCurvMax, 10)';
            ValuesMeanCurv    = round(ScatterRange{i1}, 2, 'significant');
            ScatterLegMap{i1} = cellstr([strcat(string(ValuesMeanCurv(1:end-1)), LegSep, string(ValuesMeanCurv(2:end)))]);

        otherwise
            error('Scatter feat name not recognized in defining ranges!')
    end
end

%% Creation of goups for morphology based on ranges
ProgressBar.Message = 'Defining points inside ranges...';

ScatterIndex = deal(cell(size(ScatterFeats)));
for i1 = 1:numel(ScatterIndex)
    ScatterIndex{i1} = cell(length(ScatterRange{i1})-1, size(ScatterDtStd{i1},2));
    for i2 = 1:length(ScatterRange{i1})-1
        if i2 < length(ScatterRange{i1})-1
            ScatterIndex{i1}(i2,:) = cellfun(@(x) find(x>=ScatterRange{i1}(i2) & x<ScatterRange{i1}(i2+1)),  ScatterDtStd{i1}, 'UniformOutput',false);
        else
            ScatterIndex{i1}(i2,:) = cellfun(@(x) find(x>=ScatterRange{i1}(i2) & x<=ScatterRange{i1}(i2+1)), ScatterDtStd{i1}, 'UniformOutput',false);
        end
    end
end

%% Selection of relevant classes for categorical part
ProgressBar.Message = 'Extraction of relevant categorical classes...';

DsetPlysNms = listdlg2(PolygonFeats, DsetFeats);

[PolygonPerc, PolygonIndG] = deal(cell(1, numel(DsetPlysNms))); % Attention! PolygonIndG and PolygonPerc will not follow (different sizes) the other Polygon variables, they are just service variables!
for i1 = 1:numel(PolygonPerc)
    PolygonPerc{i1} = tabulate(DatasetStudyFeatsNotNorm.(DsetPlysNms{i1}));
    
    PolygonPerc{i1}(PolygonPerc{i1}(:,1)==0,:) = []; % Removing no class row (0)

    PolygonIndG{i1} = find(PolygonPerc{i1}(:,3) >= MinPerc);
end

%% Legends for categorical part
ProgressBar.Message = 'Defining classes for legends...';

UpdDsetStudy = false;
PolyClssTbl  = DatasetStudyInfo.ClassPolygons{:};
PolygonLgnd  = cell(1, numel(PolygonFeats));
for i1 = 1:numel(PolygonLgnd)
    PolygonLgnd{i1} = cell(1, numel(PolygonIndG{i1}));
    PolyLegNmsTemp  = PolyClssTbl{DsetPlysNms{i1}, 'ClassNames'}{:};
    PolyLegDscrTemp = PolyClssTbl{DsetPlysNms{i1}, 'ClassDescr'}{:};
    PolyLegNumTemp  = cell2mat(PolyClssTbl{DsetPlysNms{i1}, 'ClassNum'}{:});

    MissingContent  = cellfun(@(x) all(ismissing(x)), PolyLegDscrTemp);
    if any(MissingContent)
        NewDscr2Use = inputdlg2(PolyLegNmsTemp(MissingContent), 'DefInp',PolyLegNmsTemp(MissingContent));
        PolyLegDscrTemp(MissingContent) = NewDscr2Use;

        UpdDsetInfoAns = uiconfirm(Fig, 'Do you want to update DatasetInfo with the last info?', ...
                                        'Update DatasetInfo', 'Options',{'Yes','No'}, 'DefaultOption',1);
        if strcmp(UpdDsetInfoAns,'Yes')
            UpdDsetStudy = true;
            DatasetStudyInfo.ClassPolygons{:}{DsetPlysNms{i1}, 'ClassDescr'}{:} = PolyLegDscrTemp;
        end
    end

    % Realignment between PolygonLgnd, PolygonDtNms, and PolygonDtStd
    IndOrd = cellfun(@(x) find(strcmp(x, PolygonDtNms{i1})), PolyLegNmsTemp, 'UniformOutput',false);
    ChckRl = cellfun(@isempty, IndOrd);
    if any(ChckRl)
        CorrIndEmpty   = listdlg2(PolyLegNmsTemp(ChckRl), PolygonDtNms{i1}, 'OutType','NumInd');
        IndOrd(ChckRl) = num2cell(CorrIndEmpty);
    end
    IndOrd = cell2mat(IndOrd);
    if numel(unique(IndOrd)) ~= numel(PolyLegNmsTemp)
        error('There is no 1 to 1 correspondence between PolyLegNmsTemp and PolygonDtNms')
    end

    PolygonDtNms{i1} = PolygonDtNms{i1}(IndOrd); % It will have the same order of PolyLegDscrTemp
    PolygonDtStd{i1} = PolygonDtStd{i1}(IndOrd); % It will have the same order of PolyLegDscrTemp

    % New order consistent with PolygonIndG
    IndOrdLegG = zeros(numel(PolygonLgnd{i1}), 1);
    for i2 = 1:numel(PolygonLgnd{i1})
        IndOrdLegG(i2) = find(PolygonPerc{i1}(PolygonIndG{i1}(i2), 1) == PolyLegNumTemp);
    end
    PolygonLgnd{i1}  = PolyLegDscrTemp(IndOrdLegG);  % It will have the same order of PolygonIndG
    PolygonDtNms{i1} = PolygonDtNms{i1}(IndOrdLegG); % It will have the same order of PolygonIndG
    PolygonDtStd{i1} = PolygonDtStd{i1}(IndOrdLegG); % It will have the same order of PolygonIndG

    IndLegChosed     = checkbox2(PolygonLgnd{i1}, 'Title',{'What do you want to mantain?'}, 'OutType','NumInd');
    PolygonLgnd{i1}  = PolygonLgnd{i1}(IndLegChosed);  % It will be correct just with the chosen classes
    PolygonIndG{i1}  = PolygonIndG{i1}(IndLegChosed);  % It will be correct just with the chosen classes
    PolygonDtNms{i1} = PolygonDtNms{i1}(IndLegChosed); % It will be correct just with the chosen classes
    PolygonDtStd{i1} = PolygonDtStd{i1}(IndLegChosed); % It will be correct just with the chosen classes
end

if UpdDsetStudy
    save([fold_var,sl,'DatasetStudy.mat'], 'DatasetStudyInfo', '-append')
end

%% Creation of Time sensitive data
ProgressBar.Message = 'Creation of time sensitive data...';

DaysInput = inputdlg2({['Days for TS (max is ', ...
                        num2str(length(TimeSensDtTm)),')']}, 'DefInp',{'[10, 30, 60]'});
DaysToCumTimeSens = str2num(DaysInput{1});

TimeSensOperType = repmat({'Averaged'}, 1, length(TimeSensFeats));
TimeSensOperType(TimeSensCmlb) = {'Cumulated'};

TimeSensParLabel = cell(length(TimeSensFeats), length(DaysToCumTimeSens));
for i1 = 1:length(TimeSensFeats)
    TempLabel = [TimeSensOperType{i1},TimeSensFeats{i1}];
    TimeSensParLabel(i1,:) = arrayfun(@(x) [TempLabel,'-',num2str(x),'d'], DaysToCumTimeSens, 'UniformOutput',false);
end

if max(DaysToCumTimeSens) > length(TimeSensDtTm)
    error('One of your numbers is greater than the maximum possible')
end

TimeSensDataToPlot = cell(length(DaysToCumTimeSens), length(TimeSensFeats));
for i1 = 1:length(TimeSensFeats)
    for i2 = 1:length(DaysToCumTimeSens)
        CumTimeSensTemp = cell(1, size(TimeSensDtStd{i1}, 2));
        for i3 = 1:size(TimeSensDtStd{i1}, 2)
            if TimeSensCmlb(i1)
                CumTimeSensTemp{i3} = sum([TimeSensDtStd{i1}{end : -1 : (end-DaysToCumTimeSens(i2)+1), i3}], 2);
            else
                CumTimeSensTemp{i3} = mean([TimeSensDtStd{i1}{end : -1 : (end-DaysToCumTimeSens(i2)+1), i3}], 2);
            end
        end
        TimeSensDataToPlot{i2, i1} = CumTimeSensTemp;
    end
end

[TimeSensRanges, TimeSensLegMap] = deal(cell(length(DaysInput), length(TimeSensFeats)));
for i1 = 1:length(TimeSensFeats)
    for i2 = 1:length(DaysToCumTimeSens)
        if EqlRnTS
            TimeSensMinTemp = min(cellfun(@min, [TimeSensDataToPlot{:, i1}]), [], 'all');
            TimeSensMaxTemp = max(cellfun(@max, [TimeSensDataToPlot{:, i1}]), [], 'all');
            IntervalsToUse  = [0, logspace(-1.5, 0, RngsTS-1)]';

            TimeSensRanges{i2, i1} = TimeSensMinTemp + IntervalsToUse*(TimeSensMaxTemp-TimeSensMinTemp);
        else
            TimeSensMinTemp = min(cellfun(@min, TimeSensDataToPlot{i2, i1}));
            TimeSensMaxTemp = max(cellfun(@max, TimeSensDataToPlot{i2, i1}));

            TimeSensRanges{i2, i1} = linspace(TimeSensMinTemp, TimeSensMaxTemp, RngsTS)';
        end

        ValuesTimeSensTemp = round(TimeSensRanges{i2, i1}, 3, 'significant'); % 'decimals'
        TimeSensLegMap{i2, i1} = cellstr([strcat(string(ValuesTimeSensTemp(1:end-1)), LegSep, string(ValuesTimeSensTemp(2:end)))]);
    end
end

%% Creation of goups for time sensitive data based on ranges
ProgressBar.Message = 'Creation of groups for time sensitive data...';

TimeSensIndex = cell(size(TimeSensDataToPlot));
for i1 = 1:numel(TimeSensRanges)
    TimeSensIndTemp = cell(length(TimeSensRanges{i1})-1, size(TimeSensDataToPlot{i1},2));
    for i2 = 1:length(TimeSensRanges{i1})-1
        if i2 < length(TimeSensRanges{i1})-1
            TimeSensIndTemp(i2,:) = cellfun(@(x) find(x>=TimeSensRanges{i1}(i2) & x<TimeSensRanges{i1}(i2+1)), TimeSensDataToPlot{i1}, 'UniformOutput',false);
        else
            TimeSensIndTemp(i2,:) = cellfun(@(x) find(x>=TimeSensRanges{i1}(i2) & x<=TimeSensRanges{i1}(i2+1)), TimeSensDataToPlot{i1}, 'UniformOutput',false);
        end
    end
    TimeSensIndex{i1} = TimeSensIndTemp;
end

%% Colors for plots
ProgressBar.Message = 'Attributing colors...';

ScatterClrs = cell(1, numel(ScatterFeats));
for i1 = 1:numel(ScatterClrs)
    switch ScatterFeats{i1}
        case 'Elevation'
            ScatterClrs{i1} = [ 103, 181, 170;
                                127, 195, 186;
                                152, 210, 199;
                                177, 225, 217;
                                200, 232, 226;
                                225, 240, 238;
                                245, 237, 224;
                                240, 227, 200;
                                235, 217, 176;
                                223, 198, 157;
                                213, 179, 136;
                                201, 159, 116 ];

        case 'Slope'
            ScatterClrs{i1} = cool(length(ScatterRange{i1})-1)*255;

        case 'Aspect Angle'
            ScatterClrs{i1} = [ 201, 160, 220;
                                143, 000, 255;
                                000, 100, 255;
                                127, 255, 212 ];

        case 'Mean Curvature'
            ScatterClrs{i1} = spring(length(ScatterRange{i1})-1)*255;

        otherwise
            error('Scatter feat name not recognized in defining colors for ranges!')
    end
end

TimeSensClrs = cell(1, numel(TimeSensFeats));
for i1 = 1:numel(TimeSensClrs)
    switch TimeSensFeats{i1}
        case 'Rainfall'
            if RainManualColors
                TimeSensClrs{i1} = [ 228, 229, 224;
                                     226, 252, 255;
                                     169, 200, 244;
                                     171, 189, 227;
                                     048, 127, 226;
                                     000, 000, 255;
                                     018, 010, 143;
                                     019, 041, 075 ];
            else
                TimeSensClrs{i1} = sky(RngsTS)*255; % 1 additional color to avoid the too withe color on the first column!
                TimeSensClrs{i1}(1,:) = [];
            end

        otherwise
            error('Time Sensitive feat name not recognized in defining colors for ranges!')
    end
end

%% Figure preliminary settings
ProgressBar.Message = 'Preliminary settings for figures...';

[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'FinScale',SclPxl);

dExtremes = [MaxExtremes(1)-MinExtremes(1) , MaxExtremes(2)-MinExtremes(2) ];
xLimits   = [MinExtremes(1)-dExtremes(1)/15, MaxExtremes(1)+dExtremes(1)/15];
yLimits   = [MinExtremes(2)-dExtremes(2)/15, MaxExtremes(2)+dExtremes(2)/15];

yLatMean     = mean([MinExtremes(2), MaxExtremes(2)]);
dLat1Meter   = rad2deg(1/earthRadius); % 1 m in lat
dLong1Meter  = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long
RatioLatLong = dLat1Meter/dLong1Meter;

%% Figure creation
ProgressBar.Message = 'Figure creation...';

TimeInd = length(PlotList)-numel(TimeSensFeats); % Time Independant
Titles  = string(strcat(('a':'z')', ')'));

for i1 = 1:numel(PlotOpts)
    if strcmp(PlotChoice, 'Unique Figure')
        FilenameFig = 'Input features plot';
        RowGridNumb = ceil(numel(ScatterFeats)/2) + ...
                      ceil(numel(PolygonFeats)/2) + ...
                      ceil(numel(TimeSensFeats)/2);
        ColGridNumb = 2;
        FigHeight   = 180*RowGridNumb;
        FigWidth    = 300*ColGridNumb;
        WindowSize  = get(0, 'ScreenSize');
        GrdSubPlts  = [RowGridNumb, ColGridNumb];
        CurrFig     = figure('Position',max([(WindowSize(3)-FigWidth)/2, ...
                                             (WindowSize(4)-FigHeight)/2, ...
                                             FigWidth, FigHeight], 1));

        RelSubHgth  = (1/RowGridNumb)*0.7;
        RelSubWdth  = (1/ColGridNumb)*0.7;

        RelSubSpcY  = (1/RowGridNumb - RelSubHgth)/2;
        RelSubSpcX  = (1/ColGridNumb - RelSubWdth)/2;

        StrtPolyRow = ceil(numel(ScatterFeats)/ColGridNumb);
        StrtTmSnRow = ceil(numel(ScatterFeats)/ColGridNumb) + ceil(numel(PolygonFeats)/ColGridNumb);

    elseif strcmp(PlotChoice, 'Separate Figures')
        FilenameFig = [PlotList{PlotOpts{i1}}, ' feature plot'];
        RowGridNumb = 1;
        ColGridNumb = 1;
        GrdSubPlts  = [1, 1];
        CurrFig     = figure(i1);

        RelSubHgth  = .815;
        RelSubWdth  = .775;

        RelSubSpcY  = (1 - RelSubHgth)/2;
        RelSubSpcX  = (1 - RelSubWdth)/2;

        StrtPolyRow = 0;
        StrtTmSnRow = 0;
    end

    set(CurrFig, 'Name',FilenameFig, 'visible','off');
    
    %% Plot based on content
    [ScAxs, ScLeg ] = deal(cell(1, numel(ScatterFeats )));
    [PlAxs, PlLeg ] = deal(cell(1, numel(PolygonFeats )));
    [TSAxs, TSLeg ] = deal(cell(1, numel(TimeSensFeats)));
    [iSc, iPl, iTS] = deal(1);
    for i2 = 1:numel(PlotOpts{i1})
        switch PlotList{PlotOpts{i1}(i2)}
            case ScatterFeats
                CurrCol = rem(iSc, ColGridNumb) - 1; % First left column is 0, then 1, 2, ...
                if CurrCol == -1; CurrCol = ColGridNumb-1; end
                CurrRow = ceil(iSc/ColGridNumb); % First top row is 1, then 2, 3, ...
                CurrPos = [(1/ColGridNumb)*CurrCol     + RelSubSpcX, ...
                           1 - (1/RowGridNumb)*CurrRow + RelSubSpcY];

                ScAxs{iSc} = subplot('Position',[CurrPos, RelSubWdth, RelSubHgth], 'Parent',CurrFig);
                % ScAxs{iSc} = subplot(GrdSubPlts(1),GrdSubPlts(2),PlotNum(1), 'Parent',CurrFig);
                hold(ScAxs{iSc},'on');
                % set(ScAxs{iSc}, 'visible','on')
                
                iCurr = find(strcmp(PlotList{PlotOpts{i1}(i2)}, ScatterFeats)); % To reflect the correct order! Scatter matrices could be in different order compared to PlotList
                ScPlt = cell(length(ScatterRange{iCurr})-1, size(xLongStudy,2));
                for i3 = 1:length(ScatterRange{iCurr})-1
                    ScPlt(i3,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                                'MarkerFaceColor',ScatterClrs{iCurr}(i3,:)./255, ...
                                                                'MarkerEdgeColor','none', 'Parent',ScAxs{iSc}), ...
                                	                    xLongStudy, yLatStudy, ScatterIndex{iCurr}(i3,:), 'UniformOutput',false);
                end
                
                plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ScAxs{iSc})
                
                xlim(xLimits)
                ylim(yLimits)
                % xtickformat('degrees')
                % ytickformat('degrees')
                xticks([])
                yticks([])
                if ShowBox; box on; else; axis off; end
                
                daspect(ScAxs{iSc}, [1, RatioLatLong, 1])
                
                LegendObjects  = ScPlt(1:end,1);
                ScttLegMapSplt = split_text_newline(ScatterLegMap{iCurr}, MaxLnTx);
                
                [ScLeg{iSc}, ScLegIco, ScLegPlt] = legend([LegendObjects{:}], ...
                                                           ScttLegMapSplt, ...
                                                           'NumColumns',1, ...
                                                           'FontName',SelFont, ...
                                                           'FontSize',SelFntSz, ...
                                                           'Location',LgndPos, ...
                                                           'Box','off');
                
                title(ScLeg{iSc}, [ScatterFeats{iCurr}, ScatterUnits{iCurr}], 'FontName',SelFont, 'FontSize',SelFntSz)
                fix_leg_scatter(ScLeg{iSc}, ScLegIco, ScLegPlt, DimItemScatLeg, LgndPos)
                
                % fig_rescaler(ScAxs{iSc}, ScLeg{iSc}, LgndPos)
                
                if ShowTtl; title(Titles(i2), 'FontName',SelFont, 'FontSize',1.5*SelFntSz); end

                iSc = iSc + 1;

            case PolygonFeats
                CurrCol = rem(iPl, ColGridNumb) - 1; % First left column is 0, then 1, 2, ...
                if CurrCol == -1; CurrCol = ColGridNumb-1; end
                CurrRow = StrtPolyRow + ceil(iPl/ColGridNumb); % First top row is Rows of Scatter + 1
                CurrPos = [(1/ColGridNumb)*CurrCol     + RelSubSpcX, ...
                           1 - (1/RowGridNumb)*CurrRow + RelSubSpcY];

                PlAxs{iPl} = subplot('Position',[CurrPos, RelSubWdth, RelSubHgth], 'Parent',CurrFig);
                hold(PlAxs{iPl},'on');
                % set(PlAxs{iPl}, 'visible','on')
                
                iCurr = find(strcmp(PlotList{PlotOpts{i1}(i2)}, PolygonFeats)); % To reflect the correct order! Scatter matrices could be in different order compared to PlotList

                plot(PolygonDtStd{iCurr}, 'LineWidth',LineIntSize, 'EdgeColor',EdgeColInt, 'Parent',PlAxs{iPl})
                plot(StudyAreaPolygon,    'LineWidth',LineExtSize, 'FaceColor','none',     'Parent',PlAxs{iPl})
                
                xlim(xLimits)
                ylim(yLimits)
                % xtickformat('degrees')
                % ytickformat('degrees')
                xticks([])
                yticks([])
                if ShowBox; box on; else; axis off; end
                
                daspect(PlAxs{iPl}, [1, RatioLatLong, 1])
                
                PolyLegSplit = split_text_newline(PolygonLgnd{iCurr}, MaxLnTx);
                
                PlLeg{iPl} = legend(PolyLegSplit, ...
                                 'NumColumns',1, ...
                                 'FontName',SelFont, ...
                                 'FontSize',SelFntSz, ...
                                 'Location',LgndPos, ...
                                 'Box','off');
                
                title(PlLeg{iPl}, PolygonFeats{iCurr}, 'FontName',SelFont, 'FontSize',SelFntSz)
                PlLeg{iPl}.ItemTokenSize = DimItemPolyLeg;
                
                % fig_rescaler(PlAxs{iPl}, PlLeg{iPl}, LgndPos)
                
                if ShowTtl; title(Titles(i2), 'FontName',SelFont, 'FontSize',1.5*SelFntSz); end

                iPl = iPl + 1;

            case TimeSensFeats
                iCurr  = find(strcmp(PlotList{PlotOpts{i1}(i2)}, TimeSensFeats)); % To reflect the correct order! Scatter matrices could be in different order compared to PlotList
                IndCum = checkbox2(string(DaysToCumTimeSens), 'Title',{'What do you want for TS:'}, 'OutType','NumInd');
                for i3 = IndCum
                    CurrCol = rem(iTS, ColGridNumb) - 1; % First left column is 0, then 1, 2, ...
                    if CurrCol == -1; CurrCol = ColGridNumb-1; end
                    CurrRow = StrtTmSnRow + ceil(iTS/ColGridNumb); % First top row is Rows of Scatter + 1
                    CurrPos = [(1/ColGridNumb)*CurrCol     + RelSubSpcX, ...
                               1 - (1/RowGridNumb)*CurrRow + RelSubSpcY];

                    TSAxs{iTS} = subplot('Position',[CurrPos, RelSubWdth, RelSubHgth], 'Parent',CurrFig);
                    hold(TSAxs{iTS},'on');
                    % set(TSAxs{iTS}, 'visible','on')

                    TSPlt = cell(length(TimeSensRanges{i3,iCurr})-1, size(xLongStudy,2));
                    for i4 = 1:length(TimeSensRanges{i3,iCurr})-1
                        TSPlt(i4,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                                        'MarkerFaceColor',TimeSensClrs{iCurr}(i4,:)./255, ...
                                                                        'MarkerEdgeColor','none', 'Parent',TSAxs{iTS}), ...
                                                        xLongStudy, yLatStudy, TimeSensIndex{i3,iCurr}(i4,:), 'UniformOutput',false);
                    end

                    plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',TSAxs{iTS})

                    xlim(xLimits)
                    ylim(yLimits)
                    % xtickformat('degrees')
                    % ytickformat('degrees')
                    xticks([])
                    yticks([])
                    if ShowBox; box on; else; axis off; end
                    
                    daspect(TSAxs{iTS}, [1, RatioLatLong, 1])
                    
                    LegendObjects  = TSPlt(1:end,1);
                    TmSnLegMapSplt = split_text_newline(TimeSensLegMap{i3,iCurr}, MaxLnTx);
                
                    [TSLeg{iTS}, TSLegIco, TSLegPlt] = legend([LegendObjects{:}], ...
                                                              TmSnLegMapSplt, ...
                                                              'NumColumns',1, ...
                                                              'FontName',SelFont, ...
                                                              'FontSize',SelFntSz, ...
                                                              'Location',LgndPos, ...
                                                              'Box','off');
        
                    title(TSLeg{iTS}, [TimeSensOperType{iCurr},' ',TimeSensFeats{iCurr},TimeSensUnits{iCurr}], ...
                                            'FontName',SelFont, 'FontSize',SelFntSz)
                    fix_leg_scatter(TSLeg{iTS}, TSLegIco, TSLegPlt, DimItemScatLeg, LgndPos)
                    text(TSAxs{iTS}, 0.1, 0.9, [num2str(DaysToCumTimeSens(i3)),'d'], 'FontName',SelFont, ...
                                                                                     'FontSize',SelFntSz, ...
                                                                                     'Units','normalized')

                    % fig_rescaler(TSAxs{iTS}, TSLeg{iTS}, LgndPos)

                    if ShowTtl; title(Titles(i2+iTS-iCurr), 'FontName',SelFont, 'FontSize',1.5*SelFntSz); end

                    iTS = iTS + 1;
                end

            otherwise
                error('Plot content not recognized in plotting cycle!')
        end
    end
    
    %% Layout config
    if strcmp(PlotChoice, 'Unique Figure')
        Axs2Cnf = [ScAxs, PlAxs, TSAxs];
        Leg2Cnf = [ScLeg, PlLeg, TSLeg];
        
        [PosOfPlots, PosOfLegends] = deal(cell(1, length(Axs2Cnf)));
        for i2 = 1:length(Axs2Cnf)
            PosOfPlots{i2}   = get(Axs2Cnf{i2}, 'Position');
            PosOfLegends{i2} = get(Leg2Cnf{i2}, 'Position');
        end
        
        DimsPlotsOld = cell2mat(PosOfPlots');
        MaxDims      = [max(DimsPlotsOld(:,3)), max(DimsPlotsOld(:,4))];
        xPlotsPos    = [min(DimsPlotsOld(:,1)), max(DimsPlotsOld(:,1))];
        DimsPlotsNew = [DimsPlotsOld(:,1:2), repmat(MaxDims, size(DimsPlotsOld, 1), 1)];
        
        for i2 = 1:length(Axs2Cnf)
            set(Axs2Cnf{i2}, 'Position',DimsPlotsNew(i2,:))
        end
    end
    
    %% Export
    exportgraphics(CurrFig, [fold_fig,sl,FilenameFig,'.png'], 'Resolution',400);

    if ShowPlt
        set(CurrFig, 'visible','on');
    else
        close(CurrFig)
    end
end