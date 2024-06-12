function [NewDatesStarts, NewDatesEnds, NewNumDataPerProp] = newdeltarecords(CommDatesStarts, CommDatesEnds, NumDataPerProp, DeltaTime, varargin)

% Function to adjust data of records obtained from readtimesenscell
%   
%   [NewDatesStarts, NewDatesEnds, NewNumDataPerProp] = newdeltarecords(CommDatesStarts, CommDatesEnds, NumDataPerProp, varargin)
%   
%   Dependencies: -
%   
% Outputs:
%   NewDatesStarts : is the datetime array containing common start datetimes
%   between stations, now modified according to the new delta time.
%   
%   NewDatesEnds : is the datetime array containing common end datetimes
%   between stations, now modified according to the new delta time.
%   
%   NewNumDataPerProp : is the cell array containing mxn numeric matrices of 
%   records for each attribute read. m is the number of records, n is the 
%   number of station. Each cell contain a read property (ex: cumulate, 
%   average, min). The number of rows m is now reduced according to delta
%   time.
%   
% Required arguments:
%   - CommDatesStarts : the datetime array containing start datetimes
%   shared between stations.
%   
%   - CommDatesEnds : the datetime array containing end datetimes shared 
%   between stations.
%   
%   - NumDataPerProp : the cellarray containing numeric array with propertiy
%   in each cell. In each array of each cell, the columns correspond to the 
%   stations.
%   
%   - DeltaTime : the duration object to declare the duration to impose to
%   records. If must be greather or equal (just regularization) to the delta 
%   of raw data.
%   
% Optional arguments:
%   - 'AggrMode', string/char/cellstring : is to declare the aggregation mode 
%   in case the DeltaTime is specified. It can be 'sum', 'avg', 'min', or 'max'.
%   This correspond respectively to summing, averaging, minimizing, or maximizing
%   the records in DeltaTime. If no value is specified, the dafault is 'sum' 
%   and it will be effective only in case 'DeltaTime' is specified. In case
%   of multiple columns read from readtimesenscell it must be a string or
%   cellstr array, with the operation to perform for each column!
%   
%   - 'StartDate', datetime : is to declare the desired datetime to use as
%   start of new data. It must be a datetime already present in CommDatesStarts, 
%   otherwise it will be taken the nearest date. If no value is selected,
%   then the first CommDatesStarts is taken.
%   
%   - 'EndDate', datetime : is to declare the desired datetime to use as
%   end of new data. It must be a datetime already present in CommDatesEnds, 
%   otherwise it will be taken the nearest date. If no value is selected,
%   then the nearest date to the last CommDatesEnds is taken.

%% Input check
if not(isdatetime(CommDatesStarts) && isdatetime(CommDatesEnds))
    error(['CommDatesStarts and CommDatesEnds, i.e., the ', ...
           '1st and 2nd inputs, must be datetime arrays!'])
end

if not(isequal(numel(CommDatesStarts), numel(CommDatesEnds)))
    error(['CommDatesStarts and CommDatesEnds, i.e., the ', ...
           '1st and 2nd inputs, must have same sizes!'])
end

if not(iscell(NumDataPerProp))
    error('NumDataPerProp (3rd input) must be a cell array!')
end

if not(all(cellfun(@isnumeric, NumDataPerProp)))
    error('Content of each cell of NumDataPerProp (3rd input) must be numeric!')
end

if not(isscalar(unique(cellfun(@numel, NumDataPerProp))))
    error('Size of each numeric matrix contained in each cell must be the same!')
end

if not(isduration(DeltaTime) && isscalar(DeltaTime))
    error('DeltaTime (4th input) must be a single duration object!')
end

