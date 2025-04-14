if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Options...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% Options
sl = filesep;
RndSeed = 9; % To control randomness

Patt2Use = digitsPattern(2) + '-' + digitsPattern(2) + '-' + digitsPattern(4);
DatesInp = inputdlg2({'Start Date:', 'End Date:'}, 'DefInp',{'dd-MM-yyyy', 'dd-MM-yyyy'});
for i1 = 1:numel(DatesInp)
    TmpChr = extract(DatesInp{i1}, Patt2Use);
    if numel(TmpChr) ~= 1
        error(['Error in entry n. ',num2str(i1),' (starting from bottom). ', ...
               'You must specify all patterns as dd-MM-yyyy!'])
    end
    DatesInp(i1) = TmpChr;
end

StrtDate = datetime(DatesInp{1}, 'InputFormat','dd-MM-yyyy');
EndDate  = datetime(DatesInp{2}, 'InputFormat','dd-MM-yyyy');

if StrtDate >= EndDate
    error('Start date must be < than End date!')
end

Duration = days(1); % Delta time is only 1 days, implement more options in future!

SynthSeasnNum = {[12, 1:2], 3:5 , 6:8 , 9:11}; % Month numbers per season (starting from winter)

EvsSpecs = inputdlg2({'Min number of rain events per year:', ...
                      'Oscillation of rain events per year:', ...
                      'Maximum number of days per rain event:', ...
                      'Maximum rain amount per day of event:', ...
                      'Number of synthetized timelines:', ...
                      'Distribution of events per season (start is winter):'}, ...
                      'DefInp',{'36','6','10','95','4','[0.37, 0.23, 0.11, 0.29]'}); % Defaults are based on the events occurred in Parma from 2001 to 2019!
MinEvsPerYear = str2double(EvsSpecs{1});
OscilEvntYear = str2double(EvsSpecs{2}); % MinEvsPerYear + OscilEvntYear gives the max number of events in a year!
MaxDaysPerEvn = str2double(EvsSpecs{3});
MaxRainPerDay = str2double(EvsSpecs{4});
NumberOfSynts = str2double(EvsSpecs{5}); % How many column synthetized you want.
EvsDistSeasns = str2num(EvsSpecs{6}); % Distribution of events during seasons, according to SynthSeasnNum

if numel(EvsDistSeasns) ~= 4
    error(['The last input (top one) must contain 4 ', ...
           'numbers with the following format [x, x, x, x]!'])
end

%% Processing
ProgressBar.Message = 'Processing...';
rng(RndSeed)

SynthDates = StrtDate:Duration:EndDate;
SynthRains = zeros(NumberOfSynts, numel(SynthDates));

SynthYears = unique(year(SynthDates));
YearIndsLg = arrayfun(@(x) ( x == year(SynthDates) ), SynthYears, 'UniformOutput',false);
MnthIndsLg = cellfun(@(x) ismember(month(SynthDates)', x', 'rows')', SynthSeasnNum, 'UniformOutput',false);

YrSeasInds = cell(numel(MnthIndsLg), numel(YearIndsLg));
for i1 = 1:size(YrSeasInds, 2)
    YrSeasInds(:,i1) = cellfun(@(x) find(and(x, YearIndsLg{i1})), MnthIndsLg, 'UniformOutput',false)';
end

for i1 = 1:NumberOfSynts
    for i2 = 1:size(YrSeasInds,2)
        EvsPerYear = MinEvsPerYear + ceil(rand*OscilEvntYear);
        for i3 = 1:size(YrSeasInds,1)
            EvsPerYrSn = ceil(EvsPerYear*EvsDistSeasns(i3));
            RelIndsTmp = randperm(numel(YrSeasInds{i3,i2}), EvsPerYrSn);
            for i4 = 1:numel(RelIndsTmp)
                DaysDurTmp = ceil(MaxDaysPerEvn*(rand*rand)); % (rand*rand) is necessary to reduce probabilities of having too much consecutive days! 10 days of rainfalls is a rare event!
                TmpIndices = YrSeasInds{i3,i2}(RelIndsTmp(i4)) : min(YrSeasInds{i3,i2}(RelIndsTmp(i4))+DaysDurTmp-1, numel(SynthDates));
        
                SynthRains(i1, TmpIndices) = MaxRainPerDay*(rand(1, numel(TmpIndices)).*rand(1, numel(TmpIndices))); % The doubling of rand vectors is necessary to increase the probability of having low values instead of high (rare cases)!
            end
        end
    end
end

% Table creation
SynthRainNames  = strcat('SynthRain',string(1:size(SynthRains,1)));
SynthetizedRain = [table(SynthDates', SynthDates'+Duration, 'VariableNames',{'StartDate', 'EndDate'}), ...
                   array2table(SynthRains', 'VariableNames',SynthRainNames)];

%% Saving
ProgressBar.Message = 'Saving files...';
VariablesSynth = {'SynthetizedRain', 'Duration'};

saveswitch([fold_var,sl,'SynthetizedRain.mat'], VariablesSynth)