if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Options
Options = {'Top Soil', 'Sub Soil'};
TypeOfSoil = uiconfirm(Fig, 'What type of information contains your file?', ...
                            'Soil info type', 'Options',Options);
if strcmp(TypeOfSoil,'Top Soil'); TopSoil = true; else; TopSoil = false; end

%% File loading
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon');

%% Core
lithoShapePath = strcat(fold_raw_lit,sl,FileName_Lithology);
[LithoPolygonsStudyArea, LithoAllUnique] = ...
                polyshapes_from_shapefile(lithoShapePath, LitFieldName, ...
                                          polyBound=StudyAreaPolygon, pointsLim=500000, ...
                                          progDialog=ProgressBar);

%% Plot for check
ProgressBar.Message = 'Plotting for check';

CheckFig = figure(1);
CheckAxs = axes(CheckFig);
hold(CheckAxs,'on')

plot(LithoPolygonsStudyArea', 'Parent',CheckAxs)

legend(LithoAllUnique, 'Location','SouthEast', 'AutoUpdate','off')

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1, 'Parent',CheckAxs)

title('Litho Polygon Check')
fig_settings(fold0, 'AxisTick');

%% Writing of an excel that User has to compile before Step2
ProgressBar.Message = 'Excel Creation (User Control folder)';

FileName_LithoAssociation = 'LuDSCAssociation.xlsx';
write_user_excel([fold_user,sl,FileName_LithoAssociation], LithoAllUnique, LitFieldName, Fig, 'litho')

%% Saving of polygons included in the study area
ProgressBar.Message = 'Saving...';

Variables = {'LithoPolygonsStudyArea', 'LithoAllUnique', 'FileName_LithoAssociation'};
VarsAnswr = {'AnswerAttributionSoilParameter', 'FileName_Lithology', 'LitFieldName'};

save([fold_var,sl,'LithoPolygonsStudyArea.mat'], Variables{:});
save([fold_var,sl,'UserSoil_Answers.mat'      ], VarsAnswr{:});
if TopSoil
    TopSoilPolygonsStudyArea = LithoPolygonsStudyArea;
    TopSoilAllUnique = LithoAllUnique;
    VariablesTopSoil = {'TopSoilPolygonsStudyArea', 'TopSoilAllUnique'};
    save([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], VariablesTopSoil{:});
end

close(ProgressBar) % ProgressBar instead of Fig if on the app version