%% Loading Files
cd(fold_var)
load('GridCoordinates.mat')
load('SoilParameters.mat')
load('StudyAreaVariables.mat')
load('UserSoil_Answers.mat')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'Best';
end

if AnswerAttributionSoilParameter == 1
    load('LithoPolygonsStudyArea.mat')
    load('LUDSCMapParameters.mat')
    
    [n_us, Index4Color_n]     = unique(DSCParameters{1});
    [phi_us, Index4Color_phi] = unique(DSCParameters{2});
    [c_us, Index4Color_c]     = unique(DSCParameters{3});
    [A_us, Index4Color_A]     = unique(DSCParameters{4});
    [kt_us, Index4Color_k]    = unique(DSCParameters{5});

    color_polygons = single(LU_DSCPlotColor{1})./255;

    color_c   = single(LU_DSCPlotColor{2}(Index4Color_c,:))./255;
    color_phi = single(LU_DSCPlotColor{2}(Index4Color_phi,:))./255;
    color_kt  = single(LU_DSCPlotColor{2}(Index4Color_k,:))./255;
    color_A   = single(LU_DSCPlotColor{2}(Index4Color_A,:))./255;
else
    n_us   = unique(nAll{1});
    phi_us = unique(PhiAll{1});
    c_us   = unique(CohesionAll{1});
    A_us   = unique(AAll{1});
    kt_us  = unique(KtAll{1});
    
    color_c   = [0 0 255]./255;
    color_phi = [0 0 255]./255;
    color_kt  = [0 0 255]./255;
    color_A   = [0 0 255]./255;
end

InfoDetectedExist = false;
if exist('InfoDetectedSoilSlips.mat', 'file')
    load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips')
    InfoDetectedExist = true;
end

%% For scatter dimension
RefStudyArea = 0.0417;
ExtentStudyArea = area(StudyAreaPolygon);
% ExtentStudyArea = prod(MaxExtremes-MinExtremes);
RatioRef = ExtentStudyArea/RefStudyArea;
PixelSize = .028/RatioRef;
DetPixelSize = 7.5*PixelSize;

