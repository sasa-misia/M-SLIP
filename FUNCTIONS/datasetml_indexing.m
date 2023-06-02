function [IndicesTrainDataset, ExpectedOutputs] = datasetml_indexing(DatasetCoords, DatasetFeatures, UnstablePoly, StablePoly, varargin)

% CREATE AN INDEX ARRAY TO USE IN TRAINING OF ML, WITH RELATIVE OUTPUTS
%   
% Outputs:
%   [IndicesOfTrainDataset, ExpectedOutputs]
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
%   to 'Slope'. If no value is specified, then 8° will be take as default.

%% Settings initialization
StableMethod  = "entirestable";  % Default
ModifyRatio   = true;            % Default
RatioToImpose = 1;               % Default
ResampleMode  = "undersampling"; % Default
LandslideDay  = true;            % Default
CriticalSlope = 8;               % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(StringPart) = varargin(StringPart);

    InputStableMethod = find(cellfun(@(x) strcmpi(x, "stablemethod"),   vararginCopy));
    InputModifyRatio  = find(cellfun(@(x) strcmpi(x, "modifyratio"),    vararginCopy));
    InputResampleMode = find(cellfun(@(x) strcmpi(x, "resamplemode"),   vararginCopy));
    InputRatio2Impose = find(cellfun(@(x) strcmpi(x, "ratiotoimpose"),  vararginCopy));
    InputLandslideDay = find(cellfun(@(x) strcmpi(x, "dayoflandslide"), vararginCopy));
    InputCriticSlope  = find(cellfun(@(x) strcmpi(x, "criticalslope"),  vararginCopy));

    if InputStableMethod; StableMethod  = varargin{InputStableMethod+1}; end
    if InputModifyRatio;  ModifyRatio   = varargin{InputModifyRatio+1};  end
    if InputResampleMode; ResampleMode  = varargin{InputResampleMode+1}; end
    if InputRatio2Impose; RatioToImpose = varargin{InputRatio2Impose+1}; end
    if InputLandslideDay; LandslideDay  = varargin{InputLandslideDay+1}; end
    if InputCriticSlope;  CriticalSlope = varargin{InputCriticSlope+1};  end
end

%% Union of multi polygons
if length(UnstablePoly) > 1
    UnstablePolyMrgd = union(UnstablePoly);
    StablePolyMrgd   = union(StablePoly);
else
    UnstablePolyMrgd = UnstablePoly;
    StablePolyMrgd   = StablePoly;
end

%% Index of study area points inside polygons
[pp1, ee1] = getnan2([UnstablePolyMrgd.Vertices; nan, nan]);
IndsInUnstable = inpoly([DatasetCoords.Longitude,DatasetCoords.Latitude], pp1,ee1);

[pp2, ee2] = getnan2([StablePolyMrgd.Vertices; nan, nan]);
IndsInStable   = inpoly([DatasetCoords.Longitude,DatasetCoords.Latitude], pp2,ee2);

%% Definition of unconditionally stable points and reduction of tables
switch StableMethod
    case "slope"
        IndsBelowCritSlope = DatasetFeatures.Slope <= CriticalSlope;
        IndsInStable = (IndsInStable & IndsBelowCritSlope);
end

RatioBeforeResampling = sum(IndsInUnstable)/sum(IndsInStable);

if ModifyRatio
    switch ResampleMode % NOTE THAT WORKS ONLY IF STABLES > UNSTABLES, PLEASE MODIFY IT!
        case "undersampling"
            IndsNumsStable = find(IndsInStable);
        
            PercToRemove = 1-RatioBeforeResampling/RatioToImpose; % Think about this formula please!
        
            RelIndOfStabToChange = randperm(numel(IndsNumsStable), ceil(numel(IndsNumsStable)*PercToRemove));
            IndsToChange = IndsNumsStable(RelIndOfStabToChange);

            IndsInStable(IndsToChange) = false;
        
            RatioAfterResampling = sum(IndsInUnstable)/sum(IndsInStable);
            if (any(IndsInUnstable & IndsInStable)) || (round(RatioToImpose, 1) ~= round(RatioAfterResampling, 1))
                error("Something went wrong in re-attributing the correct ratio between positive and negative outputs!")
            end

            IndicesTrainDataset = [find(IndsInUnstable);         find(IndsInStable)];
            ExpectedOutputs     = [true(sum(IndsInUnstable), 1); false(sum(IndsInStable), 1)];

        case "oversampling"
            IndsNumsUnstable = find(IndsInUnstable);
            IndsNumsStable   = find(IndsInStable);

            PercToAdd = RatioToImpose/RatioBeforeResampling; % Think about this formula please!

            NumOfReps = fix(PercToAdd);

            RelIndOfUntabToAdd = randperm(numel(IndsNumsUnstable), ceil(numel(IndsNumsUnstable)*(PercToAdd-NumOfReps)));

            IndsUnstableRepeated = [repmat(IndsNumsUnstable, NumOfReps, 1); IndsNumsUnstable(RelIndOfUntabToAdd)];

            RatioAfterResampling = numel(IndsUnstableRepeated)/numel(IndsNumsStable);
            if (not(isempty(intersect(IndsUnstableRepeated,IndsNumsStable)))) || (round(RatioToImpose, 1) ~= round(RatioAfterResampling, 1))
                error("Something went wrong in re-attributing the correct ratio between positive and negative outputs!")
            end

            IndicesTrainDataset = [IndsUnstableRepeated;                 IndsNumsStable];
            ExpectedOutputs     = [true(numel(IndsUnstableRepeated), 1); false(numel(IndsNumsStable), 1)];
    end

else
    IndicesTrainDataset = [find(IndsInUnstable);         find(IndsInStable)];
    ExpectedOutputs     = [true(sum(IndsInUnstable), 1); false(sum(IndsInStable), 1)];
end

if not(LandslideDay)
    ExpectedOutputs = false(size(ExpectedOutputs));
end

end