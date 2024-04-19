if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Initializing', 'Indeterminate','on');
drawnow

%% Options
ProgressBar.Message = 'General options...';

AreaFltAns = uiconfirm(Fig, 'Do you want to filter polygons based on the area?', ...
                            'Poly filter', 'Options',{'Yes','No'}, 'DefaultOption',1);
if strcmp(AreaFltAns,'Yes'); AreaFilter = true; else; AreaFilter = false; end

if AreaFilter
    MaxLimArea = str2num(string(inputdlg2({'Max limit area [m2]'}, 'DefInp',{'70*70'})));
    
    figure(Fig)
    drawnow
end

BufferSize  = str2double(string(inputdlg2({'Buffer for point or linear geometries [m]'}, 'DefInp',{'15'})));
OrderEvents = uiconfirm(Fig, 'How do you want to order polygons?', ...
                             'Poly order', 'Options',{'Dates','NumOfEvents'}, 'DefaultOption',1);
figure(Fig)
drawnow

%% File selection
ProgressBar.Message = 'Selection of files...';

sl = filesep;

cd(fold_var)
load('StudyAreaVariables.mat', 'StudyAreaPolygon','MaxExtremes','MinExtremes');

cd(fold_raw_det_ss);
[FlNmShp, FlPthShp] = uigetfile('*.shp', 'Choose your shapefile', 'MultiSelect','on');
if not(iscell(FlNmShp)); FlNmShp = {FlNmShp}; end
ShpPaths = strcat(FlPthShp, FlNmShp);

% Copy in case of files taken from other folders
FileShpMissing = any(cellfun(@(x) ~exist([fold_raw_det_ss,sl,x], 'file'), FlNmShp));
if FileShpMissing
    Files          = string({dir(FlPthShp).name});
    [~, FlNmShp]   = fileparts(FlNmShp);
    IndFilesToCopy = contains(Files,FlNmShp);
    FilesToCopy    = strcat(FlPthShp,Files(IndFilesToCopy));
    arrayfun(@(x) copyfile(x, fold_raw_det_ss), FilesToCopy);
end

if not(exist('SrcType', 'var'))
    SrcType = uiconfirm(Fig, 'Do you want to use just shapefiles or also excel?', ...
                             'Shp+Excel', 'Options',{'Shp','Excel+Shp'}, 'DefaultOption',1);
end

switch SrcType
    case 'Shp'

    case 'Excel+Shp'
        [FlNmXlsx, FlPthXlsx] = uigetfile('*.xlsx', 'Choose your shapefile', 'MultiSelect','off');
        InventoryExcelPath = [FlPthXlsx, FlNmXlsx];

        % Copy in case of files taken from other folders
        FileXlsxMissing = ~exist([fold_raw_det_ss,sl,FlNmXlsx], 'file');
        if FileXlsxMissing
            Files          = string({dir(FlPthXlsx).name});
            [~, FlNmXlsx]  = fileparts(FlNmXlsx);
            IndFilesToCopy = contains(Files,FlNmXlsx);
            FilesToCopy    = strcat(FlPthXlsx,Files(IndFilesToCopy));
            arrayfun(@(x) copyfile(x, fold_raw_det_ss), FilesToCopy);
        end

    otherwise
        error('Source type not recognized!')
end

%% File reading
ProgressBar.Message = 'Reading files...';

ShpInfo = cellfun(@(x) shapeinfo([fold_raw_det_ss,sl,x]), FlNmShp, 'UniformOutput',false);

EB = 500*180/pi/earthRadius; % ExtraBounding Lat/Lon increment for a respective 500 m length, necessary due to conversion errors

