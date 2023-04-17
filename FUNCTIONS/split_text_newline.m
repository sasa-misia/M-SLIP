function NewCellArrayText = split_text_newline(CellArrayText, MaxDim)

if ~iscell(CellArrayText)
    error('First input must be a cell array containing char')
end

IndTooLongText = cellfun(@(x) length(x)>MaxDim, CellArrayText);
IndShortText   = not(IndTooLongText);

CellArrayText(IndShortText) = cellfun(@(x) [x, blanks(MaxDim+1-length(x))], CellArrayText(IndShortText), 'UniformOutput',false);

if any(IndTooLongText)
    TooLongText = CellArrayText(IndTooLongText);
    NumOfSplits = cellfun(@(x) 1:fix(length(x)/MaxDim), TooLongText, 'UniformOutput',false);
    NewText = cell(1, length(TooLongText));
    for i1 = 1:length(TooLongText)
        SizePadded = MaxDim*ceil(length(TooLongText{i1})/MaxDim);
        TextPadded = [TooLongText{i1}, blanks(SizePadded-length(TooLongText{i1}))];
        TextInColumn = reshape(TextPadded, MaxDim, [])';
        PartToAdd    = repmat('  ', ceil(length(TooLongText{i1})/MaxDim), 1);
        PartToAdd(NumOfSplits{i1},:) = repmat(['-', newline], length(NumOfSplits{i1}), 1);
        NewText{i1} = reshape([TextInColumn, PartToAdd]', 1, []);
    end
    CellArrayText(IndTooLongText) = NewText;
end

NewCellArrayText = CellArrayText;

end