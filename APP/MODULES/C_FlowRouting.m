if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data and initialization of AnalysisInformation
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'  ], 'StudyAreaPolygon')
load([fold_var,sl,'GridCoordinates.mat'     ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll','SlopeAll')

ProjCRS = load_prjcrs(fold_var);

%% Defining contributing area (upslope area) and TWI
ProgressBar.Message = 'Defining contributing area...';

[xPlanAll, yPlanAll, dx, dy, CellsArea] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    [xPlanAll{i1}, yPlanAll{i1}] = projfwd(ProjCRS, yLatAll{i1}, xLongAll{i1});

    dx{i1} = abs(xPlanAll{i1}(ceil(end/2),2)-xPlanAll{i1}(ceil(end/2),1));
    dy{i1} = abs(yPlanAll{i1}(1,ceil(end/2))-yPlanAll{i1}(2,ceil(end/2)));
    CellsArea{i1} = dx{i1}*dy{i1};
end

Options = {'MergedDTM', 'SeparateDTMs'};
FlowMtd = uiconfirm(Fig, 'How do you want to define flow routing?', ...
                         'Flow Routing', 'Options',Options);
switch FlowMtd
    case 'MergedDTM'
        dxMean   = mean([dx{:}]);
        dyMean   = mean([dy{:}]);
        CellsAreaMean = mean([CellsArea{:}]);

        [xPlanMerged, yPlanMerged] = fast_merge_dems(xPlanAll, yPlanAll, newRes=[dxMean, dyMean]);

        xPlanAllCat = cellfun(@(x) x(:), xPlanAll, 'UniformOutput',false);
        xPlanAllCat = cat(1, xPlanAllCat{:});
        yPlanAllCat = cellfun(@(x) x(:), yPlanAll, 'UniformOutput',false);
        yPlanAllCat = cat(1, yPlanAllCat{:});
        ElevAllCat  = cellfun(@(x) x(:), ElevationAll, 'UniformOutput',false);
        ElevAllCat  = cat(1, ElevAllCat{:});

        ElevInterpModel = scatteredInterpolant(xPlanAllCat, yPlanAllCat, double(ElevAllCat), 'nearest');

        ElevationMerged    = zeros(size(xPlanMerged));
        ElevationMerged(:) = ElevInterpModel(xPlanMerged(:), yPlanMerged(:));

        ElevationMergedFilled = imfill(ElevationMerged, 8, 'holes');

        [FlowDirMerged, FlowMagnitMerged] = dem_flow(ElevationMergedFilled, dxMean, dyMean, 0);

        ContributingAreaMerged = upslope_area( ElevationMergedFilled, flow_matrix(ElevationMergedFilled,FlowDirMerged,dxMean,dyMean) )*CellsAreaMean;

        ContrAreaInterpModel = scatteredInterpolant(xPlanMerged(:), yPlanMerged(:), double(ContributingAreaMerged(:)), 'nearest');

        [ContributingAreaAll, ContributingAreaLogAll, TwiAll] = deal(cell(size(xLongAll)));
        for i1 = 1:length(xLongAll)
            ContributingAreaAll{i1}    = zeros(size(xLongAll{i1}));
            ContributingAreaAll{i1}(:) = ContrAreaInterpModel(xPlanAll{i1}(:), yPlanAll{i1}(:));
            ContributingAreaLogAll{i1} = log(ContributingAreaAll{i1}); % It is not necessary but for plot is more representative than ContributingArea
            TwiAll{i1}                 = log(ContributingAreaAll{i1}./(tand(SlopeAll{i1})+1e-9)); % 1e-9 to avoid having num/0
        end

    case 'SeparateDTMs'
        ElevationAllFilled = cellfun(@(x) imfill(x, 8, 'holes'), ElevationAll, 'UniformOutput',false); % Necessary to avoid stopping flow in unwanted points. If 2nd term is 8 it means that it look in the other 8 neighbors

        [FlowDirAll, FlowMagnitAll, ContributingAreaAll, ...
            ContributingAreaLogAll, TwiAll] = deal(cell(size(xLongAll)));
        for i1 = 1:length(xLongAll)
            [FlowDirAll{i1}, FlowMagnitAll{i1}] = dem_flow(ElevationAllFilled{i1}, dx{i1}, dy{i1}, 0);
            ContributingAreaAll{i1}    = upslope_area( ElevationAllFilled{i1}, flow_matrix(ElevationAllFilled{i1},FlowDirAll{i1},dx{i1},dy{i1}) )*CellsArea{i1};
            ContributingAreaLogAll{i1} = log(ContributingAreaAll{i1}); % It is not necessary but for plot is more representative than ContributingArea
            TwiAll{i1}                 = log(ContributingAreaAll{i1}./(tand(SlopeAll{i1})+1e-9)); % 1e-9 to avoid having num/0
        end
end

%% Plot for check
ProgressBar.Message = 'Plotting to check...';

CheckFig = figure(1);
CheckAxs = axes(CheckFig);
hold(CheckAxs,'on')

for i1 = 1:length(xLongAll)
    fastscatter(xLongAll{i1}(IndexDTMPointsInsideStudyArea{i1}), ...
                yLatAll{i1}(IndexDTMPointsInsideStudyArea{i1}), ...
                ContributingAreaLogAll{i1}(IndexDTMPointsInsideStudyArea{i1}))
end
colormap(CheckAxs, colormap('sky'))

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5);

title('Logaritmic contributing area check')

fig_settings(fold0, 'AxisTick');

%% Saving...
ProgressBar.Message = 'Saving...';

VarsFlowRouting = {'ContributingAreaAll', 'TwiAll'};
save([fold_var,sl,'FlowRouting.mat'], VarsFlowRouting{:});