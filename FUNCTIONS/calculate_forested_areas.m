% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Processing DTM of Study Area', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Loading files and vegetation info choice
cd(fold_var)
load('MergedDTM.mat', 'StudyAreaPolygonScaled','BBEBPoly','RGeoTot', ...
                      'xLongGeoTot','yLatGeoTot','ElevationTot')
load('StudyAreaVariables.mat', 'MaxExtremes','MinExtremes','StudyAreaPolygon')
load('UserA_Answers.mat', 'FileNameLandUses','LandUsesFieldName')
load('UserD_Answers.mat', 'FileName_Vegetation','VegFieldName')

EB = 500*360/2/pi/earthRadius;
BoundingBox = [MinExtremes(2)-EB, MaxExtremes(2)+EB
               MinExtremes(1)-EB, MaxExtremes(1)+EB];

Options = {'Vegetation', 'Land use', 'Both'};
ShapefileVeg = uiconfirm(Fig, 'What file do you want to use to define vegetation?', ...
                              'Shapefile for vegetation', 'Options',Options);

switch ShapefileVeg
    case 'Vegetation'
        [~, ~, FileExt] = fileparts(FileName_Vegetation);
        FileName_InfoVeg = {FileName_Vegetation};
        if strcmp(FileExt, '.shp')
            FieldName_Shape  = {VegFieldName};
        end
        fold_info_veg = {fold_raw_veg};
        [ForestedTot, VegetationAll, VegetationSelected, ...
            VegPolygon, VegetatedAreaPolygon, NumOfForestedPoints] = deal(cell(1));
        if strcmp(FileExt, '.shp')
            Type = {'Vegetation shapefile'};
        elseif strcmp(FileExt, '.tif')
            Type = {'Vegetation raster'};
        else
            error('Unknown type of file for vegetation, please contact the support.')
        end
    case 'Land use'
        FileName_InfoVeg = {FileNameLandUses};
        FieldName_Shape  = {LandUsesFieldName};
        fold_info_veg    = {fold_raw_land_uses};
        [ForestedTot, VegetationAll, VegetationSelected, ...
            VegPolygon, VegetatedAreaPolygon, NumOfForestedPoints] = deal(cell(1));
        Type = {'Land use shapefile'};
    case 'Both'
        [~, ~, FileExtVeg] = fileparts(FileName_Vegetation);
        FileName_InfoVeg = {FileName_Vegetation, FileNameLandUses};
        if strcmp(FileExtVeg, '.shp')
            FieldName_Shape  = {VegFieldName, LandUsesFieldName};
        else
            FieldName_Shape  = {[], LandUsesFieldName};
        end
        fold_info_veg = {fold_raw_veg, fold_raw_land_uses};
        [VegetationAll, VegetationSelected, ...
            VegPolygon, VegetatedAreaPolygon] = deal(cell(1, 2));
        [ForestedTot, NumOfForestedPoints] = deal(cell(1, 3));
        if strcmp(FileExtVeg, '.shp')
            Type = {'Vegetation shapefile', 'Land use shapefile', 'Mixed'};
        elseif strcmp(FileExtVeg, '.tif')
            Type = {'Vegetation raster', 'Land use shapefile', 'Mixed'};
        else
            error('Unknown type of file for vegetation, please contact the support.')
        end
end

