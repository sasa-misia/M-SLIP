function [TrainedModel, MdlInfo] = trainann2(DatasetTrain, ExpectedOutTrain, varargin)

% Function to create events starting from daily recordings!
%   
%   [TrainedModel, MdlInfo, TrainOpts] = trainann2(DatasetTrain, ExpectedOutTrain, varargin)
%   
%   Dependencies: -
%   
% Outputs:
%   TrainedModel : is the neural network object trained, 'dlnetwork' type.
%   
%   MdlInfo : structure containing info about model, dataset and metrics.
%   It is a TrainingInfo object.
%   
%   TrainOpts : an object containing the training options used for train
%   the net.
%   
% Required arguments:
%   DatasetTrain : is the table or numeric matrix containing input features
%   to predict with the network.
%   
%   ExpectedOutTrain : is the numeric or categorical array containing the
%   expected output of the network to train.
%   
% Optional arguments:
%   - 'ClassifNet', logical : is to declare if the network must classify the 
%   outputs (classification task) or it is a regression. If no value is 
%   specified, then true it will be take as default, if the number of unique 
%   outputs in ExpectedOutTrain is smaller than 100.
%  
%   - 'ShowVerbose', logical : is to specify if you want to prompt progress
%   in command window. If no value is specified, then false will be assumed
%   as default.
%  
%   - 'VerboseFrequency', numeric : is to specify the prompt frequency. If 
%   no value is specified, then 50 iterations will be assumed as default.
%   No effect if ShowVerbose is set to false.
%  
%   - 'ShowTrainPlot', logical : is to specify if you want a real time plot 
%   with the training progress. If no value is specified, then false will 
%   be assumed as default.
%  
%   - 'MetricsToUse', cellstr/function/deep.DifferentiableFunction : is to 
%   specify the metrics to use during training. According to these metrics, 
%   you will see all of them on the real time plot. It could be one of the 
%   built-in metrics, i.e. 'accuracy', 'auc', 'fscore', 'precision', 'recall', 
%   or 'rmse'. Alternatively you can specify a function handle (@funName), a 
%   deep.DifferentiableFunction obj, or a metric object (see MATLAB documentation
%   for trainingOptions). An example is {'accuracy', @myFunction, precisionObj}. 
%   If no value is specified, then {'accuracy'} will be assumed as default.
%  
%   - 'Solver', char/string/cellstr : is to specify the type of solver to 
%   use. It can be one between 'sgdm', 'rmsprop', 'adam', or 'lbfgs'. If no 
%   value is specified, then 'sgdm' will be assumed as default.
%   
%   - 'LayerSizes', numeric : is to specify the number of neurons per layer.
%   If no value is specified, then [20, 10] will be assumed as default,
%   which means having 2 hidden layers with respectively 20 and 10 neurons.
%  
%   - 'LayerActivations', char/string/cellstr : is to specify the activation
%   function to use per each layer. In case it is a scalar value, then the
%   network will have the same function over each layer, otherwise you should 
%   specify a value for each layer. The arguments could be 'relu', 'sigmoid', 
%   'tanh', 'elu', 'gelu', 'softplus', or 'none'. If no value is specified,  
%   then {'relu'} will be assumed as default.
%  
%   - 'IterationLimit', numeric : is to specify the number of max iterations.
%   If no value is specified, then 1000 will be assumed as default.
%  
%   - 'L2Regularization', numeric : is to specify the value of lambda in L2 
%   regularization. If no value is specified, then 0 will be assumed as 
%   default, i.e., no L2 regularization effects.
%   
%   - 'Dropout', logical : is to specify if you want the dropout during the
%   training of the netwrok. By default is set to false.
%   
%   - 'StandardizeInput', logical : is to specify if you want to standardize
%   the input layer with the zscore technique. By default is set to false.
%   
%   - 'WeightsInit', char/string/cellstr : is to specify what type of weight 
%   initializer you want to use. It must be a single value and can be one 
%   between 'glorot', 'he', 'orthogonal', 'narrow-normal', 'zeros', 'ones'. 
%   By default is set to 'glorot'.
%   
%   - 'FinalNetwork', char/string/cellstr : is to specify the final returned
%   network. It must be one of 'auto', 'last-iteration', or 'best-validation'.
%   By default is set to 'last-iteration'.
%   
%   - 'ObjectiveMetric', char/string/cellstr : is to specify the metrics to
%   use in order to evaluiate the goodness of the model. It can be 'loss'
%   or one of the metric used in MetricsToUse. By default is set to 'loss'.
%   
%   - 'ObjTolerance', numeric : is to specify the tolerance of the metric to 
%   use for the early stoppinbg of the model. if the metric is 'loss' then
%   it is the value of the loss below which you stop the train. By default
%   is set to 1e-5 and is referred to 'loss'.
%   
%   - 'ValidationData', cell : is to specify the data to use for validation
%   check and early stopping. It must be a 1x2 or 2x1 cell containing
%   numeric matrices or tables. By default is a 1x2 empty cell.
%   
%   - 'ValidFrequency', numeric : is to specify the frequency based on which
%   the Validation loss (or other metrics specified in ObjectiveMetric)
%   will be evaluated. By default is set to 1. Remember that it has no
%   effect if ValidationData is empty.
%   
%   - 'ValidPatience', numeric : is to specify the number of times to wait
%   before stopping the training. If ValidFrequency is 5 and ValidPatience
%   is 3, this means that after 3 evaluations where the ObjectiveMetric
%   increases (i.e., 15 iterations), the training will be stopped. By
%   default is set to 10.
%   
%   - 'InitialLearnRate', numeric : is to specify the initial learning rate
%   to use for 'sgdm', 'rmsprop', and 'adam' solvers. No effect in case of 
%   'lbfgs'. By default is set to .015. Effective only for 'sgdm', 'rmsprop', 
%   and 'adam' solvers.
%   
%   - 'LRDropSchedule', logical : is to specify if you want to drop the
%   learning rate after a certain number of iterations. By default is set
%   to false. Effective only for 'sgdm', 'rmsprop', and 'adam' solvers.
%   
%   - 'LRDropPeriod', numeric : is to specify the number of iterations to wait 
%   in order to drop the learning rate. It has no effect if LRDropSchedule
%   is set to false. By default is set to 40. Effective only for 'sgdm', 
%   'rmsprop', and 'adam' solvers.
%   
%   - 'LRDropFactor', numeric : is to specify the drop factor to use when
%   the learning rate drops. It is the multiplier, this means that if it is
%   set to 1, it will not drop, if it is set to 0.8, it means that the new
%   learning rate it will be 80% of the previous. By default is set to 0.7.
%   Effective only for 'sgdm', 'rmsprop', and 'adam' solvers.
%   
%   - 'ShuffleType', char/string/cellstr : is to specify if you want to
%   shuffle the train dataset (randomize order of observations). It can be 
%   'once', 'never', or 'every-epoch'. By default is set to 'every-epoch'. 
%   Effective only for 'sgdm', 'rmsprop', and 'adam' solvers.
%   
%   - 'MiniBatchSize', numeric : is to specify the mini dataset to use for
%   training at each iteration. It means that every iteration will contain
%   a sub dataset from the original one, made of X observations, equal to
%   the number specified. By default is set to 128. Effective only for 'sgdm', 
%   'rmsprop', and 'adam' solvers.
%   
%   - 'LineSearchMethod', char/string/cellstr : is to specify the line
%   search metod for 'lbfgs'. It can be 'weak-wolfe', 'strong-wolfe', or
%   'backtracking'. By default is set to 'weak-wolfe'. Effective only for 
%   'lbfgs' solver.
%   
%   - 'MaxLineSrchIter', numeric : is to specify the maximum number of line
%   to search. By default is set to 20. Effective only for 'lbfgs' solver.
%   
%   - 'HistSizeLBFGS', numeric : is to specify the history size of gradient 
%   calculation for 'lbfgs'. By default is set to 10. Effective only for 
%   'lbfgs' solver.
%   
%   - 'GradTolerance', numeric : is to specify the gradient tolerance for 
%   'lbfgs' solver. By default is set to 1e-5. Effective only for 'lbfgs' 
%   solver.
%   
%   - 'StepTolerance', numeric : is to specify the step tolerance for 'lbfgs'
%   solver. By default is set to 1e-5. Effective only for 'lbfgs' solver.
%   
%   - 'CheckpointPath', char/string/cellstr : is to specify if you want to
%   save the history of the models. It must be the path where you want to
%   save the files of the models. By default is set to '' and this means
%   that the files will not be saved.
%   
%   - 'CheckpointFreq', integer : is to specify the frequency of iterations 
%   (or epochs) based on which save the various models. By default is set to 
%   1, and this means that if 300 iterations are necessary to stop the train, 
%   you will have 300 files.
%   
%   - 'CheckpointUnit', char/string/cellstr : is to specify the units based
%   on which save the history of the models. It can be 'epoch' or 'iteration'.
%   By default is set to 'iteration'.

