function DatasetsExtracted = dataset_extraction(datasetInfo, Options)

% EXTRACT DATASET FROM DATASETINFO TABLE (M-SLIP Internal function)
%   
% Outputs:
%   Datasets: table containing all the possible datasets to extract.
%   
% Required arguments:
%   - DatasetInfo : table or structure containing datasets info (both model
%   A or B). Feats, x.Features and x.Outputs fields must be present!
%   
% Optional arguments:
%   - 'ReplaceValues', logical : is to declare if you want to replace some
%   values in the features dataset. If no entry is specified, then false 
%   will be assumed as default!
%   
%   - 'ValuesAssociation', numeric : is to declare what values you want to
%   replace (1st column) and the new replacing ones (2nd column). It must
%   be a nx2 numeric matrix. If no entry is specified, then [NaN, 0] will
%   be assumed as default! Note: it will not have effect if ReplaceValues
%   is set to false!
%   
%   - 'FeatsNumeric', logical : is to declare if you want to output the
%   features as numeric (in case some categorical features exist). If no
%   value is specified, then false will be assumed as default!

%% Arguments
arguments
    datasetInfo (:,:)
    Options.ReplaceValues (1,1) logical = false
    Options.ValuesAssociation (:,2) double = [NaN, 0]
    Options.FeatsNumeric (1,1) logical = false;
end

RepVals = Options.ReplaceValues;
ValsAss = Options.ValuesAssociation;
NmFeats = Options.FeatsNumeric;

%% Check inputs
if not(istable(datasetInfo) || isstruct(datasetInfo))
    error('Dataset with dates (1st argument) must be in a cell and must be congruent with other datasets!')
end

if isstruct(datasetInfo) % Before the check of table! (otherwise it is always struct...)
    datasetInfo = datasetInfo';
end

if istable(datasetInfo)
    datasetInfo = table2struct(datasetInfo);
end

if size(datasetInfo, 2) > 1
    error('There is an error with sizes of DatasetInfo, please check it!')
end

FldsOf1st = fieldnames(datasetInfo(1).Datasets);
FtsNms1st = datasetInfo(1).Datasets.Feats;
DtsNms1st = fieldnames(datasetInfo(1).Datasets.Total);
for i1 = 1:length(datasetInfo) % In case of Table could be wrong!!!
    ChckEqFds = isequal(FldsOf1st, fieldnames(datasetInfo(i1).Datasets));
    ChckEqFts = isequal(FtsNms1st, datasetInfo(i1).Datasets.Feats);
    ChckEqDts = isequal(DtsNms1st, fieldnames(datasetInfo(i1).Datasets.Total));
    if not(ChckEqFds)
        error(['The fields of the dataset n. ',num2str(i1),' are different from the 1st!'])
    end
    if not(ChckEqFts)
        error(['The features of the dataset n. ',num2str(i1),' are different from the 1st!'])
    end
    if not(ChckEqDts)
        error(['The type of datasets for dataset n. ',num2str(i1),' are different from the 1st!'])
    end
end

ExtraDset = false;
IdDstExtr = not(ismember(DtsNms1st, {'Features', 'Outputs'}));
FtsNmExtr = DtsNms1st(IdDstExtr); % Extra features
if not(isempty(FtsNmExtr))
    ExtraDset = true;
end

if not(islogical(RepVals) && isscalar(RepVals))
    error('ReplaceValues must be logical and single!')
end

if not(isnumeric(ValsAss) && (size(ValsAss, 2)==2))
    error('ValuesAssociation must be numeric and must contain 2 columns!')
end

if not(islogical(NmFeats) && isscalar(NmFeats))
    error('FeatsNumeric must be logical and single!')
end

%% Options
NormVal = false;
if any(strcmp(FldsOf1st, 'NvTrain')) && any(strcmp(FldsOf1st, 'NvValid'))
    NormVal = true;
end

CrossVal = false;
if any(strcmp(FldsOf1st, 'CvValid'))
    CrossVal = true;
