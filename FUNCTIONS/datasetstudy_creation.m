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
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, TimeSensitivePart]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, TimeSensitivePart, DatasetNotNormalized]
%   or
%   [DatasetFeaturesStudy, DatasetCoordinatesStudy, RangesForNormalization, TimeSensitivePart, DatasetNotNormalized, FeaturesType]
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
%   for time sensitive part. Possible string values are 'CumulOrAvg' or 
%   'MultipleSeparateDays'. If no value is specified, then the default
%   value will be 'CumulOrAvg'.
%   
%   - 'DaysForTS', num : to set how many days to consider for
%   time sensitive part (cumulate or average). If you don't specify anything 
%   the value will be set to 1 by default (1 day of cumulate or average
%   value). This entry will take effect only when 'TimeSensMode' is set to 
%   value 'CumulOrAvg'.
%   
%   - 'DayOfEvent', datetime : to set the datetime of the event you want to 
%   consider. If you don't specify anything, then it will be prompted a dialog 
%   where to choose.
%   
%   - 'FileAssName', string : is to define the name of the excel that
%   contains the association between the content of shapefiles and classes.
%   If you don't specify anything, then 'ClassesML.xlsx' file will be take 
%   as default.

%% Settings initialization
FeatsToUse = {"allfeats"};      % Default
CategVars  = true;              % Default
NormData   = true;              % Default
ModeForTS  = "cumuloravg";      % Default
DaysForTS  = 1;                 % Default
FileAssoc  = 'ClassesML.xlsx';  % Default
Prmpt4Fts  = [];                % Inizialized
FeatsType  = [];                % Initialized
SuggRanges = [];                % Initialized

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(StringPart) = varargin(StringPart);

    InputFeatures    = find(cellfun(@(x) strcmpi(x, "features"),     vararginCopy));
    InputCategorical = find(cellfun(@(x) strcmpi(x, "categorical"),  vararginCopy));
    InputNormalize   = find(cellfun(@(x) strcmpi(x, "normalize"),    vararginCopy));
    InputModeForTS   = find(cellfun(@(x) strcmpi(x, "timesensmode"), vararginCopy));
    InputDaysForTS   = find(cellfun(@(x) strcmpi(x, "daysforts"),    vararginCopy));
    InputEventDay    = find(cellfun(@(x) strcmpi(x, "dayofevent"),   vararginCopy));
    InputTargetFig   = find(cellfun(@(x) strcmpi(x, "targetfig"),    vararginCopy));
    InputFileAssoc   = find(cellfun(@(x) strcmpi(x, "fileassname"),  vararginCopy));
    InputRanges      = find(cellfun(@(x) strcmpi(x, "ranges"),       vararginCopy));

    if InputFeatures;    FeatsToUse = varargin{InputFeatures+1};    end
    if InputCategorical; CategVars  = varargin{InputCategorical+1}; end
    if InputNormalize;   NormData   = varargin{InputNormalize+1};   end
    if InputModeForTS;   ModeForTS  = varargin{InputModeForTS+1};   end
    if InputDaysForTS;   DaysForTS  = varargin{InputDaysForTS+1};   end
    if InputEventDay;    EventDay   = varargin{InputEventDay+1};    end
    if InputTargetFig;   Fig        = varargin{InputTargetFig+1};   end
    if InputFileAssoc;   FileAssoc  = varargin{InputFileAssoc+1};   end
    if InputRanges;      Ranges     = varargin{InputRanges+1};      end

    if InputFeatures
        FeatsToUse = cellfun(@(x) lower(string(x)), FeatsToUse, 'Uniform',false); % To have consistency in terms of data type and case type
    end

    if exist('Ranges', 'var') && not(istable(Ranges))
        error('Ranges input variable must be a table!')
    end
end

if not(exist('Fig', 'var')); Fig = uifigure; end

DatasetFeaturesStudy = table;

%% Loading of main variables
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Dataset: reading files for dataset creation...', ...
                                 'Indeterminate','on');
drawnow

% OS identification
if ispc; sl = '\'; elseif ismac; sl = '/'; else; error('Platform not supported'); end

