if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files
sl = filesep;

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');

load([fold_var,sl,'UserStudyArea_Answers.mat'], 'MunSel')
load([fold_var,sl,'StudyAreaVariables.mat'   ], 'StudyAreaPolygon')
load([fold_var,sl,'GridCoordinates.mat'      ], 'xLongAll','yLatAll')
load([fold_var,sl,'DatasetStudy.mat'         ], 'DatasetStudyFeats','DatasetStudyCoords')
load([fold_res_ml_curr,sl,'MLMdlB.mat'       ], 'ModelInfo','MLMdl')

PreExistPredictions = false;
if exist([fold_res_ml_curr,sl,'PredictionsStudy.mat'], 'file')
    PreExistPredictions = true;
    load([fold_res_ml_curr,sl,'PredictionsStudy.mat'], 'PredProbs','LandPolys', ...
                                                       'EventsInfo','EventsPerf')
else
    [PredProbs, LandPolys, EventsInfo] = deal(table);
    EventsPerf = struct('MSE',table, 'AUROC',table, 'BT',table);
end

Dset2PredCrd = DatasetStudyCoords;
Dset2PredFts = DatasetStudyFeats;
clear('DatasetStudyCoords', 'DatasetStudyFeats')

DsetTblPly = table();

FeatsUsd = ModelInfo{1,'DatasetInfo'}{:}{1,'FeaturesNames'}{:};
NormData = ModelInfo{1,'DatasetInfo'}{:}{1,'NormalizedData'};
Rngs4Nrm = ModelInfo.RangesForNorm{:};
TmSnMode = ModelInfo.TimeSensMode;

if strcmpi(TmSnMode, 'TriggerCausePeak')
    TmSnTrCs = ModelInfo{1,'DatasetInfo'}{:}{1,'CauseMode'};
else
    TmSnTrCs = "";
end

dX = int64(acos(sind(yLatAll{1}(1,1))*sind(yLatAll{1}(1,2))+cosd(yLatAll{1}(1,1))*cosd(yLatAll{1}(1,2))*cosd(xLongAll{1}(1,2)-xLongAll{1}(1,1)))*earthRadius);
dY = int64(acos(sind(yLatAll{1}(1,1))*sind(yLatAll{1}(2,1))+cosd(yLatAll{1}(1,1))*cosd(yLatAll{1}(2,1))*cosd(xLongAll{1}(2,1)-xLongAll{1}(1,1)))*earthRadius);
if dX == dY
    SizeDTM = dX;
else
    SizeDTM = [dX, dY];
end

%% Options
ApplOpts = checkbox2({'Select polygons', 'Parallelize', 'Manual ev names', ...
                      'Manual best sel', 'Clusterize points', 'Plot'}, 'OutType','LogInd');
SelPolys = ApplOpts(1);
Parallel = ApplOpts(2);
MnNmngEv = ApplOpts(3);
MnBstMdl = ApplOpts(4);
ClstPnts = ApplOpts(5);
PltPolys = ApplOpts(6);

TmSnsExs = any(strcmp('TimeSensitive', ModelInfo{1,'DatasetInfo'}{:}{1,'FeaturesTypes'}{:}));

if MnBstMdl
    ThrAUROC = str2double(inputdlg2('AUROC threshold:', 'DefInp','.8'));
end

%% Removing old rainfalls / temperatures and unecessary models
Ids2Rem = contains(FeatsUsd, {'Rain', 'Temperature'}, 'IgnoreCase',true);

Dset2PredFts(:,Ids2Rem) = [];

if MnBstMdl
    if size(PredProbs, 1) > 1
        BstMdlNumb = find(strcmp(MLMdl.Properties.VariableNames, PredProbs.Properties.VariableNames));
    else
        if size(MLMdl, 2) == 1
            BstMdlNumb = 1;
        else
            BstMdlNumb = checkbox2(MLMdl.Properties.VariableNames, 'OutType','NumInd', 'Title','Model to use:');
        end
    end
    
    MLMdl = MLMdl(:,BstMdlNumb);

    RemainedMdl = strjoin(MLMdl.Properties.VariableNames, '; ');
    warning(['Since you have selected the manual mode for the ', ...
             'best model, the models chosen are: ',RemainedMdl])
end

