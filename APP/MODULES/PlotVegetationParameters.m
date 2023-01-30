%% Loading Files
cd(fold_var)
load('GridCoordinates.mat')
load('VegetationParameters.mat')
load('StudyAreaVariables.mat')
load('UserD_Answers.mat')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'Best';
end

% if AnswerAttributionSoilParameter == 1 || AnswerAttributionSoilParameter == 2
%     load('VegPolygonsStudyArea.mat')
%     load('VUDVCMapParameters.mat')
%     
%     [n_us, Index4Color_n]     = unique(DSCParameters{1});
%     [phi_us, Index4Color_phi] = unique(DSCParameters{2});
%     [c_us, Index4Color_c]     = unique(DSCParameters{3});
%     [A_us, Index4Color_A]     = unique(DSCParameters{4});
%     [kt_us, Index4Color_k]    = unique(DSCParameters{5});
% 
%     color_polygons = LU_DSCPlotColor{1}./255;
% 
%     color_c   = LU_DSCPlotColor{2}(Index4Color_c,:)./255;
%     color_phi = LU_DSCPlotColor{2}(Index4Color_phi,:)./255;
%     color_kt  = LU_DSCPlotColor{2}(Index4Color_k,:)./255;
%     color_A   = LU_DSCPlotColor{2}(Index4Color_A,:)./255;
% else
%     n_us   = unique(nAll{1});
%     phi_us = unique(PhiAll{1});
%     c_us   = unique(CohesionAll{1});
%     A_us   = unique(AAll{1});
%     kt_us  = unique(KtAll{1});
%     
%     color_c   = [0 0 255]./255;
%     color_phi = [0 0 255]./255;
%     color_kt  = [0 0 255]./255;
%     color_A   = [0 0 255]./255;
% end

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

