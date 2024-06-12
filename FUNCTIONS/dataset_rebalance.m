function [DtsetDatesOut, DtsetFeatsOut, ExpOutsOut, RowsTaken, DtsetSupp] = dataset_rebalance(DtsetDatesToUse, DtsetFeatsToUse, ExpctdOutsToUse, RatioToImpose, Technique, varargin)

% CREATE AN INDEX ARRAY TO USE IN TRAINING OF ML, WITH RELATIVE OUTPUTS
%   
%   [DtsetDataOut, DtsetFeats, ExpOuts, IndsTaken, DtsetSupp] = 
%                   dataset_rebalance(DtsetDatesToUse, DtsetFeatsToUse, 
%                                     ExpctdOutsToUse, RatioToImpose, Technique, varargin)
%   
%   Dependencies: -
%   
% Outputs:
%   DtsetDataOut : is the cell array containing in each cell the new dates
%   dataset rebalanced.
%   
%   DtsetFeats : is the cell array containing in each cell the new feats
%   dataset rebalanced.
%   
%   ExpOutsOut : is the cell array containing in each cell the new output
%   values rebalanced and referred to DtsetFeats.
%   
%   RowsTaken : is the number of rows taken from DtsetFeatsToUse input
%   dataset, to create the new rebalanced dataset. In case of SMOTE
%   technique it contains nans where the observations are synthetized.
%   
%   DtsetSupp : is the cell array containing in each cell the supplementary
%   dataset, rebalanced. Cells with nans in case of no supplementary dataset.
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
%   
% Optional arguments:
%   - 'CrucialObs', cell array (logical/numeric arrays inside): is to declare 
%   if there are some crucial observations to keep during rebalance. It can 
%   be a logical array (inside each cell) with the same number of element to 
%   the rows of each DtsetFeatsToUse input and it must contains true where 
%   the indices must be maintained. In case of numeric array, it must contain 
%   the number of rows to maintain per each input Dataset, and these numbers 
%   must be referred to DtsetFeatsToUse input. Note: it will be effective 
%   only in case 'undersampling' technique is applied because, otherwise, 
%   these observations would not be excluded but repeated!
%   
%   - 'SuppDataset', cell array (tables inside): is to declare if there are 
%   other datasets to use in parallel with the main ones (required args). 
%   These supplementary datasets must have the same sizes of the inputs 
%   (same number of rows, i.e., observations). In case no SuppDataset is
%   defined, cells with tables full of nans will be given as DtsetSupp out.

%% Preliminary check
if not(iscell(DtsetDatesToUse))
    error('Dataset with dates (1st argument) must be in a cell and must be congruent with other datasets!')
end

if not(iscell(DtsetFeatsToUse))
    error('Dataset with feature (2nd argument) must be in a cell and must be congruent with other datasets!')
end

if not(iscell(ExpctdOutsToUse))
    error('Array with outputs (3rd argument) must be in a cell and must be congruent with other datasets!')
end

if not(isnumeric(RatioToImpose) && isscalar(RatioToImpose))
    error('Ratio to impose (4th argument) must be a numeric scalar!')
end

if not(ischar(Technique) || isstring(Technique) || iscellstr(Technique))
    error('Technique (5th argument) must be a char or a string!')
end

if not(any(strcmpi(Technique, {'Undersampling', 'Oversampling', 'SMOTE'})))
    error('Technique (5th argument) must be Undersampling, Oversampling, or SMOTE!')
end

for i1 = 1:length(ExpctdOutsToUse) % ExpctdOutsToUse{i1} must be a vertical array to use the function groupcounts!
    if not(size(ExpctdOutsToUse{i1}, 2) == 1)
        error(['The expected output cell n. ',num2str(i1),' is not a 1D vertical array (nx1)!'])
    end
end

Technique = lower(char(Technique));

%% Optional
CrucialObs = cell(1, numel(DtsetFeatsToUse)); % Default
for i1 = 1:numel(CrucialObs)
    CrucialObs{i1} = false(size(DtsetFeatsToUse{i1}, 1), 1);
