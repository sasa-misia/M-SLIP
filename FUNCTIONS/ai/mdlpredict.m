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
%   
%   - 'CutValues', logical : is to specify if you want to cut values out of 
%   the range [0, 1], in case of probabilities on a classification model. 
%   If no value is specified, then 'false' will be take as default for 
%   regression and true for classification.

%% Settings initialization
MdlClss = strsplit(class(Model), '.'); MdlClss = MdlClss{end};
ScndOut = contains(MdlClss, 'class', 'IgnoreCase',true); % Default
if not(ScndOut) && any(strcmpi(fieldnames(Model), 'modelparameters'))
    ScndOut = strcmpi(Model.ModelParameters.Type, {'classification'});
end
if not(ScndOut) && any(strcmpi(fieldnames(Model), 'method'))
    ScndOut = any(strcmpi(Model.Method, {'classification'}));
end
SnglCol = false; % Default
CutVals = ScndOut;

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(StringPart) = varargin(StringPart);

    InputSecondOut = find(cellfun(@(x) strcmpi(x, "secondout"), vararginCopy));
    InputSingleCol = find(cellfun(@(x) strcmpi(x, "singlecol"), vararginCopy));
    InputCutValues = find(cellfun(@(x) strcmpi(x, "cutvalues"), vararginCopy));

    if InputSecondOut; ScndOut = varargin{InputSecondOut+1}; end
    if InputSingleCol; SnglCol = varargin{InputSingleCol+1}; end
    if InputCutValues; CutVals = varargin{InputCutValues+1}; end
end

%% Core
if isa(Model, 'dlnetwork') && isa(Dataset, 'table')
    warning(['mdlpredict| Dataset to predict is a table but you have ', ...
             'a dlnetwork model -> input dataset will be converted in ', ...
             'array, check order of input dataset features!'])
    Dataset = table2array(Dataset);
end

if ScndOut
    [~, CurrPreds] = predict(Model, Dataset);
else
    CurrPreds = predict(Model, Dataset);
end

if ScndOut && any(CurrPreds < 0, 'all') % If there is ScndOut it means that it is a classificator!
    CurrPreds = exp(CurrPreds)./(exp(CurrPreds)+1);
    warning('Scores were supposed to be odds, thus converted into probabilities!')
end

OutOfRng = any(CurrPreds < 0, 'all') | any(CurrPreds > 1, 'all');
if OutOfRng && CutVals
    CurrPreds = min(max(CurrPreds, 0), 1);
    warning(['mdlpredict| Some values of the prediction ', ...
             'were cutted out because out of range 0-1'])
end

FrstPreds = CurrPreds(:,1);
if size(CurrPreds, 2) > 1 % In case of multiple columns it should be a classification!
    CurrPreds = CurrPreds(:,2:end);

    if not(all(single(round(FrstPreds, 2)) + single(round(sum(CurrPreds, 2), 2)) == 1)) % sum(CurrPreds, 2) is the remaining part, which summed must return 1-FrstPreds
        warning(['mdlpredict| Summed probabilities after 2nd column are not ' ...
                 'equal to the first one! Please check with "predict" function!'])
    end
end

if SnglCol
    CurrPreds = sum(CurrPreds, 2); % Correct only in case of softmax as last layer!
end

PredictionProbabilities = CurrPreds;

end