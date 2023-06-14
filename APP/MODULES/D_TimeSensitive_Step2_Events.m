% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
ProgressBar.Message = "Loading data...";
Options = {'Rainfall', 'Temperature'};
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

%% TS options
switch DataRead
    case 'Rainfall'
        InpMinValsEvent = inputdlg({"Set the threshold [mm/h] above which you have an event : ", ...
                                    "Set the minimum number of hours to define events [h] : " ...
                                    "Set the minimum number of hours to separate events [h] : " ...
                                    "Set the maximum number of hours for an event [h] : "}, ...
                                    '', 1, {'0.2', '6', '4', '120'});
        MinThresh = str2double(InpMinValsEvent{1});
        MinHours  = str2double(InpMinValsEvent{2});
        MinSepdT  = str2double(InpMinValsEvent{3});
        MaxHours  = str2double(InpMinValsEvent{4});

        drawnow % Remember to remove if in Standalone version
        figure(Fig) % Remember to remove if in Standalone version

    case 'Temperature'
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
        NoEventLogic = all(GeneralData <= MinThresh, 1); % All rows should have a rainfall <= than min to be NO EVENT days
        IndsNoEvents = find(NoEventLogic);
        DiffNoEvents = diff(IndsNoEvents);
        IndsOfStarts = find(DiffNoEvents > 1); % All events not contiguous (separated by at least 1 dTRecorgings)
        ColsOfStarts = IndsNoEvents(IndsOfStarts) + 1; % + 1 because you have to start from the next row after the last non event
        ColsOfEnds   = IndsNoEvents(IndsOfStarts+1) - 1; % - 1 because you have to end in the previous row before the first non event
        if not(NoEventLogic(1)) % If your first element is a possible event, then you have to add it manually
            ColsOfStarts = [1                , ColsOfStarts];
            ColsOfEnds   = [IndsNoEvents(1)-1, ColsOfEnds  ];
        end
        if not(NoEventLogic(end)) % If your last element is a possible event, then you have to add it manually
            ColsOfStarts(end+1) = IndsNoEvents(end) + 1;
            ColsOfEnds(end+1)   = size(GeneralData,2);
        end
        
        ColsRecsPerEventRaw = arrayfun(@(x,y) x:y, ColsOfStarts, ColsOfEnds, 'UniformOutput',false);
        RecDatesPerEventRaw = cellfun(@(x) RecDatesEndCommon(x), ColsRecsPerEventRaw, 'UniformOutput',false);
        DurationPerEventRaw = cellfun(@(x) x(end)-x(1), RecDatesPerEventRaw);
        dTBetweenEvents  = duration(strings(1, length(DurationPerEventRaw)-1));
        for i1 = 1:length(dTBetweenEvents)
            dTBetweenEvents(i1) = RecDatesPerEventRaw{i1+1}(1) - RecDatesPerEventRaw{i1}(end);
        end
        
        IndToMergeSx  = find(dTBetweenEvents < hours(MinSepdT));
        IndToMergeDx  = IndToMergeSx + 1;
        IndToMerge    = unique([IndToMergeSx, IndToMergeDx]);
        IndToNotMerge = 1:length(ColsRecsPerEventRaw);
        IndToNotMerge(ismember(IndToNotMerge, IndToMerge)) = [];
        
        DiffIndToMerge   = diff(IndToMerge);
        ColToMergeEnds   = [IndToMerge(DiffIndToMerge > 1), IndToMerge(end)];
        ColToMergeStarts = [IndToMerge(1), IndToMerge(find(DiffIndToMerge > 1) + 1)];
        IndToMerge       = arrayfun(@(x,y) x:y, ColToMergeStarts, ColToMergeEnds, 'UniformOutput',false);
        
        IndsEventsNew = [num2cell(IndToNotMerge), IndToMerge];
        
        ColsRecsPerEventReord = cellfun(@(x,y) [ColsRecsPerEventRaw{x}], IndsEventsNew, 'UniformOutput',false);
        RecDatesPerEventReord = cellfun(@(x) cat(1,RecDatesPerEventRaw{x}), IndsEventsNew, 'UniformOutput',false);
        DurationPerEventReord = cellfun(@(x) max(x)-min(x), RecDatesPerEventReord);
        
        EventsToMantain = DurationPerEventReord >= hours(MinHours);
        
        ColsRecsPerEvent = ColsRecsPerEventReord(EventsToMantain);
        ColsRecsPerEvent = cellfun(@(x) min(x) : max(x), ColsRecsPerEvent, 'UniformOutput',false); % To fill holes in datetime
        RecDatesPerEvent = cellfun(@(x) RecDatesEndCommon(x), ColsRecsPerEvent, 'UniformOutput',false);
        DurationPerEvent = cellfun(@(x) x(end)-x(1), RecDatesPerEvent);
        
        EventsToReduce = DurationPerEvent > MaxHours;
        if any(EventsToReduce)
            warning('Some events contain more than 120 hours. They will be automatically cutted to 120!')
        
            ColsRecsPerEvent(EventsToReduce) = cellfun(@(x) x(1 : MaxColsNumForEvent+1), ColsRecsPerEvent(EventsToReduce), 'UniformOutput',false);
            RecDatesPerEvent = cellfun(@(x) RecDatesEndCommon(x), ColsRecsPerEvent, 'UniformOutput',false);
            DurationPerEvent = cellfun(@(x) x(end)-x(1), RecDatesPerEvent);
            
            if any(DurationPerEvent > MaxHours)
                error('After cutting events to max 120 hours, something went wrong! Please Check...')
            end
        end

    case 'Temperature'
        ColsRecsPerEvent = cell(size(RainRecDatesPerEvent));
        for i1 = 1:length(ColsRecsPerEvent)
            TempDates = nan(size(RainRecDatesPerEvent{i1}));
            for i2 = 1:length(TempDates)
                TempInd = find(abs(RainRecDatesPerEvent{i1}(i2)-RecDatesEndCommon) < minutes(1));
                if not(isempty(TempInd))
                    TempDates(i2) = TempInd;
                end
            end
            ColsRecsPerEvent{i1} = TempDates;
        end

        ColsWithNoDateMatch = cellfun(@(x) any(isnan(x)), ColsRecsPerEvent);

        ColsRecsPerEvent(ColsWithNoDateMatch) = [];
        RecDatesPerEvent = cellfun(@(x) RecDatesEndCommon(x), ColsRecsPerEvent, 'UniformOutput',false);
        DurationPerEvent = cellfun(@(x) x(end)-x(1), RecDatesPerEvent);
