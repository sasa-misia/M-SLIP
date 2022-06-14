clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Removal of unwanted land uses
cd(fold_var)
load('LandUsesVariables');
load('StudyAreaVariables');

Choice = listdlg('PromptString',{'Choose land uses to remove:',''}, 'ListString',AllLandUnique);
LandUseToRemoveSel = AllLandUnique(Choice);

tic
if any(LandUseToRemoveSel ~= "None of these")
    IndexLandUsesToRemove = zeros(1,length(LandUseToRemoveSel));
    for i1 = 1:length(LandUseToRemoveSel)
        IndexLandUsesToRemove(i1) = find(strcmp(AllLandUnique,LandUseToRemoveSel{i1}));
    end
    LandToRemovePolygon = union(LandUsePolygonsStudyArea(IndexLandUsesToRemove)); % Maybe with [] to concatenate
    StudyAreaPolygonClean = subtract(StudyAreaPolygon,LandToRemovePolygon);

    % Saving..
    save('StudyAreaVariables.mat','StudyAreaPolygonClean','-append');
    cd(fold0)
else
    warning("You haven't selected any land use so don't run this script (it isn't necessary)")
    cd(fold0)
end
toc