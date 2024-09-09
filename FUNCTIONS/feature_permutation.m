function FeatureImportance = feature_permutation(ModelToUse, DatasetToUse, ExpOutsToUse, varargin)

% Function to evaluate the importance of features with ML models (not only)
% with Feature Permutation technique.
%   
%   FeatureImportance = feature_permutation(ModelToUse, DatasetToUse, ExpOutsToUse, varargin)
%   
%   Dependencies: mdlpredict function from M-SLIP toolbox.
%   
% Outputs:
%   FeatureImportance : a table containing the differences in terms of Loss
%   and MSE, in addition to the percentage of importance for each feature
%   based on the same metrics above.
%   
% Required arguments:
%   - ModelToUse : model object to use for feature importance assessment.
%   
%   - DatasetToUse : dataset to use for feature importance. It can be the
%   training dataset, the test (suggested) or the total one, i.e., test +
%   training. It can be a table or a numeric matrix.
%   
%   - ExpOutsToUse : expected outputs to use, based on the DatasetToUse input.
%   It must be a numeric array.
%   
% Optional arguments:
%   - 'PermType', string/char : is to define the type of algorithm do you
%   want in changing values of the features. It can be 'AllRange' or 'Shuffle'.
%   If set to 'Shuffle' the function will change randomly the order of the 
%   values just for the feature analyzed, cycle per cycle, but mantaining the 
%   original values (this means that if all the values of the feature are only 
%   a single number, e.g., 0.2, this operation is inefficient because the 
%   values, after the shuffle operation will be the same in each observation).
%   The latter process is repeated a number X (based on RandIters) of times
%   with each feature.
%   If set to 'AllRange', the values of the feature analyzed will change 
%   uniformly the value starting from a minimum to a maximum value in X 
%   intervals. By default the number of interval, i.e., the number of cycles, 
%   based on which the uniform value changes, it is a number X (based on 
%   RandIters) of times.
%   If no value is set, then 'Shuffle' will be take as default.
%   
%   - 'RandIters', scalar number : is the number X of times based on which
%   you repeat the 'Shuffle' operaton, or the number of intervals to use
%   for the 'AllRange' operation. If no value is set, then 10 will be take
%   as default!
%   
%   - 'RangeVals', numeric array : is the array of size 1x2 or 2x1 containing 
%   respectively the minimum and the maximum value to use with 'AllRange' in
%   'PermType'. It is effective only when 'PermType' is set to 'AllRange',
%   otherwise is useless. The first number must be the minimum of the range. 
%   If no value is set, then [0, 1] will be take as default!
%   
%   - 'RandSeed', numeric scalar : is to control the randomization process
%   in case of 'PermType' set on 'Shuffle'. Based on this seed you can have
%   different permutations of the values. Despite this, if 'RandIters' is
%   high enough, it will be not very impactful. If No value is set, then 17
%   will be take as default!

%% Input Check
if not(isnumeric(DatasetToUse) || istable(DatasetToUse))
    error('DatasetToUse (2nd input) must be numeric matrix or table!')
end

if isnumeric(DatasetToUse)
    warning(['DatasetToUse (2nd input) is numeric. Please keep attention ', ...
             'to the order of the columns, because they must be in the same', ...
             'order used while the model was training!'])
end

if not(isnumeric(ExpOutsToUse))
    error('ExpOutsToUse (3rd input) must be a numeric array!')
end

if numel(unique(ExpOutsToUse))-1 ~= max(ExpOutsToUse) % If there is a void in classes it will not work!
    error(['Expected outputs must be an array containing ', ...
           'classes, not a regression! Please contact the support.'])
end

