% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Reading data', ...
                                 'Message','Reading files...', 'Cancelable','off', ...
                                 'Indeterminate','on');
drawnow

%% Loading Files
cd(fold_var)
load('StudyAreaVariables.mat')
% load('GridCoordinates.mat')
load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips','IndDefInfoDet')
InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDefInfoDet};

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
end
cd(fold0)

%% Raster CTR Selection
fold_raw_ctr = strcat(fold_raw,sl,'CTR');
if ~exist(fold_raw_ctr, 'dir'); mkdir(fold_raw_ctr); end
save('os_folders.mat', 'fold_raw_ctr', '-append');

cd(fold_raw_ctr)
Files = sort(string([{dir('*.tif').name}, ...
                     {dir('*.tfw').name}, ...
                     {dir('*.asc').name}, ...
                     {dir('*.img').name}, ...
                     {dir('*.txt').name}, ...
                     {dir('*.png').name}, ...
                     {dir('*.pgw').name}, ...
                     {dir('*.jpg').name}, ...
                     {dir('*.jgw').name}]));
Choice = listdlg('PromptString',{'Choose a file:',''}, ...
                  'ListString',Files);
FileNameCTR = string(Files(Choice));

drawnow % Remember to remove if in Standalone version
figure(Fig) % Remember to remove if in Standalone version

if any(contains(FileNameCTR,'tif')) && any(contains(FileNameCTR,'tfw'))
    CTRType = 0;
elseif all(contains(FileNameCTR,'tif'))
    CTRType = 1;
elseif all(contains(FileNameCTR,'img'))
    CTRType = 2;
elseif any(contains(FileNameCTR,'jpg'))
    CTRType = 3;
    YetReferenced = false;
    if any(contains(FileNameCTR,'jgw'))
        YetReferenced = true;
    end
end

switch CTRType
    case 0
        NameFile1 = FileNameCTR(contains(FileNameCTR,'tif'));
        NameFile2 = FileNameCTR(contains(FileNameCTR,'tfw'));

    case 1
        NameFile1 = FileNameCTR;

    case 2
        NameFile1 = FileNameCTR;

    case 3
        NameFile1 = FileNameCTR(contains(FileNameCTR,'jpg'));
        if YetReferenced
            NameFile2 = FileNameCTR(contains(FileNameCTR,'jgw'));
        else
            NameFile3 = FileNameCTR(contains(FileNameCTR,'txt'));
        end

    otherwise
        error('Filetype not supported!')
end

%% Check pre existing CTR
SkipCTRProcessing = false;
cd(fold_var)
if exist('StudyCTR.mat', 'file')
    load('StudyCTR.mat')
    if exist('NameFileTotUsed', 'var') && all(NameFileTotUsed == NameFile1)
        SkipCTRProcessing = true;
        warning('Pre existing CTR Processing is equal -> CTR Processing will be skipped')
    end
end
cd(fold0)

