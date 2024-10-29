function [IndsRec4Ev, RecsDts4Ev, TimeDur4Ev, IndsCause4Ev] = rainevents(RainData, RecDates, varargin)

% Function to create events starting from daily recordings!
%   
%   [IndsRec4Ev, RecsDts4Ev, TimeDur4Ev, IndsCause4Ev] = rainevents(RainData, RecDates, varargin)
%   
%   Dependencies: -
%   
% Outputs:
%   IndsRec4Ev : is the cell array containing index of RainData and
%   RecDates to take for an event. Each cell represents an event!
%   
%   RecsDts4Ev : is the cell array containing dates for each event, thus
%   each cell represents an event!
%   
%   TimeDur4Ev : is the cell array containing duration for each event, thus
%   each cell represents an event!
%   
%   IndsCause4Ev: is the mxn cell array containing index of RainData and
%   RecDates to take for the cause of each event. Each cell represents the
%   cause of an event over the columns and the days to use as cause over
%   the rows. this meand that m is the number of days to use for cause and
%   n is the number of events (same length of the other 3 inputs).
%   
% Required arguments:
%   - RainData : the numeric matrix nxm, where n is the number of
%   stations and m the number of recordings. It contain rainfall data for
%   each datetime contained in RecDates
%   
%   - RecDates : the datetime array 1xm or mx1, where m is the number 
%   of recordings contained in RainData. It contain datetimes of end
%   record!
%   
% Optional arguments:
%   - 'MinThreshold', numeric : is to declare the threshold to apply [mm/day], 
%   above which a day could take part of a rainfall event. If rainfall amount 
%   in a day is less than the threshold it will be ignored! If no value is
%   specified, then 5 mm/day will be take as default.
%   
%   - 'MinDays', numeric : is to declare the minimum number of days, above 
%   which a rainfall event is defined. If there are less than minimum days,
%   those days will be removed and not considered as rainfall event! If no 
%   value is specified, then 1 day will be take as default.
%   
%   - 'MaxDays', numeric : is to declare the maximum number of days, above 
%   which the other days and relative rainfall amounts will be excluded. If 
%   there are more than maximum days in an event, then all the days after
%   this value will be eliminated and not taken into account (to avoid
%   excessive amounts of rainfall). If no value is specified, then 9999 days 
%   will be take as default (equivalent to not taking it).
%   
%   - 'MinSeparation', numeric : is to declare the minimum number of days 
%   that separate events. If 2 events are separated by a smaller number of
%   days, then they will be merged on the same event! If no value is specified, 
%   then 1 day will be take as default.
%   
%   - 'CauseDays', numeric : is to declare the maximum number of days to
%   use for the cause of each event. If no value is specified, then 30 days
%   will be assumed as default. Note: it can be also an array, if you want
%   multiple possibility of days to use.

%% Input check
if not(isnumeric(RainData))
    error('RainData (1st input) must be a numeric matrix!')
end

if not(isdatetime(RecDates) && isvector(RecDates))
    error('RecDates (2nd input) must be a 1xm or mx1 datetime array!')
end

if not(any(size(RainData) == numel(RecDates)))
    error(['RainData and RecDates must ', ...
           'have a size in common (number of recordings)'])
end

if find(size(RainData) == numel(RecDates), 1) == 1
    RainData = RainData'; % Transposing matrix in case is vertical!
end

dTRecs = RecDates(2)-RecDates(1);
if dTRecs ~= hours(24)
    error('RecDates must be given with a 24h interval!')
end

