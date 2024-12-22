function [genSummary, countInMun] = landslides_from_infodet(infoLands, Options)

arguments
    infoLands (1,:) cell
    Options.fileNames (1,:) string = strcat("File n. ",string(1:numel(infoLands)))
end

fileNames = Options.fileNames;

%% check inputs
for i1 = 1:numel(infoLands)
    if not(istable(infoLands{i1}))
        error('Every cell of infoDetLands must contains a table!')
    end
end

if numel(fileNames) ~= numel(infoLands)
    error('fileNames input must have same sizes of infoLands!')
end

%% initialization
municxInfo = cellfun(@(x) x.Municipality, infoLands, 'UniformOutput',false);
datesxInfo = cellfun(@(x) x.Datetime, infoLands, 'UniformOutput',false);
undefDates = cellfun(@(x) isnat(x), datesxInfo, 'UniformOutput',false);
infowUndef = cellfun(@any, undefDates);

if any(infowUndef)
    warning('Some datetimes are NaT, please write a datetime for these!')
    tmpFllr = inputdlg2(strcat("Filler datetime (",fileNames(infowUndef),")"), ...
                                    'DefInp',repmat({'01-jan-2000'}, 1, sum(infowUndef)));
    tmpFllr = datetime(tmpFllr, 'Format','dd-MMM-uuuu HH:mm:ss');

    fllrUndDts = NaT(1, numel(datesxInfo));
    fllrUndDts(infowUndef) = tmpFllr;
    for i1 = 1:numel(datesxInfo)
        datesxInfo{i1}(undefDates{i1}) = fllrUndDts(i1);
    end
end

tmpMunic = cat(1, municxInfo{:});
unqMunic = cellstr(unique(tmpMunic));
tmpDates = cat(1, datesxInfo{:});

[unMrgTmp, indMerge, indxReps] = unique(cellstr(tmpDates));
genSummary = table(NaT(size(unMrgTmp)), zeros(size(unMrgTmp)), ...
                   repmat({""}, size(unMrgTmp)), 'VariableNames',{'Datetime', 'NumOfLandslides', 'Municipalities'});
countInMun = table(NaT(size(unMrgTmp)), 'VariableNames',{'Datetime'});
countInMun{:, unqMunic} = zeros(numel(unMrgTmp), numel(unqMunic));
for i1 = 1:size(genSummary, 1)
    genSummary{i1, 'Datetime'} = tmpDates(indMerge(i1));
    genSummary{i1, 'NumOfLandslides'} = sum(i1 == indxReps);

    subTmpMuns = string(tmpMunic(i1 == indxReps));
    genSummary{i1, 'Municipalities'} = {unique(subTmpMuns)};

    countInMun{i1, 'Datetime'} = tmpDates(indMerge(i1));
    for i2 = 1:numel(unqMunic)
        countInMun{i1, unqMunic(i2)} = sum(strcmp(subTmpMuns, unqMunic(i2)));
    end
end

end