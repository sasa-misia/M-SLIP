if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data
sl = filesep;

load([fold_var,sl,'HRUs.mat'           ], 'CombAll','HRUsAll','InfoLegLandUse','InfoLegSlope','InfoLegSoil')
load([fold_var,sl,'GridCoordinates.mat'], 'xLongAll','yLatAll')
load([fold_var,sl,'DatasetStudy.mat'   ], 'StablePolygons','UnstablePolygons')

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

%% Calculating indices of points inside polygons
if length(UnstablePolygons) > 1; UnstablePolygons = union(UnstablePolygons); end
[pp1, ee1] = getnan2([UnstablePolygons.Vertices; nan, nan]);
IndOfUnstabPoints = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp1,ee1)), xLongAll, yLatAll, 'UniformOutput',false);

if length(StablePolygons) > 1; StablePolygons = union(StablePolygons); end
[pp2, ee2] = getnan2([StablePolygons.Vertices; nan, nan]);
IndOfStabPoints   = cellfun(@(x,y) find(inpoly([x(:),y(:)], pp2,ee2)), xLongAll, yLatAll, 'UniformOutput',false);

%% Extraction of HRUs
HRUsOfUnstabPoints = cellfun(@(x,y) x(y), HRUsAll, IndOfUnstabPoints, 'UniformOutput',false);
HRUsOfStabPoints   = cellfun(@(x,y) x(y), HRUsAll, IndOfStabPoints,   'UniformOutput',false);

HRUsOfUnstabPointsCat = cat(1, HRUsOfUnstabPoints{:});
HRUsOfStabPointsCat   = cat(1, HRUsOfStabPoints{:});

[HRUsCount{1}, HRUsClasses{1}] = histcounts(categorical(HRUsOfUnstabPointsCat));
[HRUsCount{2}, HRUsClasses{2}] = histcounts(categorical(HRUsOfStabPointsCat));

RelFrequenciesHRUs    = cellfun(@(x) x/sum(x)*100    , HRUsCount, 'UniformOutput',false);
ConsistencyFactorHRUs = cellfun(@(x) sum(x)/length(x), HRUsCount, 'UniformOutput',false); % The more is higher, the more points are not casual (more points are in the same class, instead 1 means that there is a num of classes equal to num of points)

%% Extraction of Combinations
CombsOfUnstabPoints = cellfun(@(x,y) x(y), CombAll, IndOfUnstabPoints, 'UniformOutput',false);
CombsOfStabPoints   = cellfun(@(x,y) x(y), CombAll, IndOfStabPoints,   'UniformOutput',false);

CombsOfUnstabPointsCat = cat(1, CombsOfUnstabPoints{:});
CombsOfStabPointsCat   = cat(1, CombsOfStabPoints{:});

[CombsCount{1}, CombsClasses{1}] = histcounts(categorical(CombsOfUnstabPointsCat));
[CombsCount{2}, CombsClasses{2}] = histcounts(categorical(CombsOfStabPointsCat));

RelFrequenciesCombs    = cellfun(@(x) x/sum(x)*100    , CombsCount, 'UniformOutput',false);
ConsistencyFactorCombs = cellfun(@(x) sum(x)/length(x), CombsCount, 'UniformOutput',false); % The more is higher, the more points are not casual

%% Plot (preliminary operations)
Options  = {'HRUs', 'Combinations'};
InfoType = uiconfirm(Fig, 'What information do you want to plot?', ...
                          'HRUs', 'Options',Options);

Options  = {'Yes', 'No'};
HideLows = uiconfirm(Fig, 'Do you want to hide low frequencies?', ...
                          'Low frequencies', 'Options',Options);

switch InfoType
    case 'HRUs'
        ClassesToUse = HRUsClasses;
        ClassesCount = HRUsCount;
        ClassesFreqs = RelFrequenciesHRUs;
        ConsistToUse = ConsistencyFactorHRUs;

    case 'Combinations'
        ClassesToUse = CombsClasses;
        ClassesCount = CombsCount;
        ClassesFreqs = RelFrequenciesCombs;
        ConsistToUse = ConsistencyFactorCombs;
end

