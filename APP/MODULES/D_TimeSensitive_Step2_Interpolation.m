if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig,'Title','Please wait..', ...
                                'Message','Loading files', 'Cancelable','on', ...
                                'Indeterminate','on');
drawnow

%% Import data
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'],      'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load([fold_var,sl,'RainInterpolated.mat'],     'IndexInterpolation')
load([fold_var,sl,'UserTimeSens_Answers.mat'], 'AnswerTypeRec','AnswerTypeFor')

StatusPrevAnalysis = 0;
if exist([fold_var,sl,'AnalysisInformation.mat'], 'file')
    load([fold_var,sl,'AnalysisInformation.mat'], 'StatusPrevAnalysis')
end

if AnswerTypeRec == 1
    load([fold_var,sl,'GeneralRainfall.mat'], 'Gauges','GeneralData')
end

if AnswerTypeFor == 1
    load([fold_var,sl,'RainInterpolated.mat'], 'SelectedHoursRun')
end

[xLongSta, yLatSta] = deal(Gauges{2}(:,1), Gauges{2}(:,2));
xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy  = cellfun(@(x,y) x(y), yLatAll,  IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

%% Interpolation for recording
if AnswerTypeRec == 1
    if StatusPrevAnalysis == 1
        Answer = uiconfirm(Fig, ['Interpolated rain data already exist. ' ...
                                 'Do you want to overwrite them?'], ...
                                'Existing Interpolated Data', ...
                                'Options',{'Yes','No, for God!'}, 'DefaultOption', 2);
        if strcmp(Answer,'No, for God!'); return; end
    end
    
    tic
    ProgressBar.Indeterminate = 'off';
    Steps = size(IndexInterpolation,2);
    RainInterpolated = cell(size(IndexInterpolation,2),size(xLongAll,2));
    for i1 = 1:size(IndexInterpolation,2)
        ProgressBar.Value   = i1/Steps;
        ProgressBar.Message = ['Working on n. ',num2str(i1),' of ',num2str(size(IndexInterpolation,2))];

        % Check for Cancel button press
        if ProgressBar.CancelRequested; break; end
    
        CurrIntrp = scatteredInterpolant(xLongSta, yLatSta, GeneralData(:,IndexInterpolation(i1)), 'natural');   
        for i2 = 1:size(xLongAll,2)
            xLong = xLongAll{i2}(IndexDTMPointsInsideStudyArea{i2});
            yLat  = yLatAll{i2}(IndexDTMPointsInsideStudyArea{i2});
            hw1   = max(CurrIntrp(xLong,yLat), 0); % Rain evaluation only in the internal points 
            RainInterpolated{i1,i2} = sparse(hw1); % On rows are saved temporal events of the same raster box
        end
    end
    toc

    if ProgressBar.CancelRequested; return; end
    saveswitch([fold_var,sl,'RainInterpolated.mat'], {'RainInterpolated','IndexInterpolation'});
    if AnswerTypeFor == 1; save([fold_var,sl,'RainInterpolated.mat'], 'SelectedHoursRun', '-append'); end % To use in order to reintroduce all the old variables
end

%% Interpolation for forecasting
if AnswerTypeFor == 1
    MeshLong = GridForecastModel{1};
    MeshLat  = GridForecastModel{2};

    fold_var_rain_for = strcat(fold_var,sl,'Interpolated Forecast Rainfall');
    if ~exist(fold_var_rain_for, 'dir')
        mkdir(fold_var_rain_for)
    end

    ForecastRunUnique = unique([SelectedHoursRun{:,2}]);
    for i4 = 1:length(ForecastRunUnique)
        IndexForecastRun = cellfun(@(x) x==ForecastRunUnique(i4),SelectedHoursRun(:,2));
        IndexForecastToInterpolate = unique([SelectedHoursRun{IndexForecastRun,1}]);
        
        RainForecast = ForecastData{ForecastRunUnique(i4),4}(IndexForecastToInterpolate,:,:);
        RainForecastInterpolated = cell(size(IndexForecastToInterpolate,2),length(xLongAll));

        ProgressBar.Message = ['Event n. ',num2str(i4),' of ',num2str(length(ForecastRunUnique)),', please wait...'];
        Steps = size(RainForecast,1);
        for i11 = 1:size(RainForecast,1)
            ProgressBar.Value   = i11/Steps;
            ProgressBar.Message = ['Interpolating n. ',num2str(i11),' of ',num2str(Steps)];

            % Check for Cancel button press
            if ProgressBar.CancelRequested; break; end

            CurrRain  = squeeze(RainForecast(i11, :, :));
            CurrIntrp = scatteredInterpolant(MeshLong(:), MeshLat(:), CurrRain(:), 'natural');
            for i22 = 1:length(xLongAll)
                xLong = xLongAll{i22}(IndexDTMPointsInsideStudyArea{i22});
                yLat  = yLatAll{i22}(IndexDTMPointsInsideStudyArea{i22});
                hw1   = max(CurrIntrp(xLong,yLat), 0);
                RainForecastInterpolated{i11,i22} = sparse(hw1);
            end
        end

        % Check for Cancel button press
        if ProgressBar.CancelRequested; break; end
        saveswitch([fold_var_rain_for,sl,'RainForecastInterpolated',num2str(ForecastRunUnique(i4))], {'RainForecastInterpolated'});
    end

    if ProgressBar.CancelRequested; return; end
    save([fold0,sl,'os_folders.mat'], 'fold_var_rain_for', '-append')
end