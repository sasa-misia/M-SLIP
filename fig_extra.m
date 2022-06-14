function [] = fig_extra(varargin)
% FIGURE CON SCALIMETRI E BUSSOLE
%   Se non si specificano le variabili allora verrà eseguita per intero,
%   altrimenti:
%   'ScaleBar' per disegnare lo scalimetro
%   'CompassRose' per disegnare la bussola 
%   'AxisTick' per avere gli assi lat e lon con le tacche
%   'PositionScaleBar','position' (northeast / northwest / southeast[default] / southwest)
%   'PositionCompassRose','position' (northeast / northwest[default] / southeast / southwest)

load('os_folders.mat','fold_var','fold0');
cd(fold_var)
load('StudyAreaVariables','MaxExtremes','MinExtremes')
if exist('LegendSettings.mat','file')
    load('LegendSettings.mat', 'SelectedFont', 'SelectedFontSize')
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    PositionScaleBar = 'southeast';
    PositionComprose = 'northwest';
end
cd(fold0)

if isempty(varargin); varargin = {'ScaleBar', 'CompassRose', 'AxisTick'}; end

convert = cellfun(@ischar, varargin);
varargin(convert) = cellfun(@(x) lower(string(x)), varargin(convert), 'Uniform',false);

InputPosScaleBar = find(cellfun(@(x) strcmpi(x, "positionscalebar"), varargin));
if InputPosScaleBar; PositionScaleBar = varargin{InputPosScaleBar+1}; end

InputComprose = find(cellfun(@(x) strcmpi(x, "positioncompassrose"), varargin));
if InputComprose; PositionComprose = varargin{InputComprose+1}; end

dExtremes = [MaxExtremes(1)-MinExtremes(1), MaxExtremes(2)-MinExtremes(2)];
xlim([MinExtremes(1)-dExtremes(1)/15, MaxExtremes(1)+dExtremes(1)/15])
ylim([MinExtremes(2)-dExtremes(2)/15, MaxExtremes(2)+dExtremes(2)/15])
xtickformat('degrees')
ytickformat('degrees')

if any( [varargin{:}] == "compassrose" )

    switch PositionComprose
        case "northwest"
            xComp = MinExtremes(1)+dExtremes(1)/30;
            yComp = MaxExtremes(2)-dExtremes(2)/30;
    
        case "southwest"
            xComp = MinExtremes(1)+dExtremes(1)/30;
            yComp = MinExtremes(2)+dExtremes(2)/30;
        
        case "northeast"
            xComp = MaxExtremes(1)-dExtremes(1)/30;
            yComp = MaxExtremes(2)-dExtremes(2)/30;
    
        case "southeast"
            xComp = MaxExtremes(1)-dExtremes(1)/30;
            yComp = MinExtremes(2)+dExtremes(2)/30;
    end

    comprose(xComp, yComp, 8, dExtremes(1)/35, 0, SelectedFontSize/1.2)

end

if any( [varargin{:}] == "scalebar" )
    DimScalStandard = [1 2 5 10 20 50];
    DimWindowKm = deg2km(MaxExtremes(1)-MinExtremes(1));
    [~,IndScal] = min(abs(DimWindowKm/5-DimScalStandard));
    DimScalX = DimScalStandard(IndScal); % In km
    dScaleBarX = km2deg(DimScalX);
    dScaleBarY = dScaleBarX/15;

    switch PositionScaleBar
        case "northwest"
            xPoint1 = MinExtremes(1)+dScaleBarY;
            yPoint1 = MaxExtremes(2)-2*dScaleBarY;
    
        case "southwest"
            xPoint1 = MinExtremes(1)+dScaleBarY;
            yPoint1 = MinExtremes(2)+dScaleBarY;
        
        case "northeast"
            xPoint1 = MaxExtremes(1)-dScaleBarY-dScaleBarX;
            yPoint1 = MaxExtremes(2)-2*dScaleBarY;
    
        case "southeast"
            xPoint1 = MaxExtremes(1)-dScaleBarY-dScaleBarX;
            yPoint1 = MinExtremes(2)+dScaleBarY;
    end
    
    xPoint2 = xPoint1+dScaleBarX/2;
    xPoint3 = xPoint2+dScaleBarX/2;
    yPoint2 = yPoint1+dScaleBarY;
    
    pol_scalebar1 = polyshape([xPoint1 xPoint2 xPoint2 xPoint1],...
                              [yPoint1 yPoint1 yPoint2 yPoint2]);
    
    pol_scalebar2 = polyshape([xPoint2 xPoint3 xPoint3 xPoint2],...
                              [yPoint1 yPoint1 yPoint2 yPoint2]);
    
    plot(pol_scalebar1,'FaceColor',[0 0 0],'EdgeColor','k','FaceAlpha',1,'LineWidth',0.5)
    hold on
    plot(pol_scalebar2,'FaceColor','none','EdgeColor','k','FaceAlpha',1,'LineWidth',0.5)
    
    text(xPoint1, yPoint1-dScaleBarY, '0', 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
    text(xPoint2, yPoint1-dScaleBarY, num2str(DimScalX/2), 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
    text(xPoint3, yPoint1-dScaleBarY, strcat(num2str(DimScalX)," km"), 'FontName',SelectedFont, 'FontSize',SelectedFontSize)
end

if any( [varargin{:}] == "axistick" )
    set(gca,'Box','on',...
        'TickDir','out',...
        'XTick',MinExtremes(1):dExtremes(1)/6:MaxExtremes(1),...
        'YTick',MinExtremes(2):dExtremes(2)/6:MaxExtremes(2),...
        'FontName',SelectedFont);
        grid off
end

daspect([1 1 1])

end