end

%% Core
%% Initialization
[DsetFeatsTotTmp, DsetFeatsTrnTmp, DsetFeatsTstTmp, ...
    ExpctOutsTotTmp, ExpctOutsTrnTmp, ExpctOutsTstTmp] = deal(cell(size(datasetInfo,1), 1));
if NormVal
    [DsetFeatsNvTrnTmp, DsetFeatsNvValTmp, ...
        ExpctOutsNvTrnTmp, ExpctOutsNvValTmp] = deal(cell(size(datasetInfo,1), 1));
end
if CrossVal
    [DsetFeatsCvTrnTmp, DsetFeatsCvValTmp, ...
        ExpctOutsCvTrnTmp, ExpctOutsCvValTmp] = deal(cell(size(datasetInfo,1), ...
                                                          numel(datasetInfo(1).Datasets.CvValid)));
end

if ExtraDset
    [DsetExtraTotTmp, DsetExtraTrnTmp, DsetExtraTstTmp] = deal(cell(size(datasetInfo,1), numel(FtsNmExtr)));
    if NormVal
        [DsetExtraNvTrnTmp, DsetExtraNvValTmp] = deal(cell(size(datasetInfo,1), numel(FtsNmExtr)));
    end
    if CrossVal
        [DsetExtraCvTrnTmp, DsetExtraCvValTmp] = deal(cell(1, numel(FtsNmExtr)));
        for i1 = 1:numel(FtsNmExtr)
            [DsetExtraCvTrnTmp{i1}, DsetExtraCvValTmp{i1}] = deal(cell(size(datasetInfo,1), ...
                                                                       numel(datasetInfo(1).Datasets.CvValid)));
        end
    end
end

%% Extraction
for i1 = 1:size(datasetInfo,1)
    DsetFeatsTotTmp{i1} = datasetInfo(i1).Datasets.Total.Features;
    DsetFeatsTrnTmp{i1} = datasetInfo(i1).Datasets.Train.Features;
    DsetFeatsTstTmp{i1} = datasetInfo(i1).Datasets.Test.Features;
    
    ExpctOutsTotTmp{i1} = datasetInfo(i1).Datasets.Total.Outputs;
    ExpctOutsTrnTmp{i1} = datasetInfo(i1).Datasets.Train.Outputs;
    ExpctOutsTstTmp{i1} = datasetInfo(i1).Datasets.Test.Outputs;

    if NormVal
        DsetFeatsNvTrnTmp{i1} = datasetInfo(i1).Datasets.NvTrain.Features;
        DsetFeatsNvValTmp{i1} = datasetInfo(i1).Datasets.NvValid.Features;

        ExpctOutsNvTrnTmp{i1} = datasetInfo(i1).Datasets.NvTrain.Outputs;
        ExpctOutsNvValTmp{i1} = datasetInfo(i1).Datasets.NvValid.Outputs;
    end
    
    if CrossVal
        for i2 = 1:numel(datasetInfo(1).Datasets.CvValid)
            DsetFeatsCvValTmp{i1,i2} = datasetInfo(i1).Datasets.CvValid(i2).Features;
            ExpctOutsCvValTmp{i1,i2} = datasetInfo(i1).Datasets.CvValid(i2).Outputs;
        end
    end

    if ExtraDset % Extra part
        for i2 = 1:numel(FtsNmExtr)
            DsetExtraTotTmp{i1,i2} = datasetInfo(i1).Datasets.Total.(FtsNmExtr{i2});
            DsetExtraTrnTmp{i1,i2} = datasetInfo(i1).Datasets.Train.(FtsNmExtr{i2});
            DsetExtraTstTmp{i1,i2} = datasetInfo(i1).Datasets.Test.(FtsNmExtr{i2});

            if NormVal
                DsetExtraNvTrnTmp{i1,i2} = datasetInfo(i1).Datasets.NvTrain.(FtsNmExtr{i2});
                DsetExtraNvValTmp{i1,i2} = datasetInfo(i1).Datasets.NvValid.(FtsNmExtr{i2});
            end
    
            if CrossVal
                for i3 = 1:numel(datasetInfo(1).Datasets.CvValid)
                    DsetExtraCvValTmp{i2}{i1,i3} = datasetInfo(i1).Datasets.CvValid(i3).(FtsNmExtr{i2});
                end
            end
        end
    end
