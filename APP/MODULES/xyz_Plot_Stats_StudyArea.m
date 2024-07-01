if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data
cd(fold_var)
load('GridCoordinates.mat'         , 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load('MorphologyParameters.mat'    , 'AspectAngleAll','ElevationAll','SlopeAll', ...
                                     'MeanCurvatureAll','ProfileCurvatureAll','PlanformCurvatureAll')
load('FlowRouting.mat'             , 'ContributingAreaAll','TwiAll')
load('SoilGrids.mat'               , 'ClayContentAll','SandContentAll','NdviAll')
load('LithoPolygonsStudyArea.mat'  , 'LithoAllUnique','LithoPolygonsStudyArea')
load('TopSoilPolygonsStudyArea.mat', 'TopSoilAllUnique','TopSoilPolygonsStudyArea')
load('LandUsesVariables.mat'       , 'AllLandUnique','LandUsePolygonsStudyArea')
load('VegPolygonsStudyArea.mat'    , 'VegetationAllUnique','VegPolygonsStudyArea')
load('Distances.mat'               , 'MinDistToRoadAll')
load('RainInterpolated.mat'        , 'RainInterpolated','RainDateInterpolationStarts')
load('TempInterpolated.mat'        , 'TempInterpolated','TempDateInterpolationStarts')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat', 'Font','FontSize','LegendPosition')
    SelectedFont     = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont     = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition   = 'Best';
end
cd(fold0)

%% Plot options
Options  = {'Study Area', 'Stable Area', 'Unstable Area'};
PlotArea = uiconfirm(Fig, 'In what area do you want to plot?', ...
                           'Plot Area', 'Options',Options);

if any(strcmp(PlotArea, {'Stable Area', 'Unstable Area'}))
    fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
    cd(fold_res_ml_curr)
    load('TrainedANNs.mat', 'UnstablePolyMrgd','StablePolyMrgd')
    cd(fold0)
end

switch PlotArea
    case 'Study Area'
        IndsDTMPointsInsideStatArea = IndexDTMPointsInsideStudyArea;

    case 'Stable Area'
        [pp1, ee1] = getnan2([StablePolyMrgd.Vertices; nan, nan]);
        IndsDTMPointsInsideStatArea = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp1,ee1)), xLongAll, yLatAll, 'UniformOutput',false);

    case 'Unstable Area'
        [pp1, ee1] = getnan2([UnstablePolyMrgd.Vertices; nan, nan]);
        IndsDTMPointsInsideStatArea = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp1,ee1)), xLongAll, yLatAll, 'UniformOutput',false);
end

Options  = {'BoxPlot', 'CumulativeDistribution'};
PlotType = uiconfirm(Fig, 'How do you want to plot results?', ...
                           'Plot Type', 'Options',Options);

Options   = {'Yes', 'No'};
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',Options, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

ShowTitle = true; % CHOICE TO USER!