%% Settings
PermType  = 'shuffle'; % Default
RandIters = 10;        % Default
RangeVals = [0, 1];    % Default
RandSeed  = 17;        % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputPermType  = find(cellfun(@(x) all(strcmpi(x, "permtype" )), vararginCp));
    InputRandIters = find(cellfun(@(x) all(strcmpi(x, "randiters")), vararginCp));
    InputRangeVals = find(cellfun(@(x) all(strcmpi(x, "rangevals")), vararginCp));
    InputRandSeed  = find(cellfun(@(x) all(strcmpi(x, "randseed" )), vararginCp));

    if InputPermType ; PermType  = vararginCp{InputPermType+1}; end
    if InputRandIters; RandIters = varargin{InputRandIters+1 }; end
    if InputRangeVals; RangeVals = varargin{InputRangeVals+1 }; end
    if InputRandSeed ; RandSeed  = varargin{InputRandSeed+1  }; end

    varargin([ InputPermType , InputPermType+1 , ...
               InputRandIters, InputRandIters+1, ...
               InputRangeVals, InputRangeVals+1, ... 
               InputRandSeed , InputRandSeed+1  ]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(strcmp(PermType, 'shuffle') || strcmp(PermType, 'allrange'))
    error('PermType not recognized! It must be "Shuffle" or "AllRange"!')
end

if not(isscalar(RandIters))
    error('RandIters must be a scalar value!')
end

if not(isnumeric(RangeVals))
    error('RangeVals must be a numeric array!')
end

if not(isequal(size(RangeVals), [1, 2]) || isequal(size(RangeVals), [2, 1]))
    error('RangeVals must be a 1x2 or 2x1 in sizes!')
end

if not(isnumeric(RandSeed) && isscalar(RandSeed))
    error('RandSeed must be a numeric scalar!')
end

%% Core
ExpOutsSg = double(ExpOutsToUse >= 1); % It is to have a single column also in case of multi output!
RngOfVals = linspace(RangeVals(1), RangeVals(2), RandIters);
CurrFeats = DatasetToUse.Properties.VariableNames;
CurrPreds = mdlpredict(ModelToUse, DatasetToUse, 'SingleCol',true);
CurrLoss  = crossentropy2(CurrPreds, ExpOutsSg); % 'crossentropy' is appropriate only for neural network models.
CurrMSE   = mse(ExpOutsSg, CurrPreds);
CurrRMSE  = rmse(CurrPreds, ExpOutsSg);

rng(RandSeed) % To control the randomization process
[IndRand,  RngVals] = deal(zeros(size(DatasetToUse, 1), RandIters));
[PermLoss, PermMSE, PermRMSE] = deal(zeros(RandIters, length(CurrFeats)));
for i1 = 1:RandIters
    switch PermType
        case 'shuffle'
            IndRand(:,i1) = randperm(size(DatasetToUse, 1));

        case 'allrange'
            RngVals(:,i1) = repmat(RngOfVals(i1), size(DatasetToUse, 1), 1);
    end
    
    for i2 = 1:length(CurrFeats)
        DatasetPerm = DatasetToUse;
        switch PermType
            case 'shuffle'
                DatasetPerm{:,CurrFeats{i2}} = DatasetPerm{IndRand(:,i1),CurrFeats{i2}};

            case 'allrange'
                DatasetPerm{:,CurrFeats{i2}} = RngVals(:,i1);
        end

        PermPreds = mdlpredict(ModelToUse, DatasetPerm, 'SingleCol',true);

        PermLoss(i1,i2) = crossentropy2(PermPreds, ExpOutsSg); % 'crossentropy' is appropriate only for neural network models.
        PermMSE(i1,i2)  = mse(ExpOutsSg, PermPreds);
        PermRMSE(i1,i2) = rmse(PermPreds, ExpOutsSg);
    end
end

MeanPermLoss = max(PermLoss, [], 1); % You can also average values: mean(PermLoss,1);
MeanPermMSE  = max(PermMSE,  [], 1); % You can also average values: mean(PermMSE,1);
MeanPermRMSE = max(PermRMSE, [], 1); % You can also average values: mean(PermRMSE,1);

FeatImpDiffLoss = MeanPermLoss-CurrLoss;
FeatImpDiffMSE  = MeanPermMSE-CurrMSE;
FeatImpDiffRMSE = MeanPermRMSE-CurrRMSE;

FeatImpPercLoss = max(FeatImpDiffLoss,0)/sum(max(FeatImpDiffLoss,0)); % The importance can not be negative, thus if a value is negative (better when random) it will be capped to 0 with max(value,0)
FeatImpPercMSE  = max(FeatImpDiffMSE,0)/sum(max(FeatImpDiffMSE,0));   % The importance can not be negative, thus if a value is negative (better when random) it will be capped to 0 with max(value,0)
FeatImpPercRMSE = max(FeatImpDiffRMSE,0)/sum(max(FeatImpDiffRMSE,0));   % The importance can not be negative, thus if a value is negative (better when random) it will be capped to 0 with max(value,0)

FeatureImportance = array2table([FeatImpDiffLoss; FeatImpDiffMSE; FeatImpDiffRMSE; ...
                                 FeatImpPercLoss; FeatImpPercMSE; FeatImpPercRMSE], ...
                                                'RowNames',{'LossDifferences', 'MSEDifferences', 'RMSEDifferences', ...
                                                            'PercentagesLoss', 'PercentagesMSE', 'PercentagesRMSE'}, 'VariableNames',CurrFeats);

end