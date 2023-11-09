if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Processing shapefile of land uses', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Creation of land uses polygon
tic
cd(fold_var)
load('StudyAreaVariables.mat');
cd(fold_raw_land_uses)

ShapeInfoLandUses = shapeinfo(FileNameLandUses);

if ShapeInfoLandUses.NumFeatures == 0
    error('Shapefile is empty')
end

if isempty(ShapeInfoLandUses.CoordinateReferenceSystem)
    EPSG = str2double(inputdlg({["Set Shapefile EPSG"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'32633'}));
    ShapeInfoLandUses.CoordinateReferenceSystem = projcrs(EPSG);
end

PointShapeType = strcmp( ShapeInfoLandUses.ShapeType, 'PointZ' );
if PointShapeType % REMEMBER TO CONTINUE THIS CHANGE IN OTHER SCRIPTS

    ReadShapeLandUses = readgeotable(FileNameLandUses);
    [AllPointShapeLat, AllPointShapeLong] = projinv(ShapeInfoLandUses.CoordinateReferenceSystem, ...
                                                                    [ReadShapeLandUses.Shape.X], ...
                                                                    [ReadShapeLandUses.Shape.Y]);
    AllLandRaw = string(ReadShapeLandUses.(LandUsesFieldName));

    [pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
    IndexShapePointsInStudyArea = find(inpoly([AllPointShapeLong, AllPointShapeLat], pp1, ee1)==1);

    AllPointInStudyLong = AllPointShapeLong(IndexShapePointsInStudyArea);
    AllPointInStudyLat  = AllPointShapeLat(IndexShapePointsInStudyArea);
    AllLandInStudy      = AllLandRaw(IndexShapePointsInStudyArea);

    AllLandUnique = unique(AllLandInStudy);
    IndexLandUses = cell(1,length(AllLandUnique)); % Initialize cell array
    for i1 = 1:length(AllLandUnique)
        IndexLandUses{i1} = find(strcmp(AllLandUnique(i1),AllLandInStudy));
    end

    LandUsePointsStudyArea = repmat(geopointshape, 1, length(IndexLandUses));
    ProgressBar.Indeterminate = 'off';
    for i1 = 1:length(IndexLandUses)
    
        ProgressBar.Message = strcat("Creation of Multipoints n. ",num2str(i1)," of ", num2str(length(IndexLandUses)));
        ProgressBar.Value = i1/length(IndexLandUses);

        LandUsePointsStudyArea(i1) = geopointshape({[AllPointInStudyLat(IndexLandUses{i1})]'}, ...
                                                   {[AllPointInStudyLong(IndexLandUses{i1})]'});
    end

    Variables = {'LandUsePointsStudyArea', 'AllLandUnique', 'PointShapeType'};

else

    EB = 1000*360/2/pi/earthRadius; % ExtraBounding Lat/Lon increment for a respective 100 m length, necessary due to conversion errors
    [BoundingBoxX, BoundingBoxY] = projfwd(ShapeInfoLandUses.CoordinateReferenceSystem,...
                                           [MinExtremes(2)-EB, MaxExtremes(2)+EB], ...
                                           [MinExtremes(1)-EB, MaxExtremes(1)+EB]);
    ReadShapeLandUses = shaperead(FileNameLandUses, ...
                                  'BoundingBox',[BoundingBoxX(1), BoundingBoxY(1)
                                                 BoundingBoxX(2), BoundingBoxY(2)]);

    if size(ReadShapeLandUses, 1) < 1
        error('Shapefile is not empty but have no element in bounding box!')
    end
    
    IndexToRemove = false(1, size(ReadShapeLandUses,1)); % Initialize logic array
    for i1 = 1:size(ReadShapeLandUses,1)
        IndexToRemove(i1) = numel(ReadShapeLandUses(i1).X)>80000;  % IMPORTANT! Based on this number you will remove some polygons
    end
    ReadShapeLandUses(IndexToRemove) = [];
    
    if any(IndexToRemove)
        uialert(Fig, ['Attention, some polygons have too much points, therefore, ' ...
                      'they have been excluded. Please contact support'], ...
                      'Polygons error')
    end
    
    AllLandRaw = extractfield(ReadShapeLandUses,LandUsesFieldName);
    AllLandUnique = unique(AllLandRaw);
    IndexLandUses = cell(1,length(AllLandUnique)); % Initialize cell array
    for i1 = 1:length(AllLandUnique)
        if isnumeric(AllLandRaw)
            IndexLandUses{i1} = find(AllLandUnique(i1) == AllLandRaw);
        else
            IndexLandUses{i1} = find(strcmp(AllLandUnique(i1),AllLandRaw));
        end
    end
    
    % Union of polygon on the same class
    LandUsePolygons = repmat(polyshape, 1, length(IndexLandUses)); % Initialize polyshape array
    ProgressBar.Indeterminate = 'off';
    for i1 = 1:length(IndexLandUses)
    
        ProgressBar.Message = strcat("Creation of polygon n. ",num2str(i1)," of ", num2str(length(IndexLandUses)));
        ProgressBar.Value = i1/length(IndexLandUses);
    
        [LandUseVertexLat, LandUseVertexLon] = projinv(ShapeInfoLandUses.CoordinateReferenceSystem,...
                                                [ReadShapeLandUses(IndexLandUses{i1}).X],...
                                                [ReadShapeLandUses(IndexLandUses{i1}).Y]);
        LandUsePolygons(i1) = polyshape([LandUseVertexLon', LandUseVertexLat'], 'Simplify',false);
        
        if ProgressBar.CancelRequested
            return
        end
    end
    
    % Intersection between Study Area and LandUsePolygons
    LandUsePolygonsStudyArea = intersect(LandUsePolygons,StudyAreaPolygon);
    
    % Removal of Land Uses excluded from the study area
    EmptyLandUseInStudyArea = false(1, length(LandUsePolygonsStudyArea));
    for i3 = 1:length(LandUsePolygonsStudyArea)
        EmptyLandUseInStudyArea(i3) = isempty(LandUsePolygonsStudyArea(i3).Vertices);
    end
    
    LandUsePolygonsStudyArea(EmptyLandUseInStudyArea) = [];
    AllLandUnique(EmptyLandUseInStudyArea) = [];
    if isnumeric(AllLandUnique); AllLandUnique = string(AllLandUnique); end
    
    LandToRemovePolygon = [];
    
    Variables = {'LandUsePolygonsStudyArea', 'AllLandUnique', 'LandToRemovePolygon', 'PointShapeType'};

end

%% Writing of an excel that User could compile
cd(fold_user)
FileNameLandUsesAssociation = 'LandUsesAssociation.xlsx';
DataToWrite = cell(length(AllLandUnique)+1, 3); % Plus 1 because of header line
DataToWrite(1,:) = {LandUsesFieldName, 'Abbreviation (for Map)', 'RGB (for Map)'};
DataToWrite(2:end, 1:2) = repmat(cellstr(AllLandUnique'), 1, 2);

WriteFile = checkduplicate(Fig, DataToWrite, fold_user, FileNameLandUsesAssociation);
if WriteFile; writecell(DataToWrite, FileNameLandUsesAssociation, 'Sheet','Association'); end

VariablesUserLandUses = {'FileNameLandUses', 'LandUsesFieldName'};
Variables = [Variables, {'FileNameLandUsesAssociation'}];

toc
ProgressBar.Message = 'Finising...';

%% Saving..
cd(fold_var)
save('LandUsesVariables.mat', Variables{:});
save('UserStudyArea_Answers.mat', VariablesUserLandUses{:}, '-append');

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version