%% Datetime extraction for time sensistive part
if TmSnsExs
    TmSnCmlb = false([]);
    [TmSnParm, TmSnData, TmSnDate, ...
        TmSnTrgg, TmSnPeak, TmSnEvDt] = deal({});
    
    % Rainfall
    if any(contains(FeatsUsd, 'Rain'))
        load([fold_var,sl,'RainInterpolated.mat'], 'RainInterpolated','RainDateInterpolationStarts')
        TmSnData = [TmSnData, {RainInterpolated}];
        TmSnDate = [TmSnDate, {RainDateInterpolationStarts}];
        TmSnParm = [TmSnParm, {'Rain'}];
        TmSnCmlb = [TmSnCmlb,  true];
        clear('RainInterpolated')
        if strcmpi(TmSnMode, 'TriggerCausePeak')
            load([fold_var,sl,'RainEvents.mat'], 'RainAmountPerEventInterp','RainMaxPeakPerEventInterp','RainRecDatesPerEvent')
            TmSnTrgg = [TmSnTrgg, {RainAmountPerEventInterp} ];
            TmSnPeak = [TmSnPeak, {RainMaxPeakPerEventInterp}];
            TmSnEvDt = [TmSnEvDt, {RainRecDatesPerEvent}     ];
            clear('RainAmountPerEventInterp', 'RainMaxPeakPerEventInterp', 'RainRecDatesPerEvent')
        end
    end
    
    % Temperature
    if any(contains(FeatsUsd, 'Temp'))
        load([fold_var,sl,'TempInterpolated.mat'], 'TempInterpolated','TempDateInterpolationStarts')
        TmSnData = [TmSnData,  {TempInterpolated}];
        TmSnDate = [TmSnDate,  {TempDateInterpolationStarts}];
        TmSnParm = [TmSnParm, {'Temp'}];
        TmSnCmlb = [TmSnCmlb,  false];
        clear('TempInterpolated')
        if strcmpi(TmSnMode, 'TriggerCausePeak')
            load([fold_var,sl,'TempEvents.mat'], 'TempAmountPerEventInterp','TempMaxPeakPerEventInterp','TempRecDatesPerEvent')
            TmSnTrgg = [TmSnTrgg, {TempAmountPerEventInterp} ];
            TmSnPeak = [TmSnPeak, {TempMaxPeakPerEventInterp}];
            TmSnEvDt = [TmSnEvDt, {TempRecDatesPerEvent}     ];
            clear('TempAmountPerEventInterp', 'TempMaxPeakPerEventInterp', 'TempRecDatesPerEvent')
        end
    end
    
    % Uniformization of time sensitive part
    StrDateComm = max(cellfun(@min, TmSnDate)); % Start in end dates
    EndDateComm = min(cellfun(@max, TmSnDate)); % End in end dates
    
    if EndDateComm < StrDateComm
        error('Time sensitive part has no datetime in common! Please re-interpolate time sensitive part.')
    end
    
    if length(TmSnDate) > 1
        for i1 = 1 : length(TmSnDate)
            IndStrComm = find(StrDateComm == TmSnDate{i1}); % You should put an equal related to days and not exact timing
            IndEvnComm = find(EndDateComm == TmSnDate{i1}); % You should put an equal related to days and not exact timing
            TmSnData{i1} = TmSnData{i1}(IndStrComm:IndEvnComm,:);
            TmSnDate{i1} = TmSnDate{i1}(IndStrComm:IndEvnComm);
        end
        if length(TmSnDate)>1 && ~isequal(TmSnDate{:})
            error('After uniformization of dates in time sensitive part, number of elements is not consistent! Please check it in the script.')
        end
    end
    
    TmSnDate = TmSnDate{1}; % Taking only the first one since they are identical!

    Dys4TmSn = ModelInfo{1,'DatasetInfo'}{:}{1,'DaysForTS'}{:};
    IndxEvnt = listdlg2({'Date of event (start time of 24 h):'}, TmSnDate(max(Dys4TmSn):end), 'OutType','NumInd');
    EvntDate = TmSnDate(max(Dys4TmSn)+IndxEvnt-1); % You have to start from Days4TS

    DaysNumb = str2double(inputdlg2('Days to predict (last to back):', 'DefInp','1')); % Number of days before your event, to have a sort of history graph
    
    LandsDay = checkbox2((EvntDate-days(DaysNumb-1)):days(1):EvntDate, ...
                                        'Title','Select landslide events:', 'OutType','LogInd', ...
                                        'DefInp',[false(1, DaysNumb-1), true]);
else
    DaysNumb = 1;
    LandsDay = true(1, DaysNumb); % Actually, only the last one should be landslide event!

    warning(['Please contact the support. Not yet implemented ', ...
             'the possibility of not having time sensitive part!'])
end

