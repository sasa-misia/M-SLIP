function [datesStart, datesEnd, numericData, gauges] = readtimesenscell(file2Read, varargin)

% Function to read georaster values, reference object and info.
%   
%   [DatesStart, DatesEnd, NumericData, Gauges] = readtimesenscell(FileToRead, varargin)
%   
%   Dependencies: checkbox2 and listdlg2 from M-SLIP toolbox (only if missing values)
%   
% Outputs:
%   DatesStart : is the cell array containing start datetime arrays for
%   each station detected
%   
%   DatesEnd : is the cell array containing end datetime arrays for each 
%   station detected
%   
%   NumericData : is the cell array containing numeric matrices of records
%   for each station detected
%   
%   Gauges : is the cell array containing the names of the stations in the
%   first column and the coordinates on the second.
%   
% Required arguments:
%   - FileToRead : the fullname of the file to be read! It can be also
%   just name.ext but in this case your current working directory must
%   be the one where the file is stored.
%   
% Optional arguments:
%   - 'StationSheet', string/char : is to declare the name of the excel
%   sheet where the stations are reported. If no value is specified, then 
%   'Stations table' will be assumed as default!
%   
%   - 'DataSheet', string/char : is to declare the name of the excel sheet 
%   where the data is reported. If no value is specified, then 'Data table'
%   will be assumed as default!
%   
%   - 'AutoFill', string/char : is to decide what type of auto fill do you
%   want to use in case of missing numeric data. It can be one of the
%   following options: 'Zeros', 'AverageYr', 'AverageLNE', 'OtherSta', or 
%   'NaN'. Zeros: 0 values where cells are empty. AverageYr: average value 
%   over the years. AverageLNE: average value between the Last Not Empty cells. 
%   OtherSta: it will pick the average value of the stations that contain 
%   that missing value. NaN: NaNs values in empty cells. In case no value is 
%   specified, then 'NaN' will be assumed as default!
%   
%   - 'StatsCol', numeric : is a 1x3 or 3x1 num array to define which 
%   columns contain the names of the stations, the longitude, and the 
%   latitude (it is relative to the first column not empty, ex: if column 
%   A of excel is empty and column B is the effective start, you should 
%   specify [1, 7, 8], if you want columns [B, H, I] of excel, because 
%   the count starts from column B of excel). If no value is specified, 
%   then a prompt will ask you for this info!
%   
%   - 'StatsFilt', logical : is to define if you want to filter the read
%   stations. In case is set to true, a prompt will ask you what stations
%   do you want to mantain. In case nothing is specified, then false will
%   be take as default!

%% Input check
if not(ischar(file2Read) || isstring(file2Read) || iscellstr(file2Read))
    error('FileToRead (1st input) must be a char or a string!')
end

file2Read = string(file2Read); % To have consistency!

SuppFiles = {'.xlsx'};
[~, ~, BaseExt] = fileparts(file2Read);
if not(any(strcmpi(BaseExt, SuppFiles)))
    error(['File of type "',char(BaseExt),'" not supported. Please make ' ...
           'shure your extension is: ',char(join(SuppFiles, '; ')),'!'])
end

if numel(file2Read) > 1
    error(['You specified more than one file to read! Please ' ...
           'open a for cycle that call this function instead.'])
end

