function [writeFile] = check_duplicate_spreadsheet(uiFig2Use, data2Write, fileName)

% Purpose: function to check if a spreadsheet already exist. In that case,
%          it will check if content of the two files is the same.
% 
% Outputs: 
%       - writeFile   = [logical]
% 
% Inputs:
%       - uiFig2Use   = [matlab.ui.Figure] the ui figure where you have to
%                       decide if you want to write the excel in case of
%                       duplicates.
%       - data2Write  = [cell] the content to write in the Association sheet.
%       - fileName    = [char] the full filename of the file to write.
% 
% Optional inputs:
%       - []
% 
% Dependencies: -

arguments
    uiFig2Use (1,1) matlab.ui.Figure
    data2Write (:,:) cell
    fileName (1,:) char
end

%% Core
writeFile = true;

if isfile(fileName)
    Options = {'Yes, thanks', 'No, for God!'};
    delFile = uiconfirm(uiFig2Use, ['Spreadsheet file already exists. ', ...
                                    'Do you want to overwrite it?'], ...
                                            'Window type', 'Options',Options);

    if strcmp(delFile,'Yes, thanks')
        delete(fileName)
    else
        writeFile = false;
        oldSpreadSht = readcell(fileName, 'Sheet','Association');
        isEqual2New  = isequal(size(oldSpreadSht), size(data2Write)) && ...
                       isequal(string(oldSpreadSht(2:end,1)), string(data2Write(2:end,1)));
        if ~isEqual2New
            delFile = uiconfirm(uiFig2Use, ['Row of the first column are different! ', ...
                                            'If you mantain the previous file, ', ...
                                            'you will probably get an error. ', ...
                                            'Do you want to overwrite it?'], ...
                                                    'Window type', 'Options',Options);
            if strcmp(delFile,'Yes, thanks')
                delete(fileName)
                writeFile = true;
            end
        end
    end

end

end