%% Raster CTR Processing
if ~SkipCTRProcessing
    cd(fold_raw_ctr)
    ProgressBar.Indeterminate = 'off';
    
    [xLongCTRStudy, yLatCTRStudy, GrayScaleCTRStudy] = deal(cell(1,length(NameFile1)));
    
    [pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
    for i1 = 1:length(NameFile1)
    
        ProgressBar.Message = strcat("Creation of CTR n. ",num2str(i1)," of ", num2str(length(NameFile1)));
        ProgressBar.Value = i1/length(NameFile1);
    
        switch CTRType
            case 0
                A = imread(NameFile1(i1));
                R = worldfileread(NameFile2(i1), 'planar', size(A));
    
            case 1
                [A,R] = readgeoraster(NameFile1(i1), 'OutputType','native');
    
            case 2
                [A,R] = readgeoraster(NameFile1(i1), 'OutputType','native');
    
            case 3
                A = imread(NameFile1(i1));
    
                if size(A, 3) == 3 && isequal(A(:, :, 1), A(:, :, 2), A(:, :, 3))
                    A = A(:, :, 1);
                elseif size(A, 3) == 3 && ~isequal(A(:, :, 1), A(:, :, 2), A(:, :, 3))
                    A = rgb2gray(A);
                end
    
                if ~YetReferenced % REMEMBER TO MODIFY FOR DIFFERENT CRS!
                    fileID = fopen(NameFile3(i1), 'r');
                    ImageExt = fscanf(fileID, '%f');
                    fclose(fileID);
    
                    LatN  = ImageExt(3);
                    LongW = ImageExt(2);
                    LatS  = ImageExt(1);
                    LongE = ImageExt(4);
    
                    EPSGDest = projcrs(32633); % CHANGE THIS LINE
    
                    [xW, yN] = projfwd(EPSGDest, LatN, LongW);
                    [xE, yS] = projfwd(EPSGDest, LatS, LongE);
    
                    dLat  = -(LatN-LatS)/size(A, 1); % KEEP ATTENTION
                    dLong = (LongE-LongW)/size(A, 2); % KEEP ATTENTION
                    dy = -(yN-yS)/size(A, 1);
                    dx = (xE-xW)/size(A, 2);
    
                    WorldFileContGeo  = [dLong; 0; 0; dLat; LongW; LatN];
                    WorldFileContPlan = [dx; 0; 0; dy; xW; yN];
                    WorldFileame  = getworldfilename(NameFile1(i1));
    
                    fileID = fopen(WorldFileame, 'w');
                    ImageExt = fprintf(fileID, '%f\n', WorldFileContPlan);
                    fclose(fileID);
    
                    % [~, NameFile2NoExt, ~] = fileparts(NameFile3(i1));
                    R = worldfileread(WorldFileame, 'planar', size(A));
                else
                    R = worldfileread(NameFile2(i1), 'planar', size(A));
                end
    
        end
    
        if string(R.CoordinateSystemType)=="planar" && isempty(R.ProjectedCRS) && i1==1
            EPSG = str2double(inputdlg({["Set DTM EPSG"
                                         "For Example:"
                                         "Sicily -> 32633"
                                         "Emilia Romagna -> 25832"]}, '', 1, {'32633'}));
            R.ProjectedCRS = projcrs(EPSG);
        elseif string(R.CoordinateSystemType)=="planar" && isempty(R.ProjectedCRS) && i1>1
            R.ProjectedCRS = projcrs(EPSG);
        elseif string(R.CoordinateSystemType)=="geographic" && isempty(R.GeographicCRS)
            R.GeographicCRS = geocrs(4326);
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
        clear('A')
    
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
    NameFileTotUsed = NameFile1;
    xLongCTRStudy(EmptyIndexCTRPointsInsideStudyArea)                   = [];
    yLatCTRStudy(EmptyIndexCTRPointsInsideStudyArea)                    = [];
    GrayScaleCTRStudy(EmptyIndexCTRPointsInsideStudyArea)               = [];
    
    %% Saving...
    ProgressBar.Indeterminate = 'on';
    ProgressBar.Message = 'Saving created files...';
    
    cd(fold_var)
    VariablesCTR = {'xLongCTRStudy', 'yLatCTRStudy', 'GrayScaleCTRStudy', 'NameFileIntersecated', 'NameFileTotUsed'};
    save('StudyCTR.mat', VariablesCTR{:});
    cd(fold0)
end

%% Plot for check
SkipCheck = true;
if ~SkipCheck
    ProgressBar.Message = 'Creating plot for check...';

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
end

%% Request for Elevation and Slope
ProgressBar.Message = 'Figure options...';

Options = {'All', 'Selected class', 'Elevation + Slope', 'Aspect'};
SelPlots = uiconfirm(Fig, 'What do you want to plot?', ...
                          'Tables plot', 'Options',Options);
switch SelPlots
    case 'All'
        SelPlots = 1;
    case 'Selected class'
        SelPlots = 2;
    case 'Elevation + Slope'
        SelPlots = 3;
    case 'Aspect'
        SelPlots = 4;
end
% if strcmp(SkipMSA,'No'); SkipMSA = true; else; SkipMSA = false; end

ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show plot', 'Options',{'Yes', 'No'});
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

%% Figure Creation
Options = {'Color Comb 1', 'Color Comb 2', 'Color Comb 3', 'Color Comb 4'};
ColorComb = uiconfirm(Fig, 'What color combination do you want to use?', ...
                           'Color combination', 'Options',Options);
switch ColorComb
    case 'Color Comb 1'
        rng(15)  % For havenig the same color palet everytime
    case 'Selected class'
        rng(30)  % For havenig the same color palet everytime
    case 'Elevation + Slope'
        rng(115) % For havenig the same color palet everytime
    case 'Aspect'
        rng(175) % For havenig the same color palet everytime
end

TransparencyValues = inputdlg({'Indicate transparency of background (from 0 to 1):'
                               'Indicate transparency of top layer (from 0 to 1):'},'', ...
                               1, {'0.8', '0.5'});

BTrans = eval(TransparencyValues{1});
TTrans = eval(TransparencyValues{2});

drawnow % Remember to remove if in Standalone version
figure(Fig) % Remember to remove if in Standalone version

RefStudyArea = 0.035;

xLongCTRTot      = cat(1,xLongCTRStudy{:});
yLatCTRTot       = cat(1,yLatCTRStudy{:});
GrayScaleCTRTot  = cat(1,GrayScaleCTRStudy{:});

fold_fig_det = strcat(fold_fig,sl,'Detected points plots');
if ~exist(fold_fig_det,'dir'); mkdir(fold_fig_det); end

Classes = cellfun(@(x) table2cell(x(:,1)), InfoPointsNearDetectedSoilSlips(:,7), 'UniformOutput',false);
Classes = unique(string(cat(1, Classes{:})));

IndClassesNS = strcmp(Classes, 'Land Use not specified'); % Not classified, then they will be removed
Classes(IndClassesNS) = [];

PlotColors = arrayfun(@(x) rand(1, 3), Classes, 'UniformOutput',false);

warning('off')
ProgressBar.Indeterminate = 'off';

for i1 = 1:length(PolWindow)

    ProgressBar.Message = strcat("Creation of figure n. ",num2str(i1)," of ", num2str(length(PolWindow)));
    ProgressBar.Value = i1/length(PolWindow);

    %% Preliminary operations
    ExtentStudyArea = area(PolWindow(i1));
    ExtremesPlot = PolWindow(i1).Vertices;
    [ppWin, eeWin] = getnan2([PolWindow(i1).Vertices; nan, nan]);
    RatioRef = ExtentStudyArea/RefStudyArea;    
    PixelSize = .1/RatioRef;

    % CTR Preliminary operation
    IndexCTRInPolWin = find(inpoly([xLongCTRTot, yLatCTRTot], ppWin, eeWin)==1);
    if ~isempty(IndexCTRInPolWin)

        OverlapDTMs = true; % GIVE THE CHOICE TO USER
        if OverlapDTMs
            xLongCTRPar     = xLongCTRTot(IndexCTRInPolWin);
            yLatCTRPar      = yLatCTRTot(IndexCTRInPolWin);
            GrayScaleCTRPar = GrayScaleCTRTot(IndexCTRInPolWin);
        else
            IndexCTRInPolWinSingle = cellfun(@(x,y) find(inpoly([x, y], ppWin, eeWin)==1), xLongCTRStudy, yLatCTRStudy, 'UniformOutput',false);
            [~, CTRWithMaxPoint] = max(cellfun(@length, IndexCTRInPolWinSingle));

            xLongCTRPar     = xLongCTRStudy{CTRWithMaxPoint}(IndexCTRInPolWinSingle{CTRWithMaxPoint});
            yLatCTRPar      = yLatCTRStudy{CTRWithMaxPoint}(IndexCTRInPolWinSingle{CTRWithMaxPoint});
            GrayScaleCTRPar = GrayScaleCTRStudy{CTRWithMaxPoint}(IndexCTRInPolWinSingle{CTRWithMaxPoint});
        end
    
        ColorUniqueValues = unique(GrayScaleCTRPar);
        if length(ColorUniqueValues) == 2
            ColorType = "BW";
        elseif length(ColorUniqueValues)>2 && max(ColorUniqueValues)>1
            ColorType = "GrayNotScaled";
        elseif length(ColorUniqueValues)>2 && max(ColorUniqueValues)<=1
            ColorType = "GrayScaled";
        else
            error('Error with gray color of CTR')
        end

        switch ColorType
            case "BW"
                xLongCTRToPlot = xLongCTRPar(~logical(GrayScaleCTRPar));
                yLatCTRToPlot  = yLatCTRPar(~logical(GrayScaleCTRPar));
            case "GrayNotScaled"
                GrayScaleUniqueCTR = num2cell(unique(GrayScaleCTRPar));
                IndexToPlot = cellfun(@(x) find(x == GrayScaleCTRPar), GrayScaleUniqueCTR, 'UniformOutput',false);
            case "GrayScaled"
                error('Not yet implemented')
        end

    else
        strcat("Municipality: ", string(InfoDetectedSoilSlipsToUse{i1,1}), " does not have CTR")
    end

    PointsNearLong = cell2mat(InfoPointsNearDetectedSoilSlips{i1,4}(:,3));
    PointsNearLat  = cell2mat(InfoPointsNearDetectedSoilSlips{i1,4}(:,4));

    IndexPointsInPolWin = find(inpoly([PointsNearLong, PointsNearLat], ppWin, eeWin)==1);

    PointsNearLong    = PointsNearLong(IndexPointsInPolWin);
    PointsNearLat     = PointsNearLat(IndexPointsInPolWin);

    %% Plot Classes
    if SelPlots == 1 || SelPlots == 2
        fig_class = figure('visible','off');
        ax_ind1 = axes(fig_class);
        hold(ax_ind1,'on')

        Filename1 = strcat("Classes for point n. ",string(i1));
        title(strcat( "Comune: ", string(InfoDetectedSoilSlipsToUse{i1,1})), ...
              'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.4, 'Parent',ax_ind1)
        subtitle(strcat( "Cod. IOP: ", string(strrep(InfoDetectedSoilSlipsToUse{i1,2}, '_', ' ')) ), ...
                 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'Parent',ax_ind1)
        set(fig_class, 'Name',Filename1);
    
        % Plot CTR
        if ~isempty(IndexCTRInPolWin)
            switch ColorType
                case "BW"
                    PlotCTR1 = scatter(xLongCTRToPlot, yLatCTRToPlot, 0.5, 'Marker','s', 'MarkerFaceColor','k', ...
                                       'MarkerEdgeColor','none', 'MarkerFaceAlpha',BTrans, 'Parent',ax_ind1);
                case {"GrayNotScaled", "GrayScaled"}
                    PlotCTR1 = cellfun(@(x,z) scatter(xLongCTRPar(x), yLatCTRPar(x), 0.9, ...
                                                      'Marker','s', 'MarkerFaceColor',single([z, z, z])./255, ...
                                                      'MarkerEdgeColor','none', 'MarkerFaceAlpha',BTrans, 'Parent',ax_ind1), ...
                                              IndexToPlot, GrayScaleUniqueCTR, 'UniformOutput',false);
            end
        end
    
        % Plot Classes (LU)
        PointClassNearDSS = string(InfoPointsNearDetectedSoilSlips{i1,4}(:,17)); % This is LU
        PointClassNearDSS = PointClassNearDSS(IndexPointsInPolWin);
        
        IndClasses = arrayfun(@(x) strcmp(x, PointClassNearDSS), Classes, 'UniformOutput',false);
    
        IndClassesNotEmpty = cellfun(@(x) any(x), IndClasses);
    
        IndClasses    = IndClasses(IndClassesNotEmpty);
        ClassesLocal  = Classes(IndClassesNotEmpty);
        PlotColorsLoc = PlotColors(IndClassesNotEmpty);
    
        PlotClass = cellfun(@(x,z) scatter(PointsNearLong(x), PointsNearLat(x), 0.1*PixelSize, ...
                                           'Marker','o', 'MarkerFaceColor',z, 'MarkerEdgeColor','none', ...
                                           'MarkerFaceAlpha',TTrans, 'Parent',ax_ind1), ...
                                   IndClasses, PlotColorsLoc, 'UniformOutput',false);
    
        % Plot Contour, detected point & extra settings
        PlotContour = plot(PolWindow(i1), 'FaceColor','none', 'LineWidth',1, 'LineStyle','--', 'Parent',ax_ind1);
    
        PlotDetected = scatter(InfoDetectedSoilSlipsToUse{i1,5}, InfoDetectedSoilSlipsToUse{i1,6}, PixelSize, ...
                               'Marker','d', 'MarkerFaceColor','r', 'MarkerEdgeColor','k', ...
                               'MarkerFaceAlpha',1, 'LineWidth',1, 'Parent',ax_ind1);
    
        ax_ind1.XAxis.Visible = 'off';
        ax_ind1.YAxis.Visible = 'off';
    
        fig_settings(fold0, 'ScaleBar', 'ScaleBarBox', 'SetExtremes',ExtremesPlot);

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

            fig_rescaler(fig_class, hleg1, LegendPosition)
        end
    
        if ShowPlots
            set(fig_class, 'visible','on');
            pause
        end
    
        % Saving...
        cd(fold_fig_det)
        exportgraphics(fig_class, strcat(Filename1,'.png'), 'Resolution',600);
    
        close(fig_class)
        % cla(ax_ind1,'reset')
        % clf(fig_class,'reset')
    end

    %% Plot Morphology
    if SelPlots == 1 || SelPlots == 3
        fig_morph = figure('visible','off');
        ax_ind2 = axes(fig_morph);
        hold(ax_ind2,'on')
    
        Filename2 = strcat("Morphology of point n. ",string(i1));
        title(strcat( "Comune: ", string(InfoDetectedSoilSlipsToUse{i1,1})), ...
              'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.4, 'Parent',ax_ind2)
        subtitle(strcat( "Cod. IOP: ", string(strrep(InfoDetectedSoilSlipsToUse{i1,2}, '_', ' ')) ), ...
                 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'Parent',ax_ind2)
        set(fig_morph, 'Name',Filename2);
    
        if ~isempty(IndexCTRInPolWin)
            switch ColorType
                case "BW"
                    PlotCTR2 = scatter(xLongCTRToPlot, yLatCTRToPlot, 0.5, 'Marker','s', 'MarkerFaceColor','k', ...
                                           'MarkerEdgeColor','none', 'MarkerFaceAlpha',BTrans, 'Parent',ax_ind2);
                case {"GrayNotScaled", "GrayScaled"}
                    PlotCTR2 = cellfun(@(x,z) scatter(xLongCTRPar(x), yLatCTRPar(x), 0.9, ...
                                                      'Marker','s', 'MarkerFaceColor',single([z, z, z])./255, ...
                                                      'MarkerEdgeColor','none', 'MarkerFaceAlpha',BTrans, 'Parent',ax_ind2), ...
                                              IndexToPlot, GrayScaleUniqueCTR, 'UniformOutput',false);
            end
        end
    
        PointsNearAlt  = cell2mat(InfoPointsNearDetectedSoilSlips{i1,4}(:,5));
        PointsNearAlt  = PointsNearAlt(IndexPointsInPolWin);
    
        PlotMorph = fastscatter2(PointsNearLong, PointsNearLat, PointsNearAlt, 'FaceAlpha',TTrans, 'Parent',ax_ind2);
    
        colormap(ax_ind2,'pink')
        LimitsCol = linspace(min(PointsNearAlt), max(PointsNearAlt), 5);
        LimitsCol = round(LimitsCol, 3, 'significant'); % CHECK FOR LEGEND THAT IS CUTTED AND WITH 3 DECIMAL NUMBERS, WHEN 0 IS PRESENT
        clim([LimitsCol(1), LimitsCol(end)])
        ColBar = colorbar('Location','southoutside', 'Ticks',LimitsCol);
        ColBarPos = get(ColBar,'Position');
        ColBarPos(1) = ColBarPos(1)*2.8;
        ColBarPos(2) = ColBarPos(2)-0.5*ColBarPos(2);
        ColBarPos(3:4) = ColBarPos(3:4)*0.4;
        set(ColBar, 'Position',ColBarPos)
        title(ColBar, 'Elevazione [m]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2)
    
        PlotContour = plot(PolWindow(i1), 'FaceColor','none', 'LineWidth',1, 'LineStyle','--', 'Parent',ax_ind2);
    
        PlotDetected = scatter(InfoDetectedSoilSlipsToUse{i1,5}, InfoDetectedSoilSlipsToUse{i1,6}, PixelSize, ...
                               'Marker','d', 'MarkerFaceColor','r', 'MarkerEdgeColor','k', ...
                               'MarkerFaceAlpha',1, 'LineWidth',1, 'Parent',ax_ind2);
    
        ax_ind2.XAxis.Visible = 'off';
        ax_ind2.YAxis.Visible = 'off';
    
        fig_settings(fold0, 'ScaleBar', 'ScaleBarBox', 'SetExtremes',ExtremesPlot);
    
        if ShowPlots
            set(fig_morph, 'visible','on');
            pause
        end
    
        % Saving...
        cd(fold_fig_det)
        exportgraphics(fig_morph, strcat(Filename2,'.png'), 'Resolution',600);
        close(fig_morph)
    end

    %% Plot Slope
    if SelPlots == 1 || SelPlots == 3
        fig_slope = figure('visible','off');
        ax_ind3 = axes(fig_slope);
        hold(ax_ind3,'on')
    
        Filename3 = strcat("Slope of point n. ",string(i1));
        title(strcat( "Comune: ", string(InfoDetectedSoilSlipsToUse{i1,1})), ...
              'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.4, 'Parent',ax_ind3)
        subtitle(strcat( "Cod. IOP: ", string(strrep(InfoDetectedSoilSlipsToUse{i1,2}, '_', ' ')) ), ...
                 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'Parent',ax_ind3)
        set(fig_slope, 'Name',Filename3);
    
        if ~isempty(IndexCTRInPolWin)
            switch ColorType
                case "BW"
                    PlotCTR3 = scatter(xLongCTRToPlot, yLatCTRToPlot, 0.5, 'Marker','s', 'MarkerFaceColor','k', ...
                                           'MarkerEdgeColor','none', 'MarkerFaceAlpha',BTrans, 'Parent',ax_ind3);
                case {"GrayNotScaled", "GrayScaled"}
                    PlotCTR3 = cellfun(@(x,z) scatter(xLongCTRPar(x), yLatCTRPar(x), 0.9, ...
                                                      'Marker','s', 'MarkerFaceColor',single([z, z, z])./255, ...
                                                      'MarkerEdgeColor','none', 'MarkerFaceAlpha',BTrans, 'Parent',ax_ind3), ...
                                              IndexToPlot, GrayScaleUniqueCTR, 'UniformOutput',false);
            end
        end
    
        PointsNearSlope  = cell2mat(InfoPointsNearDetectedSoilSlips{i1,4}(:,6));
        PointsNearSlope  = PointsNearSlope(IndexPointsInPolWin);
    
        PlotSlope = fastscatter2(PointsNearLong, PointsNearLat, PointsNearSlope, 'FaceAlpha',TTrans, 'Parent',ax_ind3);
    
        colormap(ax_ind3,'cool')
        LimitsCol = linspace(min(PointsNearSlope), max(PointsNearSlope), 5);
        LimitsCol = round(LimitsCol, 2, 'significant');
        if LimitsCol(end) >= 5; LimitsCol = uint16(LimitsCol); end
        clim([LimitsCol(1), LimitsCol(end)])
        ColBar = colorbar('Location','southoutside', 'Ticks',LimitsCol);
        ColBarPos = get(ColBar,'Position');
        ColBarPos(1) = ColBarPos(1)*2.8;
        ColBarPos(2) = ColBarPos(2)-0.5*ColBarPos(2);
        ColBarPos(3:4) = ColBarPos(3:4)*0.4;
        set(ColBar, 'Position',ColBarPos)
        title(ColBar, 'Inclinazione Pendio [°]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2)
    
        PlotContour = plot(PolWindow(i1), 'FaceColor','none', 'LineWidth',1, 'LineStyle','--', 'Parent',ax_ind3);
    
        PlotDetected = scatter(InfoDetectedSoilSlipsToUse{i1,5}, InfoDetectedSoilSlipsToUse{i1,6}, PixelSize, ...
                               'Marker','d', 'MarkerFaceColor','r', 'MarkerEdgeColor','k', ...
                               'MarkerFaceAlpha',1, 'LineWidth',1, 'Parent',ax_ind3);
    
        ax_ind3.XAxis.Visible = 'off';
        ax_ind3.YAxis.Visible = 'off';
    
        fig_settings(fold0, 'ScaleBar', 'ScaleBarBox', 'SetExtremes',ExtremesPlot);
    
        if ShowPlots
            set(fig_slope, 'visible','on');
            pause
        end
    
        % Saving...
        cd(fold_fig_det)
        exportgraphics(fig_slope, strcat(Filename3,'.png'), 'Resolution',600);
        close(fig_slope)
    end

    %% Plot Aspect
    if SelPlots == 1 || SelPlots == 4
        fig_aspect = figure('visible','off');
        ax_ind4 = axes(fig_aspect);
        hold(ax_ind4,'on')
    
        Filename4 = strcat("Aspect of point n. ",string(i1));
        title(strcat( "Comune: ", string(InfoDetectedSoilSlipsToUse{i1,1})), ...
              'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.4, 'Parent',ax_ind4)
        subtitle(strcat( "Cod. IOP: ", string(strrep(InfoDetectedSoilSlipsToUse{i1,2}, '_', ' ')) ), ...
                 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2, 'Parent',ax_ind4)
        set(fig_aspect, 'Name',Filename4);
    
        if ~isempty(IndexCTRInPolWin)
            switch ColorType
                case "BW"
                    PlotCTR4 = scatter(xLongCTRToPlot, yLatCTRToPlot, 0.5, 'Marker','s', 'MarkerFaceColor','k', ...
                                           'MarkerEdgeColor','none', 'MarkerFaceAlpha',BTrans, 'Parent',ax_ind4);
                case {"GrayNotScaled", "GrayScaled"}
                    PlotCTR4 = cellfun(@(x,z) scatter(xLongCTRPar(x), yLatCTRPar(x), 0.9, ...
                                                      'Marker','s', 'MarkerFaceColor',single([z, z, z])./255, ...
                                                      'MarkerEdgeColor','none', 'MarkerFaceAlpha',BTrans, 'Parent',ax_ind4), ...
                                              IndexToPlot, GrayScaleUniqueCTR, 'UniformOutput',false);
            end
        end
    
        PointsNearAspect  = cell2mat(InfoPointsNearDetectedSoilSlips{i1,4}(:,7));
        PointsNearAspect  = PointsNearAspect(IndexPointsInPolWin);
    
        PlotAspect = fastscatter2(PointsNearLong, PointsNearLat, PointsNearAspect, 'FaceAlpha',TTrans, 'Parent',ax_ind4);
    
        % cmap = summer(8);
        cmap = hsv(8);
        colormap(ax_ind4, cmap)
        % LimitsCol = linspace(min(PointsNearAspect), max(PointsNearAspect), 9);
        LimitsCol = linspace(0, 360, 9);
        LimitsCol = round(LimitsCol, 2, 'significant');
        if LimitsCol(end) >= 9; LimitsCol = uint16(LimitsCol); end
        clim([LimitsCol(1), LimitsCol(end)])
        TickLabel = {'S', 'SE', 'E', 'NE', 'N', 'NO', 'O', 'SO'};
        ColBar = colorbar('Location','southoutside', 'Ticks',LimitsCol, 'TickLabels',TickLabel);
        ColBarPos = get(ColBar,'Position');
        ColBarPos(1) = ColBarPos(1)*2.8;
        ColBarPos(2) = ColBarPos(2)-0.5*ColBarPos(2);
        ColBarPos(3:4) = ColBarPos(3:4)*0.4;
        set(ColBar, 'Position',ColBarPos)
        title(ColBar, 'Angoli di esposizione [°]', 'FontName',SelectedFont, 'FontSize',SelectedFontSize*1.2)
    
        PlotContour = plot(PolWindow(i1), 'FaceColor','none', 'LineWidth',1, 'LineStyle','--', 'Parent',ax_ind4);
    
        PlotDetected = scatter(InfoDetectedSoilSlipsToUse{i1,5}, InfoDetectedSoilSlipsToUse{i1,6}, PixelSize, ...
                               'Marker','d', 'MarkerFaceColor','r', 'MarkerEdgeColor','k', ...
                               'MarkerFaceAlpha',1, 'LineWidth',1, 'Parent',ax_ind4);
    
        ax_ind4.XAxis.Visible = 'off';
        ax_ind4.YAxis.Visible = 'off';
    
        fig_settings(fold0, 'ScaleBar', 'ScaleBarBox', 'SetExtremes',ExtremesPlot);
    
        if ShowPlots
            set(fig_aspect, 'visible','on');
            pause
        end
    
        % Saving...
        cd(fold_fig_det)
        exportgraphics(fig_aspect, strcat(Filename4,'.png'), 'Resolution',600);
        close(fig_aspect)
    end
end
close(ProgressBar) % Fig instead of ProgressBar if in Standalone Version
cd(fold0)
warning('on')