end
SupplDtset = cell(1, numel(DtsetFeatsToUse)); % Default
for i1 = 1:numel(CrucialObs)
    SupplDtset{i1} = array2table(nan(size(DtsetFeatsToUse{i1}, 1), 1), 'VariableNames',{'N.D.'});
end

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InpCrucObs = find(cellfun(@(x) all(strcmpi(x, 'CrucialObs' )), vararginCp));
    InpSpplDst = find(cellfun(@(x) all(strcmpi(x, 'SuppDataset')), vararginCp));

    if InpCrucObs; CrucialObs = varargin{InpCrucObs+1}; end
    if InpSpplDst; SupplDtset = varargin{InpSpplDst+1}; end

    varargin([ InpCrucObs, InpCrucObs+1, ...
               InpSpplDst, InpSpplDst+1 ]) = [];

    if not(isempty(varargin))
        error(['Some optional inputs were not recognized: ', ...
               char(join(string(varargin), ', ')),'. Please check it!'])
    end
end

if not(iscell(CrucialObs))
    error('CrucialObs input must be a cell array!')
end

if numel(CrucialObs) ~= numel(DtsetFeatsToUse)
    error(['CrucialObs must have the same number of ', ...
           'cells of the other inputs (1st, 2nd, and 3rd)!'])
end

for i1 = 1:numel(CrucialObs)
    if islogical(CrucialObs{i1})
        if numel(CrucialObs{i1}) ~= size(DtsetFeatsToUse{i1}, 1)
            error(['Sizes of array in cell n. ',num2str(i1),' do not match ', ...
                   'number of rows of DtsetFeatsToUse in the same cell (CrucialObs)!'])
        end

    elseif isnumeric(CrucialObs{i1})
        TmpLogInds = false(size(DtsetFeatsToUse{i1}, 1), 1);
        if (max(CrucialObs{i1}, [], 'all') > numel(TmpLogInds)) || (min(CrucialObs{i1}, [], 'all') < 1)
            error(['Your indices of CrucialObs contained in cell n. ',num2str(i1), ...
                   ' are outside of the range [1, number of raws in DtsetFeatsToUse (same cell)]!'])
        end
        
        TmpLogInds(CrucialObs{i1}) = true;
        CrucialObs{i1} = TmpLogInds;

    else
        error('Each cell of CrucialObs must contain just logical or numeric arrays!')
    end
end

KeepCruObs = false(1, numel(CrucialObs));
for i1 = 1:numel(CrucialObs)
    if any(CrucialObs{i1})
        KeepCruObs(i1) = true;
    end
end

if not(iscell(SupplDtset))
    error('SuppDataset input must be a cell array!')
end

if numel(SupplDtset) ~= numel(DtsetFeatsToUse)
    error(['SuppDataset must have the same number of ', ...
           'cells of the other inputs (1st, 2nd, and 3rd)!'])
end

for i1 = 1:numel(SupplDtset)
    if istable(SupplDtset{i1})
        if size(SupplDtset{i1}, 1) ~= size(DtsetFeatsToUse{i1}, 1)
            error(['Rows of array in cell n. ',num2str(i1),' do not match ', ...
                   'number of rows of DtsetFeatsToUse in the same cell (SuppDataset)!'])
        end
    else
        error('Each cell of SupplDtset must contain tables!')
    end
end

