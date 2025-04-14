if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Creation of land uses polygon
sl = filesep;

tic

load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon','MinExtremes','MaxExtremes');

ShapeInfoLandUses = shapeinfo([fold_raw_land_uses,sl,FileNameLandUses]);

if ShapeInfoLandUses.NumFeatures == 0
    error('Shapefile is empty')
end

if isempty(ShapeInfoLandUses.CoordinateReferenceSystem)
    EPSG = str2double(inputdlg2({['DTM EPSG (Sicily -> 32633, ' ...
                                  'Emilia Romagna -> 25832):']}, 'DefInp',{'25832'}));
    ShapeInfoLandUses.CoordinateReferenceSystem = projcrs(EPSG);
end

PointShapeType = strcmp( ShapeInfoLandUses.ShapeType, 'PointZ' );
if PointShapeType % REMEMBER TO CONTINUE THIS CHANGE IN OTHER SCRIPTS

    ReadShapeLandUses = readgeotable([fold_raw_land_uses,sl,FileNameLandUses]);
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

    VariablesLnUs = {'LandUsePointsStudyArea', 'AllLandUnique', 'PointShapeType'};

else

    lndUseShapePath = strcat(fold_raw_land_uses,sl,FileNameLandUses);
    [LandUsePolygonsStudyArea, AllLandUnique] = ...
                    polyshapes_from_shapefile(lndUseShapePath, LandUsesFieldName, ...
                                              polyBound=StudyAreaPolygon, pointsLim=200000, ...
                                              progDialog=ProgressBar);
    
    LandToRemovePolygon = [];
    
    VariablesLnUs = {'LandUsePolygonsStudyArea', 'AllLandUnique', 'LandToRemovePolygon', 'PointShapeType'};

end

%% Writing of an excel that User could compile
ProgressBar.Message = 'Excel Creation (User Control folder)';

FileNameLandUsesAssociation = 'LandUsesAssociation.xlsx';
write_user_excel([fold_user,sl,FileNameLandUsesAssociation], AllLandUnique, LandUsesFieldName, Fig, 'land use')

toc

%% Saving...
ProgressBar.Message = 'Saving...';

VarsUserLndUs = {'FileNameLandUses', 'LandUsesFieldName'};
VariablesLnUs = [VariablesLnUs, {'FileNameLandUsesAssociation'}];

save([fold_var,sl,'LandUsesVariables.mat'    ], VariablesLnUs{:});
save([fold_var,sl,'UserStudyArea_Answers.mat'], VarsUserLndUs{:}, '-append');

% close(ProgressBar) % Fig instead of ProgressBar if in Standalone version