end

% Creation of Cv train
if CrossVal
    for i1 = 1:size(datasetInfo,1)
        for i2 = 1:numel(datasetInfo(1).Datasets.CvValid)
            Ids2TkTmp = true(1, numel(datasetInfo(1).Datasets.CvValid));
            Ids2TkTmp(i2) = false;

            DsetFeatsCvTrnTmp{i1,i2} = cat(1, datasetInfo(i1).Datasets.CvValid(Ids2TkTmp).Features);
            ExpctOutsCvTrnTmp{i1,i2} = cat(1, datasetInfo(i1).Datasets.CvValid(Ids2TkTmp).Outputs );

            if ExtraDset % Extra part
                for i3 = 1:numel(FtsNmExtr)
                    DsetExtraCvTrnTmp{i3}{i1,i2} = cat(1, datasetInfo(i1).Datasets.CvValid(Ids2TkTmp).(FtsNmExtr{i3}));
                end
            end
        end
    end
end

%% Concatenation
DsetFeatsTot = cat(1, DsetFeatsTotTmp{:});
DsetFeatsTrn = cat(1, DsetFeatsTrnTmp{:});
DsetFeatsTst = cat(1, DsetFeatsTstTmp{:});

ExpctOutsTot = cat(1, ExpctOutsTotTmp{:});
ExpctOutsTrn = cat(1, ExpctOutsTrnTmp{:});
ExpctOutsTst = cat(1, ExpctOutsTstTmp{:});

if NormVal
    DsetFeatsNvTrn = cat(1, DsetFeatsNvTrnTmp{:});
    DsetFeatsNvVal = cat(1, DsetFeatsNvValTmp{:});

    ExpctOutsNvTrn = cat(1, ExpctOutsNvTrnTmp{:});
    ExpctOutsNvVal = cat(1, ExpctOutsNvValTmp{:});
end

if CrossVal
    [DsetFeatsCvTrn, DsetFeatsCvVal, ...
        ExpctOutsCvTrn, ExpctOutsCvVal] = deal(cell(1, size(DsetFeatsCvTrnTmp, 2)));
    for i1 = 1:size(DsetFeatsCvTrnTmp, 2)
        DsetFeatsCvTrn{i1} = cat(1, DsetFeatsCvTrnTmp{:,i1});
        DsetFeatsCvVal{i1} = cat(1, DsetFeatsCvValTmp{:,i1});
    
        ExpctOutsCvTrn{i1} = cat(1, ExpctOutsCvTrnTmp{:,i1});
        ExpctOutsCvVal{i1} = cat(1, ExpctOutsCvValTmp{:,i1});
    end
end

if ExtraDset
    [DsetExtraTot, DsetExtraTrn, DsetExtraTst] = deal(cell(1, numel(FtsNmExtr)));
    if NormVal
        [DsetExtraNvTrn, DsetExtraNvVal] = deal(cell(1, numel(FtsNmExtr)));
    end
    if CrossVal
        [DsetExtraCvTrn, DsetExtraCvVal] = deal(cell(1, numel(FtsNmExtr)));
        for i1 = 1:numel(FtsNmExtr)
            [DsetExtraCvTrn{i1}, DsetExtraCvVal{i1}] = deal(cell(1, size(DsetExtraCvTrnTmp{i1}, 2)));
        end
    end

    for i1 = 1:numel(FtsNmExtr)
        DsetExtraTot{i1} = cat(1, DsetExtraTotTmp{:,i1});
        DsetExtraTrn{i1} = cat(1, DsetExtraTrnTmp{:,i1});
        DsetExtraTst{i1} = cat(1, DsetExtraTstTmp{:,i1});

        if NormVal
            DsetExtraNvTrn{i1} = cat(1, DsetExtraNvTrnTmp{:,i1});
            DsetExtraNvVal{i1} = cat(1, DsetExtraNvValTmp{:,i1});
        end

        if CrossVal
            for i2 = 1:size(DsetExtraCvTrnTmp{i1}, 2)
                DsetExtraCvTrn{i1}{i2} = cat(1, DsetExtraCvTrnTmp{i1}{:,i2});
                DsetExtraCvVal{i1}{i2} = cat(1, DsetExtraCvValTmp{i1}{:,i2});
            end
        end
    end
