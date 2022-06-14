clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Creation of land uses polygon
tic
cd(fold_var)
load('UserA_Answers.mat')
load('StudyAreaVariables.mat')
cd(fold_raw_land_uses)

Fig = uifigure; % Remember to comment on app version
ProgressBar = uiprogressdlg(Fig, 'Title','Processing shapefile of land uses', ...
                            'Message','Reading file', 'Cancelable','on', 'Indeterminate','on');
drawnow

ShapeInfo_LandUses = shapeinfo(FileName_LandUses);
[BoundingBoxX,BoundingBoxY] = projfwd(ShapeInfo_LandUses.CoordinateReferenceSystem, ...
                                      [MinExtremes(2) MaxExtremes(2)],[MinExtremes(1) MaxExtremes(1)]);
ReadShape_LandUses = shaperead(FileName_LandUses, 'BoundingBox', ...
                               [BoundingBoxX(1) BoundingBoxY(1);BoundingBoxX(2) BoundingBoxY(2)]);

IndexToRemove = false(1, size(ReadShape_LandUses,1)); % Initialize logic array
for i1 = 1:size(ReadShape_LandUses,1)
    IndexToRemove(i1) = numel(ReadShape_LandUses(i1).X)>30000; % To remove too big polygons
end
ReadShape_LandUses(IndexToRemove) = [];

AllLandRaw = extractfield(ReadShape_LandUses,LandUsesFieldName);
AllLandUnique = unique(AllLandRaw);
IndexLandUses = cell(1,length(AllLandUnique)); % Initialize cell array
for i1 = 1:length(AllLandUnique)
    IndexLandUses{i1} = find(strcmp(AllLandUnique(i1),AllLandRaw));
end

% Union of polygon on the same class
Steps = length(IndexLandUses);
ProgressBar.Indeterminate = 'off';
LandUsePolygons = repmat(polyshape, 1, length(IndexLandUses)); % Initialize polyshape array
for i1 = 1:length(IndexLandUses)
    ProgressBar.Message = strcat('Creation of polygon n. ',num2str(i1)," of ", num2str(length(IndexLandUses)));
    ProgressBar.Value = i1/Steps;

    [LandUseVertexLat,LandUseVertexLon] = projinv(ShapeInfo_LandUses.CoordinateReferenceSystem, ...
                                                  [ReadShape_LandUses(IndexLandUses{i1}).X], ...
                                                  [ReadShape_LandUses(IndexLandUses{i1}).Y]);
    LandUsePolygons(i1) = polyshape([LandUseVertexLon',LandUseVertexLat'],'Simplify',false);

    if ProgressBar.CancelRequested
        return
    end
end

% Intersection between Study Area and LandUsePolygons
LandUsePolygonsStudyArea = intersect(LandUsePolygons,StudyAreaPolygon);

% Removal of Land Uses excluded from the study area
EmptyLandUseInStudyArea = false(1, length(LandUsePolygonsStudyArea));
for i1 = 1:length(LandUsePolygonsStudyArea)
    EmptyLandUseInStudyArea(i1) = isempty(LandUsePolygonsStudyArea(i1).Vertices);
end
LandUsePolygonsStudyArea(EmptyLandUseInStudyArea) = [];
AllLandUnique(EmptyLandUseInStudyArea) = [];

VariablesLandUses = {'LandUsePolygonsStudyArea','AllLandUnique'};
VariablesLandUsesUser = {'FileName_LandUses';'LandUsesFieldName'};

%% Writing of an excel that User could compile
cd(fold_user)
FileName_LandUsesAssociation = 'LandUsesAssociation.xlsx';
if isfile(FileName_LandUsesAssociation)
    warning(strcat(FileName_LandUsesAssociation," already exist"))
end
ColHeader1 = {LandUsesFieldName,'Abbreviation (for Map)','RGB (for Map)'};
writecell(ColHeader1,FileName_LandUsesAssociation,'Sheet','Association','Range','A1');
writecell(AllLandUnique',FileName_LandUsesAssociation,'Sheet','Association','Range','A2');

VariablesLandUses = [VariablesLandUses, {'FileName_LandUsesAssociation'}];
toc

ProgressBar.Message = 'Finising...';
close(Fig) % ProgressBar instead of Fig if on the app version

%% Saving..
cd(fold_var)
save('LandUsesVariables.mat',VariablesLandUses{:});
save('UserA_Answers.mat',VariablesLandUsesUser{:},'-append');
cd(fold0)