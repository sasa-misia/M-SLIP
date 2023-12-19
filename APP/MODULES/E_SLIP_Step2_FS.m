if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% Data import
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'],       'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'MorphologyParameters.mat'],  'SlopeAll')
load([fold_var,sl,'SoilParameters.mat'],        'AAll','CohesionAll','PhiAll','nAll')
load([fold_var,sl,'VegetationParameters.mat'],  'BetaStarAll','RootCohesionAll')
load([fold_var,sl,'AnalysisInformation.mat'],   'StabilityAnalysis')
load([fold_var,sl,'UserStudyArea_Answers.mat'], 'MunSel')
load([fold_var,sl,'UserMorph_Answers.mat'],     'ScaleFactorX','ScaleFactorY')
load([fold_var,sl,'UserVeg_Answers.mat'],       'VegAttribution')
load([fold_var,sl,'DmCum.mat'],                 'DmCumPar')
load([fold_var,sl,'UserTimeSens_Answers.mat'],  'Sr0','H')
if exist([fold_var,sl,'LandUsesVariables.mat'], 'file')
    load([fold_var,sl,'LandUsesVariables.mat'], 'AllLandUnique','IndexLandUsesToRemove')
    LandUsesRemoved = string(AllLandUnique(IndexLandUsesToRemove));
end

%% Calculating DmCum
ProgressBar.Message = 'Calculating DmCum...';

BetaStarStudyArea = cellfun(@(x,y) x(y), BetaStarAll, ...
                                         IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

nStudyArea = cellfun(@(x,y) x(y), nAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

DmCum = cellfun(@(x,y,z) min(x.*y./(z.*H.*(1-Sr0)), 1), DmCumPar, repmat(BetaStarStudyArea, StabilityAnalysis{1}, 1), ...
                                                        repmat(nStudyArea, StabilityAnalysis{1}, 1), 'UniformOutput',false);

%% Values Assigning
ProgressBar.Message = 'Input modeling parameters...';

InputValues = inputdlg2({'Indicate soil Gs (-):', 'Indicate lambda λ (-):', ...
                         'Indicate alpha α (-):'}, 'DefInp',{'2.7', '0.4', '3.4'});

Gs     = str2double(InputValues{1});
Lambda = str2double(InputValues{2});
Alpha  = str2double(InputValues{3});
GammaW = 10;

%% Evalutation of FS
ProgressBar.Message = 'Evaluation of FS...';

if isfile([fold_var,sl,'UserD_Answers.mat']); SubName1 = 'Veget'; else; SubName1 = 'NoVeget'; end
DEMSize   = num2str(round(1000*deg2km(abs(yLatAll{1}(1,1)-yLatAll{1}(2,1))),1));
FldNameFS = char(inputdlg2({'Choose folder name (Results->Factors of Safety):'}, ...
                           'DefInp',{[char(datetime('now', 'format','dd-MM-yy-HH-mm')), ...
                                      '-',SubName1,'-',DEMSize,'m']}));

if exist([fold_res_fs,sl,FldNameFS], 'dir')
    Options = {'Yes, thanks', 'No, for God!'};
    Answer  = uiconfirm(Fig, [FldNameFS,' is an existing folder. ' ...
                              'Do you want to overwrite it?'], 'Existing folder', 'Options',Options);
    switch Answer
        case 'Yes, thanks'
            rmdir([fold_res_fs,sl,FldNameFS], 's')
            mkdir([fold_res_fs,sl,FldNameFS])
        case 'No, for God!'
            return
    end
else
    mkdir([fold_res_fs,sl,FldNameFS])
end

StabilityAnalysis{4} = "Slip";
AnalysisParameters = table(Sr0, H, Gs, Lambda, Alpha, ScaleFactorX, ScaleFactorY, VegAttribution);
AnalysisParameters.MunSelected = {string(MunSel)};
if exist('LandUsesRemoved', 'var'); AnalysisParameters.LandUsesRemoved = {LandUsesRemoved}; end
StabilityAnalysis{5} = AnalysisParameters;

tic
ProgressBar.Indeterminate = 'off';
AnalysisNumber = StabilityAnalysis{1};
for i1 = 1:AnalysisNumber
    ProgressBar.Value   = i1/AnalysisNumber;
    ProgressBar.Message = ['Analysis of event n. ',num2str(i1),' of ',num2str(AnalysisNumber)];

    FactorSafety = cell(1, size(xLongAll,2));
    for i2 = 1:size(xLongAll,2)
        Cohesion = CohesionAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        n        = nAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        Slope    = SlopeAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        A        = AAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        Phi      = PhiAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        RootCohe = RootCohesionAll{i2}(IndexDTMPointsInsideStudyArea{i2});
        Ci       = (Cohesion+RootCohe)+A.*Sr0.*(1-Sr0).^Lambda.*(1-DmCum{i1,i2}).^Alpha;
        Wi_primo = cosd(Slope).*H.*GammaW.*(DmCum{i1,i2}.*(n-1)+Gs.*(1-n)+Sr0.*n.*(1-DmCum{i1,i2}));
        Wi       = cosd(Slope).*H.*GammaW.*(DmCum{i1,i2}.*n+Gs.*(1-n)+Sr0.*n.*(1-DmCum{i1,i2}));

        FactorSafety{i2} = (Wi_primo.*cosd(Slope).*tand(Phi)+Ci)./(Wi.*sind(Slope));
    end

    saveswitch([fold_res_fs,sl,FldNameFS,sl,'Fs',num2str(i1),'.mat'], {'FactorSafety'})
end
ProgressBar.Indeterminate = 'on';
toc

%% Saving...
ProgressBar.Message = 'Saving...';

saveswitch([fold_res_fs,sl,FldNameFS,sl,'AnalysisInformation.mat'], 'StabilityAnalysis');