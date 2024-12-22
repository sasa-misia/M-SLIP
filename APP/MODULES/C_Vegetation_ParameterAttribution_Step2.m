if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading of variables previously created
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'     ], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load([fold_var,sl,'VegetationParameters.mat'], 'BetaStarAll','RootCohesionAll')
load([fold_var,sl,'VegPolygonsStudyArea.mat'], 'FileName_VegAssociation','VegPolygonsStudyArea','VegetationAllUnique')

[InfoDetExst, InfoDet2Use] = load_info_detected(fold_var);

ModVegInDet = 'No';
if InfoDetExst
    ModVegInDet = char(listdlg2('Delete vegetation in det soil slips?', {'Yes', 'No', 'Average'}));
end

VegAttribution = true;

%% Options
AssOpts = checkbox2({'Manual colors veg classes', ...
                     'Manual colors veg units (DVC)', ...
                     'Check association at the end'}, 'OutType','LogInd', 'DefInp',[0, 0, 1], ...
                                                      'Title','Association options');

ClrsChc = AssOpts(1:2);
ChckAss = AssOpts(3);

%% Data extraction
xLonStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
if not(ChckAss); clear('xLongAll'); end

yLatStudy = cellfun(@(x,y) x(y), yLatAll , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
if not(ChckAss); clear('yLatAll'); end

%% Excel reading and coefficient matrix writing
ProgressBar.Message = 'Reading excel...';

[VegAssociation, ...
    VegParameters] = read_association_spreadsheet([fold_user,sl,FileName_VegAssociation], ...
                                                   VegPolygonsStudyArea, VegetationAllUnique, ...
                                                                    fileType='Vegetation', slColors=ClrsChc, alertFig=Fig);

%% InPolygon Procedure
if strcmp(ModVegInDet, 'Yes') || strcmp(ModVegInDet, 'Average')
    load([fold_var,sl,'MorphologyParameters.mat'], 'SlopeAll')
    DetDTM = InfoDet2Use{:,3};
    DetInd = InfoDet2Use{:,4}; % These indices are relative to StudyArea, not to xLongAll!
    DetIdA = arrayfun(@(x,y) IndexDTMPointsInsideStudyArea{x}(y), DetDTM, DetInd); % Now these are relative to xLongAll
    Sl2Use = arrayfun(@(x,y) SlopeAll{x}(y), DetDTM, DetIdA);
    Cr2Mnt = zeros(size(Sl2Use)); % Cr2Mnt = arrayfun(@(x,y) RootCohesionAll{x}(y), DetDTM, DetIdA);
    Bs2Mnt = arrayfun(@cosd, Sl2Use); % arrayfun(@(x,y) BetaStarAll{x}(y), DetDTM, DetIdA);
end

tic
ProgressBar.Indeterminate = 'off';
for i1 = 1:size(VegParameters, 1)
    ProgressBar.Message = ['Working on VU n. ',num2str(i1),' of ', num2str(size(VegParameters, 1))];
    ProgressBar.Value = i1/size(VegParameters, 1);

    CurrPolygon = VegParameters{i1, 'Polygon'};
    [ppVU, eeVU] = getnan2([CurrPolygon.Vertices; nan, nan]);
    for i2 = 1:numel(RootCohesionAll)
        IndRelInLUPoly = find(inpoly([xLonStudy{i2},yLatStudy{i2}], ppVU, eeVU) == 1);

        RootCohesionAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndRelInLUPoly)) = VegParameters{i1, 'cr'  };

        if VegParameters{i1, 'beta'} ~= 0
            BetaStarAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndRelInLUPoly)) = VegParameters{i1, 'beta'};
        end
    end

    disp(['Finished VU',num2str(i1),'of ',num2str(size(VegParameters, 1))])
end
ProgressBar.Indeterminate = 'on';

if ChckAss
    ProgressBar.Message = 'Checking association...';

    AttrCheck = check_poly2grid([xLongAll; yLatAll], [RootCohesionAll; BetaStarAll], VegParameters{:, 'Polygon'});
    if not(all(AttrCheck)); error('Some polygons were not correctly associated!'); end
end

if strcmp(ModVegInDet, 'Yes') || strcmp(ModVegInDet, 'Average') % Must be after check, because otherwise the check will fail!
    for i1 = 1:length(Bs2Mnt)
        if strcmp(ModVegInDet, 'Average')
            RootCohesionAll{DetDTM(i1)}(DetIdA(i1)) = (Cr2Mnt(i1) + RootCohesionAll{DetDTM(i1)}(DetIdA(i1))) / 2;
            BetaStarAll{DetDTM(i1)}(DetIdA(i1))     = (Bs2Mnt(i1) + BetaStarAll{DetDTM(i1)}(DetIdA(i1))) / 2;
        else
            RootCohesionAll{DetDTM(i1)}(DetIdA(i1)) = Cr2Mnt(i1);
            BetaStarAll{DetDTM(i1)}(DetIdA(i1))     = Bs2Mnt(i1);
        end
    end
end
toc

%% Saving..
ProgressBar.Message = 'Finising...';

VariablesVUPar = {'VegAssociation', 'VegParameters'};
VariablesVgPar = {'RootCohesionAll', 'BetaStarAll'};

save([fold_var,sl,'UserVeg_Answers.mat'     ], 'VegAttribution', '-append');
save([fold_var,sl,'VUDVCMapParameters.mat'  ], VariablesVUPar{:})
save([fold_var,sl,'VegetationParameters.mat'], VariablesVgPar{:}, '-append');