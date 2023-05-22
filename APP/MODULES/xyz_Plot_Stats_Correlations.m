% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Loading data
fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
load([fold_res_ml_curr,sl,'TrainedANNs.mat'], 'R2ForDatasetFeatsStudyNorm','R2ForDatasetFeatsStudyNotNorm')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize')
    SelectedFont     = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont     = 'Times New Roman';
    SelectedFontSize = 8;
end

%% Plot options
Options = {'Normalized', 'Not Normalized'};
DatasetChoice = uiconfirm(Fig, 'What dataset do you want to use?', ...
                               'Dataset choice', 'Options',Options, 'DefaultOption',2);

if strcmp(DatasetChoice, 'Normalized')
    R2DatasetToUse = R2ForDatasetFeatsStudyNorm;
else
    R2DatasetToUse = R2ForDatasetFeatsStudyNotNorm;
end

FeaturesNames = R2DatasetToUse.Properties.VariableNames;

Options = {'Normal', 'Absolute'};
CorrValuesChoice = uiconfirm(Fig, 'How do you want to plot values of correlation matrix?', ...
                                  'R2 Values', 'Options',Options, 'DefaultOption',1);

%% Plot R2 correlation matrix
fig_r2 = figure('Position',[100, 100, 800, 600], 'Units','pixels');
ax_r2  = axes(fig_r2);
hold(ax_r2, 'on')
filename_r2 = [fold_fig,sl,'R2 Correlations ',CorrValuesChoice,' Dataset ',DatasetChoice,'.png'];

if strcmp(CorrValuesChoice, 'Normal')
    imagesc(ax_r2, flip(R2DatasetToUse{:,:}))
else
    imagesc(ax_r2, flip(abs(R2DatasetToUse{:,:})))
end

EdgsX = repmat((0:size(R2DatasetToUse{:,:},2))+0.5, size(R2DatasetToUse{:,:},1)+1,1);
EdgsY = repmat((0:size(R2DatasetToUse{:,:},1))+0.5, size(R2DatasetToUse{:,:},2)+1,1).';
plot(ax_r2, EdgsX  , EdgsY  , 'k') % Vertical lines of grid
plot(ax_r2, EdgsX.', EdgsY.', 'k') % Horizontal lines of grid

box on

set(ax_r2, 'YAxisLocation','right')

xticks(ax_r2, 1:size(R2DatasetToUse{:,:},2))
yticks(ax_r2, 1:size(R2DatasetToUse{:,:},2))

xticklabels(FeaturesNames)
yticklabels(flip(FeaturesNames))

xtickangle(ax_r2, 90)

xlim(ax_r2, [0.5, size(R2DatasetToUse{:,:},2)+0.5])
ylim(ax_r2, [0.5, size(R2DatasetToUse{:,:},2)+0.5])

daspect([1, 1.1, 1])

if strcmp(CorrValuesChoice, 'Normal')
    ColBarLims  = [-1, 1];
    TicksValues = [-1, -0.75, -0.4, -0.2, 0, 0.2, 0.4 0.75, 1];
    TicksLabels = ["Perfect inv. corr.", ...
                   "High inv. corr.", ...
                   "Moderate inv. corr.", ...
                   "Low inv. corr.", ...
                   "No correlation", ...
                   "Low pos. corr.", ...
                   "Moderate pos. corr.", ...
                   "High pos. corr.", ...
                   "Perfect pos. corr."];
    colormap(ax_r2, jet)
else
    ColBarLims  = [0, 1];
    TicksValues = [0, 0.2, 0.4 0.75, 1];
    TicksLabels = ["No correlation", ...
                   "Low correlation", ...
                   "Moderate correlation", ...
                   "High correlation", ...
                   "Perfect correlation"      ];
    colormap(ax_r2, flipud(pink))
end
clim(ColBarLims);
colorbar('Location','westoutside', 'Ticks',TicksValues, 'TickLabels',TicksLabels);

title('Pearson correlation matrix', 'FontName',SelectedFont, 'FontSize',1.5*SelectedFontSize)
subtitle([DatasetChoice,' Dataset; ',CorrValuesChoice,' values'], 'FontName',SelectedFont, 'FontSize',1*SelectedFontSize)

exportgraphics(fig_r2, filename_r2, 'Resolution',600);

close(ProgressBar)