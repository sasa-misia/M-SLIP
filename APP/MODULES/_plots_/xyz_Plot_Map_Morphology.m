if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'  ], 'StudyAreaPolygon','MunPolygon')
load([fold_var,sl,'GridCoordinates.mat'     ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll','SlopeAll','AspectAngleAll','GradEAll','GradNAll')

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);
[InfoDetExst, InfoDet2Use] = load_info_detected(fold_var);

%% For scatter dimension
PixelScale = 0.35 * abs(yLatAll{1}(2,1) - yLatAll{1}(1,1)) / 6e-05;
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, FinScale=PixelScale);

%% Options
ProgressBar.Message = 'Options...';
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

%% Data extraction
ProgressBar.Message = 'Data extraction...';
xLonStudy  = cellfun(@(x,y) x(y), xLongAll      , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('xLongAll')

yLatStudy  = cellfun(@(x,y) x(y), yLatAll       , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('yLatAll')

ElvtnStudy = cellfun(@(x,y) x(y), ElevationAll  , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('ElevationAll')

SlopeStudy = cellfun(@(x,y) x(y), SlopeAll      , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('SlopeAll')

AspctStudy = cellfun(@(x,y) x(y), AspectAngleAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('AspectAngleAll')

%% Ranges
ProgressBar.Message = 'Definition of ranges for colors...';
ElvtnMin = min(cellfun(@min, ElvtnStudy));
ElvtnMax = max(cellfun(@max, ElvtnStudy));
ElvtnRng = linspace(ElvtnMin, ElvtnMax, 11)';
% ElvRng = [200, 250, 300, 350, 400, 450, 500, 600, 700, 800, 900];

if (ElvtnMax-ElvtnMin) <= 10 % ElvtnMax <= 1000
    VlsElv = round(ElvtnRng, 2, 'significant');
else
    VlsElv = round(ElvtnRng, 0); % VlsElv = round(ElvtnRng, 3, 'significant');
end

LegElvtn = [strcat(string(VlsElv(1:end-1)), " - ", string(VlsElv(2:end)))];

SlopeRng = (0:10:60)';
LegSlope = [strcat(string(SlopeRng(1:end-1)), " - ", string(SlopeRng(2:end))); strcat("> ",string(SlopeRng(end)))];

AspctRng = (0:90:360)';
LegAspct = [strcat(string(AspctRng(1:end-1)), " - ", string(AspctRng(2:end)))];

ClrElv = [ 103, 181, 170;
           127, 195, 186;
           152, 210, 199;
           177, 225, 217;
           200, 232, 226;
           225, 240, 238;
           245, 237, 224;
           240, 227, 200;
           235, 217, 176;
           223, 198, 157;
           213, 179, 136;
           201, 159, 116 ];
    
% ColorSlope = [ 201 160 220
%                143 000 255
%                000 100 025
%                127 255 212
%                000 187 045
%                255 255 102
%                255 153 000 ];

ClrSlope = cool(7)*255;

ClrAspct = [ 201, 160, 220;
             143, 000, 255;
             000, 100, 255;
             127, 255, 212 ];

%% Creation of goups based on ranges
ElvtnInd = cell(length(ElvtnRng)-1, size(ElvtnStudy,2));
for i1 = 1:length(ElvtnRng)-1
    if i1 < length(ElvtnRng)-1
        ElvtnInd(i1,:) = cellfun(@(x) find(x>=ElvtnRng(i1) & x<ElvtnRng(i1+1)) , ElvtnStudy, 'UniformOutput',false);
    else
        ElvtnInd(i1,:) = cellfun(@(x) find(x>=ElvtnRng(i1) & x<=ElvtnRng(i1+1)), ElvtnStudy, 'UniformOutput',false);
    end
end

SlopeInd = cell(length(SlopeRng), size(SlopeStudy,2));
for i1 = 1:length(SlopeRng)
    if i1 < length(SlopeRng)
        SlopeInd(i1,:) = cellfun(@(x) find(x>=SlopeRng(i1) & x<SlopeRng(i1+1)), SlopeStudy, 'UniformOutput',false);
    else
        SlopeInd(i1,:) = cellfun(@(x) find(x>=SlopeRng(i1))                   , SlopeStudy, 'UniformOutput',false);
    end
end

AspctInd = cell(length(AspctRng)-1, size(AspctStudy,2));
for i1 = 1:length(AspctRng)-1
    if i1 < length(AspctRng)-1
        AspctInd(i1,:) = cellfun(@(x) find(x>=AspctRng(i1) & x<AspctRng(i1+1)) , AspctStudy, 'UniformOutput',false);
    else
        AspctInd(i1,:) = cellfun(@(x) find(x>=AspctRng(i1) & x<=AspctRng(i1+1)), AspctStudy, 'UniformOutput',false);
    end
end

%% Plot based on user selection
ProgressBar.Message = 'Plotting...';
for iCase = [NumFigPlot(:)]' % To ensure that it will be horizontal
    %% Names
    switch iCase
        case 1
            CurrFln = 'ElevationRange';
            LegName = 'Elevation [m]';
    
        case 2
            CurrFln = 'SlopeRange';
            LegName = 'Slope angle [°]';
    
        case 3
            CurrFln = 'AspectRange';
            LegName = 'Aspect angle [°]';
    
        otherwise
            error('Plot case not recognized!')
    end

    %% Figure initialization
    CurrFig = figure(iCase);
    CurrAxs = axes('Parent',CurrFig); 
    hold(CurrAxs,'on');
    set(CurrFig, 'Name',CurrFln, 'Visible','off');  
    
    %% Object plot
    switch iCase
        case 1 % Elevation        
            helevation = cell(length(ElvtnRng)-1, size(xLonStudy,2));
            for i1 = 1:length(ElvtnRng)-1
                helevation(i1,:) = cellfun(@(x,y,z) scatter(x(z),y(z), PixelSize, 'Marker','o', ...
                                                            'MarkerFaceColor',ClrElv(i1,:)./255, ...
                                                            'MarkerEdgeColor','none'), ...
                                        	    xLonStudy, yLatStudy, ElvtnInd(i1,:), 'UniformOutput',false);
            end

            if exist('LegPos', 'var')
                LegObjs = helevation(1:end,1);
                LegCaps = cellstr(LegElvtn);
            end
    
        case 2 % Slope            
            hslope = cell(length(SlopeRng), size(xLonStudy,2));
            for i1 = 1:length(SlopeRng)
                hslope(i1,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                                'MarkerFaceColor',ClrSlope(i1,:)./255, ...
                                                                'MarkerEdgeColor','none'), ...
                                            xLonStudy, yLatStudy, SlopeInd(i1,:), 'UniformOutput',false);
            end

            if exist('LegPos', 'var')
                LegObjs = hslope(1:end,1);
                LegCaps = cellstr(LegSlope);
            end
    
        case 3 % Aspect           
            haspect = cell(length(AspctRng)-1, size(xLonStudy,2));
            for i1 = 1:length(AspctRng)-1
                haspect(i1,:) = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                            'MarkerFaceColor',ClrAspct(i1,:)./255, ...
                                                            'MarkerEdgeColor','none'), ...
                                            xLonStudy, yLatStudy, AspctInd(i1,:), 'UniformOutput',false);
            end

            if exist('LegPos', 'var')
                LegObjs = haspect(1:end,1);
                LegCaps = cellstr(LegAspct);
            end
    end

    %% Finalizing
    plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)
    plot(MunPolygon      , 'FaceColor','none', 'LineWidth',1  )
    
    fig_settings(fold0)

    if InfoDetExst
        DetObjs = arrayfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDet2Use{:,5}, InfoDet2Use{:,6});
        uistack(DetObjs,'top')
    end
    
    if exist('LegPos', 'var')
        if InfoDetExst
            LegObjs = [LegObjs; {DetObjs(1)}       ];
            LegCaps = [LegCaps; {"Points Analyzed"}];
        end

        CurrLeg = legend(CurrAxs, ...
                         [LegObjs{:}], LegCaps, 'AutoUpdate','off', ...
                                                'NumColumns',2, ...
                                                'FontName',SlFont, ...
                                                'FontSize',SlFnSz, ...
                                                'Location',LegPos, ...
                                                'Box','off');

        CurrLeg.ItemTokenSize(1) = 5;

        title(CurrLeg, LegName, 'FontName',SlFont, 'FontSize',SlFnSz*1.2, 'FontWeight','bold')

        fig_rescaler(CurrFig, CurrLeg, LegPos)
    end

    set(CurrAxs, 'Visible','off')

    exportgraphics(CurrFig, [fold_fig,sl,CurrFln,'.png'], 'Resolution',600);

    % Show Fig
    if ShowPlots
        set(CurrFig, 'Visible','on');
    else
        close(CurrFig)
    end
end