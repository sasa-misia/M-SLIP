function [pixelSize, infoDetSize] = pixelsize(studyAreaPolygon, Options)

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
%   value of det pixel size. If no value is specified, then 10 will be take 
%   as default.

arguments
    studyAreaPolygon (1,1) polyshape
    Options.RefArea (1,1) double = .0417; % Default
    Options.Extremes (1,1) logical = false; % Default
    Options.FinScale (1,1) double = .028; % Default
    Options.FixedDetSize (1,1) logical = true; % Default
    Options.DetPxSize (1,1) double = 10; % Default
end

%% Settings
refStudyArea = Options.RefArea;
useJustExtr  = Options.RefArea;
finalScale   = Options.FinScale;
detectPxSize = Options.DetPxSize;
fixedDetSize = Options.FixedDetSize;

%% Processing
ExtStudyArea = area(studyAreaPolygon);

if useJustExtr
    MaxExtremes  = max(studyAreaPolygon.Vertices);
    MinExtremes  = min(studyAreaPolygon.Vertices);
    ExtStudyArea = prod(MaxExtremes-MinExtremes);
end

RatioRef = ExtStudyArea/refStudyArea;
pixelSize = finalScale/RatioRef;
if fixedDetSize
    infoDetSize = detectPxSize;
else
    infoDetSize = detectPxSize*pixelSize;
end

end