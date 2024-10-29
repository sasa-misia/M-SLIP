function [Im] = fastscattergrid(Colors, xGrid, yGrid, varargin)
% FAST PLOT FOR GRID DATA
%   
% Outputs:
%   Im : Image object.
%   
% Required arguments:
%   - Colors : is a grid containing rgb colors (3D matrix: three 2D matrices 
%   concatenated in 3rd dim, containing R, G, and B; 2d matrix grid: a 2D 
%   matrix containing white values with same dim of xGrid). It could be also 
%   a 2D array nx3 or 3xn containing the R, G, and B values in 1st, 2nd, and 
%   3rd column (or row if 3xn). It could be also a 1D array, containing the
%   white values.
%   
%   - xGrid : is a grid containing the x coordinates. It could be 1D or 2D.
%   
%   - yGrid : is a grid containing the y coordinates. It could be 1D or 2D.
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
    SizeCheck = isequal(size(Colors, [1,2]), size(xGrid));
else
    SzCheck1  = isequal(size(Colors), size(xGrid));
    SzCheck2  = isequal(size(Colors, 1), numel(xGrid)); % In this case it must be resized!
    SzCheck3  = isequal(size(Colors, 2), numel(xGrid)); % In this case it must be resized!
    SizeCheck = SzCheck1 || SzCheck2 || SzCheck3;

    if SzCheck2 || SzCheck3 % Resize of Colors
        warning(['The color is an nx3, nx1, 3xn, or 1xn ' ...
                 'array and it will be resized in grid format!'])

        % Conversion in vertical array
        if SzCheck3
            Colors = Colors';
        end

        % Conversion in nx3
        if size(Colors, 2) == 1
            Colors = repmat(Colors, 1, 3);
        end

        % Check of dims
        if size(Colors, 2) ~= 3
            error(['First argument was written as a 2D or 1D array but it was ' ...
                   'not nx3, nx1, 3xn, or 1xn, where n is the number of pixels.'])
        end

        Colors = cat(3, reshape(Colors(:,1), size(xGrid)), ...
                        reshape(Colors(:,2), size(xGrid)), ...
                        reshape(Colors(:,3), size(xGrid)));
    end
end
if not( SizeCheck && CrdsCheck )
    error('Sizes of first 3 inputs must be identical (for 3d color matrix just first 2 dims)!')
end

if max(Colors, [], 'all') > 255 || max(Colors, [], 'all') < 0
    error('First argument, containing colors, is our of range (0 - 255)!')
end
if max(Colors, [], 'all') <= 1
    Colors = Colors.*255; % Conversion in standard RGB (0 - 255)
end

%% Settings
PolMask = [];  % Default
AlphaIm = 1;   % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputParent = find(cellfun(@(x) all(strcmpi(x, "parent")), vararginCp));
    InputPolMsk = find(cellfun(@(x) all(strcmpi(x, "mask"  )), vararginCp));
    InputAlpha  = find(cellfun(@(x) all(strcmpi(x, "alpha" )), vararginCp));

    if InputParent; CurrAxs = varargin{InputParent+1}; end
    if InputPolMsk; PolMask = varargin{InputPolMsk+1}; end
    if InputAlpha ; AlphaIm = varargin{InputAlpha+1 }; end
end

if not(exist('CurrAxs', 'var'))
    CurrFig = figure();      % Default
    CurrAxs = axes(CurrFig); % Default
end

%% Core
if not(isempty(PolMask))
    if not(isa(PolMask,'polyshape')); error('Mask must be a polyshape!'); end

    if numel(PolMask) > 1; PolMask = union(PolMask); end

    [pp1, ee1]   = getnan2([PolMask.Vertices; nan, nan]);
    IndPntsInMsk = find(inpoly([xGrid(:), yGrid(:)], pp1, ee1)==1);
else
    IndPntsInMsk = find(true(numel(xGrid), 1));
end

ColorsArr = double(reshape(Colors(:), [size(Colors,1)*size(Colors,2), 3]));
[RedTemp, GreenTemp, BlueTemp] = deal(ones(numel(xGrid), 1)); % This means that they start as white pixels.
RedTemp(IndPntsInMsk)   = ColorsArr(IndPntsInMsk, 1)./255;
GreenTemp(IndPntsInMsk) = ColorsArr(IndPntsInMsk, 2)./255;
BlueTemp(IndPntsInMsk)  = ColorsArr(IndPntsInMsk, 3)./255;

Colors2Plot    = zeros(size(xGrid, 1), size(xGrid, 2), 3); % This means that they start as black pixels -> check if an area is black outside StudyArea (error).
Colors2Plot(:) = [RedTemp; GreenTemp; BlueTemp];

Im = imagesc(CurrAxs, xGrid(:), yGrid(:), Colors2Plot, 'AlphaData',AlphaIm);

end