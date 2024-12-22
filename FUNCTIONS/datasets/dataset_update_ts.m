function [DsetUpdated, DateUsed] = dataset_update_ts(TmSnData, TmSnDate, UpdtDate, DsetFtsO, TmSnMode, TmSnParm, Dys4TmSn, Options)

arguments
    TmSnData (1,:) cell 
    TmSnDate (:,:) datetime {mustBeVector}
    UpdtDate (1,1) datetime
    DsetFtsO (:,:) table
    TmSnMode (1,:) char
    TmSnParm (1,:) cell
    Dys4TmSn (1,1) double
    Options.Rngs4Nrm (:,:) table = table()
    Options.TmSnCmlb (1,:) logical = contains(TmSnParm, 'Rain', 'IgnoreCase',true)
    Options.Inds2Tk  (:,:) double {mustBeVector} = 1:size(DsetFtsO, 1)
    Options.TmSnTrgg (1,:) cell = {};
    Options.TmSnPeak (1,:) cell = {};
    Options.TmSnEvDt (1,:) cell = {};
    Options.TmSnTrCs (1,:) char = '';
end

Rngs4Nrm = Options.Rngs4Nrm;
TmSnCmlb = Options.TmSnCmlb;
IndTS2Tk = Options.Inds2Tk;

if all(isnan(Rngs4Nrm{:,:}), 'all') || not(any(Rngs4Nrm{:,:}, 'all'))
    Rngs4Nrm = table();
end

TmSnTrgg = Options.TmSnTrgg;
TmSnPeak = Options.TmSnPeak;
TmSnEvDt = Options.TmSnEvDt;
TmSnTrCs = Options.TmSnTrCs;

if isempty(Rngs4Nrm); NormData = false; else; NormData = true; end

DateUsed = UpdtDate;
tolrDays = 2;

