if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Cancelable','off', 'Message','Reading files...');
drawnow

%% Loading data
ProgressBar.Message = "Loading data...";
Options  = {'Rainfall', 'Temperature'};
DataRead = uiconfirm(Fig, 'What type of data do you want to read?', ...
                          'Reading Data', 'Options',Options, 'DefaultOption',1);
switch DataRead
    case 'Rainfall'
        GenrlFlnm = 'GeneralRainfall.mat';
        ShortName = 'Rain';
        AggrgMode = 'sum';
        
    case 'Temperature'
        GenrlFlnm = 'GeneralTemperature.mat';
        ShortName = 'Temp';
        AggrgMode = char(listdlg2({'Operation for aggregation:'}, {'avg','min','max'}));
end

load([fold_var,sl,GenrlFlnm            ], 'GeneralData','GenDataProps','Gauges','RecDatesEndCommon') % Remember that RainfallDates are referred at the end of your registration period
load([fold_var,sl,'GridCoordinates.mat'], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')

IndPrp2Use = 1;
if not(iscell(GeneralData)); error('Please, update Generaldata (run again Select file(s))'); end
if numel(GeneralData) > 1
    IndPrp2Use = listdlg2({'Property to interpolate:'}, GenDataProps, 'OutType','NumInd');
end

%% Elaboration of data and selection of dates
ProgressBar.Message = "Selection of dates...";
[xLongSta, yLatSta] = deal(Gauges{2}(:,1), Gauges{2}(:,2));

EndDateInd   = listdlg2({'Last date to interpolate (suggested hour is 00:00):'}, ...
                        RecDatesEndCommon, 'OutType','NumInd');
MaxDaysPoss  = caldays(between(RecDatesEndCommon(1), RecDatesEndCommon(EndDateInd), 'days'));
NumberOfDays = str2double(inputdlg2({['Days to consider? (Max possible: ', ...
                                      num2str(MaxDaysPoss)]}, 'DefInp',{num2str(MaxDaysPoss)}));

if (NumberOfDays > MaxDaysPoss) || (NumberOfDays <= 0)
    error(strcat('You have to specify a number that go from 1 to ',num2str(MaxDaysPoss)))
end

dTRecsOrg = RecDatesEndCommon(2) - RecDatesEndCommon(1);
EndDate   = RecDatesEndCommon(EndDateInd);
StartDate = RecDatesEndCommon(EndDateInd) - days(NumberOfDays);
EndDtsCmm = RecDatesEndCommon;
StrDtsCmm = RecDatesEndCommon - dTRecsOrg;
GenrlProp = GeneralData(IndPrp2Use);

%% Interpolation
ProgressBar.Message = "Interpolation...";
[StrDtsCmm1d, EndDtsCmm1d, ...
        GenrlProp1d] = newdeltarecords(StrDtsCmm, EndDtsCmm, ...
                                       GenrlProp, hours(24), 'AggrMode',AggrgMode, ...
                                                             'StartDate',StartDate, ...
                                                             'EndDate',EndDate);
if numel(GenrlProp1d) > 1
    error(['Property to interpolate is not single after ', ...
           'apply the new delta, please contact the support!'])
end

DataDaily = GenrlProp1d{:};
DateInterpolationStarts = StrDtsCmm1d;

Options = {'linear', 'nearest', 'natural'};
InterpMethod = uiconfirm(Fig, 'What interpolation method do you want to use?', ...
                              'Interpolation methods', 'Options',Options);
ProgressBar.Indeterminate = 'off';
DataInterpolated = cell(size(DataDaily,1), size(xLongAll,2));
for i1 = 1:size(DataDaily,1)
    ProgressBar.Value = i1/size(DataDaily,1);
    ProgressBar.Message = strcat("Interpolating day ", string(i1)," of ", string(size(DataDaily,1)));

    CurrInterpolation = scatteredInterpolant(xLongSta, yLatSta, DataDaily(i1,:)', InterpMethod); 
    for i2 = 1:size(xLongAll,2)
        xLong = xLongAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        yLat  = yLatAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        switch DataRead
            case 'Rainfall'
                TempValues = max(CurrInterpolation(xLong,yLat), 0); % Rain has a bottom limit: 0 mm!
            case 'Temperature'
                TempValues = CurrInterpolation(xLong,yLat);
        end
        DataInterpolated{i1,i2} = sparse(TempValues); % On rows are saved temporal events of the same raster box
    end      
end
ProgressBar.Indeterminate = 'on';

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