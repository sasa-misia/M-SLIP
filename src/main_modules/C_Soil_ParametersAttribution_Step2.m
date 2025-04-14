if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading of variables previously created
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'       ], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll');
load([fold_var,sl,'SoilParameters.mat'        ], 'AAll','CohesionAll','KtAll','PhiAll','nAll');
load([fold_var,sl,'LithoPolygonsStudyArea.mat'], 'FileName_LithoAssociation','LithoPolygonsStudyArea','LithoAllUnique');

%% Options
AssOpts = checkbox2({'Manual colors litho classes', ...
                     'Manual colors soil units (DSC)', ...
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

[SoilAssociation, ...
    SoilParameters] = read_association_spreadsheet([fold_user,sl,FileName_LithoAssociation], ...
                                                   LithoPolygonsStudyArea, LithoAllUnique, ...
                                                                    fileType='Soil', slColors=ClrsChc, alertFig=Fig);

%% InPolygon Procedure
tic
ProgressBar.Indeterminate = 'off';
for i1 = 1:size(SoilParameters, 1)
    ProgressBar.Message = ['Working on LU n. ',num2str(i1),' of ', num2str(size(SoilParameters, 1))];
    ProgressBar.Value = i1/size(SoilParameters, 1);

    CurrPolygon = SoilParameters{i1, 'Polygon'};
    [ppLU, eeLU] = getnan2([CurrPolygon.Vertices; nan, nan]);
    for i2 = 1:numel(CohesionAll)
        IndRelInLUPoly = find(inpoly([xLonStudy{i2},yLatStudy{i2}], ppLU, eeLU) == 1);

        CohesionAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndRelInLUPoly)) = SoilParameters{i1, 'c'  };

        PhiAll{     i2}(IndexDTMPointsInsideStudyArea{i2}(IndRelInLUPoly)) = SoilParameters{i1, 'phi'};

        KtAll{      i2}(IndexDTMPointsInsideStudyArea{i2}(IndRelInLUPoly)) = SoilParameters{i1, 'kt' };

        AAll{       i2}(IndexDTMPointsInsideStudyArea{i2}(IndRelInLUPoly)) = SoilParameters{i1, 'A'  };

        nAll{       i2}(IndexDTMPointsInsideStudyArea{i2}(IndRelInLUPoly)) = SoilParameters{i1, 'n'  };
    end

    disp(['Finished LU',num2str(i1),'of ',num2str(size(SoilParameters, 1))])
end
ProgressBar.Indeterminate = 'on';

if ChckAss
    ProgressBar.Message = 'Checking association...';

    AttrCheck = check_poly2grid([xLongAll; yLatAll], [CohesionAll; PhiAll; KtAll; AAll; nAll], SoilParameters{:, 'Polygon'});
    if not(all(AttrCheck)); error('Some polygons were not correctly associated!'); end
end
toc

%% Saving...
ProgressBar.Message = 'Saving...';

% Variables to save
VarsSoilPars = {'SoilAssociation', 'SoilParameters'};
VarsSoil2Upd = {'CohesionAll', 'PhiAll', 'KtAll', 'AAll', 'nAll'};

save([fold_var,sl,'LUDSCMapParameters.mat'], VarsSoilPars{:})
save([fold_var,sl,'SoilParameters.mat'    ], VarsSoil2Upd{:}, '-append')
if exist([fold_var,sl,'TopSoil'], 'var')
    save([fold_var,sl,'TopSoilParameters.mat'], VarsSoilPars{:})
end