%% Settings
AggMode = repmat({'sum'}, 1, numel(NumDataPerProp)); % Default
StrDate = CommDatesStarts(1); % Default
EndDate = CommDatesEnds(end); % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputAggMode = find(cellfun(@(x) all(strcmpi(x, "aggrmode" )), vararginCp));
    InputStrDate = find(cellfun(@(x) all(strcmpi(x, "startdate")), vararginCp));
    InputEndDate = find(cellfun(@(x) all(strcmpi(x, "enddate"  )), vararginCp));

    if InputAggMode; AggMode = varargin{InputAggMode+1}; end
    if InputStrDate; StrDate = varargin{InputStrDate+1}; end
    if InputEndDate; EndDate = varargin{InputEndDate+1}; end

    varargin([ InputAggMode, InputAggMode+1, ...
               InputStrDate, InputStrDate+1, ...
               InputEndDate, InputEndDate+1 ]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(isstring(AggMode) || iscellstr(AggMode) || ischar(AggMode))
    error('AggrMode must be a char, cellstring, or string!')
end

AggMode = lower(string(AggMode));
if numel(AggMode) ~= numel(NumDataPerProp)
    error('AggrMode must contain an operation for each numeric column read in excel!')
end
for i1 = 1:numel(AggMode)
    if not(any(strcmp(AggMode(i1), {'sum', 'avg', 'min', 'max'})))
        error(['Error in element n. ',num2str(i1),' of AggrMode: ', ...
               'each element must be one between: sum, avg, min, or max!'])
    end
end

if not(isdatetime(StrDate) && isscalar(StrDate))
    error('StartDate must be a single datetime!')
end

if StrDate >= CommDatesStarts(end)
    error(['The StartDate specified is greater or ', ...
           'equal to the last CommDatesStarts (1st input)'])
end

if not(isdatetime(EndDate) && isscalar(EndDate))
    error('EndDate must be a single datetime!')
end

if EndDate <= CommDatesEnds(1)
    error(['The EndDate specified is smaller or ', ...
           'equal to the first CommDatesEnds (2nd input)'])
end

if StrDate > EndDate
    error(['StartDate is greater than EndDate! Please ', ...
           'select an End Date posterior to Start!'])
end

%% Core
DltTimeShft = CommDatesStarts(2) - CommDatesStarts(1);
if DeltaTime < DltTimeShft
    error(['New DeltaTime must be greater than the raw ', ...
           'original delta! Please check your value!'])
elseif DeltaTime == DltTimeShft
    warning(['New DeltaTime is equal to the raw original ', ...
             'delta! The aggregation could be useless.'])
end

Inds2TakeNew = nan(numel(CommDatesStarts), 2); % Of course there will be less than numel(CommDatesStarts) rows! It is just to initialize.
IndEnDlTmTmp = deal(1);
iC = 1;
while (IndEnDlTmTmp < numel(CommDatesStarts)) && (CommDatesEnds(IndEnDlTmTmp) < EndDate)
    if iC == 1
        IndStDlTmTmp = 1; % listdlg2({'Select new start for new DeltaTime:'}, CommDatesStarts, 'OutType','NumInd');
        if not(isempty(StrDate))
            IndStDlTmTmp = find(CommDatesStarts >= StrDate, 1, 'first');
        end
    else
        IndStDlTmTmp = IndEnDlTmTmp + 1;
    end
    IndEnDlTmTmp = find(CommDatesEnds <= (CommDatesStarts(IndStDlTmTmp) + DeltaTime), 1, 'last'); % The last element that is before or equal to end of range!
    Inds2TakeNew(iC, :) = [IndStDlTmTmp, IndEnDlTmTmp];
    iC = iC + 1;
end

Row2Del = all(isnan(Inds2TakeNew), 2);
Inds2TakeNew(Row2Del, :) = [];

if CommDatesEnds(Inds2TakeNew(end)) ~= EndDate
    warning(['Output EndDate will not be the same ', ...
             'of specified or previous EndDate'])
end

if CommDatesStarts(Inds2TakeNew(1)) ~= StrDate
    warning(['Output StartDate will not be the same ', ...
             'of specified or previous StartDate'])
end

NewDatesStarts = (CommDatesStarts(Inds2TakeNew(1)) : DeltaTime : (CommDatesStarts(Inds2TakeNew(1)) + DeltaTime*(size(Inds2TakeNew, 1) - 1)))';
NewDatesEnds   = NewDatesStarts + DeltaTime;

NewNumDataPerProp = cell(size(NumDataPerProp));
for i1 = 1:numel(NumDataPerProp)
    switch AggMode(i1)
        case 'sum'
            TempNumData = arrayfun(@(x,y) sum(NumDataPerProp{i1}(x:y,:), 1), Inds2TakeNew(:, 1), Inds2TakeNew(:, 2), 'UniformOutput',false);

        case 'avg'
            TempNumData = arrayfun(@(x,y) mean(NumDataPerProp{i1}(x:y,:), 1), Inds2TakeNew(:, 1), Inds2TakeNew(:, 2), 'UniformOutput',false);

        case 'min'
            TempNumData = arrayfun(@(x,y) min(NumDataPerProp{i1}(x:y,:), [], 1), Inds2TakeNew(:, 1), Inds2TakeNew(:, 2), 'UniformOutput',false);

        case 'max'
            TempNumData = arrayfun(@(x,y) max(NumDataPerProp{i1}(x:y,:), [], 1), Inds2TakeNew(:, 1), Inds2TakeNew(:, 2), 'UniformOutput',false);

        otherwise
            error(['Internal AggMode variable not ', ...
                   'recognized! Please contact the support.'])
    end

    TempNumData = cat(1, TempNumData{:});
    NewNumDataPerProp{i1} = TempNumData;
end

end