end

%% Elaboration of Trigger and Peak values
switch DataRead
    case 'Rainfall'
        AmountPerEvent  = cellfun(@(x) sum(GeneralData(:, x), 2),     ColsRecsPerEvent, 'UniformOutput',false);
        MaxPeakPerEvent = cellfun(@(x) max(GeneralData(:, x), [], 2), ColsRecsPerEvent, 'UniformOutput',false); % Maybe this is not the better one (but the faster). You should first interpolate and then search for max.

    case 'Temperature'
        AmountPerEvent  = cellfun(@(x) mean(GeneralData(:, x), 2),    ColsRecsPerEvent, 'UniformOutput',false);
        MaxPeakPerEvent = cellfun(@(x) max(GeneralData(:, x), [], 2), ColsRecsPerEvent, 'UniformOutput',false); % Maybe this is not the better one (but the faster). You should first interpolate and then search for max.
end

ProgressBar.Indeterminate = 'off';
[AmountPerEventInterp, MaxPeakPerEventInterp] = deal(cell(size(AmountPerEvent,2), size(xLongAll,2)));
for i1 = 1:size(AmountPerEvent,2)
    ProgressBar.Value = i1/size(AmountPerEvent,2);
    ProgressBar.Message = strcat("Interpolating event ", string(i1)," of ", string(size(AmountPerEvent,2)));

    CurrAmountInterp  = scatteredInterpolant(xLongSta, yLatSta, AmountPerEvent{i1},  InterpMethod); 
    CurrMaxPeakInterp = scatteredInterpolant(xLongSta, yLatSta, MaxPeakPerEvent{i1}, InterpMethod);
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
cd(fold_var)
eval([ShortName,'AmountPerEventInterp = AmountPerEventInterp;'])
% clear('AmountPerEventInterp')
eval([ShortName,'MaxPeakPerEventInterp = MaxPeakPerEventInterp;'])
% clear('MaxPeakPerEventInterp')
eval([ShortName,'RecDatesPerEvent = RecDatesPerEvent;'])
% clear('RecDatesPerEvent')
eval([ShortName,'dTRecordings = dTRecordings;'])

VariablesEvents = {[ShortName,'AmountPerEventInterp'], [ShortName,'MaxPeakPerEventInterp'], ...
                   [ShortName,'RecDatesPerEvent'], [ShortName,'dTRecordings']};

save([ShortName,'Events.mat'], VariablesEvents{:}, '-v7.3');
cd(fold0)

close(ProgressBar)