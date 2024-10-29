function [polyOut, polyClass] = polyshapes_from_shapefile(filePath, fieldName, Options)

% Purpose: function to extract polyshapes from a ESRI shapefile
% 
% Outputs: 
%       - polyOut     = [polyshape array]
%       - polyClass   = [cellstr]
% 
% Inputs:
%       - filePath    = [char] the full filename of the shapefile.
%       - fieldName   = [char] char or string containing the name of the 
%                       field to use when grouping polygons.
% 
% Optional inputs:
%       - polyBound   = [polyshape] the polyshape containing the counding box
%                       to use. It limits the reading of the file and it can
%                       be used as mask for the created polygons.
%       - maskOutPoly = [logical] if set to true, the polyOut will be masked 
%                       by polyBound, otherwise, no masking but raw polygons.
%       - extraBound  = [double] the extra boundary to apply during reading.
%       - pointsLim   = [double] the maximum limit of points for polygons.
%                       If the polygon exceeds this limit, it will be deleted.
%       - progDialog  = [matlab.ui.dialog.ProgressDialog] the progress bar 
%                       object that can be used to monitoring reading.
% 
% Dependencies: meters2lonlat and inputdlg2 (M-SLIP), MATLAB Mapping Toolbox

arguments
    filePath (1,:) char {mustBeFile}
    fieldName (1, :) char
    Options.polyBound (1,1) polyshape = polyshape()
    Options.maskOutPoly (1,1) logical = true
    Options.extraBound (1,1) double = 1000 % in meters!
    Options.pointsLim (1,1) double = 80000
    Options.progDialog = []
end

polyBound   = Options.polyBound;
maskOutPoly = Options.maskOutPoly;
extraBound  = Options.extraBound;
pointsLim   = Options.pointsLim;
progDialog  = Options.progDialog;

progExist = isa(progDialog, 'matlab.ui.dialog.ProgressDialog');
if not(isempty(progDialog)) && not(progExist)
    error('progDialog must be a matlab.ui.dialog.ProgressDialog class!')
end

%% Reading
shapeInfo = shapeinfo(filePath);

if shapeInfo.NumFeatures == 0
    error('Shapefile is empty!')
end

if isempty(shapeInfo.CoordinateReferenceSystem)
    warning('CoordinateReferenceSystem of the shapefile is empty!')
    EPSG = str2double(inputdlg2({['DTM EPSG (Sicily -> 32633, ' ...
                                  'Emilia Romagna -> 25832):']}, 'DefInp',{'25832'}));
    shapeInfo.CoordinateReferenceSystem = projcrs(EPSG);
end

if isempty(polyBound.Vertices)
    shapeCont = shaperead(filePath);
else
    minPolyCrds = min(polyBound.Vertices);
    maxPolyCrds = max(polyBound.Vertices);
    
    [eBLon, eBLat] = meters2lonlat( extraBound, mean([minPolyCrds(2), maxPolyCrds(2)]) ); % extra bounds (Lat/Lon increments), necessary due to conversion errors
    [bBoxX, bBoxY] = projfwd(shapeInfo.CoordinateReferenceSystem, ...
                                   [minPolyCrds(2)-eBLat, maxPolyCrds(2)+eBLat], ...
                                   [minPolyCrds(1)-eBLon, maxPolyCrds(1)+eBLon]);
    shapeCont = shaperead(filePath, 'BoundingBox',[bBoxX(1), bBoxY(1);
                                                   bBoxX(2), bBoxY(2)]);
end

if size(shapeCont, 1) < 1
    error('Shapefile is not empty but have no element in bounding box!')
end

ind2Rem = false(size(shapeCont,1), 1); % Initialize logic array
for i1 = 1:size(shapeCont,1)
    ind2Rem(i1) = numel(shapeCont(i1).X) > pointsLim;  % IMPORTANT! Based on this number you will remove some polygons
end
shapeCont(ind2Rem) = [];

if any(ind2Rem)
    warning(['Attention, some polygons had too much points and', ...
             ' they have been excluded. Please contact support'])
    % if progExist
    %     uialert(progDialog, ['Attention, some polygons had too much points and ', ...
    %                          'they have been excluded. Please contact support'], 'Polygons error')
    % else
    %     warning(['Attention, some polygons had too much points and', ...
    %              ' they have been excluded. Please contact support'])
    % end
end

%% Extract classes
allClasses = extractfield(shapeCont, fieldName);
if not(iscellstr(allClasses)) && not(isnumeric(allClasses)) && not(isstring(allClasses))
    error('Column of fieldName must be any between numeric, string, or cellstr!')
end
polyClass  = unique(allClasses);

if not(isa(allClasses, 'cell'))
    allClasses = cellstr(string(allClasses));
    polyClass  = cellstr(string(polyClass));
    warning('Classes of polygons were converted to cellstr type!')
end

indsPlClss = cell(1, length(polyClass));
for i1 = 1:numel(polyClass)
    indsPlClss{i1} = find(strcmp(allClasses, polyClass(i1)));
end

%% Polygon creation
if progExist; progDialog.Indeterminate = 'off'; steps = numel(indsPlClss); end
polyOut = repmat(polyshape, 1, numel(indsPlClss));
for i1 = 1:numel(indsPlClss)
    [polyLat, polyLon] = projinv(shapeInfo.CoordinateReferenceSystem, ...
                                       [shapeCont(indsPlClss{i1}).X], ...
                                       [shapeCont(indsPlClss{i1}).Y]);
    polyOut(i1) = polyshape([polyLon',polyLat'],'Simplify',false);

    if progExist
        progDialog.Value = i1/steps;
        progDialog.Message = ['Polygon n. ',num2str(i1),' of ',num2str(steps)];
        if progDialog.CancelRequested
            return
        end
    end
end
if progExist; progDialog.Indeterminate = 'on'; end

%% Intersections between polyOut and polyBound
if not(isempty(polyBound.Vertices)) && maskOutPoly
    polyOut = intersect(polyOut, polyBound);
end

%% Cleaning of polyOut
emptyInds = cellfun(@isempty, {polyOut.Vertices});

polyOut(emptyInds)   = [];
polyClass(emptyInds) = [];

%% Check
if numel(polyOut) ~= numel(polyClass)
    error('An error occurred in the function, the two outputs have different sizes, please check it!')
end

end