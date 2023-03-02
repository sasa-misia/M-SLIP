%% Data import
cd(fold_var)

% Fig = uifigure;
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait..', 'Message','Loading files', ...
                                 'Cancelable','on', 'Indeterminate','on');
drawnow

load('GridCoordinates.mat', 'xLongAll','IndexDTMPointsInsideStudyArea')
load('SoilParameters.mat', 'KtAll')
% load('GeneralRainfall.mat')
load('RainInterpolated.mat', 'RainInterpolated')
load('AnalysisInformation.mat', 'StabilityAnalysis')
load('UserE_Answers.mat', 'AnswerRainfallFor')

tic
%% Preliminary operations and data extraction
NumberOfDTM = length(xLongAll);
clear('xLongAll')
AnalysisNumber = StabilityAnalysis{1};
RainStart = StabilityAnalysis{3}(1);
RW = 30*24;
dt = (RW:-1:1);

if AnswerRainfallFor == 1
    HoursPrediction = cellfun(@max,SelectedHoursRun(:,1));
end

KtStudyArea = cellfun(@(x,y) x(y), KtAll, ...
                                   IndexDTMPointsInsideStudyArea, ...
                                   'UniformOutput',false);
clear('KtAll')

%% Evalutation of m
DmCumPar = cell(AnalysisNumber,NumberOfDTM);
Steps = AnalysisNumber*NumberOfDTM;
ProgressBar.Indeterminate = 'off';

IndexRainAnalysis = arrayfun(@(x) x:x+RW-1, 1:StabilityAnalysis{1}, 'UniformOutput',false);
% Rain = cell(1,AnalysisNumber);

for i1 = 1:AnalysisNumber

    ProgressBar.Message = strcat("Processing analysis event n. ",num2str(i1), ...
                                 " of ",num2str(AnalysisNumber));
    if ProgressBar.CancelRequested
        break
    end
    
    if AnswerRainfallFor == 1
        RunForecast = SelectedHoursRun{i1,2};
        cd(fold_var_rain_for)
        load(strcat('RainForecastInterpolated',num2str(RunForecast)));
        RainForecast = RainForecastInterpolated(SelectedHoursRun{i1,1},:);
    end

    for i2 = 1:NumberOfDTM
        % RowNumber = size(xLongAll{i2},1);
        % ColumnNumber = size(xLongAll{i2},2);

        ExpKtDt = arrayfun(@(x) exp(-KtStudyArea{i2}*x), dt, 'UniformOutput',false);
        % Rain = cellfun(@(x) RainInterpolated(x,i2), IndexRainAnalysis(i1), 'UniformOutput',false);
        Rain = RainInterpolated(IndexRainAnalysis{i1},i2);

        if AnswerRainfallFor == 1
            Rain(RW-HoursPrediction(i1)+1:RW) = RainForecast(:,1); % PLEASE MODIFY!
        end

        DmCumTemp = cellfun(@(x,y) full(x)./1000.*y, Rain, ...
                                                     ExpKtDt', ...
                                                     'UniformOutput',false);
        clear('Rain')
        clear('ExpKtDt')

        DmCumPar{i1,i2} = sum( cat(3, DmCumTemp{:}), 3 );
        clear('DmCumTemp')
        
        ProgressBar.Value = (NumberOfDTM*(i1-1)+i2)/Steps;
    end

end

close(ProgressBar) % ProgressBar if in app version
toc

%% Saving...
cd(fold_var)
save('DmCum.mat', 'DmCumPar', '-v7.3')
cd(fold0)