if strcmp(HideLows, 'Yes')
    FreqThr = str2double(inputdlg({'Choose the frequency threshold above which plot bars [0 to 100]: '}, '', 1, {'2.5'}));
    IndOfClassesToMantain = cellfun(@(x) find(x >= FreqThr), ClassesFreqs, 'UniformOutput',false);

    ClassesToUse = cellfun(@(x,y) x(y), ClassesToUse, IndOfClassesToMantain, 'UniformOutput',false);
    ClassesCount = cellfun(@(x,y) x(y), ClassesCount, IndOfClassesToMantain, 'UniformOutput',false);
    ClassesFreqs = cellfun(@(x,y) x(y), ClassesFreqs, IndOfClassesToMantain, 'UniformOutput',false);
end

%% Plot of bar charts
PlotArea = {'Unstable area', 'Stable area'};
for i1 = 1:length(PlotArea)
    filename = [InfoType,' statistics (',PlotArea{i1},')'];
    curr_fig = figure(i1);
    ax_curr  = axes(curr_fig, 'FontName',SlFont, 'FontSize',SlFnSz);
    set(curr_fig, 'visible','on')
    set(curr_fig, 'Name',filename);
    
    ReplacedText = string(strrep(ClassesToUse{i1}, '_', '-')); % If you mantain _ you will have some letters as subscript
    ClassesNames = categorical(ReplacedText);
    ClassesNames = reordercats(ClassesNames, ReplacedText);
    
    BarPlot = bar(ax_curr, ClassesNames, ClassesCount{i1});
    
    xBarPos = BarPlot(1).XEndPoints;
    yBarPos = BarPlot(1).YEndPoints;
    BarLbls = strcat(num2str(round(ClassesFreqs{i1}', 1)), '%');
    text(xBarPos, yBarPos, BarLbls, 'HorizontalAlignment','center', 'VerticalAlignment','bottom', ...
                                    'FontName',SlFont, 'FontSize',0.9*SlFnSz)
    
    if strcmp(HideLows, 'Yes')
        xLabText = ['Name of ',InfoType,' (only classes with freq >= ', num2str(FreqThr), '%)'];
    else
        xLabText = ['Name of ',InfoType];
    end

    xlabel(xLabText          , 'FontName',SlFont, 'FontSize',1.2*SlFnSz)
    ylabel('Num of cells [-]', 'FontName',SlFont, 'FontSize',1.2*SlFnSz)

    ylim([0, 1.2*max(ClassesCount{i1})])

    xtickangle(ax_curr, 90)
    
    pbaspect([3.5, 1, 1])
    
    title(    ['Bar plot of ',InfoType,' in ',PlotArea{i1}]    , 'FontName',SlFont, 'FontSize',1.5*SlFnSz )
    subtitle( ['Consistency Index: ',num2str(ConsistToUse{i1})], 'FontName',SlFont, 'FontSize',SlFnSz     )

    exportgraphics(curr_fig, [fold_fig,filesep,filename,'.png'], 'Resolution',600);
end

%% Plot of tables
ColumnNames = {'Class Name', 'Attribute'};

TabLandUse = array2table(InfoLegLandUse', 'VariableNames',ColumnNames);
TabSlope   = array2table(InfoLegSlope'  , 'VariableNames',ColumnNames);
TabSoil    = array2table(InfoLegSoil'   , 'VariableNames',ColumnNames);

FigTblLandUse = uifigure('Name','Tab Parameters', 'WindowStyle','modal', 'Color',[0.97, 0.73, 0.58]);
FigTblSlope   = uifigure('Name','Tab Parameters', 'WindowStyle','modal', 'Color',[0.97, 0.73, 0.58]);
FigTblSoil    = uifigure('Name','Tab Parameters', 'WindowStyle','modal', 'Color',[0.97, 0.73, 0.58]);

TblLandUseCnt = uitable(FigTblLandUse, 'Data',TabLandUse, 'Units','normalized', 'Position',[0.01 0.01 0.98 0.98]);
TblSlopeCnt   = uitable(FigTblSlope  , 'Data',TabSlope  , 'Units','normalized', 'Position',[0.01 0.01 0.98 0.98]);
TblSoilCnt    = uitable(FigTblSoil   , 'Data',TabSoil   , 'Units','normalized', 'Position',[0.01 0.01 0.98 0.98]);

writetable([fold_fig,sl,TabLandUse], 'LegendLandUse.txt')
writetable([fold_fig,sl,TabSlope  ], 'LegendSlope.txt')
writetable([fold_fig,sl,TabSoil   ], 'LegendSoil.txt')