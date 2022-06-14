cd(fold_var)
load('LandUsesVariables.mat');
load('StudyAreaVariables.mat');

OrthophotoAnswer=0;
if exist("Orthophoto.mat")
    load("Orthophoto.mat")
    OrthophotoAnswer=1;
end



if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont='Times New Roman';
    SelectedFontSize=8;
    SelectedLocation='Best';
end

cd(fold_user)
Sheet_Ass=readcell(FileName_LandUsesAssociation,'Sheet','Association');
CheckColor=cellfun(@ismissing,Sheet_Ass(2:end,3),'UniformOutput',false);
AllLandUnique=Sheet_Ass(2:end,2);


if all([CheckColor{:}])
    answer = questdlg('No colors are set in the Excel association. Do you want to assign a random triplet', ...
                	  'No color', ...
                	  'Yes, thanks','No, for God!','No, for God!');
    switch answer
        case 'Yes, thanks'
            LUColors=rand(length(CheckColor),3).*255;
        case 'No, for God!'
            return
    end
else

LUColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
                        Sheet_Ass(2:end,3),'UniformOutput',false)); 
end

%%
switch NumFigPlot
    case 1
        filename1='AllLandUse';
        f1=figure(1);
        set(f1 , ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98 ],...    
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 30 12],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename1);
        
        for i1=1:size(LandUsePolygonsStudyArea,2)
            plot(LandUsePolygonsStudyArea(i1),'FaceColor',LUColors(i1,:)./255,'FaceAlpha',1,'EdgeColor','none')
            hold on
        end

        
        plot(StudyAreaPolygon,'FaceColor','none')
        hold on
        PlotScaleBar
        
        hleg1=legend(AllLandUnique,...
                    'FontName',SelectedFont,...
                    'FontSize',SelectedFontSize,...
                    'Location',SelectedLocation,...
                    'NumColumns',2);
        
        hleg1.ItemTokenSize(1)=4;
        
        xlim([MinExtremes(1),MinExtremes(1)+2*(MaxExtremes(1)-MinExtremes(1))])
        ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005]) 
        
        legend boxoff
        legend('AutoUpdate','off')

        
        comprose(14.1068,37.65,8,0.015,0)
        text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',SelectedFontSize)
        
        
        set(gca,'visible','off')

        cd(fold_fig)
        exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);

%%

    case 2
        filename2='ExcludedLandUse';
        f2=figure(2);
        set(f2 , ...
            'Color',[1 1 1],...
            'PaperType','a4',...
            'PaperSize',[29.68 20.98 ],...    
            'PaperUnits', 'centimeters',...
            'PaperPositionMode','manual',...
            'PaperPosition', [0 1 20 12],...
            'InvertHardcopy','off');
        set( gcf ,'Name' , filename2);
        
        axes2 = axes('Parent',f2); 
        hold(axes2,'on');

        if OrthophotoAnswer
            cellfun(@(x,y) geoshow(x,y,'FaceAlpha',.5),ZOrtho,ROrtho);
        end

        

        for i1=1:size(IndexLandUsesToRemove,2)
            hpol_LUexcluded(i1)=plot(LandUsePolygonsStudyArea(IndexLandUsesToRemove(i1)),...
                'FaceColor',LUColors(IndexLandUsesToRemove(i1),:)./255,'FaceAlpha',1,'EdgeColor','none');
            hold on
        end
        
        plot(StudyAreaPolygon,'FaceColor','none')
        hold on
        PlotScaleBar
        
        
        hleg1=legend(hpol_LUexcluded,...
            AllLandUnique{IndexLandUsesToRemove},...
            'FontName',SelectedFont,...
            'FontSize',SelectedFontSize,...
            'Location',SelectedLocation,...
            'NumColumns',1);
        
        hleg1.ItemTokenSize(1)=4;
        
        
        xlim([MinExtremes(1),MaxExtremes(1)])
        ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])
              
        
        legend('AutoUpdate','off')
        
        
        
        comprose(14.1068,37.65,8,0.015,0)
        text(14.103,37.67,'N','FontName',SelectedFont,'FontSize',SelectedFontSize)
        
        
        set(gca,'visible','off')

        cd(fold_fig)
        exportgraphics(f2,strcat(filename2,'.png'),'Resolution',600);
end
cd(fold0)