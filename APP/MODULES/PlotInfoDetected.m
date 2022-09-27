%% Loading Files
cd(fold_var)
load('StudyAreaVariables.mat')
% load('GridCoordinates.mat')
load('InfoDetectedSoilSlips.mat')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
end

%% Raster CTR Selection
cd(fold0)
fold_raw_ctr = strcat(fold_raw,sl,'CTR');
if ~exist(fold_raw_ctr, 'dir'); mkdir(fold_raw_ctr); end
save('os_folders.mat', 'fold_raw_ctr', '-append');

cd(fold_raw_ctr)
Files = sort(string([{dir('*.tif').name}, ...
                     {dir('*.tfw').name}, ...
                     {dir('*.asc').name}, ...
                     {dir('*.img').name}]));
Choice = listdlg('PromptString',{'Choose a file:',''}, ...
                  'ListString',Files);
FileNameCTR = string(Files(Choice));

if any(contains(FileNameCTR,'tif')) && any(contains(FileNameCTR,'tfw'))
    DTMType = 0;
else
    DTMType = 1;
end

switch DTMType
    case 0
        NameFile1 = FileNameCTR(contains(FileNameCTR,'tif'));
        NameFile2 = FileNameCTR(contains(FileNameCTR,'tfw'));
    case 1
        NameFile1 = FileNameCTR;
end

%% Raster CTR Processing
[xLongCTRStudy, yLatCTRStudy, GrayScaleCTRStudy] = deal(cell(1,length(NameFile1)));

[pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
for i1 = 1:length(NameFile1)
    switch DTMType
        case 0
            A = imread(NameFile1(i1));
            R = worldfileread(NameFile2(i1), 'planar', size(A));  
        case 1
            [A,R] = readgeoraster(NameFile1(i1), 'OutputType','native');
    end

    if isempty(R.ProjectedCRS) && i1==1
        EPSG = str2double(inputdlg({["Set DTM EPSG"
                                     "For Example:"
                                     "Sicily -> 32633"
                                     "Emilia Romagna -> 25832"]}, '', 1, {'32633'}));
        R.ProjectedCRS = projcrs(EPSG);
    elseif isempty(R.ProjectedCRS) && i1>1
        R.ProjectedCRS = projcrs(EPSG);
    end

    [x_lim,y_lim] = mapoutline(R, size(A));
    RasterExtentInWorldX = max(x_lim)-min(x_lim);
    RasterExtentInWorldY = max(y_lim)-min(y_lim);
    dX = RasterExtentInWorldX/(size(A,2)-1);
    dY = RasterExtentInWorldY/(size(A,1)-1);
    [X,Y] = worldGrid(R);

    AnswerChangeCTRResolution = true;
    NewDx = 1;
    NewDy = 1;
    if AnswerChangeCTRResolution
        ScaleFactorX = int64(NewDx/dX);
        ScaleFactorY = int64(NewDy/dY);
    else
        ScaleFactorX = 1;
        ScaleFactorY = 1;
    end

    X = X(1:ScaleFactorX:end, 1:ScaleFactorY:end);
    Y = Y(1:ScaleFactorX:end, 1:ScaleFactorY:end);

    GrayScaleCTR = A(1:ScaleFactorX:end, 1:ScaleFactorY:end);

    if string(R.CoordinateSystemType)=="planar"
        [yLat,xLong] = projinv(R.ProjectedCRS, X, Y);
        LatMin = min(yLat, [], "all");
        LatMax = max(yLat, [], "all");
        LongMin = min(xLong, [], "all");
        LongMax = max(xLong, [], "all");
        RGeo = georefcells([LatMin,LatMax], [LongMin,LongMax], size(GrayScaleCTR));
        RGeo.GeographicCRS = R.ProjectedCRS.GeographicCRS;
    else
        xLong = X;
        yLat  = Y;
        RGeo  = R;
    end

    clear('X', 'Y')

    IndexCTRPointsInsideStudyArea = find(inpoly([xLong(:), yLat(:)], pp1, ee1)==1);

    xLongCTRStudy{i1} = xLong(IndexCTRPointsInsideStudyArea);
    clear('xLong')
    yLatCTRStudy{i1}  = yLat(IndexCTRPointsInsideStudyArea);
    clear('yLat')
    GrayScaleCTRStudy{i1} = GrayScaleCTR(IndexCTRPointsInsideStudyArea);
    clear('GrayScaleCTR')
end

%% Cleaning of CTR files with no intersection (or only a single point)
EmptyIndexCTRPointsInsideStudyArea = cellfun(@(x) numel(x)<=1,xLongCTRStudy);
NameFileIntersecated = NameFile1(~EmptyIndexCTRPointsInsideStudyArea);
xLongCTRStudy(EmptyIndexCTRPointsInsideStudyArea)                   = [];
yLatCTRStudy(EmptyIndexCTRPointsInsideStudyArea)                    = [];
GrayScaleCTRStudy(EmptyIndexCTRPointsInsideStudyArea)               = [];

%% Saving...
cd(fold_var)
VariablesCTR = {'xLongCTRStudy', 'yLatCTRStudy', 'GrayScaleCTRStudy', 'NameFileIntersecated'};
save('StudyCTR.mat', VariablesCTR{:});
cd(fold0)

%% Plot for check
fig_check = figure(2);
ax_check = axes(fig_check);
hold(ax_check,'on')
for i3 = 1:length(xLongCTRStudy)
    fastscatter(xLongCTRStudy{i3}, yLatCTRStudy{i3}, double(GrayScaleCTRStudy{i3}), 'Parent',ax_check)
    colormap(ax_check,'gray')
    % colormap default
    % pause
end

plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1);

