if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% Data import
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'],      'xLongAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'SoilParameters.mat'],       'KtAll')
load([fold_var,sl,'RainInterpolated.mat'],     'RainInterpolated')
load([fold_var,sl,'AnalysisInformation.mat'],  'StabilityAnalysis')
load([fold_var,sl,'UserTimeSens_Answers.mat'], 'AnswerTypeFor')
if not(exist('AnswerTypeFor','var')); AnswerTypeFor = false; end
if AnswerTypeFor
    load([fold_var,sl,'RainInterpolated.mat'], 'SelectedHoursRun')
end

%% Preliminary operations and data extraction
ProgressBar.Message = 'Preliminary operations...';

NumberOfDTM = length(xLongAll);
clear('xLongAll')

AnalysisNumber = StabilityAnalysis{1};
RainStart = StabilityAnalysis{3}(1);
RW = 30*24;
dt = (RW:-1:1);

if AnswerTypeFor == 1
    HoursPrediction = cellfun(@max,SelectedHoursRun(:,1));
end

KtStudyArea = cellfun(@(x,y) x(y), KtAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
clear('KtAll')

%% Evalutation of m
ProgressBar.Indeterminate = 'off';
ProgressBar.Cancelable    = 'on';

tic
IndRnAn  = arrayfun(@(x) x:x+RW-1, 1:StabilityAnalysis{1}, 'UniformOutput',false);
Steps    = AnalysisNumber*NumberOfDTM*numel(dt);
DmCumPar = cell(AnalysisNumber,NumberOfDTM);
for i1 = 1:AnalysisNumber
    ProgressBar.Message = ['Processing analysis event n. ', ...
                           num2str(i1),' of ',num2str(AnalysisNumber)];
    if ProgressBar.CancelRequested; break; end
    
    if AnswerTypeFor == 1
        RunForecast  = SelectedHoursRun{i1,2};
        load([fold_var_rain_for,sl,'RainForecastInterpolated',num2str(RunForecast)], 'RainForecastInterpolated');

        RainForecast = RainForecastInterpolated(SelectedHoursRun{i1,1},:);
        IndToReplace = RW-HoursPrediction(i1)+1:RW;
    end

    for i2 = 1:NumberOfDTM
        DmCumPar{i1,i2} = zeros(size(KtStudyArea{i2}));
        for i3 = 1:numel(dt) % This third cycle is necessary to avoid OUT OF MEMORY error!
            ProgressBar.Value = (numel(dt)*(NumberOfDTM*(i1-1)+(i2-1))+i3)/Steps;

            RainTmp = RainInterpolated{IndRnAn{i1}(i3), i2};
            if AnswerTypeFor == 1 && any(IndToReplace == i3)
                IndFor  = IndToReplace == i3;
                RainTmp = RainForecast{IndFor, 1}; % PLEASE REMEMBER TO MODIFY! NOT EVERYTIME LAST INDEX OF FORECAST IS THE SAME OF RECS, BUT JUST WITH ANALYSES IN THE PAST! INVESTIGATE ALSO ON 1 AS COLUMN!
                warning('Not yet tested! Please contact the support in case of issues!')
            end

            ExpKtDtTmp = exp(-KtStudyArea{i2}*dt(i3));
            DmCumTemp  = full(RainTmp)./1000.*ExpKtDtTmp; % ./1000 because of millimiters
    
            DmCumPar{i1,i2} = DmCumPar{i1,i2} + DmCumTemp;
        end
    end
end
toc

if ProgressBar.CancelRequested; return; end
ProgressBar.Cancelable = 'off';

%% Saving...
ProgressBar.Message = 'Saving...';

saveswitch([fold_var,sl,'DmCum.mat'], {'DmCumPar'})