%% Extraction of points inside study area
xLongStudyArea          = cellfun(@(x,y) x(y), xLongAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudyArea           = cellfun(@(x,y) x(y), yLatAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('yLatAll')

RootCohesionStudyArea   = cellfun(@(x,y) x(y), RootCohesionAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('RootCohesionAll')

BetaStarStudyArea       = cellfun(@(x,y) x(y), BetaStarAll, ...
                                           IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('BetaStarAll')

%% Preliminary operations
RefStudyArea = 0.035;
ExtentStudyArea = area(StudyAreaPolygon);
RatioRef = ExtentStudyArea/RefStudyArea;

BetaMin = min(cellfun(@min, BetaStarStudyArea));
BetaMax = max(cellfun(@max, BetaStarStudyArea));
BetaUnique = linspace(BetaMin, BetaMax, 8)';
color_parametersBetaUnique = flipud(parula(length(BetaUnique)));

if AnswerAttributionVegetationParameter==0
    CrUniqueUV = unique(RootCohesionStudyArea{1});
    
    color_parametersCr = deal([255 222 173]./255);
else
    load('VegPolygonsStudyArea.mat');
    load('VUDVCMapParameters.mat');
    
    % cr_uv = (DVCParameters{1});
    [CrUniqueUV, PosCrUniqueUV] = unique(DVCParameters{1});

    % [~, CorrectOrderCr] = sort(cr_uv); % Forse è qui il problema

    % cr_uv = cr_uv(CorrectOrderCr);

    % BetaUnique = unique([DVCParameters{2}; BetaUnique]); Da modificare
    % per espandere gli estremi se raggiungi livelli più bassi o alti.

    [BetaUniqueUV, PosBetaUniqueUV] = unique(DVCParameters{2});

    color_polygons = single(VU_DVCPlotColors{1})./255;
    color_parameters = single(VU_DVCPlotColors{2})./255;

    color_parametersCr = color_parameters(PosCrUniqueUV,:);
    color_parametersBetaUniqueUV = color_parameters(PosBetaUniqueUV,:);
end

%% Creation of cases
UVNumber = size(CrUniqueUV,1);
cr_case = cell(UVNumber, size(xLongStudyArea,2));
betastar_case = cell(length(BetaUnique), size(xLongStudyArea,2));
if AnswerAttributionVegetationParameter~=0
    betastar_caseUV = cell(length(BetaUniqueUV), size(xLongStudyArea,2));
end
for i1 = 1:size(xLongStudyArea,2)
    for i2 = 1:UVNumber
        cr_case{i2,i1} = find( RootCohesionStudyArea{i1}==CrUniqueUV(i2) );
    end

    for i2 = 1:length(BetaUnique)
        if i2 < length(BetaUnique)
            betastar_case{i2,i1} = find( BetaStarStudyArea{i1}>=BetaUnique(i2) & BetaStarStudyArea{i1}<BetaUnique(i2+1) );
        elseif i2 == length(BetaUnique)
            betastar_case{end,i1} = find( BetaStarStudyArea{i1}==BetaUnique(end) );
        end
    end

    if AnswerAttributionVegetationParameter~=0
        for i2 = 1:length(BetaUniqueUV)
            betastar_caseUV{i2,i1} = find( BetaStarStudyArea{i1}==BetaUniqueUV(i2) );
        end
    end
end

%% Plot based on option choosed
switch NumFigPlot

    case 1
        if AnswerAttributionVegetationParameter == 0
            warning('Vegetation is uniform!')
        else
            filename1 = 'VegetationMap';
            fig_veg = figure(1);
            ax_ind1 = axes(fig_veg);
            hold(ax_ind1,'on')
    
            set(gcf, 'Name',filename1);  
            
            hplot_veg = cell(1, size(SelectedVeg,1));
            for i2 = 1:size(SelectedVeg,1)
                hplot_veg{i2} = plot(VegPolygonsStudyArea(SelectedVeg(i2)), ...
                                                'FaceColor',color_polygons(i2,:), 'Parent',ax_ind1, ...
                                                'FaceAlpha',0.9, 'EdgeColor','none');
            end
            
            plot(MunPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',ax_ind1)
    
            fig_settings(fold0)

            if InfoDetectedExist
                hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                        InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
                uistack(hdetected,'top')
            end

            if exist('LegendPosition', 'var')
                LegendObjects = hplot_veg;
                LegendCaption = cellstr(VUAbbr);

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
        
                hleg1.ItemTokenSize(1) = 5;

                fig_rescaler(fig_veg, hleg1, LegendPosition)
            end
            
            set(gca, 'visible','off')
            
            cd(fold_fig)
            exportgraphics(fig_veg, strcat(filename1,'.png'), 'Resolution',600);
        end
    
    case 2
        filename2 = 'RootCohesionMap';
        fig_root = figure(2);
        ax_ind2 = axes(fig_root);
        hold(ax_ind2,'on')

        set(gcf, 'Name',filename2);  

        hcr = cell(1, size(xLongStudyArea,2));
        for i1 = 1:size(xLongStudyArea,2)
            for i2 = 1:UVNumber
                hcr{i2} = scatter(xLongStudyArea{i1}(cr_case{i2,i1}), ...
                                  yLatStudyArea{i1}(cr_case{i2,i1}), ...
                                  PixelSize, 'o', 'Parent',ax_ind2, ...
                                             'MarkerFaceColor',color_parametersCr(i2,:), ...
                                             'MarkerEdgeColor','none');
             end
        end
   
        plot(MunPolygon, 'FaceColor','none', 'LineWidth',1, 'Parent',ax_ind2);
        
        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
            uistack(hdetected,'top')
        end

        if exist('LegendPosition', 'var')
            LegendObjects = hcr;
            LegendCaption = cellstr(num2str(CrUniqueUV)); 

            if InfoDetectedExist
                LegendObjects = [LegendObjects, {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end

            hleg1 = legend([LegendObjects{:}], ...
                           LegendCaption, ...
                           'NumColumns',1, ...
                           'FontName',SelectedFont, ...
                           'FontSize',SelectedFontSize, ...
                           'Location',LegendPosition, ...
                           'Box','off');
    
            legend('AutoUpdate','off');
            
            hleg1.ItemTokenSize(1) = 10;

            title(hleg1, '{\it c_r} [kPa]', 'FontName',SelectedFont, ...
                         'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(fig_root, hleg1, LegendPosition)
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(fig_root, strcat(filename2,'.png'), 'Resolution',600);

    case 3
        % Option for veg association
        % Fig = uifigure; % Remember to comment if in app version
        if AnswerAttributionVegetationParameter == 0
            ShowOver = false;
        else
            ShowOver = uiconfirm(Fig, 'Do you want to show beta* of veg polygons on top and separately?', ...
                                      'Show veg', 'Options',{'Yes', 'No'});
            if strcmp(ShowOver,'Yes'); ShowOver = true; else; ShowOver = false; end
        end
        
        filename3 = 'BetastarMap';
        fig_beta = figure(3);
        ax_ind3 = axes(fig_beta);
        ax_ind3_UV = axes(fig_beta, 'Visible','off');
        hold(ax_ind3,'on')

        set(fig_beta, 'Name',filename3);  
        
        hbetastar = cell(1, size(xLongStudyArea,2));
        for i1 = 1:size(xLongStudyArea,2)
            for i2 = length(BetaUnique):-1:1
                if ~isempty(betastar_case{i2,i1})
                    hbetastar{i2} = scatter(xLongStudyArea{i1}(betastar_case{i2,i1}), ...
                                            yLatStudyArea{i1}(betastar_case{i2,i1}), ...
                                            PixelSize, 'o', 'Parent',ax_ind3, ...
                                            'MarkerFaceColor',color_parametersBetaUnique(i2,:), ...
                                            'MarkerEdgeColor','none');
                end
            end

            if ShowOver
                hbetastarUV = cell(1, length(BetaUniqueUV));
                for i2 = length(BetaUniqueUV):-1:1
                    if ~isempty(betastar_caseUV{i2,i1})
                        hbetastarUV{i2} = scatter(xLongStudyArea{i1}(betastar_caseUV{i2,i1}), ...
                                                  yLatStudyArea{i1}(betastar_caseUV{i2,i1}), ...
                                                  PixelSize, '^', 'Parent',ax_ind3, ...
                                                  'MarkerFaceColor',color_parametersBetaUniqueUV(i2,:), ...
                                                  'MarkerEdgeColor','none');
                    end
                end
            end
        end
        
        plot(MunPolygon, 'FaceColor','none', 'LineWidth',1, 'Parent',ax_ind3);

        set(fig_beta, 'CurrentAxes',ax_ind3)
        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
            uistack(hdetected,'top')
        end

        % Legend 1
        if exist('LegendPosition', 'var')
            LegendObjects1 = hbetastar;
            ValuesBeta = round(BetaUnique,2);
            LegendCaption1 = cellstr([strcat(string(ValuesBeta(1:end-1)), " - ", string(ValuesBeta(2:end))); "1"]);

            if InfoDetectedExist
                LegendObjects1 = [LegendObjects1, {hdetected(1)}];
                LegendCaption1 = [LegendCaption1; {"Points Analyzed"}];
            end

%             LegendObjects = [hbetastar, hbetastarUV];
%             ValuesBeta = round(BetaUnique,2);
%             ValuesBetaUV = round(BetaUniqueUV,2);
%             LegendCaption = [strcat(string(ValuesBeta(1:end-1)), " - ", string(ValuesBeta(2:end)))
%                              "1"
%                              string(ValuesBetaUV)];

            leg1 = legend(ax_ind3, ...
                          [LegendObjects1{:}], ...
                          LegendCaption1, ...
                          'NumColumns',1, ...
                          'FontName',SelectedFont, ...
                          'FontSize',SelectedFontSize, ...
                          'Location',LegendPosition, ...
                          'Box','off', ...
                          'AutoUpdate','off');
            
            leg1.ItemTokenSize(1) = 5; % Cambia perchè non ha senso fare solo (1)
            
            title(leg1, '1-{\it \beta^*} [-]', 'FontName',SelectedFont, ...
                        'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(fig_beta, leg1, LegendPosition)
        end

        % Legend 2, is important to do this operation after fig_settings!
        if exist('LegendPosition', 'var') && ShowOver
            LegendObjects2 = hbetastarUV;
            LegendCaption2 = string(round(BetaUniqueUV,2));

            leg2Pos = get(leg1,'position');
            HeightBox = leg2Pos(4)/1.35; % The new legend has no title but the previous yes
            RatioLeg = length(LegendCaption2)/length(LegendCaption1)/1.5; % 1.5 to consider title and no title
            leg2Pos(1) = leg2Pos(1)+leg2Pos(3);
            leg2Pos(2) = leg2Pos(2)+HeightBox/2-leg2Pos(4)*RatioLeg/2.2; % 2.2 instead of 2 for a little offset
            leg2Pos(4) = leg2Pos(4)*RatioLeg;

            leg2 = legend(ax_ind3_UV, ...
                          [LegendObjects2{:}], ...
                          LegendCaption2, ...
                          'NumColumns',1, ...
                          'FontName',SelectedFont, ...
                          'FontSize',SelectedFontSize, ...
                          'Box','off', ...
                          'AutoUpdate','off', ...
                          'Position',leg2Pos);

            leg2.ItemTokenSize(1) = 5;
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(fig_beta, strcat(filename3,'.png'), 'Resolution',600);

    case 4
        filename4 = 'VegetationUnit';
        f4 = figure(4);
        ax4 = axes('Parent',f4);
        hold(ax4,'on');
        
        set(gcf, 'Name',filename4);
        
        hUnit = cell(1, size(VU_DVCPlotColors{2},1));
        for i1 = 1:size(VU_DVCPlotColors{2},1)
            IndUnit = cellfun(@(x) x==i1, VU2DVC, 'UniformOutput',false);
            hUnit{i1} = plot(VegPolygonsStudyArea(([IndUnit{:}])), ...
                                'FaceColor',single(VU_DVCPlotColors{2}(i1,:))./255, ...
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
        
            title(hleg4, 'VC')
        
            fig_rescaler(f4, hleg4, LegendPosition)
        end
    
        set(gca, 'visible','off')
        
        cd(fold_fig)
        exportgraphics(f4, strcat(filename4,'.png'), 'Resolution',600);

end