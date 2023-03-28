Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
ProgressBar.Message = "Loading data...";
cd(fold_var)
load('GeneralRainfall.mat', 'GeneralRainData','RainGauges','RainfallDates') % Remember that RainfallDates are referred at the end of your registration period
load('GridCoordinates.mat', 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
cd(fold0)

%% Elaboration of data and selection of dates
ProgressBar.Message = "Selection od dates...";
[xLongSta, yLatSta] = deal(RainGauges{2}(:,1), RainGauges{2}(:,2));

EndDateInd = listdlg('PromptString',{'Select the date of your event:',''}, ...
                     'ListString',RainfallDates, 'SelectionMode','single');

MaxDaysPossible = caldays(between(RainfallDates(1), RainfallDates(EndDateInd), 'days'));

NumberOfDays = str2double(inputdlg({["How many days do you want to consider? "
                                     strcat("(Max possible with your dataset:  ",string(MaxDaysPossible)," days")]}, ...
                                     '', 1, {num2str(MaxDaysPossible)}));

EndDate          = RainfallDates(EndDateInd);
StartDate        = RainfallDates(EndDateInd)-days(NumberOfDays);
StartDateInd     = find(abs(minutes(RainfallDates-StartDate)) <= 1);
dTRecordings     = RainfallDates(2)-RainfallDates(1);
StepForEntireDay = int64(days(1)/dTRecordings);

if (NumberOfDays > MaxDaysPossible) || (NumberOfDays <= 0)
    error(strcat('You have to specify a number that go from 1 to ',num2str(MaxDaysPossible)))
end

%% Interpolation
ProgressBar.Message = "Interpolation...";
RainCumDay = zeros(size(GeneralRainData,1), NumberOfDays);
for i1 = 1:NumberOfDays
    RainCumDay(:,i1) = sum( GeneralRainData(:, (StartDateInd+StepForEntireDay*(i1-1)+1):StartDateInd+StepForEntireDay*(i1)), 2 );
end

ProgressBar.Indeterminate = 'off';
RainInterpolated = cell(size(RainCumDay,2), size(xLongAll,2));
for i1 = 1:size(RainCumDay,2)
    ProgressBar.Value = i1/size(RainCumDay,2);
    ProgressBar.Message = strcat("Interpolating day ", string(i1)," of ", string(size(RainCumDay,2)));

    CurrInterpolation = scatteredInterpolant(xLongSta, yLatSta, RainCumDay(:,i1), 'natural');   
    for i2 = 1:size(xLongAll,2)
        xLong = xLongAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        yLat  = yLatAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        hw1   = max(CurrInterpolation(xLong,yLat), 0); % Rain evaluation only in the internal points 
        RainInterpolated{i1,i2} = sparse(hw1); % On rows are saved temporal events of the same raster box
    end      
end
ProgressBar.Indeterminate = 'on';

DateInterpolationStarts = RainfallDates(StartDateInd):days(1):RainfallDates(StartDateInd)+days(NumberOfDays-1); % -1 because normally you would take 00:00 of the day after the desired, for having the complete interpolation of the past day.

%% Saving...
ProgressBar.Message = "Saving...";
cd(fold_var)
save('RainInterpolated.mat',  'RainInterpolated','DateInterpolationStarts');
save('DateInterpolation.mat', 'DateInterpolationStarts','StartDate','EndDate','RainCumDay');
cd(fold0)
close(Fig)