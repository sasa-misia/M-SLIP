function rgbColors = readcolors(colors2Read)

% RETURN THE CORRECT PIXEL SIZE TO PLOT
%   
% Outputs:
%   [RGBColors] is a matrix of 3 columns with rgb (range [0 255])
%   
% Required arguments:
%   - Cells : a cell array containing strings or numbers with colors.

arguments
    colors2Read (:,:) cell {mustBeVector}
end

%% Check input
for i1 = 1:numel(colors2Read)
    if not(ischar(colors2Read{i1}) || isstring(colors2Read{i1}) || isnumeric(colors2Read{i1}))
        error('Each cell must contain char, string, or numeric value!')
    end
    if isnumeric(colors2Read{i1})
        if numel(colors2Read{i1}) ~= 3
            error(['Element n. ',num2str(i1),' is numeric and contain more/less than 3 numbers!'])
        end
        if all(colors2Read{i1} < 1) && any(colors2Read{i1} > 0)
            colors2Read{i1} = colors2Read{i1}.*255; % Conversion full colors
            warning(['Element n. ',num2str(i1),' was numeric and converted to full scale [0, 255]!'])
        end
        colors2Read{i1} = min(ceil(colors2Read{i1}), 255);
        colors2Read{i1} = strjoin(string(colors2Read{i1}), ', ');
    end
end

%% Settings
colorsStr = string(colors2Read);
rgbColors = zeros(numel(colors2Read), 3);
for i1 = 1:numel(colorsStr)
    tempClr = str2num(colorsStr(i1));
    if numel(tempClr) == 3
        rgbColors(i1,:) = tempClr;
    else
        tempStr = char(strrep(colorsStr(i1), '#', ''));
        if numel(tempStr) ~= 6; error(['Color ',num2str(i1),' not recognized: it must be rgb or hex!']); end
        rgbColors(i1,:) = [double(hex2dec(tempStr(1:2))), ...
                           double(hex2dec(tempStr(3:4))), ...
                           double(hex2dec(tempStr(5:6)))];
    end
end

end