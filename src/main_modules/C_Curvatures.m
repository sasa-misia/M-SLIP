if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Reading files...', 'Indeterminate','on');
drawnow

%% Loading data and initialization of AnalysisInformation
load([fold_var,sl,'GridCoordinates.mat'     ], 'xLongAll','yLatAll')
load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll')

ProjCRS = load_prjcrs(fold_var);

%% Defining different types of curvature
ProgressBar.Message = "Defining curvature...";

[xPlanAll, yPlanAll, GaussCurvatureAll, ...
    MeanCurvatureAll, P1CurvatureAll, P2CurvatureAll] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    [xPlanAll{i1}, yPlanAll{i1}] = projfwd(ProjCRS, yLatAll{i1}, xLongAll{i1});
    [GaussCurvatureAll{i1}, MeanCurvatureAll{i1}, P1CurvatureAll{i1}, P2CurvatureAll{i1}] = dem_surfature(xPlanAll{i1}, yPlanAll{i1}, ElevationAll{i1});
end

[ProfileCurvatureAll, PlanformCurvatureAll] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    dx = round(abs(xPlanAll{i1}(ceil(end/2), 2) - xPlanAll{i1}(ceil(end/2), 1)), 2);
    dy = round(abs(yPlanAll{i1}(1, ceil(end/2)) - yPlanAll{i1}(2, ceil(end/2))), 2);

    if abs(int64(dx) - int64(dy)) > 1
        error("You have a DEM of different sizes for cells in X and Y, provide another one")
    end

    [ProfileCurvatureAll{i1}, PlanformCurvatureAll{i1}] = dem_curvature(ElevationAll{i1}, dx);
end

%% Saving...
ProgressBar.Message = 'Saving...';

VariablesMorphology = {'MeanCurvatureAll', 'ProfileCurvatureAll', 'PlanformCurvatureAll'}; % Remember that you have calculate even others
save([fold_var,sl,'MorphologyParameters.mat'], VariablesMorphology{:}, '-append');

close(ProgressBar)