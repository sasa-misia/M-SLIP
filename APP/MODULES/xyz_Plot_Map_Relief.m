% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Reading files...', 'Cancelable','off', ...
                                 'Indeterminate','on');
drawnow

%% File loading
load([fold_var,sl,'StudyAreaVariables.mat'],   'StudyAreaPolygon')
load([fold_var,sl,'GridCoordinates.mat'],      'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll','OriginallyProjected','SameCRSForAll')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'])
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'Best';
end

InfoDetectedExist = false;
if exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetectedExist = true;
end

%% For scatter dimension
RefStudyArea = 0.0417;
ExtentStudyArea = area(StudyAreaPolygon);
% ExtentStudyArea = prod(MaxExtremes-MinExtremes);
RatioRef = ExtentStudyArea/RefStudyArea;
PixelSize = .028/RatioRef;
DetPixelSize = 20*PixelSize;

%% Merge DTMs
ProgressBar.Message = "Merging DTMs...";

if OriginallyProjected && SameCRSForAll
    load([fold_var,sl,'MorphologyParameters.mat'], 'OriginalProjCRS')

    ProjCRS = OriginalProjCRS;
else
    EPSG = str2double(inputdlg({["Set DTM EPSG (to calculate flow)"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
    ProjCRS = projcrs(EPSG);
end

[xPlanAll, yPlanAll, dx, dy] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    [xPlanAll{i1}, yPlanAll{i1}] = projfwd(ProjCRS, yLatAll{i1}, xLongAll{i1});

    dx{i1} = abs(xPlanAll{i1}(ceil(end/2),2)-xPlanAll{i1}(ceil(end/2),1));
    dy{i1} = abs(yPlanAll{i1}(1,ceil(end/2))-yPlanAll{i1}(2,ceil(end/2)));
end

dxMean   = mean([dx{:}]);
dyMean   = mean([dy{:}]);

xPlanMin = min(cellfun(@(x) min(x, [], 'all'), xPlanAll));
xPlanMax = max(cellfun(@(x) max(x, [], 'all'), xPlanAll));
yPlanMin = min(cellfun(@(x) min(x, [], 'all'), yPlanAll));
yPlanMax = max(cellfun(@(x) max(x, [], 'all'), yPlanAll));
[xPlanMerged, yPlanMerged] = meshgrid(xPlanMin:dxMean:xPlanMax, yPlanMax:-dyMean:yPlanMin);

xPlanAllCat = cellfun(@(x) x(:), xPlanAll, 'UniformOutput',false);
xPlanAllCat = cat(1, xPlanAllCat{:});
yPlanAllCat = cellfun(@(x) x(:), yPlanAll, 'UniformOutput',false);
yPlanAllCat = cat(1, yPlanAllCat{:});
ElevAllCat  = cellfun(@(x) x(:), ElevationAll, 'UniformOutput',false);
ElevAllCat  = cat(1, ElevAllCat{:});

ElevInterpModel = scatteredInterpolant(xPlanAllCat, yPlanAllCat, double(ElevAllCat), 'nearest');

ElevationMerged    = zeros(size(xPlanMerged));
ElevationMerged(:) = ElevInterpModel(xPlanMerged(:), yPlanMerged(:));

%% Elaboration of relief shaded plot
ProgressBar.Message = "Processing of shaded colors...";

Temp = dem(mean(xPlanMerged, 1), mean(yPlanMerged, 2), ElevationMerged, 'Azimuth',-30, ...
                                                                        'Contrast',1, 'Lake', ...
                                                                        'NoDecim', 'noplot');

ShdColorsMerged = Temp.rgb;
clear('Temp')

IndColorsMdl = scatteredInterpolant(xPlanMerged(:), yPlanMerged(:), (1:numel(xPlanMerged))', 'nearest'); % You could also use directly ShdColorsMerged but in this way you will have consistency (waiting a little bit ;) )

RedTemp   = ShdColorsMerged(:,:,1);
GreenTemp = ShdColorsMerged(:,:,2);
BlueTemp  = ShdColorsMerged(:,:,3);

[ShdColorsAll, RedColAll, GreenColAll, BlueColAll] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    IdxToUse = IndColorsMdl(xPlanAll{i1}(:), yPlanAll{i1}(:));

    ShdColorsAll{i1}    = zeros(size(xLongAll{i1}, 1), size(xLongAll{i1}, 2), 3);
    ShdColorsAll{i1}(:) = [RedTemp(IdxToUse); GreenTemp(IdxToUse); BlueTemp(IdxToUse)]; % It is not necessary but for plot is more representative than ContributingArea

    RedColAll{i1}   = ShdColorsAll{i1}(:,:,1);
    GreenColAll{i1} = ShdColorsAll{i1}(:,:,2);
    BlueColAll{i1}  = ShdColorsAll{i1}(:,:,3);
end

%% Data extraction
ProgressBar.Message = "Extraction of data in Study Area...";

xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudy = cellfun(@(x,y) x(y), yLatAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('yLatAll')

ShdColorsStudy = cellfun(@(x,y,z,i) [x(i), y(i), z(i)], RedColAll, GreenColAll, BlueColAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('RedColAll', 'GreenColAll', 'BlueColAll', 'ShdColorsAll')

%% Concatenation of values
xLongStudyCat     = cat(1, xLongStudy{:});
yLatStudyCat      = cat(1, yLatStudy{:});
ShdColorsStudyCat = cat(1, ShdColorsStudy{:});

%% Plot
ProgressBar.Message = "Plotting...";

filename1 = 'Hillshade';
curr_fig = figure('Visible','off');
curr_ax  = axes('Parent',curr_fig); 
hold(curr_ax,'on'); 

set(gcf, 'Name',filename1); 

hShd = scatter(xLongStudyCat, yLatStudyCat, PixelSize, ...
                    ShdColorsStudyCat, 'Filled', 'Marker','s', 'Parent',curr_ax);

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',curr_ax)

fig_settings(fold0)

if InfoDetectedExist
    hDet = cellfun(@(x,y) scatter(x, y, DetPixelSize, 'MarkerFaceColor','#A2142F', ...
                                                      'Marker','o', 'MarkerEdgeColor','flat', ...
                                                      'Parent',curr_ax), ...
                                      InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
    uistack(hDet,'top')
end

if exist('LegendPosition', 'var')
    LegendObjects = {};
    LegendCaption = {};

    if InfoDetectedExist
        LegendObjects = [LegendObjects; {hDet(1)}];
        LegendCaption = [LegendCaption; {"Points Analyzed"}];
    end

    hLeg = legend([LegendObjects{:}], ...
                   LegendCaption, ...
                  'NumColumns',2, ...
                  'FontName',SelectedFont, ...
                  'FontSize',SelectedFontSize, ...
                  'Location',LegendPosition, ...
                  'Box','off');
    
    legend('AutoUpdate','off');
    hLeg.ItemTokenSize(1) = 5;
    
    % title(hLeg, 'Elevation [m]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

    fig_rescaler(curr_fig, hLeg, LegendPosition)

end

set(gca, 'visible','off')

ProgressBar.Message = "Saving...";

exportgraphics(curr_fig, [fold_fig,sl,filename1,'.png'], 'Resolution',600);

close(curr_fig)