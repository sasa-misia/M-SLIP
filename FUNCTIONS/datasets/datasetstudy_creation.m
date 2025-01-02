function [dsetNorm, dsetCoord, dsetRange, dsetTmSns, dsetOrig, dsetFtsCl, dsetPolys] = datasetstudy_creation(fold0, Options)

% CREATE A DATASET TO USE FOR ML
%   
% Outputs:
%   [dsetNorm, dsetCoord, dsetRange, dsetTmSns, dsetOrig, dsetFtsCl, dsetPolys]
%   
% Required arguments:
%   - fold0 : is to identify the folder in which you have the analysis.
%   
% Optional arguments:
%   - 'Features', cellStringArray : a list of the feature you want to use 
%   (example: 'Features', {'Elevation', 'Slope', 'Rainfall'}).
%   Possible feature are 'Elevation', 'Slope', 'Aspect Angle', 'Mean Curvature', 
%   'Profile Curvature', 'Planform Curvature', 'Contributing Area (log)', 'TWI', 
%   'Clay Content', 'Sand Content', 'NDVI', 'Sub Soil', 'Top Soil', 'Land Use', 
%   'Vegetation', 'Distance To Roads', 'Rainfall', 'Temperature', 'Random'.
%   If you use ('Features', 'AllFeats') or you don't specify anything, then you 
%   will take all of these.
%   
%   - 'Categorical', logical : to choose if you want to consider
%   categorical part (i.e. Sub Soil, Top Soil, Land Use, and Vegetation) as
%   a categorical variable or numerical. If you set ('Categorical', true)
%   then you will consider these variables as categorical, otherwise not.
%   If you don't specify anything, then ('Categorical', true) will be
%   assumed.
%   
%   - 'Normalize', logical : to have or not ranges for normalization. Default 
%   is true, so it will ask you to specify these ranges during the script. 
%   If you write false, then no Normalization will be performed and outfput
%   for Ranges will be a matrix of NaNs.
%   
%   - 'Ranges', table : is the table that will be used to normalize data
%   in dataset. It must be a nx2 table (n is the number of features you
%   have), containing in the first column min values and in the second the
%   max values.
%   
%   - 'TargetFig', uiFigObject : to specify in which figure you want to
%   prompt questions or extra inputs. If you don't specify anything, a new
%   uifigure will be created.
%   
%   - 'TimeSensMode', string : to set the type of approach you want to use
%   for time sensitive part. Possible string values are 'CondensedDays', 
%   'SeparateDays', or 'TriggerCausePeak'. If no value is specified, then
%   the default value will be 'CondensedDays'.
%   
%   - 'DaysForTS', num : to set how many days to consider for time sensitive 
%   part (cumulate or average). If you don't specify anything the value will 
%   be set to 1 by default (1 day of cumulate or average value). This entry 
%   means the number of days you want to use to cumulate or average values 
%   when 'TimeSensMode' is set to value 'CondensedDays'. If 'TimeSensMode' is
%   set to 'SeparateDays', this value will be the number of separate 
%   days to consider as separate features of your neural network.
%   
%   - 'DayOfEvent', datetime : to set the datetime of the event you want to 
%   consider. If you don't specify anything, then it will be prompted a dialog 
%   where to choose.
%   
%   - 'CauseMode', string : to set the way you want to consider rainfalls 
%   before the Trigger event. It will have effect only when 'TimeSensMode'
%   is set to 'TriggerCausePeak'. Possible string values are 'DailyCumulate' 
%   or'EventsCumulate'. If no value is specified, then 'EventsCumulate' is 
%   taken as default.
%   
%   - 'FileAssName', string : is to define the name of the excel that
%   contains the association between the content of shapefiles and classes.
%   If you don't specify anything, then 'ClassesML.xlsx' file will be take 
%   as default.

%% Arguments
arguments
    fold0 (1,:) char {mustBeFolder}
    Options.Features (1,:) cell = {'allfeats'}
    Options.Categorical (1,1) logical = true
    Options.Normalize (1,1) logical = true
    Options.TimeSensMode (1,:) char = 'condenseddays'
    Options.DaysForTS (1,:) double = 1 % It must be horizontal!
    Options.DayOfEvent (1,1) datetime = NaT
    Options.TargetFig (1,1) matlab.ui.Figure = uifigure
    Options.FileAssName (1,:) char = 'ClassesML.xlsx'
    Options.Ranges (:,:) table = table()
    Options.CauseMode (1,:) char = 'eventscumulate'
    Options.RenameFeats (1,1) logical = false
