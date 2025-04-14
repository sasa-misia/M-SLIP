function [imOut] = fastscattergrid(colors2Use, xGrid, yGrid, Options)
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
%   black values.
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
%   
%   - 'ColorMap', string/char: the name of the colorbar to use in case of
%   1d vector in Colors

%% Arguments
arguments
    colors2Use (:,:,:) double
    xGrid (:,:) double
    yGrid (:,:) double
    Options.Parent (1,1) matlab.graphics.axis.Axes
    Options.Mask (1,1) polyshape
    Options.Alpha (1,1) double = 1 % Default
    Options.ColorMap (1,:) char = 'gray'
end

if isfield(Options, 'Parent')
    currAxs = Options.Parent; % Default
else
    currFig = figure();      % Default
    currAxs = axes(currFig); % Default
end

polMask = []; % Default
if isfield(Options, 'Mask')
    polMask = Options.Mask;
end

alphaIm = Options.Alpha;

colMap = lower(Options.ColorMap);

%% Input Check
if not( isnumeric(colors2Use) && isnumeric(xGrid) && isnumeric(yGrid) )
    WrongInp = find([not(ismatrix(colors2Use)), not(ismatrix(xGrid)), not(ismatrix(yGrid))]);
    error(['Input ',num2str(WrongInp),' must be numeric matrices!'])
end

clrWasWht = false;
dimInpClr = ndims(colors2Use);
crdsCheck = isequal(size(xGrid), size(yGrid));
if dimInpClr == 3
    sizeCheck = isequal(size(colors2Use, [1,2]), size(xGrid));
else
    clrWasWht = true;
    
    szCheck1  = isequal(size(colors2Use), size(xGrid));
    szCheck2  = isequal(size(colors2Use, 1), numel(xGrid)); % In this case it must be resized!
    szCheck3  = isequal(size(colors2Use, 2), numel(xGrid)); % In this case it must be resized!
    sizeCheck = szCheck1 || szCheck2 || szCheck3;

    if szCheck1
        colors2Use = repmat(colors2Use, 1, 1, 3); % R G B (also if it was just white band)
    end

    if szCheck2 || szCheck3 % Resize of Colors
        % warning(['The color is an nx3, nx1, 3xn, or 1xn ' ...
        %          'array and it will be resized in grid format!'])

        % Conversion in vertical array
        if szCheck3
            colors2Use = colors2Use';
        end

        % Conversion in nx3
        if size(colors2Use, 2) == 1
            colors2Use = repmat(colors2Use, 1, 3);
        end

        % Check of dims
        if size(colors2Use, 2) ~= 3
            error(['First argument was written as a 2D or 1D array but it was ' ...
                   'not nx3, nx1, 3xn, or 1xn, where n is the number of pixels.'])
        end

        colors2Use = cat(3, reshape(colors2Use(:,1), size(xGrid)), ...
                            reshape(colors2Use(:,2), size(xGrid)), ...
                            reshape(colors2Use(:,3), size(xGrid)));
    end
end
if not( sizeCheck && crdsCheck )
    error('Sizes of first 3 inputs must be identical (for 3d color matrix just first 2 dims)!')
end

if max(colors2Use, [], 'all') > 255 || max(colors2Use, [], 'all') < 0
    error('First argument, containing colors, is our of range (0 - 255)!')
end
if max(colors2Use, [], 'all') <= 1
    colors2Use = colors2Use.*255; % Conversion in standard RGB (0 - 255)
end

if not(any(strcmp(colMap, {'pink', 'gray', 'sky', 'copper', 'bone', 'spring', 'cool', 'parula', 'summer', 'autumn', 'winter'})))
    error('ColorMap not recognized!')
end

if clrWasWht
    possCl = eval([colMap,'(100);']).*255;
    colInd = 100 - int64(rescale(reshape(colors2Use(:,:,1), numel(colors2Use(:,:,1)), 1), 1, 100, 'InputMax',255, 'InputMin',0)) + 1; % 100- x + 1 because colors must be reversed! (1 means black -> highest value, 0 means white -> lowest value)
    colors2Use(:,:,1) = reshape(possCl(colInd, 1), size(xGrid));
    colors2Use(:,:,2) = reshape(possCl(colInd, 2), size(xGrid));
    colors2Use(:,:,3) = reshape(possCl(colInd, 3), size(xGrid));
end

%% Core
if not(isempty(polMask))
    if not(isa(polMask,'polyshape')); error('Mask must be a polyshape!'); end

    if numel(polMask) > 1; polMask = union(polMask); end

    [pp1, ee1]   = getnan2([polMask.Vertices; nan, nan]);
    indPntsInMsk = find(inpoly([xGrid(:), yGrid(:)], pp1, ee1)==1);
else
    indPntsInMsk = find(true(numel(xGrid), 1));
end

colorsArr = double(reshape(colors2Use(:), [size(colors2Use,1)*size(colors2Use,2), 3]));
[redTemp, greenTemp, blueTemp] = deal(ones(numel(xGrid), 1)); % This means that they start as white pixels.
redTemp(indPntsInMsk)   = colorsArr(indPntsInMsk, 1)./255;
greenTemp(indPntsInMsk) = colorsArr(indPntsInMsk, 2)./255;
blueTemp(indPntsInMsk)  = colorsArr(indPntsInMsk, 3)./255;

colors2Plot    = zeros(size(xGrid, 1), size(xGrid, 2), 3); % This means that they start as black pixels -> check if an area is black outside StudyArea (error).
colors2Plot(:) = [redTemp; greenTemp; blueTemp];

imOut = imagesc(currAxs, xGrid(:), yGrid(:), colors2Plot, 'AlphaData',alphaIm);

end