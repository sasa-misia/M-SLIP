% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Soil parameter attribution',...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Setting parameters and assigning
tic
cd(fold_var)
load('SoilParameters.mat');

KtUnique = unique(KtAll{1});
CohesionUnique = unique(CohesionAll{1});
PhiUnique = unique(PhiAll{1});
AUnique = unique(AAll{1});
nUnique = unique(nAll{1});

CheckLength = length(KtUnique)==1;

if CheckLength && ~isnan(KtUnique(1))
    SuggestedValues = {num2str(CohesionUnique(1)),num2str(PhiUnique(1)), ...
                       num2str(KtUnique(1)),num2str(AUnique(1)), ...
                       num2str(nUnique(1))};
else
    SuggestedValues = {'0', '36.3', '3.6*10^(-7)*3600', '50', '0.48'};
end

InputValues = inputdlg({'Cohesion value c (kPa):'
                        'Friction angle φ (°):'
                        'kt (h^-1):'
                        'A (kPa):'
                        'n (-):'}, 'Set',1, ...
                         SuggestedValues);

cUniform = eval(InputValues{1});
PhiUniform = eval(InputValues{2});
ktUniform = eval(InputValues{3});
AUniform = eval(InputValues{4});
nUniform = eval(InputValues{5});

ProgressBar.Message = 'Writing parameters in matrices...';
for i1 = 1:length(CohesionAll)
    RowNumber = size(CohesionAll{i1},1);
    ColumnNumber = size(CohesionAll{i1},2);
    CohesionAll{i1} = ones(RowNumber,ColumnNumber).*cUniform;
    PhiAll{i1} = ones(RowNumber,ColumnNumber).*PhiUniform;
    KtAll{i1} = ones(RowNumber,ColumnNumber).*ktUniform;
    AAll{i1} = ones(RowNumber,ColumnNumber).*AUniform;
    nAll{i1} = ones(RowNumber,ColumnNumber).*nUniform;
end

% Creatings string names of variables in a cell array to save at the end
Variables = {'CohesionAll', 'PhiAll', 'KtAll', 'AAll', 'nAll'};
VariablesAnswer = {'AnswerAttributionSoilParameter'};
toc

ProgressBar.Message = 'Finising...';

%% Saving...
save('SoilParameters.mat', Variables{:});
save('UserSoil_Answers.mat', VariablesAnswer{:});
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version