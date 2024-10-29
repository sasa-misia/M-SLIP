function [DataInGrid, xLonGrid, yLatGrid] = scatter2grid(xScatter, yScatter, DataScatter, varargin)

% Function to convert data from scatter to grid, with near value approach
%   
%   [DatInGrid, xLongGrid, yGrid] = scatter2grid(xScatter, yScatter, DataScatter, varargin)
%   
%   Dependencies: none.
%   
% Outputs:
%   DatInGrid : the new data in a 2d matrix format.
%   
%   xLonGrid : the grid of X points in space used for the new DataInGrid.
%   Grid is given in Longitude values.
%   
%   yLatGrid : the grid of Y points in space used for the new DataInGrid.
%   Grid is given in Latitude values.
%   
% Required arguments:
%   - xScatter : numeric 1d array vector, containing all the X values of
%   points sparse in space. Data should be given in Longitude values.
%   
%   - yScatter : numeric 1d array vector, containing all the Y values of
%   points sparse in space. Data should be given in Latitude values.
%   
%   - DataScatter : numeric 1d array vector, containing all the values to
%   interpolate.
%   
% Optional arguments:
%   - 'PlanEPSG', numeric : is the EPSG number that control the conversion 
%   of the scatter coordinates, in order to create a new grid in meters
%   instead of degrees. If no value is specified, then 25832 will be applied.
%   
%   - 'OriginEPSG', numeric : is the EPSG number used with the input data.
%   Input data should be given in Long and Lat but, if it is different from
%   that, you must declare what is the EPSG of xScatter and yScatter. If no 
%   value is specified, then Geographic CRS 4326 will be applied.
%
%   - 'DEMSize', numeric : is the size, in meters, that identify the
%   spacing of the grid. It must be given in 1x2 or 2x1 numeric array. If no 
%   value is specified, then it will be take the nearest size to the minimum 
%   distance between xScatter and yScatter.
%   
%   - 'Interp', string/char : is to define the type of interpolation that
%   you want to apply. It can be 'linear', 'nearest', or 'natural'. More
%   info about those methods in scatterInterpolant MATLAB function.
%   If no value is specified, then 'nearest' will be take as default.
%   
%   - 'yLimits', numeric : is to define the latitude or planar limits in y
%   direction. Keep attention: the limits must be expressed with the same
%   CRS of xScatter and yScatter! It must be a 1x2 or 2x1 numeric array, 
%   containing respectively min and max extension in y coordinates. if no value
%   is selected, then the min and max will be by default the min and max y
%   coordinates of yScatter.
%   
%   - 'xLimits', numeric : is to define the longitude or planar limits in x
%   direction. Keep attention: the limits must be expressed with the same
%   CRS of xScatter and yScatter! It must be a 1x2 or 2x1 numeric array, 
%   containing respectively min and max extension in x coordinates. if no value
%   is selected, then the min and max will be by default the min and max x
%   coordinates of xScatter

%% Input Check
if not(isnumeric(xScatter) && isnumeric(yScatter) && isnumeric(DataScatter))
    error('All the inputs must be 1d numeric vector. Only numeric, not cells or others!')
end

if not(isequal(numel(xScatter), numel(yScatter), numel(DataScatter)))
    error('The three vectors do not have the same number of elements!')
end

if not(any(size(xScatter) == 1) && any(size(yScatter) == 1) && any(size(DataScatter) == 1))
    error('One of your inputs is not a 1d array!')
end

xScatter    = reshape(xScatter   , [numel(xScatter   ), 1]);
yScatter    = reshape(yScatter   , [numel(yScatter   ), 1]);
DataScatter = reshape(DataScatter, [numel(DataScatter), 1]);