end

%% Conversion into numeric (just for filtering)
DsetFeatsTotNum = DsetFeatsTot;
DsetFeatsTrnNum = DsetFeatsTrn;
DsetFeatsTstNum = DsetFeatsTst;

ColsNoNumTot = varfun(@(x) not(isnumeric(x)), DsetFeatsTotNum, 'OutputFormat','uniform');
ColsNoNumTrn = varfun(@(x) not(isnumeric(x)), DsetFeatsTrnNum, 'OutputFormat','uniform');
ColsNoNumTst = varfun(@(x) not(isnumeric(x)), DsetFeatsTstNum, 'OutputFormat','uniform');

DsetFeatsTotNum(:,ColsNoNumTot) = array2table(repmat(-999, size(DsetFeatsTotNum,1), sum(ColsNoNumTot))); % Necessary, otherwise table2array would not work!
DsetFeatsTrnNum(:,ColsNoNumTrn) = array2table(repmat(-999, size(DsetFeatsTrnNum,1), sum(ColsNoNumTrn))); % Necessary, otherwise table2array would not work!
DsetFeatsTstNum(:,ColsNoNumTst) = array2table(repmat(-999, size(DsetFeatsTstNum,1), sum(ColsNoNumTst))); % Necessary, otherwise table2array would not work!

if NormVal
    DsetFeatsNvTrnNum = DsetFeatsNvTrn;
    DsetFeatsNvValNum = DsetFeatsNvVal;
    
    ColsNoNumNvTrn = varfun(@(x) not(isnumeric(x)), DsetFeatsNvTrnNum, 'OutputFormat','uniform');
    ColsNoNumNvVal = varfun(@(x) not(isnumeric(x)), DsetFeatsNvValNum, 'OutputFormat','uniform');
    
    DsetFeatsNvTrnNum(:,ColsNoNumNvTrn) = array2table(repmat(-999, size(DsetFeatsNvTrnNum,1), sum(ColsNoNumNvTrn))); % Necessary, otherwise table2array would not work!
    DsetFeatsNvValNum(:,ColsNoNumNvVal) = array2table(repmat(-999, size(DsetFeatsNvValNum,1), sum(ColsNoNumNvVal))); % Necessary, otherwise table2array would not work!
end

if CrossVal
    [DsetFeatsCvTrnNum, DsetFeatsCvValNum, ...
        ColsNoNumCvTrn, ColsNoNumCvVal] = deal(cell(size(DsetFeatsCvTrn)));
    for i1 = 1:size(DsetFeatsCvTrn, 2)
        DsetFeatsCvTrnNum{i1} = DsetFeatsCvTrn{i1};
        DsetFeatsCvValNum{i1} = DsetFeatsCvVal{i1};
        
        ColsNoNumCvTrn{i1} = varfun(@(x) not(isnumeric(x)), DsetFeatsCvTrnNum{i1}, 'OutputFormat','uniform');
        ColsNoNumCvVal{i1} = varfun(@(x) not(isnumeric(x)), DsetFeatsCvValNum{i1}, 'OutputFormat','uniform');
        
        DsetFeatsCvTrnNum{i1}(:,ColsNoNumCvTrn{i1}) = array2table(repmat(-999, size(DsetFeatsCvTrnNum{i1},1), sum(ColsNoNumCvTrn{i1}))); % Necessary, otherwise table2array would not work!
        DsetFeatsCvValNum{i1}(:,ColsNoNumCvVal{i1}) = array2table(repmat(-999, size(DsetFeatsCvValNum{i1},1), sum(ColsNoNumCvVal{i1}))); % Necessary, otherwise table2array would not work!
    end