switch lower(TmSnMode)
    case 'separatedays'
        if not(isscalar(Dys4TmSn)); error('Dys4TmSn must be single with separetedays'); end
        FtsNm2Ch = cellfun(@(x) strcat(x,string(1:Dys4TmSn)','d2L'), TmSnParm, 'UniformOutput',false); % Remember to change this line if you change feats names in datasetstudy_creation function!

        for i1 = 1:length(TmSnParm)
            for i2 = 1:Dys4TmSn
                Row2Take = find(UpdtDate == TmSnDate) - i2 + 1;
                TSEvTmNN = full(cat(1,TmSnData{i1}{Row2Take,:})); % Concatenation of study points for each DTM
                if NormData
                    TSEvTime = rescale(TSEvTmNN, ...
                                           'InputMin',Rngs4Nrm{FtsNm2Ch{i1}(i2), 'Min value'}, ...
                                           'InputMax',Rngs4Nrm{FtsNm2Ch{i1}(i2), 'Max value'});
                else
                    TSEvTime = TSEvTmNN;
                end

                DsetFtsO.(FtsNm2Ch{i1}(i2)) = TSEvTime(IndTS2Tk,:); % TSEventTime(IndicesMLDataset);
            end
        end

    case 'condenseddays'
        TmSnOper = repmat({'Av'}, 1, length(TmSnParm));
        TmSnOper(TmSnCmlb) = {'Cm'};
        FtsNm2Ch = cellfun(@(x, y) [x,y,num2str(Dys4TmSn),'d'], TmSnOper, TmSnParm, 'UniformOutput',false);

        Row2Take = find(UpdtDate == TmSnDate);
        for i1 = 1:length(TmSnParm)
            Col2Chg = cell(1, size(TmSnData{i1}, 2));
            for i2 = 1:size(TmSnData{i1}, 2)
                if TmSnCmlb(i1)
                    Col2Chg{i2} = sum( [TmSnData{i1}{Row2Take : -1 : (Row2Take-Dys4TmSn+1), i2}], 2);
                else
                    Col2Chg{i2} = mean([TmSnData{i1}{Row2Take : -1 : (Row2Take-Dys4TmSn+1), i2}], 2);
                end
            end

            TSEvTmNN = full(cat(1,Col2Chg{:})); % Concatenation of study points for each DTM
            if NormData
                TSEvTime = rescale(TSEvTmNN, 'InputMin',Rngs4Nrm{FtsNm2Ch{i1}, 'Min value'}, ...
                                             'InputMax',Rngs4Nrm{FtsNm2Ch{i1}, 'Max value'});
            else
                TSEvTime = TSEvTmNN;
            end

            DsetFtsO.(FtsNm2Ch{i1}) = TSEvTime(IndTS2Tk,:);
        end
       
    case 'triggercausepeak'
        if any([isempty(TmSnTrgg), isempty(TmSnPeak), isempty(TmSnEvDt)])
            error(['TmSnTrgg, TmSnPeak, and TmSnEvDt (opiontal ', ...
                   'arguments) must be specified with TriggerCausePeak mode!'])
        end

        TmSnType = ["Trig"; "Peak"; strcat("Cause",num2str(Dys4TmSn),"d")];
        FtsNm2Ch = cellfun(@(x) strcat(TmSnType,x), TmSnParm, 'UniformOutput',false);

        for i1 = 1:length(TmSnParm)
            [TSEvTmNN, TSEvTime] = deal(cell(1, 3)); % 3 because you will have Trigger, Peak, and Cause
            if not(exist('StrDtTrg', 'var'))
                IndsPssEvs = find(cellfun(@(x) min(abs(UpdtDate-x)) < days(tolrDays), TmSnEvDt{i1}));
                if isempty(IndsPssEvs)
                    warning(['You have no events in a time window of 2 days around ' ...
                             'your datetime. Trigger and peak will be 0!'])
                    IdEv2Tk = [];

                else
                    if numel(IndsPssEvs) > 1
                        PssEvNms = strcat("Event of ",char(cellfun(@(x) min(x), TmSnEvDt{i1}(IndsPssEvs))),' (+', ...
                                          num2str(cellfun(@(x) length(x), TmSnEvDt{i1}(IndsPssEvs))'),' dT)');
                        RlIdEvnt = listdlg2({'Rain event to consider:'}, PssEvNms, 'OutType','NumInd');
                    elseif isscalar(IndsPssEvs)
                        RlIdEvnt = 1;
                    end

                    IdEv2Tk = IndsPssEvs(RlIdEvnt);
                end

            else
                IdEv2Tk = find(cellfun(@(x) min(abs(StrDtTrg-x)) < minutes(1), TmSnEvDt{i1}));
            end

            if isempty(IdEv2Tk)
                StrDtTrg = UpdtDate;

                if TmSnCmlb(i1)
                    TSEvTmNN{1} = zeros(size(full(cat(1, TmSnTrgg{i1}{1,:})))); % Concatenation of study points for each DTM. Trigger rain is 0 (no event to take)!
                    TSEvTmNN{2} = zeros(size(full(cat(1, TmSnPeak{i1}{1,:})))); % Concatenation of study points for each DTM. Peak rain is 0 (no event to take)!
                else
                    [~, IndFke] = min(cellfun(@(x) min(abs(StrDtTrg-x)), TmSnEvDt{i1})); % Search just for the nearest!
                    if not(isscalar(IndFke)); error('IndFke is not unique! Please check it!');end
                    TSEvTmNN{1} = full(cat(1, TmSnTrgg{i1}{IndFke,:})); % Concatenation of study points for each DTM. Trigger is the same of the nearest (no event < tolrDays)!
                    TSEvTmNN{2} = full(cat(1, TmSnPeak{i1}{IndFke,:})); % Concatenation of study points for each DTM. Peak is the same of the nearest (no event < tolrDays)!
                end

            elseif isscalar(IdEv2Tk)
                StrDtTrg = min(TmSnEvDt{i1}{IdEv2Tk});

                TSEvTmNN{1} = full(cat(1, TmSnTrgg{i1}{IdEv2Tk,:})); % Concatenation of study points for each DTM. Pay attention to order! 1st row is Trigger
                TSEvTmNN{2} = full(cat(1, TmSnPeak{i1}{IdEv2Tk,:})); % Pay attention to order! 2nd row is Peak

            else
                error(['Triggering event is more than 1 in ',TmSnParm{i1},'. Please check it!'])
            end

            switch lower(TmSnTrCs)
                case 'dailycumulate'
                    Row2Take = find( abs(TmSnDate - StrDtTrg) < days(1), 1 ) - 1; % Overwriting of RowToTake with the first date before your event! I want only the first one. -1 to take the day before the start of the event!
                    Col2AddT = cell(1, size(TmSnData{i1}, 2));
                    for i2 = 1:size(TmSnData{i1}, 2)
                        IndStart = (Row2Take-Dys4TmSn+1);
                        if IndStart <= 0
                            warning(['Start for cause (',num2str(Dys4TmSn),' d) do not ', ...
                                     'include all required days (',num2str(1-IndStart),' d less)'])
                            IndStart = 1;
                        end
                        if TmSnCmlb(i1)
                            Col2AddT{i2} = sum( [TmSnData{i1}{Row2Take : -1 : IndStart, i2}], 2);
                        else
                            Col2AddT{i2} = mean([TmSnData{i1}{Row2Take : -1 : IndStart, i2}], 2);
                        end
                    end
                    TSEvTmNN{3} = cat(1,Col2AddT{:}); % Concatenation of study points for each DTM. Pay attention to order! 3rd row is Cause

                case 'eventscumulate'
                    StrDtCaus = StrDtTrg - days(Dys4TmSn);
                    IdCausEvs = find(cellfun(@(x) any(StrDtCaus < x) && all(StrDtTrg > x), TmSnEvDt{i1})); % With any(StartDateCause < x) you could go before StartDateCause. change with all if you don't want (that event will be excluded)

                    MinDtEvts = min(cellfun(@min, TmSnEvDt{i1}));
                    if StrDtCaus < min(MinDtEvts)
                        warning('Some events could not be included (start date of Cause is before the minimum date of events)')
                    elseif isempty(IdCausEvs)
                        warning('No events in the time period from start cause to start trigger!')
                    end

                    if isempty(IdCausEvs)
                        if TmSnCmlb(i1)
                            Col2AddT = zeros(size(TSEvTmNN{1},1), 1); % Just 0 (no rainfall cause)
                        else
                            [~, IndFke] = min(cellfun(@(x) min(abs(StrDtCaus-x)), TmSnEvDt{i1})); % Search just for the nearest!
                            if not(isscalar(IndFke)); error('IndFke is not unique! Please check it!');end
                            Col2AddT = full(cat(1, TmSnTrgg{i1}{IndFke,:}));
                        end
                        
                    else
                        Col2AddT = zeros(size(TSEvTmNN{1},1), length(IdCausEvs));
                        for i2 = 1:length(IdCausEvs)
                            Col2AddT(:,i2) = full(cat(1, TmSnTrgg{i1}{IdCausEvs(i2),:}));
                        end
                    end

                    if TmSnCmlb(i1)
                        TSEvTmNN{3} = sum(Col2AddT, 2); % Pay attention to order! 3rd row is Cause
                    else
                        TSEvTmNN{3} = mean(Col2AddT, 2); % Pay attention to order! 3rd row is Cause
                    end

                otherwise
                    error('Time sensitive cause for TriggerCausePeak not recognized!')
            end

            for i2 = 1:length(FtsNm2Ch{i1})
                if NormData
                    TSEvTime{i2} = rescale(TSEvTmNN{i2}, ...
                                               'InputMin',Rngs4Nrm{FtsNm2Ch{i1}(i2), 'Min value'}, ...
                                               'InputMax',Rngs4Nrm{FtsNm2Ch{i1}(i2), 'Max value'});
                else
                    TSEvTime{i2} = TSEvTmNN{i2};
                end

                DsetFtsO.(FtsNm2Ch{i1}(i2)) = TSEvTime{i2}(IndTS2Tk,:);
            end
        end

        DateUsed = StrDtTrg;

    otherwise
        error('Time sensitive mode not recognized during update of dataset!')
end

DsetUpdated = DsetFtsO;

end