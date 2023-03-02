%% File loading
tic
cd(fold_var)
load('StudyAreaVariables.mat');
cd(fold_raw_veg);

% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Initializing');
drawnow

ShapeInfo_Vegetation=shapeinfo(FileName_Vegetation);

if ShapeInfo_Vegetation.NumFeatures == 0
    error('Shapefile is empty')
end

EB = 1000*360/2/pi/earthRadius; % ExtraBounding Lat/Lon increment for a respective 100 m length, necessary due to conversion errors
[BoundingBoxX,BoundingBoxY] = projfwd(ShapeInfo_Vegetation.CoordinateReferenceSystem, ...
                                      [MinExtremes(2)-EB, MaxExtremes(2)+EB], ...
                                      [MinExtremes(1)-EB, MaxExtremes(1)+EB]);
ReadShape_Vegetation = shaperead(FileName_Vegetation, ...
                                 'BoundingBox',[BoundingBoxX(1), BoundingBoxY(1)
                                                BoundingBoxX(2), BoundingBoxY(2)]);

if size(ReadShape_Vegetation, 1) < 1
    error('Shapefile is not empty but have no element in bounding box!')
end

%% Extract vegetation name abbreviations
VegetationAll = extractfield(ReadShape_Vegetation,VegFieldName);
VegetationAllUnique = unique(VegetationAll);

IndexVeg = cell(1,length(VegetationAllUnique));
for i1 = 1:length(VegetationAllUnique)
    IndexVeg{i1} = find(strcmp(VegetationAll,VegetationAllUnique(i1)));
end

% Poligon creation
VegPolygon=repmat(polyshape, 1, length(IndexVeg));
for i2=1:length(IndexVeg)
    [VegVertexLat,VegVertexLon] = projinv(ShapeInfo_Vegetation.CoordinateReferenceSystem,...
                                          [ReadShape_Vegetation(IndexVeg{i2}).X],...
                                          [ReadShape_Vegetation(IndexVeg{i2}).Y]);
    VegPolygon(i2) = polyshape([VegVertexLon',VegVertexLat'], 'Simplify',false);

    Steps = length(IndexVeg);
    ProgressBar.Value = i1/Steps;
    ProgressBar.Message = strcat("Polygon n. ", string(i1)," of ", string(Steps));
    drawnow
end

ProgressBar.Indeterminate = true;
ProgressBar.Message = strcat("Intersection with Study Area");
drawnow

% Find intersection among Veg polygons and the study area
VegPolygonsStudyArea = intersect(VegPolygon, StudyAreaPolygon); 

% Removal of Veg excluded from the study area
EmptyVegInStudyArea = cellfun(@isempty,{VegPolygonsStudyArea.Vertices});

VegPolygonsStudyArea(EmptyVegInStudyArea) = [];
VegetationAllUnique(EmptyVegInStudyArea) = [];

%% Plot to check the vegetation in the Study Area
ProgressBar.Message = strcat("Plotting for check");
drawnow

f1 = figure(1);
plot(VegPolygonsStudyArea)
title('Vegetation Polygon Check')
legend(VegetationAllUnique,'Location','SouthEast','AutoUpdate','off')
hold on
plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1)

fig_settings(fold0, 'AxisTick');

%% Writing of an excel that User has to compile before Step2
ProgressBar.Message = strcat("Excel Creation (User Control folder)");
drawnow

cd(fold_user)
FileName_VegAssociation = 'VuDVCAssociation.xlsx';
DataToWrite1 = cell(length(VegetationAllUnique)+1, 4); % Plus 1 because of header line
DataToWrite1(1, :) = {VegFieldName, 'UV Associated', 'VU Abbrev (For Map)', 'RGB VU (for Map)'};
DataToWrite1(2:end, 1) = cellstr(VegetationAllUnique');

DataToWrite2 = {'UV','c_R''(kPa)','\beta (-)','Color'};

WriteFile = checkduplicate(Fig, DataToWrite1, fold_user, FileName_VegAssociation);
if WriteFile
    writecell(DataToWrite1, FileName_VegAssociation, 'Sheet','Association');
    writecell(DataToWrite2, FileName_VegAssociation, 'Sheet','DVCParameters');
end

VariablesVeg = {'VegPolygonsStudyArea', 'VegetationAllUnique', 'FileName_VegAssociation'};
VariablesAnswerD = {'AnswerAttributionVegetationParameter', 'FileName_Vegetation', 'VegFieldName'};
toc

close(ProgressBar) % ProgressBar instead of Fig if on the app version

%% Saving of polygons included in the study area
cd(fold_var)
save('VegPolygonsStudyArea.mat', VariablesVeg{:});
save('UserD_Answers.mat', VariablesAnswerD{:}, '-append');
cd(fold0)