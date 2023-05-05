% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
cd(fold_var)
if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat', 'Font','FontSize','LegendPosition')
    SelectedFont     = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont     = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition   = 'Best';
end

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
cd(fold_res_ml_curr)
load('TrainedANNs.mat', 'ANNModels','ANNModelsROCTest')
cd(fold0)

%% User opts and selection of good models to plot
Options   = {'Yes', 'No'};
ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',Options, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

MaxLoss = str2double(inputdlg({'Choose the max loss for models to plot: '}, '', 1, {'0.15'}));

IndGoodMdls = cell2mat(ANNModels{'DatasetTestMSE',:}) <= MaxLoss;

%% Plot
[~, AnalysisFoldName] = fileparts(fold_res_ml_curr);
fold_fig_curr = [fold_fig,sl,'Feature Importance',sl,AnalysisFoldName];

if ~exist(fold_fig_curr, 'dir')
    mkdir(fold_fig_curr)
end

cd(fold_fig_curr)
for i1 = 1:length(IndGoodMdls)
    if not(IndGoodMdls(i1)); continue; end % To skip cycle if not good model

    filename = ['Feature importance model n - ',num2str(i1)];
    curr_fig = figure(i1);
    ax_curr  = axes(curr_fig, 'FontName',SelectedFont, 'FontSize',SelectedFontSize);
    set(curr_fig, 'visible','off')
    set(curr_fig, 'Name',filename);

    ImportanceInPerc = ANNModels{'FeatureImportance',i1}{:}{'PercentagesMSE',:}*100;
    FeaturesNames    = categorical(ANNModels{'ConditioningFactorsNames',i1}{:});
    % FeaturesNames    = reordercats(FeaturesNames, ANNModels{'ConditioningFactorsNames',i1}{:});
    CurrentLoss      = ANNModels{'DatasetTestMSE',i1}{:};
    CurrentTestAUC   = ANNModelsROCTest{'AUC-Test',i1}{:};
    StructOfLayers   = ANNModels{'Model',i1}{:}.LayerSizes;

    BarPlot = bar(ax_curr, FeaturesNames, ImportanceInPerc);

    xBarPos = BarPlot(1).XEndPoints;
    yBarPos = BarPlot(1).YEndPoints;
    [~, FeatOrd] = sort(BarPlot(1).YData, 'descend');
    BarLbls = string(1:length(FeaturesNames));
    [~, FeatOrd2] = sort(FeatOrd, 'ascend');
    BarLbls = BarLbls(FeatOrd2);
    text(xBarPos, yBarPos, BarLbls, 'HorizontalAlignment','center', 'VerticalAlignment','bottom')

    ylim([0, 100])
    ylabel('Feature Importance [%]')

    xtickangle(ax_curr, 90)
    
    pbaspect([3,1,1])

    title(['Feature Importance (Model n. ',num2str(i1),')'], 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize)
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