if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'         ], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load([fold_var,sl,'MorphologyParameters.mat'    ], 'AspectAngleAll','ElevationAll','SlopeAll', ...
                                                   'MeanCurvatureAll','ProfileCurvatureAll','PlanformCurvatureAll')
load([fold_var,sl,'FlowRouting.mat'             ], 'ContributingAreaAll','TwiAll')
load([fold_var,sl,'SoilGrids.mat'               ], 'ClayContentAll','SandContentAll','NdviAll')
load([fold_var,sl,'LithoPolygonsStudyArea.mat'  ], 'LithoAllUnique','LithoPolygonsStudyArea')
load([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], 'TopSoilAllUnique','TopSoilPolygonsStudyArea')
load([fold_var,sl,'LandUsesVariables.mat'       ], 'AllLandUnique','LandUsePolygonsStudyArea')
load([fold_var,sl,'VegPolygonsStudyArea.mat'    ], 'VegetationAllUnique','VegPolygonsStudyArea')
load([fold_var,sl,'Distances.mat'               ], 'MinDistToRoadAll')
load([fold_var,sl,'RainInterpolated.mat'        ], 'RainInterpolated','RainDateInterpolationStarts')
load([fold_var,sl,'TempInterpolated.mat'        ], 'TempInterpolated','TempDateInterpolationStarts')

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

%% Plot options
StatOpts = listdlg2({'Which area?', 'Type of plot?', 'Categorical classes?', ...
                     'Stats of TS?', 'Type of figure?', 'Show title?', 'Show plot?'}, ...
                    {{'Study Area', 'Stable Area', 'Unstable Area'}, ...
                     {'BoxPlot', 'CumulativeDistribution'}, {'Yes', 'No'}, {'SingleDay', 'Cumulate'}, ...
                     {'Unique Figure', 'Separate Figures'}, {'Yes', 'No'}, {'Yes', 'No'}});

PlotArea = StatOpts{1};
PlotType = StatOpts{2};
if strcmp(StatOpts{3},'Yes'); CategClss = true; else; CategClss = false; end
TSChoice = StatOpts{4};
PltFigTp = StatOpts{5};
if strcmp(StatOpts{6},'Yes'); ShowTitle = true; else; ShowTitle = false; end
if strcmp(StatOpts{7},'Yes'); ShowPlots = true; else; ShowPlots = false; end

if any(strcmp(PlotArea, {'Stable Area', 'Unstable Area'}))
    load([fold_var,sl,'DatasetMLB.mat'], 'DatasetInfo')

    IndPolys = listdlg2({'Select polygons to use:'}, DatasetInfo.EventDate, 'OutType','NumInd');
    StabPlyM = union(DatasetInfo.PolysStable{IndPolys});
    UnstPlyM = union(DatasetInfo.PolysUnstable{IndPolys});
end

switch PlotArea
    case 'Study Area'
        IndsPtsInStatArea = IndexDTMPointsInsideStudyArea;

    case 'Stable Area'
        [pp1, ee1] = getnan2([StabPlyM.Vertices; nan, nan]);
        IndsPtsInStatArea = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp1,ee1)), xLongAll, yLatAll, 'UniformOutput',false);

    case 'Unstable Area'
        [pp1, ee1] = getnan2([UnstPlyM.Vertices; nan, nan]);
        IndsPtsInStatArea = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp1,ee1)), xLongAll, yLatAll, 'UniformOutput',false);
end