%% Creation of forested maps rasters
for i1 = 1:length(FileName_InfoVeg)
    ProgressBar.Message = strcat("Reading file n. ", string(i1)," of ", string(length(FileName_InfoVeg)));
    cd(fold_info_veg{i1})

    if strcmp(Type{i1}, 'Vegetation raster') % REMEMBER TO IMPLEMENT MULTIPLE FILES, DIFFERENT TYPES, AND THE POSSIBILITY OF HAVING NO GEOREFERENCED FILE
        [ARastVeg,RRastVeg] = readgeoraster(FileName_InfoVeg{i1}, 'OutputType','native');
        [ARastVeg,RRastVeg] = geocrop(ARastVeg, RRastVeg, BoundingBox(1,:), BoundingBox(2,:));

        if string(RRastVeg.CoordinateSystemType)=="planar" && isempty(RRastVeg.ProjectedCRS)
            EPSG = str2double(inputdlg({["Set Raster EPSG"
                                         "For Example:"
                                         "Sicily -> 32633"
                                         "Emilia Romagna -> 25832"]}, '', 1, {'32633'}));
            RRastVeg.ProjectedCRS = projcrs(EPSG);
        elseif string(RRastVeg.CoordinateSystemType)=="geographic" && isempty(RRastVeg.GeographicCRS)
            RRastVeg.GeographicCRS = geocrs(4326);
        end

        if RRastVeg.CoordinateSystemType == "planar"
            [XTemp, YTemp] = worldGrid(RRastVeg);
            [yLatVeg, xLongVeg] = projinv(RRastVeg.ProjectedCRS, XTemp, YTemp);
            VegRasterSize = int16(RRastVeg.CellExtentInWorldX);
        elseif RRastVeg.CoordinateSystemType == "geographic"
            [yLatVeg, xLongVeg] = geographicGrid(RRastVeg);
            VegRasterSize = int16(deg2km(RRastVeg.CellExtentInLatitude)*1000);
        end

        WarningVegSize = uiconfirm(Fig, strcat("Veg raster size is: ",string(VegRasterSize), ...
                                               ", be sure to have an equal or larger resolution of your dtm for best results"), ...
                                        'Raster Veg Resolution', 'Options',{'Ok boss =)'});
    else
        ShapeInfo_Vegetation = shapeinfo(FileName_InfoVeg{i1});
        
        if ShapeInfo_Vegetation.NumFeatures == 0
            error('Shapefile is empty')
        end
        
        EB = 1000*360/2/pi/earthRadius; % ExtraBounding Lat/Lon increment for a respective 100 m length, necessary due to conversion errors
        [BoundingBoxX,BoundingBoxY] = projfwd(ShapeInfo_Vegetation.CoordinateReferenceSystem, ...
                                              [MinExtremes(2)-EB, MaxExtremes(2)+EB], ...
                                              [MinExtremes(1)-EB, MaxExtremes(1)+EB]);
        ReadShape_Vegetation = shaperead(FileName_InfoVeg{i1}, ...
                                         'BoundingBox',[BoundingBoxX(1), BoundingBoxY(1)
                                                        BoundingBoxX(2), BoundingBoxY(2)]);
        
        if size(ReadShape_Vegetation, 1) < 1
            error('Shapefile is not empty but have no element in bounding box!')
        end
        cd(fold0)
        
        %% Extract vegetation name abbreviations
        VegetationAll{i1} = extractfield(ReadShape_Vegetation,FieldName_Shape{i1});
        VegetationAllUnique = unique(VegetationAll{i1});
        VegetationChoice = listdlg('PromptString',{'Choose forested areas:',''}, 'ListString',VegetationAllUnique);
        VegetationSelected{i1} = VegetationAllUnique(VegetationChoice);
        
        IndexVeg = cell(1, length(VegetationSelected{i1}));
        for i2 = 1:length(VegetationSelected{i1})
            IndexVeg{i2} = find(strcmp(VegetationAll{i1},VegetationSelected{i1}(i2)));
        end
        
        % Poligon creation
        ProgressBar.Indeterminate = false;
        VegPolygon{i1} = repmat(polyshape, 1, length(IndexVeg));
        for i2 = 1:length(IndexVeg)
            [VegVertexLat,VegVertexLon] = projinv(ShapeInfo_Vegetation.CoordinateReferenceSystem,...
                                                  [ReadShape_Vegetation(IndexVeg{i2}).X],...
                                                  [ReadShape_Vegetation(IndexVeg{i2}).Y]);
            VegPolygon{i1}(i2) = polyshape([VegVertexLon',VegVertexLat'], 'Simplify',false);
        
            Steps = length(IndexVeg);
            ProgressBar.Value = i2/Steps;
            ProgressBar.Message = strcat("Polygon n. ", string(i2)," of ", string(Steps));
            drawnow
        end
        
        ProgressBar.Indeterminate = true;
        ProgressBar.Message = strcat("Union of vegetation polygons");
        VegetatedAreaPolygon{i1} = union(VegPolygon{i1});
        
        ProgressBar.Message = strcat("Intersection with Study Area");
        VegetatedAreaPolygon{i1} = intersect(VegetatedAreaPolygon{i1}, StudyAreaPolygonScaled);
    end
    
    %% Forested raster creation
    ForestedTot{i1} = zeros(size(ElevationTot));
    
    if strcmp(Type{i1}, 'Vegetation raster')
        ForestedTemp = ForestedTot{i1};
        [pp1, ee1] = getnan2([StudyAreaPolygonScaled.Vertices; nan, nan]);
        IndexVegRasterInStudyAreaScaled = find(inpoly([xLongVeg(:), yLatVeg(:)], pp1, ee1)==1);

        Options = {'linear', 'nearest', 'natural'};
        InterpMethod = uiconfirm(Fig, 'What interpolation method do you want to use for veg raster?', ...
                                      'Interpolation methods', 'Options',Options);

        InterpolationVeg = scatteredInterpolant(xLongVeg(IndexVegRasterInStudyAreaScaled), ...
                                                yLatVeg(IndexVegRasterInStudyAreaScaled), ...
                                                double(ARastVeg(IndexVegRasterInStudyAreaScaled)), ...
                                                InterpMethod);

        [pp2, ee2] = getnan2([StudyAreaPolygonScaled.Vertices; nan, nan]);
        IndexDTMTotInStudyAreaScaled = find(inpoly([xLongGeoTot(:), yLatGeoTot(:)], pp2, ee2)==1);

        ForestedTemp(IndexDTMTotInStudyAreaScaled) = InterpolationVeg(xLongGeoTot(IndexDTMTotInStudyAreaScaled), ...
                                                                         yLatGeoTot(IndexDTMTotInStudyAreaScaled));

        MinValueVegRaster = min(min(ARastVeg));
        MaxValueVegRaster = max(max(ARastVeg));
        ForestedThreshold = str2double(inputdlg({[strcat("Value contained in raster going from: ",string(MinValueVegRaster)," to: ",string(MaxValueVegRaster))
                                                  "Set your threshold for defining forested areas"]}, '', 1, {char(string((MaxValueVegRaster-MinValueVegRaster)/2))}));
        IndexDTMTotWithVeg = find(ForestedTemp(:) >= ForestedThreshold);
    else
        [pp1, ee1] = getnan2([VegetatedAreaPolygon{i1}.Vertices; nan, nan]);
        IndexDTMTotWithVeg = find(inpoly([xLongGeoTot(:), yLatGeoTot(:)], pp1, ee1)==1);
    end
    
    ForestedTot{i1}(IndexDTMTotWithVeg) = 1;

    NumOfForestedPoints{i1} = sum(ForestedTot{i1}(:)==1);
