function kanObj = trainKAN(trainDataset, expectedOuts, Options)

arguments
    trainDataset (:,:) {mustBeValidDset}
    expectedOuts (:,1) double
    Options.trainingInds (:,1) logical = true(size(expectedOuts))
    Options.learningRate (1,1) double = 0.1
    Options.trainEpochs  (1,1) double = 500
    Options.netStrLayers (1,:) double {mustBeVector} = [7, 7]
    Options.validPatience (1,1) double = 10
    Options.lossTolerance (1,1) double = 0.001
    Options.validationData (1,:) cell = cell(1,2)
end

trainingInds   = Options.trainingInds;
learningRate   = Options.learningRate;
trainEpochs    = Options.trainEpochs;
netStrLayers   = Options.netStrLayers;
validPatience  = Options.validPatience;
lossTolerance  = Options.lossTolerance;
validationData = Options.validationData;

if sum(cellfun(@isempty, cell(1,2))) == 2
    if not(all(trainingInds))
        error('You have to specify trainingInds OR validationData, NOT both!')
    end
    trainDataset = [trainDataset; validationData{1}];
    expectedOuts = [expectedOuts; validationData{2}];
    trainingInds = [trainingInds; false(numel(validationData{2}), 1)];
elseif sum(cellfun(@isempty, cell(1,2))) == 1
    error(['If you specify optional argument validationData, ', ...
           'you must fill a 1x2 cell {validDset, validExpOuts}!'])
end

%% Check
if not(isnumeric(trainDataset) || istable(trainDataset))
    error('trainDataset (1st input) must be a numeric array or a table!')
end

if size(trainDataset,1) ~= size(expectedOuts,1)
    error('Number of rows for trainDataset and expectedOuts must be the same!')
end

predctrNames = repmat({''}, 1, size(trainDataset, 2));
if istable(trainDataset)
    predctrNames = trainDataset.Properties.VariableNames;
    trainDataset = table2array(trainDataset);
end

clssNms = {};
netType = 'Regression';
if numel(unique(expectedOuts)) <= 1
    error('You must have at least 2 different values in expectedOuts!')
elseif numel(unique(expectedOuts)) == 2 % please modify the rest of the script if you change it!
    netType = 'Classification';
else
    disp('More than two unique values to predict -> regression')
end

if numel(netStrLayers) ~= 2
    error('netStrLayers must be a 1x2 numeric array!')
end

%% Parameters
N = size(trainDataset,1); % total number of input-output records - training and validation
m = size(trainDataset,2); % number of inputs

%. label records to be used for training and validation
labTrnVal = ones(N,1);
labTrnVal(not(trainingInds)) = 2;
identID = 1;
verifID = 2;

%. limits
xmin = min(min(trainDataset));
xmax = max(max(trainDataset));
ymin = min(expectedOuts);
ymax = max(expectedOuts);

%. num. of nodes bottom
n = netStrLayers(1);

%. num. of nodes top
q = netStrLayers(2);

%. num. of bottom operators, 2*m+1 for classical K.-A.
p = 2*m+1;

%% Core
%. initialise
[ fnB0, fnT0 ] = buildKA_init( m, n, q, p, ymin, ymax );

%. basis functions - cubic splines, identification method - Newton-Kaczmarz, standard
[ outs, weights, loss, stopInfo, inTop, LgradAll, limits ] = buildKA_basisC_mod( trainDataset, expectedOuts, ...
                                                                                 labTrnVal, identID, verifID, ...
                                                                                 learningRate, trainEpochs, ...
                                                                                 xmin, xmax, ymin, ymax, ...
                                                                                 fnB0, fnT0, ...
                                                                                 lossTolerance=lossTolerance, ...
                                                                                 verifPatience=validPatience );

if contains(netType, 'class', 'IgnoreCase',true)
    clssNms = num2cell(unique(expectedOuts)'); % expectedOuts supposed to be always vertical
    yprdmax = max(outs(trainingInds));
    yprdmin = min(outs(trainingInds));
    limits.yprdmax = yprdmax;
    limits.yprdmin = yprdmin;
end

laySizes = [n, q];
actFuncs = repmat({'B-spline'}, 1, numel(laySizes));

%% Output
mdlPar = struct('LayerSizes',laySizes, ...
                'Activations',actFuncs, ...
                'LossTolerance',lossTolerance, ...
                'ValidationPatience',validPatience, ...
                'Method','KanNetwork', ...
                'Type',netType);

kanObj = kanNet(ConvergenceInfo=stopInfo, ...
                Solver='Cubic splines; Newton-Kaczmarz; Standard', ...
                Type=netType, ...
                TrainingHistory=loss, ...
                X=trainDataset, Y=expectedOuts, ...
                ModelParameters=mdlPar, ...
                PredictorNames=predctrNames, ...
                ClassNames=clssNms, ...
                LayerSizes=laySizes, ...
                Operators=p, ...
                Activations=actFuncs, ...
                LayerWeights=weights, ...
                Limits=limits);

end

function mustBeValidDset(a)
    assert(isa(a,'table') || isa(a,'double'), ...
                        'mustBeValidDset:notTableOrDouble', ...
                        'Input must be either a table or double array.')
end