clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Creating StudyArea
tic
cd(fold_var)
load('UserA_Answers.mat')
cd(fold_raw_mun);

% Reading shapefile
ReadShape_StudyArea = shaperead(FileName_StudyArea);
ShapeInfo_StudyArea = shapeinfo(FileName_StudyArea);

if ~isempty(MunFieldName)
    AllMunInShape = extractfield(ReadShape_StudyArea,MunFieldName);
    IndexMun = zeros(length(MunSel),1);
    for i1 = 1:size(MunSel,2)
        IndMun = find(strcmp(AllMunInShape,MunSel(i1))); 
        IndexMun(i1) = IndMun;
    end
else
    IndexMun = 1;
end
    
% Poligon creation and evaluation of Study area extent
MunPolygon = repmat(polyshape, 1, length(IndexMun));
for i2 = 1:length(IndexMun)
    [StudyAreaVertexLat,StudyAreaVertexLon] = projinv(ShapeInfo_StudyArea.CoordinateReferenceSystem,...
                                                      ReadShape_StudyArea(IndexMun(i2)).X,...
                                                      ReadShape_StudyArea(IndexMun(i2)).Y);
    MunVertex = [StudyAreaVertexLon;StudyAreaVertexLat]';
    MunPolygon(i2) = polyshape(MunVertex,'Simplify',false);
end

% Union of Polygons
StudyAreaPolygon = union(MunPolygon);
StudyAreaPolygonClean = StudyAreaPolygon;

% Specific Window if you want only a part of study area
if SpecificWindow
    CoordinatesWindow = inputdlg({'Lon_{min} (°):'
                                  'Lon_{max} (°):'
                                  'Lat_{min} (°):'
                                  'Lat_{max} (°):'});
    CoordinatesWindow = cat(1,cellfun(@eval,CoordinatesWindow));
    PolWindow = polyshape([CoordinatesWindow(1) CoordinatesWindow(2) CoordinatesWindow(2) CoordinatesWindow(1)], ...
                          [CoordinatesWindow(3) CoordinatesWindow(3) CoordinatesWindow(4) CoordinatesWindow(4)]);
    StudyAreaPolygon = intersect(StudyAreaPolygon,PolWindow);
end

% Limit of study area
MaxExtremes = max(StudyAreaPolygon.Vertices);
MinExtremes = min(StudyAreaPolygon.Vertices);

% Creatings string names of variables in a cell array to save at the end
Variables = {'MunPolygon','StudyAreaPolygon','StudyAreaPolygonClean','MaxExtremes','MinExtremes'};
toc

%% Saving..
cd(fold_var)
save('StudyAreaVariables.mat',Variables{:});
cd(fold0)