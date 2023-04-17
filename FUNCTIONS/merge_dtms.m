% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Processing DTM of Study Area', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Buffered boundary of study area
cd(fold_var)
load('StudyAreaVariables.mat', 'MaxExtremes','MinExtremes','StudyAreaPolygon')

EB = 500*360/2/pi/earthRadius;
BoundingBox = [MinExtremes(2)-EB, MaxExtremes(2)+EB
               MinExtremes(1)-EB, MaxExtremes(1)+EB];
BBEBPoly = polyshape([BoundingBox(2), BoundingBox(4), BoundingBox(4), BoundingBox(2)], ...
                     [BoundingBox(1), BoundingBox(1), BoundingBox(3), BoundingBox(3)]);

BufferDist = km2deg(80/1000);
StudyAreaPolygonScaled = polybuffer(StudyAreaPolygon, BufferDist);

%% Detecting point inside scaled StudyAreaScaled
cd(fold_var)
% load('GridCoordinates.mat', 'xLongAll','yLatAll')
% load('MorphologyParameters.mat', 'ElevationAll')
load('UserB_answers.mat', 'DTMType','NameFileIntersecated')

if DTMType == 0
    [~, NameFileNoExt, ~] = fileparts(NameFileIntersecated);
                NameFileInt2 = strcat(NameFileNoExt,".tfw");
end

