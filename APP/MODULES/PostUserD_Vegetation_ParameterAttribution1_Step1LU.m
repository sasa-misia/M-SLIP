%% File loading
cd(fold_var)
load('LandUsesVariables');
load('UserA_Answers', 'LandUsesFieldName');

if exist('IndexLandUsesToRemove', 'var')
    AllIndex=1:length(AllLandUnique);
    AllIndex(IndexLandUsesToRemove)=[];
    LandUsePolygonsStudyArea=LandUsePolygonsStudyArea(AllIndex);
    AllLandUnique=AllLandUnique(AllIndex);
end

VegPolygonsStudyArea = LandUsePolygonsStudyArea;
VegetationAllUnique = AllLandUnique;
VegFieldName = LandUsesFieldName;

%% Writing of an excel that User has to compile before Step2
FileName_VegAssociation = 'VuDVCAssociation.xlsx';
DataToWrite1 = cell(length(VegetationAllUnique)+1, 4); % Plus 1 because of header line
DataToWrite1(1, :) = {LandUsesFieldName, 'UV Associated', 'VU Abbrev (For Map)', 'RGB VU (for Map)'};
DataToWrite1(2:end, 1) = cellstr(VegetationAllUnique');

DataToWrite2 = {'UV','c_R''(kPa)','\beta (-)','Color'};

WriteFile = checkduplicate(Fig, DataToWrite1, fold_user, FileName_VegAssociation);
if WriteFile
    writecell(DataToWrite1, FileName_VegAssociation, 'Sheet','Association');
    writecell(DataToWrite2, FileName_VegAssociation, 'Sheet','DVCParameters');
end

VariablesVeg = {'VegPolygonsStudyArea', 'VegetationAllUnique', 'FileName_VegAssociation'};
VariablesAnswerD = {'AnswerAttributionVegetationParameter', 'FileName_Vegetation', 'VegFieldName'};

%% Saving of polygons included in the study area
cd(fold_var)
save('VegPolygonsStudyArea.mat', VariablesVeg{:});
save('UserD_Answers.mat', VariablesAnswerD{:}, '-append');
cd(fold0)