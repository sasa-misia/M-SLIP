% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Processing shapefile of study area', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Reading shapefile
cd(fold_raw_mun);
ReadShapeStudyArea = shaperead(FileName_StudyArea);
ShapeInfoStudyArea = shapeinfo(FileName_StudyArea);

if isempty(ShapeInfoStudyArea.CoordinateReferenceSystem)
    EPSG = str2double(inputdlg({["Set Shapefile EPSG"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'32633'}));
    ShapeInfoStudyArea.CoordinateReferenceSystem = projcrs(EPSG);
end

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
ProgressBar.Indeterminate = 'off';
for i1 = 1:length(IndexMun)
    ProgressBar.Message = strcat("Creation of Municipality polygon n. ",num2str(i1)," of ", num2str(length(IndexMun)));
    ProgressBar.Value = i1/length(IndexMun);

    [StudyAreaVertexLat, StudyAreaVertexLon] = projinv(ShapeInfoStudyArea.CoordinateReferenceSystem, ...
                                                       ReadShapeStudyArea(IndexMun(i1)).X, ...
                                                       ReadShapeStudyArea(IndexMun(i1)).Y);
    MunVertex = [StudyAreaVertexLon; StudyAreaVertexLat]';
    MunPolygon(i1) = polyshape(MunVertex, 'Simplify',false);
end

%% Union of Polygons
ProgressBar.Indeterminate = 'on';
ProgressBar.Message = 'Union of polygons...';

StudyAreaPolygon = union(MunPolygon);
StudyAreaPolygonClean = StudyAreaPolygon;
StudyAreaPolygonExcluded = polyshape();

if SpecificWindow
    ProgressBar.Message = 'Creation of specific window...';

    ChoiceWindow = 'SingleWindow';
    cd(fold_var)
    if exist('InfoDetectedSoilSlips.mat', 'file')
        load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips','IndDefInfoDet')
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
            StudyAreaPolygon = intersect(StudyAreaPolygon, PolWindow); % Maybe not necessary if you want the entire rectangle. You can write: StudyAreaPolygon = PolWindow;

        case 'MultiWindows'
            xLongDet = [InfoDetectedSoilSlips{IndDefInfoDet}{:,5}];
            yLatDet  = [InfoDetectedSoilSlips{IndDefInfoDet}{:,6}];
            WindowSide = str2double(inputdlg("Set side of each window (m)", '', 1, {'1200'}));
            dLatHalfSide  = rad2deg(WindowSide/2/earthRadius); % /2 to have half of the size from the centre
            PolWindow = repmat(polyshape, 1, length(xLongDet));
            for i1 = 1:length(xLongDet)
                dLongHalfSide = rad2deg(acos( (cos(WindowSide/2/earthRadius)-sind(yLatDet(i1))^2)/cosd(yLatDet(i1))^2 )); % /2 to have half of the size from the centre
                PolWindow(i1) = polyshape( [xLongDet(i1)-dLongHalfSide, xLongDet(i1)+dLongHalfSide, ...
                                            xLongDet(i1)+dLongHalfSide, xLongDet(i1)-dLongHalfSide], ...
                                           [yLatDet(i1)-dLatHalfSide,  yLatDet(i1)-dLatHalfSide, ...
                                            yLatDet(i1)+dLatHalfSide,  yLatDet(i1)+dLatHalfSide ] );
            end
            StudyAreaPolygon = union(PolWindow);
    end

    StudyAreaPolygonClean = StudyAreaPolygon;

    for i1 = 1:length(MunPolygon)
        MunPolygon(i1) = intersect(StudyAreaPolygon, MunPolygon(i1));
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

ProgressBar.Message = 'Finising...';

%% Saving..
cd(fold_var)
save('StudyAreaVariables.mat', VariablesStudyArea{:});
save('UserStudyArea_Answers.mat', VariablesUserA{:});

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version