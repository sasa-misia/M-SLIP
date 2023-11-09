function PredictionProbabilities = mdlpredict(Model, Dataset, varargin)

% Modded version of "predict" MATLAB function, useful in M-SLIP
%   
% Outputs:
%   PredictionProbabilities : column(s) of predicted probabilities per each
%   class
%   
% Required arguments:
%   - Model : whatever model object you have
%   
%   - Dataset : dataset to predict
%   
%   - ExpctdOutsToUse : is/are the array/s with the expected output classes
%   
%   - RatioToUse : is the ratio to impose between stable class and all the
%   others
%   
%   - Technique : is the technique you want to use. You can choose between
%   'Undersampling', 'Oversampling', and 'SMOTE'
%   
% Optional arguments:
%   - 'SecondOut', logical : is to specify if your model give as a second
%   output the probabilities (when you apply stock predict). If no value is 
%   specified, then 'false' will be take as default.
%   
%   - 'SingleCol', logical : is to specify if you want just one single
%   column with probabilities summed (one vs all remaining classes) or if
%   you want to mantain separate columns for each class (except for the
%   first one that is always delted, since it is complementary). If no value
%   is specified, then 'false' will be take as default.

%% Settings initialization
ScndOut = false; % Default
SnglCol = false; % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(StringPart) = varargin(StringPart);

    InputSecondOut = find(cellfun(@(x) strcmpi(x, "secondout"), vararginCopy));
    InputSingleCol = find(cellfun(@(x) strcmpi(x, "singlecol"), vararginCopy));

    if InputSecondOut; ScndOut = varargin{InputSecondOut+1}; end
    if InputSingleCol; SnglCol = varargin{InputSingleCol+1}; end
end

%% Core
if ScndOut
    [~, CurrPreds] = predict(Model, Dataset);
else
    CurrPreds = predict(Model, Dataset);
end

OutOfRng = any(CurrPreds < 0) | any(CurrPreds > 1);
if OutOfRng
    CurrPreds = min(max(CurrPreds, 0), 1);
    warning('Some values of the prediction were cutted out because out of range 0-1')
end

FrstPreds = CurrPreds(:,1);
OrigSize  = 1;
if size(CurrPreds, 2) > 1
    OrigSize  = size(CurrPreds, 2);
    CurrPreds = CurrPreds(:,2:end);
end

if SnglCol
    CurrPreds = sum(CurrPreds, 2); % Correct only in case of softmax as last layer!
    if OrigSize > 1 && not(isequal(single(1-round(FrstPreds, 2)), single(round(CurrPreds, 2))))
        warning(['Summed probabilities are not equal to the first class! ' ...
                 'Please check with predict function!'])
    end
end

PredictionProbabilities = CurrPreds;

end