%% Creation of Study Area Matrices
xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudy = cellfun(@(x,y) x(y), yLatAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('yLatAll')

CohesionStudy = cellfun(@(x,y) x(y), CohesionAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('CohesionAll')

PhiStudy = cellfun(@(x,y) x(y), PhiAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('PhiAll')

KtStudy = cellfun(@(x,y) x(y), KtAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('KtAll')

AStudy = cellfun(@(x,y) x(y), AAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('AAll')

c_case = cell(size(c_us,1), length(CohesionStudy));
for i2=1:size(c_us,1)
    c_case(i2,:) = cellfun(@(x) find(x==c_us(i2)), CohesionStudy, 'UniformOutput',false);
end

phi_case = cell(size(phi_us,1), length(PhiStudy));
for i2=1:size(phi_us,1)
    phi_case(i2,:) = cellfun(@(x) find(x==phi_us(i2)), PhiStudy, 'UniformOutput',false);
end

A_case = cell(size(A_us,1), length(AStudy));
for i2=1:size(A_us,1)
    A_case(i2,:) = cellfun(@(x) find(x==A_us(i2)), AStudy, 'UniformOutput',false);
end

kt_case = cell(size(kt_us,1), length(KtStudy));
for i2=1:size(kt_us,1)
    kt_case(i2,:) = cellfun(@(x) find(x==kt_us(i2)), KtStudy, 'UniformOutput',false);
end

%% Plot Case
switch NumFigPlot

    case 1
        filename1 = 'Lithology';
        f1 = figure(1);
        ax1 = axes('Parent',f1); 
        hold(ax1,'on'); 

        set(gcf, 'Name',filename1);  
        
        hplot_litho = cell(1, size(SelectedSoil,1));
        for i2 = 1:size(SelectedSoil,1)
            hplot_litho{i2} = plot(LithoPolygonsStudyArea(SelectedSoil(i2)), ...
                                        'FaceColor',color_polygons(i2,:), ...
                                        'FaceAlpha',1, 'EdgeColor','none');
        end

        plot(MunPolygon, 'FaceColor','none', 'LineWidth',1.5)

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
            uistack(hdetected,'top')
        end
        
        if exist('LegendPosition', 'var')
            LegendObjects = hplot_litho;
            LegendCaption = cellstr(LUAbbr);

            if InfoDetectedExist
                LegendObjects = [LegendObjects, {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end

            hleg1 = legend([LegendObjects{:}], ...
                            LegendCaption, ...
                           'AutoUpdate','off', ...
                           'NumColumns',1, ...
                           'FontName',SelectedFont, ...
                           'FontSize',SelectedFontSize, ...
                           'Location',LegendPosition, ...
                           'Box','off');
    
            hleg1.ItemTokenSize(1) = 10;

            title(hleg1, 'Lithology', 'FontName',SelectedFont, ...
                         'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(f1, hleg1, LegendPosition)
        end

        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f1, strcat(filename1,'.png'), 'Resolution',600);
    
    case 2
        filename2 = 'EffectiveCohesionMap';
        f2 = figure(2);
        ax2 = axes('Parent',f2); 
        hold(ax2,'on'); 

        set(gcf, 'Name',filename2);

        hc = cell(length(c_us), length(xLongStudy));
        for i1 = 1:length(c_us)
            hc(i1,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                'MarkerFaceColor',color_c(i1,:), ...
                                                'MarkerEdgeColor','none'), ...
                                     xLongStudy, yLatStudy, c_case(i1,:), 'UniformOutput',false);
        end

        plot(MunPolygon, 'FaceColor','none', 'LineWidth',1);
        
        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
            uistack(hdetected,'top')
        end

        if exist('LegendPosition', 'var')
            LegendObjects = hc(1:end,1);
            LegendCaption = cellstr(num2str(c_us));

            if InfoDetectedExist
                LegendObjects = [LegendObjects; {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end
        
            hleg2 = legend([LegendObjects{:}], ...
                           LegendCaption, ...
                           'NumColumns',1, ...
                           'FontName',SelectedFont, ...
                           'Location',LegendPosition, ...
                           'FontSize',SelectedFontSize, ...
                           'Box','off');
    
            legend('AutoUpdate','off');
            
            hleg2.ItemTokenSize(1) = 10;
    
            title(hleg2, '{\it c''} [kPa]', 'FontName',SelectedFont, ...
                        'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(f2, hleg2, LegendPosition)
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f2, strcat(filename2,'.png'), 'Resolution',600);

    case 3
        filename3 = 'FrictionMap';
        f3 = figure(3);
        ax3 = axes('Parent',f3); 
        hold(ax3,'on'); 

        set(gcf, 'Name',filename3);
        
        hphi = cell(length(phi_us), length(xLongStudy));
        for i1 = 1:length(phi_us)
            hphi(i1,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                  'MarkerFaceColor',color_phi(i1,:), ...
                                                  'MarkerEdgeColor','none'), ...
                                     xLongStudy, yLatStudy, phi_case(i1,:), 'UniformOutput',false);
        end

        plot(MunPolygon, 'FaceColor','none', 'LineWidth',1);

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
            uistack(hdetected,'top')
        end

        if exist('LegendPosition', 'var')
            LegendObjects = hphi(1:end,1);
            LegendCaption = cellstr(num2str(phi_us));

            if InfoDetectedExist
                LegendObjects = [LegendObjects; {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end

            hleg3 = legend([LegendObjects{:}], ...
                           LegendCaption, ...
                           'NumColumns',1, ...
                           'FontName',SelectedFont, ...
                           'Location',LegendPosition, ...
                           'FontSize',SelectedFontSize, ...
                           'Box','off');
    
            legend('AutoUpdate','off');
            
            hleg3.ItemTokenSize(1) = 10;
    
            title(hleg3, '{\it \phi''} [°]', 'FontName',SelectedFont, ...
                        'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(f3, hleg3, LegendPosition)
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f3, strcat(filename3,'.png'), 'Resolution',600);

    case 4
        filename4 = 'SoilUnit';
        f4 = figure(4);
        ax4 = axes('Parent',f4); 
        hold(ax4,'on');

        set(gcf, 'Name',filename4); 

        hUnit = cell(1, size(LU_DSCPlotColor{2},1));
        for i1 = 1:size(LU_DSCPlotColor{2},1)
            IndUnit = cellfun(@(x) x==i1, LU2DSC, 'UniformOutput',false);
            hUnit{i1} = plot(LithoPolygonsStudyArea(([IndUnit{:}])), ...
                                'FaceColor',single(LU_DSCPlotColor{2}(i1,:))./255, ...
                                'FaceAlpha',1, 'EdgeColor','none', 'DisplayName',num2str(i1));
        end

        plot(MunPolygon, 'FaceColor','none', 'LineWidth',1);

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
            uistack(hdetected,'top')
        end

        if exist('LegendPosition', 'var')
            IndLeg = find(~cellfun(@isempty, hUnit'));
            LegendCaption = cellstr(string(IndLeg));

            hUnitGood = hUnit(IndLeg);
            LegendObjects = cellfun(@(x) x(1), hUnitGood, 'UniformOutput',false);

            if InfoDetectedExist
                LegendObjects = [LegendObjects, {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end
            
            hleg4 = legend([LegendObjects{:}], ...
                           LegendCaption, ...
                           'AutoUpdate','off', ...
                           'NumColumns',1, ...
                           'FontName',SelectedFont, ...
                           'Location',LegendPosition, ...
                           'FontSize',SelectedFontSize, ...
                           'Box','off');
    
            hleg4.ItemTokenSize(1) = 10;

            title(hleg4, 'SC')

            fig_rescaler(f4, hleg4, LegendPosition)
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f4, strcat(filename4,'.png'), 'Resolution',600);
    
    case 5
        filename5 = 'KtMap';
        f5 = figure(5);
        ax5 = axes('Parent',f5); 
        hold(ax5,'on');

        set(gcf, 'Name',filename5);  
        
        hkt = cell(length(kt_us), length(xLongStudy));
        for i1 = 1:length(kt_us)
            hkt(i1,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                  'MarkerFaceColor',color_kt(i1,:), ...
                                                  'MarkerEdgeColor','none'), ...
                                      xLongStudy, yLatStudy, kt_case(i1,:), 'UniformOutput',false);
        end 

        plot(MunPolygon, 'FaceColor','none', 'LineWidth',1);

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
            uistack(hdetected,'top')
        end

        if exist('LegendPosition', 'var')
            LegendObjects = hkt(1:end,1);
            LegendCaption = cellstr(num2str(round(kt_us,3)));

            if InfoDetectedExist
                LegendObjects = [LegendObjects; {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end
        
            hleg5 = legend([LegendObjects{:}], ...
                           LegendCaption, ...
                           'NumColumns',1, ...
                           'FontName',SelectedFont, ...
                           'Location',LegendPosition, ...
                           'FontSize',SelectedFontSize, ...
                           'Box','off');
    
            legend('AutoUpdate','off');
            
            hleg5.ItemTokenSize(1) = 10;
    
            title(hleg5, '{\it k_t} [1/s]', 'FontName',SelectedFont, ...
                         'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(f5, hleg5, LegendPosition)
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f5, strcat(filename5,'.png'), 'Resolution',600);
    
    case 6
        filename6 = 'AMap';
        f6 = figure(6);
        ax6 = axes('Parent',f6); 
        hold(ax6,'on');

        set(gcf, 'Name',filename6);
        
        hA = cell(length(A_us), length(xLongStudy));
        for i1 = 1:length(A_us)
            hA(i1,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                  'MarkerFaceColor',color_A(i1,:), ...
                                                  'MarkerEdgeColor','none'), ...
                                     xLongStudy, yLatStudy, kt_case(i1,:), 'UniformOutput',false);
        end

        plot(MunPolygon, 'FaceColor','none', 'LineWidth',1);

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
            uistack(hdetected,'top')
        end

        if exist('LegendPosition', 'var')
            LegendObjects = hA(1:end,1);
            LegendCaption = cellstr(num2str(A_us,3));

            if InfoDetectedExist
                LegendObjects = [LegendObjects; {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end

            hleg6 = legend([LegendObjects{:}], ...
                           LegendCaption, ...
                           'NumColumns',1, ...
                           'FontName',SelectedFont, ...
                           'Location',LegendPosition, ...
                           'FontSize',SelectedFontSize, ...
                           'Box','off');
    
            legend('AutoUpdate','off');
            
            hleg6.ItemTokenSize(1) = 10;
    
            title(hleg6, '{\it A} [kPa]', 'FontName',SelectedFont, ...
                         'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(f6, hleg6, LegendPosition)
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f6, strcat(filename6,'.png'), 'Resolution',600);

end