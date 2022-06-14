clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Data import and extraction
tic
cd(fold_var)
load('GridCoordinates.mat')
load('RainInterpolated.mat','IndexInterpolation','SelectedHoursRun')
load('UserE_Answers.mat')

StatusPrevAnalysis = 0;
if exist('AnalysisInformation.mat', 'file'); load('AnalysisInformation.mat','StatusPrevAnalysis'); end

if AnswerRainfallRec == 1; load('GeneralRainfall.mat'); end

[xLongSta, yLatSta] = deal(RainGauges{2}(:,1), RainGauges{2}(:,2));

%% Interpolation for recording
if AnswerRainfallRec == 1 && StatusPrevAnalysis == 0
    RainInterpolated = cell(size(GeneralRainData,2), size(xLongAll,2));
    Fig = uifigure; % Remember to comment this line if is app version
    ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Initializing', 'Cancelable','on');
    Steps = size(IndexInterpolation,2);

    for i1 = 1:size(IndexInterpolation,2)
        ProgressBar.Value = i1/Steps;
        if ProgressBar.CancelRequested; break; end % Check for Cancel button press

        CurrInterpolation = scatteredInterpolant(xLongSta, yLatSta, GeneralRainData(:,IndexInterpolation(i1)), 'natural');   
        for i2 = 1:size(xLongAll,2)
            xLong = xLongAll{i2}(IndexDTMPointsInsideStudyArea{i2});
            yLat = yLatAll{i2}(IndexDTMPointsInsideStudyArea{i2});
            hw1 = max(CurrInterpolation(xLong,yLat), 0); % Rain evaluation only in the internal points 
            RainInterpolated{i1,i2} = sparse(hw1); % On rows are saved different temporal events of the same raster box (in column)
        end
        ProgressBar.Message = strcat("Finished n. ",num2str(i1)," of ",num2str(size(IndexInterpolation,2)));
    end

    if ~ProgressBar.CancelRequested; save('RainInterpolated.mat', 'RainInterpolated', 'IndexInterpolation', '-append'); end
    close(Fig) % ProgressBar instead of Fig if on the app version
else
    Fig = uifigure;
    Alert = uialert(Fig, 'Recorded rainfall already interpolated from previous analyses', 'Warning');
    pause(3)
    close(Fig) % Alert instead of Fig if on the app version
end
cd(fold0)

%% Interpolation for forecasting
if AnswerRainfallFor == 1
    MeshLong = GridForecastModel{1};
    MeshLat = GridForecastModel{2};

    fold_var_rain_for = strcat(fold_var,sl,'Interpolated Forecast Rainfall');
    if ~exist(fold_var_rain_for, 'dir'); mkdir(fold_var_rain_for); end
    cd(fold_var_rain_for)

    ForecastRunUnique = unique([SelectedHoursRun{:,2}]);
    for i4 = 1:length(ForecastRunUnique)
        IndexForecastRun = cellfun(@(x) x==ForecastRunUnique(i4), SelectedHoursRun(:,2));
        IndexForecastToInterpolate = unique([SelectedHoursRun{IndexForecastRun,1}]);
        
        RainForecast = ForecastData{ForecastRunUnique(i4),4}(IndexForecastToInterpolate,:,:);
        RainForecastInterpolated = cell(size(IndexForecastToInterpolate,2), length(xLongAll));

        Fig = uifigure;
        ProgressBar = uiprogressdlg(Fig, 'Title',strcat("Event n.",num2str(i4)," of ",num2str(length(ForecastRunUnique)),". Please wait"), ...
                                    'Message','Initializing', 'Cancelable','on');
        Steps = size(RainForecast,1);
        for i11 = 1:size(RainForecast,1)
            ProgressBar.Value = i11/Steps;
            ProgressBar.Message = strcat("Interpolating n. ",num2str(i11)," of ", num2str(Steps));
            if ProgressBar.CancelRequested; break; end % Check for Cancel button press
            CurrRain = squeeze(RainForecast(i11, :, :));
            CurrInterpolation = scatteredInterpolant(MeshLong(:), MeshLat(:), CurrRain(:), 'natural');
            for i22 = 1:length(xLongAll)
                xLong = xLongAll{i22}(IndexDTMPointsInsideStudyArea{i22});
                yLat = yLatAll{i22}(IndexDTMPointsInsideStudyArea{i22});
                hw1 = max(CurrInterpolation(xLong,yLat), 0);
                RainForecastInterpolated{i11,i22} = sparse(hw1);
            end
        end

        if ~ProgressBar.CancelRequested
            save(strcat('RainForecastInterpolated',num2str(ForecastRunUnique(i4))), ...
                 'RainForecastInterpolated', '-v7.3');
        end
    end
    close(Fig) % ProgressBar instead of Fig if on the app version
    cd(fold0)
    save('os_folders.mat', 'fold_var_rain_for', '-append')
end
toc