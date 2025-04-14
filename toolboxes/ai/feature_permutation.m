function featImportance = feature_permutation(model2Use, dataset2Use, expOuts2Use, Options)

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
%   If no value is set, then 'AllRange' will be take as default.
%   
%   - 'RandIters', scalar number : is the number X of times based on which
%   you repeat the 'Shuffle' operaton, or the number of intervals to use
%   for the 'AllRange' operation. If no value is set, then 5 will be take
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

%% Arguments
arguments
    model2Use (1,1)
    dataset2Use (:,:)
    expOuts2Use (:,1) double
    Options.PermType (1,:) char = 'allrange'
    Options.RandIters (1,1) double = 5
    Options.RangeVals (1,2) double = [0, 1]
    Options.RandSeed (1,1) double = 17;
end

permType  = lower(Options.PermType);
randIters = Options.RandIters;
rangeVals = Options.RangeVals;
randSeed  = Options.RandSeed;

%% Input Check
if not(isnumeric(dataset2Use) || istable(dataset2Use))
    error('DatasetToUse (2nd input) must be numeric matrix or table!')
end

if isnumeric(dataset2Use)
    warning(['DatasetToUse (2nd input) is numeric. Please keep attention ', ...
             'to the order of the columns, because they must be in the same', ...
             'order used while the model was training!'])
end

if numel(unique(expOuts2Use))-1 ~= max(expOuts2Use) % If there is a void in classes it will not work!
    error(['Expected outputs must be an array containing ', ...
           'classes, not a regression! Please contact the support.'])
end

if not(strcmp(permType, 'shuffle') || strcmp(permType, 'allrange'))
    error('PermType not recognized! It must be "Shuffle" or "AllRange"!')
end

if any(rangeVals > 1) || any(rangeVals < 0) || (rangeVals(2) < rangeVals(1))
    error(['RangeVals must be in the range [0, 1] and the ', ...
           'second element must be greater than the first!'])
end

%% Core
expOutsSg = double(expOuts2Use >= 1); % It is to have a single column also in case of multi output!
rngOfVals = linspace(rangeVals(1), rangeVals(2), randIters);
currFeats = dataset2Use.Properties.VariableNames;
currPreds = mdlpredict(model2Use, dataset2Use, 'SingleCol',true);
currLoss  = crossentropy2(currPreds, expOutsSg); % 'crossentropy' is appropriate only for neural network models.
currMSE   = mse(expOutsSg, currPreds);
currRMSE  = rmse(currPreds, expOutsSg);

rng(randSeed) % To control the randomization process
[indRand,  rngVals] = deal(zeros(size(dataset2Use, 1), randIters));
[permLoss, permMSE, permRMSE] = deal(zeros(randIters, length(currFeats)));
for i1 = 1:randIters
    switch permType
        case 'shuffle'
            indRand(:,i1) = randperm(size(dataset2Use, 1));

        case 'allrange'
            rngVals(:,i1) = repmat(rngOfVals(i1), size(dataset2Use, 1), 1);
    end
    
    for i2 = 1:length(currFeats)
        datasetPerm = dataset2Use;
        switch permType
            case 'shuffle'
                datasetPerm{:,currFeats{i2}} = datasetPerm{indRand(:,i1),currFeats{i2}};

            case 'allrange'
                minValFtTmp = min(dataset2Use{:, currFeats{i2}});
                maxValFtTmp = max(dataset2Use{:, currFeats{i2}});
                datasetPerm{:,currFeats{i2}} = rngVals(:,i1) .* (maxValFtTmp - minValFtTmp) + minValFtTmp;
        end

        permPreds = mdlpredict(model2Use, datasetPerm, 'SingleCol',true);

        permLoss(i1,i2) = crossentropy2(permPreds, expOutsSg); % 'crossentropy' is appropriate only for neural network models.
        permMSE(i1,i2)  = mse(expOutsSg, permPreds);
        permRMSE(i1,i2) = rmse(permPreds, expOutsSg);
    end
end

meanPermLoss = max(permLoss, [], 1); % You can also average values: mean(PermLoss,1);
meanPermMSE  = max(permMSE,  [], 1); % You can also average values: mean(PermMSE,1);
meanPermRMSE = max(permRMSE, [], 1); % You can also average values: mean(PermRMSE,1);

featImpDiffLoss = meanPermLoss-currLoss;
featImpDiffMSE  = meanPermMSE-currMSE;
featImpDiffRMSE = meanPermRMSE-currRMSE;

featImpPercLoss = max(featImpDiffLoss,0)/sum(max(featImpDiffLoss,0)); % The importance can not be negative, thus if a value is negative (better when random) it will be capped to 0 with max(value,0)
featImpPercMSE  = max(featImpDiffMSE,0)/sum(max(featImpDiffMSE,0));   % The importance can not be negative, thus if a value is negative (better when random) it will be capped to 0 with max(value,0)
featImpPercRMSE = max(featImpDiffRMSE,0)/sum(max(featImpDiffRMSE,0));   % The importance can not be negative, thus if a value is negative (better when random) it will be capped to 0 with max(value,0)

featImportance = array2table([featImpDiffLoss; featImpDiffMSE; featImpDiffRMSE; ...
                              featImpPercLoss; featImpPercMSE; featImpPercRMSE], ...
                                                'RowNames',{'LossDifferences', 'MSEDifferences', 'RMSEDifferences', ...
                                                            'PercentagesLoss', 'PercentagesMSE', 'PercentagesRMSE'}, 'VariableNames',currFeats);

end