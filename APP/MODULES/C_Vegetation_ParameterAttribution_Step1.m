if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon');

%% Core
vegShapePath = strcat(fold_raw_veg,sl,FileName_Vegetation);
[VegPolygonsStudyArea, VegetationAllUnique] = ...
                polyshapes_from_shapefile(vegShapePath, VegFieldName, ...
                                          polyBound=StudyAreaPolygon, pointsLim=500000, ...
                                          progDialog=ProgressBar);

%% Plot to check the vegetation in the Study Area
ProgressBar.Message = 'Plotting for check';

fig_check = figure(1);
ax_check  = axes(fig_check);
hold(ax_check,'on')

plot(VegPolygonsStudyArea, 'Parent',ax_check)

legend(VegetationAllUnique,'Location','SouthEast','AutoUpdate','off')

plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1, 'Parent',ax_check)

title('Vegetation Polygon Check')
fig_settings(fold0, 'AxisTick');

%% Writing of an excel that User has to compile before Step2
ProgressBar.Message = 'Excel Creation (User Control folder)';

FileName_VegAssociation = 'VuDVCAssociation.xlsx';
write_user_excel([fold_user,sl,FileName_VegAssociation], VegetationAllUnique, VegFieldName, Fig, 'veg')

%% Saving of polygons included in the study area
ProgressBar.Message = 'Saving...';

VariablesVeg = {'VegPolygonsStudyArea', 'VegetationAllUnique', 'FileName_VegAssociation'};
VarsAnswrVeg = {'AnswerAttributionVegetationParameter', 'FileName_Vegetation', 'VegFieldName'};

save([fold_var,sl,'VegPolygonsStudyArea.mat'], VariablesVeg{:});
save([fold_var,sl,'UserVeg_Answers.mat'     ], VarsAnswrVeg{:}, '-append');

close(ProgressBar) % ProgressBar instead of Fig if on the app version