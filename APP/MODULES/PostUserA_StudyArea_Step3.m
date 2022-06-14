cd(fold_var)
load('LandUsesVariables');
load('StudyAreaVariables');
Variables={'MunPolygon','StudyAreaPolygon','MaxExtremes','MinExtremes'};

if any(LandUseToRemoveSel~="None of these")
    IndexLandUsesToRemove = zeros(1,length(LandUseToRemoveSel));
    for i6=1:length(LandUseToRemoveSel)
        IndexLandUsesToRemove(i6)=find(strcmp(AllLandUnique,LandUseToRemoveSel{i6}));
    end
    LandToRemovePolygon=union([LandUsePolygonsStudyArea(IndexLandUsesToRemove)]);
    StudyAreaPolygonClean=subtract(StudyAreaPolygon,LandToRemovePolygon);

    Variables=[Variables {'StudyAreaPolygonClean'}];
else
    error("You haven't selected any land use so reload UserA_StudyArea and select no when prompted")
end

VariablesLandUse={'AllLandUnique','LandUsePolygonsStudyArea','LandToRemovePolygon','IndexLandUsesToRemove'};

%% Saving..
cd(fold_var)

save('StudyAreaVariables.mat',Variables{:});
save('LandUsesVariables.mat',VariablesLandUse{:},'-append')
cd(fold0)