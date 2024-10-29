function [ClassInds, ClassCrds, ClassClrs, ClassVals] = clusterize_points(xLonCoords, yLatCoords, Values, varargin)

% CLUSTERIZE POINTS IN GROUP AND REMOVE NOISE (M-SLIP Internal function)
%   
% [ClassInds, ClassCrds, ClassClrs, ...
%       ClassVals] = clusterize_points(xLonCoords, yLatCoords, Values, varargin)
%
% Dependencies: dbscan; mapping toolbox.
%   
% Outputs:
%   ClassInds: cell array containing the indices of the inputs that go in
%   the i-th cluster.
%   
%   ClassCrds: cell array containing the coordinates of the points that go
%   in the i-th cluster.
%   
%   ClassClrs: cell array containing the colors (randomly assigned) of the 
%   points that go in the i-th cluster.
%   
%   OutClssInds: cell array containing indices of points excluded from clusters.
%   
% Required arguments:
%   - xLonCoords : numeric array containing the longitudes of the points to
%   clusterize.
%   
%   - yLatCoords : numeric array containing the latitudes of the points to
%   clusterize.
%   
%   - Values : numeric array containing the values based on which clusterize 
%   the points. It is suggested to use probabilities of predictions.
%   
% Optional arguments:
%   - 'Threshold', numeric : is to declare the threshold to apply in order
%   to separate the values that must be clusterized from the on that must
%   not. By default is set to the minimum possible, which means that every
%   member of ValuesToClust will be considered. If threshold is specified,
%   then when a member of ValuesToClust is > than this threshold, that 
%   observation become part of points to clusterize.
%   
%   - 'EPSG', numeric : is to declare the EPSG code to use in order to
%   convert latitudes and longitudes in planar coordinates (necessary to
%   detect distances between points). By default is set to 25832.
%   
%   - 'SearchRadius', numeric : is to declare the radius (in meters) to use
%   while searching near points in creating clusters. By default is set to
%   the minimum distance between input points.
%   
%   - 'MinPopulation', numeric : is to declare the number of points that a
%   cluster must have as a minimum. If the cluster contains less than this
%   number, it will be removed. By defaults is set to 6.
%   
%   - 'RemovedClass', logical : is to declare if you want to maintain the
%   removed class (points that are not inside the clusters). By default is
%   set to false. In case is set to true, the removed class will be the
%   last one!

%% Preliminary check
if not(isnumeric(xLonCoords) && isnumeric(yLatCoords) && isnumeric(Values))
    error('All the first three inputs must be numeric!')
end

if not(isvector(xLonCoords) && isvector(yLatCoords) && isvector(Values))
    error('All the first three inputs must be vectors!')
end

if not(isequal(size(xLonCoords), size(yLatCoords), size(Values)))
    error('All the first three inputs must have the same size!')
end

%% Settings
Thrsh = min(Values); % Default
EPSGc = 25832;       % Default
SrRad = 0;           % Default
MnPop = 6;           % Default
RemCl = false;       % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputThrsh = find(cellfun(@(x) all(strcmpi(x, 'Threshold'    )), vararginCp));
    InputEPSGc = find(cellfun(@(x) all(strcmpi(x, 'EPSG'         )), vararginCp));
    InputSrRad = find(cellfun(@(x) all(strcmpi(x, 'SearchRadius' )), vararginCp));
    InputMnPop = find(cellfun(@(x) all(strcmpi(x, 'MinPopulation')), vararginCp));
    InputRemCl = find(cellfun(@(x) all(strcmpi(x, 'RemovedClass' )), vararginCp));

    if InputThrsh; Thrsh = varargin{InputThrsh+1}; end
    if InputEPSGc; EPSGc = varargin{InputEPSGc+1}; end
    if InputSrRad; SrRad = varargin{InputSrRad+1}; end
    if InputMnPop; MnPop = varargin{InputMnPop+1}; end
    if InputRemCl; RemCl = varargin{InputRemCl+1}; end

    varargin([ InputThrsh, InputThrsh+1, ...
               InputEPSGc, InputEPSGc+1, ...
               InputSrRad, InputSrRad+1, ...
               InputMnPop, InputMnPop+1, ...
               InputRemCl, InputRemCl+1 ]) = [];
    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(isnumeric(Thrsh) && isscalar(Thrsh))
    error('Threshold must be numeric and single!')
end

if not((isnumeric(EPSGc) && isscalar(EPSGc)) || isa(EPSGc, 'projcrs'))
    error('EPSG must be numeric and single (or projcrs object)!')
end

if not(isnumeric(SrRad) && isscalar(SrRad))
    error('SearchRadius must be numeric and single!')
end

if SrRad < 0
    error('SearchRadius must be greater than 0!')
end

if not(isnumeric(MnPop) && isscalar(MnPop))
    error('MinPopulation must be numeric and single!')
end

if not(islogical(RemCl) && isscalar(RemCl))
    error('RemovedClass must be logical and single!')
end

%% Core
if not(isa(EPSGc, 'projcrs'))
    ProjCRS = projcrs(EPSGc);
else
    ProjCRS = EPSGc;
end

[xPlanCoord, yPlanCoord] = projfwd(ProjCRS, yLatCoords, xLonCoords);

if SrRad == 0
    dyPln = mode(diff(unique(round(yPlanCoord))), 'all');
    dxPln = mode(diff(unique(round(xPlanCoord))), 'all');
    SrRad = sqrt((2*dyPln)^2+(2*dxPln)^2)*1.1;
end

IdPts2Cl = find(round(Values,4) >= Thrsh); % Indices referred to the database!

Clusters = dbscan([xPlanCoord(IdPts2Cl), ...
                   yPlanCoord(IdPts2Cl)], SrRad, MnPop); % Coordinates, min dist, min n. of point for each core point

IdRmPnts = (Clusters == -1);
ClassCln = unique(Clusters(not(IdRmPnts)));

if RemCl
    ClassCln(end+1) = -1; % Append the removed class!
end

[ClassInds, ClassCrds, ClassVals] = deal(cell(1, length(ClassCln)));
for i1 = 1:numel(ClassCln)
    ClassInds{i1} = IdPts2Cl( Clusters == ClassCln(i1) );
    ClassCrds{i1} = [xLonCoords(ClassInds{i1}), yLatCoords(ClassInds{i1})];
    ClassVals{i1} = Values(ClassInds{i1});
end

ClassClrs = arrayfun(@(x) rand(1, 3), ClassCln', 'UniformOutput',false);

end