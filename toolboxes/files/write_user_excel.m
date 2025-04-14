function [] = write_user_excel(fileName, polyClass, fieldName, figObj, contType)

% Purpose: function to create a user association excel in M-SLIP
% 
% Outputs: 
%       - []
% 
% Inputs:
%       - fileName    = [char] the full filename of the excel to create.
%       - polyClass   = [cellstr] the cellstring containing class names.
%       - polyClass   = [char] the type of user excel to write. It can be
%                       one of the following: {'litho', 'veg', 'land use', 
%                       'generic'}.
% 
% Optional inputs:
%       - []
% 
% Dependencies: checkduplicate (M-SLIP)

arguments
    fileName (1,:) char
    polyClass (1,:) cell {iscellstr}
    fieldName (1,:) char
    figObj (1,1) matlab.ui.Figure
    contType (1,:) char = 'generic'
end

contType = lower(contType);
switch contType
    case 'litho'
        dataHead1 = {fieldName, 'US Associated', 'LU Abbrev (For Map)', 'RGB LU (for Map)'};
        dataHead2 = {'US', 'c''(kPa)', 'phi (°)', 'kt (h^-1)', 'A (kPa)', 'n', 'Color'};
        nmSheet2  = 'DSCParameters';

    case 'veg'
        dataHead1 = {fieldName, 'UV Associated', 'VU Abbrev (For Map)', 'RGB VU (for Map)'};
        dataHead2 = {'UV','c_R''(kPa)','\beta (-)','Color'};
        nmSheet2  = 'DVCParameters';

    case 'land use'
        dataHead1 = {fieldName, 'Abbreviation (for Map)', 'RGB (for Map)'};
        dataHead2 = {};
        nmSheet2  = 'DLUCParameters';

    case 'generic'
        dataHead1 = {fieldName, 'Associated Unit', 'Abbrev (For Map)', 'RGB (for Map)'};
        dataHead2 = {'Associated Unit', 'Prop 1', 'Prop 2', 'Prop 3', 'Prop 4', 'Prop 5', 'Prop 6'};
        nmSheet2  = 'DGCParameters';

    otherwise
        error('contType not recognized!')
end

%% Writing excel
data2Wrt1           = cell(numel(polyClass)+1, numel(dataHead1)); % Plus 1 because of header line
data2Wrt1(1, :)     = dataHead1;
data2Wrt1(2:end, 1) = cellstr(polyClass');

data2Wrt2           = dataHead2;

writeFile = check_duplicate_spreadsheet(figObj, data2Wrt1, fileName);
if writeFile
    writecell(data2Wrt1, fileName, 'Sheet','Association');
    writecell(data2Wrt2, fileName, 'Sheet',nmSheet2);
end

end