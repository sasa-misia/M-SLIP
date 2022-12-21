%% File loading
cd(fold_var)
load('StudyAreaVariables.mat');
cd(fold_raw_lit);

% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Initializing');
drawnow

ShapeInfo_Lithology = shapeinfo(FileName_Lithology);
[BoundingBoxX, BoundingBoxY] = projfwd(ShapeInfo_Lithology.CoordinateReferenceSystem,...
                    [MinExtremes(2) MaxExtremes(2)],[MinExtremes(1) MaxExtremes(1)]);
ReadShape_Lithology = shaperead(FileName_Lithology, ...
                                'BoundingBox',[BoundingBoxX(1) BoundingBoxY(1)
                                               BoundingBoxX(2) BoundingBoxY(2)]);

%% Extract litho name abbreviations
LithoAll = extractfield(ReadShape_Lithology,LitFieldName);
LithoAllUnique = unique(LithoAll);

IndexLitho = cell(1,length(LithoAllUnique));
for i1 = 1:length(LithoAllUnique)
    IndexLitho{i1} = find(strcmp(LithoAll,LithoAllUnique(i1)));
end

% Poligon creation
LithoPolygon = repmat(polyshape, 1, length(IndexLitho));
for i2 = 1:length(IndexLitho)
    [LithoVertexLat, LithoVertexLon] = projinv(ShapeInfo_Lithology.CoordinateReferenceSystem,...
                                               [ReadShape_Lithology(IndexLitho{i2}).X],...
                                               [ReadShape_Lithology(IndexLitho{i2}).Y]);
    LithoPolygon(i2) = polyshape([LithoVertexLon',LithoVertexLat'],'Simplify',false);

    Steps = length(IndexLitho);
    ProgressBar.Value = i1/Steps;
    ProgressBar.Message = strcat("Polygon n. ", string(i1)," of ", string(Steps));
    drawnow
end

% Find intersection among Litho polygon and the study area
LithoPolygonsStudyArea = intersect(LithoPolygon, StudyAreaPolygon);

% Removal of Litho excluded from the study area
EmptyLithoInStudyArea = cellfun(@isempty,{LithoPolygonsStudyArea.Vertices});

LithoPolygonsStudyArea(EmptyLithoInStudyArea) = [];
LithoAllUnique(EmptyLithoInStudyArea) = [];

%% Plot for check
ProgressBar.Indeterminate = true;
ProgressBar.Message = strcat("Plotting for check");
drawnow

f1 = figure(1);
plot(LithoPolygonsStudyArea')
title('Litho Polygon Check')
xlim([MinExtremes(1) MaxExtremes(1)])
ylim([MinExtremes(2) MaxExtremes(2)])
daspect([1 1 1])
legend(LithoAllUnique, 'Location','SouthEast', 'AutoUpdate','off')
hold on
plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1)

%% Writing of an excel that User has to compile before Step2
ProgressBar.Message = strcat("Excel Creation (User Control folder)");
drawnow

cd(fold_user)
FileName_LithoAssociation = 'LuDSCAssociation.xlsx';
DataToWrite1 = cell(length(LithoAllUnique)+1, 4); % Plus 1 because of header line
DataToWrite1(1, :) = {LitFieldName, 'US Associated', 'LU Abbrev (For Map)', 'RGB LU (for Map)'};
DataToWrite1(2:end, 1) = cellstr(LithoAllUnique');

DataToWrite2 = {'US', 'c''(kPa)', 'phi (°)', 'kt (h^-1)', 'A (kPa)', 'n', 'Color'};

WriteFile = checkduplicate(Fig, DataToWrite1, fold_user, FileName_LithoAssociation);
if WriteFile
    writecell(DataToWrite1, FileName_LithoAssociation, 'Sheet','Association');
    writecell(DataToWrite2, FileName_LithoAssociation, 'Sheet','DSCParameters');
end

% Creatings string names of variables in a cell array to save at the end
Variables = {'LithoPolygonsStudyArea', 'LithoAllUnique', 'FileName_LithoAssociation'};
Variables_Answer = {'AnswerAttributionSoilParameter', 'FileName_Lithology', 'LitFieldName'};

close(ProgressBar) % ProgressBar instead of Fig if on the app version

%% Saving of polygons included in the study area
cd(fold_var)
save('LithoPolygonsStudyArea.mat', Variables{:});
save('UserC_Answers.mat', Variables_Answer{:});
cd(fold0)