end

%% Conversion from cat to num (eventual)
if NmFeats
    Cols2CnvTot = find(ColsNoNumTot); Cols2CnvTrn = find(ColsNoNumTrn); Cols2CnvTst = find(ColsNoNumTst);

    if not(isequal(Cols2CnvTot, Cols2CnvTrn, Cols2CnvTst))
        error('Column to convert must be the same for Total, Train, and Test datasets!')
    end

    for i1 = 1:numel(Cols2CnvTot)
        if not(iscategorical(DsetFeatsTot{:,Cols2CnvTot(i1)}) && ...
               iscategorical(DsetFeatsTrn{:,Cols2CnvTrn(i1)}) && ...
               iscategorical(DsetFeatsTst{:,Cols2CnvTst(i1)}))
            error('The column to convert into numeric must be categorical!')
        end
        DsetFeatsTot(:,Cols2CnvTot(i1)) = array2table(grp2idx(DsetFeatsTot{:,Cols2CnvTot(i1)}));
        DsetFeatsTrn(:,Cols2CnvTrn(i1)) = array2table(grp2idx(DsetFeatsTrn{:,Cols2CnvTrn(i1)}));
        DsetFeatsTst(:,Cols2CnvTst(i1)) = array2table(grp2idx(DsetFeatsTst{:,Cols2CnvTst(i1)}));
    end

    if NormVal
        Cols2CnvNvTrn = find(ColsNoNumNvTrn); Cols2CnvNvVal = find(ColsNoNumNvVal);
    
        if not(isequal(Cols2CnvNvTrn, Cols2CnvNvVal))
            error('Column to convert must be the same for NvTrain and NvValid datasets!')
        end
    
        for i1 = 1:numel(Cols2CnvNvTrn)
            if not(iscategorical(DsetFeatsNvTrn{:,Cols2CnvNvTrn(i1)}) && ...
                   iscategorical(DsetFeatsNvVal{:,Cols2CnvNvVal(i1)}))
                error('The column to convert into numeric must be categorical!')
            end
            DsetFeatsNvTrn(:,Cols2CnvNvTrn(i1)) = array2table(grp2idx(DsetFeatsNvTrn{:,Cols2CnvNvTrn(i1)}));
            DsetFeatsNvVal(:,Cols2CnvNvVal(i1)) = array2table(grp2idx(DsetFeatsNvVal{:,Cols2CnvNvVal(i1)}));
        end
    end

    if CrossVal
        for i1 = 1:numel(ColsNoNumCvTrn)
            Cols2CnvCvTrn = find(ColsNoNumCvTrn{i1}); Cols2CnvCvVal = find(ColsNoNumCvVal{i1});
        
            if not(isequal(Cols2CnvCvTrn, Cols2CnvCvVal))
                error('Column to convert must be the same for CvTrain and CvValid datasets!')
            end
        
            for i2 = 1:numel(Cols2CnvCvTrn)
                if not(iscategorical(DsetFeatsCvTrn{i1}{:,Cols2CnvCvTrn(i2)}) && ...
                       iscategorical(DsetFeatsCvVal{i1}{:,Cols2CnvCvVal(i2)}))
                    error('The column to convert into numeric must be categorical!')
                end
                DsetFeatsCvTrn{i1}(:,Cols2CnvCvTrn(i2)) = array2table(grp2idx(DsetFeatsCvTrn{i1}{:,Cols2CnvCvTrn(i2)}));
                DsetFeatsCvVal{i1}(:,Cols2CnvCvVal(i2)) = array2table(grp2idx(DsetFeatsCvVal{i1}{:,Cols2CnvCvVal(i2)}));
            end
        end
    end
