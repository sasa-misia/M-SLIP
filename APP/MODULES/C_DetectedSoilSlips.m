% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Initializing', 'Indeterminate','on');
drawnow

%% File loading
cd(fold_var)
load('StudyAreaVariables.mat', 'StudyAreaPolygon','MaxExtremes','MinExtremes');

cd(fold_raw_det_ss);
[FileNameIDs, FilePath] = uigetfile('*.shp', 'Choose your shapefile', 'MultiSelect','off');
FullName = [FilePath, FileNameIDs];

if ~exist([fold_raw_det_ss,sl,FileNameIDs], 'file')
    Files = string({dir(FilePath).name});
    [~, FileNameIDsNoExt] = fileparts(FileNameIDs);
    IndFilesToCopy = contains(Files,FileNameIDsNoExt);
    FilesToCopy = strcat(FilePath,Files(IndFilesToCopy));
    arrayfun(@(x) copyfile(x, fold_raw_det_ss), FilesToCopy);
end

ShapeInfo_SS = shapeinfo(FileNameIDs);

if ShapeInfo_SS.NumFeatures == 0
    error('Shapefile is empty')
end

EB = 500*180/pi/earthRadius; % ExtraBounding Lat/Lon increment for a respective 500 m length, necessary due to conversion errors
[BoundingBoxX, BoundingBoxY] = projfwd(ShapeInfo_SS.CoordinateReferenceSystem, ...
                                       [MinExtremes(2)-EB, MaxExtremes(2)+EB], ...
                                       [MinExtremes(1)-EB, MaxExtremes(1)+EB]);

ReadShape_SS = shaperead(FileNameIDs, 'BoundingBox',[BoundingBoxX(1) BoundingBoxY(1)
                                                  BoundingBoxX(2) BoundingBoxY(2)]);

if size(ReadShape_SS, 1) < 1
    error('Shapefile is not empty but have no element in bounding box!')
end
cd(fold0)

%% Extract ids
SoilSlipsShapeFields = [{ShapeInfo_SS.Attributes.Name},"None of these"];
FieldChoice = listdlg('PromptString',{'Choose field where you have the IDs: ',''}, ...
                      'ListString',SoilSlipsShapeFields, 'SelectionMode','single'); % REMEMBER: This colum should contain same values type of the second column of your excel, containing detected soil slips

IDsAll = extractfield(ReadShape_SS, SoilSlipsShapeFields(FieldChoice));
IDsAllUnique = unique(IDsAll);

IndexIDs = cell(1,length(IDsAllUnique));
for i1 = 1:length(IDsAllUnique)
    IndexIDs{i1} = find(strcmp(IDsAll,IDsAllUnique(i1)));
end

% Poligons creation
ProgressBar.Indeterminate = 'off';
IDsPolygon = repmat(polyshape, 1, length(IndexIDs));
for i1 = 1:length(IndexIDs)
    [IDsVertexLat, IDsVertexLon] = projinv(ShapeInfo_SS.CoordinateReferenceSystem, ...
                                               [ReadShape_SS(IndexIDs{i1}).X], ...
                                               [ReadShape_SS(IndexIDs{i1}).Y]);
    IDsPolygon(i1) = polyshape([IDsVertexLon',IDsVertexLat'],'Simplify',false);

    Steps = length(IndexIDs);
    ProgressBar.Value = i1/Steps;
    ProgressBar.Message = strcat("Polygon n. ", string(i1)," of ", string(Steps));
    drawnow
end
ProgressBar.Indeterminate = 'on';

% Find intersection among IDs polygon and the study area
ProgressBar.Message = 'Intersection with study area...';
IDsPolygonsStudyArea = intersect(IDsPolygon, StudyAreaPolygon);

% Removal of IDs excluded from the study area
ProgressBar.Message = 'Removal of IDs outside the study area...';
EmptyIDsInStudyArea = cellfun(@isempty,{IDsPolygonsStudyArea.Vertices});

IDsPolygonsStudyArea(EmptyIDsInStudyArea) = [];
IDsAllUnique(EmptyIDsInStudyArea) = [];

%% Plot for check
ProgressBar.Message = strcat("Plotting for check");

fig_check = figure(1);
ax_check = axes(fig_check);
hold(ax_check,'on')

plot(IDsPolygonsStudyArea)
title('Litho Polygon Check')
xlim([MinExtremes(1), MaxExtremes(1)])
ylim([MinExtremes(2), MaxExtremes(2)])
% legend(IDsAllUnique, 'Location','SouthEast', 'AutoUpdate','off')
plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1)

yLatMean    = (MaxExtremes(2)+MinExtremes(2))/2;
dLat1Meter  = rad2deg(1/earthRadius); % 1 m in lat
dLong1Meter = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long

RatioLatLong = dLat1Meter/dLong1Meter;
daspect([1, RatioLatLong, 1])

%% Saving of polygons included in the study area
cd(fold_var)
VariablesSS = {'IDsPolygonsStudyArea', 'IDsAllUnique', 'FileNameIDs'};
save('SoilSlipPolygonsStudyArea.mat', VariablesSS{:});
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version