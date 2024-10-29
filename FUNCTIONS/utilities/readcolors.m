function RGBColors = readcolors(Cells)

% RETURN THE CORRECT PIXEL SIZE TO PLOT
%   
% Outputs:
%   [RGBColors] is a matrix of 3 columns with rgb
%   
% Required arguments:
%   - Cells : a cell array containing strings or numbers with colors.

%% Settings
ColWithClr = string(Cells);
RGBColors  = zeros(numel(Cells), 3);
for i1 = 1:numel(ColWithClr)
    TmpClr = str2num(ColWithClr(i1));
    if numel(TmpClr) == 3
        RGBColors(i1,:) = TmpClr;
    else
        TmpStr = char(strrep(ColWithClr(i1), '#',''));
        if numel(TmpStr) ~= 6; error(['Color ',num2str(i1),' not recognized']); end
        RGBColors(i1,:) = [double(hex2dec(TmpStr(1:2))), ...
                           double(hex2dec(TmpStr(3:4))), ...
                           double(hex2dec(TmpStr(5:6)))];
    end
end

end