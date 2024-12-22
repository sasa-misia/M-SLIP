function [filesList, foldsList] = list_content_folder(startPath)

arguments
    startPath (1,:) char {mustBeFolder}
end

sl = filesep;

filesList = {startPath};
foldsList = {};
while any(isfolder(filesList))
    indPreFold = false(1, numel(filesList));
    contnt2Add = {};
    for i1 = 1:numel(filesList)
        if isfolder(filesList{i1})
            indPreFold(i1) = true;
            newCntFold = strcat(filesList{i1},sl,{dir(filesList{i1}).name});
            contnt2Add = [contnt2Add, newCntFold(3:end)]; % newCntFold(3:end) because first two are . and ..
        end
    end
    foldsList = [foldsList, filesList(indPreFold)];
    filesList(indPreFold) = [];
    filesList = [filesList, contnt2Add];
end

end