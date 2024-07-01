if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Options
WgtsInps = str2double(inputdlg2({'Weight of L day vs NL: ', 'Weight of PPR vs NPR: '}, 'DefInp',{'0.5', '0.5'}));
WgPLvsPB = WgtsInps(1); % Is to set the weight of the last day in the positive line (day of landslide vs all the others)
WgTPvsTN = WgtsInps(2); % Is to set the weight of the PPR curve vs the NPR curve

Thresholds = [60, 70, 80];

%% Loading
sl = filesep;

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
load([fold_res_ml_curr,sl,'PredictionsStudy.mat'], 'PredPlyRt','EventsInfo','LandPolys')

Perc_L_U  = PredPlyRt.PercLsInUnst;
Perc_NL_S = PredPlyRt.PercNlInStab;

%% Loops for models
ProgressBar.Message  = 'Loop through the models per each series...';

EvsNames = EventsInfo.Properties.VariableNames;
DateTemp = [EventsInfo{'PredictionDate',:}{:}];
IndStrts = [1, find(hours(diff(DateTemp)) > 24)+1];
IndEnds  = [find(hours(diff(DateTemp)) > 24), numel(DateTemp)];

MdlNames = PredPlyRt.ThrUsed.Properties.VariableNames;

TimeScore = table();
for IndMdl = 1:numel(MdlNames)
    SerPrds = cell(3, numel(IndEnds));
    SerPlys = cell(2, numel(IndEnds));
    for i1 = 1:numel(IndEnds)
        UnstPolys = LandPolys{IndStrts(i1):IndEnds(i1), 'UnstablePolygons'};
        CheckEqUn = all(cellfun(@(x) isequal(UnstPolys{1}, x), UnstPolys));
    
        StabPolys = LandPolys{IndStrts(i1):IndEnds(i1), 'StablePolygons'};
        CheckEqSt = all(cellfun(@(x) isequal(StabPolys{1}, x), StabPolys));
    
        if CheckEqSt && CheckEqUn
            UnstPolys = UnstPolys{1};
            StabPolys = StabPolys{1};
        else
            error(['You have selected events with different polygons! Time series n. ',num2str(i1)])
        end
    
        SerPrds(:, i1) = {DateTemp(IndStrts(i1):IndEnds(i1)); ...
                           Perc_L_U{IndStrts(i1):IndEnds(i1), IndMdl}'; ...
                           Perc_NL_S{IndStrts(i1):IndEnds(i1), IndMdl}'};
        SerPlys(:, i1) = {StabPolys; UnstPolys};
    end
    
    MinNumOfDays = min(cellfun(@numel, SerPrds(1,:)));
    for i1 = 1:size(SerPrds, 2)
        if numel(SerPrds{1,i1}) ~= MinNumOfDays
            warning(['Time series n. ',num2str(i1),' has too much dates, it will be reduced!'])
            for i2 = 1:size(SerPrds, 1)
                SerPrds{i2,i1} = SerPrds{i2,i1}(end-MinNumOfDays+1:end);
            end
        end
    end
    
    % for i1 = 1:size(SepPreds, 2)
    %     for i2 = 1:size(SepPreds, 1)
    %         SepPreds{i2,i1} = SepPreds{i2,i1}(1:end-1); % To temove the last day (theoretically the training is stopped the day before)
    %     end
    % end
    
    %% Core variables
    [TmScSrs, PPRwThr, NPRwThr] = deal(cell(numel(Thresholds), size(SerPrds,2)));
    for i1 = 1:size(SerPrds,2)
        for i2 = 1:length(Thresholds)
            PPR = cellfun(@(x) numel(find(x>=Thresholds(i2))), SerPrds{2, i1});
            NPR = cellfun(@(x) numel(find(x>=Thresholds(i2))), SerPrds{3, i1});
        
            PPRwThr{i2,i1} = 100*PPR./numel(SerPlys{2, i1});
            NPRwThr{i2,i1} = 100*NPR./numel(SerPlys{1, i1});
    
            DaysL   = 1;
            DaysNL  = size(PPRwThr{i2,i1},2) - DaysL;
            TmErrTP = (1-WgPLvsPB) * rmse( zeros(1,DaysNL), PPRwThr{i2,i1}(1:DaysNL) ) + WgPLvsPB * rmse( 100, PPRwThr{i2,i1}(end) );
            TmErrTN = rmse( repmat(100, 1, DaysNL+DaysL), NPRwThr{i2,i1} );
        
            TmScSrs{i2,i1} = 100 - (WgTPvsTN*TmErrTP + (1-WgTPvsTN)*TmErrTN); % The more is high, the more the mdl is good! Score 100 is perfect!
        end
    end
    
    ColsNms = strcat({'Series'},string(1:size(TmScSrs,2)));
    RowsNms = strcat({'Threshold'},string(1:numel(Thresholds)));
    
    TmScSrs = array2table(TmScSrs, 'VariableNames',ColsNms, 'RowNames',RowsNms);
    PPRwThr = array2table(PPRwThr, 'VariableNames',ColsNms, 'RowNames',RowsNms);
    NPRwThr = array2table(NPRwThr, 'VariableNames',ColsNms, 'RowNames',RowsNms);
    SerPrds = array2table(SerPrds, 'VariableNames',ColsNms, 'RowNames',{'Dates','PercLsInUnst','PercNlInStab'});
    TmScAvg = array2table(mean(cell2mat(table2array(TmScSrs)), 2), 'VariableNames',{'AvgSeries'}, 'RowNames',RowsNms);

    TimeScore{{'TimeScore', 'AvgTimeScore', 'PPR', 'NPR', 'Series'}, MdlNames(IndMdl)} = {TmScSrs; TmScAvg; PPRwThr; NPRwThr; SerPrds};
end

%% Saving
ProgressBar.Message  = 'Saving files...';

save([fold_res_ml_curr,sl,'TimeScoreIndex.mat'], 'TimeScore','Thresholds')