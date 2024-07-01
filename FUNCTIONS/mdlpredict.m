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
% Optional arguments:
%   - 'SecondOut', logical : is to specify if your model give as a second
%   output the probabilities (when you apply stock predict). If no value is 
%   specified, then is set by default to 'true' if the class of the Model 
%   contains the string 'class', otherwise is set to 'false'.
%   
%   - 'SingleCol', logical : is to specify if you want just one single
%   column with probabilities summed (one vs all remaining classes) or if
%   you want to mantain separate columns for each class (except for the
%   first one that is always delted, since it is complementary). If no value
%   is specified, then 'false' will be take as default.

%% Settings initialization
ScndOut = contains(class(Model), 'class', 'IgnoreCase',true); % Default
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
if isa(Model, 'dlnetwork')
    if isa(Dataset, 'table')
        warning(['mdlpredict| Dataset to predict is a table but you have ', ...
                 'a dlnetwork model -> input dataset will be converted in ', ...
                 'array, check order of input dataset features!'])
        DatasetArr = table2array(Dataset);
    end

    CurrPreds = predict(Model, DatasetArr);

else
    if ScndOut
        [~, CurrPreds] = predict(Model, Dataset);

    else
        CurrPreds = predict(Model, Dataset);
    end
end

OutOfRng = any(CurrPreds < 0) | any(CurrPreds > 1);
if OutOfRng
    CurrPreds = min(max(CurrPreds, 0), 1);
    warning(['mdlpredict| Some values of the prediction ', ...
             'were cutted out because out of range 0-1'])
end

FrstPreds = CurrPreds(:,1);
OrigSize  = 1;
if size(CurrPreds, 2) > 1
    OrigSize  = size(CurrPreds, 2);
    CurrPreds = CurrPreds(:,2:end);
end

if SnglCol
    CurrPreds = sum(CurrPreds, 2); % Correct only in case of softmax as last layer!
    if OrigSize > 1 && not(all(single(round(FrstPreds, 2)) + single(round(CurrPreds, 2)) == 1))
        warning(['mdlpredict| Summed probabilities are not equal to ' ...
                 'the first class! Please check with predict function!'])
    end
end

PredictionProbabilities = CurrPreds;

end