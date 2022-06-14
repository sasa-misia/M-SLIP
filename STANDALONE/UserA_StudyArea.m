clc
clear
close all

load('os_folders.mat');
if string(pwd)~=string(fold0)
    User0_FolderCreation
end

%% User Information about the study area
% Write the name of your shapefile (.shp)
cd(fold_raw_mun)
Files={dir('*.shp').name};
choice1=listdlg('PromptString',{'Choose Municipalities file:',''},'ListString',Files,...
                'SelectionMode','single');
FileName_StudyArea=Files{choice1};

% Write the fieldname where municipalities names are saved
MunShape=shaperead(Files{choice1});
MunShapeFields=unique(fieldnames(MunShape));
MunShapeFields=[MunShapeFields;{'None of these'}];
choice2=listdlg('PromptString',{'Choose fieldname where are located municipalities:',''},...
                'ListString',MunShapeFields,'SelectionMode','single');
MunFieldName=MunShapeFields{choice2};

% Write the selected municipalities for your study area
if string(MunFieldName)~="None of these"
    MunOpt=unique({MunShape.(MunFieldName)});
    choice3=listdlg('PromptString',{'Choose municipality:',''},'ListString',MunOpt);      
    MunSel=MunOpt(choice3);
else
    MunSel=[];
    MunFieldName=[];
end

% Creating cell array with name of variables that will be stored
Variables={'FileName_StudyArea','MunFieldName','MunSel'};

%% User information about land uses
cd(fold_raw_land_uses)
Files2={dir('*.shp').name};
choice4=listdlg('PromptString',{'Choose Land Uses file:',''},'ListString',Files2,...
                'SelectionMode','single');
FileName_LandUses=Files2{choice4};

LandUseShape=shaperead(FileName_LandUses);
LandUseShapeFields=unique(fieldnames(LandUseShape));
LandUseShapeFields=[LandUseShapeFields;{'None of these'}];
choice5=listdlg('PromptString',{'Choose fieldname where are located land uses:',''},...
                'ListString',LandUseShapeFields,'SelectionMode','single');
LandUsesFieldName=LandUseShapeFields{choice5};

Variables=[Variables,{'FileName_LandUses','LandUsesFieldName'}];

%% Saving..
cd(fold_var)
save('UserA_Answers.mat',Variables{:})
cd(fold0)