function [xCurve, yCurve, thrs2Use, crvAUC, optPoint, indSgPts] = perfcurve_polygon(pointsProbs, pointsCoords, unstPolygons, Options)

% Purpose: function to create roc or prc curves with soil slips polygons
% 
% Outputs: 
%       - xCurve       = [numeric] the x coordinates of the curve
%       - yCurve       = [numeric] the y coordinates of the curve
%       - thrs2Use     = [numeric] the thresholds that were used for points
%       - crvAUC       = [numeric] the result of the AUC
%       - optPoint     = [numeric] the index of the point that maximize TPR
%                        over FPR
%       - indSgPts     = [numeric] the indices of the significantThr
% 
% Inputs:
%       - pointsProbs  = [cell] cell 1xn containing the probabilities of
%                        each point in each grid of the original DEMs.
%       - pointsCoords = [cell] cell 2xn containing as 1st row the longitudes
%                        and as 2nd row the latitudes (each cell must be
%                        numeric and the number of columns must be the same
%                        of pointsProbs.
%       - unstPolygons = [polyshape] polyshape array containing polygons of
%                        unstable area.
% 
% Optional inputs:
%       - significantThr = [numeric] the array containing the significant
%                          thresholds (points of the curve) to investigate.
%       - unstApproach   = [numeric] 1 (default) -> each point of the grid
%                          is considered as separate from the others.
%                          2 -> if a number of points >= minUnstable is
%                          detected inside one of the unstPolygons, then
%                          all the pixels in that polygon will switch as
%                          TP, also if there are some FN!
%       - minUnstable    = [numeric] the minimum number of points (pixels)
%                          that must be unstable to consider the entire
%                          polygon as unstable (effective only with
%                          unstApproach set to 2)
%       - curveType      = [char] 'roc' (default) or 'prc' curve.
%       - progDialog     = [matlab.ui.dialog.ProgressDialog] the progress bar 
%                          object that can be used to monitoring progress.
% 
% Dependencies: polybuffpoint2 (M-SLIP), getnan2, inpoly

arguments
    pointsProbs (1,:) cell
    pointsCoords (2,:) cell
    unstPolygons (1,:) polyshape
    Options.significantThr (1,:) double = .5
    Options.unstApproach (1,1) double = 1
    Options.curveType (1,:) char = 'roc'
    Options.progDialog = []
    Options.minUnstable (1,1) int32 = 1
end

significantThr = Options.significantThr;
unstApproach   = Options.unstApproach;
curveType      = lower(Options.curveType);
progDialog     = Options.progDialog;
minUnstable    = Options.minUnstable;

%% Input check
if not(isequal(size(pointsProbs, 2), size(pointsCoords, 2)))
    error('Columns number of the first 2 inputs must be the same!')
end

for i1 = 1:numel(pointsProbs)
    if not(isnumeric(pointsProbs{i1})) || not(isnumeric(pointsCoords{1, i1})) || not(isnumeric(pointsCoords{2, i1}))
        error('All cells contained in pointsProbs and pointsCoords must contain numeric vectors!')
    end

    if not(isequal(size(pointsProbs{i1}), size(pointsCoords{1, i1}), size(pointsCoords{2, i1})))
        error('All cells contained in pointsProbs and pointsCoords must have consistent sizes!')
    end

    pointsProbs{i1} = round(pointsProbs{i1}, 2);

    pointsProbs{i1}     = [pointsProbs{i1}(:)    ]; % vertical concatenation
    pointsCoords{1, i1} = [pointsCoords{1, i1}(:)]; % vertical concatenation
    pointsCoords{2, i1} = [pointsCoords{2, i1}(:)]; % vertical concatenation

    if any(pointsProbs{i1} > 1) || any(pointsProbs{i1} < 0)
        error('pointsProbs must contain probabilities in the range [0, 1]')
    end
end

if any(significantThr < 0) || any(significantThr > 1)
    error('mainThresholds must be in the range [0, 1]')
end

if not(any(unstApproach == [1, 2]))
    error('unstApproach must be 1 or 2!')
end

if not(any(strcmp(curveType, {'roc', 'prc'})))
    error('curveType must be "roc" or "prc"!')
end

progExist = isa(progDialog, 'matlab.ui.dialog.ProgressDialog');
if not(isempty(progDialog)) && not(progExist)
    error('progDialog must be a matlab.ui.dialog.ProgressDialog class!')
end

%% Thresholds to use to build the curve
extraPnt = max(max(cat(1, pointsProbs{:})), max(significantThr)) + .01; % to ensure that all the possible points of ROC curve are considered! (>= of values, thus the last one must be not existing)
allVlsCt = [cat(1, pointsProbs{:}); significantThr'; extraPnt];
thrs2Use = flip(unique(allVlsCt)');
indSgPts = find(ismember(thrs2Use, significantThr));

%% Bounding polygons for TP
totUnstPlys = union(unstPolygons); % Otherwise in the next for loop you have a low speed
[pBndTot, eBndTot] = getnan2([totUnstPlys.Vertices; nan, nan]);

[pBndSep, eBndSep] = deal(cell(1, numel(unstPolygons)));
for i1 = 1:numel(unstPolygons)
    [pBndSep{i1}, eBndSep{i1}] = getnan2([unstPolygons(i1).Vertices; nan, nan]);
end

%% Finding TP, TN, FP, FN
if progExist; progDialog.Indeterminate = 'off'; end

[crvTPR, crvTNR, crvFPR, crvFNR, crvPRC] = deal(zeros(1, numel(thrs2Use)));
for i1 = 1:numel(thrs2Use)
    if progExist
        progDialog.Value = i1/numel(thrs2Use);
        progDialog.Message = ['Threshold n. ',num2str(i1),' of ',num2str(numel(thrs2Use))];
    end

    stabPntsInd = cellfun(@(x) x <  thrs2Use(i1), pointsProbs, 'UniformOutput',false);
    unstPntsInd = cellfun(@(x) x >= thrs2Use(i1), pointsProbs, 'UniformOutput',false);

    xCrdsStab = cellfun(@(x,y) x(y), pointsCoords(1,:), stabPntsInd, 'UniformOutput',false);
    yCrdsStab = cellfun(@(x,y) x(y), pointsCoords(2,:), stabPntsInd, 'UniformOutput',false);
    xCrdsUnst = cellfun(@(x,y) x(y), pointsCoords(1,:), unstPntsInd, 'UniformOutput',false);
    yCrdsUnst = cellfun(@(x,y) x(y), pointsCoords(2,:), unstPntsInd, 'UniformOutput',false);

    numUnstPts = sum(cellfun(@numel, xCrdsUnst));
    numStabPts = sum(cellfun(@numel, xCrdsStab));

    % NOTE: Negative are stable points, Positive are unstable points!
    switch unstApproach
        case 1 % Individual points
            stabInPlyTot = cellfun(@(x,y) inpoly([x,y], pBndTot, eBndTot), xCrdsStab, yCrdsStab, 'UniformOutput',false);
            unstInPlyTot = cellfun(@(x,y) inpoly([x,y], pBndTot, eBndTot), xCrdsUnst, yCrdsUnst, 'UniformOutput',false);

            numFN = sum(cellfun(@sum, stabInPlyTot)); % StabInPlyRP is logical
            numTP = sum(cellfun(@sum, unstInPlyTot)); % UnstInPlyRP is logical
            numTN = numStabPts - numFN;
            numFP = numUnstPts - numTP;

        case 2 % At least NumMinUnst points in radius (separate polygon)
            if isscalar(unstPolygons)
                warning('unstApproach 2 must be used with a polyshape containing multiple polygons!')
            end

            hasMinUnst = false(numel(unstPolygons), 1);
            [stabInPlySep, unstInPlySep] = deal(zeros(numel(unstPolygons), numel(xCrdsStab)));
            for i2 = 1:numel(unstPolygons)
                stabInPlySep(i2,:) = cellfun(@(x,y) sum(inpoly([x,y], pBndSep{i2}, eBndSep{i2})), xCrdsStab, yCrdsStab);
                unstInPlySep(i2,:) = cellfun(@(x,y) sum(inpoly([x,y], pBndSep{i2}, eBndSep{i2})), xCrdsUnst, yCrdsUnst);

                if sum(unstInPlySep(i2,:)) >= minUnstable
                    hasMinUnst(i2) = true;
                end
            end

            % switches happen just with FN and TP (polygons must be made only of all TP or all FN), outside no effect
            numFN = sum(unstInPlySep(not(hasMinUnst), :), 'all') + sum(stabInPlySep(not(hasMinUnst), :), 'all');
            numTP = sum(unstInPlySep(hasMinUnst     , :), 'all') + sum(stabInPlySep(hasMinUnst     , :), 'all');
            numTN = numStabPts - sum(stabInPlySep, 'all');
            numFP = numUnstPts - sum(unstInPlySep, 'all');

        otherwise
            error('UnstProced not recognized or not implemented!')
    end

    crvTPR(i1) = numTP / (numTP + numFN);
    crvTNR(i1) = numTN / (numFP + numTN);
    crvFPR(i1) = numFP / (numFP + numTN);
    crvFNR(i1) = numFN / (numFN + numTP);
    crvPRC(i1) = numTP / (numTP + numFP);
end

if progExist; progDialog.Indeterminate = 'on'; end

switch curveType
    case 'roc'
        xCurve = crvFPR;
        yCurve = crvTPR;

    case 'prc'
        xCurve = crvTPR;
        yCurve = crvPRC;

    otherwise
        error('curveType to use in output not recognized!')
end

crvAUC = trapz(xCurve, yCurve)*100;

[~, optPoint] = max(crvTPR ./ crvFPR);

end