[ShpRead, ShpGmtUn] = deal(cell(size(ShpInfo)));
for i1 = 1:numel(ShpInfo)
    if ShpInfo{i1}.NumFeatures == 0
        error(['Shapefile ',FlNmShp{i1},' is empty'])
    end

    ShpGmtUn{i1} = ShpInfo{i1}.CoordinateReferenceSystem.LengthUnit;
    switch ShpInfo{i1}.ShapeType
        case 'Polygon'

        case {'PolyLine','Point'}
            if not(strcmp(ShpGmtUn{i1}, 'meter'))
                error(['Shapefile (',FlNmShp{i1},') must be in meters! Conversion not yet supported!'])
            end
    
        otherwise
            error(['Shapefile (',FlNmShp{i1},') geometry type not recognized!'])
    end

    [BoundingBoxX, BoundingBoxY] = projfwd(ShpInfo{i1}.CoordinateReferenceSystem, ...
                                           [MinExtremes(2)-EB, MaxExtremes(2)+EB], ...
                                           [MinExtremes(1)-EB, MaxExtremes(1)+EB]);
    
    ShpRead{i1} = shaperead([fold_raw_det_ss,sl,FlNmShp{i1}], 'BoundingBox',[ BoundingBoxX(1), BoundingBoxY(1); ...
                                                                              BoundingBoxX(2), BoundingBoxY(2) ]);

    if size(ShpRead{i1}, 1) < 1
        error('Shapefile is not empty but have no element in bounding box!')
    end
end

ShpFldPrp = cellfun(@(x) ['ID field in ',x,': '], FlNmShp, 'UniformOutput',false);
ShpFields = cellfun(@(x) [{x.Attributes.Name},"None of these"], ShpInfo, 'UniformOutput',false);
ShpFldsID = listdlg2(ShpFldPrp, ShpFields);

NotFldShp = cellfun(@(x) strcmp(x, 'None of these'), ShpFldsID);
if any(NotFldShp)
    warning(['Since you have selected "None of these", ' ...
             'shapefile ',char(join(FlNmShp(NotFldShp),' and ')), ...
             ' will not be taken into account!'])

    ShpPaths(NotFldShp)  = [];
    FlNmShp(NotFldShp)   = [];
    ShpInfo(NotFldShp)   = [];
    ShpRead(NotFldShp)   = [];
    ShpFldsID(NotFldShp) = [];
    ShpGmtUn(NotFldShp)  = [];
end