title('Study Area Polygon Check')

fig_settings(fold0, 'AxisTick');

%% Figure Creation
RefStudyArea = 0.035;

xLongCTRTot      = cat(1,xLongCTRStudy{:});
yLatCTRTot       = cat(1,yLatCTRStudy{:});
GrayScaleCTRTot  = cat(1,GrayScaleCTRStudy{:});

fold_fig_det = strcat(fold_fig,sl,'Detected points plots');
if ~exist(fold_fig_det,'dir'); mkdir(fold_fig_det); end

Options = {'Yes', 'No'};
Skip = uiconfirm(Fig, 'Do you want to plot Elevation and Slope too?', ...
                      'Tables plot', 'Options',Options);
if strcmp(Skip,'No'); Skip = true; else; Skip = false; end

Classes = cellfun(@(x) table2cell(x(:,1)), InfoPointsNearDetectedSoilSlips(:,7), 'UniformOutput',false);
Classes = unique(string(cat(1, Classes{:})));

IndClassesNS = strcmp(Classes, 'Land Use not specified'); % Not classified, then they will be removed
Classes(IndClassesNS) = [];

PlotColors = arrayfun(@(x) rand(1, 3), Classes, 'UniformOutput',false);

for i1 = 1:length(PolWindow)
    %% Preliminary operations
    fig_class = figure(3);
    ax_ind1 = axes(fig_class);
    hold(ax_ind1,'on')

    ExtentStudyArea = area(PolWindow(i1));
    ExtremesPlot = PolWindow(i1).Vertices;
    [ppWin, eeWin] = getnan2([PolWindow(i1).Vertices; nan, nan]);
    RatioRef = ExtentStudyArea/RefStudyArea;

    Filename1 = strcat("Classes for point n. ",string(i1));
    title(strcat( "Comune: ", string(InfoDetectedSoilSlips{i1,1})), ...
          'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.4, 'Parent',ax_ind1)
    subtitle(strcat( "Cod. IOP: ", string(InfoDetectedSoilSlips{i1,2})), ...
             'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'Parent',ax_ind1)
    set(fig_class, 'Name',Filename1);
    
    PixelSize = .1/RatioRef;

    %% Plot CTR
    IndexCTRInPolWin = find(inpoly([xLongCTRTot, yLatCTRTot], ppWin, eeWin)==1);

    if ~isempty(IndexCTRInPolWin)
        xLongCTRPar     = xLongCTRTot(IndexCTRInPolWin);
        yLatCTRPar      = yLatCTRTot(IndexCTRInPolWin);
        GrayScaleCTRPar = GrayScaleCTRTot(IndexCTRInPolWin);
    
        xLongCTRToPlot  = xLongCTRPar(~logical(GrayScaleCTRPar));
        yLatCTRToPlot   = yLatCTRPar(~logical(GrayScaleCTRPar));
    
        PlotCTR1 = scatter(xLongCTRToPlot, yLatCTRToPlot, 0.5, 'Marker','s', 'MarkerFaceColor','k', ...
                           'MarkerEdgeColor','none', 'MarkerFaceAlpha',1, 'Parent',ax_ind1);
    else
        strcat("Municipality: ", string(InfoDetectedSoilSlips{i1,1}), " does not have CTR")
    end

    %% Plot Classes (LU)
    PointClassNearDSS = string(InfoPointsNearDetectedSoilSlips{i1,4}(:,17)); % This is LU
    PointsNearLong = cell2mat(InfoPointsNearDetectedSoilSlips{i1,4}(:,3));
    PointsNearLat  = cell2mat(InfoPointsNearDetectedSoilSlips{i1,4}(:,4));

    IndexPointClassesInPolWin = find(inpoly([PointsNearLong, PointsNearLat], ppWin, eeWin)==1);

    PointClassNearDSS = PointClassNearDSS(IndexPointClassesInPolWin);
    PointsNearLong    = PointsNearLong(IndexPointClassesInPolWin);
    PointsNearLat     = PointsNearLat(IndexPointClassesInPolWin);
    
    IndClasses = arrayfun(@(x) strcmp(x, PointClassNearDSS), Classes, 'UniformOutput',false);

    IndClassesNotEmpty = cellfun(@(x) any(x), IndClasses);

    IndClasses    = IndClasses(IndClassesNotEmpty);
    ClassesLocal  = Classes(IndClassesNotEmpty);
    PlotColorsLoc = PlotColors(IndClassesNotEmpty);

    PlotClass = cellfun(@(x,z) scatter(PointsNearLong(x), PointsNearLat(x), 0.15*PixelSize, ...
                                       'Marker','o', 'MarkerFaceColor',z, 'MarkerEdgeColor','none', ...
                                       'MarkerFaceAlpha',0.3, 'Parent',ax_ind1), ...
                               IndClasses, PlotColorsLoc, 'UniformOutput',false);

    %% Plot Contour, detected point & extra settings
    PlotContour = plot(PolWindow(i1),'FaceColor','none','LineWidth',1, 'LineStyle','--', 'Parent',ax_ind1);

    PlotDetected = scatter(InfoDetectedSoilSlips{i1,5}, InfoDetectedSoilSlips{i1,6}, PixelSize, ...
                           'Marker','d', 'MarkerFaceColor','r', 'MarkerEdgeColor','k', ...
                           'MarkerFaceAlpha',1, 'LineWidth',1, 'Parent',ax_ind1);

    ax_ind1.XAxis.Visible = 'off';
    ax_ind1.YAxis.Visible = 'off';

    if exist('LegendPosition', 'var')
        LegendObjects = [PlotClass; {PlotDetected}];
        LegendCaption = [ClassesLocal; {'Ponte'}];

        hleg1 = legend([LegendObjects{:}], LegendCaption, ...
                       'FontName',SelectedFont, ...
                       'FontSize',SelectedFontSize, ...
                       'Location',LegendPosition, ...
                       'NumColumns',1);
        
        hleg1.ItemTokenSize(1) = 3;
        
        legend('AutoUpdate','off')
    end

    fig_settings(fold0, 'ScaleBar', 'ScaleBarBox', 'SetExtremes',ExtremesPlot);

    pause

    %% Saving...
    cd(fold_fig_det)
    exportgraphics(fig_class, strcat(Filename1,'.png'), 'Resolution',600);

    close(fig_class)
    % cla(ax_ind1,'reset')
    % clf(fig_class,'reset')

    if Skip; continue; end

    %% Plot Morphology
    fig_morph = figure(4);
    ax_ind2 = axes(fig_morph);
    hold(ax_ind2,'on')

    Filename2 = strcat("Morphology of point n. ",string(i1));
    title(strcat( "Comune: ", string(InfoDetectedSoilSlips{i1,1})), ...
          'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.4, 'Parent',ax_ind2)
    subtitle(strcat( "Cod. IOP: ", string(InfoDetectedSoilSlips{i1,2})), ...
             'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'Parent',ax_ind2)
    set(fig_morph, 'Name',Filename2);

    if ~isempty(IndexCTRInPolWin)
        PlotCTR2 = scatter(xLongCTRToPlot, yLatCTRToPlot, 0.5, 'Marker','s', 'MarkerFaceColor','k', ...
                               'MarkerEdgeColor','none', 'MarkerFaceAlpha',1, 'Parent',ax_ind2);
    end

    PointsNearAlt  = cell2mat(InfoPointsNearDetectedSoilSlips{i1,4}(:,5));
    PointsNearAlt  = PointsNearAlt(IndexPointClassesInPolWin);

    PlotMorph = fastscatter2(PointsNearLong, PointsNearLat, PointsNearAlt, 'FaceAlpha',0.4, 'Parent',ax_ind2);

    colormap(ax_ind2,'pink')
    ColBar = colorbar('Location','southoutside');
    ColBarPos = get(ColBar,'Position');
    ColBarPos(1) = ColBarPos(1)*2.2;
    ColBarPos(2) = ColBarPos(2)-0.3*ColBarPos(2);
    ColBarPos(3:4) = ColBarPos(3:4)*0.6;
    set(ColBar,'Position',ColBarPos)

    PlotContour = plot(PolWindow(i1),'FaceColor','none','LineWidth',1, 'LineStyle','--', 'Parent',ax_ind2);

    PlotDetected = scatter(InfoDetectedSoilSlips{i1,5}, InfoDetectedSoilSlips{i1,6}, PixelSize, ...
                           'Marker','d', 'MarkerFaceColor','r', 'MarkerEdgeColor','k', ...
                           'MarkerFaceAlpha',1, 'LineWidth',1, 'Parent',ax_ind2);

    ax_ind2.XAxis.Visible = 'off';
    ax_ind2.YAxis.Visible = 'off';

    fig_settings(fold0, 'ScaleBar', 'ScaleBarBox', 'SetExtremes',ExtremesPlot);

    pause

    %% Saving...
    cd(fold_fig_det)
    exportgraphics(fig_morph, strcat(Filename2,'.png'), 'Resolution',600);
    close(fig_morph)

    %% Plot Slope
    fig_slope = figure(5);
    ax_ind3 = axes(fig_slope);
    hold(ax_ind3,'on')

    Filename3 = strcat("Slope of point n. ",string(i1));
    title(strcat( "Comune: ", string(InfoDetectedSoilSlips{i1,1})), ...
          'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.4, 'Parent',ax_ind3)
    subtitle(strcat( "Cod. IOP: ", string(InfoDetectedSoilSlips{i1,2})), ...
             'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'Parent',ax_ind3)
    set(fig_slope, 'Name',Filename3);

    if ~isempty(IndexCTRInPolWin)
        PlotCTR2 = scatter(xLongCTRToPlot, yLatCTRToPlot, 0.5, 'Marker','s', 'MarkerFaceColor','k', ...
                               'MarkerEdgeColor','none', 'MarkerFaceAlpha',1, 'Parent',ax_ind3);
    end

    PointsNearSlope  = cell2mat(InfoPointsNearDetectedSoilSlips{i1,4}(:,6));
    PointsNearSlope  = PointsNearSlope(IndexPointClassesInPolWin);

    PlotSlope = fastscatter2(PointsNearLong, PointsNearLat, PointsNearSlope, 'FaceAlpha',0.4, 'Parent',ax_ind3);

    colormap(ax_ind3,'cool')
    ColBar = colorbar('Location','southoutside');
    ColBarPos = get(ColBar,'Position');
    ColBarPos(1) = ColBarPos(1)*2.2;
    ColBarPos(2) = ColBarPos(2)-0.3*ColBarPos(2);
    ColBarPos(3:4) = ColBarPos(3:4)*0.6;
    set(ColBar,'Position',ColBarPos)

    PlotContour = plot(PolWindow(i1),'FaceColor','none','LineWidth',1, 'LineStyle','--', 'Parent',ax_ind3);

    PlotDetected = scatter(InfoDetectedSoilSlips{i1,5}, InfoDetectedSoilSlips{i1,6}, PixelSize, ...
                           'Marker','d', 'MarkerFaceColor','r', 'MarkerEdgeColor','k', ...
                           'MarkerFaceAlpha',1, 'LineWidth',1, 'Parent',ax_ind3);

    ax_ind3.XAxis.Visible = 'off';
    ax_ind3.YAxis.Visible = 'off';

    fig_settings(fold0, 'ScaleBar', 'ScaleBarBox', 'SetExtremes',ExtremesPlot);

    pause

    %% Saving...
    cd(fold_fig_det)
    exportgraphics(fig_slope, strcat(Filename3,'.png'), 'Resolution',600);
    close(fig_slope)
end
cd(fold0)