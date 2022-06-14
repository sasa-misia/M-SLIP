clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% File loading
cd(fold_var)
load('LandUsesVariables');
load('UserA_Answers', 'LandUsesFieldName');

if exist('IndexLandUsesToRemove')
    AllIndex = 1:length(AllLandUnique);
    AllIndex(IndexLandUsesToRemove) = [];
    LandUsePolygonsStudyArea = LandUsePolygonsStudyArea(AllIndex);
    AllLandUnique = AllLandUnique(AllIndex);
end

VegPolygonsStudyArea = LandUsePolygonsStudyArea;
VegetationAllUnique = AllLandUnique;
VegFieldName = LandUsesFieldName;

%% Writing of an excel that User has to compile before Step2
cd(fold_user)
ColHeader1 = {'UV', 'c_R''(kPa)', '\beta (-)', 'Color'};
ColHeader2 = {LandUsesFieldName, 'UV associated', 'VU Abbrev (For Map)', 'RGB VU (for Map)'};

writecell(ColHeader1, 'VuDVCAssociation.xlsx', 'Sheet','DVCParameters', 'Range','A1');
writecell(ColHeader2, 'VuDVCAssociation.xlsx', 'Sheet','Association', 'Range','A1');
writecell(AllLandUnique', 'VuDVCAssociation.xlsx', 'Sheet','Association', 'Range','A2');

FileName_VegAssociation = 'VuDVCAssociation.xlsx';
if isfile(FileName_VegAssociation)
    warning(strcat(FileName_VegAssociation,' already exist'))
end
ColHeader1 = {VegFieldName, 'UV associated', 'VU Abbrev (For Map)', 'RGB LU (for Map)'};
ColHeader2 = {'UV', 'c_R''(kPa)', '\beta (-)', 'Color'};
writecell(ColHeader1, FileName_VegAssociation, 'Sheet','Association', 'Range','A1');
writecell(VegetationAllUnique', FileName_VegAssociation, 'Sheet','Association', 'Range','A2');
writecell(ColHeader2, FileName_VegAssociation, 'Sheet','DVCParameters', 'Range','A1');

VariablesVeg = {'VegPolygonsStudyArea', 'VegetationAllUnique', 'FileName_VegAssociation'};
VariablesAnswer = {'FileName_Vegetation', 'VegFieldName'}; % Remember to save AnswerAttributionVegetationParemeter from UserD

%% Saving of polygons included in the study area
cd(fold_var)
save('VegPolygonsStudyArea.mat', VariablesVeg{:});
save('UserD_Answers.mat', VariablesAnswer{:}, '-append');
cd(fold0)