end

%% Creation of mixed vegetation map
if strcmp(ShapefileVeg,'Both')
    DiffMatrix = abs(ForestedTot{1}-ForestedTot{2});
    ForestedTot{3} = max(ForestedTot{1}-DiffMatrix,0); % Taking ForestedTot{1} or ForestedTot{2} make no difference
    NumOfForestedPoints{3} = sum(ForestedTot{3}(:)==1);
end

%% Plot to check the Study Area
for i1 = 1:length(ForestedTot)
    fig_check = figure(i1+1);
    ax_check = axes(fig_check);
    hold(ax_check,'on')
    
    fastscatter(xLongGeoTot(:), yLatGeoTot(:), ForestedTot{i1}(:))
    
    plot(StudyAreaPolygonScaled, 'FaceColor','none', 'LineWidth',1);
    plot(BBEBPoly, 'FaceColor','none', 'LineWidth',1.5);
    
    title(strcat("Study Area Scaled Forested Check: ", Type{i1}))
    
    fig_settings(fold0, 'AxisTick');
end

%% Writing ASCII file
Options = {'Geographic', 'Planar'};
CoordinateTypeChoice = uiconfirm(Fig, 'How do you want to write the file?', ...
                                      'Coordinates type', 'Options',Options);
if strcmp(CoordinateTypeChoice, 'Geographic')
    MinX = sprintf('%.6f', min(RGeoTot.LongitudeLimits));
    MinY = sprintf('%.6f', min(RGeoTot.LatitudeLimits));
    CellSize = RGeoTot.CellExtentInLatitude;
    DTMSize  = int16(deg2km(CellSize)*1000); % In meters, just for the title
else
    EPSG = str2double(inputdlg({["Set DTM EPSG"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'32633'}));
    CRS = projcrs(EPSG);
    [MinX, MinY] = projfwd(CRS, min(RGeoTot.LatitudeLimits), min(RGeoTot.LongitudeLimits));
    CellSize = deg2km(RGeoTot.CellExtentInLatitude)*1000;
    DTMSize  = int16(CellSize);
end

DataToWriteHead = {'ncols'; 'nrows'; 'xllcorner'; 'yllcorner'; 'cellsize'; 'NODATA_value'};
DataToWriteValues = {size(ForestedTot{1},2); size(ForestedTot{1},1); MinX; MinY; CellSize; sprintf('%i', 0)};
DataToWrite1 = [char(DataToWriteHead), repmat(' ', 6, 1), char(string(DataToWriteValues))];

cd(fold_raw_veg)
for i1 = 1:length(ForestedTot)
    DataToWrite2 = sprintf('% i', ForestedTot{i1}(:));
    
    writelines([string(DataToWrite1); string(DataToWrite2)], strcat('ForestedArea-',string(DTMSize),'-',CoordinateTypeChoice,'-',Type{i1},'.txt'))
end
cd(fold0)

%% Saving...
ProgressBar.Indeterminate = 'on';
ProgressBar.Message = 'Saving created files...';

cd(fold_var)
VariablesForestedAreaDTM = {'StudyAreaPolygonScaled', 'BBEBPoly', 'RGeoTot', ...
                            'xLongGeoTot', 'yLatGeoTot', 'VegetationAll', ...
                            'VegetationSelected', 'VegetatedAreaPolygon', ...
                            'VegPolygon', 'ForestedTot', 'Type'};
save('MergedForestedRaster.mat', VariablesForestedAreaDTM{:});
cd(fold0)