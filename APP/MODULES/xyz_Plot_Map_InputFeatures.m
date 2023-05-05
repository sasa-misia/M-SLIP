% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
cd(fold_var)
load('StudyAreaVariables.mat',       'StudyAreaPolygon','MaxExtremes','MinExtremes')
load('GridCoordinates.mat',          'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load('MorphologyParameters.mat',     'ElevationAll','SlopeAll','AspectAngleAll','MeanCurvatureAll')
load('LithoPolygonsStudyArea.mat',   'LithoPolygonsStudyArea')
load('VegPolygonsStudyArea.mat',     'VegPolygonsStudyArea')
load('LandUsesVariables.mat',        'LandUsePolygonsStudyArea')
load('TopSoilPolygonsStudyArea.mat', 'TopSoilPolygonsStudyArea')
load('RainInterpolated.mat',         'RainInterpolated','RainDateInterpolationStarts')

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
cd(fold_res_ml_curr)
load('TrainedANNs.mat',              'DatasetTableStudy','RangesForNorm')
cd(fold0)

%% Date check and uniformization for time sensitive part (rain rules the others) MANUAL!
ProgressBar.Message = 'Defining time sensitive part...';

TimeSensitiveParam  = {'Rainfall'}; % First must be always Rainfall!
CumulableParam      = [true      ];
TimeSensitiveDate   = {RainDateInterpolationStarts};
TimeSensitiveData   = {RainInterpolated};
clear('RainInterpolated')

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

%% Data extraction
ProgressBar.Message = 'Extraction of data in study area...';

xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudy = cellfun(@(x,y) x(y), yLatAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('yLatAll')

ElevationStudy = cellfun(@(x,y) x(y), ElevationAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('ElevationAll')

SlopeStudy = cellfun(@(x,y) x(y), SlopeAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('SlopeAll')

AspectStudy = cellfun(@(x,y) x(y), AspectAngleAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('AspectAngleAll')

MeanCurvatureStudy = cellfun(@(x,y) x(y), MeanCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('MeanCurvatureAll')

TimeSensitiveDataInterpStudy = cell(1, length(TimeSensitiveParam));
for i1 = 1:length(TimeSensitiveParam)
    TimeSensitiveDataInterpStudy{i1} = cellfun(@full, TimeSensitiveData{i1}, 'UniformOutput',false);
end
clear('TimeSensitiveData')

%% Ranges & legends for morphology
ProgressBar.Message = 'Defining ranges...';

LegSep = " ‒ ";

EleMin   = min(cellfun(@min, ElevationStudy));
EleMax   = max(cellfun(@max, ElevationStudy));
EleRange = linspace(EleMin, EleMax, 11)';

if EleMax <= 1000
    ValuesEle = round(EleRange, 2, 'significant');
else
    ValuesEle = round(EleRange, 3, 'significant');
end

LegEleMap = cellstr([strcat(string(ValuesEle(1:end-1)), LegSep, string(ValuesEle(2:end)))]);

SlopeRange  = (0:10:60)';
LegSlopeMap = cellstr([strcat(string(SlopeRange(1:end-1)), LegSep, string(SlopeRange(2:end))); strcat("> ",string(SlopeRange(end)))]);

AspectRange  = (0:90:360)';
LegAspectMap = cellstr([strcat(string(AspectRange(1:end-1)), LegSep, string(AspectRange(2:end)))]);

MeanCurvMin   = max(min(cellfun(@min, MeanCurvatureStudy)), RangesForNorm{'Curvature','Min value'});
MeanCurvMax   = min(max(cellfun(@max, MeanCurvatureStudy)), RangesForNorm{'Curvature','Max value'});
% MeanCurvMin   = min(cellfun(@min, MeanCurvatureStudy));
% MeanCurvMax   = max(cellfun(@max, MeanCurvatureStudy));
MeanCurvRange = linspace(MeanCurvMin, MeanCurvMax, 10)';

ValuesMeanCurv = round(MeanCurvRange, 2, 'significant');

LegMeanCurvMap = cellstr([strcat(string(ValuesMeanCurv(1:end-1)), LegSep, string(ValuesMeanCurv(2:end)))]);

%% Creation of goups for morphology based on ranges
ProgressBar.Message = 'Defining points inside ranges...';

ElevationIndex = cell(length(EleRange)-1, size(ElevationStudy,2));
for i1 = 1:length(EleRange)-1
    if i1 < length(EleRange)-1
        ElevationIndex(i1,:) = cellfun(@(x) find(x>=EleRange(i1) & x<EleRange(i1+1)), ElevationStudy, 'UniformOutput',false);
    else
        ElevationIndex(i1,:) = cellfun(@(x) find(x>=EleRange(i1) & x<=EleRange(i1+1)), ElevationStudy, 'UniformOutput',false);
    end
end

SlopeIndex = cell(length(SlopeRange), size(SlopeStudy,2)); % Not -1 because there is even the class >=60
for i1 = 1:length(SlopeRange)
    if i1 < length(SlopeRange)
        SlopeIndex(i1,:) = cellfun(@(x) find(x>=SlopeRange(i1) & x<SlopeRange(i1+1)), SlopeStudy, 'UniformOutput',false);
    else
        SlopeIndex(i1,:) = cellfun(@(x) find(x>=SlopeRange(i1)), SlopeStudy, 'UniformOutput',false);
    end
end

AspectIndex = cell(length(AspectRange)-1, size(AspectStudy,2));
for i1 = 1:length(AspectRange)-1
    if i1 < length(AspectRange)-1
        AspectIndex(i1,:) = cellfun(@(x) find(x>=AspectRange(i1) & x<AspectRange(i1+1)), AspectStudy, 'UniformOutput',false);
    else
        AspectIndex(i1,:) = cellfun(@(x) find(x>=AspectRange(i1) & x<=AspectRange(i1+1)), AspectStudy, 'UniformOutput',false);
    end
end

MeanCurvIndex = cell(length(MeanCurvRange)-1, size(MeanCurvatureStudy,2));
for i1 = 1:length(MeanCurvRange)-1
    if i1 < length(MeanCurvRange)-1
        MeanCurvIndex(i1,:) = cellfun(@(x) find(x>=MeanCurvRange(i1) & x<MeanCurvRange(i1+1)), MeanCurvatureStudy, 'UniformOutput',false);
    else
        MeanCurvIndex(i1,:) = cellfun(@(x) find(x>=MeanCurvRange(i1) & x<=MeanCurvRange(i1+1)), MeanCurvatureStudy, 'UniformOutput',false);
    end
end

%% Selection of relevant classes for categorical part
ProgressBar.Message = 'Extraction of relevant categorical classes...';

PercLitho   = tabulate(DatasetTableStudy.Lithology);
PercTopSoil = tabulate(DatasetTableStudy.TopSoil);
PercLanduse = tabulate(DatasetTableStudy.LandUse);
PercVeg     = tabulate(DatasetTableStudy.Vegetation);

% Removing no class row (0)
PercLitho(PercLitho(:,1)==0,:)     = [];
PercTopSoil(PercTopSoil(:,1)==0,:) = [];
PercLanduse(PercLanduse(:,1)==0,:) = [];
PercVeg(PercVeg(:,1)==0,:)         = [];

% Searching indices of classes that have a percentage >= MinPerc
MinPerc = 2; % This value is expressed in percentage
GoodPercLitho   = find(PercLitho(:,3)   >= MinPerc);
GoodPercTopSoil = find(PercTopSoil(:,3) >= MinPerc);
GoodPercLandUse = find(PercLanduse(:,3) >= MinPerc);
GoodPercVeg     = find(PercVeg(:,3)     >= MinPerc);

%% Legends for categorical part (REMEMBER to look at indices GoodPerc that could not match polyshapes!!!)
ProgressBar.Message = 'Deining classes for legends...';

% Lithology
LithoSheet = readcell('ClassesML.xlsx', 'Sheet','Litho');
if size(LithoSheet, 2) >= 3
    LegInfoLitho   = LithoSheet(:,3);
    MissingContent = cellfun(@(x) all(ismissing(x)), LegInfoLitho);
    LegInfoLitho(MissingContent) = LithoSheet(MissingContent,1);
else
    LegInfoLitho = LithoSheet(:,1);
end

LegLithoMap = cell(1, length(GoodPercLitho));
for i1 = 1:length(GoodPercLitho)
    IndLithoTemp    = find(PercVeg(GoodPercLitho(i1),1) == [LithoSheet{:,2}]);
    LegLithoMap(i1) = LegInfoLitho(IndLithoTemp);
end

IndLegChosed = listdlg('PromptString',{'Select legend titles that you want to mantain:',''}, ...
                       'ListString',LegLithoMap, 'SelectionMode','multiple');
LegLithoMap   = LegLithoMap(IndLegChosed);
GoodPercLitho = GoodPercLitho(IndLegChosed);

% Top soil
TopSoilSheet = readcell('ClassesML.xlsx', 'Sheet','Top soil');
if size(TopSoilSheet, 2) >= 3
    LegInfoTopSoil = TopSoilSheet(:,3);
    MissingContent = cellfun(@(x) all(ismissing(x)), LegInfoTopSoil);
    LegInfoTopSoil(MissingContent) = TopSoilSheet(MissingContent,1);
else
    LegInfoTopSoil = TopSoilSheet(:,1);
end

LegTopSoilMap = cell(1, length(GoodPercTopSoil));
for i1 = 1:length(GoodPercTopSoil)
    IndTopSoilTemp    = find(PercVeg(GoodPercTopSoil(i1),1) == [TopSoilSheet{:,2}]);
    LegTopSoilMap(i1) = LegInfoTopSoil(IndTopSoilTemp);
end

IndLegChosed = listdlg('PromptString',{'Select legend titles that you want to mantain:',''}, ...
                       'ListString',LegTopSoilMap, 'SelectionMode','multiple');
LegTopSoilMap   = LegTopSoilMap(IndLegChosed);
GoodPercTopSoil = GoodPercTopSoil(IndLegChosed);

% Land use
LandUseSheet = readcell('ClassesML.xlsx', 'Sheet','Land use');
if size(LandUseSheet, 2) >= 3
    LegInfoLandUse = LandUseSheet(:,3);
    MissingContent = cellfun(@(x) all(ismissing(x)), LegInfoLandUse);
    LegInfoLandUse(MissingContent) = LandUseSheet(MissingContent,1);
else
    LegInfoLandUse = LandUseSheet(:,1);
end

LegLandUseMap = cell(1, length(GoodPercLandUse));
for i1 = 1:length(GoodPercLandUse)
    IndLandUseTemp    = find(PercVeg(GoodPercLandUse(i1),1) == [LandUseSheet{:,2}]);
    LegLandUseMap(i1) = LegInfoLandUse(IndLandUseTemp);
end

IndLegChosed = listdlg('PromptString',{'Select legend titles that you want to mantain:',''}, ...
                       'ListString',LegLandUseMap, 'SelectionMode','multiple');
LegLandUseMap   = LegLandUseMap(IndLegChosed);
GoodPercLandUse = GoodPercLandUse(IndLegChosed);

% Vegetation
VegSheet = readcell('ClassesML.xlsx', 'Sheet','Veg');
if size(VegSheet, 2) >= 3
    LegInfoVeg     = VegSheet(:,3);
    MissingContent = cellfun(@(x) all(ismissing(x)), LegInfoVeg);
    LegInfoVeg(MissingContent) = VegSheet(MissingContent,1);
else
    LegInfoVeg = VegSheet(:,1);
end

LegVegMap = cell(1, length(GoodPercVeg));
for i1 = 1:length(GoodPercVeg)
    IndVegTemp    = find(PercVeg(GoodPercVeg(i1),1) == [VegSheet{:,2}]);
    LegVegMap(i1) = LegInfoVeg(IndVegTemp);
end

IndLegChosed = listdlg('PromptString',{'Select legend titles that you want to mantain:',''}, ...
                       'ListString',LegVegMap, 'SelectionMode','multiple');
LegVegMap   = LegVegMap(IndLegChosed);
GoodPercVeg = GoodPercVeg(IndLegChosed);

%% Creation of Time sensitive data
ProgressBar.Message = 'Creation of time sensitive data...';

DaysInput = inputdlg({["Days to take into account: "
                      strcat("Maximum n. of days is: ", string(length(TimeSensitiveDate)))]}, ...
                      '', 1, {'[10, 30, 60]'});
DaysToCumTimeSens = str2num(DaysInput{1});

TimeSensOperType = repmat({'Averaged'}, 1, length(TimeSensitiveParam));
TimeSensOperType(CumulableParam) = {'Cumulated'};

TimeSensParLabel = cell(length(TimeSensitiveParam), length(DaysToCumTimeSens));
for i1 = 1:length(TimeSensitiveParam)
    TempLabel = [TimeSensOperType{i1},TimeSensitiveParam{i1}];
    TimeSensParLabel(i1,:) = arrayfun(@(x) [TempLabel,'-',num2str(x),'d'], DaysToCumTimeSens, 'UniformOutput',false);
end

if max(DaysToCumTimeSens) > length(TimeSensitiveDate)
    error('One of your numbers is greater than the maximum possible')
end

TimeSensDataToPlot = cell(length(DaysToCumTimeSens), length(TimeSensitiveParam));
for i1 = 1:length(TimeSensitiveParam)
    for i2 = 1:length(DaysToCumTimeSens)
        CumTimeSensTemp = cell(1, size(TimeSensitiveDataInterpStudy{i1}, 2));
        for i3 = 1:size(TimeSensitiveDataInterpStudy{i1}, 2)
            if CumulableParam(i1)
                CumTimeSensTemp{i3} = sum([TimeSensitiveDataInterpStudy{i1}{end : -1 : (end-DaysToCumTimeSens(i2)+1), i3}], 2);
            else
                CumTimeSensTemp{i3} = mean([TimeSensitiveDataInterpStudy{i1}{end : -1 : (end-DaysToCumTimeSens(i2)+1), i3}], 2);
            end
        end
        TimeSensDataToPlot{i2, i1} = CumTimeSensTemp;
    end
end

[TimeSensRanges, LegTimeSensMap] = deal(cell(length(DaysInput), length(TimeSensitiveParam)));
for i1 = 1:length(TimeSensitiveParam)
    for i2 = 1:length(DaysToCumTimeSens)
        TimeSensMinTemp = min(cellfun(@min, TimeSensDataToPlot{i2, i1}));
        TimeSensMaxTemp = max(cellfun(@max, TimeSensDataToPlot{i2, i1}));
        TimeSensRanges{i2, i1} = linspace(TimeSensMinTemp, TimeSensMaxTemp, 8)';
        ValuesTimeSensTemp = round(TimeSensRanges{i2, i1}, 3, 'significant');
        LegTimeSensMap{i2, i1} = cellstr([strcat(string(ValuesTimeSensTemp(1:end-1)), LegSep, string(ValuesTimeSensTemp(2:end)))]);
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

ColorElevation = [ 103, 181, 170
                   127, 195, 186
                   152, 210, 199
                   177, 225, 217
                   200, 232, 226
                   225, 240, 238
                   245, 237, 224
                   240, 227, 200
                   235, 217, 176
                   223, 198, 157
                   213, 179, 136
                   201, 159, 116 ];

ColorSlope = cool(length(SlopeRange))*255; % Not -1 because there is even the class >=60

ColorAspect = [ 201, 160, 220
                143, 000, 255
                000, 100, 255
                127, 255, 212 ];

ColorMeanCurv = spring(length(MeanCurvRange)-1)*255;

ColorVegMap = {'#FF6600', '#800000', '#33CC33', '#7FFFD4', ...
               '#ffff00', ' #FF9900', '#c9a0dc', '#FF66FF'};

ColorRain = [ 228, 229, 224
              171, 189, 227
              169, 200, 244
              048, 127, 226
              000, 000, 255
              018, 010, 143
              019, 041, 075 ];

%% Figure preliminary settings
ProgressBar.Message = 'Preliminary settings for figures...';

RefStudyArea = 0.0417;
ExtentStudyArea = area(StudyAreaPolygon);
RatioRef = ExtentStudyArea/RefStudyArea;
PixelSize = .05/RatioRef;
DetPixelSize = 7.5*PixelSize;

ShowBox   = false;
ShowTitle = false;

EdgeColInt  = 'none';
LineExtSize = 0.8;
LineIntSize = .5;

IndividualTitlesTS = false;

DimItemPolyLeg = [3, 3];
DimItemScatLeg = 1.38*DimItemPolyLeg(1);

SelectedFont     = 'Times new roman';
LegendPosition   = 'eastoutside';
LegendPositionTS = 'southoutside';
SelectedFontSize = 4;
MaxLengthText    = 25;

dExtremes = [MaxExtremes(1)-MinExtremes(1), MaxExtremes(2)-MinExtremes(2)];
xLimits   = [MinExtremes(1)-dExtremes(1)/15, MaxExtremes(1)+dExtremes(1)/15];
yLimits   = [MinExtremes(2)-dExtremes(2)/15, MaxExtremes(2)+dExtremes(2)/15];

yLatMean     = mean([MinExtremes(2), MaxExtremes(2)]);
dLat1Meter   = rad2deg(1/earthRadius); % 1 m in lat
dLong1Meter  = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long
RatioLatLong = dLat1Meter/dLong1Meter;

%% Figure creation
ProgressBar.Message = 'Figure creation...';

Options = {'Unique Figure', 'Separate Figures'};
PlotChoice = uiconfirm(Fig, 'How do you want to plot figures?', ...
                            'Plot choice', 'Options',Options, 'DefaultOption',1);

PlotList = [{'Elevation', 'Slope', 'Aspect', 'MeanCurvature', 'Lithology', ...
             'TopSoil', 'LandUse', 'Vegetation'}, TimeSensitiveParam]; % THEY MUST HAVE THE SAME NAME OF BELOW!
TimeIndependent = length(PlotList)-length(TimeSensitiveParam);

Titles = string(strcat(('a':'z')', ')'));

if strcmp(PlotChoice, 'Separate Figures')
    PlotOpts = num2cell(listdlg('PromptString',{'Choose what do you want to plot:',''}, ...
                                'ListString',PlotList, 'SelectionMode','multiple'));
else
    PlotOpts = {1:length(PlotList)};
end

for i1 = 1:length(PlotOpts)
    if strcmp(PlotChoice, 'Unique Figure')
        filename_fig = 'Input features plot';
        GirdSubPlots = [5, 2];
        curr_fig = figure('Position',[80, 50, 600, 900]);
        PlotNum  = 1:TimeIndependent; % You can even rearrange the order!
    elseif strcmp(PlotChoice, 'Separate Figures')
        filename_fig = [PlotList{PlotOpts{i1}}, ' feature plot'];
        GirdSubPlots = [1, 1];
        curr_fig = figure(i1);
        PlotNum  = ones(1, TimeIndependent);
    end

    set(curr_fig, 'Name',filename_fig);
    
    %% Plot Elevation
    if any(strcmp(string({PlotList{PlotOpts{i1}}}), 'Elevation')) % IT MUST HAVE THE SAME NAME OF ABOVE!
        ax_ele = subplot(GirdSubPlots(1),GirdSubPlots(2),PlotNum(1), 'Parent',curr_fig);
        hold(ax_ele,'on');
        set(ax_ele, 'visible','on')
        
        helevation = cell(length(EleRange)-1, size(xLongStudy,2));
        for i2 = 1:length(EleRange)-1
            helevation(i2,:) = cellfun(@(x,y,z) scatter(x(z),y(z), PixelSize, 'Marker','o', ...
                                                        'MarkerFaceColor',ColorElevation(i2,:)./255, ...
                                                        'MarkerEdgeColor','none', 'Parent',ax_ele), ...
                                	        xLongStudy, yLatStudy, ElevationIndex(i2,:), 'UniformOutput',false);
        end
        
        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_ele)
        
        xlim(xLimits)
        ylim(yLimits)
        % xtickformat('degrees')
        % ytickformat('degrees')
        xticks([])
        yticks([])
        if ShowBox; box on; else; axis off; end
        
        daspect(ax_ele, [1, RatioLatLong, 1])
        
        SplitLegEleMap = split_text_newline(LegEleMap, MaxLengthText);
        LegendObjects  = helevation(1:end,1);
        
        [leg_ele, leg_ico, leg_plots] = legend([LegendObjects{:}], ...
                                               SplitLegEleMap, ...
                                               'NumColumns',1, ...
                                               'FontName',SelectedFont, ...
                                               'FontSize',SelectedFontSize, ...
                                               'Location',LegendPosition, ...
                                               'Box','off');
        
        title(leg_ele, 'Elevation [m]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
        fix_leg_scatter(leg_ele, leg_ico, leg_plots, DimItemScatLeg, LegendPosition)
        
        % fig_rescaler(ax_ele, leg_ele, LegendPosition)
        
        if ShowTitle; title(Titles(PlotNum(1)), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
    end
    
    %% Plot Slope
    if any(strcmp(string({PlotList{PlotOpts{i1}}}), 'Slope')) % IT MUST HAVE THE SAME NAME OF ABOVE!
        ax_slo = subplot(GirdSubPlots(1),GirdSubPlots(2),PlotNum(2), 'Parent',curr_fig);
        hold(ax_slo,'on');
        set(ax_slo, 'visible','on')
        
        hslope = cell(length(SlopeRange), size(xLongStudy,2));
        for i2 = 1:length(SlopeRange)
            hslope(i2,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                            'MarkerFaceColor',ColorSlope(i2,:)./255, ...
                                                            'MarkerEdgeColor','none', 'Parent',ax_slo), ...
                                        xLongStudy, yLatStudy, SlopeIndex(i2,:), 'UniformOutput',false);
        end
        
        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_slo)
        
        xlim(xLimits)
        ylim(yLimits)
        % xtickformat('degrees')
        % ytickformat('degrees')
        xticks([])
        yticks([])
        if ShowBox; box on; else; axis off; end
        
        daspect(ax_slo, [1, RatioLatLong, 1])
        
        SplitLegSlopeMap = split_text_newline(LegSlopeMap, MaxLengthText);
        LegendObjects  = hslope(1:end,1);
        
        [leg_slo, leg_ico, leg_plots] = legend([LegendObjects{:}], ...
                                               SplitLegSlopeMap, ...
                                               'NumColumns',1, ...
                                               'FontName',SelectedFont, ...
                                               'FontSize',SelectedFontSize, ...
                                               'Location',LegendPosition, ...
                                               'Box','off');
        
        title(leg_slo, 'Slope [°]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
        fix_leg_scatter(leg_slo, leg_ico, leg_plots, DimItemScatLeg, LegendPosition)
        
        % fig_rescaler(ax_slo, leg_slo, LegendPosition)
        
        if ShowTitle; title(Titles(PlotNum(2)), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
    end
    
    %% Plot Aspect
    if any(strcmp(string({PlotList{PlotOpts{i1}}}), 'Aspect')) % IT MUST HAVE THE SAME NAME OF ABOVE!
        ax_asp = subplot(GirdSubPlots(1),GirdSubPlots(2),PlotNum(3), 'Parent',curr_fig);
        hold(ax_asp,'on');
        set(ax_asp, 'visible','on')
        
        haspect = cell(length(AspectRange)-1, size(xLongStudy,2));
        for i2 = 1:length(AspectRange)-1
            haspect(i2,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                        'MarkerFaceColor',ColorAspect(i2,:)./255, ...
                                                        'MarkerEdgeColor','none', 'Parent',ax_asp), ...
                                        xLongStudy, yLatStudy, AspectIndex(i2,:), 'UniformOutput',false);
        end
        
        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_asp)
        
        xlim(xLimits)
        ylim(yLimits)
        % xtickformat('degrees')
        % ytickformat('degrees')
        xticks([])
        yticks([])
        if ShowBox; box on; else; axis off; end
        
        daspect(ax_asp, [1, RatioLatLong, 1])
        
        SplitLegAspectMap = split_text_newline(LegAspectMap, MaxLengthText);
        LegendObjects  = haspect(1:end,1);
        
        [leg_asp, leg_ico, leg_plots] = legend([LegendObjects{:}], ...
                                               SplitLegAspectMap, ...
                                               'NumColumns',1, ...
                                               'FontName',SelectedFont, ...
                                               'FontSize',SelectedFontSize, ...
                                               'Location',LegendPosition, ...
                                               'Box','off');
        
        title(leg_asp, 'Aspect [°]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
        fix_leg_scatter(leg_asp, leg_ico, leg_plots, DimItemScatLeg, LegendPosition)
        
        % fig_rescaler(ax_asp, leg_asp, LegendPosition)
        
        if ShowTitle; title(Titles(PlotNum(3)), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
    end
    
    %% Plot Mean Curvature
    if any(strcmp(string({PlotList{PlotOpts{i1}}}), 'MeanCurvature')) % IT MUST HAVE THE SAME NAME OF ABOVE!
        ax_mc = subplot(GirdSubPlots(1),GirdSubPlots(2),PlotNum(4), 'Parent',curr_fig);
        hold(ax_mc,'on');
        set(ax_mc, 'visible','on')
        
        hmeancurv = cell(length(MeanCurvRange)-1, size(xLongStudy,2));
        for i2 = 1:length(MeanCurvRange)-1
            hmeancurv(i2,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                            'MarkerFaceColor',ColorMeanCurv(i2,:)./255, ...
                                                            'MarkerEdgeColor','none', 'Parent',ax_mc), ...
                                            xLongStudy, yLatStudy, MeanCurvIndex(i2,:), 'UniformOutput',false);
        end
        
        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_mc)
        
        xlim(xLimits)
        ylim(yLimits)
        % xtickformat('degrees')
        % ytickformat('degrees')
        xticks([])
        yticks([])
        if ShowBox; box on; else; axis off; end
        
        daspect(ax_mc, [1, RatioLatLong, 1])
        
        SplitLegMeanCurvMap = split_text_newline(LegMeanCurvMap, MaxLengthText);
        LegendObjects  = hmeancurv(1:end,1);
        
        [leg_mc, leg_ico, leg_plots] = legend([LegendObjects{:}], ...
                                               SplitLegMeanCurvMap, ...
                                               'NumColumns',1, ...
                                               'FontName',SelectedFont, ...
                                               'FontSize',SelectedFontSize, ...
                                               'Location',LegendPosition, ...
                                               'Box','off');
        
        title(leg_mc, 'Mean curvature [1/m]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
        fix_leg_scatter(leg_mc, leg_ico, leg_plots, DimItemScatLeg, LegendPosition)
        
        % fig_rescaler(ax_mc, leg_mc, LegendPosition)
        
        if ShowTitle; title(Titles(PlotNum(4)), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
    end
    
    %% Plot Lithology
    if any(strcmp(string({PlotList{PlotOpts{i1}}}), 'Lithology')) % IT MUST HAVE THE SAME NAME OF ABOVE!
        ax_lit = subplot(GirdSubPlots(1),GirdSubPlots(2),PlotNum(5), 'Parent',curr_fig);
        hold(ax_lit,'on');
        set(ax_lit, 'visible','on')
        
        plot(LithoPolygonsStudyArea(GoodPercLitho), 'Parent',ax_lit, 'LineWidth',LineIntSize, 'EdgeColor',EdgeColInt)
        plot(StudyAreaPolygon,'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_lit)
        
        xlim(xLimits)
        ylim(yLimits)
        % xtickformat('degrees')
        % ytickformat('degrees')
        xticks([])
        yticks([])
        if ShowBox; box on; else; axis off; end
        
        daspect(ax_lit, [1, RatioLatLong, 1])
        
        SplitLegLithoMap = split_text_newline(LegLithoMap, MaxLengthText);
        
        leg_lit = legend(SplitLegLithoMap, ...
                         'NumColumns',1, ...
                         'FontName',SelectedFont, ...
                         'FontSize',SelectedFontSize, ...
                         'Location',LegendPosition, ...
                         'Box','off');
        
        title(leg_lit, 'Lithology', 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
        leg_lit.ItemTokenSize = DimItemPolyLeg;
        
        % fig_rescaler(ax_lit, leg_lit, LegendPosition)
        
        if ShowTitle; title(Titles(PlotNum(5)), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
    end
    
    %% Plot Top Soil
    if any(strcmp(string({PlotList{PlotOpts{i1}}}), 'TopSoil')) % IT MUST HAVE THE SAME NAME OF ABOVE!
        ax_ts = subplot(GirdSubPlots(1),GirdSubPlots(2),PlotNum(6), 'Parent',curr_fig);
        hold(ax_ts,'on');
        set(ax_ts, 'visible','on')
        
        plot(TopSoilPolygonsStudyArea(GoodPercTopSoil), 'Parent',ax_ts, 'LineWidth',LineIntSize, 'EdgeColor',EdgeColInt)
        plot(StudyAreaPolygon,'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_ts)
        
        xlim(xLimits)
        ylim(yLimits)
        % xtickformat('degrees')
        % ytickformat('degrees')
        xticks([])
        yticks([])
        if ShowBox; box on; else; axis off; end
        
        daspect(ax_ts, [1, RatioLatLong, 1])
        
        SplitLegTopSoilMap = split_text_newline(LegTopSoilMap, MaxLengthText);
        
        leg_ts = legend(SplitLegTopSoilMap, ...
                        'NumColumns',1, ...
                        'FontName',SelectedFont, ...
                        'FontSize',SelectedFontSize, ...
                        'Location',LegendPosition, ...
                        'Box','off');
        
        title(leg_ts, 'Top Soil', 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
        leg_ts.ItemTokenSize = DimItemPolyLeg;
        
        % fig_rescaler(ax_ts, leg_ts, LegendPosition)
        
        if ShowTitle; title(Titles(PlotNum(6)), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
    end
    
    %% Plot Land Use
    if any(strcmp(string({PlotList{PlotOpts{i1}}}), 'LandUse')) % IT MUST HAVE THE SAME NAME OF ABOVE!
        ax_lu = subplot(GirdSubPlots(1),GirdSubPlots(2),PlotNum(7), 'Parent',curr_fig);
        hold(ax_lu,'on');
        set(ax_lu, 'visible','on')
        
        plot(LandUsePolygonsStudyArea(GoodPercLandUse), 'Parent',ax_lu, 'LineWidth',LineIntSize, 'EdgeColor',EdgeColInt)
        plot(StudyAreaPolygon,'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_lu)
        
        xlim(xLimits)
        ylim(yLimits)
        % xtickformat('degrees')
        % ytickformat('degrees')
        xticks([])
        yticks([])
        if ShowBox; box on; else; axis off; end
        
        daspect(ax_lu, [1, RatioLatLong, 1])
        
        SplitLegLandUseMap = split_text_newline(LegLandUseMap, MaxLengthText);
        
        leg_lu = legend(SplitLegLandUseMap, ...
                        'NumColumns',1, ...
                        'FontName',SelectedFont, ...
                        'FontSize',SelectedFontSize, ...
                        'Location',LegendPosition, ...
                        'Box','off');
        
        title(leg_lu, 'Land Use', 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
        leg_lu.ItemTokenSize = DimItemPolyLeg;
        
        %fig_rescaler(ax_lu, leg_lu, LegendPosition)
        
        if ShowTitle; title(Titles(PlotNum(7)), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
    end
    
    %% Plot Vegetation
    if any(strcmp(string({PlotList{PlotOpts{i1}}}), 'Vegetation')) % IT MUST HAVE THE SAME NAME OF ABOVE!
        ax_veg = subplot(GirdSubPlots(1),GirdSubPlots(2),PlotNum(8), 'Parent',curr_fig);
        hold(ax_veg,'on');
        set(ax_veg, 'visible','on')
        
        arrayfun(@(x,y) plot(x,'FaceColor',y, 'Parent',ax_veg, 'LineWidth',LineIntSize, 'EdgeColor',EdgeColInt), ...
                    VegPolygonsStudyArea(GoodPercVeg), string(ColorVegMap))
        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_veg)
        
        xlim(xLimits)
        ylim(yLimits)
        % xtickformat('degrees')
        % ytickformat('degrees')
        xticks([])
        yticks([])
        if ShowBox; box on; else; axis off; end
        
        daspect(ax_veg, [1, RatioLatLong, 1])
        
        SplitLegVegMap = split_text_newline(LegVegMap, MaxLengthText);
        
        leg_veg = legend(SplitLegVegMap, ...
                         'NumColumns',1, ...
                         'FontName',SelectedFont, ...
                         'FontSize',SelectedFontSize, ...
                         'Location',LegendPosition, ...
                         'Box','off');
        
        title(leg_veg, 'Vegetation', 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
        leg_veg.ItemTokenSize = DimItemPolyLeg;
        
        % fig_rescaler(ax_veg, leg_veg, LegendPosition)
        
        if ShowTitle; title(Titles(PlotNum(8)), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
    end
    
    %% Layout config (for non time sensitive part)
    if strcmp(PlotChoice, 'Unique Figure')
        axes_names  = who('-regexp','ax_');
        legs_names  = who('-regexp','leg_');
        IndToRemove = contains(legs_names, {'ico', 'plots'});
        legs_names(IndToRemove) = [];
        
        [PosOfPlots, PosOfLegends] = deal(cell(1, length(axes_names)));
        for i2 = 1:length(axes_names)
            PosOfPlots{i2}   = get(eval(axes_names{i2}), 'Position');
            PosOfLegends{i2} = get(eval(legs_names{i2}), 'Position');
        end
        
        DimsPlotsOld = cell2mat(PosOfPlots');
        MaxDims      = [max(DimsPlotsOld(:,3)), max(DimsPlotsOld(:,4))];
        xPlotsPos    = [min(DimsPlotsOld(:,1)), max(DimsPlotsOld(:,1))];
        DimsPlotsNew = [DimsPlotsOld(:,1:2), repmat(MaxDims, size(DimsPlotsOld, 1), 1)];
        
        for i2 = 1:length(axes_names)
            set(eval(axes_names{i2}), 'Position',DimsPlotsNew(i2,:))
        end
    end
    
    %% Plot Cumulative Time Sensitive
    if any(ismember(PlotList(PlotOpts{1}), TimeSensitiveParam))
        IndCum = listdlg('PromptString',{'Select what plot do you want for time sensitive part:',''}, ...
                         'ListString',string(DaysToCumTimeSens), 'SelectionMode','multiple');
        
        if strcmp(PlotChoice, 'Unique Figure')
            IndTit = PlotNum(end)+1;
        else
            IndTit = PlotNum(end);
        end
        IndFig = 1;
        [ax_rain, leg_rain] = deal(cell(1, length(TimeSensitiveParam)*length(IndCum)));
        for i2 = 1:length(TimeSensitiveParam)
            for i3 = IndCum
                StartInd = (GirdSubPlots(1)-1)*length(IndCum);
                ax_rain{IndFig} = subplot(GirdSubPlots(1),length(IndCum),StartInd+IndFig, 'Parent',curr_fig);
                hold(ax_rain{IndFig},'on');
                set(ax_rain{IndFig}, 'visible','on')
            
                hrain = cell(length(TimeSensRanges{i3,i2})-1, size(xLongStudy,2));
                for i4 = 1:length(TimeSensRanges{i3,i2})-1
                    hrain(i4,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                                    'MarkerFaceColor',ColorRain(i4,:)./255, ...
                                                                    'MarkerEdgeColor','none', 'Parent',ax_rain{IndFig}), ...
                                                    xLongStudy, yLatStudy, TimeSensIndex{i3,i2}(i4,:), 'UniformOutput',false);
                end
                
                plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',LineExtSize, 'Parent',ax_rain{IndFig})
                
                xlim(xLimits)
                ylim(yLimits)
                % xtickformat('degrees')
                % ytickformat('degrees')
                xticks([])
                yticks([])
                if ShowBox; box on; else; axis off; end
                
                daspect(ax_rain{IndFig}, [1, RatioLatLong, 1])
                
                SplitLegTimeSensMap = split_text_newline(LegTimeSensMap{i3,i2}, MaxLengthText);
                LegendObjects = hrain(1:end,1);
            
                [leg_rain{IndFig}, leg_ico, leg_plots] = legend([LegendObjects{:}], ...
                                                                SplitLegTimeSensMap, ...
                                                                'NumColumns',1, ...
                                                                'FontName',SelectedFont, ...
                                                                'FontSize',SelectedFontSize, ...
                                                                'Location',LegendPositionTS, ...
                                                                'Box','off');
        
                title(leg_rain{IndFig}, [TimeSensOperType{i2},' ',TimeSensitiveParam{i2},' [mm]'], ...
                                        'FontName',SelectedFont, 'FontSize',SelectedFontSize)
                fix_leg_scatter(leg_rain{IndFig}, leg_ico, leg_plots, DimItemScatLeg, LegendPositionTS)
                text(ax_rain{IndFig}, 0.1, 0.9, [num2str(DaysToCumTimeSens(i3)),'d'], 'FontName',SelectedFont, 'FontSize',SelectedFontSize, 'Units','normalized')
                
                % fig_rescaler(ax_rain{IndFig}, leg_rain{IndFig}, LegendPosition)
            
                if IndividualTitlesTS
                    if ShowTitle; title(Titles(IndTit), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
                    IndTit = IndTit + 1;
                else
                    if i3 == int64(length(IndCum)/2)
                        if ShowTitle; title(Titles(IndTit), 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end
                        IndTit = IndTit + 1;
                    end
                end
        
                IndFig = IndFig + 1;
            end
        end
        
        PosOfPlotsRain   = cellfun(@(x) get(x, 'Position'), ax_rain, 'UniformOutput',false);
        PosOfLgendsRain  = cellfun(@(x) get(x, 'Position'), leg_rain, 'UniformOutput',false);
        WidthOfLegRain   = max(cellfun(@(x) x(3), PosOfLgendsRain));
        HeightOfLegRain  = max(cellfun(@(x) x(4), PosOfLgendsRain));
        DimsPlotsRainOld = cell2mat(PosOfPlotsRain');
        if length(IndCum) >= 3
            switch LegendPositionTS
                case {'eastoutside', 'westoutside'}
                    xShift = (MaxDims(1)+WidthOfLegRain)/2;
                    yPosPlotRain = DimsPlotsRainOld(:,2);
                case {'southoutside', 'northoutside'}
                    xShift = MaxDims(1)/2;
                    yPosPlotRain = DimsPlotsRainOld(:,2)-HeightOfLegRain;
                otherwise
                    xShift = MaxDims(1)/2;
                    yPosPlotRain = DimsPlotsRainOld(:,2);
            end
            xPlotsRainNew = [xPlotsPos(1)-xShift, mean(xPlotsPos), xPlotsPos(2)+xShift];
        
            DimsPlotsRainNew = [repmat(xPlotsRainNew', numel(TimeSensitiveParam), 1), ...
                                yPosPlotRain, ...
                                repmat(MaxDims, size(DimsPlotsRainOld, 1), 1)];
            
            cellfun(@(x,y) set(x, 'Position',y), ax_rain', num2cell(DimsPlotsRainNew,2))
        end
    end
    
    %% Export
    cd(fold_fig)
    exportgraphics(curr_fig, strcat(filename_fig,'.png'), 'Resolution',600);
    close(curr_fig)
    cd(fold0)
end

close(ProgressBar)