%% Choice of polygons
if SelPolys
    load([fold_var,sl,'DatasetMLB.mat'], 'DatasetInfo')
    
    IndPolys = listdlg2({'Select polygons to predict:'}, DatasetInfo.EventDate, 'OutType','NumInd');
    StabPlys = DatasetInfo.PolysStable{IndPolys};
    IndePlys = DatasetInfo.PolysIndecision{IndPolys};
    UnstPlys = DatasetInfo.PolysUnstable{IndPolys};
else
    load([fold_var,sl,'DatasetStudy.mat'], 'StablePolygons','UnstablePolygons','IndecisionPolygons')
    StabPlys = StablePolygons;
    IndePlys = IndecisionPolygons;
    UnstPlys = UnstablePolygons;
end

%% Core
if numel(TmSnDate) < DaysNumb
    error(['The number of history days should be less ' ...
           'than the dates in TimeSensitiveDate!'])
end
if numel(TmSnDate) < (DaysNumb + max(Dys4TmSn) - 1)
    error(['The number of history days should be take ', ...
           'into account also the antecedent days for ', ...
           'the Time Sensitive part! Reduce history days by ', ...
           num2str(DaysNumb + max(Dys4TmSn) - 1 - numel(TmSnDate)), ...
           ' or move forward the event date of the same quantity.'])
end

