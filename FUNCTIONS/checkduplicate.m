function [WriteFile] = checkduplicate(FigWherePrompt, DataToWrite, FilePath, NewFileName)
%CHECKDUPLICATE
%
%       checkduplicate(FigWherePrompt, DataToWrite, FilePath, NewFileName) 
%       check if a file already exist. In that case it will check if columns 
%       of the two files are the same.

cd(FilePath)
WriteFile = true;

if isfile(NewFileName)
    Options = {'Yes, thanks', 'No, for God!'};
    DeleteFile = uiconfirm(FigWherePrompt, ['There is an existing association file. ' ...
                                            'Do you want to overwrite it?'], ...
                                            'Window type', 'Options',Options);

    if strcmp(DeleteFile,'Yes, thanks')
        delete(NewFileName)
    else
        WriteFile = false;
        OldExcel = readcell(NewFileName, 'Sheet','Association');
        OldEqualNew = isequal(size(OldExcel), size(DataToWrite)) && ...
                      all( strcmp(string(OldExcel(2:end,1)), string(DataToWrite(2:end,1))) );
        if ~OldEqualNew
            DeleteFile = uiconfirm(FigWherePrompt, ['Row of the first column are different! ' ...
                                                    'If you mantain the previous file, ' ...
                                                    'you will probably get an error. ' ...
                                                    'Do you want to overwrite it?'], ...
                                                    'Window type', 'Options',Options);
            if strcmp(DeleteFile,'Yes, thanks')
                delete(NewFileName)
                WriteFile = true;
            end
        end
    end

end

end