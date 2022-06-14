clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end
%% Assign uniform values
cd(fold_var)
load('GridCoordinates.mat');
load('VegetationParameters.mat');

InputValues = inputdlg({'Root cohesion value {\it c_r} (kPa):'
                        'Assign uniform {\beta^*} (already calculate through slope) (Yes/No)'
                        ['{\beta^*} value (not necessary if set No previously) (-). ' ...
                         'Value between 0 and 1:']}, '', 1, {'0','No','1'});

cRUniform = eval(InputValues{1});
UniformBeta = string(lower(InputValues{2}));
BetaStarUniform = eval(InputValues{3});

for i1 = 1:length(RootCohesionAll)
    RowNumber = size(RootCohesionAll{i1},1);
    ColumnNumber = size(RootCohesionAll{i1},2);
    if UniformBeta == "yes"
        BetaStarAll{i1} = ones(RowNumber,ColumnNumber).*BetaStarUniform;
    end
    RootCohesionAll{i1} = ones(RowNumber,ColumnNumber).*cRUniform;
end
VariablesVeg = {'RootCohesionAll'};
if UniformBeta == "yes"; Variables = [Variables, {'BetaStarAll'}]; end

%% Saving...
save('VegetationParameters.mat', VariablesVeg{:}, '-append');
cd(fold0)