if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'  ], 'StudyAreaPolygonClean')
load([fold_var,sl,'VegetationParameters.mat'], 'RootCohesionAll')
load([fold_var,sl,'MorphologyParameters.mat'], 'SlopeAll')

%% Assign uniform values
ProgressBar.Message = 'Writing parameters in matrices...';

InpVals = inputdlg2({'Root cohesion {\it c_r} [kPa]:', ...
                     'Infiltration {\beta^*} (NaN if you want slope based) [-]'}, 'DefInp',{'0', 'NaN'});

cRootUniform = str2double(InpVals{1});
bStarUniform = str2double(InpVals{2});

if cRootUniform < 0
    error('Root cohesion must be > 0!')
end
if not(isnan(bStarUniform)) && ((bStarUniform > 1) || (bStarUniform < 0))
    error('Beta star must be in the range [0, 1]!')
end

Rows = cellfun(@(x) size(x, 1), RootCohesionAll, 'UniformOutput',false);
Cols = cellfun(@(x) size(x, 2), RootCohesionAll, 'UniformOutput',false);

RootCohesionAll = cellfun(@(x,y) ones(x, y).*cRootUniform, Rows, Cols, 'UniformOutput',false);

if isnan(bStarUniform)
    BetaStarAll = cellfun(@cosd, SlopeAll, 'UniformOutput',false);
else
    BetaStarAll = cellfun(@(x,y) ones(x, y).*bStarUniform, Rows, Cols, 'UniformOutput',false);
end

%% Association tables
VegAssociation = table("Uniform", 1, "Uniform", StudyAreaPolygonClean, ...
                            {floor(rand(1, 3) .* 255)}, 'VariableNames',{ ...
                                                                'Class', 'UC', 'Acronym', 'Polygon', 'Color'});

VegParameters = table(1, cRootUniform, bStarUniform, StudyAreaPolygonClean, ...
                            {floor(rand(1, 3) .* 255)}, 'VariableNames',{ ...
                                                                'UC', 'cr', 'beta', 'Polygon', 'Color'});

%% Saving...
ProgressBar.Message = 'Saving...';

VarsVUPrms = {'VegAssociation', 'VegParameters'};
VarsVegPrs = {'RootCohesionAll', 'BetaStarAll'};
VarsAnsVeg = {'AnswerAttributionVegetationParameter'};

save([fold_var,sl,'VUDVCMapParameters.mat'  ], VarsVUPrms{:})
save([fold_var,sl,'VegetationParameters.mat'], VarsVegPrs{:}, '-append');
if exist([fold_var,sl,'UserVeg_Answers.mat'], 'file')
    save([fold_var,sl,'UserVeg_Answers.mat'], VarsAnsVeg{:}, '-append');
else
    save([fold_var,sl,'UserVeg_Answers.mat'], VarsAnsVeg{:});
end