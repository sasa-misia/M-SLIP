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

switch lower(TmSnMode)
    case 'separatedays'
        FtsNm2Ch = cellfun(@(x) strcat(x,'-',string(1:Dys4TmSn)','daysBefore'), TmSnParm, 'UniformOutput',false); % Remember to change this line if you change feats names in datasetstudy_creation function!

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
        TmSnOper = repmat({'Averaged'}, 1, length(TmSnParm));
        TmSnOper(TmSnCmlb) = {'Cumulated'};
        FtsNm2Ch = cellfun(@(x, y) [x,y,num2str(Dys4TmSn),'d'], TmSnParm, TmSnOper, 'UniformOutput',false);

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

        TmSnType = ["Trigger"; strcat("Cause",num2str(Dys4TmSn),"d"); "TriggPeak"];
        FtsNm2Ch = cellfun(@(x) strcat(x,TmSnType), TmSnParm, 'UniformOutput',false);

        for i1 = 1:length(TmSnParm)
            [TSEvTmNN, TSEvTime] = deal(cell(1, 3)); % 3 because you will have Trigger, cause, and peak
            if not(exist('StartDateTrigg', 'var'))
                IndsPssEvs = find(cellfun(@(x) min(abs(UpdtDate-x)) < days(2), TmSnEvDt{i1}));
                if isempty(IndsPssEvs)
                    error('You have no events in a time window of 2 days around your datetime. Choose another datetime!')
                elseif IndsPssEvs > 1
                    PssEvNms = strcat("Event of ",char(cellfun(@(x) min(x), TmSnEvDt{i1}(IndsPssEvs))),' (+', ...
                                      num2str(cellfun(@(x) length(x), TmSnEvDt{i1}(IndsPssEvs))'),' h)');
                    RlIdEvnt = listdlg2({'Rain event to consider:'}, PssEvNms, 'OutType','NumInd');
                elseif IndsPssEvs == 1
                    RlIdEvnt = 1;
                end
                IdEv2Tk = IndsPssEvs(RlIdEvnt);

            else
                IdEv2Tk = find(cellfun(@(x) min(abs(StrDtTrg-x)) < minutes(1), TmSnEvDt{i1}));
                if isempty(IdEv2Tk) || (numel(IdEv2Tk) > 1)
                    error(['Triggering event is not present in ',TmSnParm{i1}, ...
                           ', or there are multiple possibilities. Please check it!'])
                end
            end
            StrDtTrg = min(TmSnEvDt{i1}{IdEv2Tk});

            TSEvTmNN{1} = full(cat(1, TmSnTrgg{i1}{IdEv2Tk,:})); % Concatenation of study points for each DTM. Pay attention to order! 1st row is Trigger

            switch lower(TmSnTrCs)
                case 'dailycumulate'
                    Row2Take = find( abs(TmSnDate - StrDtTrg) < days(1), 1 ) - 1; % Overwriting of RowToTake with the first date before your event! I want only the first one. -1 to take the day before the start of the event!
                    Col2AddT = cell(1, size(TmSnData{i1}, 2));
                    for i2 = 1:size(TmSnData{i1}, 2)
                        if TmSnCmlb(i1)
                            Col2AddT{i2} = sum( [TmSnData{i1}{Row2Take : -1 : (Row2Take-Dys4TmSn+1), i2}], 2);
                        else
                            Col2AddT{i2} = mean([TmSnData{i1}{Row2Take : -1 : (Row2Take-Dys4TmSn+1), i2}], 2);
                        end
                    end
                    TSEvTmNN{2} = cat(1,Col2AddT{:}); % Concatenation of study points for each DTM. Pay attention to order! 2nd row is Cause

                case 'eventscumulate'
                    StrDtCaus = StrDtTrg - days(Dys4TmSn);
                    IdCausEvs = find(cellfun(@(x) any(StrDtCaus < x) && all(StrDtTrg > x), TmSnEvDt{i1})); % With any(StartDateCause < x) you could go before StartDateCause. change with all if you don't want (that event will be excluded)

                    MinDtEvts = min(cellfun(@min, TmSnEvDt{i1}));
                    if StrDtCaus < min(MinDtEvts)
                        warning('Some events could not be included (start date of Cause is before the minimum date of events)')
                    elseif isempty(IdCausEvs)
                        error('No events in the time period from start cause to start trigger!')
                    end

                    Col2AddT = zeros(size(TSEvTmNN{1},1), length(IdCausEvs));
                    for i2 = 1:length(IdCausEvs)
                        Col2AddT(:,i2) = full(cat(1, TmSnTrgg{i1}{IdCausEvs(i2),:}));
                    end
                    if TmSnCmlb(i1)
                        TSEvTmNN{2} = sum(Col2AddT, 2); % Pay attention to order! 2nd row is Cause
                    else
                        TSEvTmNN{2} = mean(Col2AddT, 2); % Pay attention to order! 2nd row is Cause
                    end

                otherwise
                    error('Time sensitive cause for TriggerCausePeak not recognized!')
            end

            TSEvTmNN{3} = full(cat(1, TmSnPeak{i1}{IdEv2Tk,:})); % Pay attention to order! 3rd row is Peak

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