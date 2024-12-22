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
    case 'Temperature'
        GenrlFlnm = 'GeneralTemperature.mat';
        ShortName = 'Temp';
end

sl = filesep;
load([fold_var,sl,GenrlFlnm            ], 'GeneralData','Gauges','RecDatesEndCommon','GenDataProps') % Remember that RainfallDates are referred at the end of your registration period
load([fold_var,sl,'GridCoordinates.mat'], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')

IndPrp2Use = 1;
if not(iscell(GeneralData)); error('Please, update Generaldata (run again Select file(s))'); end
if numel(GeneralData) > 1
    IndPrp2Use = listdlg2({'Property to interpolate (average):'}, GenDataProps, 'OutType','NumInd');
end
GenrlProp = GeneralData{IndPrp2Use};

%% TS options
switch DataRead
    case 'Rainfall'
        InpMinValsEvent = inputdlg2({'Rain threshold [mm/h] for event:', ...
                                     'Min number of hours for events [h]:', ...
                                     'Min num of hours to separate events [h]:', ...
                                     'Max number of hours for an event [h]:'}, ...
                                    'DefInp',{'0.2', '6', '4', '120'});
        MinThresh = str2double(InpMinValsEvent{1});
        MinHours  = str2double(InpMinValsEvent{2});
        MinSepdT  = str2double(InpMinValsEvent{3});
        MaxHours  = str2double(InpMinValsEvent{4});

    case 'Temperature'
        % error('Not yet implemented!!! Please contact the support.')
        if exist([fold_var,sl,'RainEvents.mat'], 'file')
            load([fold_var,sl,'RainEvents.mat'], 'RainRecDatesPerEvent')
        else
            error('First you have to use rainfall! Please retry.')
        end
end

Options = {'linear', 'nearest', 'natural'};
InterpMethod = uiconfirm(Fig, 'What interpolation method do you want to use?', ...
                              'Interpolation methods', 'Options',Options);

%% Elaboration of data and selection of dates
ProgressBar.Message = "Selection od dates...";
[xLongSta, yLatSta] = deal(Gauges{2}(:,1), Gauges{2}(:,2));
dTRecordings        = RecDatesEndCommon(2)-RecDatesEndCommon(1);

switch DataRead
    case 'Rainfall'
        MinColsNumForEvent = hours(MinHours)/dTRecordings;
        MaxColsNumForEvent = hours(MaxHours)/dTRecordings;
        
        if rem(MinColsNumForEvent,1) ~= 0 || rem(MaxColsNumForEvent,1) ~= 0
            error(['You have selected a number of hours < than TimeSensitive discretization or ' ...
                   'the discretization does not allow to full 1 hour! Please check the script.'])
        end
        
        % IndsPossEvents = find(any(GeneralData >  MinThresh, 1)); % At least 1 row should have a rainfall > than min
        NoEventLogic = all(GenrlProp <= MinThresh, 2); % All columns of a row must have a rainfall <= than min to be NO EVENT days
        IndsNoEvents = find(NoEventLogic);
        DiffNoEvents = diff(IndsNoEvents);
        IndsOfStarts = find(DiffNoEvents > 1); % All events not contiguous (separated by at least 1 dTRecorgings)
        RowsOfStarts = IndsNoEvents(IndsOfStarts) + 1; % + 1 because you have to start from the next row after the last non event
        RowsOfEnds   = IndsNoEvents(IndsOfStarts+1) - 1; % - 1 because you have to end in the previous row before the first non event
        if not(NoEventLogic(1)) % If your first element is a possible event, then you have to add it manually
            RowsOfStarts = [1                ; RowsOfStarts];
            RowsOfEnds   = [IndsNoEvents(1)-1; RowsOfEnds  ];
        end
        if not(NoEventLogic(end)) % If your last element is a possible event, then you have to add it manually
            RowsOfStarts(end+1) = IndsNoEvents(end) + 1;
            RowsOfEnds(end+1)   = size(GenrlProp, 1);
        end
        
        RowsRecsPerEventRaw = arrayfun(@(x,y) x:y, RowsOfStarts, RowsOfEnds, 'UniformOutput',false);
        RecDatesPerEventRaw = cellfun(@(x) RecDatesEndCommon(x), RowsRecsPerEventRaw, 'UniformOutput',false);
        DurationPerEventRaw = cellfun(@(x) x(end)-x(1)+dTRecordings, RecDatesPerEventRaw); % +dTRecordings because if you think just at one date, remember that that one is the end of a period that last for dTRecordings
        dTBetweenEvents  = duration(strings(1, length(DurationPerEventRaw)-1));
        for i1 = 1:length(dTBetweenEvents)
            dTBetweenEvents(i1) = RecDatesPerEventRaw{i1+1}(1) - RecDatesPerEventRaw{i1}(end);
        end
        
        IndToMergeSx  = find(dTBetweenEvents < hours(MinSepdT));
        IndToMergeDx  = IndToMergeSx + 1;
        IndToMerge    = unique([IndToMergeSx, IndToMergeDx]);
        IndToNotMerge = 1:length(RowsRecsPerEventRaw);
        IndToNotMerge(ismember(IndToNotMerge, IndToMerge)) = [];
        
        if not(isempty(IndToMerge))
            DiffIndToMerge   = diff(IndToMerge);
            ColToMergeEnds   = [IndToMerge(DiffIndToMerge > 1), IndToMerge(end)];
            ColToMergeStarts = [IndToMerge(1), IndToMerge(find(DiffIndToMerge > 1) + 1)];
            IndToMerge       = arrayfun(@(x,y) x:y, ColToMergeStarts, ColToMergeEnds, 'UniformOutput',false);
        end
        
        IndsEventsNew = [num2cell(IndToNotMerge), IndToMerge];
        
        RowsRecsPerEventReord = cellfun(@(x,y) [RowsRecsPerEventRaw{x}], IndsEventsNew, 'UniformOutput',false);
        RecDatesPerEventReord = cellfun(@(x) cat(1,RecDatesPerEventRaw{x}), IndsEventsNew, 'UniformOutput',false);
        DurationPerEventReord = cellfun(@(x) max(x)-min(x), RecDatesPerEventReord);
        
        EventsToMantain = DurationPerEventReord >= hours(MinHours);
        
        IndsRecsPerEvent = RowsRecsPerEventReord(EventsToMantain);
        IndsRecsPerEvent = cellfun(@(x) min(x) : max(x), IndsRecsPerEvent, 'UniformOutput',false); % To fill holes in datetime
        RecDatesPerEvent = cellfun(@(x) RecDatesEndCommon(x), IndsRecsPerEvent, 'UniformOutput',false);
        DurationPerEvent = cellfun(@(x) x(end)-x(1)+dTRecordings, RecDatesPerEvent);
        
        EventsToReduce = DurationPerEvent > hours(MaxHours);
        if any(EventsToReduce)
            warning('Some events contain more than 120 hours. They will be automatically cutted to 120!')
        
            IndsRecsPerEvent(EventsToReduce) = cellfun(@(x) x(1 : MaxColsNumForEvent), IndsRecsPerEvent(EventsToReduce), 'UniformOutput',false);
            RecDatesPerEvent = cellfun(@(x) RecDatesEndCommon(x), IndsRecsPerEvent, 'UniformOutput',false);
            DurationPerEvent = cellfun(@(x) x(end)-x(1)+dTRecordings, RecDatesPerEvent);
            
            if any(DurationPerEvent > hours(MaxHours))
                error('After cutting events to max 120 hours, something went wrong! Please Check...')
            end
        end

    case 'Temperature'
        IndsRecsPerEvent = cell(size(RainRecDatesPerEvent));
        for i1 = 1:length(IndsRecsPerEvent)
            TempDates = nan(size(RainRecDatesPerEvent{i1}));
            for i2 = 1:length(TempDates)
                TempInd = find(abs(RainRecDatesPerEvent{i1}(i2)-RecDatesEndCommon) < minutes(1));
                if not(isempty(TempInd))
                    TempDates(i2) = TempInd;
                end
            end
            IndsRecsPerEvent{i1} = TempDates;
        end

        RowsWithNoDateMatch = cellfun(@(x) any(isnan(x)), IndsRecsPerEvent);

        IndsRecsPerEvent(RowsWithNoDateMatch) = [];
        RecDatesPerEvent = cellfun(@(x) RecDatesEndCommon(x), IndsRecsPerEvent, 'UniformOutput',false);
        DurationPerEvent = cellfun(@(x) x(end)-x(1), RecDatesPerEvent);
end

%% Elaboration of Trigger and Peak values
switch DataRead
    case 'Rainfall'
        AmountPerEvent  = cellfun(@(x) sum(GenrlProp(x, :), 1),     IndsRecsPerEvent, 'UniformOutput',false);
        MaxPeakPerEvent = cellfun(@(x) max(GenrlProp(x, :), [], 1), IndsRecsPerEvent, 'UniformOutput',false); % Maybe this is not the better one (but the faster). You should first interpolate and then search for max.

    case 'Temperature'
        AmountPerEvent  = cellfun(@(x) mean(GenrlProp(x, :), 1),    IndsRecsPerEvent, 'UniformOutput',false);
        MaxPeakPerEvent = cellfun(@(x) max(GenrlProp(x, :), [], 1), IndsRecsPerEvent, 'UniformOutput',false); % Maybe this is not the better one (but the faster). You should first interpolate and then search for max.
end

ProgressBar.Indeterminate = 'off';
[AmountPerEventInterp, MaxPeakPerEventInterp] = deal(cell(size(AmountPerEvent,2), size(xLongAll,2)));
for i1 = 1:size(AmountPerEvent,2)
    ProgressBar.Value = i1/size(AmountPerEvent,2);
    ProgressBar.Message = strcat("Interpolating event ", string(i1)," of ", string(size(AmountPerEvent,2)));

    CurrAmountInterp  = scatteredInterpolant(xLongSta, yLatSta, AmountPerEvent{i1}',  InterpMethod); 
    CurrMaxPeakInterp = scatteredInterpolant(xLongSta, yLatSta, MaxPeakPerEvent{i1}', InterpMethod);
    for i2 = 1:size(xLongAll,2)
        xLong = xLongAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        yLat  = yLatAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        switch DataRead
            case 'Rainfall'
                TemporaryAmountValues  = max(CurrAmountInterp(xLong,yLat), 0);
                TemporaryMaxPeakValues = max(CurrMaxPeakInterp(xLong,yLat), 0);

            case 'Temperature'
                TemporaryAmountValues  = CurrAmountInterp(xLong,yLat);
                TemporaryMaxPeakValues = CurrMaxPeakInterp(xLong,yLat);
        end
        AmountPerEventInterp{i1,i2}  = sparse(TemporaryAmountValues); % On rows are saved temporal events, in cols you have different raster boxes
        MaxPeakPerEventInterp{i1,i2} = sparse(TemporaryMaxPeakValues); % On rows are saved temporal events, in cols you have different raster boxes
    end      
end
ProgressBar.Indeterminate = 'on';

%% Saving...
ProgressBar.Message = "Saving...";

eval([ShortName,'AmountPerEventInterp = AmountPerEventInterp;'])
clear('AmountPerEventInterp')
eval([ShortName,'MaxPeakPerEventInterp = MaxPeakPerEventInterp;'])
clear('MaxPeakPerEventInterp')
eval([ShortName,'RecDatesPerEvent = RecDatesPerEvent;'])
clear('RecDatesPerEvent')
eval([ShortName,'dTRecordings = dTRecordings;'])

VariablesEvents = {[ShortName,'AmountPerEventInterp'], [ShortName,'MaxPeakPerEventInterp'], ...
                   [ShortName,'RecDatesPerEvent'], [ShortName,'dTRecordings']};

saveswitch([fold_var,sl,ShortName,'Events.mat'], VariablesEvents);