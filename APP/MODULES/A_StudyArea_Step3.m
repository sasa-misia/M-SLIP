if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading variables
sl = filesep;

load([fold_var,sl,'LandUsesVariables' ], 'AllLandUnique','LandUsePolygonsStudyArea');
load([fold_var,sl,'StudyAreaVariables'], 'StudyAreaPolygon');

%% Removing excluded areas
ProgressBar.Indeterminate = 'off';
IndexLandUsesToRemove = zeros(1,length(LndUse2RemSel));
for i1 = 1:length(LndUse2RemSel)
    ProgressBar.Message = ['Removing polygon n. ',num2str(i1),' of ',num2str(numel(LndUse2RemSel))];
    ProgressBar.Value = i1/numel(LndUse2RemSel);

    IndexLandUsesToRemove(i1) = find(strcmp(AllLandUnique, LndUse2RemSel{i1}));
end
ProgressBar.Indeterminate = 'on';

LandToRemovePolygon      = union([LandUsePolygonsStudyArea(IndexLandUsesToRemove)]);
StudyAreaPolygonClean    = subtract(StudyAreaPolygon, LandToRemovePolygon);
StudyAreaPolygonExcluded = LandToRemovePolygon;

%% Saving...
ProgressBar.Message = 'Finising...';

VarsStdyAr = {'StudyAreaPolygonClean', 'StudyAreaPolygonExcluded'};
VarsLndUse = {'AllLandUnique', 'LandUsePolygonsStudyArea', ...
                    'LandToRemovePolygon', 'IndexLandUsesToRemove'};

save([fold_var,sl,'StudyAreaVariables.mat'], VarsStdyAr{:}, '-append');
save([fold_var,sl,'LandUsesVariables.mat' ], VarsLndUse{:}, '-append')

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version