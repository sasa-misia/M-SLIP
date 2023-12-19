function [Im] = fastscattergrid(Colors, xGrid, yGrid, varargin)
% CREATE POLYGONS OF UNSTABLE, STABLE, AND INDECISION AREAS
%   
% Outputs:
%   Im : Image object.
%   
% Required arguments:
%   - Colors : is a grid containing rgb colors (3d matrix, whith the third
%   containing respectively the R, G, and B). It could be also just a 2d
%   grid, containing a single value.
%   
%   - xGrid : is a grid containing rgb colors (3d matrix, whith the third
%   containing respectively the R, G, and B). It could be also just a 2d
%   grid, containing a single value.
%   
% Optional arguments:
%   - 'Parent', axes object: axes where the image is plotted.
%   
%   - 'Mask', polyshape: the polyshape that represent the mask of the image.
%   outside this polyshape, there is no color (white).
%   
%   - 'Alpha', num: a number between > 0 and < 1 that represent the opacity
%   of the image. If no value is specified, then 1 will be take as default.

%% Input Check
if not( isnumeric(Colors) && isnumeric(xGrid) && isnumeric(yGrid) )
    WrongInp = find([not(ismatrix(Colors)), not(ismatrix(xGrid)), not(ismatrix(yGrid))]);
    error(['Input ',num2str(WrongInp),' must be numeric matrices!'])
end

DimInpClr = ndims(Colors);
CrdsCheck = isequal(size(xGrid), size(yGrid));
if DimInpClr == 3
    ClrCheck = isequal(size(Colors, [1,2]), size(xGrid));
else
    ClrCheck = isequal(size(Colors), size(xGrid)); 
end
if not( ClrCheck && CrdsCheck )
    error('Sizes of first 3 inputs must be identical (for 3d color matrix just first 2 dims)!')
end

%% Settings
curr_ax = gca; % Default
PolMask = [];  % Default
AlphaIm = 1;   % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputParent = find(cellfun(@(x) all(strcmpi(x, "parent")), vararginCp));
    InputPolMsk = find(cellfun(@(x) all(strcmpi(x, "mask"  )), vararginCp));
    InputAlpha  = find(cellfun(@(x) all(strcmpi(x, "alpha" )), vararginCp));

    if InputParent; curr_ax = varargin{InputParent+1}; end
    if InputPolMsk; PolMask = varargin{InputPolMsk+1}; end
    if InputAlpha ; AlphaIm = varargin{InputAlpha+1 }; end
end

%% Core
switch DimInpClr
    case 1 % Create a separate function to convert from 1d to 2d in a regular grid!
        error('Not yet implemenyted!')

    case 2
        error('Not yet implemenyted!')

    case 3

    otherwise
        error('Dimensions of input not recognized!')
end

if not(isempty(PolMask))
    if numel(PolMask) > 1; PolMask = union(PolMask); end

    [pp1, ee1]   = getnan2([PolMask.Vertices; nan, nan]);
    IndPntsInMsk = find(inpoly([xGrid(:), yGrid(:)], pp1, ee1)==1);

    if DimInpClr == 3
        ColorsArr = double(reshape(Colors(:), [size(Colors,1)*size(Colors,2), 3]));
        [RedTemp, GreenTemp, BlueTemp] = deal(ones(numel(xGrid), 1)); % This means that they start as white pixels.
        RedTemp(IndPntsInMsk)   = ColorsArr(IndPntsInMsk, 1)./255;
        GreenTemp(IndPntsInMsk) = ColorsArr(IndPntsInMsk, 2)./255;
        BlueTemp(IndPntsInMsk)  = ColorsArr(IndPntsInMsk, 3)./255;
    
        Colors2Plot    = zeros(size(xGrid, 1), size(xGrid, 2), 3); % This means that they start as black pixels -> check if an area is black outside StudyArea (error).
        Colors2Plot(:) = [RedTemp; GreenTemp; BlueTemp];
    else
        error('Not yet implemenyted!')
    end

    Im = imagesc(curr_ax, xGrid(:), yGrid(:), Colors2Plot, 'AlphaData',AlphaIm);
end

end