%% Input check
if not(isnumeric(DatasetTrain) || istable(DatasetTrain))
    error('DatasetTrain (1st input) must be a numeric array or a table!')
end

if not(isvector(ExpectedOutTrain) && (isnumeric(ExpectedOutTrain) || iscategorical(ExpectedOutTrain)))
    error('ExpectedOutTrain (2nd input) must be a numeric or categorical array!')
end

if size(DatasetTrain, 1) ~= numel(ExpectedOutTrain)
    error('1st input must have the number of rows equal to the 2nd input!')
end

if istable(DatasetTrain)
    warning(['Attention: the given dataset (1st input) is a ', ...
             'table, it will be converted to a numeric array!'])
    DatasetTrain = table2array(DatasetTrain);
end

ExpectedOutTrain = reshape(ExpectedOutTrain, [numel(ExpectedOutTrain), 1]);

OutNeurN = numel(unique(ExpectedOutTrain));

%% Settings
ClassNet = OutNeurN <= 100;  % Default: if there are less than 100 unique out values, it is probably a classification task and not regression!
ShowVerb = false;            % Default
VerbFreq = 50;               % Default
ShwTrPlt = false;            % Default
Mets2Use = {'accuracy'};     % Default % {'auc', 'fscore', 'precision', 'recall'};
DeepSlvr = 'sgdm';           % Default
LaySizes = [20, 10];         % Default
LyrsActv = {'relu'};         % Default
IterLimt = 1000;             % Default
RegStrgt = 0;                % Default
DrpOutOn = false;            % Default
StndDeep = false;            % Default
WghtInit = 'glorot';         % Default
FinalNet = 'last-iteration'; % Default
ObjcMetr = 'loss';           % Default % It could be also custom or one of the Met2Plot!
ObjToler = 1e-5;             % Default (referred to ObjcMetr, i.e. loss by default)
VldtData = cell(1, 2);       % Default
VldtFreq = 1;                % Default
VldtPatc = 10;               % Default
InitLrRt = .015;             % Default
DropSchd = false;            % Default
DropPrdI = 40;               % Default
DropLrRt = .7;               % Default
SfflType = 'every-epoch';    % Default
MiniBtch = 128;              % Default
LnSrchMt = 'weak-wolfe';     % Default
MxLnSrch = 20;               % Default
HistSize = 10;               % Default
GrdToler = 1e-5;             % Default
StpToler = 1e-5;             % Default
Path4Hst = "";               % Default
HistFreq = 1;                % Default
HistFrUn = 'iteration';      % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InpClassNet = find(cellfun(@(x) all(strcmpi(x, 'ClassifNet'      )), vararginCp));
    InpShowVerb = find(cellfun(@(x) all(strcmpi(x, 'ShowVerbose'     )), vararginCp));
    InpVerbFreq = find(cellfun(@(x) all(strcmpi(x, 'VerboseFrequency')), vararginCp));
    InpPlt2Show = find(cellfun(@(x) all(strcmpi(x, 'ShowTrainPlot'   )), vararginCp));
    InpMets2Use = find(cellfun(@(x) all(strcmpi(x, 'MetricsToUse'    )), vararginCp));
    InpDeepSlvr = find(cellfun(@(x) all(strcmpi(x, 'Solver'          )), vararginCp));
    InpLaySizes = find(cellfun(@(x) all(strcmpi(x, 'LayerSizes'      )), vararginCp));
    InpLyrsActv = find(cellfun(@(x) all(strcmpi(x, 'LayerActivations')), vararginCp));
    InpIterLimt = find(cellfun(@(x) all(strcmpi(x, 'IterationLimit'  )), vararginCp));
    InpRegStrgt = find(cellfun(@(x) all(strcmpi(x, 'L2Regularization')), vararginCp));
    InpDrpOutOn = find(cellfun(@(x) all(strcmpi(x, 'Dropout'         )), vararginCp));
    InpStndDeep = find(cellfun(@(x) all(strcmpi(x, 'StandardizeInput')), vararginCp));
    InpWghtInit = find(cellfun(@(x) all(strcmpi(x, 'WeightsInit'     )), vararginCp));
    InpFinalNet = find(cellfun(@(x) all(strcmpi(x, 'FinalNetwork'    )), vararginCp));
    InpObjcMetr = find(cellfun(@(x) all(strcmpi(x, 'ObjectiveMetric' )), vararginCp));
    InpObjToler = find(cellfun(@(x) all(strcmpi(x, 'ObjTolerance'    )), vararginCp));
    InpVldtData = find(cellfun(@(x) all(strcmpi(x, 'ValidationData'  )), vararginCp));
    InpVldtFreq = find(cellfun(@(x) all(strcmpi(x, 'ValidFrequency'  )), vararginCp));
    InpVldtPatc = find(cellfun(@(x) all(strcmpi(x, 'ValidPatience'   )), vararginCp));
    InpInitLrRt = find(cellfun(@(x) all(strcmpi(x, 'InitialLearnRate')), vararginCp));
    InpDropSchd = find(cellfun(@(x) all(strcmpi(x, 'LRDropSchedule'  )), vararginCp));
    InpDropPrdI = find(cellfun(@(x) all(strcmpi(x, 'LRDropPeriod'    )), vararginCp));
    InpDropLrRt = find(cellfun(@(x) all(strcmpi(x, 'LRDropFactor'    )), vararginCp));
    InpSfflType = find(cellfun(@(x) all(strcmpi(x, 'ShuffleType'     )), vararginCp));
    InpMiniBtch = find(cellfun(@(x) all(strcmpi(x, 'MiniBatchSize'   )), vararginCp));
    InpLnSrchMt = find(cellfun(@(x) all(strcmpi(x, 'LineSearchMethod')), vararginCp));
    InpMxLnSrch = find(cellfun(@(x) all(strcmpi(x, 'MaxLineSrchIter' )), vararginCp));
    InpHistSize = find(cellfun(@(x) all(strcmpi(x, 'HistSizeLBFGS'   )), vararginCp));
    InpGrdToler = find(cellfun(@(x) all(strcmpi(x, 'GradTolerance'   )), vararginCp));
    InpStpToler = find(cellfun(@(x) all(strcmpi(x, 'StepTolerance'   )), vararginCp));
    InpPath4Hst = find(cellfun(@(x) all(strcmpi(x, 'CheckpointPath'  )), vararginCp));
    InpHistFreq = find(cellfun(@(x) all(strcmpi(x, 'CheckpointFreq'  )), vararginCp));
    InpHistFrUn = find(cellfun(@(x) all(strcmpi(x, 'CheckpointUnit'  )), vararginCp));

    if InpClassNet; ClassNet = varargin{InpClassNet+1}; end
    if InpShowVerb; ShowVerb = varargin{InpShowVerb+1}; end
    if InpVerbFreq; VerbFreq = varargin{InpVerbFreq+1}; end
    if InpPlt2Show; ShwTrPlt = varargin{InpPlt2Show+1}; end
    if InpMets2Use; Mets2Use = varargin{InpMets2Use+1}; end
    if InpDeepSlvr; DeepSlvr = varargin{InpDeepSlvr+1}; end
    if InpLaySizes; LaySizes = varargin{InpLaySizes+1}; end
    if InpLyrsActv; LyrsActv = varargin{InpLyrsActv+1}; end
    if InpIterLimt; IterLimt = varargin{InpIterLimt+1}; end
    if InpRegStrgt; RegStrgt = varargin{InpRegStrgt+1}; end
    if InpDrpOutOn; DrpOutOn = varargin{InpDrpOutOn+1}; end
    if InpStndDeep; StndDeep = varargin{InpStndDeep+1}; end
    if InpWghtInit; WghtInit = varargin{InpWghtInit+1}; end
    if InpFinalNet; FinalNet = varargin{InpFinalNet+1}; end
    if InpObjcMetr; ObjcMetr = varargin{InpObjcMetr+1}; end
    if InpObjToler; ObjToler = varargin{InpObjToler+1}; end
    if InpVldtData; VldtData = varargin{InpVldtData+1}; end
    if InpVldtFreq; VldtFreq = varargin{InpVldtFreq+1}; end
    if InpVldtPatc; VldtPatc = varargin{InpVldtPatc+1}; end
    if InpInitLrRt; InitLrRt = varargin{InpInitLrRt+1}; end
    if InpDropSchd; DropSchd = varargin{InpDropSchd+1}; end
    if InpDropPrdI; DropPrdI = varargin{InpDropPrdI+1}; end
    if InpDropLrRt; DropLrRt = varargin{InpDropLrRt+1}; end
    if InpSfflType; SfflType = varargin{InpSfflType+1}; end
    if InpMiniBtch; MiniBtch = varargin{InpMiniBtch+1}; end
    if InpLnSrchMt; LnSrchMt = varargin{InpLnSrchMt+1}; end
    if InpMxLnSrch; MxLnSrch = varargin{InpMxLnSrch+1}; end
    if InpHistSize; HistSize = varargin{InpHistSize+1}; end
    if InpGrdToler; GrdToler = varargin{InpGrdToler+1}; end
    if InpStpToler; StpToler = varargin{InpStpToler+1}; end
    if InpPath4Hst; Path4Hst = varargin{InpPath4Hst+1}; end
    if InpHistFreq; HistFreq = varargin{InpHistFreq+1}; end
    if InpHistFrUn; HistFrUn = varargin{InpHistFrUn+1}; end

    varargin([ InpClassNet, InpClassNet+1, ...
               InpShowVerb, InpShowVerb+1, ...
               InpVerbFreq, InpVerbFreq+1, ...
               InpPlt2Show, InpPlt2Show+1, ...
               InpMets2Use, InpMets2Use+1, ...
               InpDeepSlvr, InpDeepSlvr+1 ...
               InpLaySizes, InpLaySizes+1, ...
               InpLyrsActv, InpLyrsActv+1, ...
               InpIterLimt, InpIterLimt+1, ...
               InpRegStrgt, InpRegStrgt+1, ...
               InpDrpOutOn, InpDrpOutOn+1, ...
               InpStndDeep, InpStndDeep+1, ...
               InpWghtInit, InpWghtInit+1, ...
               InpFinalNet, InpFinalNet+1, ...
               InpObjcMetr, InpObjcMetr+1, ...
               InpObjToler, InpObjToler+1, ...
               InpVldtData, InpVldtData+1, ...
               InpVldtFreq, InpVldtFreq+1 ...
               InpVldtPatc, InpVldtPatc+1, ...
               InpInitLrRt, InpInitLrRt+1, ...
               InpDropSchd, InpDropSchd+1, ...
               InpDropPrdI, InpDropPrdI+1, ...
               InpDropLrRt, InpDropLrRt+1, ...
               InpSfflType, InpSfflType+1, ...
               InpMiniBtch, InpMiniBtch+1, ...
               InpLnSrchMt, InpLnSrchMt+1, ...
               InpMxLnSrch, InpMxLnSrch+1 ...
               InpHistSize, InpHistSize+1, ...
               InpGrdToler, InpGrdToler+1, ...
               InpStpToler, InpStpToler+1, ...
               InpPath4Hst, InpPath4Hst+1, ...
               InpHistFreq, InpHistFreq+1, ...
               InpHistFrUn, InpHistFrUn+1 ]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

% ClassifNet
if not(islogical(ClassNet)); error('ClassifNet must be logical!'); end

% ShowVerbose
if not(islogical(ShowVerb)); error('ShowVerbose must be logical!'); end

% VerboseFrequency
if not(isnumeric(VerbFreq) && isscalar(VerbFreq) && ((VerbFreq - floor(VerbFreq)) == 0))
    error('VerboseFrequency must be a single integer number!')
end
VerbFreq = int64(VerbFreq);

% ShowTrainPlot
if not(islogical(ShwTrPlt)); error('ShowTrainPlot must be logical!'); end
if ShwTrPlt; Plt2Show = 'training-progress'; else; Plt2Show = 'none'; end

% MetricsToUse
if not(iscellstr(Mets2Use))
    error(['MetricsToUse must be just a cellstr, functions and ', ...
           'objects not yet supported. Please contact the support!'])
end

% Solver
if not(isstring(DeepSlvr) || ischar(DeepSlvr) || iscellstr(DeepSlvr))
    error('Solver must be char, string, or cellstr!')
end
DeepSlvr = string(DeepSlvr);
if not(isscalar(DeepSlvr))
    error('Solver must be a single value!')
end

% LayerSizes
if not(isnumeric(LaySizes) && isvector(LaySizes))
    error('LayerSizes must be a numeric scalar or array!')
end

% LayerActivations
if not(isstring(LyrsActv) || ischar(LyrsActv) || iscellstr(LyrsActv))
    error('LayerActivations must be char, string, or cellstr!')
end
LyrsActv = cellstr(LyrsActv);
if isscalar(LyrsActv)
    LyrsActv = repmat(LyrsActv, 1, numel(LaySizes));
end
if numel(LyrsActv) ~= numel(LaySizes)
    error(['Activation fubnction of the layers must be a single ', ...
           'scalar or a cell string with one value per layer!'])
end
for i1 = 1:numel(LyrsActv)
    if not(any(strcmpi(LyrsActv{i1}, {'relu', 'sigmoid', 'tanh', 'elu', 'gelu', 'softplus', 'none'})))
        error(['Element n. ',num2str(i1),' of LayerActivations must ', ...
               'be one between relu, sigmoid, tanh, elu, gelu, softplus, or none!'])
    end
end

% IterationLimit
if not(isnumeric(IterLimt) && isscalar(IterLimt))
    error('IterationLimit must be a single integer number!')
end
IterLimt = int64(IterLimt);

% L2Regularization
if not(isnumeric(RegStrgt) && isscalar(RegStrgt))
    error('L2Regularization must be a single number!')
end

% Dropout
if not(islogical(DrpOutOn)); error('Dropout must be logical!'); end

% StandardizeInput
if not(islogical(StndDeep)); error('StandardizeInput must be logical!'); end
if StndDeep; StndType = 'zscore'; else; StndType = 'none'; end

% WeightsInit
if not(isstring(WghtInit) || ischar(WghtInit) || iscellstr(WghtInit))
    error('WeightsInit must be char, string, or cellstr!')
end
WghtInit = string(WghtInit);
if not(any(strcmpi(WghtInit, {'glorot', 'he', 'orthogonal', 'narrow-normal', 'zeros', 'ones'})))
    error(['WeightsInit must be single value, glorot, ', ...
           'he, orthogonal, narrow-normal, zeros, or ones!'])
end

% FinalNetwork
if not(isstring(FinalNet) || ischar(FinalNet) || iscellstr(FinalNet))
    error('FinalNetwork must be char, string, or cellstr!')
end
FinalNet = string(FinalNet);
if not(any(strcmpi(FinalNet, {'auto', 'last-iteration', 'best-validation'})))
    error('FinalNetwork must be a single value, auto, last-iteration, or best-validation!')
end

% ObjectiveMetric
if not(isstring(ObjcMetr) || ischar(ObjcMetr) || iscellstr(ObjcMetr))
    error('ObjectiveMetric must be char, string, or cellstr!')
end
ObjcMetr = string(ObjcMetr);
if not(isscalar(ObjcMetr))
    error('ObjectiveMetric must be a single value!')
end
if not(strcmpi(ObjcMetr, 'loss') || any(strcmpi(ObjcMetr, Mets2Use)))
    error('ObjectiveMetric must be loss or one of the MetricsToUse')
end

% ObjTolerance
if not(isnumeric(ObjToler) && isscalar(ObjToler))
    error('ObjTolerance must be a single number!')
end

% ValidationData
if not(iscell(VldtData) && numel(VldtData)==2)
    error(['Validation set must be given as a 1x2 or 2x1 cell, ', ...
           'containing as a first argument the validation dataset ', ...
           'and as a second argument the expected outputs!'])
end
if any(cellfun(@isempty, VldtData)); UseVal = false; else; UseVal = true; end
DsetVal = VldtData{1};
ExOtVal = VldtData{2};
if size(DsetVal, 1) ~= numel(ExOtVal)
    error(['The first argument of the validation cell must contain a n. ', ...
           'of rows equal to the number of element of the second argument ', ...
           '(that is the expected output of the validation and must be a 1D vector)'])
end
if istable(DsetVal) % Datasets must be always arrays!
    DsetVal = table2array(DsetVal);
end

% ValidFrequency
if not(isnumeric(VldtFreq) && isscalar(VldtFreq))
    error('ValidFrequency must be a single number!')
end

% ValidPatience
if not(isnumeric(VldtPatc) && isscalar(VldtPatc))
    error('ValidPatience must be a single number!')
end

% InitialLearnRate
if not(isnumeric(InitLrRt) && isscalar(InitLrRt))
    error('InitialLearnRate must be a single number!')
end

% LRDropSchedule
if not(islogical(DropSchd)); error('DropSchedule must be logical!'); end
if DropSchd; DropType = 'piecewise'; else; DropType = 'none'; end

% LRDropPeriod
if not(isnumeric(DropPrdI) && isscalar(DropPrdI))
    error('LRDropPeriod must be a single number!')
end

% LRDropFactor
if not(isnumeric(DropLrRt) && isscalar(DropLrRt))
    error('LRDropFactor must be a single number!')
end

% ShuffleType
if not(isstring(SfflType) || ischar(SfflType) || iscellstr(SfflType))
    error('ShuffleType must be char, string, or cellstr!')
end
SfflType = string(SfflType);
if not(isscalar(SfflType))
    error('ShuffleType must be a single value!')
end
if not(any(strcmpi(SfflType, {'once', 'never', 'every-epoch'})))
    error('ShuffleType must be once, never, or every-epoch!')
end

% MiniBatchSize
if not(isnumeric(MiniBtch) && isscalar(MiniBtch))
    error('ValidPatience must be a single integer number!')
end
MiniBtch = int64(MiniBtch);

% LineSearchMethod
if not(isstring(LnSrchMt) || ischar(LnSrchMt) || iscellstr(LnSrchMt))
    error('LineSearchMethod must be char, string, or cellstr!')
end
LnSrchMt = string(LnSrchMt);
if not(isscalar(LnSrchMt))
    error('LineSearchMethod must be a single value!')
end
if not(any(strcmpi(LnSrchMt, {'weak-wolfe', 'strong-wolfe', 'backtracking'})))
    error('LineSearchMethod must be weak-wolfe, strong-wolfe, or backtracking!')
end

% MaxLineSrchIter
if not(isnumeric(MxLnSrch) && isscalar(MxLnSrch))
    error('MaxLineSrchIter must be a single integer number!')
end
MxLnSrch = int64(MxLnSrch);

% HistSizeLBFGS
if not(isnumeric(HistSize) && isscalar(HistSize))
    error('HistSizeLBFGS must be a single integer number!')
end
HistSize = int64(HistSize);

% GradTolerance
if not(isnumeric(GrdToler) && isscalar(GrdToler))
    error('GradTolerance must be a single number!')
end

% StepTolerance
if not(isnumeric(StpToler) && isscalar(StpToler))
    error('StepTolerance must be a single number!')
end

% CheckpointPath
if not(isstring(Path4Hst) || ischar(Path4Hst) || iscellstr(Path4Hst))
    error('CheckpointPath must be char, string, or cellstr!')
end
Path4Hst = string(Path4Hst);
if not(isscalar(Path4Hst))
    error('CheckpointPath must be a single value (one folder)!')
end
if not(Path4Hst == "")
    if not(exist(Path4Hst, 'dir'))
        warning(['The folder to use for saving the models does ', ...
                 'not exist. It will be created! ',char(Path4Hst)])
        mkdir(Path4Hst)
    end
end

% CheckpointFreq
if not(isnumeric(HistFreq) && isscalar(HistFreq) && ((HistFreq - floor(HistFreq)) == 0))
    error('CheckpointFreq must be a single and integer number!')
end
HistFreq = int64(HistFreq);

% CheckpointUnit
if not(isstring(HistFrUn) || ischar(HistFrUn) || iscellstr(HistFrUn))
    error('CheckpointUnit must be char, string, or cellstr!')
end
HistFrUn = string(HistFrUn);
if not(any(strcmpi(HistFrUn, {'epoch', 'iteration'})))
    error('CheckpointUnit must be a single value, epoch or iteration!')
end

%% Core
if ClassNet
    if not(iscategorical(ExpectedOutTrain))
        ExpectedOutTrain = categorical(ExpectedOutTrain, 'Ordinal',true);
    end
    if not(iscategorical(ExOtVal))
        ExOtVal = categorical(ExOtVal, 'Ordinal',true);
    end
else
    if iscategorical(ExpectedOutTrain)
        error('Since you have a regression task, the train outputs must be numeric!')
    end
    if iscategorical(ExOtVal)
        error('Since you have a regression task, the validation outputs must be numeric!')
    end
end

DpActLyr = cell(1, numel(LaySizes));
for i2 = 1:numel(LaySizes)
    switch lower(LyrsActv{i2})
        case 'relu'
            DpActLyr{i2} = reluLayer;
    
        case 'sigmoid'
            DpActLyr{i2} = sigmoidLayer;
    
        case 'tanh'
            DpActLyr{i2} = tanhLayer;
    
        case 'elu'
            DpActLyr{i2} = eluLayer;
    
        case 'gelu'
            DpActLyr{i2} = geluLayer;
        
        case 'softplus'
            DpActLyr{i2} = softplusLayer;

        case 'none'
            DpActLyr{i2} = [];
    
        otherwise
            error('Activation function not recognized for Deep mode!')
    end
end

if ClassNet; OutSftMax = softmaxLayer; else; OutSftMax = []; end
if DrpOutOn; DrpOutLyr = dropoutLayer; else; DrpOutLyr = []; end

DeepLyr = cell(numel(LaySizes)+2, 1); % +2 because of input and output layer!
DeepLyr{1} = [featureInputLayer(size(DatasetTrain,2), 'Normalization',StndType, 'NormalizationDimension','all')];
for i2 = 1:numel(LaySizes)
    DeepLyr{i2+1} = [fullyConnectedLayer(LaySizes(i2), 'WeightsInitializer',WghtInit); DpActLyr{i2}; DrpOutLyr];
end
DeepLyr{end} = [fullyConnectedLayer(OutNeurN, 'WeightsInitializer',WghtInit); OutSftMax];
DeepLyr = cat(1, DeepLyr{:});

DeepNet = dlnetwork(DeepLyr);

TrainOpts = trainingOptions(DeepSlvr, 'Plots',Plt2Show, 'Metrics',Mets2Use, ...
                                      'ObjectiveMetricName',ObjcMetr, ...
                                      'OutputFcn',@(x)stopTraining(x,ObjToler), ... % The function of outputFcn must have just one argument (the second output of trainnet, i.e., MdlInfo)
                                      'Verbose',ShowVerb, 'VerboseFrequency',VerbFreq, ...
                                      'OutputNetwork',FinalNet, 'L2Regularization',RegStrgt);

if UseVal
    TrainOpts.ValidationData      = {DsetVal, ExOtVal};
    TrainOpts.ValidationFrequency = VldtFreq;
    TrainOpts.ValidationPatience  = VldtPatc;
end

if not(Path4Hst == "")
    TrainOpts.CheckpointPath      = Path4Hst;
    TrainOpts.CheckpointFrequency = HistFreq;
    if any(strcmpi(DeepSlvr, {'sgdm','rmsprop','adam'}))
        TrainOpts.CheckpointFrequencyUnit = HistFrUn;
    end
end

switch DeepSlvr
    case {'sgdm','rmsprop','adam'}
        TrainOpts.MaxEpochs           = IterLimt;
        TrainOpts.MiniBatchSize       = MiniBtch;
        TrainOpts.Shuffle             = SfflType;
        TrainOpts.InitialLearnRate    = InitLrRt;
        TrainOpts.LearnRateSchedule   = DropType;
        TrainOpts.LearnRateDropPeriod = DropPrdI;
        TrainOpts.LearnRateDropFactor = DropLrRt;

        if strcmp(DeepSlvr,'sgdm')
            TrainOpts.Momentum = .9;

        elseif strcmp(DeepSlvr,'adam')
            TrainOpts.GradientDecayFactor = .9;
        end

        if strcmp(DeepSlvr,'adam') || strcmp(DeepSlvr,'rmsprop')
            TrainOpts.Epsilon = 1e-8;
            TrainOpts.SquaredGradientDecayFactor = .9;
        end

    case 'lbfgs'
        TrainOpts.MaxIterations              = IterLimt;
        TrainOpts.LineSearchMethod           = LnSrchMt;
        TrainOpts.HistorySize                = HistSize; % Values between 3 and 20 suit most tasks
        TrainOpts.MaxNumLineSearchIterations = MxLnSrch;
        TrainOpts.GradientTolerance          = GrdToler;
        TrainOpts.StepTolerance              = StpToler;

    otherwise
        error('Deep solver not recognized in adding extra training options');
end

[TrainedModel, MdlInfo] = trainnet(DatasetTrain, ExpectedOutTrain, DeepNet, 'crossentropy', TrainOpts); % remember that you can use show(MdlInfo) to plot the training history as you would see with 'Plots','training-progress'

%% Nested functions (must be specified at the end)
function StopFlg = stopTraining(InfoObj, Toler)
    CurrObj = InfoObj.TrainingLoss;
    StopFlg = CurrObj < Toler; % It is a logical value, if 1, then it will stop the outputFcn
end

end