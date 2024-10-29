function [rocMetrics, rocSummMtr] = roccurve2(predProbabts, expectedOuts, Options)

arguments
    predProbabts (:,:) single
    expectedOuts (:,1) single
    Options.bestThrMethod (1,:) char = 'MATLAB'
    Options.multiClass (1,1) logical = false
    Options.columnClass (1,:) single = []
end

bestThrMethod = lower(Options.bestThrMethod);
multiClass = Options.multiClass;
columnClass = Options.columnClass;

%% Check inputs
if size(predProbabts, 1) ~= size(expectedOuts, 1)
    error('The number of rows of 1st and 2nd arguments must be equal!')
end

if multiClass
    if (numel(unique(expectedOuts)) - 1) ~= size(predProbabts, 2)
        error(['To use multiClass, you must have x-1 columns in predictions, where ', ...
               'x is the number of classes in expectedOuts (0 class excluded).'])
    end

    if not(any(unique(expectedOuts) == 0))
        error('0 class is not inside in your expected outputs!')
    end
else
    if (numel(unique(expectedOuts)) > 2)
        warning(['Multiple classes in expected outputs! They ', ...
                 'will be converted in 0 or not 0 (forced to 1).'])
    
        expectedOuts = double(expectedOuts >= 1);
    
        if size(predProbabts, 2) > 1
            predProbabts = sum(predProbabts, 2);
        else
            error(['Predictions have a single column, but ', ...
                   'the expected outputs are more than 2!'])
        end
    end
    
    if not(isequal(unique(expectedOuts), [0; 1]))
        error('Expected outputs must be just 0 or 1!')
    end
    
    if size(predProbabts, 2) > 1
        error('Predictions must have a single column!')
    end
end

if (max(predProbabts, [], 'all') > 1) || (min(predProbabts, [], 'all') < 0)
    warning(['Probabilities are outside the range [0,1]! They ', ...
             'will be rescaled from 0 to 1 automatically.'])
    predProbabts = rescale(predProbabts);
end

if isempty(columnClass)
    possClasses = unique(expectedOuts);
    possClasses(possClasses==0) = [];
    columnClass = possClasses'; % By default, columnClass is ordered numerically (ascend order) and 0 class is deleted!
end

if numel(columnClass) ~= size(predProbabts, 2)
    error('Each column of probabilities must have a corresponding class!')
end

%% Core
[fpr4ROC, tpr4ROC, thrsROC, auroc, optPnt, ...
        indBest, bestThr] = deal(cell(1, size(predProbabts, 2)));
for i1 = 1:size(predProbabts, 2)
    [fpr4ROC{i1}, tpr4ROC{i1}, thrsROC{i1}, auroc{i1}, optPnt{i1}] = perfcurve(expectedOuts, predProbabts(:,i1), columnClass(i1));
    switch bestThrMethod
        case 'matlab'
            % Method integrated in MATLAB
            indBest{i1} = find(ismember([fpr4ROC{i1}, tpr4ROC{i1}], optPnt{i1}, 'rows'));
            bestThr{i1} = thrsROC{i1}(indBest{i1});
    
        case 'maximizeratio-tpr-fpr'
            % Method max ratio TPR/FPR
            ratTprFpr = tpr4ROC{i1}./fpr4ROC{i1};
            ratTprFpr(isinf(ratTprFpr)) = nan;
            [~, indBest{i1}] = max(ratTprFpr);
            bestThr{i1} = thrsROC{i1}(indBest{i1});
    
        case 'maximizearea-tpr-tnr'
            % Method max product TPR*TNR
            areaTprTnr = tpr4ROC{i1}.*(1-fpr4ROC{i1});
            [~, indBest{i1}] = max(areaTprTnr);
            bestThr{i1} = thrsROC{i1}(indBest{i1});
    
        otherwise
            error(['bestThrMethod mode not recognized! It must be one between ', ...
                   '{MATLAB, MaximizeRatio-TPR-FPR, MaximizeArea-TPR-TNR}'])
    end
end

avg_auroc = mean(cell2mat(auroc));
min_auroc = min(cell2mat(auroc));
max_auroc = max(cell2mat(auroc));
sDv_auroc = std(cell2mat(auroc));

if isscalar(auroc)
    fpr4ROC = fpr4ROC{:}; 
    tpr4ROC = tpr4ROC{:}; 
    auroc   = auroc{:};
    bestThr = bestThr{:}; 
    indBest = indBest{:};
end

rocMtrRows = {'FPR', 'TPR', 'AUC', 'BestThreshold', 'BestThrInd', 'Class'};
rocMetrics = cell2table({fpr4ROC; tpr4ROC; auroc; bestThr; indBest; columnClass}, 'RowNames',rocMtrRows);

rocSMtRows = {'MeanAUC', 'MinAUC', 'MaxAUC', 'StDvAUC'};
rocSummMtr = array2table({avg_auroc; min_auroc; max_auroc; sDv_auroc}, 'RowNames',rocSMtRows);