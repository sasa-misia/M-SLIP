if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

rng(10) % For reproducibility of the model

%% Loading data and initialization of variables
sl = filesep;
load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'SubArea','FilesDetectedSoilSlip')
% load([fold_var,sl,'GridCoordinates.mat'      ], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load([fold_var,sl,'StudyAreaVariables.mat'   ], 'StudyAreaPolygon')

IdDet2Use = 1;
if not(isscalar(FilesDetectedSoilSlip))
    IdDet2Use = listdlg2('Choose dataset you want to use: ', FilesDetectedSoilSlip, 'OutType','NumInd');
end

Rngs4Norm = table;
LndsldDay = true;
CritSlope = nan;
EventDate = nan;
DaysForTS = nan;
TmSnsMode = "";
CauseMode = "";
RsmplMode = nan;
Ratio2Imp = nan;
MntUnstPt = true;

%% Pre existing DatasetML check
[Add2OldDset, OldSettings] = deal(false);
if exist([fold_var,sl,'DatasetMLB.mat'], 'file')
    Options = {'Yes, add this to the old one.', 'No, overwite it!'};
    MergeDataAns = uiconfirm(Fig, ['A pre-existing dataset for ML has been found. ' ...
                                   'Do you want to merge this new one with the old?'], ...
                                  'Merge datasets', 'Options',Options, 'DefaultOption',1);
    if strcmp(MergeDataAns, 'Yes, add this to the old one.')
        Add2OldDset = true;

        load([fold_var,sl,'DatasetMLB.mat'], 'DatasetInfo','Rngs4Norm')
        DatasetInfoOld = DatasetInfo;

        Options = {'Yes, please', 'No, use different settings'};
        OldSettingsAns = uiconfirm(Fig, 'Do you want to mantain settings of the old one?', ...
                                        'Dataset settings', 'Options',Options, 'DefaultOption',1);
        if strcmp(OldSettingsAns, 'Yes, please'); OldSettings = true; end
    else
        UseOldRanges = uiconfirm(Fig, 'Do you want to use old ranges?', ...
                                      'Old ranges', 'Options',{'Yes','No'}, 'DefaultOption',1);
        if strcmp(UseOldRanges, 'Yes')
            load([fold_var,sl,'DatasetMLB.mat'], 'Rngs4Norm')
        end
    end
end

%% Dataset options
ProgressBar.Message = 'Dataset options...';

if Add2OldDset
    FeaturesChn = DatasetInfoOld.Parameters{end};
else
    FeaturesOps = {'Elevation', 'Slope', 'Aspect angle', 'Mean curvature', 'Profile curvature', ...
                   'Planform curvature', 'Contributing area (log)', 'TWI', 'Clay content', ...
                   'Sand content', 'NDVI', 'Sub Soil', 'Top Soil', 'Land use', 'Vegetation', ...
                   'Distances to roads', 'Random', 'Rainfall', 'Temperature', 'Veg probs'};
    FeaturesChn = checkbox2(FeaturesOps, 'Title',{'Select features to use:'});
end

TmSensExs = false;
if any(strcmp(FeaturesChn, 'Rainfall')) || any(strcmp(FeaturesChn, 'Temperature'))
    if Add2OldDset
        TmSnsMode = DatasetInfoOld.TimeSensMode{end};
    else
        TmSnsMode = char(listdlg2({'Time sensitive mode?'}, {'CondensedDays', 'SeparateDays', 'TriggerCausePeak'}));
    end

    if Add2OldDset && OldSettings
        MultDayAnl = DatasetInfoOld.MultipleDays(end);
    else
        MultDayChc = uiconfirm(Fig, 'Do you want to add the NO landslide day?', ...
                                    'Time sensitive analyses', 'Options',{'Yes', 'No, just one'}, 'DefaultOption',2);
        if strcmp(MultDayChc,'Yes'); MultDayAnl = true; else; MultDayAnl = false; end
    end

    TmSensExs = true;
end

if Add2OldDset
    NormData = DatasetInfoOld.NormalizedData(end);
    CtgExist = DatasetInfoOld.CategClasses(end);
    CreateCV = DatasetInfoOld.CrossValidSet(end);
    CreateNV = DatasetInfoOld.NormValidSet(end);
else
    DtOptAns = checkbox2({'Normalize data', 'Use classes', 'CV set', 'NV set'}, 'DefInp',[1, 0, 1, 1], 'OutType','LogInd');
    NormData = DtOptAns(1);
    CtgExist = DtOptAns(2);
    CreateCV = DtOptAns(3);
    CreateNV = DtOptAns(4);
end

PerfMode = char(listdlg2({'Split mode (test, validation, cross)'}, {'RandomSplit', 'PolySplit'}));
PerfMetr = struct('TestPerc',nan, 'NVPerc',nan, 'CVFolds',nan, ...
                  'PolySplit',struct('Train',nan, 'Test',nan, ...
                                     'NvTrn',nan, 'NvVal',nan, 'CvVal',nan));
switch PerfMode % Test
    case 'RandomSplit'
        PerfMetr.TestPerc = str2double(inputdlg2({'Percentage for test:'}, 'DefInp',{'0.3'}));
        if PerfMetr.TestPerc >= .5 || PerfMetr.TestPerc <= 0
            error('The percentage must be in a range from 0 to 0.5, both not included!')
        end

        if CreateNV
            PerfMetr.NVPerc = str2double(inputdlg2({'Percentage for validation (NV, over training):'}, 'DefInp',{'0.3'}));
            if PerfMetr.NVPerc >= .5 || PerfMetr.NVPerc <= 0
                error('The percentage must be in a range from 0 to 0.5, both not included!')
            end
        end

        if CreateCV && not(Add2OldDset)
            PerfMetr.CVFolds = round(str2double(inputdlg2({'Number of k-folds (CV):'}, 'DefInp',{'10'})));
            if PerfMetr.CVFolds <= 1
                error('The number of k-folds must be integer and > 1!')
            end
        end

    case 'PolySplit'
        disp('Since you have selected polysplit, later a prompt will ask you polygons.')

    otherwise 
        error('Perc mode not recognized!')
end

if CreateCV && Add2OldDset
    PerfMetr.CVFolds = DatasetInfoOld{end,'DsetSplitMetr'}.CVFolds;
end

if SubArea
    UnstPlyMode = char(listdlg2({'Unstable area?'}, {'ManualSquares', 'PolygonsOfInfoDetected'}));
else
    UnstPlyMode = 'ManualSquares';
end

if Add2OldDset && OldSettings
    StabPntsApp = DatasetInfoOld.StabAreaApproach{end};
    if strcmp(StabPntsApp, 'SlopeOutsideUnstable')
        CritSlope = DatasetInfoOld.CriticalSlope(end);
    end
    InpBffSzs = DatasetInfoOld.InputBufferSizes{end};
    ModifyRat = DatasetInfoOld.ModifyRatioOuts(end);
    if ModifyRat
        RatioInps = table2array(DatasetInfoOld.RatioClasses{end})';
        Ratio2Imp = RatioInps(1)/RatioInps(2);
        RsmplMode = DatasetInfoOld.Resampling(end);
        if exist('MultDayAnl', 'var') && MultDayAnl
            MntUnstPt = DatasetInfoOld.UnstPointsMant(end);
        end
    end

else
    StabPntsApp = char(listdlg2({'Stable points mode:'}, ...
                                {'BufferedUnstablePolygons', 'SlopeOutsideUnstable', 'AllOutsideUnstable'}));

    if strcmp(StabPntsApp, 'SlopeOutsideUnstable')
        CritSlope = str2double(inputdlg2({"Critical slope (below you have stable points)"}, 'DefInp',{'8'}));
    end
    
    if strcmp(UnstPlyMode, 'PolygonsOfInfoDetected')
        PromptBuffer = ["Buffer of indecision area [m]"
                        "Buffer of stable area [m]"    ];
        SuggBuffVals = {'100', '250'};
    else
        PromptBuffer = ["Window side of unstable points"
                        "Window side of indecision area"
                        "Window side of stable area"    ];
        SuggBuffVals = {'45', '200', '300'};
    end
    
    if any(strcmp(StabPntsApp, {'SlopeOutsideUnstable','AllOutsideUnstable'}))
        PromptBuffer(end) = [];
        SuggBuffVals(end) = [];
    end
    
    InpBffSzs = str2double(inputdlg2(PromptBuffer, 'DefInp',SuggBuffVals));
    
    ModRatAns = uiconfirm(Fig, 'Do you want to resample dataset (rebalancing)?', ...
                               'Resampling', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
    if strcmp(ModRatAns,'Yes'); ModifyRat = true; else; ModifyRat = false; end
    if ModifyRat
        RatioInps = str2double(inputdlg2({'Part of unstable:', 'Part of stable:'}, 'DefInp',{'1', '2'})');
        Ratio2Imp = RatioInps(1)/RatioInps(2);
        RsmplMode = char(listdlg2({'Resampling data approach?'}, {'Undersampling', 'Oversampling', 'SMOTE'}));
    
        if exist('MultDayAnl', 'var') && MultDayAnl && strcmp(RsmplMode,'Undersampling')
            MntUnstChc = uiconfirm(Fig, ['Do you want to mantain points where there is instability ' ...
                                         'also in the day when all points are stable? ' ...
                                         '(these points will be mantained during the merge and ' ...
                                         'the subsequent ratio adjustment)'], 'Mantain unstable points', ...
                                        'Options',{'Yes', 'No'}, 'DefaultOption',1);
            if strcmp(MntUnstChc,'No'); MntUnstPt = false; end
        end
    end
end

switch StabPntsApp
    case {'SlopeOutsideUnstable'}
        PolyStableMode = 'AllOutside';
        StableMethod   = 'Slope';

    case {'AllOutsideUnstable'}
        PolyStableMode = 'AllOutside';
        StableMethod   = 'EntireStable';

    case {'BufferedUnstablePolygons'}
        PolyStableMode = 'Buffer';
        StableMethod   = 'EntireStable';
end

%% Writing DatasetStudyInfo
DatasetStudyInfo = table;

DatasetStudyInfo.FullPathInfoDet  = string(FilesDetectedSoilSlip(IdDet2Use)); % Before was string([fold_raw_det_ss,sl,char(FilesDetectedSoilSlip(IndDetToUse))]); or you should modify at row 13, mantaining only names and not full path and put it again!
DatasetStudyInfo.Parameters       = {FeaturesChn};
DatasetStudyInfo.NormalizedData   = NormData;
DatasetStudyInfo.CategClasses     = CtgExist;
DatasetStudyInfo.CrossValidSet    = CreateCV;
DatasetStudyInfo.NormValidSet     = CreateNV;
DatasetStudyInfo.DsetSplitMode    = string(PerfMode); % string() to allow concatenation of different lengths
DatasetStudyInfo.DsetSplitMetr    = PerfMetr;
DatasetStudyInfo.UnstPolygonsMode = string(UnstPlyMode);
DatasetStudyInfo.StabAreaApproach = string(StabPntsApp);
if strcmp(StabPntsApp,'SlopeOutsideUnstable')
    DatasetStudyInfo.CriticalSlope = CritSlope;
end
DatasetStudyInfo.InputBufferSizes = {InpBffSzs};
DatasetStudyInfo.ModifyRatioOuts  = ModifyRat;
if ModifyRat
    DatasetStudyInfo.RatioClasses = {array2table(RatioInps', 'VariableNames',{'UnstablePart','StablePart'})};
    DatasetStudyInfo.Resampling   = string(RsmplMode);
    if MultDayAnl
        DatasetStudyInfo.UnstPointsMant = MntUnstPt;
    end
end

%% ANN time sensitive additional options
if TmSensExs
    TmSensDts = {};
    
    % Rainfall
    if any(strcmp(FeaturesChn, 'Rainfall'))
        load([fold_var,sl,'RainInterpolated.mat'], 'RainDateInterpolationStarts')
        TmSensDts = [TmSensDts, {RainDateInterpolationStarts}];
        TmSensExs = true;
    end
    
    % Temperature
    if any(strcmp(FeaturesChn, 'Temperature'))
        load([fold_var,sl,'TempInterpolated.mat'], 'TempDateInterpolationStarts')
        TmSensDts = [TmSensDts, {TempDateInterpolationStarts}];
        TmSensExs = true;
    end
    
    % Uniformization of time sensitive part
    StrDateCmm = max(cellfun(@min, TmSensDts)); % Start in end dates
    EndDateCmm = min(cellfun(@max, TmSensDts)); % End in end dates
    
    if EndDateCmm < StrDateCmm
        error(['Time sensitive part has no datetime in common!', ...
               ' Please re-interpolate time sensitive part.'])
    end
    
    if length(TmSensDts) > 1
        for i1 = 1:numel(TmSensDts)
            IndStartCmm = find(StrDateCmm == TmSensDts{i1}); % You should put an equal related to days and not exact timing
            IndEventCmm = find(EndDateCmm == TmSensDts{i1}); % You should put an equal related to days and not exact timing
            TmSensDts{i1} = TmSensDts{i1}(IndStartCmm:IndEventCmm);
        end
        if length(TmSensDts)>1 && ~isequal(TmSensDts{:})
            error(['After uniformization of dates in time sensitive part, number ', ...
                   'of elements is not consistent! Please check it in the script.'])
        end
    end
    
    TmSensDts = TmSensDts{1}; % Taking only the first one since they are identical!
    
    IndsEvAns = listdlg2({'Event date (start of 24 h):', 'Is this a landslide day?'}, ...
                         {TmSensDts, {'Yes', 'No'}}, 'OutType','NumInd');
    IndOfEvnt = IndsEvAns(1);
    EventDate = TmSensDts(IndOfEvnt);
    if IndsEvAns(2) == 1; LndsldDay = true; else; LndsldDay = false; end

    % User choice about days to consider
    MaxDaysPoss = IndOfEvnt;
    if MultDayAnl
        if Add2OldDset && OldSettings
            DaysBfWhStb = DatasetInfoOld.DayBeforeEvent(end);

            if (IndOfEvnt-DaysBfWhStb) <= 0
                error(['Since you want to add this dataset to the old one, ', ...
                       'you need more recording datetimes for TS. You need', ...
                       num2str(-IndOfEvnt+DaysBfWhStb),' more days in recs!'])
            end
        else
            DaysBfWhStb = str2double(inputdlg2({['Days before event, when all points are stable. (', ...
                                                 num2str(IndOfEvnt),' days of cum rain to your event)']}, 'DefInp',{'10'}));

            if (IndOfEvnt-DaysBfWhStb) <= 0
                error(['You have to select another day for stable points, ', ...
                       'more forward in time than the start of your dataset'])
            end
        end

        MaxDaysPoss = IndOfEvnt - DaysBfWhStb;
        BefEvntDate = EventDate - days(DaysBfWhStb);
    end

    if Add2OldDset % Important: do not add OldSettings because, even if you don't want the OldSettings, this parameter MUST BE the same!
        DaysForTS = DatasetInfoOld.DaysForTS{end};
        if (MaxDaysPoss - max(DaysForTS)) < 0
            error(['Since you want to add this dataset to the old one, you need more ', ...
                   num2str(abs(MaxDaysPoss-max(DaysForTS))),' days in recs!'])
        end
        if strcmp(TmSnsMode,'TriggerCausePeak')
            CauseMode = DatasetInfoOld.CauseMode{end};
        end

    else
        switch TmSnsMode
            case 'SeparateDays'
                DaysForTS = str2num(inputdlg2({['Num of days (max ',num2str(MaxDaysPoss),') to consider:']}, 'DefInp',{['[',num2str(MaxDaysPoss),']']}));
        
            case 'CondensedDays'
                DaysForTS = str2num(inputdlg2({['Days to cumulate/average (max ',num2str(MaxDaysPoss),')']}, 'DefInp',{['[',num2str(MaxDaysPoss),']']}));

            case 'TriggerCausePeak'
                DaysForTS = str2num(char(inputdlg2({['Days for cause rain (max ',num2str(MaxDaysPoss-2),')']}, 'DefInp',{['[',num2str(MaxDaysPoss-2),']']}))); % -2 because script is set to search an event in a time window of max 2 days before or after
                CauseMode = char(listdlg2({'Cause rainfall type?'}, {'DailyCumulate', 'EventsCumulate'}));
        end

        if (MaxDaysPoss - max(DaysForTS)) < 0
            error('You have to select fewer days than the maximum possible (or you have to change matrix of daily rainfalls)')
        end
    end

    % Continuing to write DatasetStudyInfo
    DatasetStudyInfo.EventDate      = EventDate;
    DatasetStudyInfo.LandslideEvent = LndsldDay;
    DatasetStudyInfo.TimeSensMode   = string(TmSnsMode);
    if strcmp(TmSnsMode,'TriggerCausePeak')
        DatasetStudyInfo.CauseMode  = string(CauseMode);
    end
    DatasetStudyInfo.MultipleDays = MultDayAnl;
    if MultDayAnl
        DatasetStudyInfo.BeforeEventDate = BefEvntDate;
        DatasetStudyInfo.DayBeforeEvent  = DaysBfWhStb;
    else
        DatasetStudyInfo.BeforeEventDate = NaT;
        DatasetStudyInfo.DayBeforeEvent  = NaN;
    end
    DatasetStudyInfo.DaysForTS = {DaysForTS};
end

%% Check for changes compared to eventual old dataset
if Add2OldDset
    Vars2Chck = {'UnstPolygonsMode', 'StabAreaApproach', 'InputBufferSizes', 'ModifyRatioOuts', 'RatioClasses', 'Resampling', 'LandslideEvent', 'MultipleDays'};
    CheckVars = false(size(DatasetInfoOld, 1), length(Vars2Chck));
    for i1 = 1:length(Vars2Chck)
        for i2 = 1:size(DatasetInfoOld, 1)
            CheckVars(i2, i1) = isequal(DatasetStudyInfo.(Vars2Chck{i1}), DatasetInfoOld{i2, Vars2Chck{i1}});
        end
    end
    CheckVars = any(all(CheckVars, 2));

    [~, NewDetSSName] = fileparts(DatasetStudyInfo.FullPathInfoDet);
    [~, OldDetSSName] = fileparts(cellstr(DatasetInfoOld.FullPathInfoDet));

    CheckNmes = any(strcmp(NewDetSSName, OldDetSSName));

    HourToler = 23;
    CheckTime = any(abs(hours(DatasetStudyInfo.EventDate - DatasetInfoOld.EventDate)) < HourToler);

    IdentDset = CheckTime && CheckNmes && CheckVars;
    if IdentDset
        error(['Dataset that you are trying to add is already inside the old one ' ...
               '(or it is too similar)! Please overwrite it or change event to add.'])
    elseif not(IdentDset) && CheckTime
        warning(['Dataset that you want is not exactly identical but the date you ' ...
                 'chosed is very near to another already inside!'])
    end
end

%% Datasets creation
[DatasetStudyFeats, DatasetStudyCoords, ...
    Rngs4Norm, TimeSensPart, DatasetStudyFtsOg, ...
        FeaturesType, ClassPolys] = datasetstudy_creation( fold0, 'Features',FeaturesChn, ...
                                                                  'Categorical',CtgExist, ...
                                                                  'Normalize',NormData, ...
                                                                  'TargetFig',Fig, ...
                                                                  'DayOfEvent',EventDate, ...
                                                                  'DaysForTS',DaysForTS, ...
                                                                  'TimeSensMode',TmSnsMode, ...
                                                                  'CauseMode',CauseMode, ...
                                                                  'Ranges',Rngs4Norm );

FeatsNames = DatasetStudyFeats.Properties.VariableNames;

if TmSensExs
    TmSnsPrms = TimeSensPart.ParamNames;
    CumlbPrms = TimeSensPart.Cumulable;
    TmSensDts = TimeSensPart.Datetimes;
    TmSnsData = TimeSensPart.Data;
    [TmSnsTrg, TmSnsPks, TmSnsEvD] = deal({});
    if strcmp(TmSnsMode,'TriggerCausePeak')
        TmSnsTrg = TimeSensPart.TriggAmountPerEvent;
        TmSnsPks = TimeSensPart.PeaksPerEvent;
        TmSnsEvD = TimeSensPart.DatesPerEvent;
        StrDtTrg = TimeSensPart.StartDateTriggering;
        HoursDff = abs(EventDate - StrDtTrg);
        if HoursDff >= hours(1)
            warning(['There is a difference of ',num2str(hours(HoursDff)), ...
                     'h between data you chosed and the start of the triggering!', ...
                     ' Event date will be overwrite.'])
        end
    end

    if not(isequal(EventDate, TimeSensPart.EventTime))
        error('Datetime of DatasetStudy and the one you chosed do not match! Please check "datasetstudy_creation" function')
    end
end

%% Continuing to write DatasetStudyInfo
DatasetStudyInfo.FeaturesNames = {FeatsNames};
DatasetStudyInfo.FeaturesTypes = {FeaturesType};
DatasetStudyInfo.ClassPolygons = {ClassPolys};
if TmSensExs
    DatasetStudyInfo.TSParameters = {TmSnsPrms};
    DatasetStudyInfo.TSCumulable  = {CumlbPrms};
end

%% R2 Correlation coefficients for Study Area
ProgressBar.Message = 'Creation of correlation matrix...';

R2ForDatasetStudyFeats = feats_correlation(DatasetStudyFeats);
R2ForDatasetStudyFtsOg = feats_correlation(DatasetStudyFtsOg);

%% Statistics of study area
ProgressBar.Message = 'Statistics of study area...';

[TempNormStats, TempNotNormStats] = deal(array2table(nan(size(DatasetStudyFeats,2), 4), ...
                                                                'VariableNames',{'1stQuantile','3rdQuantile','MinExtreme','MaxExtreme'}, ...
                                                                'RowNames',FeatsNames));
for i1 = 1:length(FeatsNames)
    if strcmp(FeaturesType(i1),'Categorical'); continue; end
    TempNormStats{FeatsNames{i1}, 1:2} = quantile(DatasetStudyFeats.(FeatsNames{i1}), [0.25, 0.75]);
    TempNormStats{FeatsNames{i1}, 3:4} = [min(DatasetStudyFeats.(FeatsNames{i1})), ...
                                             max(DatasetStudyFeats.(FeatsNames{i1}))];

    TempNotNormStats{FeatsNames{i1}, 1:2} = quantile(DatasetStudyFtsOg.(FeatsNames{i1}), [0.25, 0.75]);
    TempNotNormStats{FeatsNames{i1}, 3:4} = [min(DatasetStudyFtsOg.(FeatsNames{i1})), ...
                                             max(DatasetStudyFtsOg.(FeatsNames{i1}))];
end

DatasetStudyStats = table({TempNormStats}, {TempNotNormStats}, 'VariableNames',{'Normalized', 'NotNormalized'});

%% Creation of landslides, indecision, and stable polygons
ProgressBar.Message = 'Creation of polygons...';

[UnstablePolygons, StablePolygons, ...
        IndecisionPolygons] = polygons_landslides(fold0, 'StableMode',PolyStableMode, ...
                                                         'UnstableMode',UnstPlyMode, ...
                                                         'BufferSizes',InpBffSzs, ...
                                                         'CreationCoordinates','Planar', ...
                                                         'PolyOutputMode','Multi', ...
                                                         'IndOfInfoDetToUse',IdDet2Use);

UnstPolyMrgd = union(UnstablePolygons);
IndePolyMrgd = union(IndecisionPolygons);
StabPolyMrgd = union(StablePolygons);

% Definition of polygons to mantain for test, validation, and cross (eventually)
switch PerfMode
    case 'RandomSplit'

    case 'PolySplit'
        fig_ply = figure(1);
        axs_ply = axes(fig_ply);
        hold(axs_ply,'on')

        plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1.5)
        plot(UnstablePolygons, 'FaceColor','#e95833', 'EdgeColor','k', 'LineWidth',1)
        plot(StablePolygons, 'FaceColor','#7dffc4', 'EdgeColor','k', 'LineWidth',1)

        NumPolyTot = 1:numel(UnstablePolygons);
        [xCntrUn, yCntrUn] = centroid(UnstablePolygons);
        text(xCntrUn, yCntrUn, string(NumPolyTot))

        yLatMean = mean(yCntrUn);
        dLat1Met = rad2deg(1/earthRadius); % 1 m in lat
        dLon1Met = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long
        
        RatLatLong = dLat1Met/dLon1Met;
        daspect([1, RatLatLong, 1])

        if not(Add2OldDset)
            PerfMetr.CVFolds = round(str2double(inputdlg2({['Number of CV gropus (',num2str(numel(NumPolyTot)),' polygons)']}, 'DefInp',{'10'})));
        end

        IndPolyTst = checkbox2(strcat("Polygon n. ",string(NumPolyTot)), 'OutType','LogInd', 'Title','Polygons for test:');
        NumPolyTrn = NumPolyTot(not(IndPolyTst));

        if isempty(NumPolyTrn)
            error('You can not select all the polygons for test!')
        end

        PerfMetr.PolySplit.Train = NumPolyTrn;
        PerfMetr.PolySplit.Test  = NumPolyTot(IndPolyTst);

        if CreateNV
            if isscalar(NumPolyTrn); error('You must have more than 2 polygon remained in train!'); end
            IndPolyValNV = checkbox2(strcat("Polygon n. ",string(NumPolyTrn)), 'OutType','LogInd', 'Title','Polygons for validation:');
            if all(IndPolyValNV)
                error('You can not select all the polygons for validation!')
            end
            PerfMetr.PolySplit.NvTrn = NumPolyTrn(not(IndPolyValNV));
            PerfMetr.PolySplit.NvVal = NumPolyTrn(IndPolyValNV);
        end

        if CreateCV
            if PerfMetr.CVFolds > numel(NumPolyTrn)
                error('You have more gropus than polygons for cross validation!')
            end

            NumPly2Emp = NumPolyTrn;
            NumPolyCrV = cell(1, PerfMetr.CVFolds);
            for i1 = 1:PerfMetr.CVFolds
                if isempty(NumPly2Emp); error(['No polygons remained for Cv fold n. ',num2str(i1)]); end
                if i1 == PerfMetr.CVFolds
                    IndPolyCVTemp = true(size(NumPly2Emp));
                    disp(['CV fold n. ',num2str(i1),' filled with the remaining polygons!'])
                else
                    IndPolyCVTemp = checkbox2(strcat("Polygon n. ",string(NumPly2Emp)), 'OutType','LogInd', ...
                                                                                        'Title',['Polygons for CV',num2str(i1), ...
                                                                                                 ' of ',num2str(PerfMetr.CVFolds)]);
                end
                NumPolyCrV{i1} = NumPly2Emp(IndPolyCVTemp);
                NumPly2Emp(IndPolyCVTemp) = [];
            end
            PerfMetr.PolySplit.CvVal = NumPolyCrV;
        end

    otherwise
        error('Perf mode not recognized in defining polygons!')
end

%% Continuing to write DatasetStudyInfo
DatasetStudyInfo.PolysUnstable   = {UnstablePolygons};
DatasetStudyInfo.PolysIndecision = {IndecisionPolygons};
DatasetStudyInfo.PolysStable     = {StablePolygons};
DatasetStudyInfo.DsetSplitMetr   = PerfMetr; % Update DsetSplitMetr of DatasetStudyInfo

%% Creation of first part of ML dataset
ProgressBar.Message = 'Indexing of dataset...';

[IndsDsetRedPrt1, ...
    ExpOutsRedPrt1] = dataset_poly_idx(DatasetStudyCoords, DatasetStudyFtsOg, ...
                                       UnstPolyMrgd, StabPolyMrgd, 'StableMethod',StableMethod, ...
                                                                   'ModifyRatio',false, ... % because it must be the total! No rebalance!
                                                                   'DayOfLandslide',LndsldDay, ...
                                                                   'CriticalSlope',CritSlope);

DsetRedCoordPrt1 = DatasetStudyCoords(IndsDsetRedPrt1,:);
DsetRedFeatsPrt1 = DatasetStudyFeats(IndsDsetRedPrt1,:);
DsetRedClassPrt1 = double(ExpOutsRedPrt1);
DsetRedDatesPrt1 = table(repmat(EventDate, size(DsetRedCoordPrt1,1), 1), ...
                         repmat(LndsldDay, size(DsetRedCoordPrt1,1), 1), 'VariableNames',{'Datetime','LandslideEvent'});

%% Creation of a copy to use in analysis (could be made of 2 different days)
if not(MultDayAnl)
    DsetRedDates = DsetRedDatesPrt1;
    DsetRedCoord = DsetRedCoordPrt1;
    DsetRedFeats = DsetRedFeatsPrt1;
    DsetRedClass = DsetRedClassPrt1;

elseif MultDayAnl
    ProgressBar.Message = 'Addition of points in the day of stability';

    DsetRedDatesPrt2 = table(repmat(BefEvntDate, size(DsetRedCoordPrt1,1), 1), ...
                             false(size(DsetRedCoordPrt1,1), 1), 'VariableNames',{'Datetime','LandslideEvent'}); % false because this is the day of not landslide!
    DsetRedCoordPrt2 = DsetRedCoordPrt1;
    for i1 = 1:numel(DaysForTS)
        [DsetRedFeatsPrt2, StrDtNoTrg] = dataset_update_ts(TmSnsData, TmSensDts, BefEvntDate, DsetRedFeatsPrt1, ...
                                                           TmSnsMode, TmSnsPrms, DaysForTS(i1), Rngs4Nrm=Rngs4Norm, ...
                                                           Inds2Tk=IndsDsetRedPrt1, TmSnCmlb=CumlbPrms, TmSnTrgg=TmSnsTrg, ...
                                                           TmSnPeak=TmSnsPks, TmSnEvDt=TmSnsEvD, TmSnTrCs=CauseMode);
    end
    DsetRedClassPrt2 = double(false(size(ExpOutsRedPrt1))); % At this particular timing prediction should be 0! (no landslide)

    DsetRedDates = [DsetRedDatesPrt1; DsetRedDatesPrt2];
    DsetRedCoord = [DsetRedCoordPrt1; DsetRedCoordPrt2];
    DsetRedFeats = [DsetRedFeatsPrt1; DsetRedFeatsPrt2];
    DsetRedClass = [DsetRedClassPrt1; DsetRedClassPrt2];
end

%% Overwriting of dates in DatasetStudyInfo and DatasetMLDates (if TriggerCausePeak)
if TmSensExs && strcmp(TmSnsMode,'TriggerCausePeak')
    DatasetStudyInfo.EventDate = StrDtTrg;
    DsetRedDates.Datetime(DsetRedDates.Datetime == EventDate) = StrDtTrg;
    if MultDayAnl
        DatasetStudyInfo.BeforeEventDate = StrDtNoTrg;
        DatasetStudyInfo.DayBeforeEvent  = ceil(days(StrDtTrg-StrDtNoTrg));
        DsetRedDates.Datetime(DsetRedDates.Datetime == BefEvntDate) = StrDtNoTrg;
    end
end
DatasetInfo = DatasetStudyInfo;

%% Partitioning of datasets (partitions of DsetRedFeats)
switch PerfMode
    case 'RandomSplit'
        PrtDsetTot = cvpartition(DsetRedClass, 'Holdout',PerfMetr.TestPerc);
        IndsTrnLog = training(PrtDsetTot); % Indices for the training set
        IndsTstLog = test(PrtDsetTot);     % Indices for the test set

        if CreateNV
            PrtDsetNrV = cvpartition(DsetRedClass(IndsTrnLog), 'Holdout',PerfMetr.NVPerc); % Must be taken from training dataset!
            IndsNvTrLg = training(PrtDsetNrV); % Indices for the NV training set
            IndsNvVlLg = test(PrtDsetNrV);     % Indices for the NV validation set
        end

        if CreateCV
            PrtCross = cvpartition(DsetRedClass(IndsTrnLog), 'KFold',PerfMetr.CVFolds); % Must be taken from training dataset!

            IndsCvVlLg = deal(cell(1, PerfMetr.CVFolds));
            for i1 = 1:PerfMetr.CVFolds
                IndsCvVlLg{i1} = PrtCross.test(i1);
            end
        end

    case 'PolySplit'
        PlyTrn = union(union(UnstablePolygons(PerfMetr.PolySplit.Train), StablePolygons(PerfMetr.PolySplit.Train)));
        PlyTst = union(union(UnstablePolygons(PerfMetr.PolySplit.Test ), StablePolygons(PerfMetr.PolySplit.Test )));

        [ppTrn, eeTrn] = getnan2([PlyTrn.Vertices; nan, nan]);
        [ppTst, eeTst] = getnan2([PlyTst.Vertices; nan, nan]);

        IndsTrnLog = inpoly([DsetRedCoord.Longitude,DsetRedCoord.Latitude], ppTrn,eeTrn);
        IndsTstLog = inpoly([DsetRedCoord.Longitude,DsetRedCoord.Latitude], ppTst,eeTst);

        if CreateNV
            PlyNvTr = union(union(UnstablePolygons(PerfMetr.PolySplit.NvTrn), StablePolygons(PerfMetr.PolySplit.NvTrn)));
            PlyNvVl = union(union(UnstablePolygons(PerfMetr.PolySplit.NvVal), StablePolygons(PerfMetr.PolySplit.NvVal)));
    
            [ppNvTr, eeNvTr] = getnan2([PlyNvTr.Vertices; nan, nan]);
            [ppNvVl, eeNvVl] = getnan2([PlyNvVl.Vertices; nan, nan]);

            IndsNvTrLg = inpoly([DsetRedCoord.Longitude(IndsTrnLog),DsetRedCoord.Latitude(IndsTrnLog)], ppNvTr,eeNvTr); % Must be taken from training dataset!
            IndsNvVlLg = inpoly([DsetRedCoord.Longitude(IndsTrnLog),DsetRedCoord.Latitude(IndsTrnLog)], ppNvVl,eeNvVl); % Must be taken from training dataset!
        end

        if CreateCV
            IndsCvVlLg = cell(1, PerfMetr.CVFolds);
            for i1 = 1:PerfMetr.CVFolds
                PlyCvVl = union(union(UnstablePolygons(PerfMetr.PolySplit.CvVal{i1}), StablePolygons(PerfMetr.PolySplit.CvVal{i1})));
    
                [ppCvVl, eeCvVl] = getnan2([PlyCvVl.Vertices; nan, nan]);
    
                IndsCvVlLg{i1} = inpoly([DsetRedCoord.Longitude(IndsTrnLog),DsetRedCoord.Latitude(IndsTrnLog)], ppCvVl,eeCvVl); % Must be taken from training dataset!
            end
        end

    otherwise
        error('Perf mode not recognized!')
end

%% Creation of datasets
DsetTrnDates = DsetRedDates(IndsTrnLog, :);
DsetTrnCoord = DsetRedCoord(IndsTrnLog, :);
DsetTrnFeats = DsetRedFeats(IndsTrnLog, :);
DsetTrnClass = DsetRedClass(IndsTrnLog, :);

DsetTstDates = DsetRedDates(IndsTstLog, :);
DsetTstCoord = DsetRedCoord(IndsTstLog, :);
DsetTstFeats = DsetRedFeats(IndsTstLog, :);
DsetTstClass = DsetRedClass(IndsTstLog, :);

if CreateNV
    DsetNvTDates = DsetTrnDates(IndsNvTrLg, :);
    DsetNvTCoord = DsetTrnCoord(IndsNvTrLg, :);
    DsetNvTFeats = DsetTrnFeats(IndsNvTrLg, :);
    DsetNvTClass = DsetTrnClass(IndsNvTrLg, :);
    
    DsetNvVDates = DsetTrnDates(IndsNvVlLg, :);
    DsetNvVCoord = DsetTrnCoord(IndsNvVlLg, :);
    DsetNvVFeats = DsetTrnFeats(IndsNvVlLg, :);
    DsetNvVClass = DsetTrnClass(IndsNvVlLg, :);
end

if CreateCV
    [DsetCvVDates, DsetCvVCoord, DsetCvVFeats, DsetCvVClass] = deal(cell(1, PerfMetr.CVFolds));
    for i1 = 1:PerfMetr.CVFolds
        DsetCvVDates{i1} = DsetTrnDates(IndsCvVlLg{i1}, :);
        DsetCvVCoord{i1} = DsetTrnCoord(IndsCvVlLg{i1}, :);
        DsetCvVFeats{i1} = DsetTrnFeats(IndsCvVlLg{i1}, :);
        DsetCvVClass{i1} = DsetTrnClass(IndsCvVlLg{i1}, :);
    end
end

% Rebalancing
if ModifyRat
    Inds2KpTrn = false(size(DsetTrnCoord, 1), 1);
    Inds2KpTst = false(size(DsetTstCoord, 1), 1);
    if MntUnstPt
        [pUn, eUn] = getnan2([UnstPolyMrgd.Vertices; nan, nan]);
        Inds2KpTrn = inpoly([DsetTrnCoord.Longitude,DsetTrnCoord.Latitude], pUn,eUn);
        Inds2KpTst = inpoly([DsetTstCoord.Longitude,DsetTstCoord.Latitude], pUn,eUn);
    end

    [DsetCll1, DsetCll2, ...
        DsetCll3, ~, DsetCll4] = dataset_rebalance({DsetTrnDates, DsetTstDates}, ... % 1 is Train, 2 is test
                                                   {DsetTrnFeats, DsetTstFeats}, ...
                                                   {DsetTrnClass, DsetTstClass}, ...
                                                   Ratio2Imp, RsmplMode, 'CrucialObs',{Inds2KpTrn, Inds2KpTst}, ...
                                                                         'SuppDataset',{DsetTrnCoord, DsetTstCoord});

    DsetTrnDates = DsetCll1{1}; DsetTrnFeats = DsetCll2{1}; DsetTrnClass = DsetCll3{1}; DsetTrnCoord = DsetCll4{1}; % 1 is Train
    DsetTstDates = DsetCll1{2}; DsetTstFeats = DsetCll2{2}; DsetTstClass = DsetCll3{2}; DsetTstCoord = DsetCll4{2}; % 2 is Test

    if CreateNV
        Inds2KpNvT = false(size(DsetNvTCoord, 1), 1);
        Inds2KpNvV = false(size(DsetNvVCoord, 1), 1);
        if MntUnstPt
            Inds2KpNvT = inpoly([DsetNvTCoord.Longitude,DsetNvTCoord.Latitude], pUn,eUn);
            Inds2KpNvV = inpoly([DsetNvVCoord.Longitude,DsetNvVCoord.Latitude], pUn,eUn);
        end
    
        [DsetCll1V, DsetCll2V, ...
            DsetCll3V, ~, DsetCll4V] = dataset_rebalance({DsetNvTDates, DsetNvVDates}, ... % 1 is NV Train, 2 is NV Validation
                                                         {DsetNvTFeats, DsetNvVFeats}, ...
                                                         {DsetNvTClass, DsetNvVClass}, ...
                                                         Ratio2Imp, RsmplMode, 'CrucialObs',{Inds2KpNvT, Inds2KpNvV}, ...
                                                                               'SuppDataset',{DsetNvTCoord, DsetNvVCoord});
    
        DsetNvTDates = DsetCll1V{1}; DsetNvTFeats = DsetCll2V{1}; DsetNvTClass = DsetCll3V{1}; DsetNvTCoord = DsetCll4V{1}; % 1 is NV Train
        DsetNvVDates = DsetCll1V{2}; DsetNvVFeats = DsetCll2V{2}; DsetNvVClass = DsetCll3V{2}; DsetNvVCoord = DsetCll4V{2}; % 2 is NV Validation
    end

    if CreateCV
        Inds2KpCvV = cell(1, PerfMetr.CVFolds);
        for i1 = 1:PerfMetr.CVFolds
            Inds2KpTmp = false(size(DsetCvVCoord{i1}, 1), 1);
            if MntUnstPt
                Inds2KpTmp = inpoly([DsetCvVCoord{i1}.Longitude,DsetCvVCoord{i1}.Latitude], pUn,eUn);
            end
            Inds2KpCvV{i1} = Inds2KpTmp;
        end
        
        [DsetCvVDates, DsetCvVFeats, ...
            DsetCvVClass, ~, DsetCvVCoord] = dataset_rebalance(DsetCvVDates, DsetCvVFeats, DsetCvVClass, ...
                                                               Ratio2Imp, RsmplMode, 'CrucialObs',Inds2KpCvV, ...
                                                                                     'SuppDataset',DsetCvVCoord);
    end
end

%% Storing of datasets for ML
Datasets = struct();
Datasets.Feats = FeatsNames;

Datasets.Total = struct('Dates',DsetRedDates, 'Coordinates',DsetRedCoord, 'Features',DsetRedFeats, 'Outputs',DsetRedClass);
Datasets.Train = struct('Dates',DsetTrnDates, 'Coordinates',DsetTrnCoord, 'Features',DsetTrnFeats, 'Outputs',DsetTrnClass);
Datasets.Test  = struct('Dates',DsetTstDates, 'Coordinates',DsetTstCoord, 'Features',DsetTstFeats, 'Outputs',DsetTstClass);

if CreateNV
    Datasets.NvTrain = struct('Dates',DsetNvTDates, 'Coordinates',DsetNvTCoord, 'Features',DsetNvTFeats, 'Outputs',DsetNvTClass);
    Datasets.NvValid = struct('Dates',DsetNvVDates, 'Coordinates',DsetNvVCoord, 'Features',DsetNvVFeats, 'Outputs',DsetNvVClass);
end

if CreateCV
    Datasets.CvValid = struct('Dates',DsetCvVDates, 'Coordinates',DsetCvVCoord, 'Features',DsetCvVFeats, 'Outputs',DsetCvVClass);
end

DatasetInfo.Datasets = {Datasets};

%% Aggregation of DatasetML
if Add2OldDset
    ProgressBar.Message = 'Merge of datasets...';
    DatasetInfo = [DatasetInfoOld; DatasetInfo];
end

if size(DatasetInfo, 1) == 1
    AdviceAns = uiconfirm(Fig, ['If you want o add other events/areas to your dataset for ML, ' ...
                                'Please consider to run again all previous scripts with new ' ...
                                'data (different study area, recordings, etc...)'], ...
                               'Merge datasets', 'Options',{'Ok, I understand!'});
end

%% Saving...
ProgressBar.Message = 'Saving files...';
VariablesDatasetStudy = {'DatasetStudyInfo', 'UnstablePolygons', 'IndecisionPolygons', 'StablePolygons', ...
                         'DatasetStudyCoords', 'DatasetStudyFeats', 'DatasetStudyFtsOg', 'DatasetStudyStats', ...
                         'Rngs4Norm', 'R2ForDatasetStudyFeats', 'R2ForDatasetStudyFtsOg'};

VariablesDatasetML = {'DatasetInfo', 'Rngs4Norm'};

saveswitch([fold_var,sl,'DatasetStudy.mat'], VariablesDatasetStudy)
saveswitch([fold_var,sl,'DatasetMLB.mat'  ], VariablesDatasetML)

close(ProgressBar) % Fig instead of ProgressBar if in standalone version