end

feats2Use = lower(cellstr(Options.Features));
categVars = Options.Categorical;
normData  = Options.Normalize;
mode4TS   = lower(Options.TimeSensMode);
days4TS   = Options.DaysForTS;
eventDay  = Options.DayOfEvent;
uiFig2Use = Options.TargetFig;
fileAssoc = Options.FileAssName; % Not lower because it is case sensitive!
rngsFts   = Options.Ranges;
causeMode = lower(Options.CauseMode);
renameFts = Options.RenameFeats;

%% Input check and initialization
suggRngs = array2table(cell(1, 3), 'VariableNames',{'Min Value','Max Value','Type'}, 'RowNames',{'InitNull'}); % Initialized
suggRngs(1,:) = [];
classPolys = table; % Initialized
dsetFtsStd = table; % Initialized

createRng = false;
if normData && (isempty(rngsFts) || all(isnan(rngsFts{:,:}), 'all'))
    createRng = true;
    warning(['Normalize is active but Ranges is empty or filled ', ...
             'with nans. Ranges will be created from scratch!'])
end

%% Loading of main variables
progBar = uiprogressdlg(uiFig2Use, 'Title','Please wait', 'Indeterminate','on', ...
                                   'Message','Dataset: reading files for dataset creation...');

sl = filesep;

