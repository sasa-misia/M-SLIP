function [PosMSE, NegMSE] = mse_sep(ExpectedOutputs, Predictions)

% Function to evaluate F1 Score based on predictions, useful in M-SLIP
%   
% Outputs:
%   PosMSE : a double scalar containing the mse for the positive class part
%   
%   NegMSE : a double scalar containing the mse for the negative class part
%   
% Required arguments:
%   - ExpectedOutputs : expected outputs array.
%   
%   - Predictions : prediction array (equal size of ExpectedOutputs).

%% Input Check
if not(isnumeric(ExpectedOutputs) || isnumeric(Predictions))
    error('ExpectedOutputs and Predictions (1st and 2nd input) must be numeric array!')
end

if not(isequal(size(ExpectedOutputs), size(Predictions)))
    error('1st and 2nd inputs must have same sizes!')
end

if all(size(ExpectedOutputs) > 1)
    error('1st and 2nd inputs must be 1d arrays!')
end

%% Core
IndRlTr = ExpectedOutputs >= 1;
IndRlFl = ExpectedOutputs == 0;

PosMSE = mse(Predictions(IndRlTr), ExpectedOutputs(IndRlTr));
NegMSE = mse(Predictions(IndRlFl), ExpectedOutputs(IndRlFl));

end