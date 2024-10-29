function [varargout] = pixelsize(StudyAreaPolygon, varargin)

% RETURN THE CORRECT PIXEL SIZE TO PLOT
%   
% Outputs:
%   [PixelSize]
%   or
%   [PixelSize, InfoDetPixelSize]
%   
% Required arguments:
%   - StudyAreaPolygon : the polyshape object containing your study area!
% 
% Optional arguments:
%   - 'RefArea', num : is to specify the area of the reference polygon. If 
%   no value is specified, then 0.0417 will be take as default.
%   
%   - 'Extremes', logical : is to specify if you want to use just the pure
%   product of the extremes instead of the area of the polygon. If no value 
%   is specified, then 'false' will be take as default.
%   
%   - 'FinScale', num : is to specify the final scale of the pixel. If no 
%   value is specified, then 0.028 will be take as default.
%   
%   - 'FixedDetSize', logical : is to specify if you want a fixed size for
%   detected points. If no value is selected, then 'true' will be take as
%   default. If setted to 'true', 'DetScale' will be ignored and the final
%   size is 50 px.
%   
%   - 'DetPxSize', num : is to specify the ratio between the normal pixels 
%   and the pixels of the detected landslides when 'FixedDetSize' is set to 
%   'false'. When 'FixedDetSize' is set to 'true', this value is the absolute 
%   value of det pixel size. If no value is specified, then 15 will be take 
%   as default.

%% Settings
RefStudyArea = .0417; % Default
UseJustExtr  = false; % Default
FinalScale   = .028;  % Default
DetectPxSize = 15;    % Default
FixedDetSize = true;  % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputRefArea = find(cellfun(@(x) all(strcmpi(x, "refarea"     )), vararginCp));
    InputUseExtr = find(cellfun(@(x) all(strcmpi(x, "extremes"    )), vararginCp));
    InputFnlScl  = find(cellfun(@(x) all(strcmpi(x, "finscale"    )), vararginCp));
    InputDetPxSz = find(cellfun(@(x) all(strcmpi(x, "detpxsize"   )), vararginCp));
    InputFixdSzs = find(cellfun(@(x) all(strcmpi(x, "fixeddetsize")), vararginCp));

    if InputRefArea; RefStudyArea = varargin{InputRefArea+1}; end
    if InputUseExtr; UseJustExtr  = varargin{InputUseExtr+1}; end
    if InputFnlScl ; FinalScale   = varargin{InputFnlScl+1 }; end
    if InputDetPxSz; DetectPxSize = varargin{InputDetPxSz+1}; end
    if InputFixdSzs; FixedDetSize = varargin{InputFixdSzs+1}; end
end

%% Processing
ExtStudyArea = area(StudyAreaPolygon);

if UseJustExtr
    MaxExtremes  = max(StudyAreaPolygon.Vertices);
    MinExtremes  = min(StudyAreaPolygon.Vertices);
    ExtStudyArea = prod(MaxExtremes-MinExtremes);
end

RatioRef = ExtStudyArea/RefStudyArea;
varargout{1} = FinalScale/RatioRef;
if FixedDetSize
    varargout{2} = DetectPxSize;
else
    varargout{2} = DetectPxSize*varargout{1};
end

end