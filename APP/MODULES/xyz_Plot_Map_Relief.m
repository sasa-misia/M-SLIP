if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Reading files...', 'Cancelable','off', ...
                                 'Indeterminate','on');
drawnow

%% File loading
load([fold_var,sl,'StudyAreaVariables.mat'],   'StudyAreaPolygon','MunPolygon')
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
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon);

%% Options
PltGrayIm = uiconfirm(Fig, 'Do you want to plot relief in gray?', ...
                           'Gray plot', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(PltGrayIm,'Yes'); PltGrayIm = true; else; PltGrayIm = false; end

ShowMunis = uiconfirm(Fig, 'Do you want to show municipalities?', ...
                           'Municipalities', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowMunis,'Yes'); ShowMunis = true; else; ShowMunis = false; end

ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

%% Merge DTMs
ProgressBar.Message = "Merging DTMs...";

if OriginallyProjected && SameCRSForAll
    load([fold_var,sl,'MorphologyParameters.mat'], 'OriginalProjCRS')

    ProjCRS = OriginalProjCRS;
else
    EPSG = str2double(inputdlg2({'Set DTM EPSG (Sicily -> 32633, Emilia Romagna -> 25832)'}, 'DefInp',{'25832'}));
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

RedTemp   = ShdColorsMerged(:,:,1);
GreenTemp = ShdColorsMerged(:,:,2);
BlueTemp  = ShdColorsMerged(:,:,3);

IndColorsMdl = scatteredInterpolant(xPlanMerged(:), yPlanMerged(:), (1:numel(xPlanMerged))', 'nearest'); % You could also use directly ShdColorsMerged but in this way you will have consistency (waiting a little bit ;) )

[yLatMerged, xLongMerged] = projinv(ProjCRS, xPlanMerged, yPlanMerged);

[pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
IndPointsInSA = inpoly([xLongMerged(:), yLatMerged(:)], pp1, ee1);

RedTemp(not(IndPointsInSA))   = 1;
GreenTemp(not(IndPointsInSA)) = 1;
BlueTemp(not(IndPointsInSA))  = 1;

ShdColorsMerged(:,:,1) = RedTemp;
ShdColorsMerged(:,:,2) = GreenTemp;
ShdColorsMerged(:,:,3) = BlueTemp;

ShdColorsAll = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    IdxToUse = IndColorsMdl(xPlanAll{i1}(:), yPlanAll{i1}(:));

    ShdColorsAll{i1}    = zeros(size(xLongAll{i1}, 1), size(xLongAll{i1}, 2), 3);
    ShdColorsAll{i1}(:) = [RedTemp(IdxToUse); GreenTemp(IdxToUse); BlueTemp(IdxToUse)];
    if PltGrayIm
        ShdColorsAll{i1} = repmat(rgb2gray(ShdColorsAll{i1}), 1, 1, 3);
    end
end

%% Plot
ProgressBar.Message = "Plotting...";

filename1 = 'Hillshade';
curr_fig  = figure('Visible','off');
curr_ax   = axes('Parent',curr_fig); 
hold(curr_ax,'on');

if PltGrayIm
    filename1 = [filename1,'BW'];
end

set(curr_fig, 'Name',filename1);

for i1 = 1:length(xLongAll)
    imagesc(curr_ax, xLongAll{i1}(:), yLatAll{i1}(:), ShdColorsAll{i1});
end

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',curr_ax)
if ShowMunis
    plot(MunPolygon, 'FaceColor','none', 'LineWidth',1, 'Parent',curr_ax)
end

fig_settings(fold0)

if InfoDetectedExist
    hDet = cellfun(@(x,y) scatter(x, y, DetPixelSize, 'MarkerFaceColor','#A2142F', ...
                                                      'Marker','o', 'MarkerEdgeColor','#A2142F', ...
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
    
    title(hLeg, 'Hillshade plot', 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

    fig_rescaler(curr_fig, hLeg, LegendPosition)

end

set(curr_ax, 'visible','off')

if ShowPlots
    set(curr_fig, 'visible','on');
    pause
end

%% Saving
ProgressBar.Message = "Saving...";

exportgraphics(curr_fig, [fold_fig,sl,filename1,'.png'], 'Resolution',600);

close(curr_fig)