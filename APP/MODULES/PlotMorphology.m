cd(fold_var)
load('StudyAreaVariables.mat');
load('GridCoordinates.mat')
load('MorphologyParameters.mat');

if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont='Times New Roman';
    SelectedFontSize=8;
    SelectedLocation='Best';
end

%For scatter dimension
RefStudyArea=0.0417;
ExtentStudyArea=area(StudyAreaPolygon);
RatioRef=ExtentStudyArea/RefStudyArea;

DimFigure=[8.5 6.5];


%% Loading
%NumFigPlot=1; %1 Elevation 2 Slope 3 Aspect
%%
slope_range=10:10:60;
aspect_range=90:90:360;
altitude_range=[200 250 300 350 400 450 500  600  700 800 900];

xLongStudy=cell(size(xLongAll));
yLatStudy=cell(size(xLongAll));
SlopeStudy=cell(size(xLongAll));
AspectStudy=cell(size(xLongAll));
GradEStudy=cell(size(xLongAll));
GradNStudy=cell(size(xLongAll));
ElevationStudy=cell(size(xLongAll));

ColorElevation=[103 181 170;
    127 195 186;
    152 210 199;
    177 225 217;
    200 232 226;
    225 240 238;
    245 237 224;
    240 227 200;
    235 217 176;
    223 198 157;
    213 179 136;
    201 159 116];
    

ColorSlope=[201 160 220;
    143 0 255;
    0 100 25;
    127 255 212;
    0 187 45;
    255 255 102;
    255 153 0];

ColorAspect=[201 160 220;
    143 0 255;
    0 100 255;
    127 255 212];

%%
xLongStudy=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

yLatStudy=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

ElevationStudy=cellfun(@(x,y) x(y),ElevationAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

SlopeStudy=cellfun(@(x,y) x(y),SlopeAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

AspectStudy=cellfun(@(x,y) x(y),AspectAngleAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

GradEStudy=cellfun(@(x,y) x(y),GradEAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

GradNStudy=cellfun(@(x,y) x(y),GradNAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

for i1=1:length(slope_range)+1
    if i1==1
        SlopeIndex(i1,:)=cellfun(@(x) find(x<=slope_range(i1)),SlopeStudy,'UniformOutput',false);
    elseif i1>1 & i1<length(slope_range)+1
        SlopeIndex(i1,:)=cellfun(@(x) find(x>=slope_range(i1-1)+.01 & x<=slope_range(i1)),SlopeStudy,'UniformOutput',false);
    else
        SlopeIndex(i1,:)=cellfun(@(x) find(x>=slope_range(i1-1)+.01),SlopeStudy,'UniformOutput',false);
    end
end


for i2=1:length(aspect_range)
    if i2==1
        AspectIndex(i2,:)=cellfun(@(x) find(x<=aspect_range(i2)),AspectStudy,'UniformOutput',false);
    else
        AspectIndex(i2,:)=cellfun(@(x) find(x>=aspect_range(i2-1)+.01 & x<=aspect_range(i2)),AspectStudy,'UniformOutput',false);
    end
end


for i3=1:length(altitude_range)+1
    if i3==1
        ElevationIndex(i3,:)=cellfun(@(x) find(x<=altitude_range(i3)),ElevationStudy,'UniformOutput',false);
    elseif i3>1 & i3<length(altitude_range)+1
        ElevationIndex(i3,:)=cellfun(@(x) find(x>=altitude_range(i3-1)+.01 & x<=altitude_range(i3)),ElevationStudy,'UniformOutput',false);
    else
        ElevationIndex(i3,:)=cellfun(@(x) find(x>=altitude_range(i3-1)+.01),ElevationStudy,'UniformOutput',false);
    end
end


%%
switch NumFigPlot
    case 1
        filename1='Elevation_Range';
        f1=figure(1);
        set(f1 , ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98 ],...    
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 DimFigure(1) DimFigure(2)],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename1);

        axes1 = axes('Parent',f1); 
        hold(axes1,'on');  
        
        for i1=1:length(altitude_range)+1
            helevation(i1,:)=cellfun(@(x,y,z) scatter(x(z),y(z),.1/RatioRef,...
            'Marker','o','MarkerFaceColor',ColorElevation(i1,:)./255,'MarkerEdgeColor','none'),...
            xLongStudy,yLatStudy,ElevationIndex(i1,:),'UniformOutput',false);
            hold on
        end       
        
        
        plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1.5)
        hold on
        PlotScaleBar;

        hleg3=legend([helevation{1:end,1}],...
            '< 200',...
            '200 - 250',...
            '250 - 300',...
            '300 - 350',...
            '350 - 400',...
            '400 - 450',...
            '450 - 500',...
            '500 - 600',...
            '600 - 700',...
            '700 - 800',...
            '800 - 900',...
            '> 900',...
            'NumColumns',2,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize);
        
        legend('AutoUpdate','off');
        legend boxoff
        hleg3.ItemTokenSize(1)=10;
        
        title(hleg3,'Elevation [m]','FontName',SelectedFont,'FontSize',SelectedFontSize*1.2,'FontWeight','bold')

       
        comprose(14.1068,37.65,8,0.015,0)
        text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',SelectedFontSize)
        
        
        xlim([MinExtremes(1),MaxExtremes(1)])
        ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])
        
        
        set(gca,'visible','off')
        cd(fold_fig)
        exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);

    case 2
        filename2='sub_slope';
        f2=figure(2);
        set(f2 , ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98 ],...
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 DimFigure(1) DimFigure(2)],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename2);
        
        axes2 = axes('Parent',f2); 
        hold(axes2,'on');
        
        for i1=1:length(slope_range)+1
            hslope(i1,:)=cellfun(@(x,y,z) scatter(x(z),y(z),.1/RatioRef,...
            'Marker','o','MarkerFaceColor',ColorSlope(i1,:)./255,'MarkerEdgeColor','none'),...
            xLongStudy,yLatStudy,SlopeIndex(i1,:),'UniformOutput',false);
            hold on
        end

        plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1.5)
        hold on
        PlotScaleBar;
        
        hleg=legend([hslope{1:end,1}],...
            '0 - 10',...
            '10 - 20',...
            '20 - 30',...
            '30 - 40',...
            '40 - 50',...
            '50 - 60',...
            '> 60',...
            'NumColumns',2,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize);
        hleg.ItemTokenSize(1)=10;
        legend('AutoUpdate','off');
        legend boxoff

        title(hleg,'Slope angle [°]','FontName',SelectedFont,'FontSize',SelectedFontSize*1.2,'FontWeight','bold')
        
        
        comprose(14.1068,37.65,8,0.015,0)
        text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',SelectedFontSize)

        xlim([MinExtremes(1),MaxExtremes(1)])
        ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])
        
        set(gca,'visible','off')
        cd(fold_fig)

        exportgraphics(f2,strcat(filename2,'.png'),'Resolution',600);

