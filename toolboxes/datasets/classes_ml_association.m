function [clssStudy, clssPolys, featNme, lablNme, polyNme, polyObj] = classes_ml_association(classesML, xLonStudy, yLatStudy, fold_var, Options)

arguments
    classesML (2,4) table
    xLonStudy (1,:) cell
    yLatStudy (1,:) cell
    fold_var  (1,:) char {mustBeFolder}
    Options.categVars (1,1) logical = false
    Options.feats2Use (1,:) string = "allfeats"
    Options.uiFig2Use (1,1) matlab.ui.Figure = uifigure
end

if numel(xLonStudy) ~= numel(yLatStudy)
    error('xLonStudy and yLatStudy must have same sizes!')
end
for i1 = 1:numel(xLonStudy)
    if not(isnumeric(xLonStudy{i1})) || not(isnumeric(yLatStudy{i1}))
        error(['Cell n. ',num2str(i1),' of xLonStudy or yLatStudy do not have numeric values!'])
    end
    if not(isequal(size(xLonStudy{i1}), size(yLatStudy{i1})))
        error(['xLonStudy or yLatStudy do not have same sizes in cell n. ',num2str(i1)])
    end
end
categVars = Options.categVars;
feats2Use = lower(Options.feats2Use);
uiFig2Use = Options.uiFig2Use;

progBar = uiprogressdlg(uiFig2Use, 'Title','Please wait', 'Indeterminate','on', ...
                                   'Message','Dataset: reading categorical part...');

%% preliminary operations
sl = filesep;
[featNme, lablNme, polyNme, polyObj] = deal({}); % initialization
clssPolys = table; % initialization

% sub soil
if any(contains(feats2Use, ["sub", "allfeats"]))
    load([fold_var,sl,'LithoPolygonsStudyArea.mat'], 'LithoAllUnique','LithoPolygonsStudyArea')
    featNme = [featNme, {'SubClass'}];
    lablNme = [lablNme, {'Sub soil'}];
    polyNme = [polyNme, {LithoAllUnique}];
    polyObj = [polyObj, {LithoPolygonsStudyArea}];
end

% top soil
if any(contains(feats2Use, ["top", "allfeats"]))
    load([fold_var,sl,'TopSoilPolygonsStudyArea.mat'], 'TopSoilAllUnique','TopSoilPolygonsStudyArea')
    featNme = [featNme, {'TopClass'}];
    lablNme = [lablNme, {'Top soil'}];
    polyNme = [polyNme, {TopSoilAllUnique}];
    polyObj = [polyObj, {TopSoilPolygonsStudyArea}];
end

% land use
if any(contains(feats2Use, ["land", "allfeats"]))
    load([fold_var,sl,'LandUsesVariables.mat'], 'AllLandUnique','LandUsePolygonsStudyArea')
    featNme = [featNme, {'LndClass'}];
    lablNme = [lablNme, {'Land use'}];
    polyNme = [polyNme, {AllLandUnique}];
    polyObj = [polyObj, {LandUsePolygonsStudyArea}];
end

% vegetation
if any(contains(feats2Use, ["vegetation", "allfeats"]))
    load([fold_var,sl,'VegPolygonsStudyArea.mat'], 'VegetationAllUnique','VegPolygonsStudyArea')
    featNme = [featNme, {'VegClass'}];
    lablNme = [lablNme, {'Vegetation'}];
    polyNme = [polyNme, {VegetationAllUnique}];
    polyObj = [polyObj, {VegPolygonsStudyArea}];
end

% initialization of arrays
clssStudy = cell(size(featNme));
for i1 = 1:numel(featNme)
    if categVars
        clssStudy{i1} = cellfun(@(x) strings(size(x)), xLonStudy, 'UniformOutput',false);
    else
        clssStudy{i1} = cellfun(@(x) zeros(  size(x)), xLonStudy, 'UniformOutput',false);
    end
end