% Main files
load([fold0,sl,'os_folders.mat'],         'fold_var','fold_user')
load([fold_var,sl,'GridCoordinates.mat'], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')

xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy  = cellfun(@(x,y) x(y), yLatAll , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

xLongStudyCat = cat(1, xLongStudy{:});
yLatStudyCat  = cat(1, yLatStudy{:});

DatasetCoordinatesStudy = table(xLongStudyCat, yLatStudyCat, 'VariableNames',{'Longitude','Latitude'});

%% Loading of features (numerical part)
ProgressBar.Message = 'Dataset: reading numerical part...';

% Elevation
if any(contains([FeatsToUse{:}], ["elevation", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll')

    ElevationStudy = cellfun(@(x,y) x(y), ElevationAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.Elevation = cat(1,ElevationStudy{:});
    clear('ElevationAll')

    Prmpt4Fts = [Prmpt4Fts, "Elevation [m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [0, 2000];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Slope
if any(contains([FeatsToUse{:}], ["slope", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'SlopeAll')

    SlopeStudy = cellfun(@(x,y) x(y), SlopeAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.Slope = cat(1,SlopeStudy{:});
    clear('SlopeAll')

    Prmpt4Fts = [Prmpt4Fts, "Slope [°]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [0, 80];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Aspect angle
if any(contains([FeatsToUse{:}], ["aspect", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'AspectAngleAll')

    AspectAngleStudy = cellfun(@(x,y) x(y), AspectAngleAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.AspectAngle = cat(1,AspectAngleStudy{:});
    clear('AspectAngleAll')

    Prmpt4Fts = [Prmpt4Fts, "Aspect Angle [°]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [0, 360];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Mean curvature
if any(contains([FeatsToUse{:}], ["mean", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'MeanCurvatureAll')

    MeanCurvStudy = cellfun(@(x,y) x(y), MeanCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.MeanCurvature = cat(1,MeanCurvStudy{:});
    clear('MeanCurvatureAll')

    Prmpt4Fts = [Prmpt4Fts, "Mean Curvature [1/m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = quantile(DatasetFeaturesStudy.MeanCurvature, [0.25, 0.75]);
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Profile curvature
if any(contains([FeatsToUse{:}], ["profile", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'ProfileCurvatureAll')

    ProfileCurvStudy = cellfun(@(x,y) x(y), ProfileCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.ProfileCurvature = cat(1,ProfileCurvStudy{:});
    clear('ProfileCurvatureAll')

    Prmpt4Fts = [Prmpt4Fts, "Profile Curvature [1/m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = quantile(DatasetFeaturesStudy.ProfileCurvature, [0.25, 0.75]);
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Planform curvature
if any(contains([FeatsToUse{:}], ["planform", "allfeats"]))
    load([fold_var,sl,'MorphologyParameters.mat'], 'PlanformCurvatureAll')

    PlanformCurvStudy = cellfun(@(x,y) x(y), PlanformCurvatureAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.PlanformCurvature = cat(1,PlanformCurvStudy{:});
    clear('PlanformCurvatureAll')

    Prmpt4Fts = [Prmpt4Fts, "Planform Curvature [1/m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = quantile(DatasetFeaturesStudy.PlanformCurvature, [0.25, 0.75]);
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Contributing area
if any(contains([FeatsToUse{:}], ["contributing", "allfeats"]))
    load([fold_var,sl,'FlowRouting.mat'], 'ContributingAreaAll')

    ContrAreaLogStudy = cellfun(@(x,y) log(x(y)), ContributingAreaAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.ContributingAreaLog = cat(1,ContrAreaLogStudy{:});
    clear('ContributingAreaAll')

    Prmpt4Fts = [Prmpt4Fts, "Contributing Area [log(m2)]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.ContributingAreaLog), max(DatasetFeaturesStudy.ContributingAreaLog)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% TWI
if any(contains([FeatsToUse{:}], ["twi", "allfeats"]))
    load([fold_var,sl,'FlowRouting.mat'], 'TwiAll')

    TwiStudy = cellfun(@(x,y) x(y), TwiAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.TWI = cat(1,TwiStudy{:});
    clear('TwiAll')

    Prmpt4Fts = [Prmpt4Fts, "TWI [log(m2)]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.TWI), max(DatasetFeaturesStudy.TWI)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Clay content
if any(contains([FeatsToUse{:}], ["clay", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'ClayContentAll')

    ClayContentStudy = cellfun(@(x,y) x(y), ClayContentAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.ClayContent = cat(1,ClayContentStudy{:});
    clear('ClayContentAll')

    Prmpt4Fts = [Prmpt4Fts, "Clay Content [-]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.ClayContent), max(DatasetFeaturesStudy.ClayContent)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Sand content
if any(contains([FeatsToUse{:}], ["sand", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'SandContentAll')

    SandContentStudy = cellfun(@(x,y) x(y), SandContentAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.SandContent = cat(1,SandContentStudy{:});
    clear('SandContentAll')

    Prmpt4Fts = [Prmpt4Fts, "Sand Content [-]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.SandContent), max(DatasetFeaturesStudy.SandContent)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% NDVI
if any(contains([FeatsToUse{:}], ["ndvi", "allfeats"]))
    load([fold_var,sl,'SoilGrids.mat'], 'NdviAll')

    NdviStudy = cellfun(@(x,y) x(y), NdviAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.NDVI = cat(1,NdviStudy{:});
    clear('NdviAll')

    Prmpt4Fts = [Prmpt4Fts, "NDVI [-]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.NDVI), max(DatasetFeaturesStudy.NDVI)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Distance
if any(contains([FeatsToUse{:}], ["distance", "allfeats"]))
    load([fold_var,sl,'Distances.mat'], 'MinDistToRoadAll')

    MinDistToRoadStudy = cellfun(@(x,y) x(y), MinDistToRoadAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.MinDistanceToRoads = cat(1,MinDistToRoadStudy{:});
    clear('MinDistToRoadAll')

    Prmpt4Fts = [Prmpt4Fts, "Distance To Roads [m]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [min(DatasetFeaturesStudy.MinDistanceToRoads), max(DatasetFeaturesStudy.MinDistanceToRoads)];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Random
if any(contains([FeatsToUse{:}], ["random", "allfeats"]))
    RandomStudy = cellfun(@(x,y) rand(size(x)), IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    DatasetFeaturesStudy.Random = cat(1,RandomStudy{:});

    Prmpt4Fts = [Prmpt4Fts, "Random [-]"];
    FeatsType = [FeatsType, "Numerical"];
    RngsToAdd = [0, 1];
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

%% Loading of features (categorical part)
ProgressBar.Message = 'Dataset: reading categorical part...';

% Reading of excel sheets
if any(contains([FeatsToUse{:}], ["sub", "top", "land", "vegetation", "allfeats"]))
    Sheet_InfoClasses    = readcell([fold_user,sl,FileAssoc], 'Sheet','Main');
    Sheet_SubSoilClasses = readcell([fold_user,sl,FileAssoc], 'Sheet','Sub soil');
    Sheet_TopSoilClasses = readcell([fold_user,sl,FileAssoc], 'Sheet','Top soil');
    Sheet_LandUseClasses = readcell([fold_user,sl,FileAssoc], 'Sheet','Land use');
    Sheet_VegetClasses   = readcell([fold_user,sl,FileAssoc], 'Sheet','Vegetation');

    [ColWithTitles, ColWithClassNum] = deal(false(1, size(Sheet_InfoClasses, 2)));
    for i1 = 1:length(ColWithTitles)
        ColWithTitles(i1)   = any(cellfun(@(x) strcmp(string(x), 'Title'),  Sheet_InfoClasses(:,i1)));
        ColWithClassNum(i1) = any(cellfun(@(x) strcmp(string(x), 'Number'), Sheet_InfoClasses(:,i1)));
    end
    ColWithSubject = find(ColWithTitles)-1;

    if sum(ColWithTitles) > 1 || sum(ColWithClassNum) > 1
        error('Please, align columns in excel! Sheet: Main')
    end

    IndsBlankRowsTot = all(cellfun(@(x) all(ismissing(x)), Sheet_InfoClasses), 2);
    IndsBlnkInColNum = cellfun(@(x) all(ismissing(x)), Sheet_InfoClasses(:,ColWithClassNum));

    if not(isequal(IndsBlankRowsTot, IndsBlnkInColNum))
        error('Please fill with data only tables with association, no more else outside!')
    end

    Sheet_Info_Splits = mat2cell(Sheet_InfoClasses, diff(find([true; diff(~IndsBlankRowsTot); true]))); % Line suggested by ChatGPT that works, but check it better!

    InfoCont  = {'Sub soil', 'Top soil', 'Land use', 'Vegetation'};
    IndSplits = zeros(size(InfoCont));
    for i1 = 1:length(IndSplits)
        IndSplits(i1) = find(cellfun(@(x) any(strcmp(InfoCont{i1}, string([x(:,ColWithSubject)]))), Sheet_Info_Splits));
    end

    Sheet_Info_Div = cell2table(Sheet_Info_Splits(IndSplits)', 'VariableNames',InfoCont);
end

% Sub Soil
if any(contains([FeatsToUse{:}], ["sub", "allfeats"]))
    ProgressBar.Message = "Dataset: associating subsoil classes...";
    load([fold_var,sl,'LithoPolygonsStudyArea.mat'], 'LithoAllUnique','LithoPolygonsStudyArea')

    [ColWithRawClasses, ColWithAss] = deal(false(1, size(Sheet_SubSoilClasses, 2)));
    for i1 = 1:length(ColWithRawClasses)
        ColWithRawClasses(i1) = any(cellfun(@(x) strcmp(string(x), 'Raw data name'), Sheet_SubSoilClasses(:,i1)));
        ColWithAss(i1)        = any(cellfun(@(x) strcmp(string(x), 'Ass. class'),    Sheet_SubSoilClasses(:,i1)));
    end

    [AssSubSoilClass, AssSubSoilNum] = deal(cell(size(LithoAllUnique)));
    for i1 = 1:length(LithoAllUnique)
        RowToTake = strcmp(LithoAllUnique{i1}, string(Sheet_SubSoilClasses(:,ColWithRawClasses)));
        NumOfSubSoilClass = Sheet_SubSoilClasses{RowToTake, ColWithAss};
        if isempty(NumOfSubSoilClass) || ismissing(NumOfSubSoilClass)
            warning(['Raw class "',LithoAllUnique{i1},'" will be skipped (no association)'])
            continue
        end

        RowToTake = find(NumOfSubSoilClass==[Sheet_Info_Div.('Sub soil'){:}{2:end,ColWithClassNum}])+1; % +1 because the first row is char and was excluded in finding equal number, but anyway must be considered in taking the correct row!
        if isempty(RowToTake)
            error(['Raw class "',LithoAllUnique{i1},'" has an associated number that is not present in main sheet! Check your excel.'])
        end

        AssSubSoilClass(i1) = Sheet_Info_Div.('Sub soil'){:}(RowToTake, ColWithTitles);
        AssSubSoilNum(i1)   = Sheet_Info_Div.('Sub soil'){:}(RowToTake, ColWithClassNum);
    end

    [AssSubSoilClassUnique, IndUniqueSubSoil] = unique(AssSubSoilClass(cellfun(@(x) ischar(x)||isstring(x), AssSubSoilClass)));
    AssSubSoilNumUnique = AssSubSoilNum(cellfun(@(x) ischar(x)||isstring(x), AssSubSoilClass));
    AssSubSoilNumUnique = AssSubSoilNumUnique(IndUniqueSubSoil);
    SubSoilPolygons  = repmat(polyshape, 1, length(AssSubSoilClassUnique));
    for i1 = 1:length(AssSubSoilClassUnique)
        IndToUnify = strcmp(AssSubSoilClassUnique{i1}, AssSubSoilClass);
        SubSoilPolygons(i1) = union(LithoPolygonsStudyArea(IndToUnify));
    end

    if CategVars
        SubSoilStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    else
        SubSoilStudy = cellfun(@(x) zeros(size(x)),   xLongStudy, 'UniformOutput',false);
    end

    for i1 = 1:length(SubSoilPolygons)
        [pp1,ee1] = getnan2([SubSoilPolygons(i1).Vertices; nan, nan]);
        IndexInsideSubSoilPolygon = cellfun(@(x,y) inpoly([x,y],pp1,ee1), xLongStudy, yLatStudy, 'Uniform',false);
        for i2 = 1:size(xLongAll,2)
            if CategVars
                SubSoilStudy{i2}(IndexInsideSubSoilPolygon{i2}) = string(AssSubSoilClassUnique{i1});
            else
                SubSoilStudy{i2}(IndexInsideSubSoilPolygon{i2}) = AssSubSoilNumUnique{i1};
            end
        end
    end

    Prmpt4Fts = [Prmpt4Fts, "Sub Soil Class [-]"];
    if CategVars
        DatasetFeaturesStudy.SubSoilClass = categorical(cat(1,SubSoilStudy{:}), string(AssSubSoilClassUnique), 'Ordinal',true);
        FeatsType  = [FeatsType, "Categorical"];
        RngsToAdd = [nan, nan];
    else
        DatasetFeaturesStudy.SubSoilClass = cat(1,SubSoilStudy{:});
        FeatsType  = [FeatsType, "Numerical"];
        RngsToAdd = [0, max([Sheet_Info_Div.('Sub soil'){:}{2:end,ColWithClassNum}])];
    end

    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Top Soil
if any(contains([FeatsToUse{:}], ["top", "allfeats"]))
    ProgressBar.Message = "Dataset: associating topsoil classes...";
    load([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], 'TopSoilAllUnique','TopSoilPolygonsStudyArea')

    [ColWithRawClasses, ColWithAss] = deal(false(1, size(Sheet_TopSoilClasses, 2)));
    for i1 = 1:length(ColWithRawClasses)
        ColWithRawClasses(i1) = any(cellfun(@(x) strcmp(string(x), 'Raw data name'), Sheet_TopSoilClasses(:,i1)));
        ColWithAss(i1)        = any(cellfun(@(x) strcmp(string(x), 'Ass. class'),    Sheet_TopSoilClasses(:,i1)));
    end

    [AssTopSoilClass, AssTopSoilNum] = deal(cell(size(TopSoilAllUnique)));
    for i1 = 1:length(TopSoilAllUnique)
        RowToTake = strcmp(TopSoilAllUnique{i1}, string(Sheet_TopSoilClasses(:,ColWithRawClasses)));
        NumOfTopSoilClass = Sheet_TopSoilClasses{RowToTake, ColWithAss};
        if isempty(NumOfTopSoilClass) || ismissing(NumOfTopSoilClass)
            warning(['Raw class "',TopSoilAllUnique{i1},'" will be skipped (no association)'])
            continue
        end

        RowToTake = find(NumOfTopSoilClass==[Sheet_Info_Div.('Top soil'){:}{2:end,ColWithClassNum}])+1; % +1 because the first row is char and was excluded in finding equal number, but anyway must be considered in taking the correct row!
        if isempty(RowToTake)
            error(['Raw class "',TopSoilAllUnique{i1},'" has an associated number that is not present in main sheet! Check your excel.'])
        end

        AssTopSoilClass(i1) = Sheet_Info_Div.('Top soil'){:}(RowToTake, ColWithTitles);
        AssTopSoilNum(i1)   = Sheet_Info_Div.('Top soil'){:}(RowToTake, ColWithClassNum);
    end

    [AssTopSoilClassUnique, IndUniqueTopSoil] = unique(AssTopSoilClass(cellfun(@(x) ischar(x)||isstring(x), AssTopSoilClass)));
    AssTopSoilNumUnique = AssTopSoilNum(cellfun(@(x) ischar(x)||isstring(x), AssTopSoilClass));
    AssTopSoilNumUnique = AssTopSoilNumUnique(IndUniqueTopSoil);
    TopSoilPolygons  = repmat(polyshape, 1, length(AssTopSoilClassUnique));
    for i1 = 1:length(AssTopSoilClassUnique)
        IndToUnify = strcmp(AssTopSoilClassUnique{i1}, AssTopSoilClass);
        TopSoilPolygons(i1) = union(TopSoilPolygonsStudyArea(IndToUnify));
    end

    if CategVars
        TopSoilStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    else
        TopSoilStudy = cellfun(@(x) zeros(size(x)),   xLongStudy, 'UniformOutput',false);
    end

    for i1 = 1:length(TopSoilPolygons)
        [pp1,ee1] = getnan2([TopSoilPolygons(i1).Vertices; nan, nan]);
        IndexInsideTopSoilPolygon = cellfun(@(x,y) inpoly([x,y],pp1,ee1), xLongStudy, yLatStudy, 'Uniform',false);
        for i2 = 1:size(xLongAll,2)
            if CategVars
                TopSoilStudy{i2}(IndexInsideTopSoilPolygon{i2}) = string(AssTopSoilClassUnique{i1});
            else
                TopSoilStudy{i2}(IndexInsideTopSoilPolygon{i2}) = AssTopSoilNumUnique{i1};
            end
        end
    end

    Prmpt4Fts = [Prmpt4Fts, "Top Soil Class [-]"];
    if CategVars
        DatasetFeaturesStudy.TopSoilClass = categorical(cat(1,TopSoilStudy{:}), string(AssTopSoilClassUnique), 'Ordinal',true);
        FeatsType  = [FeatsType, "Categorical"];
        RngsToAdd = [nan, nan];
    else
        DatasetFeaturesStudy.TopSoilClass = cat(1,TopSoilStudy{:});
        FeatsType  = [FeatsType, "Numerical"];
        RngsToAdd = [0, max([Sheet_Info_Div.('Top soil'){:}{2:end,ColWithClassNum}])];
    end

    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Land Use
if any(contains([FeatsToUse{:}], ["land", "allfeats"]))
    ProgressBar.Message = "Dataset: associating land use classes...";
    load([fold_var,sl,'LandUsesVariables.mat'], 'AllLandUnique','LandUsePolygonsStudyArea')

    [ColWithRawClasses, ColWithAss] = deal(false(1, size(Sheet_LandUseClasses, 2)));
    for i1 = 1:length(ColWithRawClasses)
        ColWithRawClasses(i1) = any(cellfun(@(x) strcmp(string(x), 'Raw data name'), Sheet_LandUseClasses(:,i1)));
        ColWithAss(i1)        = any(cellfun(@(x) strcmp(string(x), 'Ass. class'),    Sheet_LandUseClasses(:,i1)));
    end

    [AssLandUseClass, AssLandUseNum] = deal(cell(size(AllLandUnique)));
    for i1 = 1:length(AllLandUnique)
        RowToTake = strcmp(AllLandUnique{i1}, string(Sheet_LandUseClasses(:,ColWithRawClasses)));
        NumOfLandUseClass = Sheet_LandUseClasses{RowToTake, ColWithAss};
        if isempty(NumOfLandUseClass) || ismissing(NumOfLandUseClass)
            warning(['Raw class "',AllLandUnique{i1},'" will be skipped (no association)'])
            continue
        end

        RowToTake = find(NumOfLandUseClass==[Sheet_Info_Div.('Land use'){:}{2:end,ColWithClassNum}])+1; % +1 because the first row is char and was excluded in finding equal number, but anyway must be considered in taking the correct row!
        if isempty(RowToTake)
            error(['Raw class "',AllLandUnique{i1},'" has an associated number that is not present in main sheet! Check your excel.'])
        end

        AssLandUseClass(i1) = Sheet_Info_Div.('Land use'){:}(RowToTake, ColWithTitles);
        AssLandUseNum(i1)   = Sheet_Info_Div.('Land use'){:}(RowToTake, ColWithClassNum);
    end

    [AssLandUseClassUnique, IndUniqueLandUse] = unique(AssLandUseClass(cellfun(@(x) ischar(x)||isstring(x), AssLandUseClass)));
    AssLandUseNumUnique = AssLandUseNum(cellfun(@(x) ischar(x)||isstring(x), AssLandUseClass));
    AssLandUseNumUnique = AssLandUseNumUnique(IndUniqueLandUse);
    LandUsePolygons  = repmat(polyshape, 1, length(AssLandUseClassUnique));
    for i1 = 1:length(AssLandUseClassUnique)
        IndToUnify = strcmp(AssLandUseClassUnique{i1}, AssLandUseClass);
        LandUsePolygons(i1) = union(LandUsePolygonsStudyArea(IndToUnify));
    end

    if CategVars
        LandUseStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    else
        LandUseStudy = cellfun(@(x) zeros(size(x)),   xLongStudy, 'UniformOutput',false);
    end

    for i1 = 1:length(LandUsePolygons)
        [pp1,ee1] = getnan2([LandUsePolygons(i1).Vertices; nan, nan]);
        IndexInsideLandUsePolygon = cellfun(@(x,y) inpoly([x,y],pp1,ee1), xLongStudy, yLatStudy, 'Uniform',false);
        for i2 = 1:size(xLongAll,2)
            if CategVars
                LandUseStudy{i2}(IndexInsideLandUsePolygon{i2}) = string(AssLandUseClassUnique{i1});
            else
                LandUseStudy{i2}(IndexInsideLandUsePolygon{i2}) = AssLandUseNumUnique{i1};
            end
        end
    end

    Prmpt4Fts = [Prmpt4Fts, "Land Use Class [-]"];
    if CategVars
        DatasetFeaturesStudy.LandUseClass = categorical(cat(1,LandUseStudy{:}), string(AssLandUseClassUnique), 'Ordinal',true);
        FeatsType  = [FeatsType, "Categorical"];
        RngsToAdd = [nan, nan];
    else
        DatasetFeaturesStudy.LandUseClass = cat(1,LandUseStudy{:});
        FeatsType  = [FeatsType, "Numerical"];
        RngsToAdd = [0, max([Sheet_Info_Div.('Land use'){:}{2:end,ColWithClassNum}])];
    end

    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Vegetation
if any(contains([FeatsToUse{:}], ["vegetation", "allfeats"]))
    ProgressBar.Message = "Dataset: associating vegetation classes...";
    load([fold_var,sl,'VegPolygonsStudyArea.mat'], 'VegetationAllUnique','VegPolygonsStudyArea')

    [ColWithRawClasses, ColWithAss] = deal(false(1, size(Sheet_VegetClasses, 2))); % RIPRENDI QUA
    for i1 = 1:length(ColWithRawClasses)
        ColWithRawClasses(i1) = any(cellfun(@(x) strcmp(string(x), 'Raw data name'), Sheet_VegetClasses(:,i1)));
        ColWithAss(i1)        = any(cellfun(@(x) strcmp(string(x), 'Ass. class'),    Sheet_VegetClasses(:,i1)));
    end

    [AssVegetClass, AssVegetNum] = deal(cell(size(VegetationAllUnique)));
    for i1 = 1:length(VegetationAllUnique)
        RowToTake = strcmp(VegetationAllUnique{i1}, string(Sheet_VegetClasses(:,ColWithRawClasses)));
        NumOfVegetClass = Sheet_VegetClasses{RowToTake, ColWithAss};
        if isempty(NumOfVegetClass) || ismissing(NumOfVegetClass)
            warning(['Raw class "',VegetationAllUnique{i1},'" will be skipped (no association)'])
            continue
        end

        RowToTake = find(NumOfVegetClass==[Sheet_Info_Div.('Vegetation'){:}{2:end,ColWithClassNum}])+1; % +1 because the first row is char and was excluded in finding equal number, but anyway must be considered in taking the correct row!
        if isempty(RowToTake)
            error(['Raw class "',VegetationAllUnique{i1},'" has an associated number that is not present in main sheet! Check your excel.'])
        end

        AssVegetClass(i1) = Sheet_Info_Div.('Vegetation'){:}(RowToTake, ColWithTitles);
        AssVegetNum(i1)   = Sheet_Info_Div.('Vegetation'){:}(RowToTake, ColWithClassNum);
    end

    [AssVegetClassUnique, IndUniqueVeget] = unique(AssVegetClass(cellfun(@(x) ischar(x)||isstring(x), AssVegetClass)));
    AssVegetNumUnique = AssVegetNum(cellfun(@(x) ischar(x)||isstring(x), AssVegetClass));
    AssVegetNumUnique = AssVegetNumUnique(IndUniqueVeget);
    VegetPolygons  = repmat(polyshape, 1, length(AssVegetClassUnique));
    for i1 = 1:length(AssVegetClassUnique)
        IndToUnify = strcmp(AssVegetClassUnique{i1}, AssVegetClass);
        VegetPolygons(i1) = union(VegPolygonsStudyArea(IndToUnify));
    end

    if CategVars
        VegetStudy = cellfun(@(x) strings(size(x)), xLongStudy, 'UniformOutput',false);
    else
        VegetStudy = cellfun(@(x) zeros(size(x)),   xLongStudy, 'UniformOutput',false);
    end

    for i1 = 1:length(VegetPolygons)
        [pp1,ee1] = getnan2([VegetPolygons(i1).Vertices; nan, nan]);
        IndexInsideVegetPolygon = cellfun(@(x,y) inpoly([x,y],pp1,ee1), xLongStudy, yLatStudy, 'Uniform',false);
        for i2 = 1:size(xLongAll,2)
            if CategVars
                VegetStudy{i2}(IndexInsideVegetPolygon{i2}) = string(AssVegetClassUnique{i1});
            else
                VegetStudy{i2}(IndexInsideVegetPolygon{i2}) = AssVegetNumUnique{i1};
            end
        end
    end

    Prmpt4Fts = [Prmpt4Fts, "Vegetation Class [-]"];
    if CategVars
        DatasetFeaturesStudy.VegetationClass = categorical(cat(1,VegetStudy{:}), string(AssVegetClassUnique), 'Ordinal',true);
        FeatsType  = [FeatsType, "Categorical"];
        RngsToAdd = [nan, nan];
    else
        DatasetFeaturesStudy.VegetationClass = cat(1,VegetStudy{:});
        FeatsType  = [FeatsType, "Numerical"];
        RngsToAdd = [0, max([Sheet_Info_Div.('Vegetation'){:}{2:end,ColWithClassNum}])];
    end

    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

%% Loading of features (time sensitive part)
ProgressBar.Message = 'Dataset: reading time sensitive part...';

TimeSensitiveParam = {};
CumulableParam     = [];
TimeSensitiveData  = {};
TimeSensitiveDate  = {};

% Rainfall
if any(contains([FeatsToUse{:}], ["rain", "allfeats"]))
    load([fold_var,sl,'RainInterpolated.mat'], 'RainInterpolated','RainDateInterpolationStarts')

    TimeSensitiveParam = [TimeSensitiveParam, {'Rainfall'}];
    CumulableParam     = [CumulableParam, 1];
    TimeSensitiveData  = [TimeSensitiveData, {RainInterpolated}];
    TimeSensitiveDate  = [TimeSensitiveDate, {RainDateInterpolationStarts}];
    clear('RainInterpolated')

    if strcmp(ModeForTS, "cumuloravg")
        Prmpt4Fts    = [Prmpt4Fts, strcat("Rainfall Cumulate ",num2str(DaysForTS), "d [mm]")];
        FeatsType    = [FeatsType, "TimeSensitive"];
        MaxDailyRain = 30; % To discuss this value (max in Emilia was 134 mm in a day)
        RngsToAdd    = [0, MaxDailyRain*DaysForTS];
    elseif strcmp(ModeForTS, "multipleseparatedays")
        Prmpt4Fts = [Prmpt4Fts, "Rainfall Daily [mm]"];
        FeatsType = [FeatsType, repmat("TimeSensitive",1,DaysForTS)];
        RngsToAdd = [0, 120];
    end
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Temperature
if any(contains([FeatsToUse{:}], ["temp", "allfeats"]))
    load([fold_var,sl,'TempInterpolated.mat'], 'TempInterpolated','TempDateInterpolationStarts')

    TimeSensitiveParam = [TimeSensitiveParam, {'Temperature'}];
    CumulableParam     = [CumulableParam, 0];
    TimeSensitiveData  = [TimeSensitiveData, {TempInterpolated}];
    TimeSensitiveDate  = [TimeSensitiveDate, {TempDateInterpolationStarts}];
    clear('TempInterpolated')

    if strcmp(ModeForTS, "cumuloravg")
        Prmpt4Fts = [Prmpt4Fts, strcat("Temperature Average ",num2str(DaysForTS), "d [°]")];
        FeatsType = [FeatsType, "TimeSensitive"];
    elseif strcmp(ModeForTS, "multipleseparatedays")
        Prmpt4Fts = [Prmpt4Fts, "Temperature Daily [°]"];
        FeatsType = [FeatsType, repmat("TimeSensitive",1,DaysForTS)];
    end
    RngsToAdd = [-10, 35]; % In Celsius
    if NormData; SuggRanges = [SuggRanges; RngsToAdd]; end
end

% Uniformization of Time Sensitive
TimeSensExist = false;
if any(contains([FeatsToUse{:}], ["rain", "temp", "allfeats"]))
    TimeSensExist   = true;
    CumulableParam  = logical(CumulableParam);
    StartDateCommon = max(cellfun(@min, TimeSensitiveDate)); % Start in end dates
    EndDateCommon   = min(cellfun(@max, TimeSensitiveDate)); % End in end dates

    if EndDateCommon < StartDateCommon
        error('Time sensitive part has no datetime in common! Please re-interpolate time sensitive part.')
    end

    if length(TimeSensitiveParam) > 1
        for i1 = 1 : length(TimeSensitiveParam)
            IndStartCommon = find(StartDateCommon == TimeSensitiveDate{i1}); % You should put an equal related to days and not exact timing
            IndEventCommon = find(EndDateCommon   == TimeSensitiveDate{i1}); % You should put an equal related to days and not exact timing
            TimeSensitiveData{i1} = TimeSensitiveData{i1}(IndStartCommon:IndEventCommon,:);
            TimeSensitiveDate{i1} = TimeSensitiveDate{i1}(IndStartCommon:IndEventCommon);
        end
        if length(TimeSensitiveDate)>1 && ~isequal(TimeSensitiveDate{:})
            error('After uniformization of dates in time sensitive part, number of elements is not consistent! Please check it in the script.')
        end
    end

    TimeSensitiveDate = TimeSensitiveDate{1}; % Taking only the first one since they are identical!

    if exist('EventDay', 'var')
        RowToTake = find(TimeSensitiveDate == EventDay);
        if isempty(RowToTake); error('The date you chosed as input does not exist in your merged data!'); end
    else
        RowToTake = listdlg('PromptString',{'Select the date to consider (start times of 24 h):',''}, ...
                            'ListString',TimeSensitiveDate, 'SelectionMode','single');
    end

    TimeSensitiveDatetimeChosed = TimeSensitiveDate(RowToTake);

    if TimeSensitiveDate(RowToTake) < TimeSensitiveDate(DaysForTS)
        error(['You have selected a date that not allow to consider ',num2str(DaysForTS),' days before your choice! Please retry.'])
    end

    TimeSensitiveDataStudy = cell(1, length(TimeSensitiveParam));
    for i1 = 1:length(TimeSensitiveParam)
        TimeSensitiveDataStudy{i1} = cellfun(@full, TimeSensitiveData{i1}, 'UniformOutput',false);
    end
    clear('TimeSensitiveData')

    if strcmp(ModeForTS, "cumuloravg")
        ColumnsToAdd = cell(1, length(TimeSensitiveParam));
        for i1 = 1:length(TimeSensitiveParam)
            ColumnToAddTemp = cell(1, size(TimeSensitiveDataStudy{i1}, 2));
            for i2 = 1:size(TimeSensitiveDataStudy{i1}, 2)
                if CumulableParam(i1)
                    ColumnToAddTemp{i2} = sum([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                else
                    ColumnToAddTemp{i2} = mean([TimeSensitiveDataStudy{i1}{RowToTake : -1 : (RowToTake-DaysForTS+1), i2}], 2);
                end
            end
            ColumnsToAdd{i1} = cat(1,ColumnToAddTemp{:});
        end
    
        TimeSensitiveOper = repmat({'Averaged'}, 1, length(TimeSensitiveParam));
        TimeSensitiveOper(CumulableParam) = {'Cumulated'};
    
        FeaturesNamesToAdd  = cellfun(@(x, y) [x,y,num2str(DaysForTS),'d'], TimeSensitiveParam, TimeSensitiveOper, 'UniformOutput',false);
        
        for i1 = 1:length(TimeSensitiveParam)
            DatasetFeaturesStudy.(FeaturesNamesToAdd{i1}) = ColumnsToAdd{i1};
        end
    elseif strcmp(ModeForTS, "multipleseparatedays")
        ColumnsToAdd = cell(DaysForTS, length(TimeSensitiveParam));
        RowsToTake = RowToTake : -1 : (RowToTake-DaysForTS+1);
        for i1 = 1:DaysForTS
            ColumnsToAdd(i1,:) = cellfun(@(x) cat(1,x{RowsToTake(i1),:}), TimeSensitiveDataStudy, 'UniformOutput',false);
        end

        FeaturesNamesToAdd = cellfun(@(x) strcat(x,'-',string(1:DaysForTS)','daysBefore'), TimeSensitiveParam, 'UniformOutput',false);

        for i1 = 1:length(TimeSensitiveParam) % It is important to follow this order for normalization!
            for i2 = 1:DaysForTS
                DatasetFeaturesStudy.(FeaturesNamesToAdd{i1}(i2)) = ColumnsToAdd{i2,i1};
            end
        end
    else
        error('Something went wrong in selecting the mode for time sensitive, please check "datasetstudy_creation"')
    end
end

%% Normalization
ProgressBar.Message = 'Dataset: normalization of data...';

FeatsDataset = DatasetFeaturesStudy.Properties.VariableNames;
if NormData
    if not(exist('Ranges', 'var'))
        PromptForRanges = strcat("Ranges for ", Prmpt4Fts');
        RangesInputs = inputdlg( PromptForRanges, '', 1, ...
                                 strcat("[",num2str(round(SuggRanges(:,1),3,'significant'), '%.2e'),", ", ...
                                            num2str(round(SuggRanges(:,2),3,'significant'), '%.2e'),"]")      );

        TSCount = 1;
        CurrRow = 1;
        Ranges  = zeros(length(FeatsDataset), 2);
        for i1 = 1:length(FeatsDataset)
            Ranges(i1,:) = str2num(RangesInputs{CurrRow});
            if not(strcmp(FeatsType(i1), "TimeSensitive"))
                CurrRow = CurrRow + 1;
            elseif strcmp(FeatsType(i1), "TimeSensitive") && strcmp(ModeForTS, "multipleseparatedays") % Pay attention to order of TimeSens vars in Dataset!
                TSCount = TSCount + 1;
                if TSCount > DaysForTS
                    TSCount = 1;
                    CurrRow = CurrRow + 1;
                end
            elseif strcmp(FeatsType(i1), "TimeSensitive") && strcmp(ModeForTS, "cumuloravg") % Maybe not necessary
                CurrRow = CurrRow + 1; % Maybe not necessary
            end
        end
        Ranges = array2table(Ranges, 'RowNames',FeatsDataset, ...
                                     'VariableNames',["Min value", "Max value"]);
    end

    DatasetFeaturesStudyNorm = table();
    for i1 = 1:size(DatasetFeaturesStudy,2)
        if not(strcmp(FeatsType(i1), "Categorical"))
            DatasetFeaturesStudyNorm.(FeatsDataset{i1}) = rescale(DatasetFeaturesStudy.(FeatsDataset{i1}), ...
                                                                           'InputMin',Ranges{FeatsDataset{i1}, 1}, ...
                                                                           'InputMax',Ranges{FeatsDataset{i1}, 2});
        elseif strcmp(FeatsType(i1), "Categorical")
            DatasetFeaturesStudyNorm.(FeatsDataset{i1}) = DatasetFeaturesStudy.(FeatsDataset{i1});
        end
    end
else
    Ranges = array2table(nan(size(DatasetFeaturesStudy,2), 2), 'RowNames',FeatsDataset, ...
                                                               'VariableNames',["Min value", "Max value"]);
end

%% Output creation
ProgressBar.Message = 'Dataset: Outputs...';

if NormData
    varargout{1} = DatasetFeaturesStudyNorm;
    varargout{5} = DatasetFeaturesStudy;
else
    varargout{1} = DatasetFeaturesStudy;
    varargout{5} = DatasetFeaturesStudy;
end

varargout{2} = DatasetCoordinatesStudy;
varargout{3} = Ranges;

if TimeSensExist
    varargout{4} = table(TimeSensitiveParam, TimeSensitiveDatetimeChosed, TimeSensitiveDate, ...
                         TimeSensitiveDataStudy, CumulableParam, 'VariableNames',{'ParamNames', 'EventTime', 'Datetimes', 'Data', 'Cumulable'});
else
    varargout{4} = table("No Time Sensitive data selected as input!", 'VariableNames',{'EventTime'});
end

varargout{6} = FeatsType;

end