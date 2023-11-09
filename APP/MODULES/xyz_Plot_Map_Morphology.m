%% File loading
cd(fold_var)
load('StudyAreaVariables.mat')
load('GridCoordinates.mat')
load('MorphologyParameters.mat')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'Best';
end

InfoDetectedExist = false;
if exist('InfoDetectedSoilSlips.mat', 'file')
    load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetectedExist = true;
end

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon);

%% Data extraction
xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudy = cellfun(@(x,y) x(y), yLatAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('yLatAll')

ElevationStudy = cellfun(@(x,y) x(y), ElevationAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('ElevationAll')

SlopeStudy = cellfun(@(x,y) x(y), SlopeAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('SlopeAll')

AspectStudy = cellfun(@(x,y) x(y), AspectAngleAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('AspectAngleAll')

GradEStudy = cellfun(@(x,y) x(y), GradEAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('GradEAll')

GradNStudy = cellfun(@(x,y) x(y), GradNAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('GradNAll')

%% Ranges
AltMin = min(cellfun(@min, ElevationStudy));
AltMax = max(cellfun(@max, ElevationStudy));
AltRange = linspace(AltMin, AltMax, 11)';
% AltRange = [200, 250, 300, 350, 400, 450, 500, 600, 700, 800, 900];

if AltMax <= 1000
    ValuesAlt = round(AltRange, 2, 'significant');
else
    ValuesAlt = round(AltRange, 3, 'significant');
end

LegendCaptionAlt = [strcat(string(ValuesAlt(1:end-1)), " - ", string(ValuesAlt(2:end)))];

SlopeRange = (0:10:60)';
LegendCaptionSlope = [strcat(string(SlopeRange(1:end-1)), " - ", string(SlopeRange(2:end))); strcat("> ",string(SlopeRange(end)))];

AspectRange = (0:90:360)';
LegendCaptionAspect = [strcat(string(AspectRange(1:end-1)), " - ", string(AspectRange(2:end)))];

ColorElevation = [ 103 181 170
                   127 195 186
                   152 210 199
                   177 225 217
                   200 232 226
                   225 240 238
                   245 237 224
                   240 227 200
                   235 217 176
                   223 198 157
                   213 179 136
                   201 159 116 ];
    
% ColorSlope = [ 201 160 220
%                143 000 255
%                000 100 025
%                127 255 212
%                000 187 045
%                255 255 102
%                255 153 000 ];

ColorSlope = cool(7)*255;

ColorAspect = [ 201 160 220
                143 000 255
                000 100 255
                127 255 212 ];

%% Creation of goups based on ranges
ElevationIndex = cell(length(AltRange)-1, size(ElevationStudy,2));
for i1 = 1:length(AltRange)-1
    if i1 < length(AltRange)-1
        ElevationIndex(i1,:) = cellfun(@(x) find(x>=AltRange(i1) & x<AltRange(i1+1)), ElevationStudy, 'UniformOutput',false);
    else
        ElevationIndex(i1,:) = cellfun(@(x) find(x>=AltRange(i1) & x<=AltRange(i1+1)), ElevationStudy, 'UniformOutput',false);
    end
end

SlopeIndex = cell(length(SlopeRange), size(SlopeStudy,2));
for i1 = 1:length(SlopeRange)
    if i1 < length(SlopeRange)
        SlopeIndex(i1,:) = cellfun(@(x) find(x>=SlopeRange(i1) & x<SlopeRange(i1+1)), SlopeStudy, 'UniformOutput',false);
    else
        SlopeIndex(i1,:) = cellfun(@(x) find(x>=SlopeRange(i1)), SlopeStudy, 'UniformOutput',false);
    end
end

AspectIndex = cell(length(AspectRange)-1, size(AspectStudy,2));
for i1 = 1:length(AspectRange)-1
    if i1 < length(AspectRange)-1
        AspectIndex(i1,:) = cellfun(@(x) find(x>=AspectRange(i1) & x<AspectRange(i1+1)), AspectStudy, 'UniformOutput',false);
    else
        AspectIndex(i1,:) = cellfun(@(x) find(x>=AspectRange(i1) & x<=AspectRange(i1+1)), AspectStudy, 'UniformOutput',false);
    end
end

%% Plot based on user selection
switch NumFigPlot
    case 1
        %% Elevation
        filename1 = 'Elevation_Range';
        f1 = figure(1);
        ax1 = axes('Parent',f1); 
        hold(ax1,'on'); 

        set(gcf, 'Name',filename1); 
        
        helevation = cell(length(AltRange)-1, size(xLongStudy,2));
        for i1 = 1:length(AltRange)-1
            helevation(i1,:) = cellfun(@(x,y,z) scatter(x(z),y(z), PixelSize, 'Marker','o', ...
                                                        'MarkerFaceColor',ColorElevation(i1,:)./255, ...
                                                        'MarkerEdgeColor','none'), ...
                                        	xLongStudy, yLatStudy, ElevationIndex(i1,:), 'UniformOutput',false);
        end       
        
        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
            uistack(hdetected,'top')
        end

        if exist('LegendPosition', 'var')
            LegendObjects = helevation(1:end,1);
            LegendCaption = cellstr(LegendCaptionAlt);

            if InfoDetectedExist
                LegendObjects = [LegendObjects; {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end

            hleg3 = legend([LegendObjects{:}], ...
                            LegendCaption, ...
                           'NumColumns',2, ...
                           'FontName',SelectedFont, ...
                           'FontSize',SelectedFontSize, ...
                           'Location',LegendPosition, ...
                           'Box','off');
            
            legend('AutoUpdate','off');
            hleg3.ItemTokenSize(1) = 5;
            
            title(hleg3, 'Elevation [m]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(f1, hleg3, LegendPosition)
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f1, strcat(filename1,'.png'), 'Resolution',600);

    case 2
        %% Slope
        filename2 = 'sub_slope';
        f2 = figure(2);
        ax2 = axes('Parent',f2); 
        hold(ax2,'on');

        set(gcf, 'Name',filename2);
        
        hslope = cell(length(SlopeRange), size(xLongStudy,2));
        for i1 = 1:length(SlopeRange)
            hslope(i1,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                            'MarkerFaceColor',ColorSlope(i1,:)./255, ...
                                                            'MarkerEdgeColor','none'), ...
                                        xLongStudy, yLatStudy, SlopeIndex(i1,:), 'UniformOutput',false);
        end

        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
            uistack(hdetected,'top')
        end
        
        if exist('LegendPosition', 'var')
            LegendObjects = hslope(1:end,1);
            LegendCaption = cellstr(LegendCaptionSlope);

            if InfoDetectedExist
                LegendObjects = [LegendObjects; {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end

            hleg = legend([LegendObjects{:}], ...
                           LegendCaption, ...
                          'NumColumns',2, ...
                          'FontName',SelectedFont, ...
                          'Location',LegendPosition, ...
                          'FontSize',SelectedFontSize, ...
                          'Box','off');

            hleg.ItemTokenSize(1) = 5;
            legend('AutoUpdate','off');
    
            title(hleg, 'Slope angle [°]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(f2, hleg, LegendPosition)
        end

        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f2, strcat(filename2,'.png'), 'Resolution',600);

    case 3 
        %% Aspect
        filename3 = 'sub_aspect';
        f3 = figure(3);
        ax3 = axes('Parent',f3); 
        hold(ax3,'on');

        set(gcf, 'Name',filename3);
        
        haspect = cell(length(AspectRange)-1, size(xLongStudy,2));
        for i1 = 1:length(AspectRange)-1
            haspect(i1,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                        'MarkerFaceColor',ColorAspect(i1,:)./255, ...
                                                        'MarkerEdgeColor','none'), ...
                                        xLongStudy, yLatStudy, AspectIndex(i1,:), 'UniformOutput',false);
        end
        
        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
            uistack(hdetected,'top')
        end
        
        if exist('LegendPosition', 'var')
            LegendObjects = haspect(1:end,1);
            LegendCaption = cellstr(LegendCaptionAspect);

            if InfoDetectedExist
                LegendObjects = [LegendObjects; {hdetected(1)}];
                LegendCaption = [LegendCaption; {"Points Analyzed"}];
            end

            hleg2 = legend([LegendObjects{:}], ...
                            LegendCaption, ...
                           'NumColumns',2, ...
                           'FontName',SelectedFont, ...
                           'Location',LegendPosition, ...
                           'FontSize',SelectedFontSize, ...
                           'Box','off');
            
            hleg2.ItemTokenSize(1) = 5;
            legend('AutoUpdate','off');
            
            title(hleg2, 'Aspect angle [°]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')

            fig_rescaler(f3, hleg2, LegendPosition)
        end
        
        set(gca, 'visible','off')

        cd(fold_fig)
        exportgraphics(f3, strcat(filename3,'.png'), 'Resolution',600);
end