end

%% Replacing values
if RepVals
    for i1 = 1:size(ValsAss,1)
        
        Ids2RepTot = table2array(DsetFeatsTotNum) == ValsAss(i1,1) | and(isnan(table2array(DsetFeatsTotNum)), isnan(ValsAss(i1,1)));
        Ids2RepTrn = table2array(DsetFeatsTrnNum) == ValsAss(i1,1) | and(isnan(table2array(DsetFeatsTrnNum)), isnan(ValsAss(i1,1)));
        Ids2RepTst = table2array(DsetFeatsTstNum) == ValsAss(i1,1) | and(isnan(table2array(DsetFeatsTstNum)), isnan(ValsAss(i1,1)));

        for i2 = 1:size(Ids2RepTot,2)
            DsetFeatsTot{Ids2RepTot(:,i2), i2} = ValsAss(i1,2);
            DsetFeatsTrn{Ids2RepTrn(:,i2), i2} = ValsAss(i1,2);
            DsetFeatsTst{Ids2RepTst(:,i2), i2} = ValsAss(i1,2);

            DsetFeatsTotNum{Ids2RepTot(:,i2), i2} = ValsAss(i1,2); % Necessary here because otherwise below you will read again old vals!
            DsetFeatsTrnNum{Ids2RepTrn(:,i2), i2} = ValsAss(i1,2); % Necessary here because otherwise below you will read again old vals!
            DsetFeatsTstNum{Ids2RepTst(:,i2), i2} = ValsAss(i1,2); % Necessary here because otherwise below you will read again old vals!
        end

        if NormVal
            Ids2RepNvTrn = table2array(DsetFeatsNvTrnNum) == ValsAss(i1,1) | and(isnan(table2array(DsetFeatsNvTrnNum)), isnan(ValsAss(i1,1)));
            Ids2RepNvVal = table2array(DsetFeatsNvValNum) == ValsAss(i1,1) | and(isnan(table2array(DsetFeatsNvValNum)), isnan(ValsAss(i1,1)));
    
            for i2 = 1:size(Ids2RepNvTrn,2)
                DsetFeatsNvTrn{Ids2RepNvTrn(:,i2), i2} = ValsAss(i1,2);
                DsetFeatsNvVal{Ids2RepNvVal(:,i2), i2} = ValsAss(i1,2);

                DsetFeatsNvTrnNum{Ids2RepNvTrn(:,i2), i2} = ValsAss(i1,2); % Necessary here because otherwise below you will read again old vals!
                DsetFeatsNvValNum{Ids2RepNvVal(:,i2), i2} = ValsAss(i1,2); % Necessary here because otherwise below you will read again old vals!
            end
        end

        if CrossVal
            for i2 = 1:size(DsetFeatsCvTrn, 2)
                Ids2RepCvTrn = table2array(DsetFeatsCvTrnNum{i2}) == ValsAss(i1,1) | and(isnan(table2array(DsetFeatsCvTrnNum{i2})), isnan(ValsAss(i1,1)));
                Ids2RepCvVal = table2array(DsetFeatsCvValNum{i2}) == ValsAss(i1,1) | and(isnan(table2array(DsetFeatsCvValNum{i2})), isnan(ValsAss(i1,1)));
        
                for i3 = 1:size(Ids2RepCvTrn,2)
                    DsetFeatsCvTrn{i2}{Ids2RepCvTrn(:,i3), i3} = ValsAss(i1,2);
                    DsetFeatsCvVal{i2}{Ids2RepCvVal(:,i3), i3} = ValsAss(i1,2);
        
                    DsetFeatsCvTrnNum{i2}{Ids2RepCvTrn(:,i3), i3} = ValsAss(i1,2); % Necessary here because otherwise below you will read again old vals!
                    DsetFeatsCvValNum{i2}{Ids2RepCvVal(:,i3), i3} = ValsAss(i1,2); % Necessary here because otherwise below you will read again old vals!
                end
            end
        end

    end
end

