%% Assign uniform values
cd(fold_var)
load('GridCoordinates.mat')
load('VegetationParameters.mat')
load('MorphologyParameters.mat','SlopeAll');

InputValues = inputdlg({'Root cohesion value {\it c_r} (kPa):'
                        'Assign uniform {\beta^*} (already calculate through slope) (Yes/No)'
                       ['{\beta^*} value (not necessary if set No previously) (-). ' ...
                        'Value between 0 and 1:']},'', 1, {'0','No','1'});

cRUniform = eval(InputValues{1});
UniformBeta = string(lower(InputValues{2}));
BetaStarUniform = eval(InputValues{3});

RowNumber=cellfun(@(x) size(x,1),RootCohesionAll,'UniformOutput',false);
ColumnNumber=cellfun(@(x) size(x,2),RootCohesionAll,'UniformOutput',false);

if UniformBeta == "yes"
    BetaStarAll=cellfun(@(x,y) ones(x,y).*BetaStarUniform,RowNumber,ColumnNumber,'UniformOutput',false);
elseif  UniformBeta == "no"
    BetaStarAll=cellfun(@cosd,SlopeAll,'UniformOutput',false);
end

RootCohesionAll= cellfun(@(x,y) ones(x,y).*cRUniform,RowNumber,ColumnNumber,'UniformOutput',false);


VegAttribution = true;

%VariablesVeg = {'RootCohesionAll'};
VariablesVeg = {'RootCohesionAll';'BetaStarAll'};
%if UniformBeta == "yes"; VariablesVeg = [VariablesVeg, {'BetaStarAll'}]; end
VariablesAnswerD = {'AnswerAttributionVegetationParameter', 'VegAttribution'};

%% Saving...
save('VegetationParameters.mat', VariablesVeg{:}, '-append');

if exist('UserD_Answers.mat')
    save('UserD_Answers.mat', VariablesAnswerD{:}, '-append');
else
    save('UserD_Answers.mat', VariablesAnswerD{:});
end
cd(fold0)