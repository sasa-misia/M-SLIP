function [CommonStarts, CommonEnds, NumDataCell] = adjustrecords(DatesStartsRaw, DatesEndsRaw, NumDataRaw, varargin)

% Function to adjust data of records obtained from readtimesenscell
%   
%   [CommonStarts, CommonEnds, NumDataCell] = adjustrecords(DatesStartsRaw, DatesEndsRaw, NumDataRaw, varargin)
%   
%   Dependencies: newdeltarecords, from M-SLIP toolbox (only if 'DeltaTime' is specified)
%   
% Outputs:
%   CommonStarts : is the datetime array containing common start datetimes
%   between stations
%   
%   CommonEnds : is the datetime array containing common end datetimes
%   between stations
%   
%   NumDataCell : is the cell array containing mxn numeric matrices of records
%   for each attribute read. m is the number of records, n is the number of
%   station. Each cell contain a read property (ex: cumulate, average, min).
%   
% Required arguments:
%   - DatesStartsRaw : the cellarray containing start datetime arrays in each
%   cell. Each cell correspond to a station read from readtimesenscell.
%   
%   - DatesEndsRaw : the cellarray containing end datetime arrays in each
%   cell. Each cell correspond to a station read from readtimesenscell.
%   
%   - NumDataRaw : the cellarray containing numeric array with rec
%   cumulates in each cell. Each cell correspond to a station read from 
%   readtimesenscell. Same length of DatesStartsRaw and DatesEndRaw.
%   
% Optional arguments:
%   - 'OutFormat', string/char : is to declare the type of format to apply
%   on dates. It can be one of the formats recognized from MATLAB with
%   datetimes. If no value is specified, then 'dd/MM/yyyy HH:mm:ss' will be
%   assumed as default.
%   
%   - 'DeltaTime', duration : is to declare the duration to impose to
%   records. If no values is specified, then the duration is the same of
%   raw data.
%   
%   - 'ReplaceVal', numeric : is a matrix nx2 that contain in the first
%   column the value to replace and in the second one the new value to use.
%   
%   - 'AggrMode', string/char/cellstring : is to declare the aggregation mode 
%   in case the DeltaTime is specified. It can be 'sum', 'avg', 'min', or 'max'.
%   This correspond respectively to summing, averaging, minimizing, or maximizing
%   the records in DeltaTime. If no value is specified, the dafault is 'sum' 
%   and it will be effective only in case 'DeltaTime' is specified. In case
%   of multiple columns read from readtimesenscell it must be a string or
%   cellstr array, with the operation to perform for each column!
%   
%   - 'StartDate', datetime : is to declare the desired datetime to use as
%   start of new data. It must be a datetime already present in all the 
%   DatesStartsRaw, otherwise it will be taken the nearest date. If no value 
%   is selected, then the first common DatesStartsRaw is taken. Note: it will 
%   be effective only in case DeltaTime is specified!
%   
%   - 'EndDate', datetime : is to declare the desired datetime to use as
%   end of new data. It must be a datetime already present in all the 
%   DatesEndsRaw, otherwise it will be taken the nearest date. If no value 
%   is selected, then the last common DatesEndsRaw is taken. Note: it will 
%   be effective only in case DeltaTime is specified!

%% Input check
if not(iscell(DatesStartsRaw) && iscell(DatesEndsRaw) && iscell(NumDataRaw))
    error(['DatesStartsRaw, DatesEndsRaw, and NumDataRaw must be cell arrays ', ...
           'containing datetime arrays (first two) and numeric arrays (last)!'])
end

if not(isequal(numel(DatesStartsRaw), numel(DatesEndsRaw), numel(NumDataRaw)))
    error(['DatesStartsRaw, DatesEndsRaw, and ' ...
           'NumDataRaw have different number of cells!'])
end

