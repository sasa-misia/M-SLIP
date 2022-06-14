%%
cd(fold_var)
load('GridCoordinates.mat')
load('VegetationParameters.mat');

load('StudyAreaVariables.mat');

load('UserD_Answers.mat');

RefStudyArea=0.0417;
ExtentStudyArea=area(StudyAreaPolygon);
RatioRef=ExtentStudyArea/RefStudyArea;

if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont='Times New Roman';
    SelectedFontSize=8;
    SelectedLocation='Best';
end

if AnswerAttributionVegetationParameter==0

    cr_uv=unique(RootCohesionAll{1});
    betastar_uv=unique(BetaStarAll{1});
    
    color_parameters=[0 0 255]./255;

else
    load('VegPolygonsStudyArea.mat');
    load('VUDVCMapParameters.mat');
    
    cr_uv=(DVCParameters{1});
    betastar_uv=(DVCParameters{2});


    [~,CorrectOrderCr]=sort(cr_uv);
    [~,CorrectOrderBeta]=sort(betastar_uv);

    cr_uv=cr_uv(CorrectOrderCr);
    betastar_uv=betastar_uv(CorrectOrderBeta);

    color_polygons=VU_DVCPlotColors{1}./255;
    color_parameters=VU_DVCPlotColors{2}./255;

    color_parametersCr=color_parameters(CorrectOrderCr,:);
    color_parametersBeta=color_parameters(CorrectOrderBeta,:);

    [uniqueBeta,posUniqueBeta]=unique(betastar_uv);
    color_parametersBetaUnique=color_parametersBeta(posUniqueBeta,:);



end


UVNumber=size(cr_uv,1);

for i1=1:size(xLongAll,2)
    xLongStudyArea{i1}=xLongAll{i1}(IndexDTMPointsInsideStudyArea{i1});
    yLatStudyArea{i1}=yLatAll{i1}(IndexDTMPointsInsideStudyArea{i1});
    RootCohesionStudyArea{i1}=RootCohesionAll{i1}(IndexDTMPointsInsideStudyArea{i1});
    BetaStarStudyArea{i1}=BetaStarAll{i1}(IndexDTMPointsInsideStudyArea{i1});

    
    
    for i2=1:UVNumber
        cr_case{i2,i1}=find(RootCohesionStudyArea{i1}==cr_uv(i2));
    end

    for i3=1:length(uniqueBeta)
        betastar_case{i3,i1}=find(BetaStarStudyArea{i1}==uniqueBeta(i3));
    end

end


%%
switch NumFigPlot
    case 1
        filename1='VegetationMap';
        f1=figure(1);
        set(f1 , ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98 ],...    
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 13 11],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename1);  
        
        for i2=1:size(SelectedVeg,1)
            plot(VegPolygonsStudyArea(SelectedVeg(i2)),'FaceColor',color_polygons(i2,:),'FaceAlpha',0.9,'EdgeColor','none')
            hold on
        end
        
        leg1=legend(VUAbbr,...
            'AutoUpdate','off',...
            'NumColumns',1,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize,...
            'Box','off');
        leg1.ItemTokenSize(1)=10;



        plot(MunPolygon,'FaceColor','none','LineWidth',1.5)
        hold on
        PlotScaleBar
        
        xlim([MinExtremes(1) MaxExtremes(1)])
        ylim([MinExtremes(2) MaxExtremes(2)])
        
        comprose(14.1068,37.65,8,0.015,0)
        text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',SelectedFontSize)
        
        set(gca,'visible','off')
        
        cd(fold_fig)
        exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);
    
    case 2
        filename2='RootCohesionMap';
        f2=figure(2);
        set(f2 , ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98 ],...    
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 13 11],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename2);  

        for i1=1:size(xLongAll,2)
            for i2=1:UVNumber
                hcr(i2)=scatter(xLongStudyArea{i1}(cr_case{i2,i1}),yLatStudyArea{i1}(cr_case{i2,i1}),...
                    .1/RatioRef,'o','MarkerFaceColor',color_parametersCr(i2,:),'MarkerEdgeColor','none');
                hold on
             end
        end
        
        leg_cr=cellstr(num2str(cr_uv));
        leg1=legend(hcr,...
            leg_cr{:},...
            'NumColumns',1,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize);
        legend('AutoUpdate','off');
        legend boxoff
        
        leg1.ItemTokenSize(1)=10;
        title(leg1,'{\it c_r} [kPa]','FontName',SelectedFont,'FontSize',SelectedFontSize*1.2,'FontWeight','bold')

        
        plot(MunPolygon,'FaceColor','none','LineWidth',1);
        hold on
        PlotScaleBar
        
        xlim([MinExtremes(1) MaxExtremes(1)])
        ylim([MinExtremes(2) MaxExtremes(2)])
        
        comprose(14.1068,37.65,8,0.015,0)
        text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',SelectedFontSize)
        
        
        set(gca,'visible','off')
        cd(fold_fig)
        exportgraphics(f2,strcat(filename2,'.png'),'Resolution',600);

    case 3
        filename3='BetastarMap';

        f3=figure(3);
        set(f3, ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98 ],...    
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 13 11],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename3);  
        
        for i1=1:size(xLongAll,2)
            for i2=1:length(uniqueBeta)
                hbetastar(i2)=scatter(xLongStudyArea{i1}(betastar_case{i2,i1}),yLatStudyArea{i1}(betastar_case{i2,i1}),...
                    .1/RatioRef,'o','MarkerFaceColor',color_parametersBetaUnique(i2,:),'MarkerEdgeColor','none');
                hold on
            end
        end
        
        leg_beta=cellstr(num2str(uniqueBeta));
        leg1=legend(hbetastar,...
            leg_beta{:},...
            'NumColumns',1,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize);
        legend('AutoUpdate','off');
        legend boxoff
        
        leg1.ItemTokenSize(1)=10;
        
        title(leg1,'1-{\it \beta^*} [-]','FontName',SelectedFont,'FontSize',SelectedFontSize*1.2,'FontWeight','bold')
        
        
        plot(MunPolygon,'FaceColor','none','LineWidth',1);
        hold on
        PlotScaleBar
        
        xlim([MinExtremes(1) MaxExtremes(1)])
        ylim([MinExtremes(2) MaxExtremes(2)])

        comprose(14.1068,37.65,8,0.015,0)
        text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',SelectedFontSize)
        
        
        set(gca,'visible','off')
        cd(fold_fig)
        exportgraphics(f3,strcat(filename3,'.png'),'Resolution',600);

end

%%

% figure(3)
% for i2=1:size(SelectedSoil,1)
%     plot(LitoPolygonsStudyArea(SelectedSoil(i2)),'FaceColor',lu_dsc_color_plot{2}(LU2DSC{SelectedSoil(i2)},:)./255,'FaceAlpha',1,'EdgeColor','none')
%     hold on
% end
% plot(MunPolygon,'FaceColor','none','LineWidth',1.5)
% 
% LitoPolygonsStudyArea(SelectedSoil)=[];
% plot(LitoPolygonsStudyArea,'FaceColor',[253 191 228]./255,'FaceAlpha',1,'EdgeColor','none');
