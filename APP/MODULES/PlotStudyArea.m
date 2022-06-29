cd(fold_var)
load('UserA_Answers.mat');
load('StudyAreaVariables.mat');
cd(fold0)

OrthophotoAnswer = 0;
if exist("Orthophoto.mat")
    load("Orthophoto.mat")
    OrthophotoAnswer = 1;
end

if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    SelectedLocation = 'Best';
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
f1=figure(1);
set(f1 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits','centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition',[0 1 30 12],...
    'InvertHardcopy','off');
set(gcf, 'Name',Filename1);

for i1 = 1:size(MunPolygon,2)
    plot(MunPolygon(i1), 'FaceColor',MunColors(i1,:), 'FaceAlpha',1)
    hold on
end

plot(StudyAreaPolygon,'FaceColor','none')
hold on
fig_settings(fold0)

hleg1=legend(MunSel,...
             'FontName',SelectedFont,...
             'FontSize',SelectedFontSize,...
             'Location',SelectedLocation,...
             'NumColumns',2);

hleg1.ItemTokenSize(1)=4;

legend boxoff
legend('AutoUpdate','off')

% [xMunTxt yMunTxt] = centroid(MunPolygon);
% for i1 = 1:length(xMunTxt)
%     text(xMunTxt(i1),yMunTxt(i1), MunSel{i1}, 'HorizontalAlignment','center', ...
%         'VerticalAlignment','middle', 'FontName',SelectedFont, 'FontSize',SelectedFontSize/1.2)
% end

set(gca,'visible','off')

%% Export png
cd(fold_fig)
exportgraphics(f1,strcat(Filename1,'.png'),'Resolution',600);
cd(fold0)