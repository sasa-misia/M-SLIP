%% File loading
tic
cd(fold_var)
load('StudyAreaVariables.mat');
cd(fold_raw_veg);

ShapeInfo_Vegetation=shapeinfo(FileName_Vegetation);
[BoundingBoxX,BoundingBoxY]=projfwd(ShapeInfo_Vegetation.CoordinateReferenceSystem,...
                [MinExtremes(2) MaxExtremes(2)],[MinExtremes(1) MaxExtremes(1)]);
ReadShape_Vegetation=shaperead(FileName_Vegetation,'BoundingBox',...
            [BoundingBoxX(1) BoundingBoxY(1);BoundingBoxX(2) BoundingBoxY(2)]);

%% Extract vegetation name abbreviations
VegetationAll=extractfield(ReadShape_Vegetation,VegFieldName);
VegetationAllUnique=unique(VegetationAll);

IndexVeg=cell(1,length(VegetationAllUnique));
for i1=1:length(VegetationAllUnique)
    IndexVeg{i1}=find(strcmp(VegetationAll,VegetationAllUnique(i1)));
end

% Poligon creation
VegPolygon=repmat(polyshape, 1, length(IndexVeg));
for i2=1:length(IndexVeg)
    [VegVertexLat,VegVertexLon]=projinv(ShapeInfo_Vegetation.CoordinateReferenceSystem,...
                                        [ReadShape_Vegetation(IndexVeg{i2}).X],...
                                        [ReadShape_Vegetation(IndexVeg{i2}).Y]);
    VegPolygon(i2)=polyshape([VegVertexLon',VegVertexLat'],'Simplify',false);
end

% Find intersection among Veg polygons and the study area
VegPolygonsStudyArea=intersect(VegPolygon,StudyAreaPolygonClean); 

% Removal of Veg excluded from the study area
EmptyVegInStudyArea=cellfun(@isempty,{VegPolygonsStudyArea.Vertices});

VegPolygonsStudyArea(EmptyVegInStudyArea)=[];
VegetationAllUnique(EmptyVegInStudyArea)=[];

%% Plot to check the vegetation in the Study Area
f1 = figure(1);
plot(VegPolygonsStudyArea)
title('Vegetation Polygon Check')
xlim([MinExtremes(1) MaxExtremes(1)])
ylim([MinExtremes(2) MaxExtremes(2)])
daspect([1 1 1])
legend(VegetationAllUnique,'Location','SouthEast','AutoUpdate','off')
hold on
plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1)

%% Writing of an excel that User has to compile before Step2
cd(fold_user)
FileName_VegAssociation='VuDVCAssociation.xlsx';
if isfile(FileName_VegAssociation)
    Answer = questdlg('There is an existing association file. Do you want to overwrite it?', ...
                	  'Existing Association File', ...
                	  'Yes, thanks','No, for God!','No, for God!');
    if strcmp(Answer,'Yes, thanks'); delete(FileName_VegAssociation); end
end
ColHeader1={VegFieldName,'UV associated','VU Abbrev (For Map)','RGB LU (for Map)'};
ColHeader2={'UV','c_R''(kPa)','\beta (-)','Color'};
writecell(ColHeader1,FileName_VegAssociation,'Sheet','Association','Range','A1');
writecell(VegetationAllUnique',FileName_VegAssociation,'Sheet','Association','Range','A2');
writecell(ColHeader2,FileName_VegAssociation,'Sheet','DVCParameters','Range','A1');

VariablesVeg={'VegPolygonsStudyArea','VegetationAllUnique','FileName_VegAssociation'};
VariablesAnswer={'AnswerAttributionVegetationParameter';'FileName_Vegetation';'VegFieldName'};
toc

%% Saving of polygons included in the study area
cd(fold_var)
save('VegPolygonsStudyArea.mat',VariablesVeg{:});
save('UserD_Answers.mat',VariablesAnswer{:});
cd(fold0)