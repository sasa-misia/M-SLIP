if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Cancelable','off', ...
                                 'Message','Reading files...', 'Indeterminate','on');
drawnow

%% File loading
sl = filesep;
load([fold_var,sl,'StudyAreaVariables.mat'],   'StudyAreaPolygon')
load([fold_var,sl,'GridCoordinates.mat'],      'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll')

UseOrtho = false;
if exist([fold_var,sl,'Orthophoto.mat'], 'file')
    load([fold_var,sl,'Orthophoto.mat'], 'ZOrtho','xLongOrtho','yLatOrtho')

    if (numel(ZOrtho) > 1) && iscell(ZOrtho)
        error('Multiple orthophoto cells not yet supported!')
    end

    if iscell(ZOrtho)
        ZOrtho     = ZOrtho{1};
        xLongOrtho = xLongOrtho{1};
        yLatOrtho  = yLatOrtho{1};
    end

    UseOrtho = true;
end

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SelFnt   = Font;
    SelFntSz = 2*FontSize;
    LgndSize = LegendPosition;
else
    SelFnt   = 'Times New Roman';
    SelFntSz = 12;
    LgndSize = 'Best';
end

fold_pth = uigetdir(fold_res_flow, 'Select path folder');
[~, FoldnamePaths] = fileparts(fold_res_flow);

figure(Fig) % To bring forward the Fig

load([fold_pth,sl,'LandslidesPaths.mat'],      'PathsHistory','PathsInfo')

fold_fig_pth = [fold_fig,sl,'Landslide Paths'];
if not(exist(fold_fig_pth, 'dir'))
    mkdir(fold_fig_pth)
end

Depth = PathsInfo{1, 'InstabilityDepth'};

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon);

%% Options
ProgressBar.Message = 'Options...';
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

SelDEM = 1;
if size(PathsHistory, 2) > 1
    DEMNames = PathsHistory.Properties.VariableNames;
    SelDEM   = listdlg2({'DEM you want to use:'}, DEMNames, 'OutType','NumInd');
end

SelLnds = 1;
if size(PathsHistory{1,SelDEM}{:}, 2) > 1
    LndNames = PathsHistory{1,SelDEM}{:}.Properties.VariableNames;
    SelLnds  = checkbox2(LndNames, 'Title',{'Landslides you want to plot:'}, 'OutType','NumInd');
end

