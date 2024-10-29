function CrssEntr = crossentropy2(Predictions, Targets)

% This is a simple function to evaluate crossentropy because the original
% one has a conflict (same function name in 2 different toolbox)
%
% Syntax
%
%     CrssEntr = crossentropy2(Predictions, Targets)
%     
% - Predictions: is a nxm matrix containing prediction probabilities, where 
%   m is the number of classes and n is the number of observations
%  
% - Targets: is a nxm matrix containing real target outputs to predict, where 
%   m is the number of classes and n is the number of observations

% REMEMBER TO CHECK IT WITH MULTICLASS (MULTIOUTPUT AND PREDICTIONS)
ClssUnq  = unique(Targets);
ExpTrue  = arrayfun(@(x) double(Targets==x), ClssUnq, 'UniformOutput',false);

RelPred  = cell(size(ExpTrue));
for i1 = 1:length(RelPred)
    if i1 == 1
        RelPred{i1} = 1-sum(Predictions,2);
    else
        RelPred{i1} = Predictions(:,i1-1);
    end
end

% In this section you search for values too small that will give nan with
% the log. You just set a number small but not too.
MinVal = 1e-15;
IndToChng = cellfun(@(x) x<MinVal, RelPred, 'UniformOutput',false);
for i1 = 1:numel(IndToChng)
    RelPred{i1}(IndToChng{i1}) = MinVal;
end

CrssEntr = -sum(cellfun(@(x,y) sum(x.*log10(y)), ExpTrue, RelPred)) / numel(Targets);

end