%%
    case 3
        filename3='sub_aspect';
        f3=figure(3);
        set(f3 , ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98 ],...    
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 DimFigure(1) DimFigure(2)],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename3);

        axes3 = axes('Parent',f3); 
        hold(axes3,'on');
        
        for i1=1:length(aspect_range)
            haspect(i1,:)=cellfun(@(x,y,z) scatter(x(z),y(z),.1/RatioRef,...
            'Marker','o','MarkerFaceColor',ColorAspect(i1,:)./255,'MarkerEdgeColor','none'),...
            xLongStudy,yLatStudy,AspectIndex(i1,:),'UniformOutput',false);
            hold on
        end

        
        plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1.5)
        hold on
        PlotScaleBar;
        
        hleg2=legend([haspect{1:end,1}],...
            '0 - 90',...
            '90 - 180',...
            '180 - 270',...
            '270 - 360',...
            'NumColumns',2,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize);
        
        legend('AutoUpdate','off');
        
        hleg2.ItemTokenSize(1)=10;
        
        comprose(14.1068,37.65,8,0.015,0)
        text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',SelectedFontSize)
        
               
        xlim([MinExtremes(1),MaxExtremes(1)])
        ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])
        
        
        title(hleg2,'Aspect angle [°]','FontName',SelectedFont,'FontSize',SelectedFontSize*1.2,'FontWeight','bold')
        
        legend('AutoUpdate','off');
        legend boxoff
        
        set(gca,'visible','off')
        cd(fold_fig)
        exportgraphics(f3,strcat(filename3,'.png'),'Resolution',600);
end

%%
%
% cd(fold0)
% filename3='Elevation';
% f3=figure(3);
% set(f3 , ...
%     'Color',[1 1 1],...
%     'PaperType','a4',...
%     'PaperSize',[29.68 20.98 ],...    
%     'PaperUnits', 'centimeters',...
%     'PaperPositionMode','manual',...
%     'PaperPosition', [0 1 16 12],...
%     'InvertHardcopy','off');
% set( gcf ,'Name' , filename3);
% % image(flipud(d), 'XData', [14.9089+0.0004 14.9272], 'YData', [38.1867 38.1925],'AlphaData',.8);
% % axis xy
% % hold on
% 
% for i3=1:size(xLongAll,2)
% xLongAll1=xLongAll{i3};
% yLatAll1=yLatAll{i3};
% ElevationAll1=ElevationAll{i3};
% 
% fastscatter(xLongAll1(IndexDTMPointsInsideStudyArea{i3}),yLatAll1(IndexDTMPointsInsideStudyArea{i3}),ElevationAll1(IndexDTMPointsInsideStudyArea{i3}))
% hold on
% end
% 
% hcb2=colorbar;
%  
% hcb2.Title
% hcb2.Title.String='Elevation [m]';
% hcb2.Title.FontName=SelectedFont;
% hcb2.Title.FontWeight='Bold';
% 
% plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1.5)
% hold on
% plot(pol_scalebar1,'FaceColor',[0 0 0],'EdgeColor','k','FaceAlpha',1,'LineWidth',0.5)
% hold on
% plot(pol_scalebar2,'FaceColor','none','EdgeColor','k','FaceAlpha',1,'LineWidth',0.5)
% 
% 
% text(MaxExtremes(1)-11*dScaleBar,MinExtremes(2)+0.005,'0','FontName',SelectedFont,'FontSize',8)
% text(MaxExtremes(1)-6*dScaleBar,MinExtremes(2)+0.005,'5','FontName',SelectedFont,'FontSize',8)
% text(MaxExtremes(1)-dScaleBar,MinExtremes(2)+0.005,'10','FontName',SelectedFont,'FontSize',8)
% 
% text(MaxExtremes(1)-2*dScaleBar,MinExtremes(2)+2*0.009,'km','FontName',SelectedFont,'FontSize',8)
% 
% comprose(14.1068,37.65,8,0.015,0)
% text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',8)
% 
% 
% xlim([MinExtremes(1),MaxExtremes(1)])
% ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])
% 
% 
% set(gca,'visible','off')
% 
% cd(fold_fig)
% print( '-dpng'  , '-r600' , get(gcf,'Name'))
% cd(fold0)


%%
