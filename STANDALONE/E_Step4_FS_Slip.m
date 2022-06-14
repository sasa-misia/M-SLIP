clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Data import
cd(fold_var)
load('GridCoordinates.mat')
load('MorphologyParameters.mat');
load('SoilParameters.mat');
load('VegetationParameters.mat');
load('DmCum.mat');
load('AnalysisInformation.mat');
load('UserE_Answers.mat');

%% Values Assigning
InputValues = inputdlg({'Indicate soil Gs (-):'
                       'Indicate lambda λ (-):'
                       'Indicate alpha α (-):'},'',1,...
                       {'2.7', '0.4', '3.4'});

Gs = eval(InputValues{1});
Lambda = eval(InputValues{2});
Alpha = eval(InputValues{3});
GammaW = 10;

%% Evalutation of Fs and saving
if isfile('UserD_Answers.mat'); SubName1 = 'Veget'; else; SubName1 = 'NoVeget'; end
DEMSize = num2str(round(1000*deg2km(xLongAll{1}(1,2)-xLongAll{1}(1,1)), 1));
FsFolderName = string(inputdlg({'Choose analysis folder name (inside Results->Factors of Safety):'}, '', 1, ...
                               {strcat(datestr(now,'dd-mm-yy-HH-MM'),'-',SubName1,'-',DEMSize,'m')}));
cd(fold_res_fs)

% mkdir(FsFolderName)
if exist(FsFolderName, 'dir')
    Answer = questdlg(strcat(FsFolderName,'is an existing folder. Do you want to overwrite it?'), ...
                	  'Existing Folder', 'Yes, thanks', 'No, for God!', 'No, for God!');
    switch Answer
        case 'Yes, thanks'
            rmdir(FsFolderName, 's')
            mkdir(FsFolderName)
        case 'No, for God!'
            return
    end

else; mkdir(FsFolderName)
end

cd(strcat(fold_res_fs,sl,FsFolderName))

AnalysisNumber = StabilityAnalysis{1};

tic
FactorSafety = cell(1, size(xLongAll,2));
for i1 = 1:AnalysisNumber   
    for i2 = 1:size(xLongAll, 2)
        Cohesion = CohesionAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        n = nAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        Slope = SlopeAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        A = AAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        Phi = PhiAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        RootCohesion = RootCohesionAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        DmCumPar = DmCum{i1,i2};
        Ci = (Cohesion+RootCohesion)+A.*Sr0.*(1-Sr0).^Lambda.*(1-DmCumPar).^Alpha;
        Wi_primo = cosd(Slope).*H.*GammaW.*(DmCumPar.*(n-1)+Gs.*(1-n)+Sr0.*n.*(1-DmCumPar));
        Wi = cosd(Slope).*H.*GammaW.*(DmCumPar.*n+Gs.*(1-n)+Sr0.*n.*(1-DmCumPar));
        FactorSafety{i2} = (Wi_primo.*cosd(Slope).*tand(Phi)+Ci)./(Wi.*sind(Slope));
    end
    save(strcat('Fs',num2str(i1),'.mat'), 'FactorSafety')
    disp(strcat("Finished n. ",num2str(i1)," of ",num2str(AnalysisNumber)))
end
save('AnalysisInformation.mat', 'StabilityAnalysis');
toc

cd(fold0)