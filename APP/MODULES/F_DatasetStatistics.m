if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on',  ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading
sl = filesep;

MdlType = find([exist([fold_var,sl,'DatasetMLA.mat'], 'file'), ...
                exist([fold_var,sl,'DatasetMLB.mat'], 'file')]);
if isempty(MdlType); error('No dataset MLA or MLB found!'); end

DsetOpt = {'Tot', 'Pos', 'Neg'}; % Always first Total, then Positive, then Negative

%% Cycle over datasets
for i1 = 1:numel(MdlType)
    switch MdlType(i1)
        case 1
            Fl2LdDst = 'DatasetMLA.mat';
    
        case 2
            Fl2LdDst = 'DatasetMLB.mat';
    
        otherwise
            error('No trained ModelA or B found!')
    end

    load([fold_var,sl,Fl2LdDst], 'DatasetInfo')

    DsetTbl = dataset_extraction(DatasetInfo);
    
    %% Quantiles and limits
    ProgressBar.Message = 'Assessment of quantiles and limits...';

    FtsDset = DsetTbl{'Total', 'Feats'}{:}.Properties.VariableNames;
    
    IdPsPrt = DsetTbl{'Total', 'ExpOuts'}{:} ~= 0;
    IdNgPrt = DsetTbl{'Total', 'ExpOuts'}{:} == 0;

    SkipFts = false(1, numel(FtsDset));
    [DsetPrt, DsetQts, ...
        DsetLms] = deal(array2table(cell(3, numel(FtsDset)), 'RowNames',DsetOpt, 'VariableNames',FtsDset));
    for i2 = 1:numel(FtsDset)
        if iscategorical(DsetTbl{'Total', 'Feats'}{:}{:, FtsDset(i2)})
            SkipFts(i2) = true;
            warning(['Feature "',FtsDset{i2},'" is categorical. It will be skipped!'])
            continue
        end

        DsetPrt{DsetOpt{1}, FtsDset{i2}} = {DsetTbl{'Total', 'Feats'}{:}{:, FtsDset(i2)}            };
        DsetPrt{DsetOpt{2}, FtsDset{i2}} = {DsetTbl{'Total', 'Feats'}{:}{:, FtsDset(i2)}(IdPsPrt, :)};
        DsetPrt{DsetOpt{3}, FtsDset{i2}} = {DsetTbl{'Total', 'Feats'}{:}{:, FtsDset(i2)}(IdNgPrt, :)};
    
        DsetQts{DsetOpt{1}, FtsDset{i2}} = {array2table(quantile(DsetPrt{DsetOpt{1}, FtsDset{i2}}{:}, [.25, .5, .75])', ...
                                                                                                'Rownames',{'Q1','Q2','Q3'}, ...
                                                                                                'VariableNames',{'Quantile'})};
        DsetQts{DsetOpt{2}, FtsDset{i2}} = {array2table(quantile(DsetPrt{DsetOpt{2}, FtsDset{i2}}{:}, [.25, .5, .75])', ...
                                                                                                'Rownames',{'Q1','Q2','Q3'}, ...
                                                                                                'VariableNames',{'Quantile'})};
        DsetQts{DsetOpt{3}, FtsDset{i2}} = {array2table(quantile(DsetPrt{DsetOpt{3}, FtsDset{i2}}{:}, [.25, .5, .75])', ...
                                                                                                'Rownames',{'Q1','Q2','Q3'}, ...
                                                                                                'VariableNames',{'Quantile'})};
    
        DsetLms{DsetOpt{1}, FtsDset{i2}} = {array2table(quantile(DsetPrt{DsetOpt{1}, FtsDset{i2}}{:}, [0, 1])', ...
                                                                                                'Rownames',{'Inf','Sup'}, ...
                                                                                                'VariableNames',{'Quantile'})}; % The same of min and max!
        DsetLms{DsetOpt{2}, FtsDset{i2}} = {array2table(quantile(DsetPrt{DsetOpt{2}, FtsDset{i2}}{:}, [0, 1])', ...
                                                                                                'Rownames',{'Inf','Sup'}, ...
                                                                                                'VariableNames',{'Quantile'})}; % The same of min and max!
        DsetLms{DsetOpt{3}, FtsDset{i2}} = {array2table(quantile(DsetPrt{DsetOpt{3}, FtsDset{i2}}{:}, [0, 1])', ...
                                                                                                'Rownames',{'Inf','Sup'}, ...
                                                                                                'VariableNames',{'Quantile'})}; % The same of min and max!
    end
    
    %% Tables
    RowsNms  = [strcat('Min',DsetOpt), strcat('Max',DsetOpt), strcat('Mean',DsetOpt), ...
                strcat('Medn',DsetOpt), strcat('Std',DsetOpt), ...
                strcat('Q1',DsetOpt), strcat('Q2',DsetOpt), strcat('Q3',DsetOpt)];
    StatsTbl = array2table(nan(numel(RowsNms), numel(FtsDset)), 'RowNames',RowsNms, 'VariableNames',FtsDset);
    
    % Minimum, Maximum, Mean, Median, Standard Deviation
    for i2 = 1:numel(FtsDset)
        if SkipFts(i2); continue; end
        for i3 = 1:numel(DsetOpt)
            StatsTbl{['Min' ,DsetOpt{i3}], FtsDset{i2}} = min(DsetPrt{DsetOpt{i3}   , FtsDset{i2}}{:});
            StatsTbl{['Max' ,DsetOpt{i3}], FtsDset{i2}} = max(DsetPrt{DsetOpt{i3}   , FtsDset{i2}}{:});
            StatsTbl{['Mean',DsetOpt{i3}], FtsDset{i2}} = mean(DsetPrt{DsetOpt{i3}  , FtsDset{i2}}{:});
            StatsTbl{['Medn',DsetOpt{i3}], FtsDset{i2}} = median(DsetPrt{DsetOpt{i3}, FtsDset{i2}}{:});
            StatsTbl{['Std' ,DsetOpt{i3}], FtsDset{i2}} = std(DsetPrt{DsetOpt{i3}   , FtsDset{i2}}{:});
        end
    end
    
    % Q1, Q2, Q3
    for i2 = 1:numel(FtsDset)
        if SkipFts(i2); continue; end
        for i3 = 1:numel(DsetOpt)
            StatsTbl{['Q1',DsetOpt{i3}] , FtsDset{i2}} = DsetQts{DsetOpt{i3}, FtsDset{i2}}{:}{'Q1', 'Quantile'};
            StatsTbl{['Q2',DsetOpt{i3}] , FtsDset{i2}} = DsetQts{DsetOpt{i3}, FtsDset{i2}}{:}{'Q2', 'Quantile'};
            StatsTbl{['Q3',DsetOpt{i3}] , FtsDset{i2}} = DsetQts{DsetOpt{i3}, FtsDset{i2}}{:}{'Q3', 'Quantile'};
        end
    end

    %% Save
    ProgressBar.Message = 'Saving...';

    VariablesToUpdate = {'StatsTbl'};
    save([fold_var,sl,Fl2LdDst], VariablesToUpdate{:}, '-append')
end