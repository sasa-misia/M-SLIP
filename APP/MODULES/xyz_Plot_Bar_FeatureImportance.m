% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SelectedFont     = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont     = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition   = 'Best';
end

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
load([fold_res_ml_curr,sl,'TrainedANNs.mat'], 'ANNs','ANNsPerf','ModelInfo')

TestMSE = ANNsPerf{'Err','Test'}{:}{'MSE',:};
DatasetForFeatsImp = ModelInfo.FeatsImportanceDataset;

%% User opts and selection of good models to plot
Options   = {'Yes', 'No'};
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',Options, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

Options   = {'y lim 100%', 'y lim dynamic'};
UpYLimAns = uiconfirm(Fig, 'Where do you want to set the upper limit in graphs?', ...
                           'Up limit', 'Options',Options, 'DefaultOption',2);
if strcmp(UpYLimAns,'y lim dynamic'); UpYLimDyn = true; else; UpYLimDyn = false; end

Options = {'Yes', 'No, plot based on MSE'};
AllMdls = uiconfirm(Fig, ['You have ',num2str(numel(TestMSE)),' models. ' ...
                          'Do you want to plot all of them?'], ...
                         'Plot all models', 'Options',Options, 'DefaultOption',2);
if strcmp(AllMdls,'Yes'); AllMdls = true; else; AllMdls = false; end

if AllMdls
    IndGoodMdls = true(size(TestMSE));
else
    MaxLoss = str2double(inputdlg({["Choose the max MSE for models to plot : "
                                    strcat("Max MSE is ",string(max(TestMSE))," and min is ",string(min(TestMSE)))]}, ...
                                    '', 1, {num2str(min(TestMSE)*5)}));
    IndGoodMdls = TestMSE <= MaxLoss;
end

%% Plot
[~, AnalysisFoldName] = fileparts(fold_res_ml_curr);
fold_fig_curr = [fold_fig,sl,'Feature Importance',sl,AnalysisFoldName];

if ~exist(fold_fig_curr, 'dir')
    mkdir(fold_fig_curr)
end

cd(fold_fig_curr)
for i1 = 1:length(IndGoodMdls)
    if not(IndGoodMdls(i1)); continue; end % To skip cycle if not good model

    filename = ['Feature importance model n - ',num2str(i1),' - Dataset ',DatasetForFeatsImp];
    curr_fig = figure(i1);
    ax_curr  = axes(curr_fig, 'FontName',SelectedFont, 'FontSize',SelectedFontSize);
    set(curr_fig, 'visible','off')
    set(curr_fig, 'Name',filename);

    ImportanceInPerc = ANNs{'FeatsImportance',i1}{:}{'PercentagesMSE',:}*100;
    FeaturesNames    = categorical(ANNs{'FeatsConsidered',i1}{:});
    % FeaturesNames    = reordercats(FeaturesNames, ANNs{'ConditioningFactorsNames',i1}{:});
    CurrentLoss      = ANNsPerf{'Err','Test'}{:}{'Loss',i1};
    CurrentTestAUC   = ANNsPerf{'ROC','Test'}{:}{'AUC',i1}{:};
    StructOfLayers   = ANNs{'Model',i1}{:}.LayerSizes;

    BarPlot = bar(ax_curr, FeaturesNames, ImportanceInPerc);

    IndRandFeat = contains(ANNs{'FeatsConsidered',i1}{:}, 'Random');
    if any(IndRandFeat)
        yRandFeat = yline(ax_curr, ImportanceInPerc(IndRandFeat), '--', 'Color','r', 'LineWidth',1);
    end

    xBarPos = BarPlot(1).XEndPoints;
    yBarPos = BarPlot(1).YEndPoints;
    [~, FeatOrd] = sort(BarPlot(1).YData, 'descend');
    BarLbls = string(1:length(FeaturesNames));
    [~, FeatOrd2] = sort(FeatOrd, 'ascend');
    BarLbls = BarLbls(FeatOrd2);
    text(xBarPos, yBarPos, BarLbls, 'HorizontalAlignment','center', 'VerticalAlignment','bottom')

    if UpYLimDyn
        UpYLim = min(ceil(1.10*max(ImportanceInPerc)), 100);
    else
        UpYLim = 100;
    end
    ylim([0, UpYLim])
    ylabel('Feature Importance [%]')

    xtickangle(ax_curr, 90)
    
    pbaspect([3,1,1])

    title(['Feature Importance (Model n. ',num2str(i1),'; Dataset ',DatasetForFeatsImp,')'], 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize)
    subtitle(['Loss: ',num2str(CurrentLoss),'; Test AUC: ',num2str(CurrentTestAUC),'; Struct: [',strjoin({num2str(StructOfLayers)}),']'], ...
              'FontName',SelectedFont, 'FontSize',SelectedFontSize)

    %% Showing plot and saving...
    if ShowPlots
        set(curr_fig, 'visible','on');
        pause
    end

    exportgraphics(curr_fig, strcat(filename,'.png'), 'Resolution',600);
    close(curr_fig)
end
cd(fold0)