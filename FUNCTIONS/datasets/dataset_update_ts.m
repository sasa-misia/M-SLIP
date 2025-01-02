function [dsetUpd, dateSel, ftsNmUpd] = dataset_update_ts(tmSnData, tmSnDate, updtDate, dsetFtsO, tmSnMode, tmSnParm, dys4TmSn, Options)

arguments
    tmSnData (1,:) cell 
    tmSnDate (:,:) datetime {mustBeVector}
    updtDate (1,1) datetime
    dsetFtsO (:,:) table
    tmSnMode (1,:) char
    tmSnParm (1,:) cell
    dys4TmSn (1,1) double
    Options.Rngs4Nrm (:,:) table = table()
    Options.TmSnCmlb (1,:) logical = contains(tmSnParm, 'Rain', 'IgnoreCase',true)
    Options.Inds2Tk  (:,:) double {mustBeVector} = 1:size(dsetFtsO, 1)
    Options.TmSnTrgg (1,:) cell = {};
    Options.TmSnPeak (1,:) cell = {};
    Options.TmSnEvDt (1,:) cell = {};
    Options.TmSnTrCs (1,:) char = '';
end

rngs4Nrm = Options.Rngs4Nrm;
tmSnCmlb = Options.TmSnCmlb;
indTS2Tk = Options.Inds2Tk;

if all(isnan(rngs4Nrm{:,:}), 'all') || not(any(rngs4Nrm{:,:}, 'all'))
    rngs4Nrm = table();
end

tmSnTrgg = Options.TmSnTrgg;
tmSnPeak = Options.TmSnPeak;
tmSnEvDt = Options.TmSnEvDt;
tmSnTrCs = Options.TmSnTrCs;

if isempty(rngs4Nrm); normData = false; else; normData = true; end

dateSel = updtDate;
tolDays = 2;

