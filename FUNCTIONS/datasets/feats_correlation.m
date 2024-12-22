function corrTable = feats_correlation(datasetIn)

arguments
    datasetIn (:,:) table
end

featsNames = datasetIn.Properties.VariableNames;

featsType = varfun(@class, datasetIn, 'OutputFormat','cell');
cols2Conv = find(strcmp(featsType, 'categorical'));
if not(isempty(cols2Conv))
    for i1 = cols2Conv % ColumnsToConvert must be always horizontal!
        datasetIn.(featsNames{i1}) = grp2idx(datasetIn{:, i1});
    end
end

datasetIn = table2array(datasetIn);

datasetIn(isnan(datasetIn)) = -9999; % To replace NaNs with -9999 because otherwise you will have NaNs in R2 matrix.

corrTable = array2table(corrcoef(datasetIn), 'VariableNames',featsNames, 'RowNames',featsNames);