cd(fold_raw_dtm)
[xLongAll, yLatAll, ElevationAll, RAll] = deal(cell(1,length(NameFileIntersecated)));
ProgressBar.Indeterminate = 'off';
for i1 = 1:length(NameFileIntersecated)
    ProgressBar.Message = strcat("Analyzing DTM n. ",num2str(i1)," of ", num2str(length(NameFileIntersecated)));
    ProgressBar.Value = i1/length(NameFileIntersecated);
    switch DTMType
        case 0
            A = imread(NameFileIntersecated(i1));
            R = worldfileread(NameFileInt2(i1), 'planar', size(A));
        case 1
            [A,R] = readgeoraster(NameFileIntersecated(i1), 'OutputType','native');
        case 2
            [A,R] = readgeoraster(NameFileIntersecated(i1), 'OutputType','double');
    end

    if string(R.CoordinateSystemType)=="planar" && isempty(R.ProjectedCRS) && i1==1
        EPSG = str2double(inputdlg({["Set DTM EPSG"
                                     "For Example:"
                                     "Sicily -> 32633"
                                     "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
        R.ProjectedCRS = projcrs(EPSG);
    elseif string(R.CoordinateSystemType)=="planar" && isempty(R.ProjectedCRS) && i1>1
        R.ProjectedCRS = projcrs(EPSG);
    elseif string(R.CoordinateSystemType)=="geographic" && isempty(R.GeographicCRS)
        R.GeographicCRS = geocrs(4326);
    end
    
    if R.CoordinateSystemType == "planar"
        [XTBS, YTBS] = worldGrid(R);
        dX = R.CellExtentInWorldX;
        dY = R.CellExtentInWorldY;
    elseif R.CoordinateSystemType == "geographic"
        [YTBS, XTBS] = geographicGrid(R);
        dX = acos(sind(YTBS(1,1))*sind(YTBS(1,2))+cosd(YTBS(1,1))*cosd(YTBS(1,2))*cosd(XTBS(1,2)-XTBS(1,1)))*earthRadius;
        dY = acos(sind(YTBS(1,1))*sind(YTBS(2,1))+cosd(YTBS(1,1))*cosd(YTBS(2,1))*cosd(XTBS(2,1)-XTBS(1,1)))*earthRadius;
    end

    if i1 == 1
        Options = {'Yes', 'No'};
        Prompt = strcat("Actual X Y resolution is: ",string(int64(dX)), " x ",string(int64(dY)),". Do you want to change it?");
        ChangeDTMRes = uiconfirm(Fig, Prompt, 'DTM Resolution', 'Options',Options);
    
        if strcmp(ChangeDTMRes, 'Yes')
            AnswerChangeDTMResolution = 1;
            NewDTMRes = inputdlg({'Indicate new X value:'
                                  'Indicate new Y value:'},'', ...
                                   1, {num2str(int64(dX)), num2str(int64(dY))});
            NewDx = eval(NewDTMRes{1});
            NewDy = eval(NewDTMRes{1});

            Options = {'Yes', 'No, only in the merged one'};
            Prompt = strcat("Do you want to apply this resolution also at your single files (more speed)?");
            ChangeDTMResInd = uiconfirm(Fig, Prompt, 'DTM Resolution', 'Options',Options);
            if strcmp(ChangeDTMResInd, 'Yes'); ChangeDTMResInd = true; else; ChangeDTMResInd = false; end
        else
            AnswerChangeDTMResolution = 0;
        end
    end

    if AnswerChangeDTMResolution == 1 && ChangeDTMResInd == 1
        ScaleFactorX = max(int64(NewDx/dX), 1);
        ScaleFactorY = max(int64(NewDy/dY), 1);
    else
        ScaleFactorX = 1;
        ScaleFactorY = 1;
    end

    X = XTBS(1:ScaleFactorX:end, 1:ScaleFactorY:end);
    Y = YTBS(1:ScaleFactorX:end, 1:ScaleFactorY:end);

    Elevation = max(A(1:ScaleFactorX:end, 1:ScaleFactorY:end), 0); % Sometimes raster have big negative elevation values for sea
    
    if string(R.CoordinateSystemType) == "planar"
        [yLat, xLong] = projinv(R.ProjectedCRS, X, Y);
        [yLatExt, xLongExt] = projinv(R.ProjectedCRS, R.XWorldLimits, R.YWorldLimits);
        RGeo = georefcells(yLatExt, xLongExt, size(Elevation), 'ColumnsStartFrom','north'); % Remember to automatize this parameter (ColumnsStartFrom) depending on emisphere!
        RGeo.GeographicCRS = R.ProjectedCRS.GeographicCRS;
    else
        xLong = X;
        yLat  = Y;
        RGeo  = R;
    end

    clear('X', 'Y')

    xLongAll{i1} = xLong;
    clear('xLong')
    yLatAll{i1} = yLat;
    clear('yLat')
    ElevationAll{i1} = Elevation;
    clear('Elevation')
    RAll{i1} = RGeo;
    clear('RGeo')
end

ProgressBar.Indeterminate = 'on';
ProgressBar.Message = "Searching for points inside study area scaled...";
[IndexDTMPointsInsideStudyAreaScaled, IndexDTMPointsInsideBBEBPoly, ...
    xLongStudyAreaScaled, yLatStudyAreaScaled, ElevationStudyAreaScaled] = deal(cell(1,length(xLongAll)));
for i1 = 1:length(xLongAll)
    [pp1, ee1] = getnan2([StudyAreaPolygonScaled.Vertices; nan, nan]);
    [pp2, ee2] = getnan2([BBEBPoly.Vertices; nan, nan]);
    IndexDTMPointsInsideStudyAreaScaled{i1} = find(inpoly([xLongAll{i1}(:), yLatAll{i1}(:)], pp1, ee1)==1);
    IndexDTMPointsInsideBBEBPoly{i1} = find(inpoly([xLongAll{i1}(:), yLatAll{i1}(:)], pp2, ee2)==1);

    xLongStudyAreaScaled{i1}     = xLongAll{i1}(IndexDTMPointsInsideStudyAreaScaled{i1});
    yLatStudyAreaScaled{i1}      = yLatAll{i1}(IndexDTMPointsInsideStudyAreaScaled{i1});
    ElevationStudyAreaScaled{i1} = ElevationAll{i1}(IndexDTMPointsInsideStudyAreaScaled{i1});
end

%% Creation of merged DTM (empty elevation)
xLongAllCat      = cellfun(@(x) x(:), xLongAll, 'UniformOutput', false);
xLongAllCat      = vertcat(xLongAllCat{:});
yLatAllCat       = cellfun(@(x) x(:), yLatAll, 'UniformOutput', false);
yLatAllCat       = vertcat(yLatAllCat{:});
ElevationAllCat  = cellfun(@(x) x(:), ElevationAll, 'UniformOutput', false);
ElevationAllCat  = vertcat(ElevationAllCat{:});

xLongStudyAreaScaledCat     = vertcat(xLongStudyAreaScaled{:});
yLatStudyAreaScaledCat      = vertcat(yLatStudyAreaScaled{:});
ElevationStudyAreaScaledCat = vertcat(ElevationStudyAreaScaled{:});

if AnswerChangeDTMResolution == 1
    MaxLat  = BoundingBox(3);
    MinLat  = BoundingBox(1);
    MaxLong = BoundingBox(4);
    MinLong = BoundingBox(2);

    dLong = rad2deg(acos( (cos(NewDx/earthRadius) - sind((MaxLat+MinLat)/2)^2) / cosd((MaxLat+MinLat)/2)^2 )); % See my notes for more information (Sa)
    dLat  = rad2deg(NewDy/earthRadius); % See my notes for more information (Sa)
else
    [~, IndMaxLat]  = min((yLatAllCat  - BoundingBox(3)).^2);
    [~, IndMaxLong] = min((xLongAllCat - BoundingBox(4)).^2);
    [~, IndMinLat]  = min((yLatAllCat  - BoundingBox(1)).^2);
    [~, IndMinLong] = min((xLongAllCat - BoundingBox(2)).^2);
    MaxLat  = yLatAllCat(IndMaxLat);
    MinLat  = yLatAllCat(IndMinLat);
    MaxLong = xLongAllCat(IndMaxLong);
    MinLong = xLongAllCat(IndMinLong);

    if R.RasterInterpretation == "postings"
        dLong = RAll{1}.SampleSpacingInLongitude;
        dLat  = RAll{1}.SampleSpacingInLongitude;
    elseif R.RasterInterpretation == "cells"
        dLong = RAll{1}.CellExtentInLongitude;
        dLat  = RAll{1}.CellExtentInLatitude;
    end
end

SizeX = int64((MaxLong-MinLong)/dLong);
SizeY = int64((MaxLat-MinLat)/dLat);
MaxLong = MinLong + double(SizeX)*dLong;
MaxLat  = MinLat  + double(SizeY)*dLat;
RGeoTot = georefcells([MinLat, MaxLat], [MinLong, MaxLong], [SizeY, SizeX]);
[yLatGeoTot, xLongGeoTot] = geographicGrid(RGeoTot);
ElevationTot = zeros(size(xLongGeoTot));

Options = {'Nearest point DIY', 'Interpolation'};
EelevationAttrChoice = uiconfirm(Fig, 'How do you want to attribute elevation to each point?', ...
                                      'Elevation attribution', 'Options',Options);
switch EelevationAttrChoice
    case 'Nearest point DIY'
        ElevationAttrOpt = 2;
    case 'Nearest point (red)'
        ElevationAttrOpt = 3;
    case 'Interpolation'
        ElevationAttrOpt = 4;
end

switch ElevationAttrOpt
    case 1
        %% Elevation of merged DTM attribution OPT1
        DoublePointCount = 0;
        PointsDoubledInd = [];
        ProgressBar.Indeterminate = 'off';
        ProgressBar.Message = 'Creation of merged DTM';
        for i1 = 1:length(ElevationStudyAreaScaledCat)
            if rem(i1,100)
                ProgressBar.Value = i1/length(ElevationStudyAreaScaledCat);
            end
        
            [~, IndStudyTemp] = sort(((xLongGeoTot(:)-xLongStudyAreaScaledCat(i1)).^2+(yLatGeoTot(:)-yLatStudyAreaScaledCat(i1)).^2));
            IndStudyTemp = IndStudyTemp(1:4);
            if ElevationTot(IndStudyTemp(1)) == 0
                ElevationTot(IndStudyTemp(1)) = ElevationStudyAreaScaledCat(i1);
            elseif ElevationTot(IndStudyTemp(2)) == 0
                ElevationTot(IndStudyTemp(2)) = ElevationStudyAreaScaledCat(i1);
            elseif ElevationTot(IndStudyTemp(3)) == 0
                ElevationTot(IndStudyTemp(3)) = ElevationStudyAreaScaledCat(i1);
            elseif ElevationTot(IndStudyTemp(4)) == 0
                ElevationTot(IndStudyTemp(4)) = ElevationStudyAreaScaledCat(i1);
            else
                ElevationTot(IndStudyTemp(1)) = (ElevationTot(IndStudyTemp(1))+ElevationStudyAreaScaledCat(i1))/2;
                DoublePointCount = DoublePointCount+1;
                PointsDoubledInd = [PointsDoubledInd; i1];
            end
        end

    case 2
        %% Elevation of merged DTM attribution OPT2
        [pp3, ee3] = getnan2([StudyAreaPolygonScaled.Vertices; nan, nan]);
        IndexDTMTotInStudyAreaScaled = find(inpoly([xLongGeoTot(:), yLatGeoTot(:)], pp3, ee3)==1);
        ProgressBar.Indeterminate = 'off';
        for i1 = 1:length(IndexDTMTotInStudyAreaScaled)
            if rem(i1,1000)==0
                ProgressBar.Message = strcat(num2str(i1)," points created of ", num2str(length(IndexDTMTotInStudyAreaScaled)));
                ProgressBar.Value = i1/length(IndexDTMTotInStudyAreaScaled);
            end
        
            [~, IndStudyTemp] = min(( (xLongStudyAreaScaledCat(:)-xLongGeoTot(IndexDTMTotInStudyAreaScaled(i1))).^2 + ...
                                      (yLatStudyAreaScaledCat(:)-yLatGeoTot(IndexDTMTotInStudyAreaScaled(i1))).^2   ));
            ElevationTot(IndexDTMTotInStudyAreaScaled(i1)) = ElevationStudyAreaScaledCat(IndStudyTemp);
        end

    case 3
        %% Elevation of merged DTM attribution OPT3
        [pp3, ee3] = getnan2([StudyAreaPolygonScaled.Vertices; nan, nan]);
        IndexDTMTotInStudyAreaScaled = find(inpoly([xLongGeoTot(:), yLatGeoTot(:)], pp3, ee3)==1);
        xLongSASToRemove = xLongStudyAreaScaledCat;
        yLatSASToRemove  = yLatStudyAreaScaledCat;
        ElevaSASToRemove = ElevationStudyAreaScaledCat;
        
        EmptyPointCount = 0;
        EmptyPointIndex = [];
        ProgressBar.Indeterminate = 'off';
        for i1 = 1:length(IndexDTMTotInStudyAreaScaled)
            if rem(i1,1000)==0
                ProgressBar.Message = strcat(num2str(i1)," points created of ", num2str(length(IndexDTMTotInStudyAreaScaled)));
                ProgressBar.Value = i1/length(IndexDTMTotInStudyAreaScaled);
            end
        
            [MinDist, IndStudyTemp] = min(( (xLongSASToRemove(:)-xLongGeoTot(IndexDTMTotInStudyAreaScaled(i1))).^2 + ...
                                            (yLatSASToRemove(:)-yLatGeoTot(IndexDTMTotInStudyAreaScaled(i1))).^2   ));
            if MinDist < 0.7*(dLong^2+dLat^2)^0.5
                ElevationTot(IndexDTMTotInStudyAreaScaled(i1)) = ElevaSASToRemove(IndStudyTemp);
            else
                EmptyPointCount = EmptyPointCount+1;
                EmptyPointIndex = [EmptyPointIndex; IndexDTMTotInStudyAreaScaled(i1)];
            end
        
            xLongSASToRemove(IndStudyTemp) = [];
            yLatSASToRemove(IndStudyTemp)  = [];
            ElevaSASToRemove(IndStudyTemp) = [];
        end

    case 4
        %% Elevation of merged DTM attribution OPT4
        Options = {'linear', 'nearest', 'natural'};
        InterpMethod = uiconfirm(Fig, 'What interpolation method do you want to use?', ...
                                      'Interpolation methods', 'Options',Options);

        ProgressBar.Message = 'Creation of merged DTM';
        [pp3, ee3] = getnan2([StudyAreaPolygonScaled.Vertices; nan, nan]);
        IndexDTMTotInStudyAreaScaled = find(inpoly([xLongGeoTot(:), yLatGeoTot(:)], pp3, ee3)==1);
        
        InterpolationDTM = scatteredInterpolant(xLongStudyAreaScaledCat(:), ...
                                                yLatStudyAreaScaledCat(:), ...
                                                double(ElevationStudyAreaScaledCat(:)), ...
                                                InterpMethod);
        
        ElevationTot(IndexDTMTotInStudyAreaScaled) = InterpolationDTM(xLongGeoTot(IndexDTMTotInStudyAreaScaled), ...
                                                                      yLatGeoTot(IndexDTMTotInStudyAreaScaled));

        EelevationAttrChoice = {EelevationAttrChoice, InterpMethod};

end

%% Plot to check the Study Area
fig_check = figure(2);
ax_check = axes(fig_check);
hold(ax_check,'on')

fastscatter(xLongGeoTot(:), yLatGeoTot(:), ElevationTot(:))

plot(StudyAreaPolygonScaled, 'FaceColor','none', 'LineWidth',1);
plot(BBEBPoly, 'FaceColor','none', 'LineWidth',1.5);

title('Study Area Scaled Polygon Check')

fig_settings(fold0, 'AxisTick');

%% Writing ASCII file & GeoTiff
Options = {'Geographic', 'Planar'};
CoordinateTypeChoice = uiconfirm(Fig, 'How do you want to write the file?', ...
                                      'Coordinates type', 'Options',Options);
if strcmp(CoordinateTypeChoice, 'Geographic')
    MinX = sprintf('%.6f', MinLong);
    MinY = sprintf('%.6f', MinLat);
    CellSize = RGeoTot.CellExtentInLatitude;
    DTMSize  = int16(deg2km(CellSize)*1000); % In meters, just for the title
    RTiff = RGeoTot;
else
    EPSG = str2double(inputdlg({["Set DTM EPSG"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
    CRS = projcrs(EPSG);
    [MinX, MinY] = projfwd(CRS, MinLat, MinLong);
    [MaxX, MaxY] = projfwd(CRS, MaxLat, MaxLong);
    CellSize = deg2km(RGeoTot.CellExtentInLatitude)*1000;
    DTMSize  = int16(CellSize);
    RTiff = maprefcells([MinX, MaxX], [MinY, MaxY], size(ElevationTot), 'ColumnsStartFrom','north');
    RTiff.ProjectedCRS = CRS;
end

DataToWriteHead = {'ncols'; 'nrows'; 'xllcorner'; 'yllcorner'; 'cellsize'; 'NODATA_value'};
DataToWriteValues = {size(ElevationTot,2); size(ElevationTot,1); MinX; MinY; CellSize; sprintf('%.2f', 0)};
DataToWrite1 = [char(DataToWriteHead), repmat(' ', 6, 1), char(string(DataToWriteValues))];

DataToWrite2 = sprintf('% .2f', ElevationTot(:));

cd(fold_raw_dtm)
% Writing txt...
writelines([string(DataToWrite1); string(DataToWrite2)], strcat('Merged-DTM-',string(DTMSize),'-',CoordinateTypeChoice,'.txt'))
% Writing GeoTiff...
MerdedTifName = strcat('Merged-DTM-',string(DTMSize),'-',CoordinateTypeChoice,'.tif');
if strcmp(CoordinateTypeChoice, 'Geographic')
    geotiffwrite(MerdedTifName, ElevationTot, RTiff)
else
    geotiffwrite(MerdedTifName, ElevationTot, RTiff, 'CoordRefSysCode',EPSG)
end
cd(fold0)

%% Saving...
ProgressBar.Indeterminate = 'on';
ProgressBar.Message = 'Saving created files...';

cd(fold_var)
VariablesStudyAreaDTM = {'StudyAreaPolygonScaled', 'BBEBPoly', 'RGeoTot', ...
                         'xLongGeoTot', 'yLatGeoTot', 'ElevationTot'};
save('MergedDTM.mat', VariablesStudyAreaDTM{:});
cd(fold0)