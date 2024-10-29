function polyOut = polybuffpoint2(pointCoords, bufferSizes, Options)
% CREATE POLYGONS OF UNSTABLE, STABLE, AND INDECISION AREAS
%   
% Outputs:
%   - polyOut : polyshape.
%   
% Required arguments:
%   - pointCoords : is the matrix with 2 columns (x and y coord) and n rows
%   corresponding to the number of points. Values should be planar, but, in 
%   case of geographic, please set optional argument coordType to 'geo'!
%   
%   - bufferSizes : is a numeric arraay containing just one value in case
%   of circle buffers or 2 elements (dx and dy buffers) in case of rectangle
%   buffers. NOTE: Values must be ALWAYS planar!!!
%   
% Optional arguments:
%   - 'uniquePoly', logical : is to specify if you want a single polygon in
%   output or a multypolygon (array of polyshapes). If no value is specified
%   then 'true' will be take as default.
%   
%   - 'coordType', char : is to specify the type of coordinates that you
%   passed. It can be 'plan' (default) or 'geo', in case of geographic
%   coordinates.
% 
% Dependencies:
%   - meters2lonlat (M-SLIP) in case of 'geo' coordinates.

arguments
    pointCoords (:,2) double
    bufferSizes (1,:) double {mustBeVector}
    Options.uniquePoly (1,1) logical = true;
    Options.coordType (1,:) char = 'plan';
end

uniquePoly = Options.uniquePoly;
coordType  = lower(Options.coordType);

%% Input Check
if not( size(pointCoords, 2) == 2 )
    error('First input must be a nx2 matrix (x and y coordinates)!')
end

if not( numel(bufferSizes) <= 2 && numel(bufferSizes) >= 1 )
    error('bufferSizes input must contain just 1 or 2 values (circe or rectangle)!')
end

if any(bufferSizes < 1)
    warning(['You set a buffer less than 1 meter. Please remember that bufferSizes ', ...
             'must be always given in meters, also in case of geographic pointCoords!'])
end

%% Core
switch numel(bufferSizes)
    case 1
        buffPolyType = 'circle';

    case 2
        buffPolyType = 'rectangle';

    otherwise
        error('Please contact support to implement more than 2 element in bufferSizes!')
end

% definition of buffBnd matrix
switch coordType
    case 'plan'
        buffBnd = repmat(bufferSizes, size(coordType, 1), 1);
        if size(buffBnd, 2) == 1; buffBnd = repmat(buffBnd, 1, size(coordType, 2)); end

    case 'geo'
        [xBuffBnd, yBuffBnd] = meters2lonlat( bufferSizes(1), pointCoords(:,2) );
        if strcmp(buffPolyType, 'rectangle')
            [~, yBuffBnd] = meters2lonlat( bufferSizes(2), pointCoords(:,2) );
        end

        buffBnd = [xBuffBnd, yBuffBnd]; % Overwrire of planar buffers, to geographic!

    otherwise
        error('coordType not recognized! It must be "plan" or "geo"')
end

switch buffPolyType
    case 'circle'
        polyOutSep = repmat(polyshape, 1, size(pointCoords, 1));
        for i1 = 1:numel(polyOutSep)
            angs  = linspace(0, 2*pi, 50);
            xCrds = buffBnd(i1,1)*cos(angs) + pointCoords(i1, 1);
            yCrds = buffBnd(i1,2)*sin(angs) + pointCoords(i1, 2);
    
            polyOutSep(i1) = polyshape(xCrds, yCrds); % Maybe it could be improved just storing coordinates and [nan. nan] at the end of each temp poly. Then a single recall to polyshape function!
        end

    case 'rectangle'
        polyOutSep = repmat(polyshape, 1, size(pointCoords, 1));
        for i1 = 1:numel(polyOutSep)
            xCrds = [ pointCoords(i1, 1) - buffBnd(i1, 1), ...
                      pointCoords(i1, 1) + buffBnd(i1, 1), ...
                      pointCoords(i1, 1) + buffBnd(i1, 1), ...
                      pointCoords(i1, 1) - buffBnd(i1, 1)      ];

            yCrds = [ pointCoords(i1, 2) - buffBnd(i1, 2), ...
                      pointCoords(i1, 2) - buffBnd(i1, 2), ...
                      pointCoords(i1, 2) + buffBnd(i1, 2), ...
                      pointCoords(i1, 2) + buffBnd(i1, 2)      ];
    
            polyOutSep(i1) = polyshape(xCrds, yCrds); % Maybe it could be improved just storing coordinates and [nan. nan] at the end of each temp poly. Then a single recall to polyshape function!
        end

    otherwise
        error('Case of buffer not recognized!')
end

if uniquePoly
    polyOut = union(polyOutSep);
else
    polyOut = polyOutSep;
end

end