if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Cancelable','off', 'Message','Reading files...');
drawnow

%% Loading data
sl = filesep;

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

MdlType = find([exist([fold_res_ml_curr,sl,'MLMdlA.mat'], 'file'), ...
                exist([fold_res_ml_curr,sl,'MLMdlB.mat'], 'file')]);
if not(isscalar(MdlType)); error('More than one model found in your folder!'); end
switch MdlType
    case 1
        load([fold_res_ml_curr,sl,'MLMdlA.mat'], 'MLMdl','MLPerf','ModelInfo')
        MdlMode = ModelInfo.ANNsOptions.TrainMode;
        CurrFts = ModelInfo.Dataset(1).Datasets.Feats;

    case 2
        load([fold_res_ml_curr,sl,'MLMdlB.mat'], 'MLMdl','MLPerf','ModelInfo')
        MdlMode = ModelInfo.MdlMode;
        CurrFts = ModelInfo.DatasetInfo{1}.FeaturesNames{:};

    otherwise
        error('No trained ModelA or B found!')
end

DsetPrt4FI = ModelInfo.FeatureImportance.Dataset;

%% Options
PltOpts = checkbox2({'Show plots', 'Dynamic upper limit', 'Model filter', ...
                     'Custom model names'}, 'DefInp',[0, 0, 1, 0], 'OutType','LogInd');

ShowPlt = PltOpts(1);
DynUpLm = PltOpts(2);
FiltMdl = PltOpts(3);
CstmNms = PltOpts(4);

if not(DynUpLm)
    FixdLimY = str2double(inputdlg2({'Upper limit in % :'}, 'DefInp',{'100'}));
end

IndMdls2Tk = true(1, size(MLMdl,2));
if FiltMdl
    Mtr4Flt = char(listdlg2({'Metric to use for filter'}, {'MSE', 'AUROC', 'Loss'}));
    switch Mtr4Flt
        case 'MSE'
            TextMetr = 'MSE';
            TestMetr = [MLPerf{'Err','Test'}{:}{'MSE',:}];

        case 'AUROC'
            TextMetr = 'AUC';
            TestMetr = [MLPerf{'ROC','Test'}{:}{'AUC',:}{:}];

        case 'Loss'
            TextMetr = 'Loss';
            TestMetr = [MLPerf{'Err','Test'}{:}{'Loss',:}];
    end
    MetrThr = str2double(inputdlg2({[TextMetr,' threshold for models (max: ', ...
                                     num2str(max(TestMetr)),'; min: ', ...
                                     num2str(min(TestMetr))]}, 'DefInp',{num2str(mean([min(TestMetr),max(TestMetr)]))}));
    IndMdls2Tk = TestMetr <= MetrThr;
    if strcmp(Mtr4Flt,'AUROC')
        IndMdls2Tk = TestMetr >= MetrThr;
    end
end

FtsToUse = checkbox2(CurrFts, 'Title','Features to plot:');

FeatsLabels = array2table(CurrFts, 'VariableNames',CurrFts);
if CstmNms
    FtsNewLabls = inputdlg2(strcat({'New name for '},CurrFts), 'DefInp',CurrFts);
    FeatsLabels = array2table(FtsNewLabls, 'VariableNames',CurrFts);
end

if size(MLMdl, 2) > 3
    ClrsFI  = repmat({'#0097df'}, 1, size(MLMdl, 2)); % Colors
else
    ClrsFI  = {'#739373', '#d3643c', '#0097df'}; % Colors
end

%% Plot
[~, AnlFldNm] = fileparts(fold_res_ml_curr);
fold_fig_curr = [fold_fig,sl,'Feature Importance',sl,AnlFldNm];

if ~exist(fold_fig_curr, 'dir')
    mkdir(fold_fig_curr)
end