%% Filter rows and columns
NansColsTot = all(isnan(table2array(DsetFeatsTotNum)),1); % Since you converted dataset to numeric, table2array will work also with categories!
% NansColsTrn = all(isnan(table2array(DsetFeatsTrnNum)),1); % Since you converted dataset to numeric, table2array will work also with categories!
% NansColsTst = all(isnan(table2array(DsetFeatsTstNum)),1); % Since you converted dataset to numeric, table2array will work also with categories!

if any(NansColsTot)
    error(['Columns n. ',char(strjoin(string(find(NansColsTot)), ' - ')), ...
           ' contains all NaNs! Consider to use ReplaceVals to replace them!'])
end

% DsetFeatsTot{:, NansColsTot} = 0;
% DsetFeatsTrn{:, NansColsTrn} = 0;
% DsetFeatsTst{:, NansColsTst} = 0;

% DsetFeatsTotNum{:, NansColsTot} = 0; % Necessary here because otherwise the rows will read again old NaNs!
% DsetFeatsTrnNum{:, NansColsTrn} = 0; % Necessary here because otherwise the rows will read again old NaNs!
% DsetFeatsTstNum{:, NansColsTst} = 0; % Necessary here because otherwise the rows will read again old NaNs!

NansRowsTot = any(isnan(table2array(DsetFeatsTotNum)),2); % Since you converted dataset to numeric, table2array will work also with categories!
NansRowsTrn = any(isnan(table2array(DsetFeatsTrnNum)),2); % Since you converted dataset to numeric, table2array will work also with categories!
NansRowsTst = any(isnan(table2array(DsetFeatsTstNum)),2); % Since you converted dataset to numeric, table2array will work also with categories!

if any(NansRowsTot)
    warning('Some rows with NaNs detected, they will be removed!')
end

DsetFeatsTot(NansRowsTot, :) = [];
DsetFeatsTrn(NansRowsTrn, :) = [];
DsetFeatsTst(NansRowsTst, :) = [];

ExpctOutsTot(NansRowsTot, :) = [];
ExpctOutsTrn(NansRowsTrn, :) = [];
ExpctOutsTst(NansRowsTst, :) = [];

if NormVal
    % NansColsNvTrn = all(isnan(table2array(DsetFeatsNvTrnNum)),1);
    % NansColsNvVal = all(isnan(table2array(DsetFeatsNvValNum)),1);

    % DsetFeatsNvTrn{:, NansColsNvTrn} = 0;
    % DsetFeatsNvVal{:, NansColsNvVal} = 0;

    % DsetFeatsNvTrnNum{:, NansColsNvTrn} = 0; % Necessary here because otherwise the rows will read again old NaNs!
    % DsetFeatsNvValNum{:, NansColsNvVal} = 0; % Necessary here because otherwise the rows will read again old NaNs!

    NansRowsNvTrn = any(isnan(table2array(DsetFeatsNvTrnNum)),2);
    NansRowsNvVal = any(isnan(table2array(DsetFeatsNvValNum)),2);

    DsetFeatsNvTrn(NansRowsNvTrn, :) = [];
    DsetFeatsNvVal(NansRowsNvVal, :) = [];

    ExpctOutsNvTrn(NansRowsNvTrn, :) = [];
    ExpctOutsNvVal(NansRowsNvVal, :) = [];
end