%% Settings
StaSheet = 'Stations table'; % Default
DatSheet = 'Data table';     % Default
AutoFill = "nan";            % Default
StatsCol = [];               % Default
StatFilt = false;            % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputStaSheet = find(cellfun(@(x) all(strcmpi(x, "stationsheet")), vararginCp));
    InputDatSheet = find(cellfun(@(x) all(strcmpi(x, "datasheet"   )), vararginCp));
    InputAutoFill = find(cellfun(@(x) all(strcmpi(x, "autofill"    )), vararginCp));
    InputStatsCol = find(cellfun(@(x) all(strcmpi(x, "statscol"    )), vararginCp));
    InputStatFilt = find(cellfun(@(x) all(strcmpi(x, "statsfilt"   )), vararginCp));

    if InputStaSheet; StaSheet = varargin{InputStaSheet+1  }; end
    if InputDatSheet; DatSheet = varargin{InputDatSheet+1  }; end
    if InputAutoFill; AutoFill = vararginCp{InputAutoFill+1}; end
    if InputStatsCol; StatsCol = varargin{InputStatsCol+1  }; end
    if InputStatFilt; StatFilt = varargin{InputStatFilt+1  }; end

    varargin([ InputStaSheet, InputStaSheet+1, ...
               InputDatSheet, InputDatSheet+1, ...
               InputAutoFill, InputAutoFill+1, ...
               InputStatsCol, InputStatsCol+1, ...
               InputStatFilt, InputStatFilt+1 ]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(iscellstr(StaSheet) || ischar(StaSheet) || isstring(StaSheet))
    error('StationsSheet must be a string or char value!')
end

if not(iscellstr(DatSheet) || ischar(DatSheet) || isstring(DatSheet))
    error('DataSheet must be a string or char value!')
end

if not(any(strcmp(AutoFill, {'nan', 'averageyr', 'averagelne', 'zeros', 'othersta'})))
    error(['AutoFill must be one of the following: NaN, ', ...
           'AverageYr, AverageLNE, Zeros, or OtherSta!'])
end

if not(isnumeric(StatsCol) && (numel(StatsCol) == 3 || numel(StatsCol) == 0))
    error('StatsCol must be a numeric 1x3 or 3x1 array!')
end

if not(islogical(StatFilt) && isscalar(StatFilt))
    error('StatsFilt must be a single logical value!')
end

StaSheet = string(StaSheet);
DatSheet = string(DatSheet);

if numel(StaSheet) ~= 1
    error('StationsSheet must be a single value!')
end
if numel(DatSheet) ~= 1
    error('DataSheet must be a single value!')
end

%% Core
%%% Reading and reordering %%%
SheetStatRaw = readcell(file2Read, 'Sheet',StaSheet); % REMEMBER: in this sheet stations should have the same order of Data sheet!
SheetDataRaw = readcell(file2Read, 'Sheet',DatSheet);

% Reordering of stations (according to Data sheet!)
HdStsRow = find(sum(cellfun(@(x) ischar(x) || isstring(x), SheetStatRaw), 2) >= 3, 1); % The header row is the first row that ccontains at least 3 titles (station, long, lat)!
if isempty(StatsCol)
    StatsCol = listdlg2({'Column with station names:', 'Column with longitudes:', ...
                         'Column with latitudes:'}, cellstr(SheetStatRaw(HdStsRow, :)), 'OutType','NumInd');
end
SheetStatCnt = SheetStatRaw;
SheetStatCnt(HdStsRow, :) = [];
StatRowInds = sum(cellfun(@(x) all(isnumeric(x)), SheetStatCnt), 2) >= 2; % Rows that contain a station must have at least 2 numeric cells with coordinates!
StationsRaw = string(SheetStatCnt(StatRowInds, StatsCol(1)));

IndStrPartDataSheet = cellfun(@(x) any(strcmp(class(x), {'char','string'})), SheetDataRaw);
StringPartDataSheet = strings(size(SheetDataRaw));
StringPartDataSheet(IndStrPartDataSheet) = string(SheetDataRaw(IndStrPartDataSheet));
StringPartDataSheet = join(StringPartDataSheet);
StringPartDataSheet(arrayfun(@(x) all(isspace(x)), StringPartDataSheet)) = [];

IndStaInDataSheet = zeros(size(StationsRaw));
for i1 = 1:length(StationsRaw)
    TmpIndMatch = find(contains(StringPartDataSheet, StationsRaw(i1), 'IgnoreCase',true));
    if isscalar(TmpIndMatch)
        IndStaInDataSheet(i1) = TmpIndMatch;
    elseif isempty(TmpIndMatch)
        error(['Station ',char(StationsRaw(i1)),' not found in tour data table!'])
    else
        CorrSta = listdlg2(['Which is ',char(StationsRaw(i1)),'?'], StringPartDataSheet(TmpIndMatch));
        IndStaInDataSheet(i1) = find(strcmp(StringPartDataSheet, CorrSta));
    end
end

if any(IndStaInDataSheet == 0)
    StatsNotReco = char(join(StationsRaw(IndStaInDataSheet == 0), '; '));
    error(['Some stations in your Station Sheet were not recognized ', ...
           'in your Data Sheet: ',StatsNotReco,'! Please check your ', ...
           'Data Sheet or change station column.'])
end

[~, CorrectStaOrd] = sort(IndStaInDataSheet);

% Stations ordering
SheetStatOrd = SheetStatCnt(CorrectStaOrd, :);

if not(all(cellfun(@isnumeric, SheetStatOrd(:, StatsCol(2)))))
    error('Column of longitude does not contain only numbers!')
end

if not(all(cellfun(@isnumeric, SheetStatOrd(:, StatsCol(3)))))
    error('Column of latitude does not contain only numbers!')
end

Stations   = string(SheetStatOrd(:,1));
xLongSta   = [SheetStatOrd{:, StatsCol(2)}]';
yLatSta    = [SheetStatOrd{:, StatsCol(3)}]';
CrdsGauges = [xLongSta, yLatSta];
gauges     = {Stations, CrdsGauges};

SheetStatCnt(cellfun(@(x) all(ismissing(x)), SheetStatCnt)) = {''}; % To convert ismissing object into empty char (otherwise isequal will not work)
SheetStatOrd(cellfun(@(x) all(ismissing(x)), SheetStatOrd)) = {''}; % To convert ismissing object into empty char (otherwise isequal will not work)

if not(isequal(SheetStatCnt, SheetStatOrd))
    warning(['Station table sheet in excel was automatically reordered ', ...
             'because did not match order in Data table sheet. ', ...
             'Please analyze it and avoid automatic reordering!'])
end

%%% Stations filtering %%%
if StatFilt
    IndsStaFilt = checkbox2(Stations, 'Title',{'Stations to consider:'}, 'OutType','NumInd');

    if isempty(IndsStaFilt); error('You must select at least one temperature station!'); end

    SheetStatOrd = SheetStatOrd(IndsStaFilt, :);

    Stations   = Stations(IndsStaFilt,:);
    xLongSta   = [SheetStatOrd{:, StatsCol(2)}]';
    yLatSta    = [SheetStatOrd{:, StatsCol(3)}]';
    CrdsGauges = [xLongSta, yLatSta];
    gauges     = {Stations, CrdsGauges};
end

%%% Check for consistency in excel %%%
Not2DtPerRow = find(not(sum(cellfun(@(x) all(isdatetime(x)), SheetDataRaw), 2) >= 2)); % Find where there are less than 2 datetime in a row (not a record or error)
MissIn2ndCol = find(cellfun(@(x) all(ismissing(x)), SheetDataRaw(:,2)));
DiffInNot2Dt = diff(Not2DtPerRow);
IndOfStarts  = find(DiffInNot2Dt > 15); % We suppose to have at least 15 records and less than 15 rows blank or not records
RowsOfStarts = Not2DtPerRow(IndOfStarts) + 1; % + 1 because you have to start from the next row after the last not record
RowsOfEnds   = Not2DtPerRow(IndOfStarts+1) - 1; % - 1 because you have to end in the previous row before the first not record

% If your last element contains more than 2 datetimes, it is a record and you have to add manually also the last station!
if sum(cellfun(@(x) all(isdatetime(x)), SheetDataRaw(end,:)), 2) >= 2
    RowsOfStarts(end+1) = MissIn2ndCol(end) + 1;
    RowsOfEnds(end+1)   = length(SheetDataRaw(:,2));
end

% Check of a possible mismatch of stations number between the two sheets
if numel(StationsRaw) ~= numel(RowsOfStarts)
    error(['Data sheet contains a different number of stations ', ...
           'compared to Station sheet: ',num2str(numel(RowsOfStarts)), ...
           ' against ',num2str(numel(StationsRaw))])
end

% Discarding from Data table the stations not considered
if StatFilt % Same order of stations, ordered according to Data table
    RowsOfStarts = RowsOfStarts(IndsStaFilt);
    RowsOfEnds   = RowsOfEnds(IndsStaFilt);
end

RowsRecsPerSta = arrayfun(@(x,y) x:y, RowsOfStarts, RowsOfEnds, 'UniformOutput',false);

MaxRecs = sum(cellfun(@numel, RowsRecsPerSta));
DateCol = find(sum(cellfun(@(x) all(isdatetime(x)), SheetDataRaw), 1) >= .7*MaxRecs);
DataCol = find(sum(cellfun(@(x) all(isnumeric(x)) , SheetDataRaw), 1) >= .7*MaxRecs);
if numel(DateCol) ~= 2
    error('Columns with datetimes must be 2! The first column is the start.')
end
if numel(DataCol) < 1 || numel(DataCol) > 5
    error(['Column with numeric data exceed the maximum (5) or ', ...
           'were not detected (0)! Please contact the support.'])
end
if numel(DataCol) > 1
    warning(['More than one numeric column detected in you excel!', ...
             ' Check your excel if this is not your intention...'])
end

nSt = DateCol(1); % 1st column must contain always start date!
nEn = DateCol(2); % 2nd column must contain always end date!
nNu = DataCol;

RecDatesStartsPerSta = cellfun(@(x) SheetDataRaw(x,nSt), RowsRecsPerSta, 'UniformOutput',false);
RecDatesEndsPerSta   = cellfun(@(x) SheetDataRaw(x,nEn), RowsRecsPerSta, 'UniformOutput',false);
RecNumDataPerSta     = cellfun(@(x) SheetDataRaw(x,nNu), RowsRecsPerSta, 'UniformOutput',false);

IsDatetimeStarts = cellfun(@(x) cellfun(@isdatetime, x), RecDatesStartsPerSta, 'UniformOutput',false);
IsDatetimeEnds   = cellfun(@(x) cellfun(@isdatetime, x), RecDatesEndsPerSta  , 'UniformOutput',false);
IsDataNumeric    = cellfun(@(x) cellfun(@isnumeric , x), RecNumDataPerSta    , 'UniformOutput',false);

AreAllDatetimeStartsPerSta = cellfun(@all, IsDatetimeStarts);
AreAllDatetimeEndsPerSta   = cellfun(@all, IsDatetimeEnds);
AreAllDataNumericPerSta    = cellfun(@(x) all(x, 'all'), IsDataNumeric);

DataIsConsistent = all([AreAllDatetimeStartsPerSta; ...
                        AreAllDatetimeEndsPerSta; ...
                        AreAllDataNumericPerSta], 'all');

if not(DataIsConsistent)
    if any(not(AreAllDatetimeStartsPerSta))
        ProblematicStations = find(not(AreAllDatetimeStartsPerSta));
        for i1 = reshape(ProblematicStations, 1, []) % To ensure it is always horizontal!
            ProblematicRowsInExcel = RowsRecsPerSta{i1}(not(IsDatetimeStarts{i1}));
            warning(strcat("Station ", Stations(i1), " has a problem in column of starts, rows: ", ...
                           strjoin(string(ProblematicRowsInExcel), ', ')))
        end

    elseif any(not(AreAllDatetimeEndsPerSta))
        ProblematicStations = find(not(AreAllDatetimeEndsPerSta));
        for i1 = reshape(ProblematicStations, 1, [])
            ProblematicRowsInExcel = RowsRecsPerSta{i1}(not(IsDatetimeEnds{i1}));
            warning(strcat("Station ", Stations(i1), " has a problem in column of ends, rows: ", ...
                           strjoin(string(ProblematicRowsInExcel), ', ')))
        end

    elseif any(not(AreAllDataNumericPerSta))
        ProblematicStations = find(not(AreAllDataNumericPerSta));
        for i1 = reshape(ProblematicStations, 1, [])
            ProblematicRowsInExcel = RowsRecsPerSta{i1}(not(all(IsDataNumeric{i1},2)));
            warning(strcat("Station ", Stations(i1), " has a problem in columns of data, rows: ", ...
                           strjoin(string(ProblematicRowsInExcel), ', ')))
        end
    end
end

for i1 = 1:numel(Stations) % To replace missing values
    if any(not(IsDataNumeric{i1}), 'all')
        switch AutoFill
            case 'zeros'
                RecNumDataPerSta{i1}(not(IsDataNumeric{i1})) = {0};
    
            case 'nan'
                RecNumDataPerSta{i1}(not(IsDataNumeric{i1})) = {nan};

            case 'othersta'
                if numel(Stations) <= 1
                    error('Not enough stations to use OtherStat method. At least 2 stations!')
                end

                IndOthSta = not(1:numel(Stations) == i1);
                RowsEmpty = find(any(not(IsDataNumeric{i1}), 2));
                for i2 = 1:numel(RowsEmpty)
                    Date2Fill = RecDatesEndsPerSta{i1}{RowsEmpty(i2)};
    
                    MatchRows = cellfun(@(x) (Date2Fill == [x{:}])', RecDatesEndsPerSta(IndOthSta), 'UniformOutput',false);
    
                    Cells2Use = cellfun(@(x,y) repmat(x, 1, numel(nNu)) & y, MatchRows, IsDataNumeric(IndOthSta), 'UniformOutput',false);
    
                    RowToWrt  = RowsEmpty(i2);
                    ColsToWrt = find(not(IsDataNumeric{i1}(RowsEmpty(i2),:)));

                    AtLst1Dat = any(cat(1, Cells2Use{:}), 1);
                    if not(all(AtLst1Dat(ColsToWrt)))
                        error(['Data to write in ',char(Stations(i1)), ...
                               ' is not present for other stations: ', ...
                               char(RecDatesStartsPerSta{i1}{RowToWrt}),' (start) ', ...
                               char(RecDatesEndsPerSta{i1}{RowToWrt}),' (end)!'])
                    end
    
                    AvgValues = zeros(size(ColsToWrt));
                    for i3 = 1:length(AvgValues)
                        AvgValues(i3) = mean(cellfun(@(x,y) x{y(:,ColsToWrt(i3)), ColsToWrt(i3)}, ...
                                                        RecNumDataPerSta(IndOthSta), Cells2Use));
                    end
                    
                    RecNumDataPerSta{i1}(RowToWrt,ColsToWrt) = num2cell(AvgValues);
                end
    
            case 'averageyr'
                RowsEmpty = find(any(not(IsDataNumeric{i1}), 2));
                for i2 = 1:numel(RowsEmpty)
                    DateEnd  = RecDatesEndsPerSta{i1}{RowsEmpty(i2)};
                    DateMnth = month(DateEnd);
                    DateDay  = day(DateEnd);
    
                    MatchMnth = (DateMnth == month([RecDatesEndsPerSta{i1}{:}]))';
                    MatchDay  = (DateDay  == day([RecDatesEndsPerSta{i1}{:}])  )';
    
                    Cells2Use = repmat(MatchMnth & MatchDay, 1, numel(nNu)) & IsDataNumeric{i1};
    
                    RowToWrt  = RowsEmpty(i2);
                    ColsToWrt = find(not(IsDataNumeric{i1}(RowsEmpty(i2),:)));

                    AtLst1Dat = any(Cells2Use, 1);
                    if not(all(AtLst1Dat(ColsToWrt)))
                        error(['Data in other years [station: ',char(Stations(i1)), ...
                               '] is not present for ',char(RecDatesStartsPerSta{i1}{RowToWrt}), ...
                               ' (start) ',char(RecDatesEndsPerSta{i1}{RowToWrt}),' (end)!'])
                    end
    
                    AvgValues = zeros(size(ColsToWrt));
                    for i3 = 1:length(AvgValues)
                        AvgValues(i3) = mean([RecNumDataPerSta{i1}{ Cells2Use(:,ColsToWrt(i3)), ...
                                                                    ColsToWrt(i3) }]);
                    end
                    
                    RecNumDataPerSta{i1}(RowToWrt,ColsToWrt) = num2cell(AvgValues);
                end
    
            case 'averagelne'
                for i2 = 1:size(RecNumDataPerSta{i1}, 2)
                    RowsEmpty = find(not(IsDataNumeric{i1}(:,i2)));
                    IndRwEmpS = [1; find(diff(RowsEmpty) > 1) + 1];
                    IndRwEmpE = [find(diff(RowsEmpty) > 1); numel(RowsEmpty)];
                    RwsEmptyS = RowsEmpty(IndRwEmpS);
                    RwsEmptyE = RowsEmpty(IndRwEmpE);
                    Rows2Wrte = arrayfun(@(x,y) x:y, RwsEmptyS, RwsEmptyE, 'UniformOutput',false);
                    for i3 = 1:numel(Rows2Wrte)
                        if (min(Rows2Wrte{i3}) == 1)
                            error(['[Station: ',char(Stations(i1)),'] [NumCol: ',num2str(i2), ...
                                   '] The first row is empty -> AverageLNE method not usable!'])
                        elseif (max(Rows2Wrte{i3}) == size(RecNumDataPerSta{i1}, 1))
                            error(['[Station: ',char(Stations(i1)),'] [NumCol: ',num2str(i2), ...
                                   '] The last row is empty -> AverageLNE method not usable!'])
                        end
                        if numel(Rows2Wrte{i3}) > 10
                            warning(['[Station: ',char(Stations(i1)),'] [NumCol: ',num2str(i2), ...
                                     '; StartRow: ',num2str(min(Rows2Wrte{i3})),'] Attention, ', ...
                                     num2str(numel(Rows2Wrte{i3})),' rows filled with same average!'])
                        end
        
                        RowNotEmS = min(Rows2Wrte{i3}) - 1;
                        RowNotEmE = min(Rows2Wrte{i3}) + 1;

                        AvgValTmp = mean([RecNumDataPerSta{i1}{[RowNotEmS, RowNotEmE], i2}]);
                        
                        RecNumDataPerSta{i1}(Rows2Wrte{i3}, i2) = {AvgValTmp};
                    end
                end
    
            otherwise
                error(['Type of recording not recognized ', ...
                       'while trying to replace missing values!'])
        end
    end
end

IsDataNumericNew = cellfun(@(x) cellfun(@isnumeric, x), RecNumDataPerSta, 'UniformOutput',false);

AreAllDataNumericPerStaNew = cellfun(@(x) all(x, 'all'), IsDataNumericNew);

DataIsConsistentNew = all([AreAllDatetimeStartsPerSta; AreAllDatetimeEndsPerSta; AreAllDataNumericPerStaNew], 'all');

if not(DataIsConsistent) && DataIsConsistentNew
    warning(['Stations with inconsistent numeric data were', ...
             ' overwritten (',char(AutoFill),' method)' ...
             ' in rows that did not contain numbers.'])
elseif not(DataIsConsistentNew)
    error(['After trying to replace with 0 rows that ', ...
           'did not contain numbers, something went ', ...
           'wrong. Maybe Dates in 1st and 2nd columns.'])
end

% Extraction of data in single cells and shifting of datetime
datesStart  = cellfun(@(x) [x{:}]', RecDatesStartsPerSta, 'UniformOutput',false);
datesEnd    = cellfun(@(x) [x{:}]', RecDatesEndsPerSta  , 'UniformOutput',false);
numericData = cellfun(@cell2mat   , RecNumDataPerSta    , 'UniformOutput',false);

end