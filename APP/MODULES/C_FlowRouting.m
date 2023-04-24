% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Reading files...', 'Indeterminate','on');
drawnow

%% Loading data and initialization of AnalysisInformation
cd(fold_var)
load('StudyAreaVariables.mat',   'StudyAreaPolygon')
load('GridCoordinates.mat',      'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load('MorphologyParameters.mat', 'ElevationAll','SlopeAll','OriginallyProjected','SameCRSForAll')
cd(fold0)

%% Defining contributing area (upslope area) and TWI (REMEMBER THAT IT WOULD BE BETTER TO CALCULATE IN THE MERGED ONE! SEE POSTUSERC DISTANCES FOR EXAMPLES)
ProgressBar.Message = "Defining contributing area...";

ElevationAllFilled = cellfun(@(x) imfill(x, 8, 'holes'), ElevationAll, 'UniformOutput',false); % Necessary to avoid stopping flow in unwanted points. If 2nd term is 8 it means that it look in the other 8 neighbors

if OriginallyProjected && SameCRSForAll
    cd(fold_var)
    load('MorphologyParameters.mat', 'OriginalProjCRS')
    cd(fold0)

    ProjCRS = OriginalProjCRS;
else
    EPSG = str2double(inputdlg({["Set DTM EPSG (to calculate flow)"
                                 "For Example:"
                                 "Sicily -> 32633"
                                 "Emilia Romagna -> 25832"]}, '', 1, {'25832'}));
    ProjCRS = projcrs(EPSG);
end

[xPlanAll, yPlanAll, FlowDirAll, FlowMagnitAll, ...
    ContributingAreaAll, ContributingAreaLogAll, TwiAll] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    [xPlanAll{i1}, yPlanAll{i1}] = projfwd(ProjCRS, yLatAll{i1}, xLongAll{i1});

    dx = abs(xPlanAll{i1}(ceil(end/2),2)-xPlanAll{i1}(ceil(end/2),1));
    dy = abs(yPlanAll{i1}(1,ceil(end/2))-yPlanAll{i1}(2,ceil(end/2)));
    CellsArea = dx*dy;

    [FlowDirAll{i1}, FlowMagnitAll{i1}] = dem_flow(ElevationAllFilled{i1}, dx, dy, 0);
    ContributingAreaAll{i1}    = upslope_area( ElevationAllFilled{i1}, flow_matrix(ElevationAllFilled{i1},FlowDirAll{i1},dx,dy) )*CellsArea;
    ContributingAreaLogAll{i1} = log(ContributingAreaAll{i1}); % It is not necessary but for plot is more representative than ContributingArea
    TwiAll{i1}                 = log(ContributingAreaAll{i1}./(tand(SlopeAll{i1})+1e-9)); % 1e-9 to avoid having num/0
end

%% Plot for check
ProgressBar.Message = 'Plotting to check...';

fig_check = figure(1);
ax_check  = axes(fig_check);
hold(ax_check,'on')

for i1 = 1:length(xLongAll)
    fastscatter(xLongAll{i1}(IndexDTMPointsInsideStudyArea{i1}), ...
                yLatAll{i1}(IndexDTMPointsInsideStudyArea{i1}), ...
                ContributingAreaLogAll{i1}(IndexDTMPointsInsideStudyArea{i1}))
end
colormap(ax_check, colormap('sky'))

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5);

title('Logaritmic contributing area check')

fig_settings(fold0, 'AxisTick');

%% Saving...
ProgressBar.Message = 'Saving...';
cd(fold_var)
VariablesFlowRouting = {'ContributingAreaAll', 'TwiAll'};
save('FlowRouting.mat', VariablesFlowRouting{:});
cd(fold0)

close(ProgressBar)