if CrossVal
    [NansRowsCrossTrn, NansRowsCrossVal] = deal(cell(1, size(DsetFeatsCvTrn, 2)));
    % [NansColsCrossTrn, NansColsCrossVal] = deal(cell(1, size(DsetFeatsCvTrn, 2)));
    for i1 = 1:size(DsetFeatsCvTrn, 2)
        % NansColsCrossTrn{i1} = all(isnan(table2array(DsetFeatsCvTrnNum{i1})),1);
        % NansColsCrossVal{i1} = all(isnan(table2array(DsetFeatsCvValNum{i1})),1);

        % DsetFeatsCvTrn{i1}{:, NansColsCrossTrn{i1}} = 0;
        % DsetFeatsCvVal{i1}{:, NansColsCrossVal{i1}} = 0;
        
        % DsetFeatsCvTrnNum{:, NansColsCrossTrn{i1}} = 0;
        % DsetFeatsCvValNum{:, NansColsCrossVal{i1}} = 0;

        NansRowsCrossTrn{i1} = any(isnan(table2array(DsetFeatsCvTrnNum{i1})),2);
        NansRowsCrossVal{i1} = any(isnan(table2array(DsetFeatsCvValNum{i1})),2);
    
        DsetFeatsCvTrn{i1}(NansRowsCrossTrn{i1}, :) = [];
        DsetFeatsCvVal{i1}(NansRowsCrossVal{i1}, :) = [];
    
        ExpctOutsCvTrn{i1}(NansRowsCrossTrn{i1}, :) = [];
        ExpctOutsCvVal{i1}(NansRowsCrossVal{i1}, :) = [];
    end
end

%% Extra dataset filtering (just rows)
if ExtraDset
    for i1 = 1:numel(FtsNmExtr)
        DsetExtraTot{i1}(NansRowsTot, :) = [];
        DsetExtraTrn{i1}(NansRowsTrn, :) = [];
        DsetExtraTst{i1}(NansRowsTst, :) = [];

        if NormVal
            DsetExtraNvTrn{i1}(NansRowsNvTrn, :) = [];
            DsetExtraNvVal{i1}(NansRowsNvVal, :) = [];
        end

        if CrossVal
            for i2 = 1:size(DsetExtraCvTrn{i1}, 2)
                DsetExtraCvTrn{i1}{i2}(NansRowsCrossTrn{i2}, :) = [];
                DsetExtraCvVal{i1}{i2}(NansRowsCrossVal{i2}, :) = [];
            end
        end
    end
end

%% Creation of output table
DatasetsExtracted = array2table(cell(7, 2), 'RowNames',{ 'Total', ...
                                                         'Train', 'Test', ...
                                                         'NvTrain', 'NvValid', ...
                                                         'CvTrain', 'CvValid' }, ...
                                            'VariableNames',{'Feats','ExpOuts'});

DatasetsExtracted{{'Total', 'Train', 'Test'}, {'Feats','ExpOuts'}} = {DsetFeatsTot, ExpctOutsTot;
                                                                      DsetFeatsTrn, ExpctOutsTrn;
                                                                      DsetFeatsTst, ExpctOutsTst};

if NormVal
    DatasetsExtracted{{'NvTrain', 'NvValid'}, {'Feats','ExpOuts'}} = {DsetFeatsNvTrn, ExpctOutsNvTrn;
                                                                      DsetFeatsNvVal, ExpctOutsNvVal};
end

if CrossVal
    DatasetsExtracted{{'CvTrain', 'CvValid'}, {'Feats','ExpOuts'}} = {DsetFeatsCvTrn, ExpctOutsCvTrn;
                                                                      DsetFeatsCvVal, ExpctOutsCvVal};
end

if ExtraDset
    DatasetsExtracted{:,FtsNmExtr} = cell(size(DatasetsExtracted,1), numel(FtsNmExtr));
    for i1 = 1:numel(FtsNmExtr)
        DatasetsExtracted{{'Total', 'Train', 'Test'}, FtsNmExtr(i1)} = {DsetExtraTot{i1};
                                                                        DsetExtraTrn{i1};
                                                                        DsetExtraTst{i1}};

        if NormVal
            DatasetsExtracted{{'NvTrain', 'NvValid'}, FtsNmExtr(i1)} = {DsetExtraNvTrn{i1};
                                                                        DsetExtraNvVal{i1}};
        end
    
        if CrossVal
            DatasetsExtracted{{'CvTrain', 'CvValid'}, FtsNmExtr(i1)} = {DsetExtraCvTrn{i1};
                                                                        DsetExtraCvVal{i1}};
        end
    end
end

end