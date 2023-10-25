function [DtsetDatesOut, DtsetFeatsOut, ExpOutsOut] = rebalance_dataset(DtsetDatesToUse, DtsetFeatsToUse, ExpctdOutsToUse, RatioToImpose, Technique)

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
    ColumnOfStable = (unique(ExpctdOutsToUse{i1})' == 0);
    IndsOfUnstable = IndsOfClasses(:,not(ColumnOfStable));
    IndsOfStable   = IndsOfClasses(:,ColumnOfStable);

    RatioBeforeResampling = sum(IndsOfUnstable,1)./sum(IndsOfStable);

    switch Technique
        case 'Undersampling'
            IndsNumsStable   = find(IndsOfStable);

            PercToRemoveStab = 1-min(RatioBeforeResampling)./RatioToImpose; % Think about this formula please!

            RelIndOfStabToChange = randperm(numel(IndsNumsStable), ceil(numel(IndsNumsStable)*PercToRemoveStab));
            IndsToChange = IndsNumsStable(RelIndOfStabToChange);

            IndsOfStable(IndsToChange) = false;

            if size(IndsOfUnstable, 2) >= 2
                MinorClass = ( min(sum(IndsOfUnstable,1)) == sum(IndsOfUnstable,1) );

                IndsOfUnstableToRes = IndsOfUnstable(:, not(MinorClass));
                IndsOfUnstableMinor = IndsOfUnstable(:, MinorClass);
                if size(IndsOfUnstableMinor, 2) >= 2
                    error('Minor class should be just one!')
                end

                RatioBefResUnst  = sum(IndsOfUnstableMinor,1)./sum(IndsOfUnstableToRes,1);
                PercToRemoveUnst = 1-RatioBefResUnst; % Think about this formula please!
                for i2 = 1:length(PercToRemoveUnst)
                    IndsNumsUnstToResTemp = find(IndsOfUnstableToRes(:,i2));

                    RelIndOfUnstToChngTmp = randperm(numel(IndsNumsUnstToResTemp), ceil(numel(IndsNumsUnstToResTemp)*PercToRemoveUnst(i2)));
                    IndsToChngUnstTmp     = IndsNumsUnstToResTemp(RelIndOfUnstToChngTmp);
        
                    IndsOfUnstableToRes(IndsToChngUnstTmp, i2) = false;
                end

                IndsOfUnstable(:, not(MinorClass)) = IndsOfUnstableToRes;
                if not(isequal(IndsOfUnstable(:,MinorClass), IndsOfUnstableMinor))
                    error('Indices of minor class do not match!')
                end
            end

            [NumIndsUnstable, ~]  = find(IndsOfUnstable);
            RelIndsMLDatasetToUse = [NumIndsUnstable; find(IndsOfStable)];

            RatioAfterResampling = sum(IndsOfUnstable,1)./sum(IndsOfStable);
            if any((any(IndsOfUnstable & IndsOfStable))) || any((round(RatioToImpose, 1) ~= round(RatioAfterResampling, 1)))
                error('Something went wrong in re-attributing the correct ratio between positive and negative outputs!')
            end

        case 'Oversampling'
            IndsNumsStable   = find(IndsOfStable);
            IndsNumsUnstable = cell(1, size(IndsOfUnstable, 2));
            for i2 = 1:size(IndsOfUnstable, 2)
                IndsNumsUnstable{i2} = find(IndsOfUnstable(:,i2));
            end

            PercToAdd = RatioToImpose./RatioBeforeResampling; % Think about this formula please!

            NumOfReps = fix(PercToAdd);

            IndsUnstRepeated = cell(1, size(IndsOfUnstable, 2));
            for i2 = 1:size(IndsOfUnstable, 2)
                RelIndOfUnstToAddTemp = randperm(numel(IndsNumsUnstable{i2}), ceil(numel(IndsNumsUnstable{i2})*(PercToAdd(i2)-NumOfReps(i2))));
                IndsUnstRepeated{i2}  = [repmat(IndsNumsUnstable{i2}, NumOfReps(i2), 1); IndsNumsUnstable{i2}(RelIndOfUnstToAddTemp)];
            end

            IndsUnstableRepeated  = cat(1, IndsUnstRepeated{:});
            RelIndsMLDatasetToUse = [IndsUnstableRepeated; IndsNumsStable];

            RatioAfterResampling = cellfun(@numel, IndsUnstRepeated)./numel(IndsNumsStable);
            CheckResampling = (not(isempty(intersect(IndsUnstableRepeated,IndsNumsStable)))) || ...
                               any((round(RatioToImpose, 1) ~= round(RatioAfterResampling, 1))) || ...
                               (numel(IndsUnstableRepeated) <= numel(cat(1, IndsNumsUnstable{:})));
            if CheckResampling
                error('Something went wrong in re-attributing the correct ratio between positive and negative outputs!')
            end

        case 'SMOTE'
            i2 = 1;
            IndsOfClassesNew     = (ExpctdOutsToUse{i1} == unique(ExpctdOutsToUse{i1})');
            RatioAfterResampling = RatioBeforeResampling;
            while any(round(RatioAfterResampling, 1) < round(RatioToImpose, 1)) && (i2 <= 1000)
                PercToAdd = RatioToImpose./RatioAfterResampling; % Think about this formula please!
    
                NumObsCl = sum(IndsOfClassesNew,1);
                NNeighb  = NumObsCl-1; % min(NumObsCl-1, 5);
                ObsToAdd = min([0, max(PercToAdd-1, 0)], NNeighb);
    
                [DatasetEvsFeatsArr, ExpOutsOut{i1}, ...
                        DatasetFeatsAddedArr, ExpectedOutputsAddedArr] = smote(table2array(DtsetFeatsToUse{i1}), ObsToAdd, ...
                                                                                    NNeighb, 'Class',ExpctdOutsToUse{i1});
    
                TableSyntDatesToAdd = array2table([NaT, NaT], 'VariableNames',DtsetDatesToUse{i1}.Properties.VariableNames);
                DtsetDatesOut{i1} = [DtsetDatesToUse{i1}; repmat(TableSyntDatesToAdd, length(ExpectedOutputsAddedArr), 1)];
                DtsetFeatsOut{i1} = array2table(DatasetEvsFeatsArr, 'VariableNames',DtsetFeatsToUse{i1}.Properties.VariableNames);
                DatasetFeatsAdded   = array2table(DatasetFeatsAddedArr, 'VariableNames',DtsetFeatsToUse{i1}.Properties.VariableNames);
    
                IndsOfClassesNew  = (ExpctdOutsToUse{i1} == unique(ExpctdOutsToUse{i1})');
                ColumnOfStableNew = (unique(ExpctdOutsToUse{i1})' == 0);
                IndsOfUnstableNew = IndsOfClassesNew(:,not(ColumnOfStableNew));
                IndsOfStableNew   = IndsOfClassesNew(:,ColumnOfStableNew);
            
                RatioAfterResampling = sum(IndsOfUnstableNew,1)./sum(IndsOfStableNew);
                i2 = i2 + 1;
            end

            UniqueObsAft = size(unique(DtsetFeatsToUse{i1}), 1);
            if UniqueObsAft < size(DtsetFeatsToUse{i1}, 1)
                PercSynth = (UniqueObsAft-UniqueObsBef)/(size(DtsetFeatsToUse{i1}, 1)-UniqueObsBef);
                warning(['Not all new observations were synthesized, just ',num2str(PercSynth*100),' %!'])
            end

            if any((round(RatioToImpose, 1) ~= round(RatioAfterResampling, 1))) || (i2 >= 1000)
                error('Something went wrong in re-attributing the correct ratio between positive and negative outputs!')
            end

        otherwise
            error('Resample mode not recognized!')
    end

    if not(strcmp(Technique,'SMOTE'))
        DtsetDatesOut{i1} = DtsetDatesToUse{i1}(RelIndsMLDatasetToUse,:);
        DtsetFeatsOut{i1} = DtsetFeatsToUse{i1}(RelIndsMLDatasetToUse,:);
        ExpOutsOut{i1}    = ExpctdOutsToUse{i1}(RelIndsMLDatasetToUse);
    end
end

end