%% core
for iC = 1:numel(featNme)
    progBar.Message = ['Dataset: associating ',featNme{iC},'...'];

    glbClss = classesML{'Global', lablNme{iC}}{:}{:, 'Title'};

    if not(exist([fold_var,sl,'LithoPolygonsStudyArea.mat'], 'file'))
        warning(['You have selected ',lablNme{iC},' as a feature but there is no file containing ' ...
                 'polygons. Zero values or empty strings will be generated for this feature!' ...
                 'It is highly suggested to use this dataset ONLY with pre-trained models.'])

    else
        [assClss, assNumb, assDesc] = deal(cell(size(polyNme{iC})));
        for i1 = 1:numel(polyNme{iC})
            row2TkRaw = strcmp(polyNme{iC}{i1}, classesML{'Raw', lablNme{iC}}{:}{:, 'Raw data name'});
            if not(any(row2TkRaw))
                warning(['Raw ',lablNme{iC},' class "',polyNme{iC}{i1},'" will be skipped (no match found in excel)'])
                continue
            end
    
            numAssClss = classesML{'Raw', lablNme{iC}}{:}{row2TkRaw, 'Ass. class'};
            if isnan(numAssClss)
                warning(['Raw ',lablNme{iC},' class "',polyNme{iC}{i1},'" will be skipped (not associated)'])
                continue
            end
    
            row2TkGlb = find(numAssClss == classesML{'Global', lablNme{iC}}{:}{:, 'Number'});
            if isempty(row2TkGlb)
                error(['Raw ',lablNme{iC},' class "',polyNme{iC}{i1},'" has an associated ', ...
                       'number that is not present in Main sheet! Check your excel.'])
            end
    
            assClss{i1} = char(classesML{'Global', lablNme{iC}}{:}{row2TkGlb, 'Title'});
            assNumb{i1} = classesML{'Global', lablNme{iC}}{:}{row2TkGlb, 'Number'};
            assDesc(i1) = classesML{'Global', lablNme{iC}}{:}{row2TkGlb, 'Description'};
        end
    
        indNumPrt = cellfun(@(x) isnumeric(x) && not(isempty(x)), assClss);
        assClss(indNumPrt) = cellfun(@(x) num2str(x), assClss(indNumPrt), 'UniformOutput',false); % To convert all numerical values to char

        indStrPrt = cellfun(@(x) ischar(x)||isstring(x), assClss);
    
        [assClssUnq, indUnq] = unique(assClss(indStrPrt)); % Unique is on the string part!
        if numel(assClssUnq) ~= numel(glbClss)
            warning(['The associated classes of ',lablNme{iC},' are less than the ' ...
                     'possible classes in the Main sheet of the association file.'])
        end
    
        assNumbUnq = assNumb(indStrPrt); % Important!
        assNumbUnq = assNumbUnq(indUnq);

        assDescUnq = assDesc(indStrPrt); % Important!
        assDescUnq = assDescUnq(indUnq);
    
        assPolyUnq = repmat(polyshape, 1, length(assClssUnq));
        for i1 = 1:numel(assClssUnq)
            progBar.Message = ['Dataset: union of ',lablNme{iC},' poly n. ',num2str(i1),' of ',num2str(length(assClssUnq))];
            inds2Unify = strcmp(assClssUnq{i1}, assClss);
            assPolyUnq(i1) = union(polyObj{iC}(inds2Unify));
        end
    
        progBar.Message = ['Dataset: indexing of ',lablNme{iC},' classes...'];
        for i1 = 1:numel(assPolyUnq)
            [pp1, ee1] = getnan2([assPolyUnq(i1).Vertices; nan, nan]);
            indsInPoly = cellfun(@(x,y) inpoly([x,y], pp1, ee1), xLonStudy, yLatStudy, 'Uniform',false);
            for i2 = 1:numel(xLonStudy)
                if not(any(indsInPoly{i2})); continue; end
                if categVars
                    clssStudy{iC}{i2}(indsInPoly{i2}) = string(assClssUnq{i1});
                else
                    clssStudy{iC}{i2}(indsInPoly{i2}) = assNumbUnq{i1};
                end
            end
        end
    
        clssPolys(featNme{iC},{'Polys','ClassNames', ...
                               'ClassNum','ClassDescr'}) = {assPolyUnq', assClssUnq', ...
                                                            assNumbUnq', assDescUnq'};
    end
end

end