if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data and initialization of variables
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'       ], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load([fold_var,sl,'StudyAreaVariables.mat'    ], 'StudyAreaPolygon')
load([fold_var,sl,'MorphologyParameters.mat'  ], 'SlopeAll')
load([fold_var,sl,'LandUsesVariables.mat'     ], 'AllLandUnique','LandUsePolygonsStudyArea')
load([fold_var,sl,'LithoPolygonsStudyArea.mat'], 'LithoAllUnique','LithoPolygonsStudyArea')

ProjCRS = load_prjcrs(fold_var);

TopSoilExist = false;
if exist([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], 'file')
    load([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], 'TopSoilAllUnique','TopSoilPolygonsStudyArea')
    TopSoilExist = true;
end

DsetStudyExist = false;
if exist([fold_var,sl,'DatasetStudy.mat'], 'file')
    load([fold_var,sl,'DatasetStudy.mat'], 'DatasetStudyInfo')
    ClassesPolys = DatasetStudyInfo.ClassPolygons{:};
    DsetStudyExist = true;
end

%% HRUs options
PrpOpts = {'How to define classes?', 'Generate polygons of HRUs?'};
VlsOpts = {{'As they were imported'}, {'Yes', 'No'}};
if DsetStudyExist; VlsOpts{1} = [VlsOpts{1}, {'Polygons of DatasetStudy'}]; end

if TopSoilExist
    PrpOpts    = [PrpOpts, {'Information for soil classes'}];
    VlsOpts{3} = {'TopSoil', 'SubSoil'};
end

OptsHRU = listdlg2(PrpOpts, VlsOpts);

Ply2Use = OptsHRU{1};
if strcmp(OptsHRU{2}, 'Yes'); GenPoly = true; else; GenPoly = false; end
SoilInf = 'SubSoil';
if TopSoilExist
    SoilInf = OptsHRU{3};
end

OptsCls = inputdlg2({'Number of slope classes (int num): ', ...
                     'Minimum points in cluster: ', ...
                     'Points for search radius'}, 'DefInp',{'10', '1', '4'});
NumSlCl = str2double(OptsCls(1));
MinClst = str2double(OptsCls(2));
MaxSrch = str2double(OptsCls(3));

StpSlQn = 1 / ceil(NumSlCl);
if StpSlQn > 1; error('Please, select a number >= 1'); end

%% Preliminary operations
ProgressBar.Message = 'Preliminary operations...';

[pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
IndDTMPtsOutStudyArea = cellfun(@(x,y) find(~inpoly([x(:),y(:)],pp1,ee1)==1), xLongAll, yLatAll, 'UniformOutput',false);

%% Import of classes of ML
ProgressBar.Message = 'Extracting classes...';

switch Ply2Use
    case 'As they were imported'
        LndUNmeUnique = AllLandUnique;
        LndUPolysStAr = LandUsePolygonsStudyArea;

        switch SoilInf
            case 'TopSoil'
                SoilNmeUnique = TopSoilAllUnique;
                SoilPolysStAr = TopSoilPolygonsStudyArea;
    
            case 'SubSoil'
                SoilNmeUnique = LithoAllUnique;
                SoilPolysStAr = LithoPolygonsStudyArea;
        end

    case 'Polygons of DatasetStudy'
        LndUNmeUnique = ClassesPolys{'LandUse','ClassNames'}{:};
        LndUPolysStAr = ClassesPolys{'LandUse','Polys'}{:};

        switch SoilInf
            case 'TopSoil'
                SoilNmeUnique = ClassesPolys{'TopSoil','ClassNames'}{:};
                SoilPolysStAr = ClassesPolys{'TopSoil','Polys'}{:};
    
            case 'SubSoil'
                SoilNmeUnique = ClassesPolys{'SubSoil','ClassNames'}{:};
                SoilPolysStAr = ClassesPolys{'SubSoil','Polys'}{:};
        end

    otherwise
        error('Source polygon type not recognized!')
end

%% Attributing slope class to each point of DTM
ProgressBar.Message = 'Creating slope classes...';

SlopeAllCat    = cellfun(@(x) x(:), SlopeAll, 'UniformOutput',false);
SlopeAllCatTot = cat(1, SlopeAllCat{:});

% SlopeVals4Clss = (0:10:60)';
SlopeVals4Clss = quantile(SlopeAllCatTot, 0 : StpSlQn : 1);

LegInfoSep = '‒';
LegInfoSlope = [ strcat(string(round(SlopeVals4Clss(1:end-1), 3, 'significant')), ...
                    LegInfoSep, ...
                    string(round(SlopeVals4Clss(2:end), 3, 'significant')))];
LegSlope = strcat("SL", string(1 : (length(SlopeVals4Clss)-1)));
InfoLegSlope = [LegSlope; LegInfoSlope];

SlopeClssIndPts = cell(length(SlopeVals4Clss), size(xLongAll,2));
for i1 = 1:length(SlopeVals4Clss)
    if i1 < length(SlopeVals4Clss)
        SlopeClssIndPts(i1,:) = cellfun(@(x) find(x(:)>=SlopeVals4Clss(i1) & x(:)<SlopeVals4Clss(i1+1)),  SlopeAll, 'UniformOutput',false);
    else
        SlopeClssIndPts(i1,:) = cellfun(@(x) find(x(:)>=SlopeVals4Clss(i1-1) & x(:)<=SlopeVals4Clss(i1)), SlopeAll, 'UniformOutput',false);
    end
end

SlopeClssAll = cellfun(@(x) repmat("No Class", size(x)), xLongAll, 'UniformOutput',false);
for i1 = 1:length(LegSlope)
    for i2 = 1:size(SlopeClssIndPts, 2)
        SlopeClssAll{i2}(SlopeClssIndPts{i1,i2}) = LegSlope(i1);
        SlopeClssAll{i2}(IndDTMPtsOutStudyArea{i2}) = "Out";
    end
end

%% Attributing land use class to each point of DTM
ProgressBar.Message = 'Creating land use classes...';

LegLandUse = strcat("LU", string(1:length(LndUNmeUnique)));
InfoLegLandUse = [LegLandUse; {LndUNmeUnique{:}}]; % {AllLandUniqueToUse{:}} is to avoid problems of size

LandUseClssIndPts = cell(length(LndUNmeUnique), size(xLongAll,2));
for i1 = 1:length(LndUPolysStAr)
    [pp2,ee2] = getnan2([LndUPolysStAr(i1).Vertices; nan, nan]);
    LandUseClssIndPts(i1,:) = cellfun(@(x,y) find(inpoly([x(:),y(:)],pp2,ee2)==1), xLongAll, yLatAll, 'UniformOutput',false);
end

LandUseClssAll = cellfun(@(x) repmat("No Class", size(x)), xLongAll, 'UniformOutput',false);
for i1 = 1:length(LegLandUse)
    for i2 = 1:size(LandUseClssIndPts, 2)
        LandUseClssAll{i2}(LandUseClssIndPts{i1,i2}) = LegLandUse(i1);
        LandUseClssAll{i2}(IndDTMPtsOutStudyArea{i2}) = "Out";
    end
end

%% Attributing soil class to each point of DTM
ProgressBar.Message = 'Creating soil classes...';

LegSoil = strcat("SO", string(1:length(SoilNmeUnique)));
InfoLegSoil = [LegSoil; {SoilNmeUnique{:}}];

SoilClssIndPts = cell(length(SoilNmeUnique), size(xLongAll,2));
for i1 = 1:length(SoilPolysStAr)
    [pp3,ee3] = getnan2([SoilPolysStAr(i1).Vertices; nan, nan]);
    SoilClssIndPts(i1,:) = cellfun(@(x,y) find(inpoly([x(:),y(:)],pp3,ee3)==1), xLongAll, yLatAll, 'UniformOutput',false);
end

SoilClssAll = cellfun(@(x) repmat("No Class", size(x)), xLongAll, 'UniformOutput',false);
for i1 = 1:length(LegSoil)
    for i2 = 1:size(SoilClssIndPts, 2)
        SoilClssAll{i2}(SoilClssIndPts{i1,i2}) = LegSoil(i1);
        SoilClssAll{i2}(IndDTMPtsOutStudyArea{i2}) = "Out";
    end
end

%% Creation of a unique table with separate classes used
Class4CombAll = table({SlopeClssAll}, {LandUseClssAll}, {SoilClssAll}, 'VariableNames',{'Slope', 'LandUse', 'Soil'});

%% Creation of combinations (clusterized)
ProgressBar.Message = 'Defining clusters for combinations...';

CombAll = cellfun(@(x,y,z) strcat(x,"_",y,"_",z), SlopeClssAll, SoilClssAll, LandUseClssAll, 'UniformOutput',false);
for i1 = 1:length(CombAll)
    CombAll{i1}(IndDTMPtsOutStudyArea{i1}) = "Out";
end
CombStudyArRw = cellfun(@(x,y) x(y), CombAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

CombStudyArea = cellfun(@(x) unique(x), CombStudyArRw, 'UniformOutput',false);
CombStudyArea = cat(1, CombStudyArea{:});
CombStudyArea = unique(CombStudyArea);

[xPlnAll, yPlnAll] = cellfun(@(x,y) projfwd(ProjCRS, y, x), xLongAll, yLatAll, 'UniformOutput',false);

xLonTotCat = cellfun(@(x) x(:), xLongAll, 'UniformOutput',false);
xLonTotCat = cat(1, xLonTotCat{:});
yLatTotCat = cellfun(@(x) x(:), yLatAll,  'UniformOutput',false);
yLatTotCat = cat(1, yLatTotCat{:});

xPlnTotCat = cellfun(@(x) x(:), xPlnAll, 'UniformOutput',false);
xPlnTotCat = cat(1, xPlnTotCat{:});
yPlnTotCat = cellfun(@(x) x(:), yPlnAll, 'UniformOutput',false);
yPlnTotCat = cat(1, yPlnTotCat{:});
CmbsTotCat = cellfun(@(x) x(:), CombAll, 'UniformOutput',false);
CmbsTotCat = cat(1, CmbsTotCat{:});

dLat  = abs(yLatAll{1}(1)-yLatAll{1}(2));
dYPl  = deg2rad(dLat)*earthRadius;
MaxdY = MaxSrch*dYPl; % 4 points of distance!

ProgressBar.Indeterminate = 'off';
for i1 = 1:length(CombStudyArea)
    ProgressBar.Value = i1/length(CombStudyArea);
    ProgressBar.Message = ['Clusterizing class n. ', num2str(i1),' of ', num2str(length(CombStudyArea))];

    IndPtsComb = find(CombStudyArea(i1) == CmbsTotCat); % Indices referred to the concatenate vector!
    
    % To replace with clusterize_points
    ClusterCombs = dbscan([xPlnTotCat(IndPtsComb), yPlnTotCat(IndPtsComb)], MaxdY, MinClst); % Coordinates, max dist each point, min n. of point for each core point
    
    CmbsTotCat(IndPtsComb) = strcat(CmbsTotCat(IndPtsComb), '_C', string(ClusterCombs));
end
ProgressBar.Indeterminate = 'on';

%% Reshaping of combinations
IndStart = 0;
HRUsAll = cellfun(@(x) strings(size(x)), xLongAll, 'UniformOutput',false);
for i1 = 1:length(HRUsAll)
    IndEnd = IndStart + numel(HRUsAll{1});
    HRUsAll{i1}(:) = CmbsTotCat(IndStart+1 : IndEnd);
    HRUsAll{i1}(IndDTMPtsOutStudyArea{i1}) = "Out";
    IndStart = IndEnd;
end

HRUsStudyArRw = cellfun(@(x,y) x(y), HRUsAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

HRUsStudyArea = cellfun(@(x) unique(x), HRUsStudyArRw, 'UniformOutput',false);
HRUsStudyArea = cat(1, HRUsStudyArea{:});
HRUsStudyArea = unique(HRUsStudyArea);

%% Creation of polygons (TO CONTINUE, You want polyshapes instead of alphashapes. TRY CONSIDERING EACH POINT AS A SQUARE TO MERGE WITH OTHER SQUARES!)
if GenPoly
    ProgressBar.Indeterminate = 'off';
    PolyClass = repmat(polyshape, 1, numel(CombStudyArea));
    for i1 = 1:length(CombStudyArea)
        ProgressBar.Value   = i1/length(CombStudyArea);
        ProgressBar.Message = ['Creation of polygon (comb.) n. ', num2str(i1),' of ', num2str(length(CombStudyArea))];
    
        IndPtsInClass = find(contains(CmbsTotCat, CombStudyArea(i1)));
        PolyClass(i1) = polybuffpoint2([xLonTotCat(IndPtsInClass), yLatTotCat(IndPtsInClass)], 1.1*dYPl/2, uniquePoly=true); % 1.1 to allow the merging of polygons!
    end
    
    PolyHRU = repmat(polyshape, 1, numel(HRUsStudyArea));
    for i1 = 1:length(HRUsStudyArea)
        ProgressBar.Value   = i1/length(HRUsStudyArea);
        ProgressBar.Message = ['Creation of polygon (HRU) n. ', num2str(i1),' of ', num2str(length(HRUsStudyArea))];
    
        IndPtsInHRU = find(CmbsTotCat == HRUsStudyArea(i1));
        PolyHRU(i1) = polybuffpoint2([xLonTotCat(IndPtsInHRU), yLatTotCat(IndPtsInHRU)], 1.1*dYPl/2, uniquePoly=true); % 1.1 to allow the merging of polygons!
    end
    ProgressBar.Indeterminate = 'on';
end

%% Plot for check
ProgressBar.Message = 'Plotting to check...';

IndClssSel = checkbox2({'Class to plot:'}, CombStudyArea, 'OutType','NumInd');

IndPtsInClass = find(contains(CmbsTotCat, CombStudyArea(IndClssSel)));

[NameClssClst, Ind4UnqClssClst, Ind4ClssClst] = unique(CmbsTotCat(IndPtsInClass));

ColorsUnique = arrayfun(@(x) rand(1, 3), NameClssClst, 'UniformOutput',false);
Colors4Scttr = cell2mat(ColorsUnique(Ind4ClssClst));

[CurrFig, CurrAxs] = check_plot(fold0);

title('HRU Classes')

PltLgnd = arrayfun(@(x, y, i) scatter(x, y, 6, Colors4Scttr(i,:), 'filled', 'Marker','o', ...
                                                                  'MarkerFaceAlpha',0.7, 'Parent',CurrAxs), ...
                                    xLonTotCat(IndPtsInClass(Ind4UnqClssClst)), ...
                                    yLatTotCat(IndPtsInClass(Ind4UnqClssClst)), Ind4UnqClssClst);

PltClst = scatter(xLonTotCat(IndPtsInClass), yLatTotCat(IndPtsInClass), 6, Colors4Scttr, ...
                                        'filled', 'Marker','o', 'MarkerFaceAlpha',0.7, 'Parent',CurrAxs);

if numel(PltLgnd) <= 18
    CurrLeg = legend(PltLgnd, string(strrep(NameClssClst, '_', ' ')), ...
                               'NumColumns',3, ...
                               'Fontsize',5, ...
                               'Location','southoutside', ...
                               'Box','off');
end

%% Saving...
ProgressBar.Message = 'Saving...';

VarsHRUs = {'HRUsAll', 'CombAll', 'Class4CombAll', 'InfoLegSlope', ...
                'InfoLegLandUse', 'InfoLegSoil', 'HRUsStudyArea', 'CombStudyArea'};
if GenPoly; VarsHRUs = [VarsHRUs, {'PolyClass', 'PolyHRU'}]; end

saveswitch([fold_var,sl,'HRUs.mat'], VarsHRUs);