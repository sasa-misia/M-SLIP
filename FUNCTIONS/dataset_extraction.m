function DatasetsExtracted = dataset_extraction(DatasetInfo)

% EXTRACT DATASET FROM DATASETINFO TABLE (M-SLIP Internal function)
%   
% Outputs:
%   Datasets: table containing all the possible datasets to extract.
%   
% Required arguments:
%   - DatasetInfo : table containing datasets separated.

%% Preliminary check
if not(istable(DatasetInfo) || isstruct(DatasetInfo))
    error('Dataset with dates (1st argument) must be in a cell and must be congruent with other datasets!')
end

if istable(DatasetInfo)
    error('Dataset as table not yet implemented! Please contct the support...')
end

FldsOf1st = fieldnames(DatasetInfo(1).Datasets);
FtsNms1st = DatasetInfo(1).Datasets.Feats;
for i1 = 1:length(DatasetInfo) % In case of Table could be wrong!!!
    ChckEqFlds = isequal(FldsOf1st, fieldnames(DatasetInfo(i1).Datasets));
    ChckEqFts  = isequal(FtsNms1st, DatasetInfo(i1).Datasets.Feats);
    if not(ChckEqFlds)
        error(['The fields of the dataset n. ',num2str(i1),' are different from the 1st!'])
    end
    if not(ChckEqFts)
        error(['The features of the dataset n. ',num2str(i1),' are different from the 1st!'])
    end
end

%% Options
CrossVal = false;
if any(strcmp(FldsOf1st, 'CvTrain')) && any(strcmp(FldsOf1st, 'CvValid'))
    CrossVal = true;
end

NormVal = false;
if any(strcmp(FldsOf1st, 'NvTrain')) && any(strcmp(FldsOf1st, 'NvValid'))
    NormVal = true;
end

%% Core
% Initialization
[DatasetEvsFeats, DatasetEvsFeatsTrain, DatasetEvsFeatsTest, ...
        ExpectedOutputs, ExpectedOutputsTrain, ExpectedOutputsTest] = deal(cell(length(DatasetInfo), 1));
if CrossVal
    [DatasetFeatsCvTrnTmp, DatasetFeatsCvValTmp, ...
            ExpOutputsCvTrnTmp, ExpOutputsCvValTmp] = deal(cell(length(DatasetInfo), ...
                                                                length(DatasetInfo(1).Datasets.CvTrain)));
end
if NormVal
    [DatasetEvsFeatsNvTrn, DatasetEvsFeatsNvVal, ...
        ExpectedOutputsNvTrn, ExpectedOutputsNvVal] = deal(cell(length(DatasetInfo), 1));
end

% Extraction
for i1 = 1:length(DatasetInfo)
    DatasetEvsFeats{i1}      = DatasetInfo(i1).Datasets.Total.Features;
    DatasetEvsFeatsTrain{i1} = DatasetInfo(i1).Datasets.Train.Features;
    DatasetEvsFeatsTest{i1}  = DatasetInfo(i1).Datasets.Test.Features;
    
    ExpectedOutputs{i1}      = DatasetInfo(i1).Datasets.Total.Outputs;
    ExpectedOutputsTrain{i1} = DatasetInfo(i1).Datasets.Train.Outputs;
    ExpectedOutputsTest{i1}  = DatasetInfo(i1).Datasets.Test.Outputs;
    
    if CrossVal
        for i2 = 1:length(DatasetInfo(1).Datasets.CvTrain)
            DatasetFeatsCvTrnTmp{i1,i2} = DatasetInfo(i1).Datasets.CvTrain(i2).Features;
            DatasetFeatsCvValTmp{i1,i2} = DatasetInfo(i1).Datasets.CvValid(i2).Features;
        
            ExpOutputsCvTrnTmp{i1,i2} = DatasetInfo(i1).Datasets.CvTrain(i2).Outputs;
            ExpOutputsCvValTmp{i1,i2} = DatasetInfo(i1).Datasets.CvValid(i2).Outputs;
        end
    end

    if NormVal
        DatasetEvsFeatsNvTrn{i1} = DatasetInfo(i1).Datasets.NvTrain.Features;
        DatasetEvsFeatsNvVal{i1} = DatasetInfo(i1).Datasets.NvValid.Features;

        ExpectedOutputsNvTrn{i1} = DatasetInfo(i1).Datasets.NvTrain.Outputs;
        ExpectedOutputsNvVal{i1} = DatasetInfo(i1).Datasets.NvValid.Outputs;
    end
end

% Concatenation
DatasetEvsFeats      = cat(1, DatasetEvsFeats{:});
DatasetEvsFeatsTrain = cat(1, DatasetEvsFeatsTrain{:});
DatasetEvsFeatsTest  = cat(1, DatasetEvsFeatsTest{:});