Titles = string(strcat(('a':'z')', ')'));

NumerParam = {'Elevation', 'Slope', 'Aspect', 'MeanCurvature', 'ProfileCurvature', 'PlanformCurvature', ...
                  'ContributingArea', 'Twi', 'ClayContent', 'SandContent', 'Ndvi', 'MinDistToRoad'}; % Do not change order!
CategParam = {'Lithology', 'TopSoil', 'LandUse', 'Vegetation'}; % Do not change order!
TmSnsParam = {'Rainfall', 'Temperature'}; % Do not change order!

PltList = [NumerParam, CategParam, TmSnsParam];
if strcmp(PltFigTp, 'Separate Figures')
    PltOpts = num2cell(checkbox2(PltList, 'Title',{'Feats to plot:'}, 'OutType','NumInd'));
else
    PltOpts = {1:numel(PltList)};
end

ParamType = ones(1, length(NumerParam)); % 1 -> Numeric; 2 -> categorical; 3 -> time sensitive
if CategClss
    ParamType = [ParamType, repmat(2, 1, length(CategParam))];
else
    ParamType = [ParamType, ones(1, length(CategParam))];
end
ParamType = [ParamType, repmat(3, 1, length(TmSnsParam))];

%% Extraction of points in study area (numerical part)
ProgressBar.Message = 'Extraction of points in study area for numerical part...';

xLonStat               = cellfun(@(x,y) x(y), xLongAll,             IndsPtsInStatArea, 'UniformOutput',false);
clear('xLongAll')

yLatStat               = cellfun(@(x,y) x(y), yLatAll,              IndsPtsInStatArea, 'UniformOutput',false);
clear('yLatAll')

Info.ElevationStudy    = cellfun(@(x,y) x(y), ElevationAll,         IndsPtsInStatArea, 'UniformOutput',false);
clear('ElevationAll')

Info.SlopeStudy        = cellfun(@(x,y) x(y), SlopeAll,             IndsPtsInStatArea, 'UniformOutput',false);
clear('SlopeAll')

Info.AspectAngleStudy  = cellfun(@(x,y) x(y), AspectAngleAll,       IndsPtsInStatArea, 'UniformOutput',false);
clear('AspectAngleAll')

Info.MeanCurvStudy     = cellfun(@(x,y) x(y), MeanCurvatureAll,     IndsPtsInStatArea, 'UniformOutput',false);
clear('MeanCurvatureAll')

Info.ProfileCurvStudy  = cellfun(@(x,y) x(y), ProfileCurvatureAll,  IndsPtsInStatArea, 'UniformOutput',false);
clear('ProfileCurvatureAll')

Info.PlanformCurvStudy = cellfun(@(x,y) x(y), PlanformCurvatureAll, IndsPtsInStatArea, 'UniformOutput',false);
clear('PlanformCurvatureAll')

Info.ContribAreaStudy  = cellfun(@(x,y) x(y), ContributingAreaAll,  IndsPtsInStatArea, 'UniformOutput',false);
clear('ContributingAreaAll')

Info.TwiStudy          = cellfun(@(x,y) x(y), TwiAll,               IndsPtsInStatArea, 'UniformOutput',false);
clear('TwiAll')

Info.ClayContentStudy  = cellfun(@(x,y) x(y), ClayContentAll,       IndsPtsInStatArea, 'UniformOutput',false);
clear('ClayContentAll')

Info.SandContentStudy  = cellfun(@(x,y) x(y), SandContentAll,       IndsPtsInStatArea, 'UniformOutput',false);
clear('SandContentAll')

Info.NdviStudy         = cellfun(@(x,y) x(y), NdviAll,              IndsPtsInStatArea, 'UniformOutput',false);
clear('NdviAll')

Info.DistToRoadStudy   = cellfun(@(x,y) x(y), MinDistToRoadAll,     IndsPtsInStatArea, 'UniformOutput',false);
clear('MinDistToRoadAll')

%% Extraction of points in study area (categorical part)
ProgressBar.Message = 'Extraction of points in study area for categorical part...';

ClassesML = read_ml_association_spreadsheet([fold_user,sl,'ClassesML.xlsx']);

[ClassStat, ~, ~, LabelName] = classes_ml_association(ClassesML, xLonStat, yLatStat, ...
                                                      fold_var, categVars=CategClss, uiFig2Use=Fig);
for i1 = 1:numel(LabelName)
    switch LabelName{i1}
        case 'Sub soil'
            Info.LithoStudy   = ClassStat{i1};

        case 'Top soil'
            Info.TopSoilStudy = ClassStat{i1};

        case 'Land use'
            Info.LandUseStudy = ClassStat{i1};

        case 'Vegetation'
            Info.VegStudy     = ClassStat{i1};

        otherwise
            error('Type of categorical data not recognized!')
    end
end
clear('ClassStat')

%% Extraction of points in study area (time sensitive part)
ProgressBar.Message = 'Extraction of points in study area for time sensitive part...';

CumuParam = [true, false];
TmSnsData = {RainInterpolated, TempInterpolated};
TmSnsDate = {RainDateInterpolationStarts, TempDateInterpolationStarts};
clear('RainInterpolated', 'TempInterpolated')

StrDatCmm = max(cellfun(@min, TmSnsDate));
EndDatCmm = min(cellfun(@max, TmSnsDate));

if EndDatCmm < StrDatCmm
    error('Time sensitive part has no common dates between features')
end

FreeDates = RainDateInterpolationStarts( ...
                        find(RainDateInterpolationStarts == StrDatCmm) : find(RainDateInterpolationStarts == EndDatCmm) );

% Conversion in full
IndCommon = cellfun(@(x) find(ismember(x, FreeDates)), TmSnsDate, 'UniformOutput',false);
for i1 = 1:length(TmSnsData)
    TmSnsData{i1} = cellfun(@full, TmSnsData{i1}(IndCommon{i1},:), 'UniformOutput',false);
end

% Choice of events
IndEvents = checkbox2(FreeDates, 'Title',{'Dates you want to use:'}, 'OutType','NumInd');

PossDys2C = min(IndEvents);

if strcmp(TSChoice, 'Cumulate')
    Dys2Cumul = str2double(inputdlg2(['Days to cumulate (Max: ', ... 
                                           num2str(PossDys2C),')'], 'DefInp',num2str(PossDys2C)));
    if Dys2Cumul > PossDys2C
        error('You have to select a number of days to cumulate <= than max possible')
    end
else
    Dys2Cumul = 1;
end

% Creation of Info to add
TSDataStd = cell(length(IndEvents), length(TmSnsParam));
ChsnDates = cell(1, length(IndEvents));
for i1 = 1:length(IndEvents)
    RowToTake     = IndEvents(i1);
    ChsnDates{i1} = char(FreeDates(RowToTake));
    for i2 = 1:length(TmSnsParam)
        for i3 = 1:size(TmSnsData{i2}, 2)
            if CumuParam(i2)
                TSDataStd{i1, i2}{i3} = sum([TmSnsData{i2}{RowToTake : -1 : (RowToTake-Dys2Cumul+1), i3}], 2);
            else
                TSDataStd{i1, i2}{i3} = mean([TmSnsData{i2}{RowToTake : -1 : (RowToTake-Dys2Cumul+1), i3}], 2);
            end
        end
    end
end

for i1 = 1:length(TmSnsParam)
    Info.(TmSnsParam{i1}) = [TSDataStd(:,i1), ChsnDates'];
end

%% Concatenation, quantiles, and extremes
InfoFields = fieldnames(Info);
[Qnts4Fld, Lims4Fld, ...
        Vals4Fld, ClassAss] = deal(cell(1, length(InfoFields)));
for i1 = 1:length(InfoFields)
    switch ParamType(i1)
        case 1
            Vals4Fld{i1}{1} = cat(1, Info.(InfoFields{i1}){:});

        case 2
            ValsCatPerFieldTemp = cat(1, Info.(InfoFields{i1}){:});
            ValsCatPerFieldTemp = categorical(cellstr(ValsCatPerFieldTemp), 'Ordinal',true);
            [Vals4Fld{i1}{1}, ClassAss{i1}] = grp2idx(ValsCatPerFieldTemp);

        case 3
            Vals4Fld{i1} = cellfun(@(x) cat(1, x{:}), Info.(InfoFields{i1})(:,1), 'UniformOutput',false);
    end

    Qnts4Fld{i1} = cellfun(@(x) quantile(x, [0.25, 0.75]), Vals4Fld{i1}, 'UniformOutput',false);
    Lims4Fld{i1} = cellfun(@(x) quantile(x, [0, 1]), Vals4Fld{i1}, 'UniformOutput',false);
end

%% Figure initialization
ProgressBar.Message = 'Figure creation...';

PltLblF = cell(1, length(InfoFields));
for i1 = 1:length(PltLblF)
    if ParamType(i1) == 3
        PltLblF{i1} = cellstr(strcat(PltList{i1}, " ", ...
                                             repmat(TSChoice, 2, 1), string(Dys2Cumul),"d"));
    else
        PltLblF{i1} = PltList(i1);
    end
end

TimeIndep = length(PltList) - length(TmSnsParam);

if strcmp(PlotType, 'BoxPlot')
    fold_fig_curr = [fold_fig,sl,'Box Plots ',PlotArea,' (stats)'];
elseif strcmp(PlotType, 'CumulativeDistribution')
    fold_fig_curr = [fold_fig,sl,'Cumul Distr ',PlotArea,' (stats)'];
end

if not(exist(fold_fig_curr, 'dir'))
    mkdir(fold_fig_curr)
end

%% Plot section
for i1 = 1:length(PltOpts)
    if strcmp(PltFigTp, 'Unique Figure')
        if strcmp(PlotType, 'BoxPlot')
            CurrFln = ['Overall features box plots in ',PlotArea];
        elseif strcmp(PlotType, 'CumulativeDistribution')
            CurrFln = ['Overall features cumulative distributions in ',PlotArea];
        end
        GirdPlt = [4, 4];
        CurrFig = figure('Position',[80, 50, 600, 900], 'Visible','off', 'Name',CurrFln);
        PlotNum = 1:TimeIndep; % You can even rearrange the order!
    elseif strcmp(PltFigTp, 'Separate Figures')
        if strcmp(PlotType, 'BoxPlot')
            CurrFln = [PltList{PltOpts{i1}}, ' feature box plot in ',PlotArea];
        elseif strcmp(PlotType, 'CumulativeDistribution')
            CurrFln = [PltList{PltOpts{i1}}, ' feature cumulative distribution in ',PlotArea];
        end
        GirdPlt = [1, length(Vals4Fld{PltOpts{i1}})];
        CurrFig = figure(i1);
        set(CurrFig, 'Visible','off', 'Name',CurrFln)
        PlotNum = ones(1, length(PltList));
    end

    %% Figures creation
    CurrAxs = cell(1, numel(PltOpts{i1}));
    NumPlot = 1;
    for i2 = 1:numel(PltOpts{i1})
        for i3 = 1:length(Vals4Fld{PltOpts{i1}})
            Vals2Use = Vals4Fld{PltOpts{i1}}{i3};
            ValsDesc = {PltLblF{PltOpts{i1}}{i3}};
            Qnts2Use = Qnts4Fld{i1}{i3};

            CurrAxs{i2} = subplot(GirdPlt(1),GirdPlt(2),NumPlot, 'Parent',CurrFig);
            hold(CurrAxs{i2},'on');
    
            switch PlotType
                case 'BoxPlot'
                    boxplot(CurrAxs{i2}, Vals2Use, ValsDesc, ...
                                    'Notch','on', 'OutlierSize',4, 'Symbol',['.'; 'm']);

                    IQR        = Qnts2Use(2) - Qnts2Use(1);
                    UppFence = Qnts2Use(2) + 1.5*IQR;
                    LowFence = Qnts2Use(1) - 1.5*IQR;
    
                    xlim([0.75, 1.25])
                    ylim([0.98*LowFence, 1.05*UppFence])
                    pbaspect([1,1.5,1])
    
                case 'CumulativeDistribution'
                    cdfplot(Vals2Use);
                    xline(Qnts2Use(1), '--r', [num2str(round(Qnts2Use(1), 3)),' (1st quartile)'], ...
                                        'LabelVerticalAlignment','bottom', 'LabelHorizontalAlignment','left');
                    xline(Qnts2Use(2), '--r', [num2str(round(Qnts2Use(2), 3)),' (3rd quartile)'], ...
                                        'LabelVerticalAlignment','top', 'LabelHorizontalAlignment','right');
                    xlabel('Values')
                    ylabel('Cumulative frequency')
    
                    pbaspect([2,1,1])
            end
            
            if ShowTitle; title(Titles{NumPlot}, 'FontName',SlFont, 'FontSize',1.5*SlFnSz); end

            NumPlot = NumPlot + 1;
        end
    end

    %% Showing plot and saving...
    if ShowPlots
        set(CurrFig, 'Visible','on');
        pause
    end

    exportgraphics(CurrFig, [fold_fig_curr,sl,CurrFln,'.png'], 'Resolution',600);
    close(CurrFig)
end