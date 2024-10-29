function [assCsTbl, parUCTbl] = read_association_spreadsheet(filePath, polygons, polyNames, Options)

arguments
    filePath (1,:) char {mustBeFile}
    polygons (:,:) polyshape {mustBeVector}
    polyNames (:,:) cell {mustBeVector}
    Options.fileType (1,:) char = '';
    Options.classCol (1,1) double = nan;
    Options.slColors (1,2) logical = [false, false];
    Options.alertFig (1,1) = nan
end

%% Input check
fileType = lower(Options.fileType);
classCol = Options.classCol;
slColors = Options.slColors;
alertFig = Options.alertFig;

manualCs = slColors(1);
manualUC = slColors(2);

if isempty(fileType)
    fileType = lower(char(listdlg2({'File info type:'}, {'Soil', 'Vegetation'})));
end

if numel(polygons) ~= numel(polyNames)
    error('Sizes of [polygons] and [polyNames] inputs must be the same!')
end

alrtExist = isa(alertFig, 'matlab.ui.Figure');
if not(alrtExist) && not(isnan(alertFig))
    error('alertFig must be a matlab.ui.Figure class!')
end

%% Initialization
switch fileType
    case 'soil'
        sheetAssnName = 'Association';
        sheetPrmsName = 'DSCParameters';
        assCsColNames = {'LU Abbrev', 'RGB LU', 'US Associated'}; % It is important the order!
        parUCColNames = {'US', 'Color', 'c''', 'phi', 'kt', 'A (', 'n'}; % It is important the order (first two)!
        optUCColNames = {'c', 'phi', 'kt', 'A', 'n'}; % NOTE: they must be same order of parUCColNames, excluding first 2!

    case 'vegetation'
        sheetAssnName = 'Association';
        sheetPrmsName = 'DVCParameters';
        assCsColNames = {'VU Abbrev', 'RGB VU', 'UV Associated'}; % It is important the order!
        parUCColNames = {'UV','Color', 'c_R''','beta'}; % It is important the order (first two)!
        optUCColNames = {'cr', 'beta'}; % NOTE: they must be same order of parUCColNames, excluding first 2!

    otherwise
        error('File info type not recognized!')
end

assCsColLbls = {'Acronym', 'Color', 'UC'};
parUCColLbls = [{'UC', 'Color'}, optUCColNames];

errMsgCsClrs = strcat("An error occurred while reading colors of [",{sheetAssnName, sheetPrmsName}, ...
                      "] sheet (see Command Window), but do not worry: random colors will be generated.");

%% Reading and identification of headings
sheet_Ass = readcell(filePath, 'Sheet',sheetAssnName);
sheet_Par = readcell(filePath, 'Sheet',sheetPrmsName);

fstRowAss = find(cellfun(@(x) not(all(ismissing(x))), sheet_Ass(:, 2)), 1);
fstRowPar = find(cellfun(@(x) not(all(ismissing(x))), sheet_Par(:, 2)), 1);

if isnan(classCol)
    fstColAss = find(cellfun(@(x) not(all(ismissing(x))), sheet_Ass(2, :)), 1);
else
    fstColAss = classCol;
end

hdrRowAss = sheet_Ass(fstRowAss, :);
hdrRowPar = sheet_Par(fstRowPar, :);

%% Finding column indices
assLblCol = zeros(size(assCsColNames));
for i1 = 1:numel(assCsColNames)
    indColTmp = find(contains(hdrRowAss, assCsColNames{i1}, 'IgnoreCase',true));
    if isscalar(indColTmp)
        assLblCol(i1) = indColTmp;
    end
end

parLblCol = zeros(size(parUCColNames));
for i1 = 1:numel(parUCColNames)
    indColTmp = find(contains(hdrRowPar, parUCColNames{i1}, 'IgnoreCase',true));
    if isscalar(indColTmp)
        parLblCol(i1) = indColTmp;
    end
end

if not(all(assLblCol))
    assLblCol(assLblCol==0) = listdlg2(strcat(assCsColNames(assLblCol==0), ' column:'), hdrRowAss, 'OutType','NumInd');
end

if not(all(parLblCol))
    parLblCol(parLblCol==0) = listdlg2(strcat(parUCColNames(parLblCol==0), ' column:'), hdrRowPar, 'OutType','NumInd');
end

assLblCol = array2table(assLblCol, 'VariableNames',assCsColLbls(1:numel(assLblCol)));
parLblCol = array2table(parLblCol, 'VariableNames',parUCColLbls(1:numel(parLblCol)));

%% Extraction of data for assCsTbl
assCsOrg = sheet_Ass((fstRowAss + 1) : size(sheet_Ass, 1), fstColAss              ); % (fstRowAss + 1) to discard the first header row
assCs2UC = sheet_Ass((fstRowAss + 1) : size(sheet_Ass, 1), assLblCol{1, 'UC'     }); % (fstRowAss + 1) to discard the first header row
assCsAbb = sheet_Ass((fstRowAss + 1) : size(sheet_Ass, 1), assLblCol{1, 'Acronym'}); % (fstRowAss + 1) to discard the first header row
assCsClr = sheet_Ass((fstRowAss + 1) : size(sheet_Ass, 1), assLblCol{1, 'Color'  }); % (fstRowAss + 1) to discard the first header row

