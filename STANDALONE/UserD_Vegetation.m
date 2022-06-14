clc
clear
close all

load('os_folders.mat');
if string(pwd)~=string(fold0)
    User0_FolderCreation
end

%% User Information about the vegetation parameters attribution
% Specify how to attribute vegetation parameter: 0 for uniform parameters in the study
% area; 1 for different parameters according to the vegetation map
tic
choice1=listdlg('PromptString',{'Select vegetation parameters mode:',''},'ListString',...
                {'Uniform','Variegate (vegetation map)'},'SelectionMode','single');
AnswerAttributionVegetationParameter=choice1-1;

% Creating cell array with name of variables that will be stored
Variables={'AnswerAttributionVegetationParameter'};

if AnswerAttributionVegetationParameter==1

    % Write the name of your lithology shapefile (.shp)
    cd(fold_raw_veg)
    Files={dir('*.shp').name};
    choice2=listdlg('PromptString',{'Choose a file:',''},'ListString',Files,...
                    'SelectionMode','single');
    FileName_Vegetation=Files{choice2};

    % Write the fieldname where lithology class names are saved
    VegShape=shaperead(Files{choice2});
    VegShapeFields=unique(fieldnames(VegShape));
    VegShapeFields=[VegShapeFields;{'None of these'}];
    choice3=listdlg('PromptString',{'Choose fieldname where is located vegetation:',''},...
                    'ListString',VegShapeFields,'SelectionMode','single');
    VegFieldName=VegShapeFields{choice3};
    Variables=[Variables;{'FileName_Vegetation';'RefCoordSystem';'VegFieldName'}];
end
toc

%% Saving..
cd(fold_var)
save('UserD_Answers.mat',Variables{:})
cd(fold0)