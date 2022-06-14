clc
clear
close all

load('os_folders.mat');
if string(pwd)~=string(fold0)
    User0_FolderCreation
end

%% User Information about the Soil parameters attribution
% Specify how to attribute soil parameter: 0 for uniform parameters in the study
% area; 1 for different parameters according to the lithology map
tic
choice1=listdlg('PromptString',{'Select soil parameters mode:',''},'ListString',...
                {'Uniform','Variegate (lithology map)'},'SelectionMode','single');
AnswerAttributionSoilParameter=choice1-1;

% Creating cell array with name of variables that will be stored
Variables={'AnswerAttributionSoilParameter'};

if AnswerAttributionSoilParameter==1
    % Write the name of your lithology shapefile (.shp)
    cd(fold_raw_lit)
    Files={dir('*.shp').name};
    choice2=listdlg('PromptString',{'Choose a file:',''},'ListString',Files,...
                    'SelectionMode','single');
    FileName_Lithology=Files{choice2};

    % Write the fieldname where lithology class names are saved
    LitShape=shaperead(Files{choice2});
    LitShapeFields=unique(fieldnames(LitShape));
    LitShapeFields=[LitShapeFields;{'None of these'}];
    choice3=listdlg('PromptString',{'Choose fieldname where are located lithologies:',''},...
                    'ListString',LitShapeFields,'SelectionMode','single');
    LitFieldName=LitShapeFields{choice3};
    Variables=[Variables;{'FileName_Lithology';'LitFieldName'}];   
end
toc

%% Saving..
cd(fold_var)
save('UserC_Answers.mat',Variables{:})
cd(fold0)