%% Settings
MinThrs = 5;  % Default minimum threshold to define a possible day of event
MinDays = 1;  % Default minimum days over threshold
MaxDays = 10; % Default maximum days over threshold
MinSpdT = 1;  % Default minimum separation days between events
CseDays = 30; % Default maximum number of days for cause quantities

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputMinThrs = find(cellfun(@(x) all(strcmpi(x, "minthreshold" )), vararginCp));
    InputMinDays = find(cellfun(@(x) all(strcmpi(x, "mindays"      )), vararginCp));
    InputMaxDays = find(cellfun(@(x) all(strcmpi(x, "maxdays"      )), vararginCp));
    InputMinSpdT = find(cellfun(@(x) all(strcmpi(x, "minseparation")), vararginCp));
    InputCseDays = find(cellfun(@(x) all(strcmpi(x, "causedays"    )), vararginCp));

    if InputMinThrs; MinThrs = varargin{InputMinThrs+1}; end
    if InputMinDays; MinDays = varargin{InputMinDays+1}; end
    if InputMaxDays; MaxDays = varargin{InputMaxDays+1}; end
    if InputMinSpdT; MinSpdT = varargin{InputMinSpdT+1}; end
    if InputCseDays; CseDays = varargin{InputCseDays+1}; end

    varargin([ InputMinThrs, InputMinThrs+1, ...
               InputMinDays, InputMinDays+1, ...
               InputMaxDays, InputMaxDays+1, ...
               InputMinSpdT, InputMinSpdT+1, ...
               InputCseDays, InputCseDays+1 ]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(isnumeric(MinThrs) && isscalar(MinThrs))
    error('MinThreshold must be a scalar and numeric value!')
end

if not(isnumeric(MinDays) && isscalar(MinDays))
    error('MinDays must be a scalar and numeric value!')
end

if not(isnumeric(MaxDays) && isscalar(MaxDays))
    error('MaxDays must be a scalar and numeric value!')
end

if not(isnumeric(MinSpdT) && isscalar(MinSpdT))
    error('MinSeparation must be a scalar and numeric value!')
end

if not((isnumeric(CseDays) || isduration(CseDays)) && (isscalar(CseDays) || isvector(CseDays)))
    error('CauseDays must be numeric or duration, array or scalar structure!')
end

if isvector(CseDays)
    CseDays = reshape(CseDays, [numel(CseDays), 1]);
end

if isnumeric(CseDays)
    CseDays = days(CseDays);
end

%% Core
MinEls4Ev = days(MinDays)/dTRecs;
MaxEls4Ev = days(MaxDays)/dTRecs;

if rem(MinEls4Ev,1) ~= 0 || rem(MaxEls4Ev,1) ~= 0
    error(['You have selected a number of hours < than RecDates discretization or ' ...
           'the discretization does not allow to full 24 hours! Please check the script.'])
end

NoEvsLog = all(RainData <= MinThrs, 1); % All rows should have a rainfall <= than min to be NO EVENT days
NoEvsInd = find(NoEvsLog);
NoEvsDff = diff(NoEvsInd);
EvsBreak = find(NoEvsDff > 1); % Not contiguous events (separated by at least 1 dTRecorgings)
EvsStInd = NoEvsInd(EvsBreak) + 1; % + 1 because you have to start from the next element after the last non event
EvsEnInd = NoEvsInd(EvsBreak+1) - 1; % - 1 because you have to end in the previous element before the first non event
if not(NoEvsLog(1)) % If your first element is a possible event, then you have to add it manually
    EvsStInd = [1            , EvsStInd];
    EvsEnInd = [NoEvsInd(1)-1, EvsEnInd];
end
if not(NoEvsLog(end)) % If your last element is a possible event, then you have to add it manually
    EvsStInd(end+1) = NoEvsInd(end) + 1;
    EvsEnInd(end+1) = size(RainData, 2);
end

IndsRec4EvRaw = arrayfun(@(x,y) x:y, EvsStInd, EvsEnInd, 'UniformOutput',false);
RecsDts4EvRaw = cellfun(@(x) RecDates(x), IndsRec4EvRaw, 'UniformOutput',false);
TimeDur4EvRaw = cellfun(@(x) x(end)-x(1)+dTRecs, RecsDts4EvRaw);

dTBetEvs = hours(zeros(1, numel(TimeDur4EvRaw)-1)); % -1 because if you have n events, the intervals between them are n-1!
for i1 = 1:length(dTBetEvs)
    dTBetEvs(i1) = RecsDts4EvRaw{i1+1}(1) - RecsDts4EvRaw{i1}(end);
end

Ind2MrgSx = find(dTBetEvs < days(MinSpdT));
Ind2MrgDx = Ind2MrgSx + 1;
Ind2MrgUn = unique([Ind2MrgSx, Ind2MrgDx]);
Ind2NtMrg = 1:length(IndsRec4EvRaw);
Ind2NtMrg(ismember(Ind2NtMrg, Ind2MrgUn)) = [];

if not(isempty(Ind2MrgUn)) % It will be also converted to a cell!
    DffIn2Mrg = diff(Ind2MrgUn);
    Ind2MrgEn = [Ind2MrgUn(DffIn2Mrg > 1), Ind2MrgUn(end)];
    Ind2MrgSt = [Ind2MrgUn(1), Ind2MrgUn(find(DffIn2Mrg > 1) + 1)];
    Ind2MrgUn = arrayfun(@(x,y) x:y, Ind2MrgSt, Ind2MrgEn, 'UniformOutput',false);
end

IndEvsNew     = [num2cell(Ind2NtMrg), Ind2MrgUn];
IndsRec4EvRrd = cellfun(@(x,y) [IndsRec4EvRaw{x}], IndEvsNew, 'UniformOutput',false);
RecsDts4EvRrd = cellfun(@(x) cat(1,RecsDts4EvRaw{x}), IndEvsNew, 'UniformOutput',false);
TimeDur4EvRrd = cellfun(@(x) max(x)-min(x)+dTRecs, RecsDts4EvRrd);

Evs2Mant = TimeDur4EvRrd >= days(MinDays);

IndsRec4Ev = IndsRec4EvRrd(Evs2Mant);
IndsRec4Ev = cellfun(@(x) min(x) : max(x), IndsRec4Ev, 'UniformOutput',false); % To fill holes in datetime
RecsDts4Ev = cellfun(@(x) RecDates(x), IndsRec4Ev, 'UniformOutput',false);
TimeDur4Ev = cellfun(@(x) x(end)-x(1)+dTRecs, RecsDts4Ev);

EventsToReduce = days(TimeDur4Ev) > MaxDays;
if any(EventsToReduce)
    warning(['Some events (',num2str(sum(EventsToReduce)),') contain more than your max days. They will be automatically cutted to max days!'])

    IndsRec4Ev(EventsToReduce) = cellfun(@(x) x(1 : MaxEls4Ev), IndsRec4Ev(EventsToReduce), 'UniformOutput',false);
    RecsDts4Ev = cellfun(@(x) RecDates(x), IndsRec4Ev, 'UniformOutput',false);
    TimeDur4Ev = cellfun(@(x) x(end)-x(1)+dTRecs, RecsDts4Ev);
    
    if any(days(TimeDur4Ev) > MaxDays)
        error('After cutting events to max days, something went wrong! Please Check...')
    end
end

StrDts4Ev = reshape(cellfun(@min, RecsDts4Ev), [1, numel(RecsDts4Ev)]);

StrCseDts4Ev = StrDts4Ev - CseDays + dTRecs;
EndCseDts4Ev = repmat(StrDts4Ev, numel(CseDays), 1);

[IndCseStr4Ev, IndCseEnd4Ev] = deal(nan(size(StrCseDts4Ev)));
for i1 = 1:size(StrDts4Ev, 2)
    IndStrTmp = arrayfun(@(x) find(abs(x-RecDates) < dTRecs, 1), StrCseDts4Ev(:,i1), 'UniformOutput',false);
    EmptyCell = cellfun(@isempty, IndStrTmp);
    NtEmpCell = not(EmptyCell);

    if any(EmptyCell)
        warning(['Event n. ',num2str(i1),' has not enough ', ...
                 'data to detect correct start in cause days'])
    end

    IndCseStr4Ev(NtEmpCell, i1) = [IndStrTmp{NtEmpCell}];
    IndCseStr4Ev(EmptyCell, i1) = 1;
    IndCseEnd4Ev(:        , i1) = find(abs(EndCseDts4Ev(1,i1)-RecDates) < dTRecs, 1, 'last');
end

IndsCause4Ev = arrayfun(@(x,y) x:y, IndCseStr4Ev, IndCseEnd4Ev, 'UniformOutput',false);

end