for i1 = 1:numel(DatesStartsRaw)
    if not(isdatetime(DatesStartsRaw{i1}) && isdatetime(DatesEndsRaw{i1}))
        error(['DatesStartsRaw or DatesEndsRaw does not contain ', ...
               'datetime array in cell n. ',num2str(i1),'! Check it...'])
    end
    if not(isnumeric(NumDataRaw{i1}))
        error(['NumDataRaw does not contain numeric array ', ...
               'in cell n. ',num2str(i1),'! Check it...'])
    end
    if not(isequal(numel(DatesStartsRaw{i1}), numel(DatesEndsRaw{i1}), size(NumDataRaw{i1}, 1)))
        error(['Number of records do not match between DatesStartsRaw, ', ...
               'DatesEndsRaw, and NumDataRaw for cell n. ',num2str(i1),'! Check it...'])
    end
end

%% Settings
OutFrmt = []; % Default
DltTime = []; % Default
ReplVal = []; % Default
AggMode = repmat({'sum'}, 1, size(NumDataRaw{1}, 2)); % Default
StrDate = []; % Default
EndDate = []; % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputOutFrmt = find(cellfun(@(x) all(strcmpi(x, "outformat" )), vararginCp));
    InputDltTime = find(cellfun(@(x) all(strcmpi(x, "deltatime" )), vararginCp));
    InputReplVal = find(cellfun(@(x) all(strcmpi(x, "replaceval")), vararginCp));
    InputAggMode = find(cellfun(@(x) all(strcmpi(x, "aggrmode"  )), vararginCp));
    InputStrDate = find(cellfun(@(x) all(strcmpi(x, "startdate" )), vararginCp));
    InputEndDate = find(cellfun(@(x) all(strcmpi(x, "enddate"   )), vararginCp));

    if InputOutFrmt; OutFrmt = varargin{InputOutFrmt+1}; end
    if InputDltTime; DltTime = varargin{InputDltTime+1}; end
    if InputReplVal; ReplVal = varargin{InputReplVal+1}; end
    if InputAggMode; AggMode = varargin{InputAggMode+1}; end
    if InputStrDate; StrDate = varargin{InputStrDate+1}; end
    if InputEndDate; EndDate = varargin{InputEndDate+1}; end

    varargin([ InputOutFrmt, InputOutFrmt+1, ...
               InputDltTime, InputDltTime+1, ...
               InputReplVal, InputReplVal+1, ...
               InputAggMode, InputAggMode+1, ...
               InputStrDate, InputStrDate+1, ...
               InputEndDate, InputEndDate+1 ]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(iscellstr(OutFrmt) || ischar(OutFrmt) || isstring(OutFrmt) || isempty(OutFrmt))
    error('OutFormat must be a cellstring, char, or string!')
end

if not(isempty(DltTime) || (isduration(DltTime) && isscalar(DltTime)))
    error('DeltaTime must be a single duration object!')
end

if not(isnumeric(ReplVal))
    error('ReplaceVal must be numeric!')
end

if not(isempty(ReplVal) || (size(ReplVal, 2) == 2))
    error('ReplaceVal must contain two columns!')
end

if not(isstring(AggMode) || iscellstr(AggMode) || ischar(AggMode))
    error('AggrMode must be a char, cellstring, or string!')
end

OutFrmt = string(OutFrmt);
if not(isscalar(OutFrmt) || isempty(OutFrmt))
    error('OutFormat must be a single value!')
end

AggMode = lower(string(AggMode));
if numel(AggMode) ~= size(NumDataRaw{1}, 2)
    error('AggrMode must contain an operation for each numeric column read in excel!')
end
for i1 = 1:numel(AggMode)
    if not(any(strcmp(AggMode(i1), {'sum', 'avg', 'min', 'max'})))
        error(['Error in element n. ',num2str(i1),' of AggrMode: ', ...
               'each element must be one between: sum, avg, min, or max!'])
    end
end

if not(isempty(StrDate) || (isdatetime(StrDate) && isscalar(StrDate)))
    error('StartDate must be a single datetime!')
end

if not(isempty(EndDate) || (isdatetime(EndDate) && isscalar(EndDate)))
    error('StartDate must be a single datetime!')
end

%% Core
DltTimeRaw = DatesStartsRaw{1}(2) - DatesStartsRaw{1}(1);
if DltTimeRaw < minutes(59) && DltTimeRaw >= seconds(59)
    ShiftApprox = 'minute';

elseif DltTimeRaw < hours(23) && DltTimeRaw >= minutes(59)
    ShiftApprox = 'hour';

elseif DltTimeRaw >= hours(23) && DltTimeRaw < days(30)
    ShiftApprox = 'day';

else
    error('Time discretization of excel not recognized!')
end

DatesStrtShft = cellfun(@(x) dateshift(x, 'start',ShiftApprox, 'nearest'), DatesStartsRaw, 'UniformOutput',false);
DatesEndShft  = cellfun(@(x) dateshift(x, 'start',ShiftApprox, 'nearest'), DatesEndsRaw  , 'UniformOutput',false);

StartDateCommon = max(cellfun(@min, DatesEndShft)); % Start in end dates
EndDateCommon   = min(cellfun(@max, DatesEndShft)); % End in end dates

IndIntersecated = cellfun(@(x) find(x == StartDateCommon) : find(x == EndDateCommon), DatesEndShft, 'UniformOutput',false);

NumOfCommonRecs = unique(cellfun(@numel, IndIntersecated));

if length(NumOfCommonRecs) > 1
    error('You have a different timing among stations, please check your excel!')
end

DataNotConsidered = cellfun(@(x) length(x) > NumOfCommonRecs, DatesEndShft);
if any(DataNotConsidered)
    warning('Attention! Some stations have more recs than others. Recs outside common dates will be excluded.')
end

CommonStarts = DatesStrtShft{1}(IndIntersecated{1}); % Taking only the firs cell (the others are equal!)
CommonEnds   = DatesEndShft{1}(IndIntersecated{1}); % Taking only the firs cell (the others are equal!)

NumDataCell = cell(1, size(NumDataRaw{1}, 2));
for i1 = 1:numel(NumDataCell)
    NumDataCell{i1} = cell2mat(cellfun(@(x,y) x(y, i1), ...
                                            reshape(NumDataRaw, 1, numel(NumDataRaw)), ...
                                            reshape(IndIntersecated, 1, numel(IndIntersecated)), 'UniformOutput',false));
    if not(isempty(ReplVal))
        for i2 = 1:size(ReplVal, 1)
            NumDataCell{i1}(NumDataCell{i1} == ReplVal(i2, 1)) = ReplVal(i2, 2);
        end
    end
end

if isempty(OutFrmt)
    switch ShiftApprox
        case 'minute'
            CommonStarts.Format = 'dd/MM/yyyy HH:mm:ss';
            CommonEnds.Format   = 'dd/MM/yyyy HH:mm:ss';
    
        case 'hour'
            CommonStarts.Format = 'dd/MM/yyyy HH:mm';
            CommonEnds.Format   = 'dd/MM/yyyy HH:mm';
    
        case 'day'
            CommonStarts.Format = 'dd/MM/yyyy HH';
            CommonEnds.Format   = 'dd/MM/yyyy HH';
    
        otherwise
            error(['Internal ShiftApprox variable not ', ...
                   'recognized. Please contact the support.'])
    end
else
    CommonStarts.Format = OutFrmt;
    CommonEnds.Format   = OutFrmt;
end

if not(isempty(DltTime))
    if isempty(StrDate); StrDate = CommonStarts(1); end
    if isempty(EndDate); EndDate = CommonEnds(end); end
    [CommonStarts, CommonEnds, ...
            NumDataCell] = newdeltarecords(CommonStarts, CommonEnds, ...
                                           NumDataCell, DltTime, 'AggrMode',AggMode, ...
                                                                 'StartDate',StrDate, ...
                                                                 'EndDate',EndDate);
end

end
