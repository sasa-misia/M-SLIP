function [xMrg, yMrg, dxMrg, dyMrg] = fast_merge_dems(xCoords, yCoords, Options)

arguments
    xCoords (1,:) cell
    yCoords (1,:) cell
    Options.newRes (1,2) double = [0, 0]
end

newRes = Options.newRes;

%% Input check
for i1 = 1:numel(xCoords)
    if not(isnumeric(xCoords{i1}) && isnumeric(yCoords{i1}))
        error(['xCoords or yCoords contains not a numeric matrix at position: ',num2str(i1)])
    end
    if not(isequal(size(xCoords{i1}), size(yCoords{i1})))
        error(['xCoords and yCoords do not have same matrix sizes at position: ',num2str(i1)])
    end
end

if any(isnan(newRes) | isinf(newRes) | newRes<0)
    error('newRes must contains [dxRes, dyRes] and must be > 0 in both cases, not Inf, not NaN!')
end

%% Core
if newRes(1)
    dxMrg = newRes(1);
else
    dxMrg = abs(mean(diff(xCoords{1}, 1, 2), 'all'));
end

if newRes(2)
    dyMrg = newRes(2);
else
    dyMrg = abs(mean(diff(yCoords{1}, 1, 1), 'all'));
end

xMin = min(cellfun(@(x) min(x, [], 'all'), xCoords));
xMax = max(cellfun(@(x) max(x, [], 'all'), xCoords));
yMin = min(cellfun(@(x) min(x, [], 'all'), yCoords));
yMax = max(cellfun(@(x) max(x, [], 'all'), yCoords));

[xMrg, yMrg] = meshgrid(xMin :  dxMrg : xMax, ...
                        yMax : -dyMrg : yMin); % works only with north emisphere!

end