%% Core
[DtsetDatesOut, DtsetFeatsOut, ExpOutsOut, RowsTaken, DtsetSupp] = deal(cell(1, length(ExpctdOutsToUse)));
for i1 = 1:numel(ExpctdOutsToUse)
    if numel(unique(ExpctdOutsToUse{i1})) <= 1
        warning(['Dataset n. ',num2str(i1),' has only one class and will be skipped!'])

        DtsetDatesOut{i1} = DtsetDatesToUse{i1};
        DtsetFeatsOut{i1} = DtsetFeatsToUse{i1};
        ExpOutsOut{i1}    = ExpctdOutsToUse{i1};
        RowsTaken{i1}     = (1:size(DtsetFeatsToUse{i1}, 1))';
        DtsetSupp{i1}     = SupplDtset{i1};
        continue
    end
    UniqueObsBef = size(unique(DtsetFeatsToUse{i1}), 1);

    IndsClasses = (ExpctdOutsToUse{i1} == unique(ExpctdOutsToUse{i1})');
    IndNotEnPop = sum(IndsClasses,1) <= 1;
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
        IndsClasses = (ExpctdOutsToUse{i1} == unique(ExpctdOutsToUse{i1})');
    end

    [ClCnt, UnCl]  = groupcounts(ExpctdOutsToUse{i1});
    [~, MjClssInd] = max(ClCnt);
    MajClassVal    = UnCl(MjClssInd);

    ColumnOfMajor = (unique(ExpctdOutsToUse{i1})' == MajClassVal);
    if not(sum(ColumnOfMajor) == 1)
        error('The column of the major class is not unique!')
    end

    IndsOfMajCl = IndsClasses(:,ColumnOfMajor);
    IndsOfMinCl = IndsClasses(:,not(ColumnOfMajor));

    RatioBefResmpl = sum(IndsOfMinCl, 1) ./ sum(IndsOfMajCl);

    switch Technique
        case 'undersampling'
            NumIndsOfMaj = find(IndsOfMajCl);

            PercToRemMaj = 1-min(RatioBefResmpl)./RatioToImpose; % Think about this formula please!

            if KeepCruObs(i1)
                NumIndsDltbl = find(not(CrucialObs{i1}) & IndsOfMajCl);
                RelIndMj2Chg = randperm(numel(NumIndsDltbl), ...
                                        min(ceil(numel(NumIndsOfMaj)*PercToRemMaj), ...
                                        numel(NumIndsDltbl))); % ceil(numel(NumIndsMin2ResTmp)*PercToRemMin(i2) remain because you have in any case to remove that number of points!
                IndsToChange = NumIndsDltbl(RelIndMj2Chg);
            else
                RelIndMj2Chg = randperm(numel(NumIndsOfMaj), ceil(numel(NumIndsOfMaj)*PercToRemMaj));
                IndsToChange = NumIndsOfMaj(RelIndMj2Chg);
            end

            IndsOfMajCl(IndsToChange) = false;

            if size(IndsOfMinCl, 2) >= 2
                MinorClass = ( min(sum(IndsOfMinCl,1)) == sum(IndsOfMinCl,1) );

                IndsMin2Res = IndsOfMinCl(:, not(MinorClass));
                IndsAbstMin = IndsOfMinCl(:, MinorClass);
                if size(IndsAbstMin, 2) >= 2
                    error('Minor class should be just one!')
                end

                RatBefResMin = sum(IndsAbstMin,1)./sum(IndsMin2Res,1);
                PercToRemMin = 1-RatBefResMin; % Think about this formula please!
                for i2 = 1:numel(PercToRemMin)
                    NumIndsMin2ResTmp = find(IndsMin2Res(:,i2));

                    if KeepCruObs(i1)
                        NumIndsPntsDltbl = find(not(CrucialObs{i1}) & IndsMin2Res(:,i2));
                        RelIndsMin2ChTmp = randperm(numel(NumIndsPntsDltbl), ...
                                                    min(ceil(numel(NumIndsMin2ResTmp)*PercToRemMin(i2)), ...
                                                    numel(NumIndsPntsDltbl))); % ceil(numel(NumIndsMin2ResTmp)*PercToRemMin(i2) remain because you have in any case to remove that number of points!
                        IndsToChngMinTmp = NumIndsPntsDltbl(RelIndsMin2ChTmp);
                    else
                        RelIndsMin2ChTmp = randperm(numel(NumIndsMin2ResTmp), ceil(numel(NumIndsMin2ResTmp)*PercToRemMin(i2)));
                        IndsToChngMinTmp = NumIndsMin2ResTmp(RelIndsMin2ChTmp);
                    end
        
                    IndsMin2Res(IndsToChngMinTmp, i2) = false;
                end

                IndsOfMinCl(:, not(MinorClass)) = IndsMin2Res;
                if not(isequal(IndsOfMinCl(:,MinorClass), IndsAbstMin))
                    error('Indices of minor class do not match!')
                end
            end

            [NumIndsOfMin, ~]  = find(IndsOfMinCl);
            RelIndsMLDsetToUse = [NumIndsOfMin; find(IndsOfMajCl)];

            RatioAfterRes = sum(IndsOfMinCl,1)./sum(IndsOfMajCl);
            if any((any(IndsOfMinCl & IndsOfMajCl))) || any((round(RatioToImpose, 1) ~= round(RatioAfterRes, 1)))
                error('Something went wrong in re-attributing the correct ratio between positive and negative outputs!')
            end

        case 'oversampling'
            NumIndsOfMaj = find(IndsOfMajCl);
            NumIndsOfMin = cell(1, size(IndsOfMinCl, 2));
            for i2 = 1:size(IndsOfMinCl, 2)
                NumIndsOfMin{i2} = find(IndsOfMinCl(:,i2));
            end

            PercToAdd = RatioToImpose./RatioBefResmpl; % Think about this formula please!

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

        case 'smote'
            i2 = 1;
            IndsOfClssNew = (ExpctdOutsToUse{i1} == unique(ExpctdOutsToUse{i1})');
            RatioAfterRes = RatioBefResmpl;
            while any(round(RatioAfterRes, 1) < round(RatioToImpose, 1)) && (i2 <= 1000)
                PercToAdd = RatioToImpose ./ RatioAfterRes; % Think about this formula please!
    
                NumObsCl = sum(IndsOfClssNew,1);
                NNeighb  = NumObsCl-1; % min(NumObsCl-1, 5);
                ObsToAdd = min([0, max(PercToAdd-1, 0)], NNeighb);
    
                [DatasetEvsFeatsArr, ExpOutsOut{i1}, ...
                        ~, ExpOutsAddedArr] = smote(table2array(DtsetFeatsToUse{i1}), ObsToAdd, ...
                                                        NNeighb, 'Class',ExpctdOutsToUse{i1});
    
                TblSyntDates2Add  = array2table(NaT(1, size(DtsetDatesToUse{i1}, 2)), 'VariableNames',DtsetDatesToUse{i1}.Properties.VariableNames);
                DtsetDatesOut{i1} = [DtsetDatesToUse{i1}; repmat(TblSyntDates2Add, length(ExpOutsAddedArr), 1)]; % Supposing that synthetic data is appended at the end! Check it!
                DtsetFeatsOut{i1} = array2table(DatasetEvsFeatsArr, 'VariableNames',DtsetFeatsToUse{i1}.Properties.VariableNames);
                % DatasetFeatsAdded = array2table(DatasetFeatsAddedArr, 'VariableNames',DtsetFeatsToUse{i1}.Properties.VariableNames); % DatasetFeatsAddedArr was the argument that now is ~ in smote function!
                RowsTaken{i1}     = [(1:size(DtsetFeatsToUse{i1},1))'; nan(length(ExpOutsAddedArr), 1)]; % Supposing that synthetic data is appended at the end! Check it!
                TblSyntSuppl2Add  = array2table(nan(1, size(SupplDtset{i1}, 2)), 'VariableNames',SupplDtset{i1}.Properties.VariableNames);
                DtsetSupp{i1}     = [SupplDtset{i1}; repmat(TblSyntSuppl2Add, length(ExpOutsAddedArr), 1)]; % Supposing that synthetic data is appended at the end! Check it!
    
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

    if not(strcmpi(Technique,'smote'))
        DtsetDatesOut{i1} = DtsetDatesToUse{i1}(RelIndsMLDsetToUse,:);
        DtsetFeatsOut{i1} = DtsetFeatsToUse{i1}(RelIndsMLDsetToUse,:);
        ExpOutsOut{i1}    = ExpctdOutsToUse{i1}(RelIndsMLDsetToUse,:);
        RowsTaken{i1}     = RelIndsMLDsetToUse;
        DtsetSupp{i1}     = SupplDtset{i1}(RelIndsMLDsetToUse,:);
    end
end

end