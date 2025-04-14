if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'LandUsesVariables'    ], 'AllLandUnique','LandUsePolygonsStudyArea','IndexLandUsesToRemove');
load([fold_var,sl,'UserStudyArea_Answers'], 'LandUsesFieldName');

if exist('IndexLandUsesToRemove', 'var')
    AllIndex = 1:length(AllLandUnique);
    AllIndex(IndexLandUsesToRemove) = [];
    LandUsePolygonsStudyArea = LandUsePolygonsStudyArea(AllIndex);
    AllLandUnique = AllLandUnique(AllIndex);
end

VegPolygonsStudyArea = LandUsePolygonsStudyArea;
VegetationAllUnique  = AllLandUnique;
VegFieldName         = LandUsesFieldName;

%% Writing of an excel that User has to compile before Step2
ProgressBar.Message = 'Excel Creation (User Control folder)';

FileName_VegAssociation = 'VuDVCAssociation.xlsx';
write_user_excel([fold_user,sl,FileName_VegAssociation], VegetationAllUnique, VegFieldName, Fig, 'veg')

%% Saving of polygons included in the study area
ProgressBar.Message = 'Saving...';

VariablesVeg = {'VegPolygonsStudyArea', 'VegetationAllUnique', 'FileName_VegAssociation'};
VarsAnswerD  = {'AnswerAttributionVegetationParameter', 'FileName_Vegetation', 'VegFieldName'};

save([fold_var,sl,'VegPolygonsStudyArea.mat'], VariablesVeg{:});
save([fold_var,sl,'UserVeg_Answers.mat'     ], VarsAnswerD{:}, '-append');