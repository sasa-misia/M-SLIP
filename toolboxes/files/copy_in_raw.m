function [newPaths, wasCopied] = copy_in_raw(mainPath, saveFold, file2Scn)

arguments
    mainPath (1,:) char {mustBeFolder}
    saveFold (1,:) char
    file2Scn (1,:) cell
end

file2Scn = cellstr(file2Scn);
for i1 = 1:numel(file2Scn)
    if not(isfile(file2Scn{i1}))
        error('Every path in file2Scn must be a file!')
    end
end

if isfile(saveFold) || isfolder(saveFold)
    error('saveFold must be specified just as a name (ex: Lithology), not a path!')
end

sl = filesep;

filesMain = list_content_folder(mainPath);
copyPath  = [mainPath,sl,saveFold];
newPaths  = file2Scn;
wasCopied = false(1, numel(file2Scn));

for i1 = 1:numel(file2Scn)
    if not(any(strcmp(file2Scn{i1}, filesMain)))
        if not(exist(copyPath, 'dir'))
            mkdir(copyPath)
        end
        copyindirectory('all', copyPath, 'mode','multiple', 'file2copy',file2Scn{i1})
        [~, fileNmPrt, fileExt] = fileparts(file2Scn{i1});
        newPaths{i1}  = [copyPath,sl,fileNmPrt,fileExt];
        wasCopied(i1) = true;
    end
end

end