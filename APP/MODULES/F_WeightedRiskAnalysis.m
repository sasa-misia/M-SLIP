cd(fold_var)
load('GridCoordinates.mat')
load('SoilParameters.mat')
load('StudyAreaVariables.mat')
load('Distances.mat')
load('LandUsesVariables.mat')

if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    SelectedLocation = 'Best';
end

%%
xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy  = cellfun(@(x,y) x(y), yLatAll,  IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

cd(fold_res_fs)

foldFS=uigetdir('open');
[~,namefoldFS] = fileparts(foldFS);

cd(foldFS)
load('AnalysisInformation.mat');

EventsAnalysed=string(StabilityAnalysis{:,2});
Choice=listdlg('PromptString',{'Select event analysed to plot:',''},'ListString',EventsAnalysed);
EventFS = datetime(EventsAnalysed(Choice),'InputFormat','dd/MM/yyyy HH:mm:ss');
IndexFS = hours(EventFS-StabilityAnalysis{2}(1))+1;

Event_FS1=datetime(EventFS,'Format','dd-MM-yyyy HH-mm');


load(strcat('Fs',num2str(IndexFS),'.mat'));
Fs = FactorSafety;

WeightFS=[1 0.75 0.5 0.25];
FSRange=[0 1 2 5];
        
FsLow = cellfun(@(x) x<=FSRange(2) & x>FSRange(1), Fs, 'UniformOutput',false);
FsMedium = cellfun(@(x) x>FSRange(2) & x<=FSRange(3), Fs, 'UniformOutput',false);
FsMediumHigh = cellfun(@(x) x>FSRange(3) & x<=FSRange(4), Fs, 'UniformOutput',false);
FsHigh = cellfun(@(x) x>FSRange(4), Fs, 'UniformOutput',false);

WFSLow=cellfun(@(x) x*WeightFS(1),FsLow,'UniformOutput',false);
WFSMedium=cellfun(@(x) x*WeightFS(2),FsMedium,'UniformOutput',false);
WFSMediumHigh=cellfun(@(x) x*WeightFS(3),FsMediumHigh,'UniformOutput',false);
WFSHigh=cellfun(@(x) x*WeightFS(4),FsHigh,'UniformOutput',false);


WFSAll=cellfun(@(a,b,c,d) a+b+c+d,...
    WFSLow,WFSMedium,WFSMediumHigh,WFSHigh,...
   'UniformOutput',false);


DistRange=[0 40 80 120]./1000;
WeightExp=[1 0.75 0.5 0.25];

RiskClasses=[0 0.25 0.5 0.75 1];


ExpHigh=cellfun(@(x) x>=DistRange(1) & x<DistRange(2),MinDistanceLU,'UniformOutput',false);
ExpMediumHigh=cellfun(@(x) x>=DistRange(2) & x<DistRange(3),MinDistanceLU,'UniformOutput',false);
ExpMedium=cellfun(@(x) x>=DistRange(3) & x<DistRange(4),MinDistanceLU,'UniformOutput',false);
ExpLow=cellfun(@(x) x>=DistRange(4),MinDistanceLU,'UniformOutput',false);

WexpHigh=cellfun(@(x) x*WeightExp(1),ExpHigh,'UniformOutput',false);
WexpMediumHigh=cellfun(@(x) x*WeightExp(2),ExpMediumHigh,'UniformOutput',false);
WexpMedium=cellfun(@(x) x*WeightExp(3),ExpMedium,'UniformOutput',false);
WexpLow=cellfun(@(x) x*WeightExp(4),ExpLow,'UniformOutput',false);

WexpAll=cellfun(@(a,b,c,d) a+b+c+d,...
    WexpHigh,WexpMediumHigh,WexpMedium,WexpLow,...
   'UniformOutput',false);

RiskAssessment=cellfun(@(x,y) x.*y,WFSAll,WexpAll,'UniformOutput',false);

VeryLowRisk=cellfun(@(x) x<=RiskClasses(2) & x>RiskClasses(1), RiskAssessment, 'UniformOutput',false);
LowRisk=cellfun(@(x) x<=RiskClasses(3) & x>RiskClasses(2), RiskAssessment, 'UniformOutput',false);
MediumRisk=cellfun(@(x) x<=RiskClasses(4) & x>RiskClasses(3), RiskAssessment, 'UniformOutput',false);
HighRisk=cellfun(@(x) x<=RiskClasses(5) & x>RiskClasses(4), RiskAssessment, 'UniformOutput',false);

NumVeryLowRisk=cellfun(@(x) numel(find(x)),VeryLowRisk);
NumLowRisk=cellfun(@(x) numel(find(x)),LowRisk);
NumMediumRisk=cellfun(@(x) numel(find(x)),MediumRisk);
NumHighRisk=cellfun(@(x) numel(find(x)),HighRisk);

TotalRisk=sum([NumLowRisk,NumMediumRisk,NumHighRisk]);


NumInstabilityPoints=cellfun(@(x) numel(find(x)),FsLow);



IndexStudyAreaLowFS = cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, FsLow,'UniformOutput',false);

