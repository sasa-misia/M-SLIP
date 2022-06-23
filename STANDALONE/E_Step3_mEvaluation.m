clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Data import
tic
cd(fold_var)

Fig = uifigure; % Remember to comment this line if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait..', 'Message','Loading files', ...
                                 'Cancelable','on', 'Indeterminate','on');
drawnow

load('GridCoordinates.mat')
load('SoilParameters.mat');
load('VegetationParameters.mat');
load('GeneralRainfall.mat');
load('RainInterpolated.mat');
load('AnalysisInformation.mat');
load('UserE_Answers.mat');

%% Preliminary operations and data extraction
AnalysisNumber = StabilityAnalysis{1};
RainStart = StabilityAnalysis{3}(1);
RW = 30*24;
dt = (RW:-1:1);
if AnswerRainfallFor == 1; HoursPrediction = cellfun(@max, SelectedHoursRun(:,1)); end

%% Evalutation of m
DmCum = cell(AnalysisNumber, length(xLongAll));
Steps = AnalysisNumber*length(xLongAll)*RW;
ProgressBar.Indeterminate = 'off';
for i1 = 1:AnalysisNumber
    Rain = cell(RW, 1);

    if AnswerRainfallFor == 1
        RunForecast = SelectedHoursRun{i1,2};
        cd(fold_var_rain_for)
        load(strcat('RainForecastInterpolated',num2str(RunForecast)));
        RainForecast = RainForecastInterpolated(SelectedHoursRun{i1,1},:);
    end

    for i2 = 1:length(xLongAll)
        RowNumber = size(xLongAll{i2},1);
        ColumnNumber = size(xLongAll{i2},2);
        DmCumPar = zeros(RowNumber, ColumnNumber);
        Rain = RainInterpolated(i1:RW-1+i1, i2); % Forse qui si genera un pò di confusione se le date che scegli non sono una dietro l'altra
        if AnswerRainfallFor == 1; Rain(RW-HoursPrediction(i1)+1:RW) = RainForecast(:,1); end

        for i3 = 1:RW
            ProgressBar.Value = (length(xLongAll)*RW*(i1-1)+RW*(i2-1)+i3)/Steps;
            if ProgressBar.CancelRequested; break; end
            Hw = Rain{i3}./1000; % It is important to have Rain in m
            if any(Hw)
                DmCumPar(IndexDTMPointsInsideStudyArea{i2}) = DmCumPar(IndexDTMPointsInsideStudyArea{i2})+ ...
                                              Hw.*exp(-KtAll{i2}(IndexDTMPointsInsideStudyArea{i2}).*dt(i3));
            end
            ProgressBar.Message = strcat("Processing analysis event n. ",num2str(i1)," of ",num2str(AnalysisNumber));
        end

        DmCum{i1,i2} = min(BetaStarAll{i2}(IndexDTMPointsInsideStudyArea{i2})./ ...
                          (nAll{i2}(IndexDTMPointsInsideStudyArea{i2}).*H.* ...
                          (1-Sr0)).*DmCumPar(IndexDTMPointsInsideStudyArea{i2}), 1); % You cannot have DmCum > 1 because when you have 1 is already completely saturated
    end
end
close(Fig) % ProgressBar if in app version
toc

%% Saving..
cd(fold_var)
save('DmCum.mat', 'DmCum', '-v7.3')
cd(fold0)