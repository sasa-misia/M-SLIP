if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Cancelable','off', 'Message','Reading files...');
drawnow

%% Options
ProgressBar.Message = 'General options...';

AnsFilters = checkbox2({'Polygon filter based on area', 'Polygon filter based on ID'}, 'OutType','LogInd');
AreaFilter = AnsFilters(1);
PlIDFilter = AnsFilters(2);

if AreaFilter
    MaxLimArea = str2num(char(inputdlg2({'Max limit area [m2]'}, 'DefInp',{'70*70'})));
end

BufferSize  = str2double(inputdlg2({'Buffer for point or linear geometries [m]'}, 'DefInp',{'15'}));
OrderEvents = uiconfirm(Fig, 'How do you want to order polygons?', ...
                             'Poly order', 'Options',{'Dates','NumOfEvents'}, 'DefaultOption',1);

%% File selection
ProgressBar.Message = 'Selection of files...';

sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon','MaxExtremes','MinExtremes');

[FlNmShp, FlPthShp] = uigetfile([fold_raw_det_ss,sl,'*.shp'], 'Choose your shapefile', 'MultiSelect','on');
if not(iscell(FlNmShp)); FlNmShp = {FlNmShp}; end
ShpPath = strcat(FlPthShp, FlNmShp);

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
        [FlNmXlsx, FlPthXlsx] = uigetfile([fold_raw_det_ss,sl,'*.xlsx'], 'Choose your excel file', 'MultiSelect','off');
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

[ShpInfo, ShpRead, ShpType, ShpUnit] = deal(cell(1, numel(FlNmShp)));
for i1 = 1:numel(FlNmShp)
    [ShpInfo{i1}, ShpRead{i1}, ShpType{i1}, ShpUnit{i1}] = readshape2(ShpPath{i1}, polyBound=StudyAreaPolygon, extraBound=1000);
end

IndPln = find(cellfun(@(x) strcmp(x, "meter"), ShpUnit), 1); % Just a single index! It is not important which CRS you use but it must be in meters.
if isempty(IndPln)
    NmEPSG = str2double(inputdlg2({['EPSG for area assessment (Sicily -> 32633, ' ...
                                    'Emilia Romagna -> 25832):']}, 'DefInp',{'25832'}));
    PlnRef = projcrs(NmEPSG); % To convert into planar coordinates (just one)
else
    PlnRef = ShpInfo{IndPln}.CoordinateReferenceSystem; % To convert into planar coordinates (just one)
end

ShpFldPrp = cellfun(@(x) ['ID field in ',x,': '], FlNmShp, 'UniformOutput',false);
ShpFields = cellfun(@(x) [{x.Attributes.Name},"None of these"], ShpInfo, 'UniformOutput',false);
ShpFlID = listdlg2(ShpFldPrp, ShpFields);
NotFldShp = cellfun(@(x) strcmp(x, 'None of these'), ShpFlID);
if any(NotFldShp)
    warning(['Since you have selected "None of these", ' ...
             'shapefile ',char(join(FlNmShp(NotFldShp),' and ')), ...
             ' will not be taken into account!'])

    ShpPath(NotFldShp) = [];
    FlNmShp(NotFldShp) = [];
    ShpInfo(NotFldShp) = [];
    ShpRead(NotFldShp) = [];
    ShpType(NotFldShp) = [];
    ShpUnit(NotFldShp) = [];
    ShpFlID(NotFldShp) = [];
end

