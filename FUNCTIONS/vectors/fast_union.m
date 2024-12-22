function polyOut = fast_union(polyIn)

arguments
    polyIn (1,:) polyshape
end

[crdsReg, crdsHol] = deal(cell(numel(polyIn), 1));
[progReg, progHol] = deal(0);
for i1 = 1:numel(polyIn)
    crdsTemp = polyIn(i1).Vertices;

    if isempty(crdsTemp)
        continue
    end

    if not(isnan(crdsTemp(end, 1)))
        crdsTemp = [crdsTemp; NaN, NaN];
    end

    numReg = polyIn(i1).NumRegions;
    numHol = polyIn(i1).NumHoles;

    progReg = progReg + numReg;
    progHol = progHol + numHol;

    indNaN = find(isnan(crdsTemp(:,1)));

    crdsReg{i1} = crdsTemp(1 : indNaN(numReg), :);
    if numHol >= 1
        crdsHol{i1} = crdsTemp(indNaN(numReg)+1 : end, :);
        if sum(isnan(crdsHol{i1}(:,1))) ~= numHol
            error('Something went wrong during attribution of holes...')
        end
    end
end

% crdsMrg = [cat(1, crdsReg{:}); cat(1, crdsHol{:})];
% if not(isnan(crdsMrg(end, 1)))
%     error('The last row of the coordinates muyst be NaN!')
% end
% crdsMrg(end, :) = [];
% 
% polyOut = polyshape(crdsMrg);

crdsRegTmp = cat(1, crdsReg{:});
crdsHolTmp = cat(1, crdsHol{:});
if not(isnan(crdsRegTmp(end, 1))) || not(isnan(crdsHolTmp(end, 1)))
    error('The last row of the coordinates muyst be NaN!')
end
crdsRegTmp(end, :) = [];
crdsHolTmp(end, :) = [];

polyOut = polyshape({crdsRegTmp(:,1), crdsHolTmp(:,1)}, {crdsRegTmp(:,2), crdsHolTmp(:,2)});

end