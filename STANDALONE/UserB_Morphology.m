clc
clear
close all

load('os_folders.mat');
if string(pwd)~=string(fold0)
    User0_FolderCreation
end

%% User Information about the morphology
% Specify your DTM format (0 Tiff+Tfw, 1 geotiff,2 arcgrid)
tic
cd(fold_raw_dtm)
Files={dir().name};
Files(1:2)=[];
choice1=listdlg('PromptString',{'Choose a file:',''},'ListString',Files);
FileName_DTM=string(Files(choice1));

if any(contains(FileName_DTM,'tif')) && any(contains(FileName_DTM,'tfw'))
    DTMType=0;
elseif all(contains(FileName_DTM,'tif'))
    DTMType=1;
elseif all(contains(FileName_DTM,'asc'))
    DTMType=2;
end

% Creating cell array with name of variables that will be stored
Variables={'FileName_DTM','DTMType'};

% Indicate if you need to change the DTM resolution (0 no, 1 yes), if 1 the
% new resolution
choice2=listdlg('PromptString',{'Do you want to change DTM resolution?',''},...
                'ListString',{'No','Yes'},'SelectionMode','single');
AnswerChangeDTMResolution=choice2-1;

if AnswerChangeDTMResolution==1
    choice3=inputdlg('Indicate new resolution (in meters):');
    NewDx=str2double(choice3{1}); % New discretisation in meters
    NewDy=NewDx;
    Variables=[Variables,{'NewDx','NewDy','AnswerChangeDTMResolution'}];
else
    Variables=[Variables,{'AnswerChangeDTMResolution'}];
end
toc

%% Saving..
cd(fold_var)
save('UserB_Answers.mat',Variables{:});
cd(fold0)