% Main files
load([fold0,sl,'os_folders.mat'        ], 'fold_var','fold_user')
load([fold_var,sl,'GridCoordinates.mat'], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')

xLonStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy = cellfun(@(x,y) x(y), yLatAll , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

xLonStCat = cat(1, xLonStudy{:});
yLatStCat = cat(1, yLatStudy{:});

dsetCrdStd = table(xLonStCat, yLatStCat, 'VariableNames',{'Longitude','Latitude'});
clear('xLonStCat', 'yLatStCat')

%% Loading of features (numerical part)
progBar.Message = 'Dataset: reading numerical part...';

% Elevation
if any(contains(feats2Use, ["elevation", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll')

    tmpFtName = 'Elevation';
    elevStudy = cellfun(@(x,y) x(y), ElevationAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, elevStudy{:});
    clear('ElevationAll', 'elevStudy')

    suggRngs{tmpFtName, :} = {0, 2500, "Num"};
end

% Slope
if any(contains(feats2Use, ["slope", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'SlopeAll')

    tmpFtName = 'Slope';
    slopeStudy = cellfun(@(x,y) x(y), SlopeAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, slopeStudy{:});
    clear('SlopeAll', 'slopeStudy')

    suggRngs{tmpFtName, :} = {0, 80, "Num"};
end

% Aspect angle
if any(contains(feats2Use, ["aspect", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'AspectAngleAll')

    tmpFtName = 'AspAngle';
    aspAngleStudy = cellfun(@(x,y) x(y), AspectAngleAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, aspAngleStudy{:});
    clear('AspectAngleAll', 'aspAngleStudy')

    suggRngs{tmpFtName, :} = {0, 360, "Num"};
end

% Mean curvature
if any(contains(feats2Use, ["mean", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'MeanCurvatureAll')

    tmpFtName = 'MnCurv';
    meanCurvStudy = cellfun(@(x,y) x(y), MeanCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, meanCurvStudy{:});
    clear('MeanCurvatureAll', 'meanCurvStudy')

    suggRngs{tmpFtName, :} = [num2cell(quantile(dsetFtsStd.(tmpFtName), [0.25, 0.75])), {"Num"}];
end

% Profile curvature
if any(contains(feats2Use, ["profile", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'ProfileCurvatureAll')

    tmpFtName = 'PrCurv';
    profCurvStudy = cellfun(@(x,y) x(y), ProfileCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, profCurvStudy{:});
    clear('ProfileCurvatureAll', 'profCurvStudy')

    suggRngs{tmpFtName, :} = [num2cell(quantile(dsetFtsStd.(tmpFtName), [0.25, 0.75])), {"Num"}];
end

% Planform curvature
if any(contains(feats2Use, ["planform", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'PlanformCurvatureAll')

    tmpFtName = 'PlCurv';
    planCurvStudy = cellfun(@(x,y) x(y), PlanformCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, planCurvStudy{:});
    clear('PlanformCurvatureAll', 'planCurvStudy')

    suggRngs{tmpFtName, :} = [num2cell(quantile(dsetFtsStd.(tmpFtName), [0.25, 0.75])), {"Num"}];
end

% Contributing area
if any(contains(feats2Use, ["contributing", "allfeats"]))
    load([fold_var,sl,'FlowRouting.mat'], 'ContributingAreaAll')

    tmpFtName = 'ContArea';
    contrAreaStudy = cellfun(@(x,y) log(x(y)), ContributingAreaAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, contrAreaStudy{:});
    clear('ContributingAreaAll', 'contrAreaStudy')

    suggRngs{tmpFtName, :} = {min(dsetFtsStd.(tmpFtName)), max(dsetFtsStd.(tmpFtName)), "Num"};
end

% TWI
if any(contains(feats2Use, ["twi", "allfeats"]))
    load([fold_var,sl,'FlowRouting.mat'], 'TwiAll')

    tmpFtName = 'TWI';
    twiStudy = cellfun(@(x,y) x(y), TwiAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, twiStudy{:});
    clear('TwiAll', 'twiStudy')

    suggRngs{tmpFtName, :} = {min(dsetFtsStd.(tmpFtName)), max(dsetFtsStd.(tmpFtName)), "Num"};
end

% Clay content
if any(contains(feats2Use, ["clay", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'ClayContentAll')

    tmpFtName = 'ClayCont';
    clayContStudy = cellfun(@(x,y) x(y), ClayContentAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, clayContStudy{:});
    clear('ClayContentAll', 'clayContStudy')

    suggRngs{tmpFtName, :} = {min(dsetFtsStd.(tmpFtName)), max(dsetFtsStd.(tmpFtName)), "Num"};
end

% Sand content
if any(contains(feats2Use, ["sand", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'SandContentAll')

    tmpFtName = 'SandCont';
    sandContStudy = cellfun(@(x,y) x(y), SandContentAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, sandContStudy{:});
    clear('SandContentAll', 'sandContStudy')

    suggRngs{tmpFtName, :} = {min(dsetFtsStd.(tmpFtName)), max(dsetFtsStd.(tmpFtName)), "Num"};
end

% NDVI
if any(contains(feats2Use, ["ndvi", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'NdviAll')

    tmpFtName = 'NDVI';
    ndviStudy = cellfun(@(x,y) x(y), NdviAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, ndviStudy{:});
    clear('NdviAll', 'ndviStudy')

    suggRngs{tmpFtName, :} = {min(dsetFtsStd.(tmpFtName)), max(dsetFtsStd.(tmpFtName)), "Num"};
end

% Distance
if any(contains(feats2Use, ["distance", "allfeats"]))
    load([fold_var,sl,'Distances.mat'], 'Distances')

    tmpFtName = 'RoadDist';
    obDstNames = Distances.Properties.VariableNames;
    roadDistNm = 1;
    if not(isscalar(obDstNames))
        roadDistNm = listdlg2({'Select roads object:'}, obDstNames, 'OutType','NumInd');
    end
    minDistTmp = cellfun(@(x,y) x(y), Distances{'Distances',roadDistNm}{:}, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, minDistTmp{:});
    clear('Distances', 'minDistTmp')

    suggRngs{tmpFtName, :} = {min(dsetFtsStd.(tmpFtName)), max(dsetFtsStd.(tmpFtName)), "Num"};
end

% Vegetation Probabilities
if any(contains(feats2Use, ["veg"+wildcardPattern+"prob"+lettersPattern, "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'VgPrAll')

    tmpFtName = VgPrAll.Properties.RowNames;
    for i1 = 1:numel(tmpFtName)
        vegPrTmp = cellfun(@(x,y) x(y), VgPrAll{i1,:}, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
        dsetFtsStd.(tmpFtName{i1}) = cat(1, vegPrTmp{:});
    end
    clear('VgPrAll', 'vegPrTmp')

    suggRngs{tmpFtName, :} = repmat({min(dsetFtsStd{:,tmpFtName}, [], 'all'), max(dsetFtsStd{:,tmpFtName}, [], 'all'), "Num"}, numel(tmpFtName), 1);
end

% Random
if any(contains(feats2Use, ["random", "allfeats"]))
    tmpFtName = 'RandFeat';
    randomStudy = cellfun(@(x,y) rand(size(x)), IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.(tmpFtName) = cat(1, randomStudy{:});
    clear('randomStudy')

    suggRngs{tmpFtName, :} = {0, 1, "Num"};
end

%% Loading of features (categorical part)
progBar.Message = 'Dataset: reading categorical part...';

if any(contains(feats2Use, ["sub", "top", "land", "vegetation", "allfeats"]))
    classesML = read_ml_association_spreadsheet([fold_user,sl,fileAssoc]);

    [clssStudy, classPolys, ...
        tmpFtName, lablNme] = classes_ml_association(classesML, xLonStudy, yLatStudy, ...
                                                     fold_var, categVars=categVars, ...
                                                     feats2Use=feats2Use, uiFig2Use=uiFig2Use);

    for iC = 1:numel(tmpFtName)
        progBar.Message = ['Dataset: associating ',tmpFtName{iC},'...'];
    
        glbClss = classesML{'Global', lablNme{iC}}{:}{:, 'Title'};
    
        if categVars
            dsetFtsStd.(tmpFtName{iC}) = categorical(cat(1, clssStudy{iC}{:}), unique(glbClss), 'Ordinal',true); % unique is to order the classes!
            suggRngs{tmpFtName{iC}, :} = {nan, nan, "Categ"};
        else
            dsetFtsStd.(tmpFtName{iC}) = cat(1, clssStudy{iC}{:});
            suggRngs{tmpFtName{iC}, :} = {0, max(classesML{'Global', lablNme{iC}}{:}{:, 'Number'}), "Num"};
        end
    end

    clear('clssStudy')
end

%% Loading of features (time sensitive part)
progBar.Message = 'Dataset: reading time sensitive part...';

[timeSnsPar, timeSnsNmD, timeSnsDtt, ...
    timeSnsTrg, timeSnsPks, timeSnsEvD] = deal({});
cumulParam = [];

% Rainfall
if any(contains(feats2Use, ["rain", "allfeats"]))
    load([fold_var,sl,'RainInterpolated.mat'], 'RainInterpolated','RainDateInterpolationStarts')

    timeSnsPar = [timeSnsPar, {'Rain'}];
    cumulParam = [cumulParam, 1];
    timeSnsNmD = [timeSnsNmD, {RainInterpolated}];
    timeSnsDtt = [timeSnsDtt, {RainDateInterpolationStarts}];
    clear('RainInterpolated')

    if strcmp(mode4TS, "triggercausepeak")
        load([fold_var,sl,'RainEvents.mat'], 'RainAmountPerEventInterp','RainMaxPeakPerEventInterp','RainRecDatesPerEvent')

        timeSnsTrg = [timeSnsTrg, {RainAmountPerEventInterp} ];
        timeSnsPks = [timeSnsPks, {RainMaxPeakPerEventInterp}];
        timeSnsEvD = [timeSnsEvD, {RainRecDatesPerEvent}     ];
        clear('RainAmountPerEventInterp', 'RainMaxPeakPerEventInterp', 'RainRecDatesPerEvent')
    end
end

% Temperature
if any(contains(feats2Use, ["temp", "allfeats"]))
    load([fold_var,sl,'TempInterpolated.mat'], 'TempInterpolated','TempDateInterpolationStarts')

    timeSnsPar = [timeSnsPar, {'Temp'}];
    cumulParam = [cumulParam, 0];
    timeSnsNmD = [timeSnsNmD, {TempInterpolated}];
    timeSnsDtt = [timeSnsDtt, {TempDateInterpolationStarts}];
    clear('TempInterpolated')

    if strcmp(mode4TS, "triggercausepeak")
        load([fold_var,sl,'TempEvents.mat'], 'TempAmountPerEventInterp','TempMaxPeakPerEventInterp','TempRecDatesPerEvent')

        timeSnsTrg = [timeSnsTrg, {TempAmountPerEventInterp} ];
        timeSnsPks = [timeSnsPks, {TempMaxPeakPerEventInterp}];
        timeSnsEvD = [timeSnsEvD, {TempRecDatesPerEvent}     ];
        clear('TempAmountPerEventInterp', 'TempMaxPeakPerEventInterp', 'TempRecDatesPerEvent')
    end
end

% Uniformization of Time Sensitive
timeSnsExs = false;
if any(contains(feats2Use, ["rain", "temp", "allfeats"]))
    timeSnsExs = true;
    cumulParam = logical(cumulParam);
    strDateCmm = max(cellfun(@min, timeSnsDtt)); % Start in end dates
    endDateCmm = min(cellfun(@max, timeSnsDtt)); % End in end dates

    if endDateCmm < strDateCmm
        error('Time sensitive part has no datetime in common! Please re-interpolate time sensitive part.')
    end

    if length(timeSnsPar) > 1
        for i1 = 1 : length(timeSnsPar)
            indStrCmm = find(strDateCmm == timeSnsDtt{i1}); % You should put an equal related to days and not exact timing
            indEvtCmm = find(endDateCmm   == timeSnsDtt{i1}); % You should put an equal related to days and not exact timing
            timeSnsNmD{i1} = timeSnsNmD{i1}(indStrCmm:indEvtCmm,:);
            timeSnsDtt{i1} = timeSnsDtt{i1}(indStrCmm:indEvtCmm);
        end
        if length(timeSnsDtt)>1 && ~isequal(timeSnsDtt{:})
            error('After uniformization of dates in time sensitive part, number of elements is not consistent! Please check it in the script.')
        end
    end

    timeSnsDtt = timeSnsDtt{1}; % Taking only the first one since they are identical!

    if not(isnat(eventDay))
        row2Tk = find( abs(timeSnsDtt - eventDay) < minutes(1) );
        if isempty(row2Tk); error('The date you chosed as input does not exist in your merged data!'); end
    else
        row2Tk = listdlg2('Start time of 24 h:', timeSnsDtt, 'OutType','NumInd');
    end

    timeSnsDtCh = timeSnsDtt(row2Tk);

    if timeSnsDtt(row2Tk) < timeSnsDtt(max(days4TS))
        error(['You have selected a date that not allow to consider ', ...
               num2str(max(days4TS)),' days before your choice! Please retry.'])
    end

    timeSnsData = cell(1, length(timeSnsPar));
    for i1 = 1:length(timeSnsPar)
        timeSnsData{i1} = cellfun(@full, timeSnsNmD{i1}, 'UniformOutput',false);
    end
    clear('timeSnsNmD')

    for i1 = 1:numel(days4TS)
        [dsetFtsStd, timeSnsDttm, ...
            tmpFtName] = dataset_update_ts(timeSnsData, timeSnsDtt, ...
                                           timeSnsDtCh, dsetFtsStd, ...
                                           mode4TS, timeSnsPar, days4TS(i1), ...
                                           TmSnCmlb=cumulParam, TmSnTrgg=timeSnsTrg, ...
                                           TmSnPeak=timeSnsPks, TmSnEvDt=timeSnsEvD, ...
                                           TmSnTrCs=causeMode);
        for i2 = 1:numel(tmpFtName)
            for i3 = 1:numel(tmpFtName{i2})
                if contains(tmpFtName{i2}{i3}, 'Rain')
                    suggRngs{tmpFtName{i2}{i3}, :} = {0, 300, "TimeSens"};
                elseif contains(tmpFtName{i2}, 'Temp')
                    suggRngs{tmpFtName{i2}{i3}, :} = {-10, 35, "TimeSens"};
                else
                    error('Feat TS type not recognized!')
                end
            end
        end
    end
end

%% Normalization
progBar.Message = 'Dataset: normalization of data...';

ftsDset = dsetFtsStd.Properties.VariableNames;
if createRng
    prmpRngs = strcat("Ranges for ", suggRngs.Properties.RowNames);
    rngsInps = inputdlg2( prmpRngs, 'DefInp',strcat("[",num2str(round([suggRngs{:,1}{:}]',3,'significant'), '%.2e'),", ", ...
                                                        num2str(round([suggRngs{:,2}{:}]',3,'significant'), '%.2e'),"]"));

    tSCount = 1;
    currRow = 1;
    rngsFts = zeros(length(ftsDset), 2);
    for i1 = 1:length(ftsDset)
        rngsFts(i1,:) = str2num(rngsInps{currRow}); % Pay attention to order!
        if not(strcmp(ftsType(i1), "TimeSensitive"))
            currRow = currRow + 1;
        else
            switch mode4TS
                case 'separatedays'
                    tSCount = tSCount + 1;
                    if tSCount > days4TS % daysForTS must be scalar!
                        tSCount = 1;
                        currRow = currRow + 1;
                    end

                case {'condenseddays', 'triggercausepeak'}
                    currRow = currRow + 1;

                otherwise
                    error('Time Sensitive approach not recognized in creating ranges. Please check Normalization part!')
            end
        end
    end
    rngsFts = array2table(rngsFts, 'RowNames',ftsDset, 'VariableNames',["Min value", "Max value"]);
end

if normData
    dsetFtsStN = table();
    for i1 = 1:size(dsetFtsStd,2)
        if not(strcmp(ftsType(i1), "Categorical"))
            dsetFtsStN.(ftsDset{i1}) = rescale(dsetFtsStd.(ftsDset{i1}), 'InputMin',rngsFts{ftsDset{i1}, 1}, ...
                                                                         'InputMax',rngsFts{ftsDset{i1}, 2});
        elseif strcmp(ftsType(i1), "Categorical")
            dsetFtsStN.(ftsDset{i1}) = dsetFtsStd.(ftsDset{i1});
        end
    end
else
    rngsFts = array2table(nan(size(dsetFtsStd,2), 2), 'RowNames',ftsDset, ...
                                                      'VariableNames',["Min value", "Max value"]);
end

%% Rename feats
if renameFts
    newFtsLbls = inputdlg2(dsetFtsStd.Properties.VariableNames, 'DefInp',dsetFtsStd.Properties.VariableNames, 'Title','Type new names');
    featsAssoc = array2table(newFtsLbls, 'VariableNames',dsetFtsStd.Properties.VariableNames);

    fts4Std = featsAssoc{1, dsetFtsStd.Properties.VariableNames};
    dsetFtsStd.Properties.VariableNames = fts4Std;
    if normData
        fts4Nrm = featsAssoc{1, dsetFtsStN.Properties.VariableNames};
        dsetFtsStN.Properties.VariableNames = fts4Nrm;
    end

    fts4Rng = featsAssoc{1, rngsFts.Properties.RowNames};
    rngsFts.Properties.RowNames = fts4Rng;

    fts4Cls = featsAssoc{1, classPolys.Properties.RowNames};
    classPolys.Properties.RowNames = fts4Cls;
end

%% Output creation
progBar.Message = 'Dataset: Outputs...';

dsetNorm = dsetFtsStd;
dsetOrig = dsetFtsStd;
if normData % Overwrite in case it exists
    dsetNorm = dsetFtsStN;
end

dsetCoord = dsetCrdStd;
dsetRange = rngsFts;

dsetTmSns = table("No Time Sensitive data selected as input!", 'VariableNames',{'EventTime'});
if timeSnsExs % Overwrite in case it exists
    if strcmp(mode4TS, "triggercausepeak")
        dsetTmSns = table(timeSnsPar, timeSnsDtCh, timeSnsDtt', ...
                          timeSnsData, cumulParam, timeSnsTrg, timeSnsPks, ...
                          timeSnsEvD, timeSnsDttm, 'VariableNames',{'ParamNames', 'EventTime', ...
                                                                    'Datetimes', 'Data', ...
                                                                    'Cumulable', 'TriggAmountPerEvent' ...
                                                                    'PeaksPerEvent', 'DatesPerEvent', ...
                                                                    'StartDateTriggering'});
    else
        dsetTmSns = table(timeSnsPar, timeSnsDttm, timeSnsDtt', ...
                          timeSnsData, cumulParam, 'VariableNames',{'ParamNames', 'EventTime', ...
                                                                    'Datetimes', 'Data', 'Cumulable'});
    end
end

dsetFtsCl = string(suggRngs{:,3});
dsetPolys = classPolys;

end