for EvId = 1 : DaysNumb
    %% Selection of event and adjustment of dataset
    CurrDate = EvntDate - days(DaysNumb - EvId);

    for i1 = 1:numel(Dys4TmSn)
        [Dset2PredFts, ...
            CurrDate] = dataset_update_ts(TmSnData, TmSnDate, CurrDate, ...
                                          Dset2PredFts, TmSnMode, TmSnParm, Dys4TmSn(i1), ...
                                          Rngs4Nrm = Rngs4Nrm, TmSnCmlb = TmSnCmlb, TmSnTrgg = TmSnTrgg, ...
                                          TmSnPeak = TmSnPeak, TmSnEvDt = TmSnEvDt, TmSnTrCs = TmSnTrCs);
    end
    
    %% Prediction of dataset
    if PreExistPredictions || (EvId > 1)
        CheckDate = (CurrDate == [EventsInfo{'PredictionDate', :}{:}]);
        % CheckStdy = not(area(intersect(StudyAreaPolygon, [EventsInfo{'StudyAreaPolygon', :}{:}])) == 0); % Super slow!
        CheckStdy = false(size(CheckDate));
        CheckSize = (SizeDTM == [EventsInfo{'SizeOfDTM', :}{:}]);
    
        EqualAnls = all([CheckDate; CheckStdy; CheckSize], 1);
    
        if any(EqualAnls)
            warning(['This event is comprised already in your predictions (or at ', ...
                     'least a part)! Please take a look at PredictionsStudy.mat'])
        end
    end
    
    ProgressBar.Indeterminate = 'off';
    PredProbsCell = cell(1, size(MLMdl, 2));
    if Parallel
        ProgressBar.Message = 'Predictions of study area with parallelization...';
        ModelsToUse = [MLMdl{'Model',:}];
        parfor i1 = 1:size(MLMdl, 2)
            CurrMdl = ModelsToUse{i1};
            PredProbsCell{i1} = mdlpredict(CurrMdl, Dset2PredFts);
        end
    else
        for i1 = 1:size(MLMdl, 2)
            ProgressBar.Message = ['Predictions with model n. ',num2str(i1),' of ',num2str(size(MLMdl, 2))];
            ProgressBar.Value   = i1/size(MLMdl, 2);
        
            CurrMdl = MLMdl{'Model',i1}{:};
            PredProbsCell{i1} = mdlpredict(CurrMdl, Dset2PredFts);
        end
    end
    ProgressBar.Indeterminate = 'on';
    
    %% Creation (or update) of tables
    SuggFldNm = ['Ev-',num2str(size(EventsInfo, 2)+1)];
    if MnNmngEv
        EventName = {char(inputdlg2({'Current event name:'}, 'DefInp',SuggFldNm))};
    else
        EventName = SuggFldNm;
    end
    MdlsNames = MLMdl.Properties.VariableNames;
    
    RowEvs2Wr = {'PredictionDate', 'Municipalities', 'SizeOfDTM', 'StudyAreaPolygon'};
    EventsInfo{RowEvs2Wr, EventName} = {CurrDate, MunSel, SizeDTM, StudyAreaPolygon}';
    
    PredProbs{EventName, MdlsNames} = cellfun(@(x) sparse(double(round(x, 2))), PredProbsCell, 'UniformOutput',false);
    LandPolys{EventName, {'UnstablePolygons','StablePolygons','LandslideDay'}} = {UnstPlys, StabPlys, LandsDay(EvId)};
    
    %% Extraction of points inside Unstable and Stable areas (polygons)
    if isscalar(UnstPlys)
        StabPlysMrgd = StabPlys;
        UnstPlysMrgd = UnstPlys;
    else
        StabPlysMrgd = union(StabPlys);
        UnstPlysMrgd = union(UnstPlys);
    end
    
    [pp1, ee1] = getnan2([UnstPlysMrgd.Vertices; nan, nan]);
    IdPntsUnstMrgd = find(inpoly([Dset2PredCrd.Longitude,Dset2PredCrd.Latitude], pp1,ee1));
    
    [pp2, ee2] = getnan2([StabPlysMrgd.Vertices; nan, nan]);
    IdPntsStabMrgd = find(inpoly([Dset2PredCrd.Longitude,Dset2PredCrd.Latitude], pp2,ee2));

    DsetFtsPlys = Dset2PredFts([IdPntsUnstMrgd;IdPntsStabMrgd], :);
    DsetCrdPlys = Dset2PredCrd([IdPntsUnstMrgd;IdPntsStabMrgd], :);
    DsetDtsPlys = table(repmat(CurrDate, size(DsetCrdPlys, 1), 1), ...
                        repmat(LandsDay(EvId), size(DsetCrdPlys, 1), 1), 'VariableNames',{'Datetime', 'LandslideEvent'});
    
    if LandsDay(EvId)
        RealOutPlys = [ ones(size(IdPntsUnstMrgd));
                        zeros(size(IdPntsStabMrgd)) ];
    else
        RealOutPlys = [ zeros(size(IdPntsUnstMrgd));
                        zeros(size(IdPntsStabMrgd)) ];
    end

    DsetTblPly{EventName,'Tables'} = {cell2table({DsetFtsPlys, RealOutPlys, ...
                                                  DsetDtsPlys, DsetCrdPlys}, 'VariableNames',{'Feats','ExpOuts', ...
                                                                                              'Dates','Coordinates'}, ...
                                                                             'RowNames',{'Total'})};
    
    %% Evaluation of quality
    [MSEQ, AUCQ] = deal(zeros(1, size(MLMdl, 2)));
    [FPR4ROC_4Q, TPR4ROC_4Q, ...
            ThrROC_4Q, OptPnt_4Q] = deal(cell(1, size(MLMdl, 2)));
    if Parallel
        ProgressBar.Message = 'Computing quality for dataset in parallel...';
        IsLndDay = LandsDay(EvId);
        parfor i1 = 1:size(MLMdl, 2)
            PredPrbsTmp = [PredProbsCell{i1}(IdPntsUnstMrgd);
                           PredProbsCell{i1}(IdPntsStabMrgd)];
        
            MSEQ(i1) = mse(RealOutPlys, PredPrbsTmp);
        
            if IsLndDay
                [FPR4ROC_4Q{i1}, TPR4ROC_4Q{i1}, ThrROC_4Q{i1}, ...
                        AUCQ(i1), OptPnt_4Q{i1}] = perfcurve(RealOutPlys, PredPrbsTmp, 1);
            end
        end
        delete(ProgressParallel);
    else
        for i1 = 1:size(MLMdl, 2)
            ProgressBar.Message = ['Predicting dataset for quality n. ',num2str(i1),' of ',num2str(size(MLMdl, 2))];
    
            PredPrbsTmp = [PredProbsCell{i1}(IdPntsUnstMrgd);
                           PredProbsCell{i1}(IdPntsStabMrgd)];
        
            MSEQ(i1) = mse(RealOutPlys, PredPrbsTmp);
        
            if LandsDay(EvId)
                [FPR4ROC_4Q{i1}, TPR4ROC_4Q{i1}, ThrROC_4Q{i1}, ...
                        AUCQ(i1), OptPnt_4Q{i1}] = perfcurve(RealOutPlys, PredPrbsTmp, 1);
            end
        end
    end

    clear('PredProbsCell', 'PredPrbsTmp')
    
    %% Extraction of best threshold
    BThQ = nan(1, size(MLMdl, 2));
    if LandsDay(EvId)
        MtBstTh = ModelInfo.BestThrMethod;
        for i1 = 1:size(MLMdl, 2)
            switch MtBstTh
                case 'MATLAB'
                    % Method integrated in MATLAB
                    IdBsTh4Q = find(ismember([FPR4ROC_4Q{i1}, TPR4ROC_4Q{i1}], OptPnt_4Q{i1}, 'rows'));
                    BThQ(i1) = ThrROC_4Q{i1}(IdBsTh4Q);
            
                case 'MaximizeRatio-TPR-FPR'
                    % Method max ratio TPR/FPR
                    RatTPR_FPR_4Q = TPR4ROC_4Q{i1}./FPR4ROC_4Q{i1};
                    RatTPR_FPR_4Q(isinf(RatTPR_FPR_4Q)) = nan;
                    [~, IdBsTh4Q] = max(RatTPR_FPR_4Q);
                    BThQ(i1) = ThrROC_4Q{i1}(IdBsTh4Q);
            
                case 'MaximizeArea-TPR-TNR'
                    % Method max product TPR*TNR
                    AreTPR_TNR_4Q = TPR4ROC_4Q{i1}.*(1-FPR4ROC_4Q{i1});
                    [~, IdBsTh4Q] = max(AreTPR_TNR_4Q);
                    BThQ(i1) = ThrROC_4Q{i1}(IdBsTh4Q);
            end
        end
    end
    
    %% Writing (or updating) tables
    EventsPerf.MSE{EventName,MdlsNames  } = MSEQ;
    EventsPerf.AUROC{EventName,MdlsNames} = AUCQ;
    EventsPerf.BT{EventName,MdlsNames   } = BThQ;
