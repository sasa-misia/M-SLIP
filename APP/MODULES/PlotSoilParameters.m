%%
cd(fold_var)
load('GridCoordinates.mat')
load('SoilParameters.mat');

load('StudyAreaVariables.mat');
load('UserC_Answers.mat');

if AnswerAttributionSoilParameter==1
    load('LithoPolygonsStudyArea.mat');
    load('LUDSCMapParameters.mat');
    
    [n_us Index4Color_n ]=unique(dsc_parameters{1});
    [phi_us Index4Color_phi ]=unique(dsc_parameters{2});
    [c_us Index4Color_c]=unique(dsc_parameters{3});
    [A_us Index4Color_A]=unique(dsc_parameters{4});
    [kt_us Index4Color_k]=unique(dsc_parameters{5});

    color_polygons=lu_dsc_color_plot{1}./255;

    color_c=lu_dsc_color_plot{2}(Index4Color_c,:)./255;
    color_phi=lu_dsc_color_plot{2}(Index4Color_phi,:)./255;



else
    n_us=unique(nAll{1});
    phi_us=unique(PhiAll{1});
    c_us=unique(CohesionAll{1});
    A_us=unique(AAll{1});
    kt_us=unique(KtAll{1});
    
    color_c=[0 0 255]./255;
    color_phi=[0 0 255]./255;
end

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




xLongStudy=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

yLatStudy=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

CohesionStudy=cellfun(@(x,y) x(y),CohesionAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

PhiStudy=cellfun(@(x,y) x(y),PhiAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

KtStudy=cellfun(@(x,y) x(y),KtAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

AStudy=cellfun(@(x,y) x(y),AAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);



    
    
    for i2=1:size(c_us,1) %Diversi cicli perché ci sono volte in cui ho parametri uguali per diverse DSC
        c_case(i2,:)=cellfun(@(x) find(x==c_us(i2)),CohesionStudy,...
            'UniformOutput',false);
    end

    for i2=1:size(phi_us,1)
        phi_case(i2,:)=cellfun(@(x) find(x==phi_us(i2)),PhiStudy,...
            'UniformOutput',false);
    end

    for i2=1:size(A_us,1)
        A_case(i2,:)=cellfun(@(x) find(x==A_us(i2)),AStudy,...
            'UniformOutput',false);
    end

    for i2=1:size(kt_us,1)
        kt_case(i2,:)=cellfun(@(x) find(x==kt_us(i2)),KtStudy,...
            'UniformOutput',false);
    end


%%
switch NumFigPlot
    case 1
        filename1='Lithology';
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
        
        for i2=1:size(SelectedSoil,1)
            hplot_litho(i2)=plot(LithoPolygonsStudyArea(SelectedSoil(i2)),'FaceColor',color_polygons(i2,:),'FaceAlpha',1,'EdgeColor','none');
            hold on
        end
        
        hleg1=legend(hplot_litho,...
            LUAbbr,'AutoUpdate','off',...
            'Location',SelectedLocation,...
            'NumColumns',1,...
             'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize,...
            'Box','off');

        hleg1.ItemTokenSize(1)=10;

        plot(MunPolygon,'FaceColor','none','LineWidth',1.5)
        hold on
        %PlotScaleBar
        
        xlim([MinExtremes(1) MaxExtremes(1)])
        ylim([MinExtremes(2) MaxExtremes(2)])
        
               
        comprose(14.1068,37.65,8,0.015,0)
        text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',SelectedFontSize)
        daspect([1 1 1])

        set(gca,'visible','off')
        cd(fold_fig)
        exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);
    %%
    case 2
        filename2='EffectiveCohesionMap';
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

        axes2 = axes('Parent',f2); 
        hold(axes2,'on');  
        

        for i1=1:length(c_us)
            hc(i1,:)=cellfun(@(x,y,z) scatter(x(z),y(z),.1/RatioRef,...
            'Marker','o','MarkerFaceColor',color_c(i1,:),'MarkerEdgeColor','none'),...
            xLongStudy,yLatStudy,c_case(i1,:),'UniformOutput',false);
            hold on
        end       
        
        
        leg_c=cellstr(num2str(c_us));
        leg1=legend([hc{1:end,1}],...
            leg_c{:},...
            'NumColumns',1,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize);
        legend('AutoUpdate','off');
        legend boxoff
        
        leg1.ItemTokenSize(1)=10;
        
        plot(MunPolygon,'FaceColor','none','LineWidth',1);
        hold on
        PlotScaleBar
        
        xlim([MinExtremes(1) MaxExtremes(1)])
        ylim([MinExtremes(2) MaxExtremes(2)])
        
        set(gca,'visible','off')

        cd(fold_fig)
        exportgraphics(f2,strcat(filename2,'.png'),'Resolution',600);

    case 3
        filename3='FrictionMap';

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

        axes3 = axes('Parent',f3); 
        hold(axes3,'on');  
        
        for i1=1:length(phi_us)
            hphi(i1,:)=cellfun(@(x,y,z) scatter(x(z),y(z),.1/RatioRef,...
            'Marker','o','MarkerFaceColor',color_phi(i1,:),'MarkerEdgeColor','none'),...
            xLongStudy,yLatStudy,phi_case(i1,:),'UniformOutput',false);
            hold on
        end   


        
        leg_phi=cellstr(num2str(phi_us));
        leg1=legend([hphi{1:end,1}],...
            leg_phi{:},...
            'NumColumns',1,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize);
        legend('AutoUpdate','off');
        legend boxoff
        
        leg1.ItemTokenSize(1)=10;
        
        
        plot(MunPolygon,'FaceColor','none','LineWidth',1);
        hold on
        PlotScaleBar
        
        xlim([MinExtremes(1) MaxExtremes(1)])
        ylim([MinExtremes(2) MaxExtremes(2)])   
        
        set(gca,'visible','off')

        cd(fold_fig)
        exportgraphics(f3,strcat(filename3,'.png'),'Resolution',600);

    case 4
        filename4='SoilUnit';
        f4=figure(4);
        set(f4 , ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98],...    
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 13 11],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename4);  

        for i1=1:size(lu_dsc_color_plot{2},1)
            IndUnit=cellfun(@(x) x==i1,LU2DSC,'UniformOutput',false);
            hUnit{i1}=plot(LithoPolygonsStudyArea(([IndUnit{:}])),...
                'FaceColor',lu_dsc_color_plot{2}(i1,:)./255,'FaceAlpha',1,'EdgeColor','none','DisplayName',num2str(i1));
            hold on
        end
        
        IndLeg=find(~cellfun(@isempty,hUnit'));
        leg_unit=string(IndLeg);

        hUnitGood=hUnit(IndLeg);
        hUnitGoodLeg=cellfun(@(x) x(1),hUnitGood);
        
        leg1=legend(hUnitGoodLeg,...
            leg_unit,'AutoUpdate','off',...
            'NumColumns',1,...
            'FontName',SelectedFont,...
            'Location',SelectedLocation,...
            'FontSize',SelectedFontSize);
        title(leg1,'SC')
        legend boxoff

        leg1.ItemTokenSize(1)=10;
        
        
        plot(MunPolygon,'FaceColor','none','LineWidth',1);
        hold on
        %PlotScaleBar
        
        xlim([MinExtremes(1) MaxExtremes(1)])
        ylim([MinExtremes(2) MaxExtremes(2)])
        
        set(gca,'visible','off')
        daspect([1 1 1])
        cd(fold_fig)
        exportgraphics(f4,strcat(filename4,'.png'),'Resolution',600);
end

