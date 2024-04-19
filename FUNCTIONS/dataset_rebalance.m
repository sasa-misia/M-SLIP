function [DtsetDatesOut, DtsetFeatsOut, ExpOutsOut] = dataset_rebalance(DtsetDatesToUse, DtsetFeatsToUse, ExpctdOutsToUse, RatioToImpose, Technique)

% CREATE AN INDEX ARRAY TO USE IN TRAINING OF ML, WITH RELATIVE OUTPUTS
%   
% Outputs:
%   [DtsetDataOut, DtsetFeats, ExpOuts]
%   
% Required arguments:
%   - DtsetDatesToUse : is/are the dataset/s with the dates of your events.
%   
%   - DtsetFeatsToUse : is/are the dataset/s containing features
%   
%   - ExpctdOutsToUse : is/are the array/s with the expected output classes
%   
%   - RatioToUse : is the ratio to impose between stable class and all the
%   others
%   
%   - Technique : is the technique you want to use. You can choose between
%   'Undersampling', 'Oversampling', and 'SMOTE'

%% Preliminary check
if not(iscell(DtsetDatesToUse))
    error('Dataset with dates (1st argument) must be in a cell and must be congruent with other datasets!')
end

if not(iscell(DtsetFeatsToUse))
    error('Dataset with feature (2nd argument) must be in a cell and must be congruent with other datasets!')
end

if not(iscell(DtsetDatesToUse))
    error('Array with outputs (3rd argument) must be in a cell and must be congruent with other datasets!')
end

if not(numel(RatioToImpose) == 1) || not(isscalar(RatioToImpose))
    error('Ratio to impose (4th argument) must be a scalar!')
end

if not(ischar(Technique) || isstring(Technique))
    error('Technique (5th argument) must be a char or a string!')
end

for i1 = 1:length(ExpctdOutsToUse) % ExpctdOutsToUse{i1} must be a vertical array to use the function groupcounts!
    if not(size(ExpctdOutsToUse{i1}, 2) == 1)
        error(['The expected output cell n. ',num2str(i1),' is not a 1D vertical array (nx1)!'])
    end
end

