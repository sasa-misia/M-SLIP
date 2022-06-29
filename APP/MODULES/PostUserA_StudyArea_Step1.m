cd(fold_raw_mun);

% Reading shapefile
ReadShapeStudyArea = shaperead(FileName_StudyArea);
ShapeInfoStudyArea = shapeinfo(FileName_StudyArea);

if ~isempty(MunFieldName)
    AllMunInShape = extractfield(ReadShapeStudyArea,MunFieldName);
    IndexMun = zeros(length(MunSel),1);
    for i1 = 1:size(MunSel,1)
        IndMun = find(strcmp(AllMunInShape,MunSel(i1))); 
        IndexMun(i1) = IndMun;
    end
else
    IndexMun = 1;
end
    
% Poligon creation and evaluation of Study area extent
MunPolygon = repmat(polyshape, 1, length(IndexMun)); % Polyshape initialization
for i2 = 1:length(IndexMun)
    [StudyAreaVertexLat,StudyAreaVertexLon] = projinv(ShapeInfoStudyArea.CoordinateReferenceSystem, ...
                                                      ReadShapeStudyArea(IndexMun(i2)).X, ...
                                                      ReadShapeStudyArea(IndexMun(i2)).Y);
    MunVertex = [StudyAreaVertexLon;StudyAreaVertexLat]';
    MunPolygon(i2) = polyshape(MunVertex,'Simplify',false);
end

% Union of Polygons
StudyAreaPolygon = union(MunPolygon);
StudyAreaPolygonClean = StudyAreaPolygon;
StudyAreaPolygonExcluded = polyshape();

if SpecificWindow
    CoordinatesWindow = inputdlg({'Lon_{min} (°):'
                                  'Lon_{max} (°):'
                                  'Lat_{min} (°):'
                                  'Lat_{max} (°):'});    
    CoordinatesWindow = cat(1,cellfun(@eval,CoordinatesWindow));
    PolWindow = polyshape([CoordinatesWindow(1), CoordinatesWindow(2), ...
                           CoordinatesWindow(2), CoordinatesWindow(1)], ...
                          [CoordinatesWindow(3), CoordinatesWindow(3), ...
                           CoordinatesWindow(4), CoordinatesWindow(4)]);
    StudyAreaPolygon = intersect(StudyAreaPolygon,PolWindow);
    StudyAreaPolygonClean = StudyAreaPolygon;

end

% Limit of study area
MaxExtremes = max(StudyAreaPolygon.Vertices);
MinExtremes = min(StudyAreaPolygon.Vertices);

% Creatings string names of variables in a cell array to save at the end
VariablesStudyArea = {'MunPolygon', 'StudyAreaPolygon', 'StudyAreaPolygonClean', ...
                      'StudyAreaPolygonExcluded', 'MaxExtremes', 'MinExtremes'};
if SpecificWindow; Variables = [Variables, {'CoordinatesWindow'}]; end
VariablesUserA = {'FileName_StudyArea', 'MunFieldName', 'MunSel', 'SpecificWindow'};

%% Saving..
cd(fold_var)
save('StudyAreaVariables.mat', VariablesStudyArea{:});
save('UserA_Answers.mat', VariablesUserA{:});