ExpectedOutputs      = cat(1, ExpectedOutputs{:});
ExpectedOutputsTrain = cat(1, ExpectedOutputsTrain{:});
ExpectedOutputsTest  = cat(1, ExpectedOutputsTest{:});

if CrossVal
    [DatasetFeatsCvTrn, DatasetFeatsCvVal, ...
            ExpOutputsCvTrn, ExpOutputsCvVal] = deal(cell(1, size(DatasetFeatsCvTrnTmp, 2)));
    for i1 = 1:size(DatasetFeatsCvTrnTmp, 2)
        DatasetFeatsCvTrn{i1} = cat(1, DatasetFeatsCvTrnTmp{:,i1});
        DatasetFeatsCvVal{i1} = cat(1, DatasetFeatsCvValTmp{:,i1});
    
        ExpOutputsCvTrn{i1} = cat(1, ExpOutputsCvTrnTmp{:,i1});
        ExpOutputsCvVal{i1} = cat(1, ExpOutputsCvValTmp{:,i1});
    end
end

if NormVal
    DatasetEvsFeatsNvTrn = cat(1, DatasetEvsFeatsNvTrn{:});
    DatasetEvsFeatsNvVal = cat(1, DatasetEvsFeatsNvVal{:});

    ExpectedOutputsNvTrn = cat(1, ExpectedOutputsNvTrn{:});
    ExpectedOutputsNvVal = cat(1, ExpectedOutputsNvVal{:});
end

% Filter
NansIndsTot = any(isnan(table2array(DatasetEvsFeats)),2);
NansIndsTrn = any(isnan(table2array(DatasetEvsFeatsTrain)),2);
NansIndsTst = any(isnan(table2array(DatasetEvsFeatsTest)),2);

DatasetEvsFeats(NansIndsTot, :)      = [];
DatasetEvsFeatsTrain(NansIndsTrn, :) = [];
DatasetEvsFeatsTest(NansIndsTst, :)  = [];

ExpectedOutputs(NansIndsTot, :)      = [];
ExpectedOutputsTrain(NansIndsTrn, :) = [];
ExpectedOutputsTest(NansIndsTst, :)  = [];

if CrossVal
    [NansIndsCrossTrn, NansIndsCrossVal] = deal(cell(1, size(DatasetFeatsCvTrn, 2)));
    for i1 = 1:size(DatasetFeatsCvTrn, 2)
        NansIndsCrossTrn{i1} = any(isnan(table2array(DatasetFeatsCvTrn{i1})),2);
        NansIndsCrossVal{i1} = any(isnan(table2array(DatasetFeatsCvVal{i1})),2);
    
        DatasetFeatsCvTrn{i1}(NansIndsCrossTrn{i1}, :) = [];
        DatasetFeatsCvVal{i1}(NansIndsCrossVal{i1}, :) = [];
    
        ExpOutputsCvTrn{i1}(NansIndsCrossTrn{i1}, :) = [];
        ExpOutputsCvVal{i1}(NansIndsCrossVal{i1}, :) = [];
    end
end

if NormVal
    NansIndsNvTrn = any(isnan(table2array(DatasetEvsFeatsNvTrn)),2);
    NansIndsNvVal = any(isnan(table2array(DatasetEvsFeatsNvVal)),2);

    DatasetEvsFeatsNvTrn(NansIndsNvTrn, :) = [];
    DatasetEvsFeatsNvVal(NansIndsNvVal, :) = [];

    ExpectedOutputsNvTrn(NansIndsNvTrn, :) = [];
    ExpectedOutputsNvVal(NansIndsNvVal, :) = [];
end

DatasetsExtracted = array2table(cell(7, 2), 'RowNames',{'Total', 'Train', 'Test', ...
                                                        'CvTrain', 'CvValid', ...
                                                        'NvTrain', 'NvValid'}, ...
                                            'VariableNames',{'Feats','ExpOuts'});

DatasetsExtracted{{'Total', 'Train', 'Test'}, {'Feats','ExpOuts'}} = {DatasetEvsFeats     , ExpectedOutputs     ;
                                                                      DatasetEvsFeatsTrain, ExpectedOutputsTrain;
                                                                      DatasetEvsFeatsTest , ExpectedOutputsTest  };

if CrossVal
    DatasetsExtracted{{'CvTrain', 'CvValid'}, {'Feats','ExpOuts'}} = {DatasetFeatsCvTrn, ExpOutputsCvTrn;
                                                                      DatasetFeatsCvVal, ExpOutputsCvVal };
end

if NormVal
    DatasetsExtracted{{'NvTrain', 'NvValid'}, {'Feats','ExpOuts'}} = {DatasetEvsFeatsNvTrn, ExpectedOutputsNvTrn;
                                                                      DatasetEvsFeatsNvVal, ExpectedOutputsNvVal };
end

end