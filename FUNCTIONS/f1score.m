function [FScore, Prec, Recl] = f1score(ExpectedOutputs, Predictions, varargin)

% Function to evaluate F1 Score based on predictions, useful in M-SLIP
%   
%   [FScore, Prec, Recl] = f1score(ExpectedOutputs, Predictions, varargin)
%   
% Outputs:
%   FScore : a double scalar containing the F1 Score value
%   
%   Prec : a double scalar containing the Precision value, used for FScore
%   
%   Recl : a double scalar containing the Recall value, used for FScore
%   
% Required arguments:
%   - ExpectedOutputs : expected outputs array.
%   
%   - Predictions : prediction array (equal size of ExpectedOutputs).
%   
% Optional arguments:
%   - 'Threshold', numeric scalar : is the value that separates classes 
%   based on Predictions array. if Predictions > Threshold then is class 1,
%   otherwise 0! If no value is specified, then 0.5 will be take as default.

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

%% Settings
Threshold = .5; % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputThreshold = find(cellfun(@(x) all(strcmpi(x, "threshold")), vararginCp));

    if InputThreshold; Threshold = varargin{InputThreshold+1}; end

    varargin([InputThreshold, InputThreshold+1]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(isscalar(Threshold))
    error('Threshold must be a scalar value!')
end

%% Core
Classes = double(Predictions >= Threshold); % Actually, you should use the best threshold according to PR Curve!

TruePos = sum(all([Classes==1, ExpectedOutputs>=1], 2));
% TrueNeg = sum(all([Classes==0, ExpectedOutputs==0], 2)); % Not useful!
FlsePos = sum(all([Classes==1, ExpectedOutputs==0], 2));
FlseNeg = sum(all([Classes==0, ExpectedOutputs>=1], 2));

Prec = TruePos / (TruePos + FlsePos);
Recl = TruePos / (TruePos + FlseNeg);

FScore = 2*Prec*Recl / (Prec + Recl);

end