Titles = string(strcat(('a':'z')', ')'));

%% Extraction of points in study area (numerical part)
ProgressBar.Message = 'Extraction of points in study area for numerical part...';

xLongStudy             = cellfun(@(x,y) x(y), xLongAll,             IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudy              = cellfun(@(x,y) x(y), yLatAll,              IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('yLatAll')

Info.ElevationStudy    = cellfun(@(x,y) x(y), ElevationAll,         IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('ElevationAll')

Info.SlopeStudy        = cellfun(@(x,y) x(y), SlopeAll,             IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('SlopeAll')

Info.AspectAngleStudy  = cellfun(@(x,y) x(y), AspectAngleAll,       IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('AspectAngleAll')

Info.MeanCurvStudy     = cellfun(@(x,y) x(y), MeanCurvatureAll,     IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('MeanCurvatureAll')

Info.ProfileCurvStudy  = cellfun(@(x,y) x(y), ProfileCurvatureAll,  IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('ProfileCurvatureAll')

Info.PlanformCurvStudy = cellfun(@(x,y) x(y), PlanformCurvatureAll, IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('PlanformCurvatureAll')

Info.ContribAreaStudy  = cellfun(@(x,y) x(y), ContributingAreaAll,  IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('ContributingAreaAll')

Info.TwiStudy          = cellfun(@(x,y) x(y), TwiAll,               IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('TwiAll')

Info.ClayContentStudy  = cellfun(@(x,y) x(y), ClayContentAll,       IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('ClayContentAll')

Info.SandContentStudy  = cellfun(@(x,y) x(y), SandContentAll,       IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('SandContentAll')

Info.NdviStudy         = cellfun(@(x,y) x(y), NdviAll,              IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('NdviAll')

Info.DistToRoadStudy   = cellfun(@(x,y) x(y), MinDistToRoadAll,     IndsDTMPointsInsideStatArea, 'UniformOutput',false);
clear('MinDistToRoadAll')

NumericalParam = {'Elevation', 'Slope', 'Aspect', 'MeanCurvature', 'ProfileCurvature', 'PlanformCurvature', ...
                  'ContributingArea', 'Twi', 'ClayContent', 'SandContent', 'Ndvi', 'MinDistToRoad'};
TypeParam      = ones(1, length(NumericalParam));

%% Extraction of points in study area (categorical part)
ProgressBar.Message = 'Extraction of points in study area for categorical part...';

Options = {'Categorical classes', 'Numbered classes'};
CategoricalChoice = uiconfirm(Fig, 'How do you want to define classes?', ...
                                   'Classes type', 'Options',Options, 'DefaultOption',2);
if strcmp(CategoricalChoice,'Categorical classes'); CategoricalClasses = true; else; CategoricalClasses = false; end

% Matrices initialization
if CategoricalClasses
    Info.LithoStudy   = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    Info.TopSoilStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    Info.LandUseStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    Info.VegStudy     = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
else
    Info.LithoStudy   = cellfun(@(x) zeros(size(x)), xLongStudy, 'UniformOutput',false);
    Info.TopSoilStudy = cellfun(@(x) zeros(size(x)), xLongStudy, 'UniformOutput',false);
    Info.LandUseStudy = cellfun(@(x) zeros(size(x)), xLongStudy, 'UniformOutput',false);
    Info.VegStudy     = cellfun(@(x) zeros(size(x)), xLongStudy, 'UniformOutput',false);
end

% Excel reading
cd(fold_user)
SubSoilClasses = readcell('ClassesML.xlsx', 'Sheet','Sub soil');
TopSoilClasses = readcell('ClassesML.xlsx', 'Sheet','Top soil');
LandUseClasses = readcell('ClassesML.xlsx', 'Sheet','Land use');
VegClasses     = readcell('ClassesML.xlsx', 'Sheet','Vegetation');
cd(fold0)

% Litho classes association
ProgressBar.Message = "Associating subsoil classes...";
for i1 = 1:size(LithoAllUnique,2)
    IndClassLitho = find(strcmp(LithoAllUnique{i1}, string(SubSoilClasses(:,1))));
    if CategoricalClasses
        if isempty(IndClassLitho); ClassLitho = ""; else; ClassLitho = string(SubSoilClasses(IndClassLitho, 1)); end
    else
        if isempty(IndClassLitho); ClassLitho = 0; else; ClassLitho = SubSoilClasses{IndClassLitho, 2}; end
    end
    LUPolygon = LithoPolygonsStudyArea(i1);
    [pp,ee] = getnan2([LUPolygon.Vertices; nan, nan]);
    for i2 = 1:size(xLongStudy,2)
        if not(isempty(xLongStudy{i2}))
            IndexInsideLithoPolygon = find(inpoly([xLongStudy{i2},yLatStudy{i2}],pp,ee)==1);
            Info.LithoStudy{i2}(IndexInsideLithoPolygon) = ClassLitho;
        end
    end
end

% Top-soil classes association
ProgressBar.Message = "Associating topsoil classes...";
for i1 = 1:size(TopSoilAllUnique,2)
    IndClassTopSoil = find(strcmp(TopSoilAllUnique{i1}, string(TopSoilClasses(:,1))));
    if CategoricalClasses
        if isempty(IndClassTopSoil); ClassTopSoil = ""; else; ClassTopSoil = string(TopSoilClasses(IndClassTopSoil, 1)); end
    else
        if isempty(IndClassTopSoil); ClassTopSoil = 0; else; ClassTopSoil = TopSoilClasses{IndClassTopSoil, 2}; end
    end
    TSUPolygon = TopSoilPolygonsStudyArea(i1);
    [pp,ee] = getnan2([TSUPolygon.Vertices; nan, nan]);
    for i2 = 1:size(xLongStudy,2)
        if not(isempty(xLongStudy{i2}))
            IndexInsideTopSoilPolygon = find(inpoly([xLongStudy{i2},yLatStudy{i2}],pp,ee)==1);
            Info.TopSoilStudy{i2}(IndexInsideTopSoilPolygon) = ClassTopSoil;
        end
    end
end

% Land use classes association
ProgressBar.Message = "Associating land use classes...";
for i1 = 1:size(AllLandUnique,2)
    IndClassLand = find(strcmp(AllLandUnique{i1}, string(LandUseClasses(:,1))));
    if CategoricalClasses
        if isempty(IndClassLand); ClassLandUse = ""; else; ClassLandUse = string(LandUseClasses(IndClassLand, 1)); end
    else
        if isempty(IndClassLand); ClassLandUse = 0; else; ClassLandUse = LandUseClasses{IndClassLand, 2}; end
    end
    LandUsePolygon = LandUsePolygonsStudyArea(i1);
    [pp,ee] = getnan2([LandUsePolygon.Vertices; nan, nan]);
    for i2 = 1:size(xLongStudy,2)  
        if not(isempty(xLongStudy{i2}))
            IndexInsideLandUsePolygon = find(inpoly([xLongStudy{i2},yLatStudy{i2}],pp,ee)==1);
            Info.LandUseStudy{i2}(IndexInsideLandUsePolygon) = ClassLandUse;
        end
    end
end

% Veg classes association
ProgressBar.Message = "Associating vegetation classes...";
for i1 = 1:size(VegetationAllUnique,2)
    IndClassVeg = find(strcmp(VegetationAllUnique{i1}, string(VegClasses(:,1))));
    if CategoricalClasses
        if isempty(IndClassVeg); ClassVeg = ""; else; ClassVeg = string(VegClasses(IndClassVeg, 1)); end
    else
        if isempty(IndClassVeg); ClassVeg = 0; else; ClassVeg = VegClasses{IndClassVeg, 2}; end
    end
    VUPolygon = VegPolygonsStudyArea(i1);
    [pp_veg,ee_veg] = getnan2([VUPolygon.Vertices; nan, nan]);
    for i2 = 1:size(xLongStudy,2)  
        if not(isempty(xLongStudy{i2}))
            IndexInsideVegPolygon = find(inpoly([xLongStudy{i2},yLatStudy{i2}],pp_veg,ee_veg)==1);
            Info.VegStudy{i2}(IndexInsideVegPolygon) = ClassVeg;
        end
    end
end

CategoricalParam = {'Lithology', 'TopSoil', 'LandUse', 'Vegetation'};
if CategoricalClasses
    TypeParam = [TypeParam, repmat(2, 1, length(CategoricalParam))];
else
    TypeParam = [TypeParam, ones(1, length(CategoricalParam))];
end

%% Extraction of points in study area (time sensitive part)
ProgressBar.Message = 'Extraction of points in study area for time sensitive part...';

TimeSensitiveParam = {'Rainfall', 'Temperature'}; % Mantain same order of the rows below
CumulableParam     = [true      , false        ];
TimeSensitiveData  = {RainInterpolated, TempInterpolated};
TimeSensitiveDate  = {RainDateInterpolationStarts, TempDateInterpolationStarts};
clear('RainInterpolated', 'TempInterpolated')

StartDateCommon = max(cellfun(@min, TimeSensitiveDate));
EndDateCommon   = min(cellfun(@max, TimeSensitiveDate));

if EndDateCommon < StartDateCommon
    error('Time sensitive part has no common dates between features')
end

Options = {'SingleDay', 'Cumulate'};
TSChoice = uiconfirm(Fig, 'How do you want to plot statistics of time sensitive part?', ...
                          'Duration of TS', 'Options',Options, 'DefaultOption',2);

AvailableDates = RainDateInterpolationStarts( ...
                        find(RainDateInterpolationStarts == StartDateCommon) : find(RainDateInterpolationStarts == EndDateCommon) );

% Conversion in full
IndCommon = cellfun(@(x) find(ismember(x, AvailableDates)), TimeSensitiveDate, 'UniformOutput',false);
for i1 = 1:length(TimeSensitiveData)
    TimeSensitiveData{i1} = cellfun(@full, TimeSensitiveData{i1}(IndCommon{i1},:), 'UniformOutput',false);
end

% Choice of events
IndEvent = listdlg('PromptString',{'Select the dates you want to plot:',''}, ...
                   'ListString',AvailableDates, 'SelectionMode','Multiple');

DaysAvailableToCumulate = min(IndEvent);

if strcmp(TSChoice, 'Cumulate')
    DaysToCumulate = str2double(inputdlg({[ "Please specify how many days you want to cumulate: "
                                            strcat("Max: ",string(DaysAvailableToCumulate))       ]}, ...
                                            '', 1, {num2str(DaysAvailableToCumulate)}                 ));
    if DaysToCumulate > DaysAvailableToCumulate
        error('You have to select a number of days to cumulate <= than max possible')
    end
else
    DaysToCumulate = 1;
end

% Creation of Info to add
TimeSensDataStudy = cell(length(IndEvent), length(TimeSensitiveParam));
ChosedDates       = cell(1, length(IndEvent));
for i1 = 1:length(IndEvent)
    RowToTake       = IndEvent(i1);
    ChosedDates{i1} = char(AvailableDates(RowToTake));
    for i2 = 1:length(TimeSensitiveParam)
        for i3 = 1:size(TimeSensitiveData{i2}, 2)
            if CumulableParam(i2)
                TimeSensDataStudy{i1, i2}{i3} = sum([TimeSensitiveData{i2}{RowToTake : -1 : (RowToTake-DaysToCumulate+1), i3}], 2);
            else
                TimeSensDataStudy{i1, i2}{i3} = mean([TimeSensitiveData{i2}{RowToTake : -1 : (RowToTake-DaysToCumulate+1), i3}], 2);
            end
        end
    end
end

for i1 = 1:length(TimeSensitiveParam)
    Info.(TimeSensitiveParam{i1}) = [TimeSensDataStudy(:,i1), ChosedDates'];
end

TypeParam = [TypeParam, repmat(3, 1, length(TimeSensitiveParam))];

%% Concatenation, quantiles, and extremes
InfoFieldnames = fieldnames(Info);
[QuantsPerField, LimitsPerField, ...
        ValsCatPerField, ClassAssociation] = deal(cell(1, length(InfoFieldnames)));
for i1 = 1:length(InfoFieldnames)
    switch TypeParam(i1)
        case 1
            ValsCatPerField{i1}{1} = cat(1, Info.(InfoFieldnames{i1}){:});

        case 2
            ValsCatPerFieldTemp = cat(1, Info.(InfoFieldnames{i1}){:});
            ValsCatPerFieldTemp = categorical(cellstr(ValsCatPerFieldTemp), 'Ordinal',true);
            [ValsCatPerField{i1}{1}, ClassAssociation{i1}] = grp2idx(ValsCatPerFieldTemp);

        case 3
            ValsCatPerField{i1} = cellfun(@(x) cat(1, x{:}), Info.(InfoFieldnames{i1})(:,1), 'UniformOutput',false);
    end

    QuantsPerField{i1}     = cellfun(@(x) quantile(x, [0.25, 0.75]), ValsCatPerField{i1}, 'UniformOutput',false);
    LimitsPerField{i1}     = cellfun(@(x) quantile(x, [0, 1]), ValsCatPerField{i1}, 'UniformOutput',false);
end

%% Figure initialization
ProgressBar.Message = 'Figure creation...';

Options    = {'Unique Figure', 'Separate Figures'};
PlotChoice = uiconfirm(Fig, 'How do you want to plot figures?', ...
                            'Plot choice', 'Options',Options, 'DefaultOption',1);

PlotList = [NumericalParam, CategoricalParam, TimeSensitiveParam]; % THEY MUST HAVE THE SAME NAME OF BELOW!
PlotLblPerField = cell(1, length(InfoFieldnames));
for i1 = 1:length(PlotLblPerField)
    if TypeParam(i1) == 3
        % PlotLblPerField{i1} = cellstr(strcat(PlotList{i1}, " ", Info.(PlotList{i1})(:,2), " ", ...
        %                                      TSChoice, string(DaysToCumulate),"d"));
        PlotLblPerField{i1} = cellstr(strcat(PlotList{i1}, " ", ...
                                             repmat(TSChoice, 2, 1), string(DaysToCumulate),"d"));
    else
        PlotLblPerField{i1} = PlotList(i1);
    end
end

TimeIndependent = length(PlotList)-length(TimeSensitiveParam);

if strcmp(PlotChoice, 'Separate Figures')
    PlotOpts = num2cell(listdlg('PromptString',{'Choose what do you want to plot:',''}, ...
                                'ListString',PlotList, 'SelectionMode','multiple'));
else
    PlotOpts = {1:length(PlotList)};
end

if strcmp(PlotType, 'BoxPlot')
    fold_fig_curr = [fold_fig,sl,'Box Plots ',PlotArea];
elseif strcmp(PlotType, 'CumulativeDistribution')
    fold_fig_curr = [fold_fig,sl,'Cumulative Distributions ',PlotArea];
end

if ~exist(fold_fig_curr, 'dir')
    mkdir(fold_fig_curr)
end

%% Plot section
cd(fold_fig_curr)
for i1 = 1:length(PlotOpts)
    if strcmp(PlotChoice, 'Unique Figure')
        if strcmp(PlotType, 'BoxPlot')
            filename_fig = ['Overall features box plots in ',PlotArea];
        elseif strcmp(PlotType, 'CumulativeDistribution')
            filename_fig = ['Overall features cumulative distributions in ',PlotArea];
        end
        GirdSubPlots = [4, 4];
        curr_fig = figure('Position',[80, 50, 600, 900], 'Visible','off');
        PlotNum  = 1:TimeIndependent; % You can even rearrange the order!
    elseif strcmp(PlotChoice, 'Separate Figures')
        if strcmp(PlotType, 'BoxPlot')
            filename_fig = [PlotList{PlotOpts{i1}}, ' feature box plot in ',PlotArea];
        elseif strcmp(PlotType, 'CumulativeDistribution')
            filename_fig = [PlotList{PlotOpts{i1}}, ' feature cumulative distribution in ',PlotArea];
        end
        GirdSubPlots = [1, length(ValsCatPerField{PlotOpts{i1}})];
        curr_fig = figure(i1);
        set(curr_fig, 'visible','off')
        PlotNum  = ones(1, length(PlotList));
    end

    set(curr_fig, 'Name',filename_fig);

    %% Figures creation
    ax_curr   = cell(1, numel(PlotOpts{i1}));
    NumOfPlot = 1;
    for i2 = 1:numel(PlotOpts{i1})
        for i3 = 1:length(ValsCatPerField{PlotOpts{i1}})
            ValuesToUse = ValsCatPerField{PlotOpts{i1}}{i3};
            ValuesDescr = {PlotLblPerField{PlotOpts{i1}}{i3}};
            QuantsToUse = QuantsPerField{i1}{i3};

            ax_curr{i2} = subplot(GirdSubPlots(1),GirdSubPlots(2),NumOfPlot, 'Parent',curr_fig);
            hold(ax_curr{i2},'on');
    
            switch PlotType
                case 'BoxPlot'
                    boxplot(ax_curr{i2}, ValuesToUse, ValuesDescr, ...
                                    'Notch','on', 'OutlierSize',4, 'Symbol',['.'; 'm']);

                    IQR        = QuantsToUse(2) - QuantsToUse(1);
                    UpperFence = QuantsToUse(2) + 1.5*IQR;
                    LowerFence = QuantsToUse(1) - 1.5*IQR;
    
                    xlim([0.75, 1.25])
                    ylim([0.98*LowerFence, 1.05*UpperFence])
                    pbaspect([1,1.5,1])
    
                case 'CumulativeDistribution'
                    cdfplot(ValuesToUse);
                    xline(QuantsToUse(1), '--r', [num2str(round(QuantsToUse(1), 3)),' (1st quartile)'], ...
                                        'LabelVerticalAlignment','bottom', 'LabelHorizontalAlignment','left');
                    xline(QuantsToUse(2), '--r', [num2str(round(QuantsToUse(2), 3)),' (3rd quartile)'], ...
                                        'LabelVerticalAlignment','top', 'LabelHorizontalAlignment','right');
                    xlabel('Values')
                    ylabel('Cumulative frequency')
    
                    pbaspect([2,1,1])
            end
            
            if ShowTitle; title(Titles{NumOfPlot}, 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize); end

            NumOfPlot = NumOfPlot + 1;
        end
    end

    %% Showing plot and saving...
    if ShowPlots
        set(curr_fig, 'visible','on');
        pause
    end

    exportgraphics(curr_fig, strcat(filename_fig,'.png'), 'Resolution',600);
    close(curr_fig)
end
cd(fold0)

close(ProgressBar)