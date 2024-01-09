if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
ProgressBar.Message = "Loading data...";
Options  = {'Rainfall', 'Temperature'};
DataRead = uiconfirm(Fig, 'What type of data do you want to read?', ...
                          'Reading Data', 'Options',Options, 'DefaultOption',1);
switch DataRead
    case 'Rainfall'
        GeneralFileName = 'GeneralRainfall.mat';
        ShortName       = 'Rain';
    case 'Temperature'
        GeneralFileName = 'GeneralTemperature.mat';
        ShortName       = 'Temp';
end

load([fold_var,sl,GeneralFileName],       'GeneralData','Gauges','RecDatesEndCommon') % Remember that RainfallDates are referred at the end of your registration period
load([fold_var,sl,'GridCoordinates.mat'], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')

%% Elaboration of data and selection of dates
ProgressBar.Message = "Selection od dates...";
[xLongSta, yLatSta] = deal(Gauges{2}(:,1), Gauges{2}(:,2));

EndDateInd   = listdlg2({'Last date to interpolate (suggested hour is 00:00):'}, ...
                        RecDatesEndCommon, 'OutType','NumInd');
MaxDaysPoss  = caldays(between(RecDatesEndCommon(1), RecDatesEndCommon(EndDateInd), 'days'));
NumberOfDays = str2double(inputdlg2({['Days to consider? (Max possible: ', ...
                                      num2str(MaxDaysPoss)]}, 'DefInp',{num2str(MaxDaysPoss)}));

EndDate          = RecDatesEndCommon(EndDateInd);
StartDate        = RecDatesEndCommon(EndDateInd) - days(NumberOfDays);
StartDateInd     = find(abs(minutes(RecDatesEndCommon - StartDate)) <= 1);
dTRecordings     = RecDatesEndCommon(2) - RecDatesEndCommon(1);
StepForEntireDay = int64(days(1)/dTRecordings);

if (NumberOfDays > MaxDaysPoss) || (NumberOfDays <= 0)
    error(strcat('You have to specify a number that go from 1 to ',num2str(MaxDaysPoss)))
end

%% Interpolation
ProgressBar.Message = "Interpolation...";
DataDaily = zeros(size(GeneralData,1), NumberOfDays);
for i1 = 1:NumberOfDays
    switch DataRead
        case 'Rainfall'
            DataDaily(:,i1) = sum(  GeneralData(:, (StartDateInd+StepForEntireDay*(i1-1)+1) : StartDateInd+StepForEntireDay*(i1)), 2 );

        case 'Temperature'
            DataDaily(:,i1) = mean( GeneralData(:, (StartDateInd+StepForEntireDay*(i1-1)+1) : StartDateInd+StepForEntireDay*(i1)), 2 );
    end
end

Options = {'linear', 'nearest', 'natural'};
InterpMethod = uiconfirm(Fig, 'What interpolation method do you want to use?', ...
                              'Interpolation methods', 'Options',Options);
ProgressBar.Indeterminate = 'off';
DataInterpolated = cell(size(DataDaily,2), size(xLongAll,2));
for i1 = 1:size(DataDaily,2)
    ProgressBar.Value = i1/size(DataDaily,2);
    ProgressBar.Message = strcat("Interpolating day ", string(i1)," of ", string(size(DataDaily,2)));

    CurrInterpolation = scatteredInterpolant(xLongSta, yLatSta, DataDaily(:,i1), InterpMethod); 
    for i2 = 1:size(xLongAll,2)
        xLong = xLongAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        yLat  = yLatAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        switch DataRead
            case 'Rainfall'
                TempValues = max(CurrInterpolation(xLong,yLat), 0);
            case 'Temperature'
                TempValues = CurrInterpolation(xLong,yLat);
        end
        DataInterpolated{i1,i2} = sparse(TempValues); % On rows are saved temporal events of the same raster box
    end      
end
ProgressBar.Indeterminate = 'on';

DateInterpolationStarts = RecDatesEndCommon(StartDateInd) : days(1) : RecDatesEndCommon(StartDateInd)+days(NumberOfDays-1); % -1 because normally you would take 00:00 of the day after the desired, for having the complete interpolation of the past day.

%% Saving...
ProgressBar.Message = "Saving...";

eval([ShortName,'Interpolated = DataInterpolated;'])
clear('DataInterpolated')
eval([ShortName,'DateInterpolationStarts = DateInterpolationStarts;'])
clear('DateInterpolationStarts')
eval([ShortName,'CumDay = DataDaily;'])
clear('DataDaily')

VariablesInterpolated = {[ShortName,'Interpolated'], [ShortName,'DateInterpolationStarts']};
VariablesDates        = {[ShortName,'DateInterpolationStarts'], 'StartDate', 'EndDate', [ShortName,'CumDay']};

saveswitch([fold_var,sl,ShortName,'Interpolated.mat'], VariablesInterpolated, '-append');
save([fold_var,sl,ShortName,'DateInterpolation.mat'],  VariablesDates{:});

close(ProgressBar)