switch lower(tmSnMode)
    case 'separatedays'
        if not(isscalar(dys4TmSn)); error('Dys4TmSn must be single with separetedays'); end
        ftsNmUpd = cellfun(@(x) strcat(x,string(1:dys4TmSn)','d2L'), tmSnParm, 'UniformOutput',false); % Remember to change this line if you change feats names in datasetstudy_creation function!

        for i1 = 1:length(tmSnParm)
            for i2 = 1:dys4TmSn
                row2Take = find(updtDate == tmSnDate) - i2 + 1;
                tsEvTmNN = full(cat(1,tmSnData{i1}{row2Take,:})); % Concatenation of study points for each DTM
                if normData
                    tsEvTime = rescale(tsEvTmNN, ...
                                           'InputMin',rngs4Nrm{ftsNmUpd{i1}(i2), 'Min value'}, ...
                                           'InputMax',rngs4Nrm{ftsNmUpd{i1}(i2), 'Max value'});
                else
                    tsEvTime = tsEvTmNN;
                end

                dsetFtsO.(ftsNmUpd{i1}(i2)) = tsEvTime(indTS2Tk,:); % TSEventTime(IndicesMLDataset);
            end
        end

    case 'condenseddays'
        tmSnOper = repmat({'Av'}, 1, length(tmSnParm));
        tmSnOper(tmSnCmlb) = {'Cm'};
        ftsNmUpd = cellfun(@(x, y) [x,y,num2str(dys4TmSn),'d'], tmSnOper, tmSnParm, 'UniformOutput',false);

        row2Take = find(updtDate == tmSnDate);
        for i1 = 1:length(tmSnParm)
            col2Chg = cell(1, size(tmSnData{i1}, 2));
            for i2 = 1:size(tmSnData{i1}, 2)
                if tmSnCmlb(i1)
                    col2Chg{i2} = sum( [tmSnData{i1}{row2Take : -1 : (row2Take-dys4TmSn+1), i2}], 2);
                else
                    col2Chg{i2} = mean([tmSnData{i1}{row2Take : -1 : (row2Take-dys4TmSn+1), i2}], 2);
                end
            end

            tsEvTmNN = full(cat(1,col2Chg{:})); % Concatenation of study points for each DTM
            if normData
                tsEvTime = rescale(tsEvTmNN, 'InputMin',rngs4Nrm{ftsNmUpd{i1}, 'Min value'}, ...
                                             'InputMax',rngs4Nrm{ftsNmUpd{i1}, 'Max value'});
            else
                tsEvTime = tsEvTmNN;
            end

            dsetFtsO.(ftsNmUpd{i1}) = tsEvTime(indTS2Tk,:);
        end
       
    case 'triggercausepeak'
        if any([isempty(tmSnTrgg), isempty(tmSnPeak), isempty(tmSnEvDt)])
            error(['TmSnTrgg, TmSnPeak, and TmSnEvDt (opiontal ', ...
                   'arguments) must be specified with TriggerCausePeak mode!'])
        end

        tmSnType = ["Trig"; "Peak"; strcat("Cause",num2str(dys4TmSn),"d")];
        ftsNmUpd = cellfun(@(x) strcat(tmSnType,x), tmSnParm, 'UniformOutput',false);

        for i1 = 1:length(tmSnParm)
            [tsEvTmNN, tsEvTime] = deal(cell(1, 3)); % 3 because you will have Trigger, Peak, and Cause
            if not(exist('StrDtTrg', 'var'))
                IndsPssEvs = find(cellfun(@(x) min(abs(updtDate-x)) < days(tolDays), tmSnEvDt{i1}));
                if isempty(IndsPssEvs)
                    warning(['You have no events in a time window of 2 days around ' ...
                             'your datetime. Trigger and peak will be 0!'])
                    idEv2Tk = [];

                else
                    if numel(IndsPssEvs) > 1
                        pssEvNms = strcat("Event of ",char(cellfun(@(x) min(x), tmSnEvDt{i1}(IndsPssEvs))),' (+', ...
                                          num2str(cellfun(@(x) length(x), tmSnEvDt{i1}(IndsPssEvs))'),' dT)');
                        rlIdEvnt = listdlg2({'Rain event to consider:'}, pssEvNms, 'OutType','NumInd');
                    elseif isscalar(IndsPssEvs)
                        rlIdEvnt = 1;
                    end

                    idEv2Tk = IndsPssEvs(rlIdEvnt);
                end

            else
                idEv2Tk = find(cellfun(@(x) min(abs(strDtTrg-x)) < minutes(1), tmSnEvDt{i1}));
            end

            if isempty(idEv2Tk)
                strDtTrg = updtDate;

                if tmSnCmlb(i1)
                    tsEvTmNN{1} = zeros(size(full(cat(1, tmSnTrgg{i1}{1,:})))); % Concatenation of study points for each DTM. Trigger rain is 0 (no event to take)!
                    tsEvTmNN{2} = zeros(size(full(cat(1, tmSnPeak{i1}{1,:})))); % Concatenation of study points for each DTM. Peak rain is 0 (no event to take)!
                else
                    [~, IndFke] = min(cellfun(@(x) min(abs(strDtTrg-x)), tmSnEvDt{i1})); % Search just for the nearest!
                    if not(isscalar(IndFke)); error('IndFke is not unique! Please check it!');end
                    tsEvTmNN{1} = full(cat(1, tmSnTrgg{i1}{IndFke,:})); % Concatenation of study points for each DTM. Trigger is the same of the nearest (no event < tolrDays)!
                    tsEvTmNN{2} = full(cat(1, tmSnPeak{i1}{IndFke,:})); % Concatenation of study points for each DTM. Peak is the same of the nearest (no event < tolrDays)!
                end

            elseif isscalar(idEv2Tk)
                strDtTrg = min(tmSnEvDt{i1}{idEv2Tk});

                tsEvTmNN{1} = full(cat(1, tmSnTrgg{i1}{idEv2Tk,:})); % Concatenation of study points for each DTM. Pay attention to order! 1st row is Trigger
                tsEvTmNN{2} = full(cat(1, tmSnPeak{i1}{idEv2Tk,:})); % Pay attention to order! 2nd row is Peak

            else
                error(['Triggering event is more than 1 in ',tmSnParm{i1},'. Please check it!'])
            end

            switch lower(tmSnTrCs)
                case 'dailycumulate'
                    row2Take = find( abs(tmSnDate - strDtTrg) < days(1), 1 ) - 1; % Overwriting of RowToTake with the first date before your event! I want only the first one. -1 to take the day before the start of the event!
                    col2AddT = cell(1, size(tmSnData{i1}, 2));
                    for i2 = 1:size(tmSnData{i1}, 2)
                        IndStart = (row2Take-dys4TmSn+1);
                        if IndStart <= 0
                            warning(['Start for cause (',num2str(dys4TmSn),' d) do not ', ...
                                     'include all required days (',num2str(1-IndStart),' d less)'])
                            IndStart = 1;
                        end
                        if tmSnCmlb(i1)
                            col2AddT{i2} = sum( [tmSnData{i1}{row2Take : -1 : IndStart, i2}], 2);
                        else
                            col2AddT{i2} = mean([tmSnData{i1}{row2Take : -1 : IndStart, i2}], 2);
                        end
                    end
                    tsEvTmNN{3} = cat(1,col2AddT{:}); % Concatenation of study points for each DTM. Pay attention to order! 3rd row is Cause

                case 'eventscumulate'
                    strDtCaus = strDtTrg - days(dys4TmSn);
                    idCausEvs = find(cellfun(@(x) any(strDtCaus < x) && all(strDtTrg > x), tmSnEvDt{i1})); % With any(StartDateCause < x) you could go before StartDateCause. change with all if you don't want (that event will be excluded)

                    minDtEvts = min(cellfun(@min, tmSnEvDt{i1}));
                    if strDtCaus < min(minDtEvts)
                        warning('Some events could not be included (start date of Cause is before the minimum date of events)')
                    elseif isempty(idCausEvs)
                        warning('No events in the time period from start cause to start trigger!')
                    end

                    if isempty(idCausEvs)
                        if tmSnCmlb(i1)
                            col2AddT = zeros(size(tsEvTmNN{1},1), 1); % Just 0 (no rainfall cause)
                        else
                            [~, IndFke] = min(cellfun(@(x) min(abs(strDtCaus-x)), tmSnEvDt{i1})); % Search just for the nearest!
                            if not(isscalar(IndFke)); error('IndFke is not unique! Please check it!');end
                            col2AddT = full(cat(1, tmSnTrgg{i1}{IndFke,:}));
                        end
                        
                    else
                        col2AddT = zeros(size(tsEvTmNN{1},1), length(idCausEvs));
                        for i2 = 1:length(idCausEvs)
                            col2AddT(:,i2) = full(cat(1, tmSnTrgg{i1}{idCausEvs(i2),:}));
                        end
                    end

                    if tmSnCmlb(i1)
                        tsEvTmNN{3} = sum(col2AddT, 2); % Pay attention to order! 3rd row is Cause
                    else
                        tsEvTmNN{3} = mean(col2AddT, 2); % Pay attention to order! 3rd row is Cause
                    end

                otherwise
                    error('Time sensitive cause for TriggerCausePeak not recognized!')
            end

            for i2 = 1:length(ftsNmUpd{i1})
                if normData
                    tsEvTime{i2} = rescale(tsEvTmNN{i2}, ...
                                               'InputMin',rngs4Nrm{ftsNmUpd{i1}(i2), 'Min value'}, ...
                                               'InputMax',rngs4Nrm{ftsNmUpd{i1}(i2), 'Max value'});
                else
                    tsEvTime{i2} = tsEvTmNN{i2};
                end

                dsetFtsO.(ftsNmUpd{i1}(i2)) = tsEvTime{i2}(indTS2Tk,:);
            end
        end

        dateSel = strDtTrg;

    otherwise
        error('Time sensitive mode not recognized during update of dataset!')
end

dsetUpd = dsetFtsO;

end