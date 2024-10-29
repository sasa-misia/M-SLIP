function [IndicesUsed, ExpcOutputs] = dataset_poly_idx(DatasetCoords, DatasetFeatures, UnstablePoly, StablePoly, varargin)

% CREATE AN INDEX ARRAY TO USE IN TRAINING OF ML, WITH RELATIVE OUTPUTS
%   
% Outputs:
%   [IndicesUsed, ExpcOutputs]
%   
% Required arguments:
%   - DatasetStudy : is the dataset of your entire study area. It is
%   preferable to give it with NOT normalized data.
%   
%   - UnstablePoly : is the polyshape containing the contour of unstable
%   points. It can be both a multi or a single merged polygon.
%   
%   - StablePoly : is the polyshape containing the contour of stable points. 
%   It can be both a multi or a single merged polygon.
%   
% Optional arguments:
%   - 'StableMethod', string : is to specify the criterion you want to adopt 
%   in picking stable points. Possible values can be 'EntireStable', 'Slope'.
%   If no value is specified, then 'EntireStable' will be taken as default.
%   
%   - 'ModifyRatio', logical : is to specify if you want or not to balance
%   the ratio between positive and negative points (outputs in training).
%   If no value is specified, then true value will be taken as default.
%   
%   - 'RatioToImpose', num : is to specify the new ratio you want to impose between
%   classes. If no value is specified, then a ratio of 1:1 will be taken.
%   
%   - 'ResampleMode', string : is to specify the way you want to rebalance
%   the ratio between positive and negative points (outputs in training).
%   Possible string values are 'Undersampling', 'Oversampling'.
%   If no value is specified, then 'Undersampling' will be taken as default.
%   
%   - 'DayOfLandslide', logical : is to specify if the day you are using in
%   your Dataset is the one of when the landslide was detected. If no value 
%   is specified, then true value will be taken as default.
%   
%   - 'CriticalSlope', num : is to specify the critical slope below which you 
%   have stable points. It will only have an effect if 'StableMethod' is set 
%   to 'Slope'. If no value is specified, then 8° will be taken as default.
%   
%   - 'KeepUnstable', logical : is to specify if you want to keep all the
%   points inside the unstable area during eventual resampling. If no value 
%   is specified, then false value will be taken as default.

%% Settings initialization
StableMethod  = "entirestable";  % Default
ModifyRatio   = true;            % Default
RatioToImpose = 1;               % Default
ResampleMode  = "undersampling"; % Default
LandslideDay  = true;            % Default
CriticalSlope = 8;               % Default
KeepUnstable  = false;           % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(StringPart) = varargin(StringPart);

    InputStableMethod = find(cellfun(@(x) strcmpi(x, "stablemethod"  ), vararginCopy));
    InputModifyRatio  = find(cellfun(@(x) strcmpi(x, "modifyratio"   ), vararginCopy));
    InputResampleMode = find(cellfun(@(x) strcmpi(x, "resamplemode"  ), vararginCopy));
    InputRatio2Impose = find(cellfun(@(x) strcmpi(x, "ratiotoimpose" ), vararginCopy));
    InputLandslideDay = find(cellfun(@(x) strcmpi(x, "dayoflandslide"), vararginCopy));
    InputCriticSlope  = find(cellfun(@(x) strcmpi(x, "criticalslope" ), vararginCopy));
    InputKeepUnstable = find(cellfun(@(x) strcmpi(x, "keepunstable"  ), vararginCopy));

    if InputStableMethod; StableMethod  = varargin{InputStableMethod+1}; end
    if InputModifyRatio ; ModifyRatio   = varargin{InputModifyRatio+1} ; end
    if InputResampleMode; ResampleMode  = varargin{InputResampleMode+1}; end
    if InputRatio2Impose; RatioToImpose = varargin{InputRatio2Impose+1}; end
    if InputLandslideDay; LandslideDay  = varargin{InputLandslideDay+1}; end
    if InputCriticSlope ; CriticalSlope = varargin{InputCriticSlope+1} ; end
    if InputKeepUnstable; KeepUnstable  = varargin{InputKeepUnstable+1}; end
end

%% Core
% Union of multi polygons
if length(UnstablePoly) > 1
    UnstabPolyMrgd = union(UnstablePoly);
    StablePolyMrgd = union(StablePoly);
else
    UnstabPolyMrgd = UnstablePoly;
    StablePolyMrgd = StablePoly;
end

% Index of study area points inside polygons
[ppUn, eeUn] = getnan2([UnstabPolyMrgd.Vertices; nan, nan]);
IndsInUnstab = inpoly([DatasetCoords.Longitude,DatasetCoords.Latitude], ppUn,eeUn);

[ppSt, eeSt] = getnan2([StablePolyMrgd.Vertices; nan, nan]);
IndsInStable = inpoly([DatasetCoords.Longitude,DatasetCoords.Latitude], ppSt,eeSt);

% Definition of unconditionally stable points and reduction of tables
switch StableMethod
    case "slope"
        IndsBelowCritSlope = DatasetFeatures.Slope <= CriticalSlope;
        IndsInStable = (IndsInStable & IndsBelowCritSlope);
end

IndicesUsed = [find(IndsInUnstab)        ; find(IndsInStable)         ]; % Default, no resampling!
ExpcOutputs = [true(sum(IndsInUnstab), 1); false(sum(IndsInStable), 1)]; % Default, no resampling!

if ModifyRatio
    Inds2Keep = false(size(IndicesUsed));
    if KeepUnstable && strcmpi(ResampleMode, 'undersampling')
        Inds2Keep = inpoly([DatasetCoords.Longitude(IndicesUsed),DatasetCoords.Latitude(IndicesUsed)], ppUn,eeUn);
    end
    [~, ~, ExpOutsReb, RelIndsTk] = dataset_rebalance({NaT(size(ExpcOutputs))}, ...
                                                      {DatasetFeatures(IndicesUsed,:)}, ...
                                                      {ExpcOutputs}, RatioToImpose, ...
                                                      ResampleMode, 'CrucialObs',{Inds2Keep});
    if not(isscalar(ExpOutsReb))
        error('Error in dataset after rebalance! It must be a single cell!')
    end

    RelIndsTk   = RelIndsTk{1};
    IndicesUsed = IndicesUsed(RelIndsTk);
    ExpcOutputs = ExpOutsReb{1};

    StabPart = ExpcOutputs == 0;
    UnstPart = ExpcOutputs >= 1;
    IndsStab = IndicesUsed(StabPart);
    IndsUnst = IndicesUsed(UnstPart);
    IndsStab(isnan(IndsStab)) = []; % With SMOTE you have synthetic data, i.e., NaNs, that should not be take into account!
    IndsUnst(isnan(IndsUnst)) = []; % With SMOTE you have synthetic data, i.e., NaNs, that should not be take into account!
    IsInStab = inpoly([DatasetCoords.Longitude(IndsStab),DatasetCoords.Latitude(IndsStab)], ppSt,eeSt);
    IsInUnst = inpoly([DatasetCoords.Longitude(IndsUnst),DatasetCoords.Latitude(IndsUnst)], ppUn,eeUn);
    if not(all(IsInUnst) && all(IsInStab))
        error('There was an error in rebalancing!')
    end
end

if not(LandslideDay)
    ExpcOutputs = false(size(ExpcOutputs));
end

end