SelView = uiconfirm(Fig, 'Do you want to manually select the view for each landslide?', ...
                         'Select view', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(SelView,'Yes'); SelView = true; else; SelView = false; end

GrdView = uiconfirm(Fig, 'Do you want to see grid lines?', ...
                         'Grid lines', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(GrdView,'Yes'); GrdView = 'k'; else; GrdView = 'none'; end

NewOrth = uiconfirm(Fig, 'Do you want to use a new (or different resolution) orthophoto?', ...
                         'New orthophoto', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(NewOrth,'Yes'); NewOrth = true; UseOrtho = true; else; NewOrth = false; end

%% Path video
for i1 = 1:numel(SelLnds)
    %% Path extraction
    StepsNum = size(PathsHistory{'LandsPath',SelDEM}{:}{'PthHistSpeed',SelLnds(i1)}{:}, 1);
    PthGCrds = PathsHistory{'LandsPath',SelDEM}{:}{'PthHistGeo',SelLnds(i1)}{:}(1:StepsNum, :);
    PthGrInd = PathsHistory{'LandsPath',SelDEM}{:}{'GridIndHist',SelLnds(i1)}{:}(1:StepsNum, :);
    PthElev  = PathsHistory{'LandsPath',SelDEM}{:}{'PthElvation',SelLnds(i1)}{:}(1:StepsNum, :);
    PthPrLen = PathsHistory{'LandsPath',SelDEM}{:}{'PthProgLn',SelLnds(i1)}{:}(1:StepsNum, :);
    PthMnSpd = PathsHistory{'LandsPath',SelDEM}{:}{'PthMeanSpeed',SelLnds(i1)}{:};
    PthVols  = PathsHistory{'LandsPath',SelDEM}{:}{'PthVolume',SelLnds(i1)}{:}(1:StepsNum, :);
    PthErDpt = PathsHistory{'LandsPath',SelDEM}{:}{'PthErodedDpth',SelLnds(i1)}{:}(1:StepsNum, :);
    PthStpSl = PathsHistory{'LandsPath',SelDEM}{:}{'PthStpSlope',SelLnds(i1)}{:}(1:StepsNum, :);
    StrtPnt  = [PthGCrds(1,:), PthElev(1)];

    GridSize = PathsInfo{1, 'GridSize'}{SelDEM};
    if not(isequal(floor(GridSize(1)), floor(GridSize(2))))
        error('Sizes od DEM must be equal! Please, contact the support.')
    end
    SideSize = GridSize(1);
    
    CllsArnd = str2double(inputdlg2({'Points around start of landslide:'}, 'DefInp',{'200'}));

    xLonSelDEM = xLongAll{SelDEM};
    yLatSelDEM = yLatAll{SelDEM};
    ElevSelDEM = ElevationAll{SelDEM};
    
    RowMin = max(PthGrInd(1,1) - CllsArnd, 0);
    RowMax = min(PthGrInd(1,1) + CllsArnd, size(xLonSelDEM, 1));
    ColMin = max(PthGrInd(1,2) - CllsArnd, 0);
    ColMax = min(PthGrInd(1,2) + CllsArnd, size(yLatSelDEM, 2));
    
    xGrid = xLonSelDEM(RowMin:RowMax, ColMin:ColMax);
    yGrid = yLatSelDEM(RowMin:RowMax, ColMin:ColMax);
    ElvGr = ElevSelDEM(RowMin:RowMax, ColMin:ColMax);

    %% 3D Path Fig
    ProgressBar.Message = 'Creating 3D path fig and video...';
    FlnmFig = ['Landslide path ',num2str(SelLnds(i1)),' DEM ',num2str(SelDEM)];
    CurrFig = figure(i1);

    if ShowPlots; Vis = 'on'; else; Vis = 'off'; end
    set(CurrFig, 'Name',FlnmFig, 'Visible',Vis)
    
    imshow('Border','tight') % The axes will fill up the entire figure as much as possible without changing aspect ratio.
    CurrFig.WindowState = 'maximized'; % Maximize the figure to your whole screen.

    surf(xGrid, yGrid, ElvGr, 'FaceColor','interp', 'EdgeColor',GrdView)

    CurrAx = gca;
    hold(CurrAx,'on')

    colormap(CurrAx, 'pink')

    xlim([min(min(xGrid)), max(max(xGrid))])
    ylim([min(min(yGrid)), max(max(yGrid))])
    zlim([min(min(ElvGr)), max(max(ElvGr))])

    if SelView
        CurrView = str2num(char(inputdlg2({'View for current landslide:'}, 'DefInp',{'[149, 54]'})));
    else
        if     (PthGCrds(end,1) <= PthGCrds(1,1)) && (PthGCrds(end,2) >= PthGCrds(1,2)) % NW
            CurrView = [250, 69];
        elseif (PthGCrds(end,1) >= PthGCrds(1,1)) && (PthGCrds(end,2) >= PthGCrds(1,2)) % NE
            CurrView = [149, 54];
        elseif (PthGCrds(end,1) <= PthGCrds(1,1)) && (PthGCrds(end,2) <= PthGCrds(1,2)) % SW
            error('To implement correct view!')
        elseif (PthGCrds(end,1) >= PthGCrds(1,1)) && (PthGCrds(end,2) <= PthGCrds(1,2)) % SE
            error('To implement correct view!')
        end
    end

    view(CurrView)

    scatter3(StrtPnt(1), StrtPnt(2), StrtPnt(3)+3, 6*DetPixelSize, 'hexagram','Filled', 'MarkerFaceColor','k', 'MarkerEdgeColor','k')

    LimitsCol = linspace(min(min(ElvGr)), max(max(ElvGr)), 5);
    LimitsCol = round(LimitsCol, 3, 'significant');
    if LimitsCol(end) >= 5; LimitsCol = uint16(LimitsCol); end
    clim([LimitsCol(1), LimitsCol(end)])
    ColBar    = colorbar('Location','eastoutside', 'Ticks',LimitsCol, 'TickLabels',string(LimitsCol));

    CBrPos      = get(ColBar,'Position');
    CBrPos(1)   = CBrPos(1)*1.12;
    CBrPos(2)   = CBrPos(2)+2*CBrPos(2);
    CBrPos(3:4) = CBrPos(3:4).*[0.3, 0.5];
    set(ColBar, 'Position',CBrPos)

    title('Elevation data with preferential route', 'FontName',SelFnt, 'FontSize',SelFntSz)
    xlabel('Longitude (°)', 'FontName',SelFnt, 'FontSize',.8*SelFntSz)
    ylabel('Latitude (°)',  'FontName',SelFnt, 'FontSize',.8*SelFntSz)
    zlabel('Elevation (m)', 'FontName',SelFnt, 'FontSize',.8*SelFntSz)
    
    % 3D Path Video
    ProgressBar.Message = 'Creating frames of the video...';
    CurrVid = VideoWriter([fold_fig_pth,sl,'Path_',num2str(SelLnds(i1)),'_DEM_',num2str(SelDEM),'_Anim'], 'MPEG-4');

    CurrVid.FrameRate = 6;
    CurrVid.Quality   = 100;

    open(CurrVid)
    for i2 = 1 : numel(PthElev)-1
        line([PthGCrds(i2,1), PthGCrds(i2+1,1)], ...
             [PthGCrds(i2,2), PthGCrds(i2+1,2)], ...
             [PthElev(i2)   , PthElev(i2+1)   ], 'color','r', 'LineWidth',2, 'Parent',CurrAx) % 'Marker','o'

        Frame = getframe(CurrFig);
        writeVideo(CurrVid, Frame);
    end
    close(CurrVid);

    % Saving 3D Path
    ProgressBar.Message = 'Saving 3D path fig...';
    exportgraphics(CurrFig, [fold_fig_pth,sl,FlnmFig,'.png'], 'Resolution',600);

    if not(ShowPlots)
        close(CurrFig)
    end

    %% Satellite Fig
    ProgressBar.Message = 'Creating satellite fig...';
    FlnmFigSat = ['Landslide satellite path ',num2str(SelLnds(i1)),' DEM ',num2str(SelDEM)];
    CurrFigSat = figure(numel(SelLnds)+i1);

    if ShowPlots; Vis = 'on'; else; Vis = 'off'; end
    set(CurrFigSat, 'Name',FlnmFigSat, 'Visible',Vis)

    CurrAxSat = axes(CurrFigSat);
    set(CurrAxSat, 'Visible','off')
    hold(CurrAxSat,'on')

    if NewOrth
        [ZOrtho, xLongOrtho, yLatOrtho] = readortophoto([fold_raw_sat,sl,'UrlMap.txt'], ...
                                                        [min(min(xGrid)), max(max(xGrid))], ...
                                                        [min(min(yGrid)), max(max(yGrid))]);
    end

    Extremes = [min(min(xGrid)), max(max(xGrid)), max(max(xGrid)), min(min(xGrid)); ...
                min(min(yGrid)), min(min(yGrid)), max(max(yGrid)), max(max(yGrid)) ];
    PolyMask = polyshape(Extremes(1,:), Extremes(2,:));
    SatImage = fastscattergrid(ZOrtho, xLongOrtho, yLatOrtho, 'Mask',PolyMask, 'Parent',CurrAxSat);

    xlim([min(min(xGrid)), max(max(xGrid))])
    ylim([min(min(yGrid)), max(max(yGrid))])

    scatter(StrtPnt(1), StrtPnt(2), 6*DetPixelSize, 'hexagram','Filled', 'MarkerFaceColor','k', 'MarkerEdgeColor','k')

    line(PthGCrds(:,1), PthGCrds(:,2), PthElev(:), 'color','r', 'LineWidth',2, 'Parent',CurrAxSat) % 'Marker','o'

    fig_settings(fold0, 'SetExtremes',Extremes', 'CompassRose', 'ScaleBar')

    % Saving 3D Path
    ProgressBar.Message = 'Saving satellite fig...';
    exportgraphics(CurrFigSat, [fold_fig_pth,sl,FlnmFigSat,'.png'], 'Resolution',600);

    if not(ShowPlots)
        close(CurrFigSat)
    end

    %% Path evolution Fig
    ProgressBar.Message = 'Creating path evolution fig...';
    FlnmFigPth = ['Path evolution',num2str(SelLnds(i1)),' DEM ',num2str(SelDEM)];
    CurrFigPth = figure(2*numel(SelLnds)+i1);

    if ShowPlots; Vis = 'on'; else; Vis = 'off'; end
    set(CurrFigPth, 'Name',FlnmFigPth, 'Visible',Vis)

    CurrAxPth = cell(1, 3);

    % Longitude path
    CurrAxPth{1} = subplot(2, 2, 1);
    hold(CurrAxPth{1},'on')
    
    title('Longitude Path', 'FontName',SelFnt, 'FontSize',SelFntSz)
    xlabel('Longitude [°]', 'FontName',SelFnt, 'FontSize',.7*SelFntSz)
    zlabel('Elevation [m]', 'FontName',SelFnt, 'FontSize',.7*SelFntSz)

    view(0, 0)
    line(PthGCrds(:,1), PthGCrds(:,2), PthElev(:), 'color','r', 'LineWidth',2, 'Parent',CurrAxPth{1}) % 'Marker','o'

    xlim([min(PthGCrds(:,1)), max(PthGCrds(:,1))])
    ylim([min(PthGCrds(:,2)), max(PthGCrds(:,2))])
    zlim([min(PthElev(:))   , max(PthElev(:))   ])
    
    % Latitude path
    CurrAxPth{2} = subplot(2, 2, 2);
    hold(CurrAxPth{2},'on')

    title('Latitude Path',  'FontName',SelFnt, 'FontSize',SelFntSz)
    ylabel('Latitude [°]',  'FontName',SelFnt, 'FontSize',.7*SelFntSz)
    zlabel('Elevation [m]', 'FontName',SelFnt, 'FontSize',.7*SelFntSz)

    view(90,0)
    line(PthGCrds(:,1), PthGCrds(:,2), PthElev(:), 'color','r', 'LineWidth',2, 'Parent',CurrAxPth{2}) % 'Marker','o'

    xlim([min(PthGCrds(:,1)), max(PthGCrds(:,1))])
    ylim([min(PthGCrds(:,2)), max(PthGCrds(:,2))])
    zlim([min(PthElev(:))   , max(PthElev(:))   ])
    
    % Monodimensional path
    CurrAxPth{3} = subplot(2, 2, [3, 4]);
    hold(CurrAxPth{3},'on')

    AvSpeed = round(PthMnSpd, 3, 'significant');
    FinVol  = round(PthVols(end,2)*100, 4, 'significant');
    SubTtl  = ['Average speed: ',num2str(AvSpeed),' m/s; Ratio final volume: ',num2str(FinVol),' %'];

    title('Rectified path',  'FontName',SelFnt, 'FontSize',SelFntSz)
    subtitle(SubTtl,         'FontName',SelFnt, 'FontSize',.6*SelFntSz)
    xlabel('Pr. length [m]', 'FontName',SelFnt, 'FontSize',.7*SelFntSz)
    ylabel('Elevation [m]',  'FontName',SelFnt, 'FontSize',.7*SelFntSz)

    line(PthPrLen, PthElev, 'color','r', 'LineWidth',2, 'Parent',CurrAxPth{3}) % 'Marker','o'

    xlim([0,            max(PthPrLen)])
    ylim([min(PthElev), max(PthElev) ])

    % Saving rectified path
    ProgressBar.Message = 'Saving rectified path fig...';
    exportgraphics(CurrFigPth, [fold_fig_pth,sl,FlnmFigPth,'.png'], 'Resolution',600);

    if not(ShowPlots)
        close(CurrFigPth)
    end

    %% Path volume video
    ProgressBar.Message = 'Creating frames of the video...';
    FlnmFigVol = ['Volume Evolution Path_',num2str(SelLnds(i1)),'_DEM_',num2str(SelDEM),'_Anim'];
    CurrFigVol = figure(3*numel(SelLnds)+i1);
    CurrAxVol  = axes(CurrFigVol);
    hold(CurrAxVol,'on')

    if ShowPlots; Vis = 'on'; else; Vis = 'off'; end
    set(CurrFigVol, 'Name',FlnmFigVol, 'Visible',Vis)
    
    % imshow('Border','tight') % The axes will fill up the entire figure as much as possible without changing aspect ratio.
    CurrFigVol.WindowState = 'maximized'; % Maximize the figure to your whole screen.

    title('Rectified path' , 'FontName',SelFnt, 'FontSize',SelFntSz)
    subtitle(SubTtl        , 'FontName',SelFnt, 'FontSize',.6*SelFntSz)
    xlabel('Pr. length [m]', 'FontName',SelFnt, 'FontSize',.7*SelFntSz)
    ylabel('Elevation [m]' , 'FontName',SelFnt, 'FontSize',.7*SelFntSz)

    pbaspect([3, 1, 1])
    daspect([1, 1, 1])

    line(PthPrLen, PthElev         , 'color','k', 'LineWidth',2  , 'Parent',CurrAxVol)
    line(PthPrLen, PthElev-PthErDpt, 'color','r', 'LineWidth',1.2, 'Parent',CurrAxVol)

    xlim([0           , max(PthPrLen)])
    ylim([min(PthElev), max(PthElev) ])

    CurrVidVol = VideoWriter([fold_fig_pth,sl,FlnmFigVol], 'MPEG-4');
    CurrVidVol.FrameRate = 6;
    CurrVidVol.Quality   = 100;

    open(CurrVidVol)
    CurrDep = Depth;
    for i2 = 1 : numel(PthElev)-1
        xBL = mean(PthPrLen(i2:i2+1)) - SideSize/2;
        xBR = mean(PthPrLen(i2:i2+1)) + SideSize/2;
        xTL = xBL + CurrDep*sind(PthStpSl(i2));
        xTR = xBR + CurrDep*sind(PthStpSl(i2));
        yBL = mean(PthElev(i2:i2+1)) + SideSize/2*tand(PthStpSl(i2));
        yBR = mean(PthElev(i2:i2+1)) - SideSize/2*tand(PthStpSl(i2));
        yTL = yBL + CurrDep*cosd(PthStpSl(i2));
        yTR = yBR + CurrDep*cosd(PthStpSl(i2));

        RectPoly = polyshape([xBL, xBR, xTR, xTL], [yBL, yBR, yTR, yTL]);
        plot(RectPoly, 'FaceColor','b', 'EdgeColor','k', 'LineWidth',1)
        
        CurrDep = CurrDep + PthErDpt(i2);

        Frame = getframe(CurrFigVol);
        writeVideo(CurrVidVol, Frame);
    end
    close(CurrVidVol);
end