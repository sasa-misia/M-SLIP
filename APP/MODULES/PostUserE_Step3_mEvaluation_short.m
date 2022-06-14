%% Data import
tic
cd(fold_var)
% Fig=uifigure;
ProgressBar=uiprogressdlg(Fig,'Title','Please wait..','Message','Loading files','Cancelable','on','Indeterminate','on');
drawnow
load('GridCoordinates.mat')
load('SoilParameters.mat')
load('VegetationParameters.mat')
load('GeneralRainfall.mat')
load('RainInterpolated.mat')
load('AnalysisInformation.mat')
load('UserE_Answers.mat')

%% Preliminary operations and data extraction
AnalysisNumber=StabilityAnalysis{1};
RainStart=StabilityAnalysis{3}(1);
RW=30*24;
dt=(RW:-1:1);

if AnswerRainfallFor==1
    HoursPrediction=cellfun(@max,SelectedHoursRun(:,1));
end

KtStudyArea=cellfun(@(x,y) x(y),KtAll,IndexDTMPointsInsideStudyArea,'UniformOutput',false);
BetaStarStudyArea=cellfun(@(x,y) x(y),BetaStarAll,IndexDTMPointsInsideStudyArea,'UniformOutput',false);
nStudyArea=cellfun(@(x,y) x(y),nAll,IndexDTMPointsInsideStudyArea,'UniformOutput',false);

%% Evalutation of m
DmCum=cell(AnalysisNumber,length(xLongAll));
Steps=AnalysisNumber*length(xLongAll);
ProgressBar.Indeterminate='off';

IndexRainAnalysis=arrayfun(@(x) x:x+RW-1,1:StabilityAnalysis{1},'UniformOutput',false);
Rain=cell(1,AnalysisNumber);


for i1=1:AnalysisNumber
    
    if AnswerRainfallFor==1
        RunForecast=SelectedHoursRun{i1,2};
        cd(fold_var_rain_for)
        load(strcat('RainForecastInterpolated',num2str(RunForecast)));
        RainForecast=RainForecastInterpolated(SelectedHoursRun{i1,1},:);
    end


    for i2=1:length(xLongAll)
        RowNumber=size(xLongAll{i2},1);
        ColumnNumber=size(xLongAll{i2},2);

        ExpKtDt=arrayfun(@(x) exp(-KtStudyArea{i2}*x),dt,'UniformOutput',false);
        Rain=cellfun(@(x) RainInterpolated(x,i2), IndexRainAnalysis, 'UniformOutput', false);

        if AnswerRainfallFor==1
            Rain{i1}(RW-HoursPrediction(i1)+1:RW)=RainForecast(:,i2);
        end

        DmCumPar=cellfun(@(x,y) full(x)./1000.*y,Rain{i1},ExpKtDt','UniformOutput',false);
        DmCum{i1,i2}=min(BetaStarStudyArea{i2}./(nStudyArea{i2}.*H.*(1-Sr0))...
                .*sum(cat(3,DmCumPar{:}),3),1);
        
        ProgressBar.Value=(length(xLongAll)*(i1-1)+i2)/Steps;
    end
    ProgressBar.Message=strcat("Processing analysis event n. ",num2str(i1)," of ",num2str(AnalysisNumber));
    if ProgressBar.CancelRequested
        break
    end

end

        


    %disp(strcat('Finished n. ',num2str(i1)," of ",num2str(AnalysisNumber)))

close(ProgressBar)
toc

%% Saving..
cd(fold_var)
save('DmCum.mat','DmCum','-v7.3');
cd(fold0)