ANNsNames = MLMdl.Properties.VariableNames;
for i1 = 1:length(IndMdls2Tk)
    if not(IndMdls2Tk(i1)); continue; end % To skip cycle if not good model

    CurrFln = ['Feature importance model n - ',num2str(i1),' - Dataset ',DsetPrt4FI];
    CurrFig = figure(i1);
    CurrAxs = axes(CurrFig, 'FontName',SlFont, 'FontSize',SlFnSz);
    set(CurrFig, 'Name',CurrFln, 'visible','off')

    CurrPssFts = MLMdl{'FeatsConsidered',i1}{:};
    CrrFts2Use = CurrPssFts(ismember(CurrPssFts, FtsToUse));
    CurrFtsNms = FeatsLabels{1, CrrFts2Use};

    ImpInPercs = MLMdl{'FeatsImportance',i1}{:}{'PercentagesMSE',CrrFts2Use}*100;
    FeatsNames = categorical(CurrFtsNms);
    FeatsNames = reordercats(FeatsNames, CurrFtsNms); % DON'T DELETE THIS ROW!!! Is necessary even if FeaturesNames is already in the correct order!
    CurrntLoss = MLPerf{'Err','Test'}{:}{'Loss',i1};
    CrrntAUROC = MLPerf{'ROC','Test'}{:}{'AUC',i1}{:};
    switch MdlMode
        case {'Classic (V)', 'Classic (L)', 'Cross Validation (K-Fold M)', ...
                'Cross Validation (K-Fold V)', 'Auto', 'Sensitivity Analysis', ...
                    'Deep (L)', 'Deep (V)'}
            StructLyrs = MLMdl{'Structure',i1}{:};
            StructStrn = strjoin({num2str(StructLyrs)});

        case 'Logistic Regression'
            StructStrn = '-';

        otherwise
            error('ANNMode not recognized during Feature Importance plots!')
    end

    CurrBarPlt = bar(CurrAxs, FeatsNames, ImpInPercs, 'FaceColor',ClrsFI{i1});

    IndRndFeat = contains(CrrFts2Use, 'Rand', 'IgnoreCase',true);
    if any(IndRndFeat) && (sum(IndRndFeat) == 1)
        yRandFeat = yline(CurrAxs, ImpInPercs(IndRndFeat), '--', 'Color','r', 'LineWidth',1);
    end

    xBarPos = CurrBarPlt(1).XEndPoints;
    yBarPos = CurrBarPlt(1).YEndPoints;
    [~, FeatOrd] = sort(CurrBarPlt(1).YData, 'descend');
    BarLbls = string(1:length(FeatsNames));
    [~, FeatOrd2] = sort(FeatOrd, 'ascend');
    BarLbls = BarLbls(FeatOrd2);
    text(xBarPos, yBarPos, BarLbls, 'HorizontalAlignment','center', 'VerticalAlignment','bottom', 'FontName',SlFont ,'FontSize',0.7*SlFnSz)

    if DynUpLm
        UpYLim = min(ceil(1.10*max(ImpInPercs)), 100);
    else
        UpYLim = FixdLimY;
    end

    ylim([0, UpYLim])
    ylabel('Feature Importance [%]', 'FontName',SlFont, 'FontSize',SlFnSz)
    CurrAxs.YAxis.FontSize = SlFnSz;

    xtickangle(CurrAxs, 90)
    xlabel(' ', 'FontName',SlFont, 'FontSize',SlFnSz)
    CurrAxs.XAxis.FontSize = SlFnSz;
    
    pbaspect([3,1,1])

    title(['Feature Importance (Model n. ',ANNsNames{i1},'; Dataset ',DsetPrt4FI,')'], 'FontName',SlFont, 'FontSize',1.5*SlFnSz)
    subtitle(['Loss: ',num2str(CurrntLoss),'; Test AUC: ',num2str(CrrntAUROC), ...
              '; Struct: [',StructStrn,']'], 'FontName',SlFont, 'FontSize',SlFnSz)

    %% Showing plot and saving...
    if ShowPlt
        set(CurrFig, 'visible','on');
        pause
    end

    exportgraphics(CurrFig, [fold_fig_curr,sl,CurrFln,'.png'], 'Resolution',600);
    close(CurrFig)
end