rowSelCs = find(cellfun(@(x) not(ismissing(x)), assCs2UC));
if isempty(rowSelCs); error(['Excel is empty in the association column! ', ...
                             'Please fill it with numbers of homogenized units!']); end

% Just associated classes, not all!
assCsOrg = string(assCsOrg(rowSelCs, :));
assCs2UC = cell2mat(assCs2UC(rowSelCs, :));
assCsAbb = string(assCsAbb(rowSelCs, :));
assCsPly = repmat(polyshape, numel(assCs2UC), 1); % Initialization
assCsClr = assCsClr(rowSelCs, :);
if not(iscell(assCsClr)); assCsClr = num2cell(assCsClr); end

assCsTbl = table(assCsOrg, assCs2UC, assCsAbb, ...
                 assCsPly, assCsClr, 'VariableNames',{'Class', 'UC', 'Acronym', 'Polygon', 'Color'});

rows2Rem = false(size(assCsTbl, 1), 1);
for i1 = 1:size(assCsTbl, 1)
    tempInd = find(strcmp(assCsTbl{i1, 'Class'}, polyNames));
    if isscalar(tempInd)
        assCsTbl{i1, 'Polygon'} = polygons(tempInd);

    elseif isempty(tempInd)
        rows2Rem(i1) = true;

    else
        error(strcat("Multiple matches for [",assCsTbl{i1, 'Class'},"] class"))
    end
end

if any(rows2Rem)
    warning(['Classes [',char(strjoin(assCsTbl{rows2Rem, 'Class'}, '; ')), ...
             '] did not find matches, they will be excluded!'])
    assCsTbl(rows2Rem, :) = [];
end

%% Extraction of data for parUSTbl
parUCNum = sheet_Par((fstRowPar + 1) : size(sheet_Par, 1), parLblCol{1, 'UC'   }); % (fstRowPar + 1) to discard the first header row
parUCClr = sheet_Par((fstRowPar + 1) : size(sheet_Par, 1), parLblCol{1, 'Color'}); % (fstRowPar + 1) to discard the first header row

parUCOpt = cell(1, numel(optUCColNames)); % Optional parameters should be always numeric!!
for i1 = 1:numel(optUCColNames)
    parUCOpt{i1} = sheet_Par((fstRowPar + 1) : size(sheet_Par, 1), parLblCol{1, optUCColNames{i1}});
end

% Conversion from cell
parUCNum = cell2mat(parUCNum);
for i1 = 1:numel(parUCOpt)
    parUCOpt{i1} = cell2mat(parUCOpt{i1});
end
parUCPly = repmat(polyshape, numel(parUCNum), 1); % Initialization

parUCTbl = table(parUCNum, parUCOpt{:}, parUCPly, parUCClr, 'VariableNames',[{'UC'}, optUCColNames, {'Polygon', 'Color'}]);

rows2Rem = false(size(parUCTbl, 1), 1);
for i1 = 1:size(parUCTbl, 1)
    tempInd = find(parUCTbl{i1, 'UC'} == assCsTbl{:, 'UC'});
    if isempty(tempInd)
        rows2Rem(i1) = true;

    else
        parUCTbl{i1, 'Polygon'} = union(assCsTbl{tempInd, 'Polygon'});
    end
end

if any(rows2Rem)
    warning(['UC [',char(strjoin(string(parUCTbl{rows2Rem, 'UC'}), '; ')), ...
             '] were not used, they will be excluded!'])
    parUCTbl(rows2Rem, :) = [];
end

%% Check or creation of colors
if manualCs
    for i1 = 1:size(assCsTbl,1)
        assCsTbl{i1, 'Color'} = {uisetcolor(strcat("Color for ",assCsTbl{i1, 'Acronym'})).*255};
    end

else
    try
        assCsTbl{: , 'Color'} = num2cell(readcolors(assCsTbl{:, 'Color'}), 2);
    catch me
        getReport(me)
        if alrtExist
            uialert(alertFig, errMsgCsClrs(1), 'Cs Color Error')
        end
        assCsTbl{: , 'Color'} = num2cell(ceil(rand(size(assCsTbl,1), 3).*255), 2);
    end
end

if manualUC
    for i1 = 1:(size(sheet_Par,1)-1)
        parUCTbl{i1, 'Color'} = {uisetcolor(strcat( "Color for UC ",num2str(parUCTbl{i1,'UC'}) )).*255};
    end

else
    try
        parUCTbl{: , 'Color'} = num2cell(readcolors(parUCTbl{:, 'Color'}), 2);
    catch me
        getReport(me)
        if alrtExist
            uialert(alertFig, errMsgCsClrs(2), 'UC Color Error')
        end
        parUCTbl{: , 'Color'} = num2cell(ceil(rand(size(parUCTbl,1), 3).*255), 2);
    end
end

end