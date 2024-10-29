%% File loading
cd(fold_var)
load('LandUsesVariables.mat')
load('StudyAreaVariables.mat')

OrthophotoAnswer = 0;
if exist('Orthophoto.mat', 'file')
    load('Orthophoto.mat')
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

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'RefArea',.035, 'Extremes',true);

%% Loading Excel
cd(fold_user)
Sheet_Ass = readcell(FileNameLandUsesAssociation,'Sheet','Association');
CheckColor = cellfun(@ismissing,Sheet_Ass(2:end,3),'UniformOutput',false);
AllLandUnique = Sheet_Ass(2:end,2);

if all([CheckColor{:}])
    % Fig = uifigure; % Remember to comment if in App version
    Options = {'Yes, thanks', 'No, for God!'};
    AssignRndColors = uiconfirm(Fig, ['No colors are set in the Excel association. ' ...
                                      'Do you want to assign a random triplet'], ...
                                     'Window type', 'Options',Options);
    switch AssignRndColors
        case 'Yes, thanks'
            LUColors = rand(length(CheckColor),3).*255;
        case 'No, for God!'
            return
    end
else
    LUColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
                        Sheet_Ass(2:end,3),'UniformOutput',false)); 
end

%% Plot based on user selection
switch NumFigPlot
    case 1
        filename1 = 'AllLandUse';
        fig_lu_all = figure(1);
        ax1 = axes(fig_lu_all);
        hold(ax1,'on')

        set(gcf, 'Name',filename1);
        
        PolygonsPlot = cell(1, size(LandUsePolygonsStudyArea,2));
        for i1 = 1:size(LandUsePolygonsStudyArea,2)
            PolygonsPlot{i1} = plot(LandUsePolygonsStudyArea(i1), 'FaceColor',LUColors(i1,:)./255, ...
                                                                  'FaceAlpha',1, 'EdgeColor','none');
        end
        
        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
            uistack(hdetected,'top')
        end
     
        if exist('LegendPosition', 'var')
            LegendObjects = PolygonsPlot;
            LegendCaption = cellstr(AllLandUnique);

            if InfoDetectedExist
                LegendObjects = [LegendObjects, {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end

            hleg1 = legend([LegendObjects{:}], ...
                            LegendCaption, ...
                           'FontName',SelectedFont, ...
                           'FontSize',SelectedFontSize, ...
                           'Location',LegendPosition, ...
                           'NumColumns',1, ...
                           'Box','off');
            
            hleg1.ItemTokenSize(1) = 3;
            
            legend('AutoUpdate','off')

            fig_rescaler(fig_lu_all, hleg1, LegendPosition)
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(fig_lu_all, strcat(filename1,'.png'), 'Resolution',600);

    case 2
        filename2 = 'ExcludedLandUse';
        fig_lu_excl = figure(2);
        ax2 = axes(fig_lu_excl);
        hold(ax2,'on')

        set(gcf, 'Name',filename2);

        if OrthophotoAnswer
            cellfun(@(x,y) geoshow(x,y, 'FaceAlpha',.5), ZOrtho, ROrtho);
        end

        LUExcludedPlot = cell(1, size(IndexLandUsesToRemove,2));
        for i1 = 1:size(IndexLandUsesToRemove,2)
            LUExcludedPlot{i1} = plot(LandUsePolygonsStudyArea(IndexLandUsesToRemove(i1)), ...
                                      'FaceColor',LUColors(IndexLandUsesToRemove(i1),:)./255, ...
                                      'FaceAlpha',1, 'EdgeColor','none');
        end
        
        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)
        
        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
            uistack(hdetected,'top')
        end
        
        if exist('LegendPosition', 'var')
            LegendObjects = LUExcludedPlot;
            LegendCaption = cellstr(AllLandUnique(IndexLandUsesToRemove));

            if InfoDetectedExist
                LegendObjects = [LegendObjects, {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end

            hleg1 = legend([LegendObjects{:}], ...
                            LegendCaption, ...
                           'FontName',SelectedFont, ...
                           'FontSize',SelectedFontSize, ...
                           'Location',LegendPosition, ...
                           'NumColumns',1);
            
            hleg1.ItemTokenSize(1) = 3;
                         
            legend('AutoUpdate','off')

            fig_rescaler(fig_lu_excl, hleg1, LegendPosition)
        end
 
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(fig_lu_excl, strcat(filename2,'.png'), 'Resolution',600);
end
cd(fold0)