switch SrcType
    case 'Shp'

    case 'Excel+Shp'
        InvLandsCell = readcell(InventoryExcelPath);
        InvLandsTbl  = array2table(InvLandsCell(2:end,:), 'VariableNames',InvLandsCell(1,:)); % From 2nd row because the first is for header!
        ColsWithDate = find(varfun(@(x) isdatetime(x{1}), InvLandsTbl, 'OutputFormat','uniform'));
        for i1 = ColsWithDate
            InvLandsTbl.(InvLandsCell{1,i1}) = num2cell([InvLandsTbl{:,i1}{:}]'); % To convert all in datetimes!
        end

        ExclFldPrp = cellfun(@(x, y) ['Excel ID for ',x,' (',y,')'], ShpFldsID, FlNmShp, 'UniformOutput',false);
        ExclFields = InvLandsTbl.Properties.VariableNames;
        ExclFldsID = listdlg2(ExclFldPrp, ExclFields);

    otherwise
        error('Source type not recognized!')
end

cd(fold0)

%% Polygons from shapefile
ProgressBar.Message = 'Creation of polygons...';

ProgressBar.Indeterminate = 'off';
[LandsOrgCoords, LandsMrgdPolys, ...
        LandsUnShpIDs, LndUnShIDInds] = deal(cell(1, numel(ShpInfo)));
for i1 = 1:numel(ShpInfo)
    ShpIDs = extractfield(ShpRead{i1}, ShpFldsID{i1});
    
    if isnumeric(ShpIDs)
        EffShpIDs = not(ShpIDs == 0);
        NumShpIDs = sum(EffShpIDs);
    else
        warning(['Attention, you do not have a numeric array in ID (', ...
                 FlNmShp{i1},')! The script could not work properly...'])
    end
    
    UnShpIDs = unique(ShpIDs);
    UnShpIDs(UnShpIDs == 0) = []; % To exclude ID n. 0!
    
    NumUnShpIDs = numel(UnShpIDs);
    
    IndUnShpIDs = cell(1, NumUnShpIDs);
    for i2 = 1:NumUnShpIDs
        IndUnShpIDs{i2} = find(UnShpIDs(i2) == ShpIDs);
    end

    LandsUnShpIDs{i1} = UnShpIDs;
    LndUnShIDInds{i1} = IndUnShpIDs;
    
    % Poligon creation
    LandsOrgCoords{i1} = cell(1, NumUnShpIDs);
    LandsMrgdPolys{i1} = repmat(polyshape, 1, NumUnShpIDs);
    for i2 = 1:length(IndUnShpIDs)
        ProgressBar.Value = i2/length(IndUnShpIDs);
        ProgressBar.Message = ['Polygon n. ',num2str(i2),' of ',num2str(length(IndUnShpIDs)),' (from ',FlNmShp{i1},')'];

        LndOrCrdsTmp = cell(1, numel(IndUnShpIDs{i2}));
        LandsPolyTmp = repmat(polyshape, 1, numel(IndUnShpIDs{i2}));
        for i3 = 1:numel(IndUnShpIDs{i2})
            [ShpLatsTmp, ShpLonsTmp] = projinv(ShpInfo{i1}.CoordinateReferenceSystem, ...
                                                    [ShpRead{i1}(IndUnShpIDs{i2}(i3)).X], ...
                                                    [ShpRead{i1}(IndUnShpIDs{i2}(i3)).Y]);

            LndOrCrdsTmp{i3} = [ShpLonsTmp', ShpLatsTmp'];

            switch ShpInfo{i1}.ShapeType
                case 'Polygon'
                    ShpLats = ShpLatsTmp';
                    ShpLons = ShpLonsTmp';
    
                case 'PolyLine'
                    PolyLineBuffPlan   = polybuffer([ [ShpRead{i1}(IndUnShpIDs{i2}(i3)).X]', ...
                                                      [ShpRead{i1}(IndUnShpIDs{i2}(i3)).Y]' ], 'lines', BufferSize);
                    PolyLineBffPlnCrds = PolyLineBuffPlan.Vertices;
                    [ShpLats, ShpLons] = projinv(ShpInfo{i1}.CoordinateReferenceSystem, ...
                                                                 PolyLineBffPlnCrds(:,1), PolyLineBffPlnCrds(:,2));

                case 'Point'
                    PolyPointBuffPlan  = polybuffer([ [ShpRead{i1}(IndUnShpIDs{i2}(i3)).X]', ...
                                                      [ShpRead{i1}(IndUnShpIDs{i2}(i3)).Y]' ], 'points', BufferSize);
                    PolyPntBuffPlnCrds = PolyPointBuffPlan.Vertices;
                    [ShpLats, ShpLons] = projinv(ShpInfo{i1}.CoordinateReferenceSystem, ...
                                                                 PolyPntBuffPlnCrds(:,1), PolyPntBuffPlnCrds(:,2));
    
                otherwise
                    error(['Shapefile (',FlNmShp{i1},') geometry not recognized!'])
            end

            LandsPolyTmp(i3) = polyshape([ShpLons, ShpLats], 'Simplify',false);
        end

        LandsOrgCoords{i1}{i2} = LndOrCrdsTmp;
        LandsMrgdPolys{i1}(i2) = union(LandsPolyTmp);
    end
end
ProgressBar.Indeterminate = 'on';

%% Cleaning of landslides polygons
ProgressBar.Message = 'Cleaning and intersection of polygons with Study Area...';

% Find intersection among IDs polygon and the study area
LndsUnShIDStudy = cat(2, LandsUnShpIDs{:});
LndsUnOrCrStudy = cat(2, LandsOrgCoords{:});
LndsUnPlysStudy = intersect(cat(2, LandsMrgdPolys{:}), StudyAreaPolygon);

% Removal of IDs excluded from the study area
MptyLndsPlyStdy = cellfun(@isempty,{LndsUnPlysStudy.Vertices});
LndsUnShIDStudy = LndsUnShIDStudy(not(MptyLndsPlyStdy));
LndsUnOrCrStudy = LndsUnOrCrStudy(not(MptyLndsPlyStdy));
LndsUnPlysStudy = LndsUnPlysStudy(not(MptyLndsPlyStdy));

% Merging of possible duplicate IDs
NewUnIDs = unique(LndsUnShIDStudy);
ToMerge  = (numel(NewUnIDs) ~= numel(LndsUnShIDStudy));
if ToMerge
    IndToUse = cell(1, numel(NewUnIDs));
    for i1 = 1:numel(NewUnIDs)
        IndToUse{i1} = find(NewUnIDs(i1) == LndsUnShIDStudy); % This is relative to LndsUnShIDStudy
    end
    NumDup = cellfun(@numel, IndToUse);
    IndDup = find(NumDup > 1); % This is relative to IndToUse or NumDup
    IDsDup = LndsUnShIDStudy(arrayfun(@(x) IndToUse{x}(1), IndDup));
    WrnStr = ['Attention, ',num2str(numel(IndDup)),' repetitions (IDs: ', ...
              num2str(IDsDup),' for respectively ',num2str(NumDup(IndDup)), ...
              ' times). These reps will be merged into single polygons!'];
    warning(WrnStr)

    LndsUnShIDStudy = NewUnIDs;
    LndsUnOrCrStudy = cellfun(@(x) [LndsUnOrCrStudy{x}], IndToUse, 'UniformOutput',false);
    LndsUnPlysStudy = cellfun(@(x) union([LndsUnPlysStudy(x)]), IndToUse);
end

%% Adding columns
ProgressBar.Message = 'Adding columns to excel table...';

Cntnt      = {'OrCrds', 'MrgdPlyg'};
[~, ClNms] = fileparts(erase(FlNmShp, ' '));

CmbsInd = combvec(1:length(Cntnt), 1:length(ClNms));
Cls2Add = cell(2, numel(ClNms));
for i1 = 1:size(CmbsInd,2)
    Cls2Add{CmbsInd(1,i1), CmbsInd(2,i1)} = [Cntnt{CmbsInd(1,i1)},'_',ClNms{CmbsInd(2,i1)}];
end

ProgressBar.Indeterminate = 'off';
[InvLandsTbl{:,Cls2Add(1,:)}, InvLandsTbl{:,Cls2Add(2,:)}] = deal(cell(size(InvLandsTbl,1), numel(ClNms)));
% InvLandsTbl{:,Cls2Add(2,:)} = repmat(polyshape, size(InvLandsTbl,1), numel(ClNms));
for i1 = 1:numel(LandsMrgdPolys)
    ProgressBar.Value = i1/numel(LandsMrgdPolys);
    ProgressBar.Message = ['Adding single polygons, shapefile n. ',num2str(i1),' of ',num2str(numel(LandsMrgdPolys))];

    for i2 = 1:numel(LandsMrgdPolys{i1})
        IndsMatchPolys = (LandsUnShpIDs{i1}(i2) == [InvLandsTbl.(ExclFldsID{i1}){:}]);
        InvLandsTbl{IndsMatchPolys,Cls2Add(1,i1)} = LandsOrgCoords{i1}(i2);
        InvLandsTbl{IndsMatchPolys,Cls2Add(2,i1)} = {LandsMrgdPolys{i1}(i2)};
    end
end

InvLandsTbl{:,'PolyTotal'} = cell(size(InvLandsTbl,1), 1);
% InvLandsTbl{:,'PolyTotal'} = repmat(polyshape, size(InvLandsTbl,1), 1);
for i1 = 1:size(InvLandsTbl,1)
    ProgressBar.Value = i1/size(InvLandsTbl,1);
    ProgressBar.Message = ['Creation of merged polygon n. ',num2str(i1),' of ',num2str(size(InvLandsTbl,1))];

    TmpPly2Mrg = [InvLandsTbl{i1,Cls2Add(2,:)}{:}];
    if not(isempty(TmpPly2Mrg))
        InvLandsTbl{i1,'PolyTotal'} = {union([InvLandsTbl{i1,Cls2Add(2,:)}{:}])};
    end
end

IndPln = find(cellfun(@(x) strcmp(x, "meter"), ShpGmtUn), 1);
if isempty(IndPln); error('No shapefile with planar coords, when calculating area!'); end

PolyTotalPlan = repmat(polyshape, size(InvLandsTbl,1), 1);
for i1 = 1:size(InvLandsTbl, 1)
    ProgressBar.Value = i1/size(InvLandsTbl,1);
    ProgressBar.Message = ['Evaluation of area n. ',num2str(i1),' of ',num2str(size(InvLandsTbl,1))];

    if not(isempty(InvLandsTbl.PolyTotal{i1}))
        [PolyTotalPlanX, PolyTotalPlanY] = projfwd(ShpInfo{IndPln}.CoordinateReferenceSystem, ...
                                                       InvLandsTbl.PolyTotal{i1}.Vertices(:,2), ...
                                                       InvLandsTbl.PolyTotal{i1}.Vertices(:,1));
        PolyTotalPlan(i1) = polyshape([PolyTotalPlanX, PolyTotalPlanY], 'Simplify',false);
    end
end
ProgressBar.Indeterminate = 'on';

InvLandsTbl.AreaPolyTotal = num2cell(area(PolyTotalPlan));

% Cleaning of Table
ProgressBar.Message = 'Cleaning of table...';
    
EmptyPolys = (cell2mat(InvLandsTbl.AreaPolyTotal) == 0);
InvLandsTbl(EmptyPolys,:) = [];

%% Excel writing
ProgressBar.Message = 'Excel writing...';

ExclFields  = InvLandsTbl.Properties.VariableNames;
ColsWthDttm = find(varfun(@(x) isdatetime(x{1}), InvLandsTbl, 'OutputFormat','uniform'));
ExcFldsDttm = ExclFields(ColsWthDttm);
ExcDttm     = listdlg2({'Field containing datetimes:'}, ExcFldsDttm);

DttmsLnds   = cat(1, InvLandsTbl.(ExcDttm{:}){:});
DttmsLndsUn = unique(DttmsLnds);

LndsPerDtUn = zeros(size(DttmsLndsUn));
for i1 = 1:length(DttmsLndsUn)
    LndsPerDtUn(i1) = sum(DttmsLndsUn(i1) == DttmsLnds);
end

switch OrderEvents
    case 'NumOfEvents'
        [LndsPerDtUnOrd, IndForOrd] = sort(LndsPerDtUn, 'descend');
        DttmsLndsUnOrd = DttmsLndsUn(IndForOrd);

    case 'Dates'
        [DttmsLndsUnOrd, IndForOrd] = sort(DttmsLndsUn, 'descend');
        LndsPerDtUnOrd = LndsPerDtUn(IndForOrd);

    otherwise
        error('Ordering table type not recognized!')
end

PmptForDts = strcat(string(DttmsLndsUnOrd, 'dd-MMM-yyyy')," (",string(LndsPerDtUnOrd)," landslides)");
IndEvents  = listdlg('PromptString',{'Choose date(s) you want to consider: ',''}, ...
                     'ListString',PmptForDts, 'SelectionMode','multiple');
DtsChosen  = DttmsLndsUnOrd(IndEvents);

figure(Fig)
drawnow

CloseDates = uiconfirm(Fig, 'Do you want to search also for dates near to the one selected?', ...
                            'Near dates', 'Options',{'Yes', 'No'}, 'DefaultOption',1);

if strcmp(CloseDates, 'Yes')
    DaysRange  = str2double(inputdlg("Specify how many days to consider for search per day : ", '', 1, {'5'}));
    IndDtInRng = cell(1, length(DtsChosen));
    for i1 = 1:length(DtsChosen)
        IndDtInRng{i1} = (DttmsLndsUnOrd >= DtsChosen(i1)-days(DaysRange)) & (DttmsLndsUnOrd <= DtsChosen(i1)+days(DaysRange));
    end

    IndEvntsNw = find(any([IndDtInRng{:}], 2));
    DatesToUse = DttmsLndsUnOrd(IndEvntsNw);
else
    DatesToUse = DtsChosen;
end

IndsToTakeDates = false(length(DttmsLnds), 1);
for i1 = 1:length(DatesToUse)
    IndsToTakeDates = any([IndsToTakeDates, DatesToUse(i1) == DttmsLnds], 2);
end

% Soil Slip Filtering
if AreaFilter
    ProbableSoilSlip = cat(1, InvLandsTbl.AreaPolyTotal{:}) <= MaxLimArea;
    IndsToTakeFilt   = ProbableSoilSlip & IndsToTakeDates;
else
    IndsToTakeFilt   = IndsToTakeDates;
end

[xLandsLong, yLandsLat]  = centroid(cat(1, InvLandsTbl.PolyTotal{:})); % Evaluation of centroid for all the polygons!
InvLandsTbl.CentroidLat  = num2cell(yLandsLat);
InvLandsTbl.CentroidLong = num2cell(xLandsLong);

TblCols = InvLandsTbl.Properties.VariableNames;
MstVars = {'Municipality', 'ID', 'Lat', 'Long', 'Date', 'Area'};
[Vars2Tk, VarLbls] = listdlg2(MstVars, TblCols, 'PairLabels',true, 'Extendable',true);
Cont2Write  = InvLandsTbl{IndsToTakeFilt, Vars2Tk};
IndsMissing = cellfun(@(x) all(ismissing(x)), Cont2Write);
Cont2Write(IndsMissing) = {'Missing'};

FlNmID = 'IDsFromShape.xlsx';
DataToWrite  = [VarLbls; Cont2Write];
writecell(DataToWrite, [fold_user,sl,FlNmID])
warning([FlNmID,' generated! You should go in "User Control" and open ' ...
         'it and then move it in "Raw Data -> Detected Soil Slips"'])

%% General landslides summary writing
ProgressBar.Message = 'Creation of General Landslides table...';

GeneralLandslidesSummary = table(DttmsLndsUnOrd, LndsPerDtUnOrd, 'VariableNames',{'Datetime','NumOfLandsllides'});

IndMun = find(strcmp(MstVars, 'Municipality'));
if numel(IndMun) ~= 1; error('Index of municipalities not found!'); end

Municipalities = cell(size(GeneralLandslidesSummary,1), 1);
for i1 = 1:length(Municipalities)
    IndsToTake = (DttmsLndsUnOrd(i1) == DttmsLnds);
    Municipalities{i1} = string(unique(InvLandsTbl.(Vars2Tk{IndMun})(IndsToTake)));
end

GeneralLandslidesSummary.Municipalities = Municipalities;

%% Number of events per municipality
ProgressBar.Message = 'Creation of LandslidesCountPerMun table...';

MunsUnique = unique(cat(1, GeneralLandslidesSummary.Municipalities{:}))';

IndDat = find(strcmp(MstVars, 'Date'));
if numel(IndDat) ~= 1; error('Index of datetimes not found!'); end

IndIDs = find(strcmp(MstVars, 'ID'));
if numel(IndIDs) ~= 1; error('Index of IDs not found!'); end

LandsPerDatePerMun = zeros(length(GeneralLandslidesSummary.Datetime), length(MunsUnique));
for i1 = 1:size(InvLandsTbl, 1)
    ColNumTemp = find(strcmp(InvLandsTbl.(Vars2Tk{IndMun}){i1}, MunsUnique));
    RowNumTemp = find(InvLandsTbl.(Vars2Tk{IndDat}){i1} == GeneralLandslidesSummary.Datetime);
    if isempty(ColNumTemp) || isempty(RowNumTemp)
        warning(['Event with GIS ID n. ',num2str(InvLandsTbl.(Vars2Tk{IndIDs}){i1}), ...
                 ' (row n. ',num2str(i1),') has not match! Please analyze it.'])
    end
    LandsPerDatePerMun(RowNumTemp, ColNumTemp) = LandsPerDatePerMun(RowNumTemp, ColNumTemp) + 1;
end

CheckNumLands = isequal(sum(LandsPerDatePerMun, 2), GeneralLandslidesSummary.NumOfLandsllides);
if not(CheckNumLands)
    error('Landslides number in LandslidesCountPerMun does not match GeneralLandslidesSummary!')
end

LandslidesCountPerMun = [GeneralLandslidesSummary(:,'Datetime'), array2table(LandsPerDatePerMun, 'VariableNames',MunsUnique)];

%% Plot for check
ProgressBar.Message = 'Plotting for check...';

fig_check = figure(1);
ax_check = axes(fig_check);
hold(ax_check,'on')

plot(LndsUnPlysStudy)
title('Litho Polygon Check')
xlim([MinExtremes(1), MaxExtremes(1)])
ylim([MinExtremes(2), MaxExtremes(2)])
% legend(LndsUnShIDStudy, 'Location','SouthEast', 'AutoUpdate','off')
plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1)

yLatMean    = (MaxExtremes(2)+MinExtremes(2))/2;
dLat1Meter  = rad2deg(1/earthRadius); % 1 m in lat
dLong1Meter = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long

RatioLatLong = dLat1Meter/dLong1Meter;
daspect([1, RatioLatLong, 1])

%% Saving of polygons included in the study area
ProgressBar.Message = 'Saving...';

VariablesLnds = {'LndsUnPlysStudy', 'LndsUnShIDStudy', 'LndsUnOrCrStudy', 'FlNmShp', 'ShpPaths'};
save([fold_var,sl,'SoilSlipPolygonsStudyArea.mat'], VariablesLnds{:});

VariablesLndsTbl = {'InvLandsTbl', 'GeneralLandslidesSummary', 'LandslidesCountPerMun'};
save([fold_var,sl,'LandslidesInfo.mat'], VariablesLndsTbl{:})

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version