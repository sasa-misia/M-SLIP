%% Creation of land uses polygon
tic
cd(fold_var)
load('StudyAreaVariables.mat');
cd(fold_raw_land_uses)

% Fig=uifigure;
ProgressBar=uiprogressdlg(Fig,'Title','Processing shapefile of land uses',...
                'Message','Reading file','Cancelable','on','Indeterminate','on');
drawnow

ShapeInfo_LandUses=shapeinfo(FileName_LandUses);
[BoundingBoxX,BoundingBoxY]=projfwd(ShapeInfo_LandUses.CoordinateReferenceSystem,...
                    [MinExtremes(2) MaxExtremes(2)],[MinExtremes(1) MaxExtremes(1)]);
ReadShape_LandUses=shaperead(FileName_LandUses,'BoundingBox',...
            [BoundingBoxX(1) BoundingBoxY(1);BoundingBoxX(2) BoundingBoxY(2)]);

IndexToRemove=false(1, size(ReadShape_LandUses,1)); % Initialize logic array
for i1=1:size(ReadShape_LandUses,1)
    IndexToRemove(i1)=numel(ReadShape_LandUses(i1).X)>30000;
end
ReadShape_LandUses(IndexToRemove)=[];

AllLandRaw=extractfield(ReadShape_LandUses,LandUsesFieldName);
AllLandUnique=unique(AllLandRaw);
IndexLandUses=cell(1,length(AllLandUnique)); % Initialize cell array
for i1=1:length(AllLandUnique)
    IndexLandUses{i1}=find(strcmp(AllLandUnique(i1),AllLandRaw));
end

% Union of polygon on the same class
Steps=length(IndexLandUses);
LandUsePolygons=repmat(polyshape, 1, length(IndexLandUses)); % Initialize polyshape array
ProgressBar.Indeterminate='off';
for i2=1:length(IndexLandUses)

    ProgressBar.Message = strcat('Creation of polygon n. ',num2str(i2)," of ", num2str(length(IndexLandUses)));
    ProgressBar.Value = i2/Steps;

    [LandUseVertexLat,LandUseVertexLon]=projinv(ShapeInfo_LandUses.CoordinateReferenceSystem,...
                                            [ReadShape_LandUses(IndexLandUses{i2}).X],...
                                            [ReadShape_LandUses(IndexLandUses{i2}).Y]);
    LandUsePolygons(i2)=polyshape([LandUseVertexLon',LandUseVertexLat'],'Simplify',false);
    
    if ProgressBar.CancelRequested
        return
    end
end

% Intersection between Study Area and LandUsePolygons
LandUsePolygonsStudyArea=intersect(LandUsePolygons,StudyAreaPolygon);

% Removal of Land Uses excluded from the study area
EmptyLandUseInStudyArea=false(1, length(LandUsePolygonsStudyArea));
for i3=1:length(LandUsePolygonsStudyArea)
    EmptyLandUseInStudyArea(i3)=isempty(LandUsePolygonsStudyArea(i3).Vertices);
end
LandUsePolygonsStudyArea(EmptyLandUseInStudyArea)=[];
AllLandUnique(EmptyLandUseInStudyArea)=[];

LandToRemovePolygon=[];

VariablesUserLandUses={'FileName_LandUses';'LandUsesFieldName'};

%% Writing of an excel that User could compile
cd(fold_user)
FileName_LandUsesAssociation='LandUsesAssociation.xlsx';
if isfile(FileName_LandUsesAssociation)
    warning(strcat(FileName_LandUsesAssociation," already exist"))
end
ColHeader1={LandUsesFieldName,'Abbreviation (for Map)','RGB (for Map)'};
writecell(ColHeader1,FileName_LandUsesAssociation,'Sheet','Association','Range','A1');
writecell(AllLandUnique',FileName_LandUsesAssociation,'Sheet','Association','Range','A2');
writecell(AllLandUnique',FileName_LandUsesAssociation,'Sheet','Association','Range','B2');

toc
Variables={'LandUsePolygonsStudyArea','AllLandUnique','LandToRemovePolygon','FileName_LandUsesAssociation'};

ProgressBar.Message = 'Finising...';
close(ProgressBar)

%% Saving..
cd(fold_var)
save('LandUsesVariables.mat',Variables{:});
save('UserA_Answers.mat',VariablesUserLandUses{:},'-append');