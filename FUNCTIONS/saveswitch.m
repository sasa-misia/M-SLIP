function saveswitch(Path, VariablesToSave)

% AUTOMATIC SWITCH OF SAVE VERSION
%   
% Required arguments:
%   - Path : must be a string or char containing the filename full path or
%   just the name of the file (in this case it will be saved in the current
%   working directory)
%   
%   - VariablesToSave : must be a string, a char or a cell containing the 
%   previous types. Could be a single element or array.

%% Inputs check and manipulation
if not(any(strcmp(class(Path), ["string", "char"])))
    error('First argument must be a char or a string!')
end

if any(strcmp(class(VariablesToSave), ["string", "char"]))
    VariablesToSave = cellstr(VariablesToSave);
elseif strcmp(class(VariablesToSave), "cell")
else
    error(['Second argument must be a string, char, or cell! ' ...
           'You should also not use {:} at the end of your variable.'])
end

for i1 = 1:length(VariablesToSave)
    eval(strcat(VariablesToSave{i1}, " = evalin('caller',VariablesToSave{i1});"));
end

[FilePath, Filename, ~] = fileparts(Path);
if not(exist(FilePath, 'dir'))
    mkdir(FilePath)
end

%% Core
try
    lastwarn('', '');
    save(Path, VariablesToSave{:})
    [warnMsg, warnId] = lastwarn();
    if not(isempty(warnId)) && contains(warnMsg,'was not saved.')
        error(warnMsg)
    elseif not(isempty(warnId)) && not(contains(warnMsg,'was not saved.'))
        error('A warning message was released while saving files... Please check!')
    end
catch me1
    if any(contains(me1.message, {'Unable to save file','was not saved.'}))
        warning(['There were some problems in saving ', Filename, '.mat file with v7.0! v7.3 will be tried instead.'])
        try
            save(Path, VariablesToSave{:}, '-v7.3')
            disp([Filename,'.mat file was correctly saved with v7.3'])
        catch me2
            error('Something went wrong also with v7.3! Please check!')
            getReport(me2)
        end
    else
        error('Unexpected error while saving files. Please check!')
        getReport(me1)
    end
end

end