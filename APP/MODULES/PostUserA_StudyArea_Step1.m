%% Reading shapefile
cd(fold_raw_mun);
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
    
%% Poligon creation and evaluation of Study area extent
MunPolygon = repmat(polyshape, 1, length(IndexMun)); % Polyshape initialization
for i1 = 1:length(IndexMun)
    [StudyAreaVertexLat,StudyAreaVertexLon] = projinv(ShapeInfoStudyArea.CoordinateReferenceSystem, ...
                                                      ReadShapeStudyArea(IndexMun(i1)).X, ...
                                                      ReadShapeStudyArea(IndexMun(i1)).Y);
    MunVertex = [StudyAreaVertexLon;StudyAreaVertexLat]';
    MunPolygon(i1) = polyshape(MunVertex,'Simplify',false);
end

%% Union of Polygons
StudyAreaPolygon = union(MunPolygon);
StudyAreaPolygonClean = StudyAreaPolygon;
StudyAreaPolygonExcluded = polyshape();

if SpecificWindow

    ChoiceWindow = 'SingleWindow';
    cd(fold_var)
    if exist('InfoDetectedSoilSlips.mat', 'file')
        load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips')
        Options = {'SingleWindow', 'MultiWindows'};
        ChoiceWindow = uiconfirm(Fig, ['Would you like to create a single window or ' ...
                                       'multiple windows based on detected soil slip'], ...
                                       'Window type', 'Options',Options);
    end

    switch ChoiceWindow
        case 'SingleWindow'
            CoordinatesWindow = inputdlg({'Lon_{min} (°):'
                                          'Lon_{max} (°):'
                                          'Lat_{min} (°):'
                                          'Lat_{max} (°):'});    
            CoordinatesWindow = cat(1,cellfun(@eval,CoordinatesWindow));
            PolWindow = polyshape( [CoordinatesWindow(1), CoordinatesWindow(2), ...
                                    CoordinatesWindow(2), CoordinatesWindow(1)], ...
                                   [CoordinatesWindow(3), CoordinatesWindow(3), ...
                                    CoordinatesWindow(4), CoordinatesWindow(4)] );
            StudyAreaPolygon = intersect(StudyAreaPolygon,PolWindow);
            StudyAreaPolygonClean = StudyAreaPolygon;
        case 'MultiWindows'
            WindowSide = str2double(inputdlg("Set side of each window (m)", '', 1, {'1200'}));
            HalfWindowSideDegree = km2deg(WindowSide/1000)/2;
            xLongDet = [InfoDetectedSoilSlips{:,5}];
            yLatDet  = [InfoDetectedSoilSlips{:,6}];
            PolWindow = repmat(polyshape, 1, length(xLongDet));
            for i1 = 1:length(xLongDet)
                PolWindow(i1) = polyshape( [xLongDet(i1)-HalfWindowSideDegree, xLongDet(i1)+HalfWindowSideDegree, ...
                                            xLongDet(i1)+HalfWindowSideDegree, xLongDet(i1)-HalfWindowSideDegree], ...
                                           [yLatDet(i1)-HalfWindowSideDegree,  yLatDet(i1)-HalfWindowSideDegree, ...
                                            yLatDet(i1)+HalfWindowSideDegree,  yLatDet(i1)+HalfWindowSideDegree ] );
            end
            StudyAreaPolygon = union(PolWindow);
            StudyAreaPolygonClean = StudyAreaPolygon;
    end

end

%% Limit of study area
MaxExtremes = max(StudyAreaPolygon.Vertices);
MinExtremes = min(StudyAreaPolygon.Vertices);

%% Creatings string names of variables in a cell array to save at the end
VariablesStudyArea = {'MunPolygon', 'StudyAreaPolygon', 'StudyAreaPolygonClean', ...
                      'StudyAreaPolygonExcluded', 'MaxExtremes', 'MinExtremes'};
if SpecificWindow; VariablesStudyArea = [VariablesStudyArea, {'PolWindow'}]; end
VariablesUserA = {'FileName_StudyArea', 'MunFieldName', 'MunSel', 'SpecificWindow'};

%% Saving..
cd(fold_var)
save('StudyAreaVariables.mat', VariablesStudyArea{:});
save('UserA_Answers.mat', VariablesUserA{:});