IndexStudyAreaMediumFS = cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, FsMedium,'UniformOutput',false);

IndexStudyAreaMediumHighFS = cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, FsMediumHigh,'UniformOutput',false);

IndexStudyAreaHighFS = cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, FsHigh,'UniformOutput',false);

xLongFSLow = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaLowFS,'UniformOutput',false);
xLongFSMedium = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaMediumFS,'UniformOutput',false);
xLongFSMediumHigh = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaMediumHighFS,'UniformOutput',false);
xLongFSHigh = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaHighFS,'UniformOutput',false);

yLatFSLow = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaLowFS,'UniformOutput',false);
yLatFSMedium = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaMediumFS,'UniformOutput',false);
yLatFSMediumHigh = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaMediumHighFS,'UniformOutput',false);
yLatFSHigh = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaHighFS,'UniformOutput',false);

%%
filename1=string(Event_FS1);
f1=figure(1);
set(f1 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits', 'centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition', [0 1 12 6],...
    'InvertHardcopy','off');
set( gcf ,'Name' , filename1);

axes1 = axes('Parent',f1); 
hold(axes1,'on');

PixelSize = 1.5;

hSLIP_Low=cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','s', 'MarkerFaceColor',[255 0 0]./255, ...
                  'MarkerEdgeColor','none'), xLongFSLow, yLatFSLow, 'UniformOutput',false);
hSLIP_Medium=cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','s', 'MarkerFaceColor',[255 117 20]./255, ...
                  'MarkerEdgeColor','none'), xLongFSMedium, yLatFSMedium, 'UniformOutput',false);
hSLIP_MediumHigh=cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','s', 'MarkerFaceColor',[245 242 148]./255, ...
                  'MarkerEdgeColor','none'), xLongFSMediumHigh, yLatFSMediumHigh, 'UniformOutput',false);
hSLIP_High=cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','s', 'MarkerFaceColor',[213 245 238]./255, ...
                   'MarkerEdgeColor','none'), xLongFSHigh, yLatFSHigh, 'UniformOutput',false);

% cd(fold_var)
% if exist('InfoDetectedSoilSlips.mat')
%     load('InfoDetectedSoilSlips.mat')
%     hdetected = cellfun(@(x,y) scatter(x, y, 5, '^k','Filled'),InfoDetectedSoilSlips(:,5),InfoDetectedSoilSlips(:,6));
%     % cellfun(@(x,y,z) text(x,y+0.001,z,'FontName',SelectedFont,'FontSize',4),InfoDetectedSoilSlips(:,5),InfoDetectedSoilSlips(:,6),InfoDetectedSoilSlips(:,2));
% end

hSLIP_LowGood = find(~cellfun(@isempty,hSLIP_Low));
hSLIP_MediumGood = find(~cellfun(@isempty,hSLIP_Medium));
hSLIP_MediumHighGood = find(~cellfun(@isempty,hSLIP_MediumHigh));
hSLIP_HighGood = find(~cellfun(@isempty,hSLIP_High));

allPlot={hSLIP_Low{hSLIP_LowGood(1)}, hSLIP_Medium{hSLIP_MediumGood(1)},...
    hSLIP_MediumHigh{hSLIP_MediumHighGood(1)},hSLIP_High{hSLIP_HighGood(1)}};


legendCaption=(["0 - 1","1 - 2","2 - 5",">5"]);
hleg=legend([allPlot{:}],...
legendCaption{:},...
    'Location',SelectedLocation,...
    'FontName',SelectedFont,...
    'FontSize',SelectedFontSize);


title(hleg,'{\it FS} [-]','FontName',SelectedFont,'FontSize',SelectedFontSize,'FontWeight','bold')

legend('AutoUpdate','off');
legend boxoff
hold on
plot(StudyAreaPolygon,'FaceColor','none','EdgeColor','k','LineWidth',1)
hold on


xlim([MinExtremes(1),MaxExtremes(1)])
ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])

set(gca,'visible','off')

cd(fold_fig)
exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);


%%
for i1=1:length(SelectedLU4Dist)
    IndLU=cellfun(@(x) strcmp(x,SelectedLU4Dist(i1)),AllLandUnique,'UniformOutput',false);
    IndLUGood(i1)=find([IndLU{:}]);
end

filename2='RiskAssessment';
f2=figure(2);
set(f2 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits', 'centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition', [0 1 7.7 6.2],...
    'InvertHardcopy','off');
set( gcf ,'Name' , filename2);

axes2 = axes('Parent',f2); 
hold(axes2,'on');

