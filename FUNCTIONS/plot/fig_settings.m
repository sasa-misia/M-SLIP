function [] = fig_settings(fold0, varargin)
% FIGURE CON SCALIMETRI E BUSSOLE
%   Se non si specificano le variabili allora verrà eseguita per intero,
%   altrimenti:
%   'ScaleBar' per disegnare lo scalimetro
%   'CompassRose' per disegnare la bussola 
%   'AxisTick' per avere gli assi lat e lon con le tacche
%   'PositionScaleBar','position' (northeast / northwest / southeast[default] / southwest)
%   'PositionCompassRose','position' (northeast / northwest[default] / southeast / southwest)
%   'SetExtremes',var (var must be 4x2 matrix with the 4 extremes, starting from bottom left to top left)
%   'ScaleBarBox' to plot the scalimeter in a box with white background

%% Preliminary Operations
sl = filesep;

load([fold0,sl,'os_folders.mat'], 'fold_var','fold0');

load([fold_var,sl,'StudyAreaVariables'], 'MaxExtremes','MinExtremes')
if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'FigSettingsInputs','Font','FontSize')
    if isempty(varargin) && isempty(FigSettingsInputs) % If is empty, nothing must be excecute except for daspect
        varargin = {'None'};
    elseif isempty(varargin) && ~isempty(FigSettingsInputs)
        varargin = FigSettingsInputs;
    elseif ~isempty(varargin)
        InputPosScaleBar = find(cellfun(@(x) strcmpi(x, "positionscalebar"), FigSettingsInputs));
        if InputPosScaleBar; PositionScaleBar = FigSettingsInputs{InputPosScaleBar+1}; end   
        InputComprose = find(cellfun(@(x) strcmpi(x, "positioncompassrose"), FigSettingsInputs));
        if InputComprose; PositionComprose = FigSettingsInputs{InputComprose+1}; end
    end
    SelectedFont     = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont     = 'Times New Roman';
    SelectedFontSize = 8;
    PositionScaleBar = 'southwest';
    PositionComprose = 'northeast';
    if isempty(varargin); varargin = {'ScaleBar', 'CompassRose', 'AxisTick'}; end
end

if ~isempty(varargin)
    convert = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(convert) = cellfun(@(x) lower(string(x)), varargin(convert), 'Uniform',false);

    InputPosScaleBar = find(cellfun(@(x) strcmpi(x, "positionscalebar"), varargin));
    if InputPosScaleBar; PositionScaleBar = varargin{InputPosScaleBar+1}; end
    
    InputComprose = find(cellfun(@(x) strcmpi(x, "positioncompassrose"), varargin));
    if InputComprose; PositionComprose = varargin{InputComprose+1}; end

    InputExtremes = find(cellfun(@(x) strcmpi(x, "setextremes"), varargin));
    if InputExtremes; Extremes = varargin{InputExtremes+1}; varargin(InputExtremes+1) = []; end
end

%% Core
hold(gca, 'on')

if any( [varargin{:}] == "setextremes" )
    MinExtremes = [Extremes(1), Extremes(5)];
    MaxExtremes = [Extremes(3), Extremes(7)];
end

dExtremes = [MaxExtremes(1)-MinExtremes(1), MaxExtremes(2)-MinExtremes(2)];

if any( [varargin{:}] == "compassrose" )
    switch PositionComprose
        case "northwest"
            xComp = MinExtremes(1)+dExtremes(1)/30;
            yComp = MaxExtremes(2)-dExtremes(2)/15;
    
        case "southwest"
            xComp = MinExtremes(1)+dExtremes(1)/30;
            yComp = MinExtremes(2)+dExtremes(2)/30;
        
        case "northeast"
            xComp = MaxExtremes(1)-dExtremes(1)/25;
            yComp = MaxExtremes(2)-dExtremes(2)/15;
    
        case "southeast"
            xComp = MaxExtremes(1)-dExtremes(1)/25;
            yComp = MinExtremes(2)+dExtremes(2)/30;
    end

    comprose(xComp, yComp, 8, dExtremes(1)/35, 0, SelectedFontSize/1.2)
end

