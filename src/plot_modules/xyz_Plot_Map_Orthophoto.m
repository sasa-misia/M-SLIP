if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Reading files...', 'Cancelable','off', ...
                                 'Indeterminate','on');
drawnow

%% File loading
sl = filesep;
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon')
load([fold_var,sl,'Orthophoto.mat'        ], 'OrthoRGB','ZOrtho','xLongOrtho', ...
                                             'yLatOrtho','IndOrthoInStudyArea')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SlFont   = Font;
    SlFnSz = FontSize;
    if exist('LegendPosition', 'var'); LegPos = LegendPosition; end
else
    SlFont = 'Calibri';
    SlFnSz = 8;
    LegPos = 'Best';
end

InfoDetExst = false;
if exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDet2Use = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetExst = true;
end

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon);

%% Options
ProgressBar.Message = 'Options...';
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

%% Data extraction
ProgressBar.Message = 'Data extraction...';

OrtColAll = cell(size(ZOrtho));
for i1 = 1:length(OrtColAll)
    [RedTemp, GreenTemp, BlueTemp]     = deal(ones(numel(xLongOrtho{i1}), 1)); % This means that they start as white pixels.
    RedTemp(IndOrthoInStudyArea{i1})   = OrthoRGB{i1}(IndOrthoInStudyArea{i1}, 1)./255;
    GreenTemp(IndOrthoInStudyArea{i1}) = OrthoRGB{i1}(IndOrthoInStudyArea{i1}, 2)./255;
    BlueTemp(IndOrthoInStudyArea{i1})  = OrthoRGB{i1}(IndOrthoInStudyArea{i1}, 3)./255;

    OrtColAll{i1}    = zeros(size(xLongOrtho{i1}, 1), size(xLongOrtho{i1}, 2), 3); % This means that they start as black pixels -> check if an area is black outside StudyArea (error).
    OrtColAll{i1}(:) = [RedTemp; GreenTemp; BlueTemp];
end

%% Plot
ProgressBar.Message = 'Plotting...';

filename1 = 'Orthophoto';
curr_fig  = figure('Visible','off');
curr_ax   = axes('Parent',curr_fig); 
hold(curr_ax,'on'); 

set(curr_fig, 'Name',filename1);

for i1 = 1:length(xLongOrtho)
    imagesc(curr_ax, xLongOrtho{i1}(:), yLatOrtho{i1}(:), OrtColAll{i1});
end

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',curr_ax)

fig_settings(fold0)

if InfoDetExst
    hdetected = arrayfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfDet2Use{:,5}, InfDet2Use{:,6});
    uistack(hdetected,'top')
end

if exist('LegPos', 'var')
    LegendObjects = {};
    LegendCaption = {};

    if InfoDetExst
        LegendObjects = [LegendObjects; {hdetected(1)}];
        LegendCaption = [LegendCaption; {"Points Analyzed"}];

        hleg3 = legend([LegendObjects{:}], ...
                        LegendCaption, ...
                       'NumColumns',2, ...
                       'FontName',SlFont, ...
                       'FontSize',SlFnSz, ...
                       'Location',LegPos, ...
                       'Box','off');
        
        legend('AutoUpdate','off');
        hleg3.ItemTokenSize(1) = 5;
    
        fig_rescaler(curr_fig, hleg3, LegPos)
    end
end

set(curr_ax, 'visible','off')

%% Saving
ProgressBar.Message = 'Saving...';

exportgraphics(curr_fig, [fold_fig,sl,filename1,'.png'], 'Resolution',600);

%% Show Fig
if ShowPlots
    set(curr_fig, 'visible','on');
else
    close(curr_fig)
end