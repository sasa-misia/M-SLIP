cd(fold_var)

if exist('ScalebarSettings.mat') 
    load('ScalebarSettings.mat');
else
    PositionScaleBar='southwest';
end

DimScalStandard=[0.01 0.02 0.05 0.1 0.2 0.5 1 2 5 10 20 50];
DimWindowkm=deg2km(MaxExtremes(1)-MinExtremes(1));


[~,IndScal]=min(abs(DimWindowkm/5-DimScalStandard));
DimScalX=DimScalStandard(IndScal); %In km


dScaleBarX=km2deg(DimScalX);
dScaleBarY=dScaleBarX/10;



switch PositionScaleBar
    case 'northwest'
        xPoint1=MinExtremes(1)+dScaleBarY;
        yPoint1=MaxExtremes(2)-2*dScaleBarY;

    case 'southwest'
        xPoint1=MinExtremes(1)+dScaleBarY;
        yPoint1=MinExtremes(2)+dScaleBarY;
    
    case 'northeast'
        xPoint1=MaxExtremes(1)-dScaleBarY-dScaleBarX;
        yPoint1=MaxExtremes(2)-2*dScaleBarY;

    case 'southeast'
        xPoint1=MaxExtremes(1)-dScaleBarY-dScaleBarX;
        yPoint1=MinExtremes(2)+dScaleBarY;

end

xPoint2=xPoint1+dScaleBarX/2;
xPoint3=xPoint2+dScaleBarX/2;

yPoint2=yPoint1+dScaleBarY;



pol_scalebar1=polyshape([xPoint1 xPoint2 xPoint2 xPoint1],...
            [yPoint1 yPoint1 yPoint2 yPoint2]);

pol_scalebar2=polyshape([xPoint2 xPoint3 xPoint3 xPoint2],...
            [yPoint1 yPoint1 yPoint2 yPoint2]);

plot(pol_scalebar1,'FaceColor',[0 0 0],'EdgeColor','k','FaceAlpha',1,'LineWidth',0.5)
hold on
plot(pol_scalebar2,'FaceColor','none','EdgeColor','k','FaceAlpha',1,'LineWidth',0.5)

text(xPoint1,yPoint1-dScaleBarY/2,'0','FontName',SelectedFont,'FontSize',SelectedFontSize)
text(xPoint2,yPoint1-dScaleBarY/2,num2str(DimScalX/2),'FontName',SelectedFont,'FontSize',SelectedFontSize)
text(xPoint3,yPoint1-dScaleBarY/2,num2str(DimScalX),'FontName',SelectedFont,'FontSize',SelectedFontSize)

text(xPoint3,yPoint2+dScaleBarY/2,'km','FontName',SelectedFont,'FontSize',SelectedFontSize)