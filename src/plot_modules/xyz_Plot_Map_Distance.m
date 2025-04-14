if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon','MunPolygon')
load([fold_var,sl,'GridCoordinates.mat'   ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'Distances.mat'         ], 'Distances')

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);
[InfoDetExst, InfoDet2Use] = load_info_detected(fold_var);

%% For scatter dimension
PixelScale = 0.35 * abs(yLatAll{1}(2,1) - yLatAll{1}(1,1)) / 6e-05;
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, FinScale=PixelScale);

%% Options
PltOpts = listdlg2({'Object to plot', 'Show plot'}, {Distances.Properties.VariableNames, {'Yes','No'}});
PltObjL = PltOpts{1};
if strcmp(PltOpts{2}, 'Yes'); ShowPlt = true; else; ShowPlt = false; end

LablPlt = inputdlg2({'Label for the object'}, 'DefInp',PltObjL);

%% Data extraction
ProgressBar.Message = 'Data extraction...';
xLonStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudy = cellfun(@(x,y) x(y), yLatAll , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('yLatAll')

DistStudy = cellfun(@(x,y) x(y), Distances{'Distances',PltObjL}{:}, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

PolygDist = Distances{'Objects',PltObjL}{:};

%% Plot
CurrFln = ['Distance from ',LablPlt{:}];
CurrFig = figure('Visible','off', 'Name',CurrFln);
CurrAxs = axes('Parent',CurrFig); 
hold(CurrAxs,'on');

for i1 = 1:numel(xLonStudy)
    fastscatter(xLonStudy{i1}(:), yLatStudy{i1}(:), DistStudy{i1}(:))
end

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',CurrAxs);
plot(MunPolygon      , 'FaceColor','none', 'LineWidth',1  , 'Parent',CurrAxs);
% plot(PolygDist       , 'FaceColor','none', 'LineWidth',.7 , 'Parent',CurrAxs);

fig_settings(fold0)

if InfoDetExst
    DetObjs = arrayfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDet2Use{:,5}, InfoDet2Use{:,6});
    uistack(DetObjs,'top')
end

if exist('LegPos', 'var')
    if InfoDetExst
        LegObjs = {DetObjs(1)};
        LegCaps = {"Points Analyzed"};
    end

    CurrLeg = legend(CurrAxs, ...
                     [LegObjs{:}], LegCaps, 'AutoUpdate','off', ...
                                            'NumColumns',2, ...
                                            'FontName',SlFont, ...
                                            'FontSize',SlFnSz, ...
                                            'Location',LegPos, ...
                                            'Box','off');

    CurrLeg.ItemTokenSize(1) = 5;

    fig_rescaler(CurrFig, CurrLeg, LegPos)
end

set(CurrAxs, 'Visible','off')

colormap(CurrAxs, flipud(colormap('turbo')))
% colormap(CurrAxs,'pink')

LimsCol = linspace(min(cellfun(@(x) min(x, [], 'all'), DistStudy)), ...
                   max(cellfun(@(x) max(x, [], 'all'), DistStudy)), 5);
LimsCol = round(LimsCol, 2, 'significant'); % CHECK FOR LEGEND THAT IS CUTTED AND WITH 3 DECIMAL NUMBERS, WHEN 0 IS PRESENT
clim([LimsCol(1), LimsCol(end)])
ColBar = colorbar('Location','westoutside', 'Ticks',LimsCol, 'TickLabels',string(LimsCol), 'FontSize',SlFnSz*.8);
ColBarPos = get(ColBar,'Position');
ColBarPos(1) = ColBarPos(1)-.05;
ColBarPos(3) = ColBarPos(3)*.5;
set(ColBar, 'Position',ColBarPos)
title(ColBar, 'Dist. [m]', 'FontName',SlFont, 'FontSize',SlFnSz)

%% Export
exportgraphics(CurrFig, [fold_fig,sl,CurrFln,'.png'], 'Resolution',600);

% Show Fig
if ShowPlt
    set(CurrFig, 'Visible','on');
else
    close(CurrFig)
end