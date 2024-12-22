function [varargout] = datasetstudy_creation(fold0, varargin)

% CREATE A DATASET TO USE FOR ML
%   
% Outputs:
%   [DatasetFeaturesStudy]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, ...
%                                                           TimeSensitivePart]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, ...
%                                     TimeSensitivePart, DatasetNotNormalized]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, ...
%                       TimeSensitivePart, DatasetNotNormalized, FeaturesType]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, ...
%           TimeSensitivePart, DatasetNotNormalized, FeaturesType, ClassPolys]
%   
% Required arguments:
%   - fold0 : is to identify the folder in which you have the analysis.
%   
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
% Optional arguments:
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

%% Settings initialization
feats2Use = {"allfeats"};      % Default
categVars = true;              % Default
normData  = true;              % Default
mode4TS   = "condenseddays";   % Default
days4TS   = 1;                 % Default
fileAssoc = 'ClassesML.xlsx';  % Default
createRng = true;              % Default
causeMode = "eventscumulate";  % Default
prm4Fts   = [];                % Inizialized
ftsType   = [];                % Initialized
suggRngs  = [];                % Initialized

classPolys = table;            % Initialized
dsetFtsStd = table;            % Initialized

if ~isempty(varargin)
    strPrt = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(strPrt) = cellfun(@(x) lower(string(x)), varargin(strPrt), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(strPrt) = varargin(strPrt);

    inputFeatures  = find(cellfun(@(x) strcmpi(x, "features"    ), vararginCopy));
    inputCategoric = find(cellfun(@(x) strcmpi(x, "categorical" ), vararginCopy));
    inputNormalize = find(cellfun(@(x) strcmpi(x, "normalize"   ), vararginCopy));
    inputMode4TS   = find(cellfun(@(x) strcmpi(x, "timesensmode"), vararginCopy));
    inputDays4TS   = find(cellfun(@(x) strcmpi(x, "daysforts"   ), vararginCopy));
    inputEventDay  = find(cellfun(@(x) strcmpi(x, "dayofevent"  ), vararginCopy));
    inputTargetFig = find(cellfun(@(x) strcmpi(x, "targetfig"   ), vararginCopy));
    inputFileAssoc = find(cellfun(@(x) strcmpi(x, "fileassname" ), vararginCopy));
    inputRanges    = find(cellfun(@(x) strcmpi(x, "ranges"      ), vararginCopy));
    inputCauseMode = find(cellfun(@(x) strcmpi(x, "causemode"   ), vararginCopy));

    if inputFeatures;  feats2Use = varargin{inputFeatures+1 }; end
    if inputCategoric; categVars = varargin{inputCategoric+1}; end
    if inputNormalize; normData  = varargin{inputNormalize+1}; end
    if inputMode4TS;   mode4TS   = varargin{inputMode4TS+1  }; end
    if inputDays4TS;   days4TS   = varargin{inputDays4TS+1  }; end
    if inputEventDay;  eventDay  = varargin{inputEventDay+1 }; end
    if inputTargetFig; uiFig2Use = varargin{inputTargetFig+1}; end
    if inputFileAssoc; fileAssoc = varargin{inputFileAssoc+1}; end
    if inputRanges;    rngsFts   = varargin{inputRanges+1   }; end
    if inputCauseMode; causeMode = varargin{inputCauseMode+1}; end

    if inputFeatures
        feats2Use = cellfun(@(x) lower(string(x)), feats2Use, 'Uniform',false); % To have consistency in terms of data type and case type
    end

    if inputRanges
        createRng = false;
        if not(istable(rngsFts))
            error('You have specified Ranges as input but not as a table!')
        elseif isempty(rngsFts) || all(isnan(rngsFts{:,:}), 'all')
            createRng = true;
            warning('You have put as input Ranges but it is empty or filled with nans. Ranges will be ignored and re-created!')
        end
    end
end

days4TS = [days4TS(:)]'; % To ensure that it is horizontal

if not(exist('uiFig2Use', 'var')); uiFig2Use = uifigure; end

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
if any(contains([feats2Use{:}], ["elevation", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll')

    elevStudy = cellfun(@(x,y) x(y), ElevationAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.Elevation = cat(1, elevStudy{:});
    clear('ElevationAll', 'elevStudy')

    prm4Fts = [prm4Fts, "Elevation [m]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [0, 2000];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Slope
if any(contains([feats2Use{:}], ["slope", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'SlopeAll')

    slopeStudy = cellfun(@(x,y) x(y), SlopeAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.Slope = cat(1, slopeStudy{:});
    clear('SlopeAll', 'slopeStudy')

    prm4Fts = [prm4Fts, "Slope [°]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [0, 80];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Aspect angle
if any(contains([feats2Use{:}], ["aspect", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'AspectAngleAll')

    aspAngleStudy = cellfun(@(x,y) x(y), AspectAngleAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.AspAngle = cat(1, aspAngleStudy{:});
    clear('AspectAngleAll', 'aspAngleStudy')

    prm4Fts = [prm4Fts, "Aspect Angle [°]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [0, 360];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Mean curvature
if any(contains([feats2Use{:}], ["mean", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'MeanCurvatureAll')

    meanCurvStudy = cellfun(@(x,y) x(y), MeanCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.MnCurv = cat(1, meanCurvStudy{:});
    clear('MeanCurvatureAll', 'meanCurvStudy')

    prm4Fts = [prm4Fts, "Mean Curvature [1/m]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = quantile(dsetFtsStd.MnCurv, [0.25, 0.75]);
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Profile curvature
if any(contains([feats2Use{:}], ["profile", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'ProfileCurvatureAll')

    profCurvStudy = cellfun(@(x,y) x(y), ProfileCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.PrCurv = cat(1, profCurvStudy{:});
    clear('ProfileCurvatureAll', 'profCurvStudy')

    prm4Fts = [prm4Fts, "Profile Curvature [1/m]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = quantile(dsetFtsStd.PrCurv, [0.25, 0.75]);
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Planform curvature
if any(contains([feats2Use{:}], ["planform", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'PlanformCurvatureAll')

    planCurvStudy = cellfun(@(x,y) x(y), PlanformCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.PlCurv = cat(1, planCurvStudy{:});
    clear('PlanformCurvatureAll', 'planCurvStudy')

    prm4Fts = [prm4Fts, "Planform Curvature [1/m]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = quantile(dsetFtsStd.PlCurv, [0.25, 0.75]);
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Contributing area
if any(contains([feats2Use{:}], ["contributing", "allfeats"]))
    load([fold_var,sl,'FlowRouting.mat'], 'ContributingAreaAll')

    contrAreaStudy = cellfun(@(x,y) log(x(y)), ContributingAreaAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.ContArea = cat(1, contrAreaStudy{:});
    clear('ContributingAreaAll', 'contrAreaStudy')

    prm4Fts = [prm4Fts, "Contributing Area [log(m2)]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [min(dsetFtsStd.ContArea), max(dsetFtsStd.ContArea)];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% TWI
if any(contains([feats2Use{:}], ["twi", "allfeats"]))
    load([fold_var,sl,'FlowRouting.mat'], 'TwiAll')

    twiStudy = cellfun(@(x,y) x(y), TwiAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.TWI = cat(1, twiStudy{:});
    clear('TwiAll', 'twiStudy')

    prm4Fts = [prm4Fts, "TWI [log(m2)]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [min(dsetFtsStd.TWI), max(dsetFtsStd.TWI)];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Clay content
if any(contains([feats2Use{:}], ["clay", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'ClayContentAll')

    clayContStudy = cellfun(@(x,y) x(y), ClayContentAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.ClayCont = cat(1, clayContStudy{:});
    clear('ClayContentAll', 'clayContStudy')

    prm4Fts = [prm4Fts, "Clay Content [-]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [min(dsetFtsStd.ClayCont), max(dsetFtsStd.ClayCont)];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Sand content
if any(contains([feats2Use{:}], ["sand", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'SandContentAll')

    sandContStudy = cellfun(@(x,y) x(y), SandContentAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.SandCont = cat(1, sandContStudy{:});
    clear('SandContentAll', 'sandContStudy')

    prm4Fts = [prm4Fts, "Sand Content [-]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [min(dsetFtsStd.SandCont), max(dsetFtsStd.SandCont)];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% NDVI
if any(contains([feats2Use{:}], ["ndvi", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'NdviAll')

    ndviStudy = cellfun(@(x,y) x(y), NdviAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.NDVI = cat(1, ndviStudy{:});
    clear('NdviAll', 'ndviStudy')

    prm4Fts = [prm4Fts, "NDVI [-]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [min(dsetFtsStd.NDVI), max(dsetFtsStd.NDVI)];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Distance
if any(contains([feats2Use{:}], ["distance", "allfeats"]))
    load([fold_var,sl,'Distances.mat'], 'Distances')

    obDstNames = Distances.Properties.VariableNames;
    if isscalar(obDstNames)
        roadDistNm = 1;
    else
        roadDistNm = listdlg2({'Select roads object:'}, obDstNames, 'OutType','NumInd');
    end
    minDistTmp = cellfun(@(x,y) x(y), Distances{'Distances',roadDistNm}{:}, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.RoadDist = cat(1, minDistTmp{:});
    clear('Distances', 'minDistTmp')

    prm4Fts = [prm4Fts, "Distance To Roads [m]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [min(dsetFtsStd.RoadDist), max(dsetFtsStd.RoadDist)];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Vegetation Probabilities
if any(contains([feats2Use{:}], ["veg"+wildcardPattern+"prob"+lettersPattern, "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'VgPrAll')

    vegVarNames = VgPrAll.Properties.RowNames;
    for i1 = 1:numel(vegVarNames)
        vegPrTmp = cellfun(@(x,y) x(y), VgPrAll{i1,:}, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
        dsetFtsStd.(vegVarNames{i1}) = cat(1, vegPrTmp{:});
    end
    clear('VgPrAll', 'vegPrTmp')

    prm4Fts = [prm4Fts, string(vegVarNames')];
    ftsType = [ftsType, repmat("Numerical", 1, numel(vegVarNames))];
    rng2Add = [min(dsetFtsStd{:,vegVarNames}, [], 'all'), ...
                 max(dsetFtsStd{:,vegVarNames}, [], 'all')];
    if normData; suggRngs = [suggRngs; repmat(rng2Add, numel(vegVarNames), 1)]; end
end

% Random
if any(contains([feats2Use{:}], ["random", "allfeats"]))
    randomStudy = cellfun(@(x,y) rand(size(x)), IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    dsetFtsStd.RandFeat = cat(1, randomStudy{:});
    clear('randomStudy')

    prm4Fts = [prm4Fts, "Random [-]"];
    ftsType = [ftsType, "Numerical"];
    rng2Add = [0, 1];
    if normData; suggRngs = [suggRngs; rng2Add]; end
end

%% Loading of features (categorical part)
progBar.Message = 'Dataset: reading categorical part...';

if any(contains([feats2Use{:}], ["sub", "top", "land", "vegetation", "allfeats"]))
    classesML = read_ml_association_spreadsheet([fold_user,sl,fileAssoc]);

    [clssStudy, classPolys, ...
        featNme, lablNme] = classes_ml_association(classesML, xLonStudy, yLatStudy, ...
                                                   fold_var, categVars=categVars, ...
                                                   feats2Use=feats2Use, uiFig2Use=uiFig2Use);

    for iC = 1:numel(featNme)
        progBar.Message = ['Dataset: associating ',featNme{iC},'...'];
    
        glbClss = classesML{'Global', lablNme{iC}}{:}{:, 'Title'};
    
        prm4Fts = [prm4Fts, strcat(lablNme{iC}," Class [-]")];
        if categVars
            dsetFtsStd.(featNme{iC}) = categorical(cat(1, clssStudy{iC}{:}), unique(glbClss), 'Ordinal',true); % unique is to order the classes!
            ftsType = [ftsType, "Categorical"];
            rng2Add = [nan, nan];
        else
            dsetFtsStd.(featNme{iC}) = cat(1, clssStudy{iC}{:});
            ftsType = [ftsType, "Numerical"];
            rng2Add = [0, max(classesML{'Global', lablNme{iC}}{:}{:, 'Number'})];
        end
    
        if normData; suggRngs = [suggRngs; rng2Add]; end
    end

    clear('clssStudy')
end

%% Loading of features (time sensitive part)
progBar.Message = 'Dataset: reading time sensitive part...';

[timeSnsPar, timeSnsNmD, timeSnsDtt, ...
    timeSnsTrg, timeSnsPks, timeSnsEvD] = deal({});
cumulParam = [];

% Rainfall
if any(contains([feats2Use{:}], ["rain", "allfeats"]))
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

    maxDayRain = 30; % To discuss this value (max in Emilia was 134 mm in a day)
    if strcmp(mode4TS, "condenseddays")
        prm4Fts = [prm4Fts, strcat("Rainfall Cumulate ",string(days4TS), "d [mm]")];
        ftsType = [ftsType, repmat("TimeSensitive", 1, numel(days4TS))];
        rng2Add = [zeros(numel(days4TS), 1), arrayfun(@(x) maxDayRain*x, days4TS')];

    elseif strcmp(mode4TS, "separatedays")
        prm4Fts = [prm4Fts, "Rainfall Daily [mm]"];
        ftsType = [ftsType, repmat("TimeSensitive", 1, days4TS)]; % daysForTS must be a scalar
        rng2Add = [0, 120];

    elseif strcmp(mode4TS, "triggercausepeak")
        prm4Fts = [prm4Fts, "Rainfall Triggering [mm]", "Rainfall Trigg Peak [mm/h]", ...
                     strcat("Rainfall Cause ",string(days4TS),"d [mm]")]; % The order is important (see also dataset_update_ts)
        ftsType = [ftsType, repmat("TimeSensitive", 1, 2+numel(days4TS))];
        rng2Add = [0, 200; 0, 40; ...
                  [zeros(numel(days4TS), 1), arrayfun(@(x) maxDayRain*x, days4TS')] ];
    end

    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Temperature
if any(contains([feats2Use{:}], ["temp", "allfeats"]))
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

    if strcmp(mode4TS, "condenseddays")
        prm4Fts = [prm4Fts, strcat("Temperature Average ",string(days4TS), "d [°]")];
        ftsType = [ftsType, repmat("TimeSensitive", 1, numel(days4TS))];
        rng2Add = repmat([-10, 35], numel(days4TS), 1); % In Celsius

    elseif strcmp(mode4TS, "separatedays")
        prm4Fts = [prm4Fts, "Temperature Daily [°]"];
        ftsType = [ftsType, repmat("TimeSensitive", 1, days4TS)]; % daysForTS must be a scalar
        rng2Add = [-10, 35];

    elseif strcmp(mode4TS, "triggercausepeak")
        prm4Fts = [prm4Fts, "Temperature Triggering [°]", "Temperature Trigg Peak [°/h]", ...
                   strcat("Temperature Cause ",string(days4TS),"d [°]")]; % The order is important (see also dataset_update_ts)
        ftsType = [ftsType, repmat("TimeSensitive", 1, 2+numel(days4TS))];
        rng2Add = repmat([-10, 35], 2+numel(days4TS), 1); % In Celsius
    end

    if normData; suggRngs = [suggRngs; rng2Add]; end
end

% Uniformization of Time Sensitive
timeSnsExs = false;
if any(contains([feats2Use{:}], ["rain", "temp", "allfeats"]))
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

    if exist('eventDay', 'var')
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
        [dsetFtsStd, ...
            timeSnsDtUs] = dataset_update_ts(timeSnsData, timeSnsDtt, ...
                                             timeSnsDtCh, dsetFtsStd, ...
                                             mode4TS, timeSnsPar, days4TS(i1), ...
                                             TmSnCmlb=cumulParam, TmSnTrgg=timeSnsTrg, ...
                                             TmSnPeak=timeSnsPks, TmSnEvDt=timeSnsEvD, ...
                                             TmSnTrCs=causeMode);
    end
end

%% Normalization
progBar.Message = 'Dataset: normalization of data...';

ftsDset = dsetFtsStd.Properties.VariableNames;
if normData
    if createRng
        prmpRngs = strcat("Ranges for ", prm4Fts');
        rngsInps = inputdlg2( prmpRngs, 'DefInp',strcat("[",num2str(round(suggRngs(:,1),3,'significant'), '%.2e'),", ", ...
                                                            num2str(round(suggRngs(:,2),3,'significant'), '%.2e'),"]"));

        tSCount = 1;
        currRow = 1;
        rngsFts = zeros(length(ftsDset), 2);
        for i1 = 1:length(ftsDset)
            rngsFts(i1,:) = str2num(rngsInps{currRow}); % Pay attention to order!
            if not(strcmp(ftsType(i1), "TimeSensitive"))
                currRow = currRow + 1;
            else
                switch mode4TS
                    case "separatedays"
                        tSCount = tSCount + 1;
                        if tSCount > days4TS % daysForTS must be scalar!
                            tSCount = 1;
                            currRow = currRow + 1;
                        end

                    case {"condenseddays", "triggercausepeak"}
                        currRow = currRow + 1;

                    otherwise
                        error('Time Sensitive approach not recognized in creating ranges. Please check Normalization part!')
                end
            end
        end
        rngsFts = array2table(rngsFts, 'RowNames',ftsDset, 'VariableNames',["Min value", "Max value"]);
    end

    dsetFtsStN = table();
    for i1 = 1:size(dsetFtsStd,2)
        if not(strcmp(ftsType(i1), "Categorical"))
            dsetFtsStN.(ftsDset{i1}) = rescale(dsetFtsStd.(ftsDset{i1}), ...
                                                                           'InputMin',rngsFts{ftsDset{i1}, 1}, ...
                                                                           'InputMax',rngsFts{ftsDset{i1}, 2});
        elseif strcmp(ftsType(i1), "Categorical")
            dsetFtsStN.(ftsDset{i1}) = dsetFtsStd.(ftsDset{i1});
        end
    end
else
    rngsFts = array2table(nan(size(dsetFtsStd,2), 2), 'RowNames',ftsDset, ...
                                                               'VariableNames',["Min value", "Max value"]);
end

%% Output creation
progBar.Message = 'Dataset: Outputs...';

if normData
    varargout{1} = dsetFtsStN;
    varargout{5} = dsetFtsStd;
else
    varargout{1} = dsetFtsStd;
    varargout{5} = dsetFtsStd;
end

varargout{2} = dsetCrdStd;
varargout{3} = rngsFts;

if timeSnsExs
    if strcmp(mode4TS, "triggercausepeak")
        varargout{4} = table(timeSnsPar, timeSnsDtCh, timeSnsDtt', ...
                             timeSnsData, cumulParam, timeSnsTrg, timeSnsPks, ...
                             timeSnsEvD, timeSnsDtUs, 'VariableNames',{'ParamNames', 'EventTime', ...
                                                                          'Datetimes', 'Data', ...
                                                                          'Cumulable', 'TriggAmountPerEvent' ...
                                                                          'PeaksPerEvent', 'DatesPerEvent', ...
                                                                          'StartDateTriggering'});
    else
        varargout{4} = table(timeSnsPar, timeSnsDtUs, timeSnsDtt', ...
                             timeSnsData, cumulParam, 'VariableNames',{'ParamNames', 'EventTime', 'Datetimes', 'Data', 'Cumulable'});
    end
else
    varargout{4} = table("No Time Sensitive data selected as input!", 'VariableNames',{'EventTime'});
end

varargout{6} = ftsType;
varargout{7} = classPolys;

end