clc
clear
close all

load('os_folders.mat');
if string(pwd)~=string(fold0)
    User0_FolderCreation
end

%% Analysis and event choice
cd(fold_res_fs)
FolderList={dir().name}; FolderList=FolderList([dir().isdir]); FolderList(1:2)=[];
Choice=listdlg('PromptString',{'Choose an analysis folder:',''},'ListString',FolderList,...
                'SelectionMode','single');
fold_res_fs_an=strcat(fold_res_fs,sl,FolderList{Choice});
cd(fold_res_fs_an)
load('AnalysisInformation.mat');

Start=StabilityAnalysis{2}(1,1);
End=StabilityAnalysis{2}(1,2);
IntervalsNum=StabilityAnalysis{1}-1;
DateOptions=(Start:((End-Start)/IntervalsNum):End);
Choice=listdlg('PromptString',{'Choose an analysis date:',''},'ListString',...
                string(DateOptions),'SelectionMode','single');
Event=Choice;

% Creating cell array with name of variables that will be stored
Variables={'fold_res_fs_an','Event'};

%% Saving..
cd(fold_var)
save('UserF_Answers.mat',Variables{:})
cd(fold0)