switch SrcType
    case 'Shp'
        ShpFldPrp = cellfun(@(x) ['Datetime field in ',x,': '], FlNmShp, 'UniformOutput',false);
        ShpFldsDt = listdlg2(ShpFldPrp, ShpFields);

        DttmAss = cell(1, numel(ShpInfo));
        for i1 = 1:numel(ShpInfo)
            NumDts = 1;
            ShpIDs = extractfield(ShpRead{i1}, ShpFlID{i1});
            ShpDts = NaT(size(ShpIDs));
            if not(strcmpi(ShpFldsDt(i1), 'None of these'))
                ShpDtsR = extractfield(ShpRead{i1}, ShpFldsDt{i1});
                for i2 = 1:numel(ShpDtsR)
                    if isdatetime(ShpDtsR(i2))
                        ShpDts(i2) = ShpDtsR(i2);
                    elseif ( iscell(ShpDtsR(i2)) && (ischar(ShpDtsR{i2}) ...
                             || isstring(ShpDtsR{i2})) ) || ischar(ShpDtsR(i2)) || isstring(ShpDtsR(i2))
                        if NumDts > 1
                            ShpDts(i2) = datetime(cellstr(ShpDtsR(i2)), 'InputFormat',DttmFrmt{:});
                        else
                            ShpDtTmp   = cellstr(ShpDtsR(i2));
                            DttmFrmt   = inputdlg2({['Datetime format for ',ShpDtTmp{:}]}, 'DefInp',{'yyyyMMdd'});
                            ShpDts(i2) = datetime(ShpDtTmp, 'InputFormat',DttmFrmt{:});
                            NumDts = NumDts + 1;
                        end
                    end
                end
            end
            DttmAss{i1} = [cellstr(string(ShpIDs))', num2cell(ShpDts)'];
        end

        DttmAss = cat(1, DttmAss{:});

        InvLandsTbl = table;
        InvTbColID  = repmat({'ID'}, 1, numel(ShpRead));

    case 'Excel+Shp'
        InvLandsCell = readcell(InventoryExcelPath);
        InvLandsTbl  = array2table(InvLandsCell(2:end,:), 'VariableNames',InvLandsCell(1,:)); % From 2nd row because the first is for header!
        ColsWithDate = find(varfun(@(x) isdatetime(x{1}), InvLandsTbl, 'OutputFormat','uniform'));
        for i1 = ColsWithDate
            InvLandsTbl.(InvLandsCell{1,i1}) = num2cell([InvLandsTbl{:,i1}{:}]'); % To convert all in datetimes!
        end

        ExclFldPrp = cellfun(@(x, y) ['Excel ID for ',x,' (',y,')'], ShpFlID, FlNmShp, 'UniformOutput',false);
        ExclFields = InvLandsTbl.Properties.VariableNames;
        InvTbColID = listdlg2(ExclFldPrp, ExclFields);

    otherwise
        error('Source type not recognized!')
end

%% Polygons from shapefile (consider to create a separate function!)
ProgressBar.Message = 'Creation of polygons...';

ProgressBar.Indeterminate = 'off';
[LandsOrgCoords, LandsMrgdPolys, ...
        LandsUnShpIDs, LndUnShIDInds] = deal(cell(1, numel(ShpInfo)));
for i1 = 1:numel(ShpInfo)
    ShpIDs   = extractfield(ShpRead{i1}, ShpFlID{i1});
    UnShpIDs = unique(ShpIDs);

    if PlIDFilter
        ID2Use = checkbox2(string(UnShpIDs), 'Title',{['ID to consider (file ',num2str(i1),') :']}, ...
                                             'OutType','NumInd', 'DefInp',true(1, numel(UnShpIDs)));
        if not(isempty(ID2Use))
            UnShpIDs = UnShpIDs(ID2Use);
        end
    end
      
    if isnumeric(ShpIDs)
        IndsW0 = UnShpIDs == 0;
        if any(IndsW0)
            UnShpIDs(IndsW0) = []; % To exclude ID n. 0!
            warning(['IDs equal to 0 found in file n. ',num2str(i1),'. They ', ...
                     'will be removed, contact the support if you need them!'])
        end

    elseif isstring(ShpIDs) || ischar(ShpIDs) || iscellstr(ShpIDs)
        warning(['You have a string ID (',FlNmShp{i1},').'])

    else
        error(['ID field data type not recognized for file ',FlNmShp{i1}])
    end

    IndUnShpIDs = cell(1, numel(UnShpIDs)); 
    for i2 = 1:numel(UnShpIDs)
        IndUnShpIDs{i2} = find(ismember(ShpIDs, UnShpIDs(i2)));
    end

    LandsUnShpIDs{i1} = cellstr(string(UnShpIDs));
    LndUnShIDInds{i1} = IndUnShpIDs;
    
    % Poligon creation
    LandsOrgCoords{i1} = cell(1, numel(UnShpIDs));
    LandsMrgdPolys{i1} = repmat(polyshape, 1, numel(UnShpIDs));
    for i2 = 1:numel(IndUnShpIDs)
        ProgressBar.Value = i2/length(IndUnShpIDs);
        ProgressBar.Message = ['Polygon n. ',num2str(i2),' of ',num2str(length(IndUnShpIDs)),' (from ',FlNmShp{i1},')'];

        LndOrCrdsTmp = cell(1, numel(IndUnShpIDs{i2}));
        LandsPolyTmp = repmat(polyshape, 1, numel(IndUnShpIDs{i2}));
        for i3 = 1:numel(IndUnShpIDs{i2})
            switch ShpUnit{i1}
                case 'meter'
                    ShpXPlnTmp = [ShpRead{i1}(IndUnShpIDs{i2}(i3)).X]';
                    ShpYPlnTmp = [ShpRead{i1}(IndUnShpIDs{i2}(i3)).Y]';
                    PlnRefTemp = ShpInfo{i1}.CoordinateReferenceSystem;
                    [ShpLatsTmp, ShpLonsTmp] = projinv(PlnRefTemp, ShpXPlnTmp, ShpYPlnTmp);

                case 'degree'
                    ShpLonsTmp = [ShpRead{i1}(IndUnShpIDs{i2}(i3)).X]';
                    ShpLatsTmp = [ShpRead{i1}(IndUnShpIDs{i2}(i3)).Y]';
                    PlnRefTemp = PlnRef;
                    [ShpXPlnTmp, ShpYPlnTmp] = projfwd(PlnRefTemp, ShpLatsTmp, ShpLonsTmp);

                otherwise
                    error('Shape unit not recognized!')
            end

            LndOrCrdsTmp{i3} = [ShpLonsTmp, ShpLatsTmp];

            switch ShpType{i1}
                case 'Polygon'
                    ShpLats = ShpLatsTmp;
                    ShpLons = ShpLonsTmp;
    
                case 'PolyLine'
                    PolyLineBuffPlan   = polybuffer([ShpXPlnTmp, ShpYPlnTmp], 'lines', BufferSize);
                    PolyLineBffPlnCrds = PolyLineBuffPlan.Vertices;
                    [ShpLats, ShpLons] = projinv(PlnRefTemp, PolyLineBffPlnCrds(:,1), PolyLineBffPlnCrds(:,2));

                case {'Point', 'MultiPoint'}
                    PolyPointBuffPlan  = polybuffer([ShpXPlnTmp, ShpYPlnTmp], 'points', BufferSize);
                    PolyPntBuffPlnCrds = PolyPointBuffPlan.Vertices;
                    [ShpLats, ShpLons] = projinv(PlnRefTemp, PolyPntBuffPlnCrds(:,1), PolyPntBuffPlnCrds(:,2));
    
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
    Inds2Mrg = cell(1, numel(NewUnIDs));
    for i1 = 1:numel(NewUnIDs)
        Inds2Mrg{i1} = find(ismember(LndsUnShIDStudy, NewUnIDs(i1))); % This is relative to LndsUnShIDStudy
    end
    NumDup = cellfun(@numel, Inds2Mrg);
    IndDup = find(NumDup > 1); % This is relative to Inds2Mrg or NumDup
    IDsDup = LndsUnShIDStudy(arrayfun(@(x) Inds2Mrg{x}(1), IndDup));
    WrnStr = ['Attention, ',num2str(numel(IndDup)),' repetitions (IDs: ', ...
              strjoin(IDsDup, ' | '),' for respectively ',num2str(NumDup(IndDup)), ...
              ' times). These reps will be merged into single polygons!'];
    warning(WrnStr)

    LndsUnShIDStudy = NewUnIDs;
    LndsUnOrCrStudy = cellfun(@(x) [LndsUnOrCrStudy{x}], Inds2Mrg, 'UniformOutput',false);
    LndsUnPlysStudy = cellfun(@(x) union([LndsUnPlysStudy(x)]), Inds2Mrg);
end

%% Adding columns
ProgressBar.Message = 'Adding columns to excel table...';

Cntnt = {'OrCrds', 'MrgdPlyg'};
[~, ClNms] = fileparts(erase(FlNmShp, ' '));

CmbsInd = combvec(1:length(Cntnt), 1:length(ClNms));
Cls2Add = cell(2, numel(ClNms));
for i1 = 1:size(CmbsInd,2)
    Cls2Add{CmbsInd(1,i1), CmbsInd(2,i1)} = [Cntnt{CmbsInd(1,i1)},'_',ClNms{CmbsInd(2,i1)}];
end

if isempty(InvLandsTbl)
    InvLandsTbl = array2table(reshape(LndsUnShIDStudy, numel(LndsUnShIDStudy), 1), 'VariableNames',{'ID'});

    Dttm2Wrt = cell(size(InvLandsTbl, 1), 1);
    for i1 = 1:size(InvLandsTbl, 1)
        IndIDwDt = find(ismember(DttmAss(:,1), LndsUnShIDStudy(i1)));
        if isempty(IndIDwDt)
            error('No match between ID of table and original ones!')
        elseif numel(IndIDwDt) >= 2
            PssDates = DttmAss(IndIDwDt, 2);
            IndDtTmp = listdlg2({['Datetime to use for ID ',LndsUnShIDStudy{i1}]}, ...
                                {[DttmAss{IndIDwDt,2}]}, 'OutType','NumInd');
            TmpDates = PssDates(IndDtTmp);
        else
            TmpDates = DttmAss(IndIDwDt, 2);
        end
        Dttm2Wrt(i1) = TmpDates;
    end

    InvLandsTbl.Date = Dttm2Wrt;

    % Cleaning of rows without dates
    EmptyDates = cellfun(@isnat, InvLandsTbl.Date);
    InvLandsTbl(EmptyDates, :) = [];
end

ProgressBar.Indeterminate = 'off';
[InvLandsTbl{:,Cls2Add(1,:)}, InvLandsTbl{:,Cls2Add(2,:)}] = deal(cell(size(InvLandsTbl,1), numel(ClNms)));
% InvLandsTbl{:,Cls2Add(2,:)} = repmat(polyshape, size(InvLandsTbl,1), numel(ClNms));
for i1 = 1:numel(LandsMrgdPolys)
    ProgressBar.Value = i1/numel(LandsMrgdPolys);
    ProgressBar.Message = ['Adding single polygons, shapefile n. ',num2str(i1),' of ',num2str(numel(LandsMrgdPolys))];

    for i2 = 1:numel(LandsMrgdPolys{i1})
        ColConv2Chars  = cellstr(string(InvLandsTbl.(InvTbColID{i1})));
        IndsMatchPolys = ismember(ColConv2Chars, LandsUnShpIDs{i1}(i2));
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

PolyTotalPlan = repmat(polyshape, size(InvLandsTbl,1), 1);
for i1 = 1:size(InvLandsTbl, 1)
    ProgressBar.Value = i1/size(InvLandsTbl,1);
    ProgressBar.Message = ['Evaluation of area n. ',num2str(i1),' of ',num2str(size(InvLandsTbl,1))];

    if not(isempty(InvLandsTbl.PolyTotal{i1}))
        [PolyTotalPlanX, PolyTotalPlanY] = projfwd(PlnRef, InvLandsTbl.PolyTotal{i1}.Vertices(:,2), ...
                                                           InvLandsTbl.PolyTotal{i1}.Vertices(:,1));
        PolyTotalPlan(i1) = polyshape([PolyTotalPlanX, PolyTotalPlanY], 'Simplify',false);
    end
end
ProgressBar.Indeterminate = 'on';

InvLandsTbl.AreaPolyTotal = num2cell(area(PolyTotalPlan));

%% Cleaning of Table
ProgressBar.Message = 'Cleaning of table...';
    
EmptyPolys = (cell2mat(InvLandsTbl.AreaPolyTotal) == 0);
if any(EmptyPolys)
    GenPoly = uiconfirm(Fig, ['Some polygons did not find a match. Do you want ', ...
                              'to generate them as they were point shapefiles?'], ...
                             'Generate polys', 'Options',{'Yes','No'}, 'DefaultOption',1);
    if strcmp(GenPoly, 'Yes'); GenPoly = true; else; GenPoly = false; end
    if GenPoly
        Cols2Tk = listdlg2({'Column of lon:', 'Column of lat:', 'Column of ID'}, InvLandsTbl.Properties.VariableNames);
        CrdMpty = cell2mat(InvLandsTbl{EmptyPolys, Cols2Tk(1:2)}); % First lon, then lat!
        PlyMpty = polybuffpoint2(CrdMpty, BufferSize, uniquePoly=false, coordType='geo')';
        AreMpty = repmat(pi*BufferSize^2, numel(PlyMpty), 1); % Area of a circle (the minimum)!
        InvLandsTbl{EmptyPolys, 'PolyTotal'    } = num2cell(PlyMpty);
        InvLandsTbl{EmptyPolys, 'AreaPolyTotal'} = num2cell(AreMpty);
        LndsUnShIDStudy = [LndsUnShIDStudy, InvLandsTbl{EmptyPolys, Cols2Tk(3)}'];
        LndsUnPlysStudy = [LndsUnPlysStudy, [InvLandsTbl{EmptyPolys, 'PolyTotal'}{:}]];
        LndsUnOrCrStudy = [LndsUnOrCrStudy, ...
                                    cellfun(@(x, y) [x, y], InvLandsTbl{EmptyPolys, Cols2Tk(1)}', ...
                                                            InvLandsTbl{EmptyPolys, Cols2Tk(2)}', 'UniformOutput',false)];

    else
        InvLandsTbl(EmptyPolys,:) = [];
    end
end

if size(InvLandsTbl, 1) == 0
    error(['The inventory of landslides is empty! Probably due ', ...
           'to a mismatch between IDs of shapefiles and excel!'])
end

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
IndEvents  = 1:numel(PmptForDts);

ManFilt = 'Yes';
if numel(PmptForDts) >= 1000
    ManFilt = uiconfirm(Fig, 'There are more than 1000 datetimes, do you want to manually select them?', ...
                             'Manual filter', 'Options',{'Yes', 'No'}, 'DefaultOption',2);
end
if strcmp(ManFilt, 'Yes')
    IndEvents = checkbox2(PmptForDts, 'Title',{'Date(s) to consider: '}, 'OutType','NumInd');
end

DtsChosen  = DttmsLndsUnOrd(IndEvents);
DatesToUse = DtsChosen;

CloseDates = 'No';
if numel(IndEvents) ~= numel(DttmsLndsUnOrd)
    CloseDates = uiconfirm(Fig, 'Do you want to search also for dates near to the one selected?', ...
                                'Near dates', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
end
if strcmp(CloseDates, 'Yes')
    DaysRange  = str2double(inputdlg2({'Days to consider for search: '}, 'DefInp',{'5'}));
    IndDtInRng = cell(1, length(DtsChosen));
    for i1 = 1:length(DtsChosen)
        IndDtInRng{i1} = (DttmsLndsUnOrd >= DtsChosen(i1)-days(DaysRange)) & (DttmsLndsUnOrd <= DtsChosen(i1)+days(DaysRange));
    end

    IndEvntsNw = find(any([IndDtInRng{:}], 2));
    DatesToUse = DttmsLndsUnOrd(IndEvntsNw);
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
MstVars = {'Municipality', 'ID', 'Latitude', 'Longitude', 'Date', 'Area'};
[Vars2Tk, VarLbls] = listdlg2(MstVars, TblCols, 'PairLabels',true, 'Extendable',true, 'DefLabels',MstVars);
Cont2Write  = InvLandsTbl{IndsToTakeFilt, Vars2Tk};
IndsMissing = cellfun(@(x) all(ismissing(x)), Cont2Write);
Cont2Write(IndsMissing) = {'Missing'};

FlNmID = 'IDsFromShape.xlsx';
DataToWrite  = [VarLbls; Cont2Write];
writecell(DataToWrite, [fold_user,sl,FlNmID])
warning([FlNmID,' generated! You should go in "User Control", open ' ...
         'it for a check, and then move it in "Raw Data -> Detected Soil Slips"'])

%% General landslides summary writing
ProgressBar.Message = 'Creation of General Landslides table...';

GeneralLandslidesSummary = table(DttmsLndsUnOrd, LndsPerDtUnOrd, 'VariableNames',{'Datetime','NumOfLandslides'});

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

CheckNumLands = isequal(sum(LandsPerDatePerMun, 2), GeneralLandslidesSummary.NumOfLandslides);
if not(CheckNumLands)
    error('Landslides number in LandslidesCountPerMun does not match GeneralLandslidesSummary!')
end

LandslidesCountPerMun = [GeneralLandslidesSummary(:,'Datetime'), array2table(LandsPerDatePerMun, 'VariableNames',MunsUnique)];

%% Plot for check
ProgressBar.Message = 'Plotting for check...';

fig_check = figure(1);
axs_check = axes(fig_check);
hold(axs_check,'on')

plot(LndsUnPlysStudy)
title('Landslides polygon check')
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

VariablesLnds = {'LndsUnPlysStudy', 'LndsUnShIDStudy', 'LndsUnOrCrStudy', 'FlNmShp', 'ShpPath'};
save([fold_var,sl,'SoilSlipPolygonsStudyArea.mat'], VariablesLnds{:});

VariablesLndsTbl = {'InvLandsTbl', 'GeneralLandslidesSummary', 'LandslidesCountPerMun'};
save([fold_var,sl,'LandslidesInfo.mat'], VariablesLndsTbl{:})

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version