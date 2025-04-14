function [unstProbs, signThrs, anlType, limVals, anlDate] = load_fs2probs(foldPath, indStudy, Options)

arguments
    foldPath (1,:) char {mustBeFolder}
    indStudy (1,:) cell
    Options.subIndices (1,:) cell = {}
    Options.checkPtNum (1,1) logical = true
    Options.cutFsValue (1,2) double = [.1, 10]
    Options.useFsRlLim (1,1) logical = false
    Options.indAn2Load (1,1) double = 0
end

subIndices = Options.subIndices;
checkPtNum = Options.checkPtNum;
cutFsValue = Options.cutFsValue;
useFsRlLim = Options.useFsRlLim;
indAn2Load = Options.indAn2Load;

%% Check inputs
if not(all(cellfun(@isnumeric, indStudy)))
    error('Each cell of indStudy must contain a numeric array!')
end

if not(isempty(subIndices)) && not(all(cellfun(@isnumeric, subIndices)))
    error('Each cell of subIndices must contain a numeric array!')
end

if isempty(subIndices)
    subIndices = cellfun(@(x) (1:numel(x))', indStudy, 'UniformOutput',false);
end

%% Core
sl = filesep;

limVals = zeros(1, 2);
numStdy = numel(cat(1, indStudy{:}));

anlTpID = find( [exist([foldPath,sl,'AnalysisInformation.mat'], 'file'), ...
                 exist([foldPath,sl,'MLMdlB.mat'             ], 'file')] );
if isempty(anlTpID)
    error('No analysis found in your folder!')
elseif numel(anlTpID) > 1
    if numel(anlTpID) ~= 2; error('Implement new analysis type!'); end
    anlTpID = listdlg2({'Analysis to load'}, {'SLIP/Hybrid', 'ML'}, 'OutType','NumInd');
end

switch anlTpID
    case 1 % SLIP or Hybrid
        load([foldPath,sl,'AnalysisInformation.mat'], 'StabilityAnalysis')
        
        if indAn2Load == 0
            indAn2Load = listdlg2({'Datetime of analysis:'}, string(StabilityAnalysis{2}), 'OutType','NumInd');
        end
    
        anlType = StabilityAnalysis{4}(1);
        anlDate = StabilityAnalysis{2}(indAn2Load);

        switch anlType
            case "Slip"
                load([foldPath,sl,'Fs',num2str(indAn2Load),'.mat'], 'FactorSafety')

                if checkPtNum && ( sum(cellfun(@numel, FactorSafety)) ~= numStdy )
                    error(['You can not use this model because there is a ', ...
                           'mismatch between points in Study Area and FactorSafety'])
                end

                fsSub = cellfun(@(x,y) x(y), FactorSafety, subIndices, 'UniformOutput',false);

                isSmlFs = cellfun(@(x) x < cutFsValue(1), fsSub, 'UniformOutput',false); % Fs > 10 means unconditionally stable!
                for i2 = 1:length(fsSub)
                    fsSub{i2}(isSmlFs{i2}) = cutFsValue(1); % Too small points (unconditionally unstable) will be considered cutFsValue(1)
                end
                
                isBigFs = cellfun(@(x) x > cutFsValue(2), fsSub, 'UniformOutput',false); % Fs > 10 means unconditionally stable!
                for i2 = 1:length(fsSub)
                    fsSub{i2}(isBigFs{i2}) = cutFsValue(2); % Inf or too big points (unconditionally stable) will be considered cutFsValue(2) (otherwise max will give Inf or a number too large)!
                end

                isNanFs = cellfun(@(x) isnan(x), fsSub, 'UniformOutput',false);
                for i2 = 1:length(fsSub)
                    fsSub{i2}(isNanFs{i2}) = cutFsValue(2); % NaN Points are excluded and considered as unconditionally stable
                end
    
                limVals(1) = min(cellfun(@min, fsSub));
                limVals(2) = max(cellfun(@max, fsSub));
                if useFsRlLim; fsLims = limVals; else; fsLims = cutFsValue; end
    
                unstProbs = cellfun(@(x) fs2probs(x, fsLims=fsLims), fsSub, 'UniformOutput',false);

                signFsVl = [1, 1.5, 2];
                signThrs = arrayfun(@(x) fs2probs(x, fsLims=fsLims), signFsVl);

            case "Hybrid"
                load([foldPath,sl,'FsH',num2str(indAn2Load),'.mat'], 'FsHybrid');

                if checkPtNum && ( sum(cellfun(@numel, FsHybrid)) ~= numStdy )
                    error(['You can not use this model because there is a ', ...
                           'mismatch between points in Study Area and FsHybrid'])
                end
    
                unstProbs = cellfun(@(x,y) x(y), FsHybrid, subIndices, 'UniformOutput',false);

                signThrs = 0.5;

            otherwise
                error('Analysis of FS not recognized!')
        end

    case 2 % ML
        anlType = "ML";

        if not(exist([foldPath,sl,'PredictionsStudy.mat'], 'file'))
            error('You must predict the study area first!')
        end

        load([foldPath,sl,'PredictionsStudy.mat'], 'PredProbs','EventsInfo')

        if indAn2Load == 0
            indAn2Load = listdlg2({'Date of analysis:'}, [EventsInfo{'PredictionDate',:}{:}], 'OutType','NumInd');
        end
        
        if isscalar(PredProbs.Properties.VariableNames)
            indMdl = 1;
        else
            indMdl = listdlg2({'Model to use:'}, PredProbs.Properties.VariableNames, 'OutType','NumInd');
        end

        prStudy = full(PredProbs{indAn2Load, indMdl}{:});
        anlDate = EventsInfo{'PredictionDate',indAn2Load}{:};

        limVals(1) = min(prStudy);
        limVals(2) = max(prStudy);

        if checkPtNum && ( numel(prStudy) ~= numStdy )
            error(['You can not use this model because there is a ', ...
                   'mismatch between points in Study Area and PredProbs'])
        end

        subIndCat = subIndices;
        for i2 = 2:numel(subIndices)
            subIndCat{i2} = subIndices{i2} + sum(cellfun(@(x) numel(x), indStudy(1:(i2-1))));
        end

        unstProbs = cellfun(@(x) prStudy(x), subIndCat, 'UniformOutput',false);
        
        signThrs = 0.5;
        
    otherwise
        error('Analysis type not recognized!')
end

% Cleaning of UnstProb
isNanPrb = cellfun(@(x) isnan(x), unstProbs, 'UniformOutput',false);
for i2 = 1:numel(unstProbs)
    unstProbs{i2}(isNanPrb{i2}) = 0; % NaN Points are excluded and considered as unconditionally stable
end
    
end