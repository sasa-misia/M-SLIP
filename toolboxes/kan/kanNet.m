classdef kanNet
    % Definition of Kolmogorov-Arnold Net class
    properties
        ConvergenceInfo struct
        Solver char
        Type char
        TrainingHistory table
        X {mustBeNumeric}
        Y double
        ModelParameters struct
        PredictorNames cell
        ClassNames cell
        LayerSizes double
        Operators double
        Activations cell
        LayerWeights struct
        Limits struct
    end

    methods
        function obj = kanNet(Options)
            arguments
               Options.ConvergenceInfo struct = struct([])
               Options.Solver char = 'Not defined'
               Options.Type char = 'Regression'
               Options.TrainingHistory table = table()
               Options.X {mustBeNumeric} = []
               Options.Y double = []
               Options.ModelParameters struct = struct([])
               Options.PredictorNames cell = {}
               Options.ClassNames cell = {}
               Options.LayerSizes double = []
               Options.Operators double = []
               Options.Activations cell = {}
               Options.LayerWeights struct = struct([])
               Options.Limits struct = struct([])
            end
            
            obj.ConvergenceInfo = Options.ConvergenceInfo;
            obj.Solver          = Options.Solver;
            obj.Type            = Options.Type;
            obj.TrainingHistory = Options.TrainingHistory;
            obj.X               = Options.X;
            obj.Y               = Options.Y;
            obj.ModelParameters = Options.ModelParameters;
            obj.PredictorNames  = Options.PredictorNames;
            obj.ClassNames      = Options.ClassNames;
            obj.LayerSizes      = Options.LayerSizes;
            obj.Operators       = Options.Operators;
            obj.Activations     = Options.Activations;
            obj.LayerWeights    = Options.LayerWeights;
            obj.Limits          = Options.Limits;

            if isempty(obj.PredictorNames)
                obj.PredictorNames = repmat({''}, 1, size(obj.X, 2));
            end

            if size(obj.PredictorNames, 2) ~= size(obj.X, 2)
                error('Columns od training dataset X must match the number of elements contained in PredictorNames!')
            end

            if isempty(obj.Activations)
                obj.Activations = repmat({'B-spline'}, 1, numel(obj.LayerSizes));
            end
       end
    
       function outPred = predict(objNet, dataset)
            if not(isnumeric(dataset) || istable(dataset))
                error('dataset to predict must be an array or a table!')
            end

            if istable(dataset)
                dataset = dataset(:, objNet.PredictorNames); % to reorder table columns and exclude not necessary variables (extra not used during training)
                dataset = table2array(dataset);
            end

            if size(dataset,2) ~= numel(objNet.PredictorNames)
                error(['Dataset to predict must have the same number of column(s) used during training (',num2str(numel(obj.PredictorNames)),')'])
            end

            outPred = modelKA_basisC( dataset, objNet.Limits.xmin, objNet.Limits.xmax, objNet.Limits.ymin, objNet.Limits.ymax, objNet.LayerWeights.Bottom, objNet.LayerWeights.Top );

            if contains(objNet.Type, 'class', 'IgnoreCase',true)
                if numel(objNet.ClassNames) ~= 2
                    error(['You can not predict probabilities with more ', ...
                           'than 2 outputs! Please contact the support.'])
                end
                outPred = max(outPred, objNet.Limits.yprdmin); % consider to use ymin, alternatively
                outPred = min(outPred, objNet.Limits.yprdmax); % consider to use ymax, alternatively
                outPred = rescale(outPred);
            end
       end

       function objOut = compact(objNet)
            objNet.X = [];
            objNet.Y = [];
            objOut = objNet;
       end
    end
end