%% Creation of land uses polygon
tic
cd(fold_var)
load('StudyAreaVariables.mat');
cd(fold_raw_land_uses)

% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Processing shapefile of land uses',...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

ShapeInfoLandUses = shapeinfo(FileNameLandUses);

ShapeTypePoint = strcmp( ShapeInfoLandUses.ShapeType, 'PointZ' );

if ShapeTypePoint % REMEMBER TO CONTINUE THIS CHANGE IN OTHER SCRIPTS

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

    Steps = length(IndexLandUses);
    LandUsePointsStudyArea = repmat(geopointshape, 1, length(IndexLandUses));
    ProgressBar.Indeterminate = 'off';
    for i1 = 1:length(IndexLandUses)
    
        ProgressBar.Message = strcat("Creation of Multipoints n. ",num2str(i1)," of ", num2str(length(IndexLandUses)));
        ProgressBar.Value = i1/Steps;

        LandUsePointsStudyArea(i1) = geopointshape({[AllPointInStudyLat(IndexLandUses{i1})]'}, ...
                                                   {[AllPointInStudyLong(IndexLandUses{i1})]'});
    end

    Variables = {'LandUsePointsStudyArea', 'AllLandUnique', 'ShapeTypePoint'};

else

    [BoundingBoxX, BoundingBoxY] = projfwd(ShapeInfoLandUses.CoordinateReferenceSystem,...
                        [MinExtremes(2) MaxExtremes(2)],[MinExtremes(1) MaxExtremes(1)]);
    ReadShapeLandUses = shaperead(FileNameLandUses, ...
                                  'BoundingBox',[BoundingBoxX(1), BoundingBoxY(1)
                                                 BoundingBoxX(2), BoundingBoxY(2)]);
    
    IndexToRemove = false(1, size(ReadShapeLandUses,1)); % Initialize logic array
    for i1 = 1:size(ReadShapeLandUses,1)
        IndexToRemove(i1) = numel(ReadShapeLandUses(i1).X)>30000;
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
        IndexLandUses{i1} = find(strcmp(AllLandUnique(i1),AllLandRaw));
    end
    
    % Union of polygon on the same class
    Steps = length(IndexLandUses);
    LandUsePolygons = repmat(polyshape, 1, length(IndexLandUses)); % Initialize polyshape array
    ProgressBar.Indeterminate = 'off';
    for i1 = 1:length(IndexLandUses)
    
        ProgressBar.Message = strcat("Creation of polygon n. ",num2str(i1)," of ", num2str(length(IndexLandUses)));
        ProgressBar.Value = i1/Steps;
    
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
    
    LandToRemovePolygon = [];
    
    Variables = {'LandUsePolygonsStudyArea', 'AllLandUnique', 'LandToRemovePolygon', 'ShapeTypePoint'};

end

%% Writing of an excel that User could compile
cd(fold_user)
FileNameLandUsesAssociation = 'LandUsesAssociation.xlsx';
if isfile(FileNameLandUsesAssociation)
    warning(strcat(FileNameLandUsesAssociation," already exist"))
end
ColHeader = {LandUsesFieldName, 'Abbreviation (for Map)', 'RGB (for Map)'};
writecell(ColHeader,FileNameLandUsesAssociation, 'Sheet','Association', 'Range','A1');
writecell(AllLandUnique',FileNameLandUsesAssociation, 'Sheet','Association', 'Range','A2');
writecell(AllLandUnique',FileNameLandUsesAssociation, 'Sheet','Association', 'Range','B2');

VariablesUserLandUses = {'FileNameLandUses', 'LandUsesFieldName'};
Variables = [Variables, {'FileNameLandUsesAssociation'}];

toc
ProgressBar.Message = 'Finising...';
close(ProgressBar)

%% Saving..
cd(fold_var)
save('LandUsesVariables.mat', Variables{:});
save('UserA_Answers.mat', VariablesUserLandUses{:}, '-append');