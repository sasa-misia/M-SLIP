function PolyOut = polybuffpoint2(PlanCoords, BufferSizes, varargin)
% CREATE POLYGONS OF UNSTABLE, STABLE, AND INDECISION AREAS
%   
% Outputs:
%   - PolyOut : polyshape.
%   
% Required arguments:
%   - PlanCoords : is the matrix with 2 columns (x and y coord) and n rows
%   corresponding to the number of points. Values must be planar!
%   
%   - BufferSizes : is a numeric arraay containing just one value in case
%   of circle buffers or 2 elements (x and y buffers) in case of rectangle
%   buffers. Values must be planar!
%   
% Optional arguments:
%   - 'UniquePoly', logical : is to specify if you want a single polygon in
%   output or a multypolygon (array of polyshapes). If no value is specified
%   then 'true' will be take as default.

%% Input Check
if not( isnumeric(PlanCoords) && isnumeric(BufferSizes) )
    error('All the two inputs must be numerical!')
end

if not( size(PlanCoords, 2) == 2 )
    error('First input must be a nx2 matrix (x and y coordinates)!')
end

if not( numel(BufferSizes) <= 2 && numel(BufferSizes) >= 1 )
    error('Second input must contain 1 or 2 values (circe or rectangle)!')
end

%% Settings
UnPoly = true; % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputUnPoly = find(cellfun(@(x) all(strcmpi(x, "uniquepoly")), vararginCp));

    if InputUnPoly; UnPoly = varargin{InputUnPoly+1}; end
end

%% Core
switch numel(BufferSizes)
    case 1
        PolyOutSep = repmat(polyshape, 1, size(PlanCoords, 1));
        for i1 = 1:numel(PolyOutSep)
            Angs  = linspace(0, 2*pi, 50);
            xCrds = BufferSizes*cos(Angs) + PlanCoords(i1, 1);
            yCrds = BufferSizes*sin(Angs) + PlanCoords(i1, 2);
    
            PolyOutSep(i1) = polyshape(xCrds, yCrds); % Maybe it could be improved just storing coordinates and [nan. nan] at the end of each temp poly. Then a single recall to polyshape function!
        end

    case 2
        PolyOutSep = repmat(polyshape, 1, size(PlanCoords, 1));
        for i1 = 1:numel(PolyOutSep)
            xCrds = [ PlanCoords(i1, 1) - BufferSizes(1), ...
                      PlanCoords(i1, 1) + BufferSizes(1), ...
                      PlanCoords(i1, 1) + BufferSizes(1), ...
                      PlanCoords(i1, 1) - BufferSizes(1)      ];
            yCrds = [ PlanCoords(i1, 2) - BufferSizes(2), ...
                      PlanCoords(i1, 2) - BufferSizes(2), ...
                      PlanCoords(i1, 2) + BufferSizes(2), ...
                      PlanCoords(i1, 2) + BufferSizes(2)      ];
    
            PolyOutSep(i1) = polyshape(xCrds, yCrds); % Maybe it could be improved just storing coordinates and [nan. nan] at the end of each temp poly. Then a single recall to polyshape function!
        end

    otherwise
        error('Case of buffer not recognized!')
end

if UnPoly
    PolyOut = union(PolyOutSep);
else
    PolyOut = PolyOutSep;
end

end