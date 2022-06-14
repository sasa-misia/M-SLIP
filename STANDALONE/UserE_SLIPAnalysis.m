clc
clear
close all

load('os_folders.mat');
if string(pwd)~=string(fold0)
    User0_FolderCreation
end

%% User Information about the SLIP Analysis
% Write the name of your lithology shapefile (.shp)
cd(fold_raw_rain)
Files={dir('*.xlsx').name};
choice1=listdlg('PromptString',{'Choose a file:',''},'ListString',Files,...
                'SelectionMode','single');
FileName_Rainfall=Files{choice1};

% Search min and max datetime for analysis window
Rainfall=readcell(FileName_Rainfall,'Sheet','Data table');
RainfallDates=Rainfall(cellfun(@isdatetime,Rainfall));
RainfallDates=[RainfallDates{:}];
AnalysisDateRange=[min(RainfallDates)+days(30),max(RainfallDates)];
AnalysisDateRange=datestr(AnalysisDateRange,'dd/mm/yyyy HH:MM:ss');

% Creating analysis window (from...to...stability evaluation)
choice2=inputdlg({'Initial date and hour (default is min):',...
                  'Ending date and hour (default is max):'},'',1,...
                 {AnalysisDateRange(1,:),AnalysisDateRange(2,:)});
AnalysisWindow=choice2';

% Attribution of Sr0 and H
choice3=inputdlg({'Indicate initial saturation Sr0 (-):',...
                  'Indicate depth of analysis H (meters):'},'',1,{'0.55','1.2'});
Sr0=eval(choice3{1});
H=eval(choice3{2});

% Creating cell array with name of variables that will be stored
Variables={'FileName_Rainfall','AnalysisWindow','Sr0','H'};

%% Saving..
cd(fold_var)
save('UserE_Answers.mat',Variables{:})
cd(fold0)