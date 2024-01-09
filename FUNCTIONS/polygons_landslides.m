function [varargout] = polygons_landslides(fold0, varargin)

% CREATE POLYGONS OF UNSTABLE, STABLE, AND INDECISION AREAS
%   
% Outputs:
%   [PolygonUnstable, PolygonStable]
%   or
%   [PolygonUnstable, PolygonStable, PolygonIndecision]
%   or
%   [PolygonUnstable, PolygonStable, PolygonIndecision, BufferSizes]
%   or
%   [PolygonUnstable, PolygonStable, PolygonIndecision, BufferSizes, GrossPoligonsMaxBuffer]
%   
% Required arguments:
%   - fold0 : is to identify the folder in which you have the analysis.
%   
%   - 'StableMode', string : is to specify what modality do you want to use
%   for defining the stable part of the study area. Possible string values 
%   are 'Buffer', 'AllOutside'. If no value is specified, then 'Buffer' will
%   be take as default.
%   
%   - 'UnstableMode', string : is to specify how you want to define unstable
%   polygons. Possible string values are 'ManualSquares', 'PolygonsOfInfoDetected'.
%   If no value is specified, then 'ManualSquares' will be take as default.
%   
% Optional arguments:
%   - 'BufferSizes', numericalArray : is to specify sizes for buffered polys.
%   This array should be specified in different ways. When StableMode is 
%   'Buffer'and UnstableMode is set to 'PolygonsOfInfoDetected', must be
%   1x2 with  (buffer size for indecision and buffer size for max extent of 
%   stable part); 1x3 with 'ManualSquares' (size of square side for unstable, 
%   size of square for indecision, and size for max extent of stable part).
%   When StableMode is set to 'AllOutside', value must be 1x1 (size of buffer 
%   for indecision). If no value is specified, then a prompt will appear and 
%   ask you for these sizes.
%   
%   - 'CreationCoordinates', string : is to specify if you want to create
%   polygons with geographic coordinates or planar coordinates. Possible 
%   string values are 'Geographic' or 'Planar'. If no value is specified, 
%   then 'Planar' will be take as default.
%   
%   - 'PolyOutputMode', string : is to specify if you want a single merged
%   polygon or a multipoligon array. Possible string values are 'Merged' or 
%   'Multi'. If no value is specified, then 'Multi' will be take as default.
%   
%   - 'IndOfInfoDetToUse', num : is to specify the index of InfoDetectedSoilSlip
%   you want to use in creating polygons. If no value is specified, then a
%   prompt will appear and ask you to select one of the possibles (or the
%   first will be taken automatically in case you have only one)

%% Settings initialization
StableMode   = "buffer"; % Default
UnstableMode = "manual"; % Default
CreateCoords = "planar"; % Default
PolyOutMode  = "multi";  % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(StringPart) = varargin(StringPart);

    InputStableMode   = find(cellfun(@(x) strcmpi(x, "stablemode"),          vararginCopy));
    InputUnstableMode = find(cellfun(@(x) strcmpi(x, "unstablemode"),        vararginCopy));
    InputBufferSizes  = find(cellfun(@(x) strcmpi(x, "buffersizes"),         vararginCopy));
    InputCreateCoords = find(cellfun(@(x) strcmpi(x, "creationcoordinates"), vararginCopy));
    InputPolyOutMode  = find(cellfun(@(x) strcmpi(x, "polyoutputmode"),      vararginCopy));
    InputIndInfoToUse = find(cellfun(@(x) strcmpi(x, "indofinfodettouse"),   vararginCopy));

    if InputStableMode;   StableMode   = varargin{InputStableMode+1};   end
    if InputUnstableMode; UnstableMode = varargin{InputUnstableMode+1}; end
    if InputBufferSizes;  BufferSizes  = varargin{InputBufferSizes+1};  end
    if InputCreateCoords; CreateCoords = varargin{InputCreateCoords+1}; end
    if InputPolyOutMode;  PolyOutMode  = varargin{InputPolyOutMode+1};  end
    if InputIndInfoToUse; IndInfoToUse = varargin{InputIndInfoToUse+1}; end
