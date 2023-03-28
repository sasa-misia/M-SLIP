cd(fold_var)
load('GridCoordinates.mat');
load('LandUsesVariables.mat');
load('StudyAreaVariables.mat');
load('Distances.mat');
load('PolygonsDistances.mat');


cd(fold_user)
Sheet_Ass=readcell(FileName_LandUsesAssociation,'Sheet','Association');
LandUniqueLeg=Sheet_Ass(2:end,2);

LUColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
                        Sheet_Ass(2:end,3),'UniformOutput',false)); 

if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont='Times New Roman';
    SelectedFontSize=8;
    SelectedLocation='Best';
end

xLongStudy=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

yLatStudy=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);


if IndLandUse

    IndLU=cellfun(@(x) find(strcmp(AllLandUnique,x)),SelectedLU4Dist);

    for i1=1:length(xLongStudy)
        cellfun(@(x,y,z) fastscatter(x,y,z),xLongStudy(i1),yLatStudy(i1),MinDistanceLU(i1))
        hold on
    end

    filename1='DistanceLU';
    f1=figure(1);
    set(f1 , ...
        'Color',[1 1 1],...
        'PaperType','a4',...
        'PaperSize',[29.68 20.98 ],...    
        'PaperUnits', 'centimeters',...
        'PaperPositionMode','manual',...
        'PaperPosition', [0 1 16 12],...
        'InvertHardcopy','off');
    set( gcf ,'Name' , filename1);
    
    for i1=1:length(IndLU)
        hLU(i1)=plot(LandUsePolygonsStudyArea(IndLU(i1)),...
            'FaceColor',LUColors(IndLU(i1),:)./255,'FaceAlpha',1,'EdgeColor','none');
        hold on
    end


    hcol=colorbar;
    hcol.Title.String='Distance [km]';
    hcol.Location = 'southoutside';

    hleg1=legend(hLU,LandUniqueLeg(IndLU),...
        'FontName',SelectedFont,...
        'Location',SelectedLocation,...
        'FontSize',SelectedFontSize,...
        'Box','off');
    
    hleg1.ItemTokenSize(1)=4;


    xlim([MinExtremes(1),MaxExtremes(1)])
    ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])

    set(gca,'visible','off')
    cd(fold_fig)
    exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);
end

if IndRoad
    VertRoad=cellfun(@(x) x.Vertices,RoadPoly,'UniformOutput',false);
    IndGoodLong=cellfun(@(x) x(:,1)>MinExtremes(1) & x(:,1)<MaxExtremes(1),...
        VertRoad,'UniformOutput',false);
    
    IndGoodLat=cellfun(@(x) x(:,2)>MinExtremes(2) & x(:,2)<MaxExtremes(2),...
        VertRoad,'UniformOutput',false);

    IndGoodAll=cellfun(@(x,y) cat(2,x,y),IndGoodLong,IndGoodLat,...
        'UniformOutput',false);
    
    IndGoodAll=cellfun(@(x) min(x,[],2),IndGoodAll,...
        'UniformOutput',false);

    filename2='DistanceRoad';
    f2=figure(2);
    set(f2 , ...
        'Color',[1 1 1],...
        'PaperType','a4',...
        'PaperSize',[29.68 20.98 ],...    
        'PaperUnits', 'centimeters',...
        'PaperPositionMode','manual',...
        'PaperPosition', [0 1 16 12],...
        'InvertHardcopy','off');
    set( gcf ,'Name' , filename2);

    for i1=1:length(xLongStudy)
        cellfun(@(x,y,z) fastscatter(x,y,z),xLongStudy(i1),yLatStudy(i1),MinDistanceRoad(i1))
        hold on
    end

    hRoad=cellfun(@(x,y) plot(x(y,1),x(y,2),'Color',[228 229 224]./255,'LineWidth',3),...
        VertRoad,IndGoodAll);

    legend(hRoad,NameRoad{:},...
        'Location',SelectedLocation)

    hcol=colorbar;
    hcol.Title.String='Distance [km]';

    xlim([MinExtremes(1),MaxExtremes(1)])
    ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])
        
        
    set(gca,'visible','off')
    cd(fold_fig)
    exportgraphics(f2,strcat(filename2,'.png'),'Resolution',600);

end