end

%% Saving
ProgressBar.Message  = "Saving files...";
VariablesPredictions = {'PredProbs', 'LandPolys', ...
                        'EventsInfo','EventsPerf'};
saveswitch([fold_res_ml_curr,sl,'PredictionsStudy.mat'], VariablesPredictions)

%% Check part
if ClstPnts || PltPolys
    Ev2Check = listdlg2({'Event to check:'}, PredProbs.Properties.RowNames);
end

%% Clusterization
if ClstPnts
    ProgressBar.Message = 'Defining clusters for unstab points...';

    load([fold_var,sl,'MorphologyParameters.mat'], 'OriginalProjCRS')
    if exist('OriginalProjCRS', 'var')
        EPSG = OriginalProjCRS;
    else
        EPSG = str2double(inputdlg2({['DTM EPSG for clusters (Sicily -> 32633; ', ...
                                      'Emilia Romagna -> 25832):']}, 'DefInp',{'25832'}));
    end

    [~, BstMdlMSE4Ql] = min(EventsPerf.MSE{Ev2Check,:}); % In terms of loss
    [~, BstMdlAUC4Ql] = max(EventsPerf.AUROC{Ev2Check,:}); % In terms of AUC

    Mdl2Tk = listdlg2({['Model to use? (Best loss: ',MLMdl.Properties.VariableNames{BstMdlMSE4Ql}, ...
                        '; Best AUC: ',MLMdl.Properties.VariableNames{BstMdlAUC4Ql}]}, MLMdl.Properties.VariableNames);

    [~, ClassCrds, ClassClrs, ~] = clusterize_points(Dset2PredCrd.Longitude, ...
                                                     Dset2PredCrd.Latitude, ...
                                                     PredProbs{Ev2Check,Mdl2Tk}{:}, 'Threshold',ThrAUROC, ...
                                                                                    'EPSG',EPSG, 'MinPopulation',6);
    
    disp(['Identified ',num2str(numel(ClassClrs)),' landslides in your area.'])

    % Plot for check
    [~, AxsChk] = check_plot(fold0);
    
    ClsCrdsCat = cat(1, ClassCrds{:});
    PltClrsCat = cellfun(@(x,y) repmat(y, size(x,1), 1), ClassCrds, ClassClrs, 'UniformOutput',false);
    PltClrsCat = cat(1, PltClrsCat{:});
    PltPixelSz = 2;
    
    PlotClusts = scatter(ClsCrdsCat(:,1), ClsCrdsCat(:,2), PltPixelSz, ...
                                PltClrsCat, 'Filled', 'Marker','s', 'Parent',AxsChk);
    
    title('Clusters')
end

%% Choose of type of results
if PltPolys
    ProgressBar.Message = 'Plot polygons...';

    load([fold_res_ml_curr,sl,'ANNsMdlB.mat'], 'ANNsPerf')

    DsetPlyChk = DsetTblPly{Ev2Check, :}{:};

    check_plot_mdlb(MLMdl, ANNsPerf, DsetPlyChk, {UnstPlys, IndePlys, StabPlys}, true, 30, true)
end