%% Settings
PlanEPSG = 25832;      % Default
OrigEPSG = 4326;       % Default
DEMSize  = [nan, nan]; % Default
Interp   = 'nearest';  % Default
xLimits  = [nan, nan]; % Default
yLimits  = [nan, nan]; % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputPlanEPSG = find(cellfun(@(x) all(strcmpi(x, "planepsg"  )), vararginCp));
    InputOrigEPSG = find(cellfun(@(x) all(strcmpi(x, "originepsg")), vararginCp));
    InputDEMSize  = find(cellfun(@(x) all(strcmpi(x, "demsize"   )), vararginCp));
    InputInterp   = find(cellfun(@(x) all(strcmpi(x, "interp"    )), vararginCp));
    InputxLimits  = find(cellfun(@(x) all(strcmpi(x, "xlimits"   )), vararginCp));
    InputyLimits  = find(cellfun(@(x) all(strcmpi(x, "ylimits"   )), vararginCp));

    if InputPlanEPSG; PlanEPSG = varargin{InputPlanEPSG+1}; end
    if InputOrigEPSG; OrigEPSG = varargin{InputOrigEPSG+1}; end
    if InputDEMSize ; DEMSize  = varargin{InputDEMSize+1 }; end
    if InputInterp  ; Interp   = vararginCp{InputInterp+1}; end
    if InputxLimits ; xLimits  = varargin{InputxLimits+1 }; end
    if InputyLimits ; yLimits  = varargin{InputyLimits+1 }; end

    varargin([ InputPlanEPSG, InputPlanEPSG+1, ...
               InputOrigEPSG, InputOrigEPSG+1, ...
               InputDEMSize , InputDEMSize+1 , ...
               InputInterp  , InputInterp+1  , ...
               InputxLimits , InputxLimits+1 , ...
               InputyLimits , InputyLimits+1  ]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(isscalar(PlanEPSG))
    error('PlanEPSG must be a scalar value!')
end

if not(isscalar(OrigEPSG))
    error('OrigEPSG must be a scalar value!')
end

if not(isnumeric(DEMSize))
    error('DEMSize must be a numeric array!')
end

if isscalar(DEMSize)
    warning(['DEMSize is a scalar: it will be converted in a ', ...
             '1x2 array, i.e., a grid with same size on X and Y!'])
    DEMSize = repmat(DEMSize, 1, 2);
end

if not(isequal(size(DEMSize), [1, 2]) || isequal(size(DEMSize), [2, 1]))
    error('DEMSize must be a 1x2 or 2x1 numeric array!')
end

if not(any(strcmp(Interp, {'linear', 'nearest', 'natural'})))
    error('Interp must be specify as linear, nearest or natural!')
end

if not(isnumeric(xLimits) && isnumeric(yLimits))
    error('xLimits and yLimits must be numeric!')
end

if not(isequal(size(xLimits), [1, 2]) || isequal(size(xLimits), [2, 1]))
    error('xLimits must be a 1x2 or 2x1 numeric array!')
end

if not(isequal(size(yLimits), [1, 2]) || isequal(size(yLimits), [2, 1]))
    error('yLimits must be a 1x2 or 2x1 numeric array!')
end

%% Preliminary operations
if OrigEPSG ~= 4326
    % error(['Different original coordinates different from geographic not yet ', ...
    %        'implemented! Please specify in xScatter and yScatter in Longitude', ...
    %        ' and Latitude. If you need it, please contact the support!'])
    [yScatter, xScatter] = projinv(projcrs(OrigEPSG), xScatter, yScatter);
    [yLimits , xLimits ] = projinv(projcrs(OrigEPSG), xLimits , yLimits );
end

[xScattPln , yScattPln ] = projfwd(projcrs(PlanEPSG), yScatter, xScatter);
[xLimitsPln, yLimitsPln] = projfwd(projcrs(PlanEPSG), yLimits , xLimits );

if any(isnan(xLimits))
    xLimitsPln = [min(xScattPln), max(xScattPln)];
else
    if (xLimitsPln(1) < min(xScattPln)) || (xLimitsPln(2) > max(xScattPln))
        warning(['Your limits in x are out of input values, for min and max, ', ...
                 'respectively of: ',char(join( string( [min(xScattPln); -max(xScattPln)] + ...
                                                        [-xLimitsPln(1); xLimitsPln(2)  ] ), ', '))])
    end
end

if any(isnan(yLimits))
    yLimitsPln = [min(yScattPln), max(yScattPln)];
else
    if (yLimitsPln(1) < min(yScattPln)) || (yLimitsPln(2) > max(yScattPln))
        warning(['Your limits in y are out of input values, for min and max, ', ...
                 'respectively of: ',char(join( string( [min(yScattPln); -max(yScattPln)] + ...
                                                        [-yLimitsPln(1); yLimitsPln(2)  ] ), ', '))])
    end
end

if any(isnan(DEMSize))
    DEMSize = [max(diff(unique(xScattPln))), ...
               max(diff(unique(yScattPln)))]; % Please check this operation! Not shure 100%
end

%% Core
xPlnMin = xLimitsPln(1);
yPlnMin = yLimitsPln(1);

xCellNm = round( (xLimitsPln(2) - xPlnMin) / DEMSize(1) );
yCellNm = round( (yLimitsPln(2) - yPlnMin) / DEMSize(2) );

xPlnMax = xPlnMin + DEMSize(1) * xCellNm;
yPlnMax = yPlnMin + DEMSize(2) * yCellNm;

RefPln  = maprefcells([xPlnMin, xPlnMax], [yPlnMin, yPlnMax], [xCellNm, yCellNm]);
[xGridPln, yGridPln] = worldGrid(RefPln);

DataInGrid = nan(size(xGridPln));
InterpData = scatteredInterpolant(xScattPln(:), yScattPln(:), double(DataScatter(:)), Interp); 

DataInGrid(:) = InterpData(xGridPln(:), yGridPln(:));

[yLatGrid, xLonGrid] = projinv(projcrs(PlanEPSG), xGridPln, yGridPln);

end