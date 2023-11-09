if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Removal of excluded areas', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Removal of excluded areas
cd(fold_var)
load('LandUsesVariables');
load('StudyAreaVariables');

VariablesStudyArea = {'StudyAreaPolygonClean', 'StudyAreaPolygonExcluded'};

ProgressBar.Indeterminate = 'off';
if any(LandUseToRemoveSel ~= "None of these")
    IndexLandUsesToRemove = zeros(1,length(LandUseToRemoveSel));
    for i1 = 1:length(LandUseToRemoveSel)
        ProgressBar.Message = strcat("Removal of polygon n. ",num2str(i1)," of ", num2str(length(LandUseToRemoveSel)));
        ProgressBar.Value = i1/length(LandUseToRemoveSel);

        IndexLandUsesToRemove(i1) = find(strcmp(AllLandUnique,LandUseToRemoveSel{i1}));
    end
    LandToRemovePolygon = union([LandUsePolygonsStudyArea(IndexLandUsesToRemove)]);
    StudyAreaPolygonClean = subtract(StudyAreaPolygon, LandToRemovePolygon);
    StudyAreaPolygonExcluded = LandToRemovePolygon;
else
    error("You haven't selected any land use so reload " + ...
          "UserA_StudyArea and select no when prompted")
end

VariablesLandUse = {'AllLandUnique', 'LandUsePolygonsStudyArea', 
                    'LandToRemovePolygon', 'IndexLandUsesToRemove'};

ProgressBar.Indeterminate = 'on';
ProgressBar.Message = 'Finising...';

%% Saving..
cd(fold_var)
save('StudyAreaVariables.mat', VariablesStudyArea{:}, '-append');
save('LandUsesVariables.mat', VariablesLandUse{:}, '-append')
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version