end

%% Loading files
if ispc; sl = '\'; elseif ismac; sl = '/'; else; error('Platform not supported'); end
load([fold0,sl,'os_folders.mat'], 'fold_var')
load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','SubArea','FilesDetectedSoilSlip')
if strcmp(StableMode, "alloutside")
    load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon')
end

if length(FilesDetectedSoilSlip) == 1
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{1};
    IndInfoToUse = 1;
elseif exist('IndInfoToUse', 'var')
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndInfoToUse};
else
    IndInfoToUse = listdlg2({'Choose dataset you want to use to define polygons: '}, FilesDetectedSoilSlip, 'OutType','NumInd');
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndInfoToUse};
end

load([fold_var,sl,'MorphologyParameters.mat'], 'OriginallyProjected','SameCRSForAll')
if OriginallyProjected && SameCRSForAll
    load([fold_var,sl,'MorphologyParameters.mat'], 'OriginalProjCRS')
    ProjCRS = OriginalProjCRS;
else
    EPSG    = str2double(inputdlg2({['DTM EPSG for polygon creation (Sicily -> 32633; ' ...
                                     'Emilia Romagna -> 25832']}, 'DefInp',{'25832'}));
    ProjCRS = projcrs(EPSG);
end

%% Creation of positive points (landslide occurred)
switch UnstableMode
    case "polygonsofinfodetected"
        %% Procedure with polygons created in InfoDetectedSoilSlips
        load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlipsAverage')

        if not(exist('BufferSizes', 'var'))
            PromptBuffer = ["Size of the buffer to define indecision area [m]"
                            "Size of the buffer to define stable area [m]"    ];
            SuggBuffVals = {'50', '250'};

            if strcmp(StableMode, "alloutside")
                PromptBuffer(2) = [];
                SuggBuffVals(2) = [];
            end

            BufferSizes = str2double(inputdlg(PromptBuffer, '', 1, SuggBuffVals));
        end

        if not(SubArea)
            error('You have chosed to use polygons in InfoDetectedSoilSlips but no polygon was created into it!')
        end

        BufferIndecision = BufferSizes(1);

        UnstablePolys = InfoDetectedSoilSlipsAverage{IndInfoToUse}{1};
        clear('InfoDetectedSoilSlipsAverage')

        [UnstabPolysCoordPlanX, UnstabPolysCoordPlanY] = arrayfun(@(x) projfwd(ProjCRS,x.Vertices(:,2),x.Vertices(:,1)), UnstablePolys, 'UniformOutput',false);
        UnstablePolysPlan = cellfun(@(x,y) polyshape(x,y, 'Simplify',false), UnstabPolysCoordPlanX, UnstabPolysCoordPlanY); % This conversion is necessary because otherwise buffer is not correct (Long is different from Lat)
        IndecisionPolysGrossPlan = polybuffer(UnstablePolysPlan, BufferIndecision);

        [IndecPolysGrossLat, IndecPolysGrossLong] = arrayfun(@(x) projinv(ProjCRS,x.Vertices(:,1),x.Vertices(:,2)), ...
                                                                        IndecisionPolysGrossPlan, 'UniformOutput',false);

        IndecisionPolysGross = cellfun(@(x,y) polyshape(x,y, 'Simplify',false), IndecPolysGrossLong, IndecPolysGrossLat);
        
        if strcmp(StableMode, "buffer")
            BufferMaxExt = BufferSizes(2);
            StablePolysGrossPlan = polybuffer(UnstablePolysPlan, BufferMaxExt);
            [StablePolysLat, StablePolysLong] = arrayfun(@(x) projinv(ProjCRS,x.Vertices(:,1),x.Vertices(:,2)), ...
                                                            StablePolysGrossPlan, 'UniformOutput',false);
            StablePolysGross = cellfun(@(x,y) polyshape(x,y, 'Simplify',false), StablePolysLong, StablePolysLat);
        end

    case {"manualsquares", "manual"}
        %% Manual procedure for creatings polygons (squares)
        if not(exist('BufferSizes', 'var'))
            PromptBuffer = ["Size of the window side where are located unstable points"
                            "Size of the window side to define indecision area"
                            "Size of the window side to define stable area"            ];
            SuggBuffVals = {'45', '200', '300'};

            if strcmp(StableMode, "alloutside")
                PromptBuffer(3) = [];
                SuggBuffVals(3) = [];
            end

            BufferSizes = str2double(inputdlg2(PromptBuffer, 'DefInp',SuggBuffVals));
        end
      
        switch CreateCoords
            case "geographic"
                yLatMean = mean(InfoDetectedSoilSlipsToUse{:,6});

                % Polygons around detected soil slips (you will attribute certain event)
                SideUnstabPolys   = BufferSizes(1); % This is the size in meters around the detected soil slip
                dLatUnstPoints    = rad2deg(SideUnstabPolys/2/earthRadius); % /2 to have half of the size from the centre
                dLongUnstPoints   = rad2deg(acos( (cos(SideUnstabPolys/2/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % /2 to have half of the size from the centre
                BoundsUnstabPolys = [cellfun(@(x) x-dLongUnstPoints, InfoDetectedSoilSlipsToUse(:,5)), ...
                                     cellfun(@(x) x-dLatUnstPoints,  InfoDetectedSoilSlipsToUse(:,6)), ...
                                     cellfun(@(x) x+dLongUnstPoints, InfoDetectedSoilSlipsToUse(:,5)), ...
                                     cellfun(@(x) x+dLatUnstPoints,  InfoDetectedSoilSlipsToUse(:,6))];
                
                % Polygons around detected soil slips (polygon where you are uncertain because landslide could be greater than 45x45)
                SideIndecisionPolys = BufferSizes(2); % This is the size in meters around the detected soil slip
                dLatIndecPoints     = rad2deg(SideIndecisionPolys/2/earthRadius); % /2 to have half of the size from the centre
                dLongIndecPoints    = rad2deg(acos( (cos(SideIndecisionPolys/2/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % /2 to have half of the size from the centre
                BoundsIndecPolys    = [cellfun(@(x) x-dLongIndecPoints, InfoDetectedSoilSlipsToUse(:,5)), ...
                                       cellfun(@(x) x-dLatIndecPoints,  InfoDetectedSoilSlipsToUse(:,6)), ...
                                       cellfun(@(x) x+dLongIndecPoints, InfoDetectedSoilSlipsToUse(:,5)), ...
                                       cellfun(@(x) x+dLatIndecPoints,  InfoDetectedSoilSlipsToUse(:,6))];
                
                if strcmp(StableMode, "buffer")
                    % Polygons around detected soil slips (max polygon visible by human)
                    SideStablePolys   = BufferSizes(3); % This is the size in meters around the detected soil slip
                    dLatStabPoints    = rad2deg(SideStablePolys/2/earthRadius); % /2 to have half of the size from the centre
                    dLongStabPoints   = rad2deg(acos( (cos(SideStablePolys/2/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % /2 to have half of the size from the centre
                    BoundsStablePolys = [cellfun(@(x) x-dLongStabPoints, InfoDetectedSoilSlipsToUse(:,5)), ...
                                         cellfun(@(x) x-dLatStabPoints,  InfoDetectedSoilSlipsToUse(:,6)), ...
                                         cellfun(@(x) x+dLongStabPoints, InfoDetectedSoilSlipsToUse(:,5)), ...
                                         cellfun(@(x) x+dLatStabPoints,  InfoDetectedSoilSlipsToUse(:,6))];
                end
        
            case "planar"
                InfoDetectedSoilSlipsToUsePlan = zeros(size(InfoDetectedSoilSlipsToUse,1), 2);    
                [InfoDetectedSoilSlipsToUsePlan(:,1), InfoDetectedSoilSlipsToUsePlan(:,2)] = ...
                                projfwd(ProjCRS, [InfoDetectedSoilSlipsToUse{:,6}]', [InfoDetectedSoilSlipsToUse{:,5}]');
                InfoDetectedSoilSlipsToUsePlan = num2cell(InfoDetectedSoilSlipsToUsePlan);
        
                % Polygons around detected soil slips (you will attribute certain event)
                SideUnstabPolys       = BufferSizes(1); % This is the size in meters around the detected soil slip
                dXUnstPoints          = SideUnstabPolys/2; % /2 to have half of the size from the centre
                dYUnstPoints          = dXUnstPoints;
                BoundsUnstabPolysPlan = [cellfun(@(x) x-dXUnstPoints, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                         cellfun(@(x) x-dYUnstPoints, InfoDetectedSoilSlipsToUsePlan(:,2)), ...
                                         cellfun(@(x) x+dXUnstPoints, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                         cellfun(@(x) x+dYUnstPoints, InfoDetectedSoilSlipsToUsePlan(:,2))];
                [BoundsUnstabPolys(:,2), BoundsUnstabPolys(:,1)] = projinv(ProjCRS, BoundsUnstabPolysPlan(:,1), BoundsUnstabPolysPlan(:,2));
                [BoundsUnstabPolys(:,4), BoundsUnstabPolys(:,3)] = projinv(ProjCRS, BoundsUnstabPolysPlan(:,3), BoundsUnstabPolysPlan(:,4));
                
                % Polygons around detected soil slips (polygon where you are uncertain because landslide could be greater than 45x45)
                SideIndecisionPolys  = BufferSizes(2); % This is the size in meters around the detected soil slip
                dXIndecPoints        = SideIndecisionPolys/2; % /2 to have half of the size from the centre
                dYIndecPoints        = dXIndecPoints;
                BoundsIndecPolysPlan = [cellfun(@(x) x-dXIndecPoints, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                        cellfun(@(x) x-dYIndecPoints, InfoDetectedSoilSlipsToUsePlan(:,2)), ...
                                        cellfun(@(x) x+dXIndecPoints, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                        cellfun(@(x) x+dYIndecPoints, InfoDetectedSoilSlipsToUsePlan(:,2))];
                [BoundsIndecPolys(:,2), BoundsIndecPolys(:,1)] = projinv(ProjCRS, BoundsIndecPolysPlan(:,1), BoundsIndecPolysPlan(:,2));
                [BoundsIndecPolys(:,4), BoundsIndecPolys(:,3)] = projinv(ProjCRS, BoundsIndecPolysPlan(:,3), BoundsIndecPolysPlan(:,4));
                
                if strcmp(StableMode, "buffer")
                    % Polygons around detected soil slips (max polygon visible by human)
                    SideStablePolys       = BufferSizes(3); % This is the size in meters around the detected soil slip
                    dXStabPoints          = SideStablePolys/2; % /2 to have half of the size from the centre
                    dYStabPoints          = dXStabPoints;
                    BoundsStablePolysPlan = [cellfun(@(x) x-dXStabPoints, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                             cellfun(@(x) x-dYStabPoints, InfoDetectedSoilSlipsToUsePlan(:,2)), ...
                                             cellfun(@(x) x+dXStabPoints, InfoDetectedSoilSlipsToUsePlan(:,1)), ...
                                             cellfun(@(x) x+dYStabPoints, InfoDetectedSoilSlipsToUsePlan(:,2))];
                    [BoundsStablePolys(:,2), BoundsStablePolys(:,1)] = projinv(ProjCRS, BoundsStablePolysPlan(:,1), BoundsStablePolysPlan(:,2));
                    [BoundsStablePolys(:,4), BoundsStablePolys(:,3)] = projinv(ProjCRS, BoundsStablePolysPlan(:,3), BoundsStablePolysPlan(:,4));
                end
        end
        
        % Polygons around detected soil slips (you will attribute certain event)
        UnstablePolys = arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]), ...
                                                     BoundsUnstabPolys(:,1), ...
                                                     BoundsUnstabPolys(:,3), ...
                                                     BoundsUnstabPolys(:,2), ...
                                                     BoundsUnstabPolys(:,4));
        
        % Polygons around detected soil slips (polygon where you are uncertain because landslide could be greater than 45x45)
        IndecisionPolysGross = arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]), ...
                                                                 BoundsIndecPolys(:,1), ...
                                                                 BoundsIndecPolys(:,3), ...
                                                                 BoundsIndecPolys(:,2), ...
                                                                 BoundsIndecPolys(:,4));

        if strcmp(StableMode, "buffer")
            % Polygons around detected soil slips (max polygon visible by human)
            StablePolysGross = arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]), ...
                                                         BoundsStablePolys(:,1), ...
                                                         BoundsStablePolys(:,3), ...
                                                         BoundsStablePolys(:,2), ...
                                                         BoundsStablePolys(:,4));
        end
end

%% Union and subtraction of polygons
UnstablePolysMerged   = union(UnstablePolys);
IndecisionPolysGross  = union(IndecisionPolysGross);
if strcmp(StableMode, "alloutside")
    StablePolysGrossMerged = StudyAreaPolygon;
else
    StablePolysGrossMerged = union(StablePolysGross);
end
IndecisionPolysMerged = subtract(IndecisionPolysGross, UnstablePolysMerged);
StablePolysMerged     = subtract(StablePolysGrossMerged, IndecisionPolysGross);

%% Separation of polygons
StablePolysSplit = regions(StablePolysMerged);
StablePolysGrossSplit = rmholes(StablePolysSplit);

% % Old technique
% IndexOfNans = find(isnan(StablePolysMerged.Vertices(:,1)));
% EndOfExtPolygons = IndexOfNans(StablePolysMerged.NumRegions);
% [StablePolysSplitLong, StablePolysSplitLat] = polysplit(StablePolysMerged.Vertices(1:EndOfExtPolygons,1), StablePolysMerged.Vertices(1:EndOfExtPolygons,2));
% StablePolysGrossSplit = cellfun(@(x, y) polyshape(x, y), StablePolysSplitLong, StablePolysSplitLat, 'UniformOutput',false);
% 
% StablePolysSplit = cellfun(@(x) intersect(x, StablePolysMerged), ...
%                                      StablePolysGrossSplit, 'UniformOutput',false);

if strcmp(StableMode, "alloutside")
    IndecisionPolysSplit = regions(IndecisionPolysMerged);
    IndecPolysGrossSplit = rmholes(IndecisionPolysSplit);
    UnstablePolysSplit   = arrayfun(@(x) intersect(x, UnstablePolysMerged),   IndecPolysGrossSplit);
else
    IndecisionPolysSplit = arrayfun(@(x) intersect(x, IndecisionPolysMerged), StablePolysGrossSplit);
    UnstablePolysSplit   = arrayfun(@(x) intersect(x, UnstablePolysMerged),   StablePolysGrossSplit);
end

%% Outputs assignment
if strcmp(PolyOutMode, "merged")
    varargout{1} = UnstablePolysMerged;
    varargout{2} = StablePolysMerged;
    varargout{3} = IndecisionPolysMerged;
    varargout{5} = StablePolysGrossMerged;
elseif strcmp(PolyOutMode, "multi")
    varargout{1} = UnstablePolysSplit;
    varargout{2} = StablePolysSplit;
    varargout{3} = IndecisionPolysSplit;
    varargout{5} = StablePolysGrossSplit;
end

varargout{4} = BufferSizes;

end