%% Core
[DtsetDatesOut, DtsetFeatsOut, ExpOutsOut] = deal(cell(1, length(ExpctdOutsToUse)));
for i1 = 1:length(ExpctdOutsToUse)
    if numel(unique(ExpctdOutsToUse{i1})) <= 1
        warning(['Dataset n. ',num2str(i1),' has only one class and will be skipped!'])

        DtsetDatesOut{i1} = DtsetDatesToUse{i1};
        DtsetFeatsOut{i1} = DtsetFeatsToUse{i1};
        ExpOutsOut{i1}    = ExpctdOutsToUse{i1};
        continue
    end
    UniqueObsBef = size(unique(DtsetFeatsToUse{i1}), 1);

    IndsOfClasses = (ExpctdOutsToUse{i1} == unique(ExpctdOutsToUse{i1})');
    IndNotEnPop   = sum(IndsOfClasses,1) <= 1;
    if any(IndNotEnPop)
        Classes = unique(ExpctdOutsToUse{i1})';
        ClToRep = Classes(IndNotEnPop);

        RepsNum = 1;
        for i2 = 1:length(ClToRep)
            warning(['Class n. ',num2str(ClToRep(i2)),' has 1 observation. This single observation will be repeated!'])
            IndToRep = find(ExpctdOutsToUse{i1} == ClToRep(i2), 1);

            DtsetDatesToUse{i1} = [DtsetDatesToUse{i1}; repmat(DtsetDatesToUse{i1}(IndToRep,:), RepsNum, 1)];
            DtsetFeatsToUse{i1} = [DtsetFeatsToUse{i1}; repmat(DtsetFeatsToUse{i1}(IndToRep,:), RepsNum, 1)];
            ExpctdOutsToUse{i1} = [ExpctdOutsToUse{i1}; repmat(ExpctdOutsToUse{i1}(IndToRep,:), RepsNum, 1)];
        end
        IndsOfClasses = (ExpctdOutsToUse{i1} == unique(ExpctdOutsToUse{i1})');
    end

    [ClCnt, UnCl]  = groupcounts(ExpctdOutsToUse{i1});
    [~, MjClssInd] = max(ClCnt);
    MajClassVal    = UnCl(MjClssInd);
    ColumnOfMajor  = (unique(ExpctdOutsToUse{i1})' == MajClassVal);
    IndsOfMajCl    = IndsOfClasses(:,ColumnOfMajor);
    IndsOfMinCl    = IndsOfClasses(:,not(ColumnOfMajor));

    RatioBeforeResampling = sum(IndsOfMinCl, 1) ./ sum(IndsOfMajCl);

    switch Technique
        case 'Undersampling'
            NumIndsOfMaj = find(IndsOfMajCl);

            PercToRemMaj = 1-min(RatioBeforeResampling)./RatioToImpose; % Think about this formula please!

            RelIndMj2Chg = randperm(numel(NumIndsOfMaj), ceil(numel(NumIndsOfMaj)*PercToRemMaj));
            IndsToChange = NumIndsOfMaj(RelIndMj2Chg);

            IndsOfMajCl(IndsToChange) = false;

            if size(IndsOfMinCl, 2) >= 2
                MinorClass = ( min(sum(IndsOfMinCl,1)) == sum(IndsOfMinCl,1) );

                IndsOfMin2Res = IndsOfMinCl(:, not(MinorClass));
                IndsOfAbsMin  = IndsOfMinCl(:, MinorClass);
                if size(IndsOfAbsMin, 2) >= 2
                    error('Minor class should be just one!')
                end

                RatBefResMin = sum(IndsOfAbsMin,1)./sum(IndsOfMin2Res,1);
                PercToRemMin = 1-RatBefResMin; % Think about this formula please!
                for i2 = 1:length(PercToRemMin)
                    NumIndsMin2ResTmp = find(IndsOfMin2Res(:,i2));

                    RelIndOfMin2ChTmp = randperm(numel(NumIndsMin2ResTmp), ceil(numel(NumIndsMin2ResTmp)*PercToRemMin(i2)));
                    IndsToChngMinTmp  = NumIndsMin2ResTmp(RelIndOfMin2ChTmp);
        
                    IndsOfMin2Res(IndsToChngMinTmp, i2) = false;
                end

                IndsOfMinCl(:, not(MinorClass)) = IndsOfMin2Res;
                if not(isequal(IndsOfMinCl(:,MinorClass), IndsOfAbsMin))
                    error('Indices of minor class do not match!')
                end
            end

            [NumIndsOfMin, ~]  = find(IndsOfMinCl);
            RelIndsMLDsetToUse = [NumIndsOfMin; find(IndsOfMajCl)];

            RatioAfterRes = sum(IndsOfMinCl,1)./sum(IndsOfMajCl);
            if any((any(IndsOfMinCl & IndsOfMajCl))) || any((round(RatioToImpose, 1) ~= round(RatioAfterRes, 1)))
                error('Something went wrong in re-attributing the correct ratio between positive and negative outputs!')
            end

        case 'Oversampling'
            NumIndsOfMaj = find(IndsOfMajCl);
            NumIndsOfMin = cell(1, size(IndsOfMinCl, 2));
            for i2 = 1:size(IndsOfMinCl, 2)
                NumIndsOfMin{i2} = find(IndsOfMinCl(:,i2));
            end

            PercToAdd = RatioToImpose./RatioBeforeResampling; % Think about this formula please!

            NumOfReps = fix(PercToAdd);

            IndsMinRep = cell(1, size(IndsOfMinCl, 2));
            for i2 = 1:size(IndsOfMinCl, 2)
                RelIndMin2AddTmp = randperm(numel(NumIndsOfMin{i2}), ceil(numel(NumIndsOfMin{i2})*(PercToAdd(i2)-NumOfReps(i2))));
                IndsMinRep{i2}   = [repmat(NumIndsOfMin{i2}, NumOfReps(i2), 1); NumIndsOfMin{i2}(RelIndMin2AddTmp)];
            end

            IndsMinRepCat      = cat(1, IndsMinRep{:});
            RelIndsMLDsetToUse = [IndsMinRepCat; NumIndsOfMaj];

            RatioAfterRes   = cellfun(@numel, IndsMinRep) ./ numel(NumIndsOfMaj);
            CheckResampling = (not(isempty(intersect(IndsMinRepCat, NumIndsOfMaj)))) || ...
                              any((round(RatioToImpose, 1) ~= round(RatioAfterRes, 1))) || ...
                              (numel(IndsMinRepCat) <= numel(cat(1, NumIndsOfMin{:})));
            if CheckResampling
                error('Something went wrong in re-attributing the correct ratio between positive and negative outputs!')
            end

        case 'SMOTE'
            i2 = 1;
            IndsOfClssNew = (ExpctdOutsToUse{i1} == unique(ExpctdOutsToUse{i1})');
            RatioAfterRes = RatioBeforeResampling;
            while any(round(RatioAfterRes, 1) < round(RatioToImpose, 1)) && (i2 <= 1000)
                PercToAdd = RatioToImpose ./ RatioAfterRes; % Think about this formula please!
    
                NumObsCl = sum(IndsOfClssNew,1);
                NNeighb  = NumObsCl-1; % min(NumObsCl-1, 5);
                ObsToAdd = min([0, max(PercToAdd-1, 0)], NNeighb);
    
                [DatasetEvsFeatsArr, ExpOutsOut{i1}, ...
                        DatasetFeatsAddedArr, ExpectedOutputsAddedArr] = smote(table2array(DtsetFeatsToUse{i1}), ObsToAdd, ...
                                                                                    NNeighb, 'Class',ExpctdOutsToUse{i1});
    
                TblSyntDates2Add  = array2table([NaT, NaT], 'VariableNames',DtsetDatesToUse{i1}.Properties.VariableNames);
                DtsetDatesOut{i1} = [DtsetDatesToUse{i1}; repmat(TblSyntDates2Add, length(ExpectedOutputsAddedArr), 1)];
                DtsetFeatsOut{i1} = array2table(DatasetEvsFeatsArr, 'VariableNames',DtsetFeatsToUse{i1}.Properties.VariableNames);
                DatasetFeatsAdded = array2table(DatasetFeatsAddedArr, 'VariableNames',DtsetFeatsToUse{i1}.Properties.VariableNames);
    
                IndsOfClssNew = (ExpctdOutsToUse{i1} == unique(ExpctdOutsToUse{i1})');
                ColnOfMajNew  = (unique(ExpctdOutsToUse{i1})' == 0);
                IndsOfMinNew  = IndsOfClssNew(:,not(ColnOfMajNew));
                IndsOfMajNew  = IndsOfClssNew(:,ColnOfMajNew);
            
                RatioAfterRes = sum(IndsOfMinNew,1)./sum(IndsOfMajNew);
                i2 = i2 + 1;
            end

            UniqueObsAft = size(unique(DtsetFeatsToUse{i1}), 1);
            if UniqueObsAft < size(DtsetFeatsToUse{i1}, 1)
                PercSynth = (UniqueObsAft-UniqueObsBef)/(size(DtsetFeatsToUse{i1}, 1)-UniqueObsBef);
                warning(['Not all new observations were synthesized, just ',num2str(PercSynth*100),' %!'])
            end

            if any((round(RatioToImpose, 1) ~= round(RatioAfterRes, 1))) || (i2 >= 1000)
                error('Something went wrong in re-attributing the correct ratio between positive and negative outputs!')
            end

        otherwise
            error('Resample mode not recognized!')
    end

    if not(strcmp(Technique,'SMOTE'))
        DtsetDatesOut{i1} = DtsetDatesToUse{i1}(RelIndsMLDsetToUse,:);
        DtsetFeatsOut{i1} = DtsetFeatsToUse{i1}(RelIndsMLDsetToUse,:);
        ExpOutsOut{i1}    = ExpctdOutsToUse{i1}(RelIndsMLDsetToUse);
    end
end

end