if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files
sl = filesep;

load([fold_var,sl,'SoilParameters.mat'], 'CohesionAll', 'PhiAll', 'KtAll', 'AAll', 'nAll');

%% Setting parameters and assigning
ProgressBar.Message = 'Writing parameters in matrices...';

ChsUnique = unique(CohesionAll{1});
PhiUnique = unique(PhiAll{1});
KtUnique  = unique(KtAll{1});
AUnique   = unique(AAll{1});
nUnique   = unique(nAll{1});

if isscalar(KtUnique) && not(isnan(KtUnique(1)))
    SuggVals = {num2str(ChsUnique(1)), num2str(PhiUnique(1)), ...
                num2str(KtUnique(1)), num2str(AUnique(1)), num2str(nUnique(1))};
else
    SuggVals = {'0', '35', '3.6*10^(-7)*3600', '50', '0.48'};
end

InpVals = inputdlg2({'Cohesion (c) [kPa]:', 'Friction angle (φ) [°]:', ...
                     'kt [h^-1]:', 'A [kPa]:', 'n [-]:'}, 'DefInp',SuggVals);

cUniform   = str2double(InpVals{1});
PhiUniform = str2double(InpVals{2});
ktUniform  = str2double(InpVals{3});
AUniform   = str2double(InpVals{4});
nUniform   = str2double(InpVals{5});

Rows = cellfun(@(x) size(x, 1), CohesionAll, 'UniformOutput',false);
Cols = cellfun(@(x) size(x, 2), CohesionAll, 'UniformOutput',false);

CohesionAll = cellfun(@(x,y) ones(x, y).*cUniform  , Rows, Cols, 'UniformOutput',false);
PhiAll      = cellfun(@(x,y) ones(x, y).*PhiUniform, Rows, Cols, 'UniformOutput',false);
KtAll       = cellfun(@(x,y) ones(x, y).*ktUniform , Rows, Cols, 'UniformOutput',false);
AAll        = cellfun(@(x,y) ones(x, y).*AUniform  , Rows, Cols, 'UniformOutput',false);
nAll        = cellfun(@(x,y) ones(x, y).*nUniform  , Rows, Cols, 'UniformOutput',false);

%% Saving...
ProgressBar.Message = 'Finising...';

% Creatings string names of variables in a cell array to save at the end
VarsSoilPrm = {'CohesionAll', 'PhiAll', 'KtAll', 'AAll', 'nAll'};
VarsAnsSoil = {'AnswerAttributionSoilParameter'};

save([fold_var,sl,'SoilParameters.mat'  ], VarsSoilPrm{:}, '-append');
save([fold_var,sl,'UserSoil_Answers.mat'], VarsAnsSoil{:});