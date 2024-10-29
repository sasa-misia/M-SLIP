function prjCRS = load_prjcrs(fold_var)

arguments
    fold_var (1,:) char {mustBeFolder}
end

sl = filesep;

load([fold_var,sl,'MorphologyParameters.mat'], 'OriginallyProjected','SameCRSForAll')

if OriginallyProjected && SameCRSForAll
    load([fold_var,sl,'MorphologyParameters.mat'], 'OriginalProjCRS')

    prjCRS = OriginalProjCRS;
else
    prjEPSG = str2double(inputdlg2({['DTM EPSG (Sicily -> 32633, ' ...
                                     'Emilia Romagna -> 25832):']}, 'DefInp',{'25832'}));
    prjCRS = projcrs(prjEPSG);
end

end