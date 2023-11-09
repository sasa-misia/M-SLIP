%% File loading
cd(fold_var)
load('UserStudyArea_Answers.mat')
load('StudyAreaVariables.mat')

OrthophotoAnswer = 0;
if exist("Orthophoto.mat", 'file')
    load("Orthophoto.mat")
    OrthophotoAnswer = 1;
end

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'best';
end

InfoDetectedExist = false;
if exist('InfoDetectedSoilSlips.mat', 'file')
    load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetectedExist = true;
end

cd(fold0)

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'RefArea',.035, 'Extremes',true);

%% Loading Excel
MunColors = zeros(length(MunPolygon),3);
% Fig = uifigure; % Remember to comment if in App version
Options = {'Yes, thanks', 'No, manually'};
AssignRndColors = uiconfirm(Fig, 'Do you want to assign random RGB triplets?', ...
                                 'Window type', 'Options',Options);
switch AssignRndColors
    case 'Yes, thanks'
        MunColors = rand(length(MunPolygon),3);
    case 'No, manually'
        for i1 = 1:length(MunPolygon)
            MunColors(i1,:) = uisetcolor(strcat("Select a color for municipality n. ",string(i1)));
        end
end

%% Plot of study area
Filename1 = 'Municipalities';
fig_mun = figure(1);
ax_ind1 = axes(fig_mun);
hold(ax_ind1,'on')

set(gcf, 'Name',Filename1);

PolygonsPlot = cell(1, size(MunPolygon,2));
for i1 = 1:size(MunPolygon,2)
    PolygonsPlot{i1} = plot(MunPolygon(i1), 'FaceColor',MunColors(i1,:), 'FaceAlpha',1);
end

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)

fig_settings(fold0)

if InfoDetectedExist
    hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
    uistack(hdetected,'top')
end

if exist('LegendPosition', 'var')
    LegendObjects = PolygonsPlot;
    LegendCaption = MunSel;

    if InfoDetectedExist
        LegendObjects = [LegendObjects, {hdetected(1)}];
        LegendCaption = [LegendCaption; {"Points Analyzed"}];
    end

    hleg1 = legend([LegendObjects{:}], LegendCaption, ...
                   'FontName',SelectedFont, ...
                   'FontSize',SelectedFontSize, ...
                   'Location',LegendPosition, ...
                   'NumColumns',2, ...
                   'Box','off');
    
    hleg1.ItemTokenSize(1) = 3;
    
    legend('AutoUpdate','off')

    fig_rescaler(fig_mun, hleg1, LegendPosition)
end

% [xMunTxt yMunTxt] = centroid(MunPolygon);
% for i1 = 1:length(xMunTxt)
%     text(xMunTxt(i1),yMunTxt(i1), MunSel{i1}, 'HorizontalAlignment','center', ...
%         'VerticalAlignment','middle', 'FontName',SelectedFont, 'FontSize',SelectedFontSize/1.2)
% end

set(gca, 'visible','off')

%% Export png
cd(fold_fig)
exportgraphics(fig_mun, strcat(Filename1,'.png'), 'Resolution',600);
cd(fold0)