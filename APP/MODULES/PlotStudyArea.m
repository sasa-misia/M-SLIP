cd(fold_var)
load('UserA_Answers.mat');
load('StudyAreaVariables.mat');
cd(fold0)

RefStudyArea = 0.035;
% ExtentStudyArea = area(StudyAreaPolygon);
ExtentStudyArea = prod(MaxExtremes-MinExtremes);
RatioRef = ExtentStudyArea/RefStudyArea;

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
end

MunColors = zeros(length(MunPolygon),3);
Answer = questdlg('Do you want to assign random RGB triplets?', 'Colors', ...
            	  'Yes, thanks','No, manually','Yes, thanks');
switch Answer
    case 'Yes, thanks'
        MunColors = rand(length(MunPolygon),3);
    case 'No, manually'
        for i1 = 1:length(MunPolygon)
            MunColors(i1,:) = uisetcolor(strcat("Select a color for municipality n. ",string(i1)));
        end
end

%%
Filename1 = 'Municipalities';
F1 = figure(1);
set(F1, ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits','centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition',[0 1 30 12],...
    'InvertHardcopy','off');
set(gcf, 'Name',Filename1);

PolygonsPlot = cell(1, size(MunPolygon,2));
for i1 = 1:size(MunPolygon,2)
    PolygonsPlot{i1} = plot(MunPolygon(i1), 'FaceColor',MunColors(i1,:), 'FaceAlpha',1);
    hold on
end

plot(StudyAreaPolygon,'FaceColor','none')
hold on
fig_settings(fold0)

cd(fold_var)
InfoDetectedExist = false;
if exist('InfoDetectedSoilSlips.mat', 'file')
    load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips')
    hdetected = cellfun(@(x,y) scatter(x, y, 5*RatioRef, '^k','Filled'), InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
    uistack(hdetected,'top')
    InfoDetectedExist = true;
end

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat', 'LegendPosition')
else
    LegendPosition = 'best';
end

LegendObjects = PolygonsPlot;
LegendCaption = MunSel;
if InfoDetectedExist
    LegendObjects = [LegendObjects, {hdetected(1)}];
    LegendCaption = [LegendCaption; {"Points Analyzed"}];
end

if exist('LegendPosition', 'var')
    hleg1 = legend([LegendObjects{:}], LegendCaption, ...
                   'FontName',SelectedFont, ...
                   'FontSize',SelectedFontSize, ...
                   'Location',LegendPosition, ...
                   'NumColumns',2);
    
    hleg1.ItemTokenSize(1) = 3;
    
    legend boxoff
    legend('AutoUpdate','off')
end

% [xMunTxt yMunTxt] = centroid(MunPolygon);
% for i1 = 1:length(xMunTxt)
%     text(xMunTxt(i1),yMunTxt(i1), MunSel{i1}, 'HorizontalAlignment','center', ...
%         'VerticalAlignment','middle', 'FontName',SelectedFont, 'FontSize',SelectedFontSize/1.2)
% end

set(gca,'visible','off')

%% Export png
cd(fold_fig)
exportgraphics(F1,strcat(Filename1,'.png'),'Resolution',600);
cd(fold0)