cellfun(@(x,y,z) fastscatter(x,y,z),xLongStudy,yLatStudy,RiskAssessment,...
    'UniformOutput',false);
hold on
plot(StudyAreaPolygon,'FaceColor','none','EdgeColor','k','LineWidth',1)
hold on
eleatrisk=plot(LandUsePolygonsStudyArea(IndLUGood),'FaceColor',[156 156 156]./255,'FaceAlpha',1);
legend(eleatrisk,'Element at risk', ...
    'FontName',SelectedFont,...
    'Box','off')

hcb2=colorbar;
 
hcb2.FontName=SelectedFont;
hcb2.FontSize=SelectedFontSize;

hcb2.Title
hcb2.Title.String='Risk Level [-]';
hcb2.Title.FontName=SelectedFont;
hcb2.Title.FontWeight='Bold';

caxis([0 1])

xlim([MinExtremes(1),MaxExtremes(1)])
ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])

set(gca,'visible','off')

cd(fold_fig)
exportgraphics(f2,strcat(filename2,'.png'),'Resolution',600);

%%
filename3='Exposure';
f3=figure(3);
set(f3 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits', 'centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition', [0 1 12 6],...
    'InvertHardcopy','off');
set( gcf ,'Name' , filename3);

axes3 = axes('Parent',f3); 
hold(axes3,'on');

ExpHighPlot=cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','s', 'MarkerFaceColor',[255 0 0]./255, ...
                  'MarkerEdgeColor','none'), xLongStudy, yLatStudy,ExpHigh, 'UniformOutput',false);
ExpMediumHighPlot=cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','s', 'MarkerFaceColor',[255 117 20]./255, ...
                  'MarkerEdgeColor','none'), xLongStudy, yLatStudy,ExpMediumHigh, 'UniformOutput',false);
ExpMediumPlot=cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','s', 'MarkerFaceColor',[245 242 148]./255, ...
                  'MarkerEdgeColor','none'), xLongStudy, yLatStudy,ExpMedium, 'UniformOutput',false);
ExpLowPlot=cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','s', 'MarkerFaceColor',[213 245 238]./255, ...
                   'MarkerEdgeColor','none'), xLongStudy, yLatStudy,ExpLow, 'UniformOutput',false);
hold on
plot(StudyAreaPolygon,'FaceColor','none','EdgeColor','k','LineWidth',1)
hold on
eleatrisk=plot(LandUsePolygonsStudyArea(IndLUGood),'FaceColor',[156 156 156]./255,'FaceAlpha',1);
legend(eleatrisk,'Element at risk', ...
    'FontName',SelectedFont,...
    'Box','off')


ExpHighPlotGood = find(~cellfun(@isempty,ExpHighPlot));
ExpMediumHighPlotGood = find(~cellfun(@isempty,ExpMediumHighPlot));
ExpMediumPlotGood = find(~cellfun(@isempty,ExpMediumPlot));
ExpLowPlotGood = find(~cellfun(@isempty,ExpLowPlot));

allPlot={ExpHighPlot{ExpHighPlotGood(1)}, ExpMediumHighPlot{ExpMediumHighPlotGood(1)},...
    ExpMediumPlot{ExpMediumPlotGood(1)},ExpLowPlot{ExpLowPlotGood(1)}};


legendCaption=(["0 - 40","40 - 80","80 - 120",">120"]);
hleg=legend([allPlot{:}],...
legendCaption{:},...
    'Location',SelectedLocation,...
    'FontName',SelectedFont,...
    'FontSize',SelectedFontSize);


title(hleg,'{\it Distance} [m]','FontName',SelectedFont,'FontSize',SelectedFontSize*1.2,'FontWeight','bold')
xlim([MinExtremes(1),MaxExtremes(1)])
ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])

set(gca,'visible','off')

cd(fold_fig)
exportgraphics(f3,strcat(filename3,'.png'),'Resolution',600);

%%

filename4='Bar_PercentageAreaAtRisk';
f4=figure(4);
set(f4 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits', 'centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition', [0 1 6 5],...
    'InvertHardcopy','off');
set( gcf ,'Name' , filename4);

X = categorical({'Low','Medium','High'});
X = reordercats(X,{'Low','Medium','High'});

b=bar(X,[NumLowRisk/TotalRisk NumMediumRisk/TotalRisk NumHighRisk/TotalRisk]*100);




b.FaceColor = 'flat';
b.CData(1,:) = [149 211 138]./255;
b.CData(2,:) = [255 173 1]./255;
b.CData(3,:) = [254 0 0]./255;

xlabel('Risk Level','FontName',SelectedFont);
ylabel('Area (%)','FontName',SelectedFont);

set(gca,...
    'YLim',[0 100],...
    'YTick',0:20:100,'FontName',SelectedFont)

cd(fold_fig)
exportgraphics(f4,strcat(filename4,'.png'),'Resolution',600);
