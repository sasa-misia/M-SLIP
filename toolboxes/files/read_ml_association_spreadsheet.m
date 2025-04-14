function infoML = read_ml_association_spreadsheet(filePath)

arguments
    filePath (1,:) char {mustBeFile}
end

sheetCntN = {'Sub soil', 'Top soil', 'Land use', 'Vegetation'}; % The order is important! These are the names of the sheets with raw classes.
sheetColM = {'Title', 'Number', 'Description'}; % The order is important! These are the names of the columns of main sheet
sheetColR = {'Raw data name', 'Ass. class'}; % The order is important! These are the names of the columns of raw sheets

sheetMain = readcell(filePath, 'Sheet','Main');
sheetRaws = cell(1, numel(sheetCntN));
for i1 = 1:numel(sheetCntN)
    sheetRaws{i1} = readcell(filePath, 'Sheet',sheetCntN{i1});
end

[colTitle, colClass, colDescr] = deal(false(1, size(sheetMain, 2)));
for i1 = 1:numel(colTitle)
    colTitle(i1) = any(cellfun(@(x) strcmp(string(x), sheetColM{1}), sheetMain(:,i1)));
    colClass(i1) = any(cellfun(@(x) strcmp(string(x), sheetColM{2}), sheetMain(:,i1)));
    colDescr(i1) = any(cellfun(@(x) strcmp(string(x), sheetColM{3}), sheetMain(:,i1)));
end
colSubjt = find(colTitle)-1;

if sum(colTitle) > 1 || sum(colClass) > 1 || sum(colDescr) > 1
    error('Please, align columns in excel! Sheet: Main')
end

indBlnkRows = all(cellfun(@(x) all(ismissing(x)), sheetMain), 2);
indBlnkClss = cellfun(@(x) all(ismissing(x)), sheetMain(:,colClass));

if not(isequal(indBlnkRows, indBlnkClss))
    error('Please fill with data only tables with association, nothing else outside!')
end

sheetMainSpl = mat2cell(sheetMain, diff(find([true; diff(not(indBlnkRows)); true]))); % Line suggested by ChatGPT. It works, but check it better!

indSplits = zeros(size(sheetCntN));
for i1 = 1:length(indSplits)
    indSplits(i1) = find(cellfun(@(x) any(strcmp(sheetCntN{i1}, string([x(:,colSubjt)]))), sheetMainSpl));
end

sheetMainCell = sheetMainSpl(indSplits)'; % It will have same order of sheetCntN

[glbClss, glbNumb, glbDscr] = deal(cell(1, numel(sheetCntN)));
for i1 = 1:numel(sheetCntN)
    glbClss{i1} = string(sheetMainCell{i1}(2:end, colTitle)); % 2:end to avoid title column!
    glbNumb{i1} = cell2mat(sheetMainCell{i1}(2:end, colClass)); % 2:end to avoid title column!
    glbDscr{i1} = sheetMainCell{i1}(2:end, colDescr); % 2:end to avoid title column!
    if numel(unique(glbClss{i1})) ~= numel(glbClss{i1})
        error([sheetCntN{i1},' Classes column in Main sheet of association', ...
               ' excel must be unique! There are repetitions, check it!'])
    end
    if not(isnumeric(glbNumb{i1}))
        error([sheetCntN{i1},' Number column in Main sheet of ', ...
              'association excel does not contain numeric values!'])
    end
end

[rawClss, rawNumb] = deal(cell(1, numel(sheetCntN)));
for i1 = 1:numel(sheetRaws)
    [colRawClss, colRawAssC] = deal(false(1, size(sheetRaws{i1}, 2)));
    for i2 = 1:numel(colRawClss)
        colRawClss(i2) = any(cellfun(@(x) strcmp(string(x), sheetColR{1}), sheetRaws{i1}(:,i2)));
        colRawAssC(i2) = any(cellfun(@(x) strcmp(string(x), sheetColR{2}), sheetRaws{i1}(:,i2)));
    end
    if sum(colRawClss) > 1 || sum(colRawAssC) > 1
        error([sheetCntN{i1},' sheet must contain these columns once: ',strjoin(sheetColR, '; ')])
    end

    rawClss{i1} = string(sheetRaws{i1}(2:end, colRawClss)); % 2:end to avoid title column!

    rawNumbTemp = sheetRaws{i1}(2:end, colRawAssC); % 2:end to avoid title column!
    ind2Replace = cellfun(@isempty, rawNumbTemp) | cellfun(@(x) all(ismissing(x)), rawNumbTemp);
    rawNumbTemp(ind2Replace) = {NaN};
    rawNumb{i1} = cell2mat(rawNumbTemp);

    ind2Delete  = rawClss{i1} == ""; % Empty classes!
    rawClss{i1}(ind2Delete) = [];
    rawNumb{i1}(ind2Delete) = [];

    if numel(unique(rawClss{i1})) ~= numel(rawClss{i1})
        error(['There are repetitions in raw classes of sheet: ',sheetCntN{i1}])
    end
end

infoML = cell2table(cell(2, numel(sheetCntN)), 'VariableNames',sheetCntN, 'RowNames',{'Global', 'Raw'});
for i1 = 1:numel(sheetCntN)
    infoML{'Global', sheetCntN{i1}} = {table(glbClss{i1}, glbNumb{i1}, glbDscr{i1}, 'VariableNames',sheetColM)};
    infoML{'Raw'   , sheetCntN{i1}} = {table(rawClss{i1}, rawNumb{i1}, 'VariableNames',sheetColR)};
end

end