if any( [varargin{:}] == "scalebar" )
    DimScalStandard = [0.25, 0.5, 1, 2, 5, 10, 20, 50];
    DimWindowKm     = deg2km(MaxExtremes(1)-MinExtremes(1));
    [~,IndScal]     = min(abs(DimWindowKm/5-DimScalStandard));
    DimScalX        = DimScalStandard(IndScal); % In km
    dScaleBarX      = km2deg(DimScalX);
    dScaleBarY      = dScaleBarX/15;
    dScaleBarOffX   = 3*dScaleBarX/15;
    if exist('PositionComprose', 'var') && strcmp(PositionComprose,PositionScaleBar)
        dScaleBarOffY = 2*dScaleBarOffX;
    else
        dScaleBarOffY = dScaleBarOffX;
    end

    switch PositionScaleBar
        case "northwest"
            xPoint1 = MinExtremes(1)+dScaleBarOffX;
            yPoint1 = MaxExtremes(2)-dScaleBarOffY-dScaleBarY;
    
        case "southwest"
            xPoint1 = MinExtremes(1)+dScaleBarOffX;
            yPoint1 = MinExtremes(2)+1.5*dScaleBarOffY;
        
        case "northeast"
            xPoint1 = MaxExtremes(1)-dScaleBarOffX-dScaleBarX;
            yPoint1 = MaxExtremes(2)-dScaleBarOffY-dScaleBarY;
    
        case "southeast"
            xPoint1 = MaxExtremes(1)-dScaleBarOffX-dScaleBarX;
            yPoint1 = MinExtremes(2)+1.5*dScaleBarOffY;
    end
    
    xPoint2 = xPoint1+dScaleBarX/2;
    xPoint3 = xPoint2+dScaleBarX/2;
    yPoint2 = yPoint1+dScaleBarY;
    
    pol_scalebar1 = polyshape([xPoint1, xPoint2, xPoint2, xPoint1], ...
                              [yPoint1, yPoint1, yPoint2, yPoint2]);
    
    pol_scalebar2 = polyshape([xPoint2, xPoint3, xPoint3, xPoint2], ...
                              [yPoint1, yPoint1, yPoint2, yPoint2]);

    dScTx = 1.1*dScaleBarY*SelectedFontSize/4;
    dTxOr = dScaleBarX/30;

    if any( [varargin{:}] == "scalebarbox" )
        dTxOr   = 0;
        dbox    = 2.2*dScaleBarY;
        dboxdx  = 8*dScaleBarY;
        yoffbox = dScaleBarY+0.8*dScTx;
        pol_box = polyshape([xPoint1-dbox/2,         xPoint3+dbox/2+dboxdx,  xPoint3+dbox/2+dboxdx, xPoint1-dbox/2], ...
                            [yPoint1-dbox/2-yoffbox, yPoint1-dbox/2-yoffbox, yPoint2+dbox/2,        yPoint2+dbox/2]);
        plot(pol_box,'FaceColor',[1 1 1],'EdgeColor','k','FaceAlpha',1,'LineWidth',0.7)
    end

    plot(pol_scalebar1, 'FaceColor',[0 0 0], 'EdgeColor','k', 'FaceAlpha',1, 'LineWidth',1);
    plot(pol_scalebar2, 'FaceColor',[1 1 1], 'EdgeColor','k', 'FaceAlpha',1, 'LineWidth',1);
    
    text(xPoint1-dTxOr, yPoint1-1.1*dScTx, '0', 'FontName',SelectedFont, 'FontSize',SelectedFontSize, 'LineWidth',1);
    if DimScalX > 0.5
        TxNE = [numel(num2str(DimScalX/2)), numel(num2str(DimScalX))];
        text(xPoint2-dTxOr*TxNE(1), yPoint1-1.1*dScTx, num2str(DimScalX/2)      , 'FontName',SelectedFont, 'FontSize',SelectedFontSize, 'LineWidth',1);
        text(xPoint3-dTxOr*TxNE(2), yPoint1-1.1*dScTx, [num2str(DimScalX),' km'], 'FontName',SelectedFont, 'FontSize',SelectedFontSize, 'LineWidth',1);
    else
        TxNE = [numel(num2str(1000*DimScalX/2)), numel(num2str(1000*DimScalX))];
        text(xPoint2-dTxOr*TxNE(1), yPoint1-1.1*dScTx, num2str(1000*DimScalX/2)     , 'FontName',SelectedFont, 'FontSize',SelectedFontSize, 'LineWidth',1);
        text(xPoint3-dTxOr*TxNE(2), yPoint1-1.1*dScTx, [num2str(1000*DimScalX),' m'], 'FontName',SelectedFont, 'FontSize',SelectedFontSize, 'LineWidth',1);
    end
end

if any( [varargin{:}] == "axistick" )
    set(gca,'Box','on', ...
            'TickDir','out', ...
            'XTick',MinExtremes(1):dExtremes(1)/6:MaxExtremes(1), ...
            'YTick',MinExtremes(2):dExtremes(2)/6:MaxExtremes(2), ...
            'FontName',SelectedFont);
    grid off
end

xlim([MinExtremes(1)-dExtremes(1)/15, MaxExtremes(1)+dExtremes(1)/15])
ylim([MinExtremes(2)-dExtremes(2)/15, MaxExtremes(2)+dExtremes(2)/15])

yLatMean     = mean([MinExtremes(2), MaxExtremes(2)]);
dLat1Meter   = rad2deg(1/earthRadius); % 1 m in lat
dLong1Meter  = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long
RatioLatLong = dLat1Meter/dLong1Meter;

xtickformat('degrees')
ytickformat('degrees')

daspect([1, RatioLatLong, 1])
end