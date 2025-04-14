function passedCheck = check_poly2grid(coord, grids, polys)

arguments
    coord (2,:) cell % xLon in first row, yLat in second row!
    grids (:,:) cell
    polys (1,:) polyshape
end

if size(grids, 2) ~= size(coord, 2)
    error('grids and coord must have the same number of columns!')
end

for i1 = 1:size(grids, 2)
    for i2 = 1:size(grids, 1)
        if not(isequal( size(grids{i2, i1}), size(coord{1, i1}), size(coord{2, i1}) ))
            error(['One of the matrices of grids or coord, contained in ', ...
                   'column n. ',num2str(i1),' is not consistent in sizes!'])
        end
    end
end

passedCheck = false(size(polys));
for i1 = 1:numel(polys)
    [ppPl, eePl] = getnan2([polys(i1).Vertices; nan, nan]);
    passCheckGr  = false(size(grids));
    for i2 = 1:size(grids, 2)
        indPtsInGrid = find(inpoly([coord{1, i2}(:),coord{2, i2}(:)], ppPl, eePl));
        if isempty(indPtsInGrid); passCheckGr(:, i2) = true; continue; end % next for cycle will be skipped
        for i3 = 1:size(grids, 1)
            unqValsTemp = unique(grids{i3, i2}(indPtsInGrid));
            if isscalar(unqValsTemp) % if the association is correct, just a single number must be there!
                passCheckGr(i3, i2) = true;
            else
                percUnqVals = zeros(1, numel(unqValsTemp));
                for i4 = 1:numel(unqValsTemp)
                    percUnqVals(i4) = sum(grids{i3, i2}(indPtsInGrid) == unqValsTemp(i4)) / numel(grids{i3, i2}(indPtsInGrid));
                end
                passCheckGr(i3, i2) = any(percUnqVals > .99); % there can be errors due to compenetration of polygons, but if one class is repeated more than 99%, the association is still good.
            end
        end
    end

    passedCheck(i1) = all(passCheckGr, 'all');
end

end