% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% File loading
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon','MaxExtremes','MinExtremes')
load([fold_var,sl,'UserMorph_Answers.mat'],  'NewDx')
load([fold_var,sl,'DatasetStudy.mat'],       'DatasetStudyCoords')

OrthophotoAnswer = 0;
if exist([fold_var,sl,'Orthophoto.mat'], 'file')
    load([fold_var,sl,'Orthophoto.mat'])
    OrthophotoAnswer = 1;
end

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'])
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'best';
end

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
load([fold_res_ml_curr,sl,'PredictionsStudy.mat'],  'PredictionProbabilities','LandslidesPolygons', ...
                                                    'EventsInfo','EventsMSE','EventsAUC','EventsBT')
load([fold_res_ml_curr,sl,'TrainedANNs.mat'],       'ANNs','ANNsPerf')

%% Options
Options   = {'Yes', 'No'};
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',Options, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

DatetimesPredicted = [EventsInfo{'PredictionDate',:}{:}];
if length(DatetimesPredicted) == 1
    DatetimeChosed = DatetimesPredicted;
    EventNameChosed = EventsInfo.Properties.VariableNames;
else
    IndDate = listdlg('PromptString',{'Choose the date you want to plot: ',''}, ...
                      'ListString',DatetimesPredicted, 'SelectionMode','single');

    DatetimeChosed  = DatetimesPredicted(IndDate);
    EventNameChosed = EventsInfo.Properties.VariableNames(IndDate);
end

Options  = {'Yes', 'No'};
BestMdls = uiconfirm(Fig, ['You have ',num2str(size(ANNs,2)),' models. ' ...
                           'Do you want to reduce num of plots based on MSE?'], ...
                          'Plot all models', 'Options',Options, 'DefaultOption',2);
if strcmp(BestMdls,'Yes'); BestMdls = true; else; BestMdls = false; end

if BestMdls
    TestMSE = ANNsPerf{'Err','Test'}{:}{'MSE',:};
    MaxLoss = str2double(inputdlg({["Choose the max MSE for models to plot : "
                                    strcat("Max MSE is ",string(max(TestMSE))," and min is ",string(min(TestMSE)))]}, ...
                                    '', 1, {num2str(min(TestMSE)*5)}));
    GoodMdl = TestMSE <= MaxLoss;
else
    GoodMdl = true(size(TestMSE));
end

IndModels = listdlg('PromptString',{'Choose models you want to plot (eventually filtered with MSE): ',''}, ...
                    'ListString',PredictionProbabilities.Properties.VariableNames, 'SelectionMode','multiple');

TransparencyValues = inputdlg({'Indicate transparency of background (from 0 to 1):'
                               'Indicate transparency of top layer (from 0 to 1):'},'', ...
                               1, {'0.35', '0.8'});

BTrans = eval(TransparencyValues{1});
TTrans = eval(TransparencyValues{2});

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'RefArea',.035, 'Extremes',true);

