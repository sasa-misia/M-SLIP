cd(fold_var)
load('GridCoordinates.mat')
load('SoilParameters.mat');
load('StudyAreaVariables.mat');

if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont='Times New Roman';
    SelectedFontSize=8;
    SelectedLocation='Best';
end

%%
cd(fold_res_fs)

foldFS=uigetdir('open');
[~,namefoldFS] = fileparts(foldFS);

cd(foldFS)
load('AnalysisInformation.mat');

EventsAnalysed=string(StabilityAnalysis{:,2});
choice1=listdlg('PromptString',...
    {'Select event analysed to plot:',''},'ListString',EventsAnalysed);
Event_FS=EventsAnalysed(choice1);

Event_FS=datetime(Event_FS,'InputFormat','dd/MM/yyyy HH:mm:ss');
FS_index=hours(Event_FS-StabilityAnalysis{2}(1))+1;

Event_FS1=datetime(Event_FS,'Format','dd-MM-yyyy HH-mm');

load(strcat('Fs',num2str(FS_index),'.mat'));
Fs=FactorSafety;

num_FS_min1=0;

%%

Fs_less1_index=cellfun(@(x) x<=1 & x>0,Fs,'UniformOutput',false);
Fs_less1_1_5_index=cellfun(@(x) x>1 & x<=1.5,Fs,'UniformOutput',false);
Fs_more_1_5_index=cellfun(@(x) x>1.5,Fs,'UniformOutput',false);

NumInstabilityPoints=cellfun(@(x) numel(find(x)),Fs_less1_index);


IndexDTMPointsInsideStudyArea2=cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, Fs_less1_index,'UniformOutput',false);

IndexDTMPointsInsideStudyArea2_1=cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, Fs_less1_1_5_index,'UniformOutput',false);

IndexDTMPointsInsideStudyArea2_2=cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, Fs_more_1_5_index,'UniformOutput',false);


xLong_sel1=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea2,'UniformOutput',false);
xLong_sel2=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea2_1,'UniformOutput',false);
xLong_sel3=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea2_2,'UniformOutput',false);

yLat_sel1=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea2,'UniformOutput',false);
yLat_sel2=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea2_1,'UniformOutput',false);
yLat_sel3=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea2_2,'UniformOutput',false);

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



hSLIP_1_1_5=cellfun(@(x,y) scatter(x,y,2,...
'Marker','s','MarkerFaceColor',[255 255 150]./255,'MarkerEdgeColor','none'),...
xLong_sel2,yLat_sel2,'UniformOutput',false);

hSLIP_more1_5=cellfun(@(x,y) scatter(x,y,2,...
'Marker','s','MarkerFaceColor',[189 236 232]./255,'MarkerEdgeColor','none'),...
xLong_sel3,yLat_sel3,'UniformOutput',false);

hSLIP_less1=cellfun(@(x,y) scatter(x,y,2,...
   'Marker','s','MarkerFaceColor',[229 81 55]./255,'MarkerEdgeColor','none'),...
   xLong_sel1,yLat_sel1,'UniformOutput',false);

cd(fold_var)
if exist('InfoDetectedSoilSlips.mat')
    load('InfoDetectedSoilSlips.mat')
    hdetected=cellfun(@(x,y) scatter(x,y,'^k','Filled'),InfoDetectedSoilSlips(:,5),InfoDetectedSoilSlips(:,6));
    cellfun(@(x,y,z) text(x,y+0.001,z,'FontName',SelectedFont,'FontSize',5),InfoDetectedSoilSlips(:,5),InfoDetectedSoilSlips(:,6),InfoDetectedSoilSlips(:,2));
else
end

legendCaption=(["SLIP FS<=1","SLIP 1<FS<=1.5","SLIP FS>1.5"]);


hSLIP_less1Good=find(~cellfun(@isempty,hSLIP_less1));
hSLIP_1_1_5Good=find(~cellfun(@isempty,hSLIP_1_1_5));
hSLIP_more1_5Good=find(~cellfun(@isempty,hSLIP_more1_5));

IndLeg=[all(~cellfun(@isempty,hSLIP_less1)) all(~cellfun(@isempty,hSLIP_1_1_5)) all(~cellfun(@isempty,hSLIP_more1_5))];

legendCaption=legendCaption(IndLeg);

allPlot={hSLIP_less1,hSLIP_1_1_5,hSLIP_more1_5};
allPlotGood={hSLIP_less1Good,hSLIP_1_1_5Good,hSLIP_more1_5Good};

allPlot=allPlot(IndLeg);
allPlotGood=allPlotGood(IndLeg);

allPlot2Plot=cellfun(@(x,y) x(y(1)),allPlot,allPlotGood);

if exist('InfoDetectedSoilSlips.mat')
    handPlot=[[allPlot2Plot{:}] hdetected(1)];
    legendCaption=[legendCaption,"Detected Soil slips"];
else
    handPlot=[allPlot2Plot{:}];
end


hleg=legend(handPlot,...
legendCaption{:},...
    'Location',SelectedLocation,...
    'FontName',SelectedFont,...
    'FontSize',SelectedFontSize);


legend('AutoUpdate','off');
legend boxoff



hold on

plot(StudyAreaPolygon,'FaceColor','none','EdgeColor','k','LineWidth',1.5)
hold on


% hSS113=line(Street(:,1),Street(:,2),'LineWidth',1.5,'Color',[239 239 239]./255);
% hTunnel=line(Street(StartEndPointsTunnel(1):StartEndPointsTunnel(2),1),Street(StartEndPointsTunnel(1):StartEndPointsTunnel(2),2),'LineWidth',4,'Color','c');





%%
xlim([MinExtremes(1),MaxExtremes(1)])
ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])
title(strcat("Safety Factors of ",string(Event_FS)," event"),...
            'FontName',SelectedFont,'FontSize',SelectedFontSize*1.4)

cd(fold_fig)

if ~exist(namefoldFS,'dir')
    mkdir(namefoldFS)
end

cd(namefoldFS)
exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);
cd(fold0)