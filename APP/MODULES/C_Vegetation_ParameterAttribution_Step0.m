% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Vegetation parameter attribution',...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Assign uniform values
cd(fold_var)
load('VegetationParameters.mat', 'RootCohesionAll')
load('MorphologyParameters.mat', 'SlopeAll')
cd(fold0)

InputValues = inputdlg({'Root cohesion value {\it c_r} (kPa):'
                        'Assign uniform {\beta^*} (already calculate through slope) (Yes/No)'
                       ['{\beta^*} value (not necessary if set No previously) (-). ' ...
                        'Value between 0 and 1:']}, '',  1, {'0','No','1'});

cRUniform       = eval(InputValues{1});
UniformBeta     = string(lower(InputValues{2}));
BetaStarUniform = eval(InputValues{3});

RowNumber    = cellfun(@(x) size(x,1), RootCohesionAll, 'UniformOutput',false);
ColumnNumber = cellfun(@(x) size(x,2), RootCohesionAll, 'UniformOutput',false);

ProgressBar.Message = 'Writing parameters in matrices...';
if strcmp(UniformBeta,'yes')
    BetaStarAll = cellfun(@(x,y) ones(x,y).*BetaStarUniform, RowNumber, ColumnNumber, 'UniformOutput',false);
elseif strcmp(UniformBeta,'no')
    BetaStarAll = cellfun(@cosd, SlopeAll, 'UniformOutput',false);
end

RootCohesionAll = cellfun(@(x,y) ones(x,y).*cRUniform, RowNumber, ColumnNumber, 'UniformOutput',false);

VegAttribution = true;

VariablesVeg = {'RootCohesionAll', 'BetaStarAll'};
VariablesAnswerVeg = {'AnswerAttributionVegetationParameter', 'VegAttribution'};

%% Saving...
ProgressBar.Message = 'Saving...';
cd(fold_var)
save('VegetationParameters.mat', VariablesVeg{:}, '-append');
if exist('UserVeg_Answers.mat', 'file')
    save('UserVeg_Answers.mat', VariablesAnswerVeg{:}, '-append');
else
    save('UserVeg_Answers.mat', VariablesAnswerVeg{:});
end
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version