%% New grid
GridApproach = 'Meters';
switch GridApproach
    case 'Meters'
        GridSize = NewDx; % In meters
        yLatMean = (MaxExtremes(2)+MinExtremes(2))/2;
        
        dLat  = rad2deg(GridSize/earthRadius); % 1 m in lat
        dLong = rad2deg(acos( (cos(GridSize/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long
        
        yRows = MaxExtremes(2) : -dLat : MinExtremes(2);
        xCols = MinExtremes(1) : dLong : MaxExtremes(1);

    case 'Pixels' % To finish!!!!
        PixelInHeight = 1500;

        RatioFig = MaxExtremes(2) - MinExtremes(2); % Continue from here (also this line)
        xCols = MinExtremes(1) : dLong : MaxExtremes(1);
end

[xLongsNew, yLatsNew] = meshgrid(xCols, yRows);

ProbsGrid = zeros(size(xLongsNew));

[pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
IndsInStudy = inpoly([xLongsNew(:), yLatsNew(:)], pp1, ee1);

%% Plot
[~, AnalysisFoldName] = fileparts(fold_res_ml_curr);
fold_fig_curr = [fold_fig,sl,'Risk maps',sl,AnalysisFoldName];

if ~exist(fold_fig_curr, 'dir')
    mkdir(fold_fig_curr)
end

LandslideDay     = LandslidesPolygons{EventNameChosed, 'LandslideDay'}{:};
UnstablePolygons = LandslidesPolygons{EventNameChosed, 'UnstablePolygons'}{:};
StablePolygons   = LandslidesPolygons{EventNameChosed, 'StablePolygons'}{:};
if length(UnstablePolygons) > 1
    UnstablePolygons = union(UnstablePolygons);
end
if length(StablePolygons) > 1
    StablePolygons = union(StablePolygons);
end

StableColor   = '#7FFF00';
if LandslideDay
    UnstableColor   = '#CC5500';
else
    UnstableColor = StableColor;
end

for i1 = IndModels
    ProgressBar.Message = ['Plotting fig. ',num2str(i1)];

    if isempty(PredictionProbabilities{EventNameChosed, i1}{:}) || not(GoodMdl(i1))
        continue % To skip the cycle in case there are no predictions
    end

    fig_curr = figure(i1);
    ax_curr  = axes(fig_curr);
    set(fig_curr, 'visible','off')
    hold(ax_curr,'on')

    EventString   = strrep(char(DatetimeChosed), '/', ' ');
    EventString   = strrep(EventString, ':', ' ');
    filename_curr = ['Risk map - ',EventString,' - ANN Model n',num2str(i1)];

    CurrentMSE  = EventsMSE{EventNameChosed,i1};
    CurrentAUC  = EventsAUC{EventNameChosed,i1};
    LayerStruct = ANNs{'Model',i1}{:}.LayerSizes;

    ProbsScatter = full(PredictionProbabilities{EventNameChosed, i1}{:});

    ProbsFun = scatteredInterpolant(DatasetStudyCoords.Longitude, ...
                                    DatasetStudyCoords.Latitude, ...
                                    ProbsScatter, 'natural');

    ProbsGrid(:) = min(max(ProbsFun(xLongsNew(:), yLatsNew(:)), 0), 1);

    ProbsGrid(not(IndsInStudy)) = 0;

    imagesc(ax_curr, xLongsNew(:), yLatsNew(:), ProbsGrid, 'AlphaData',TTrans)

    % scatter(DatasetStudyCoords.Longitude, DatasetStudyCoords.Latitude, PixelSize, ...
    %         ProbsToUse, 'Filled', 'Marker','s', 'Parent',ax_curr, 'MarkerFaceAlpha',TTrans, 'MarkerEdgeColor','none');

    ColBarLims  = [0, 1];
    TicksValues = [0, 0.2, 0.5, 0.8, 1];
    TicksLabels = ["Low risk", ...
                   "Medium-low risk", ...
                   "Medium risk", ...
                   "High risk", ...
                   "Very high risk"      ];

    colormap(ax_curr, flipud(pink))

    clim(ColBarLims);
    colorbar('Location','eastoutside', 'Ticks',TicksValues, 'TickLabels',TicksLabels);

    plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',ax_curr)

    plot(UnstablePolygons, 'FaceColor',UnstableColor, 'FaceAlpha',BTrans, 'LineWidth',2*PixelSize, 'Parent',ax_curr)
    plot(StablePolygons,   'FaceColor',StableColor,   'FaceAlpha',BTrans, 'LineWidth',2*PixelSize, 'Parent',ax_curr)

    fig_settings(fold0)

    title('Risk map', 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize)
    subtitle(['Event MSE: ',num2str(CurrentMSE),'; Event AUC: ',num2str(CurrentAUC),'; ANN Struct: [',strjoin({num2str(LayerStruct)}),']'], ...
              'FontName',SelectedFont, 'FontSize',SelectedFontSize)

    axis off
    % set(findall(ax_curr, 'type', 'text'), 'visible', 'on') % To show again titles

    % Showing plot and saving...
    if ShowPlots
        set(fig_curr, 'visible','on');
        pause
    end

    exportgraphics(fig_curr, [fold_fig_curr,sl,filename_curr,'.png'], 'Resolution',1200);
    close(fig_curr)
end