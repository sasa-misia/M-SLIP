if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data
sl = filesep;

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

%% Plot options
DsetOpt = listdlg2({'Dataset to use', 'Values'}, {{'StudyArea', 'MLA', 'MLB'}, {'Normal', 'Absolute'}});
DsetUsd = DsetOpt{1};
DsetVls = DsetOpt{2};

switch DsetUsd
    case 'StudyArea'
        load([fold_var,sl,'DatasetStudy.mat'], 'R2ForDatasetStudyFeats')
        R2Dset2Use = R2ForDatasetStudyFeats;

    case 'MLA'
        load([fold_var,sl,'DatasetMLA.mat'], 'DatasetInfo')
        DsetTbl    = dataset_extraction(DatasetInfo);
        R2Dset2Use = feats_correlation(DsetTbl{'Total', 'Feats'}{:});

    case 'MLB'
        load([fold_var,sl,'DatasetMLB.mat'], 'DatasetInfo')
        DsetTbl    = dataset_extraction(DatasetInfo);
        R2Dset2Use = feats_correlation(DsetTbl{'Total', 'Feats'}{:});

    otherwise
        error('Dataset type not recognized!')
end

FeaturesNames = R2Dset2Use.Properties.VariableNames;

%% Plot R2 correlation matrix
CurrFln = [fold_fig,sl,'R2_Correlations-',DsetVls,'-',DsetUsd,'.png'];
CurrFig = figure('Position',[100, 100, 800, 600], 'Units','pixels');
CurrAxs = axes(CurrFig, 'FontName',SlFont, 'FontSize',SlFnSz);
hold(CurrAxs, 'on')

if strcmp(DsetVls, 'Normal')
    imagesc(CurrAxs, flip(R2Dset2Use{:,:}))
else
    imagesc(CurrAxs, flip(abs(R2Dset2Use{:,:})))
end

EdgsX = repmat((0:size(R2Dset2Use{:,:},2))+0.5, size(R2Dset2Use{:,:},1)+1,1);
EdgsY = repmat((0:size(R2Dset2Use{:,:},1))+0.5, size(R2Dset2Use{:,:},2)+1,1).';
plot(CurrAxs, EdgsX  , EdgsY  , 'k') % Vertical lines of grid
plot(CurrAxs, EdgsX.', EdgsY.', 'k') % Horizontal lines of grid

box on

set(CurrAxs, 'YAxisLocation','right')

xticks(CurrAxs, 1:size(R2Dset2Use{:,:},2))
yticks(CurrAxs, 1:size(R2Dset2Use{:,:},2))

xticklabels(FeaturesNames)
yticklabels(flip(FeaturesNames))

xtickangle(CurrAxs, 90)

xlim(CurrAxs, [0.5, size(R2Dset2Use{:,:},2)+0.5])
ylim(CurrAxs, [0.5, size(R2Dset2Use{:,:},1)+0.5])

daspect([1, 1.1, 1])

if strcmp(DsetVls, 'Normal')
    ColBarLims  = [-1, 1];
    TicksValues = [-1, -0.75, -0.4, -0.2, 0, 0.2, 0.4, 0.75, 1];
    TicksLabels = ["Perfect inv. corr.", ...
                   "High inv. corr.", ...
                   "Moderate inv. corr.", ...
                   "Low inv. corr.", ...
                   "No correlation", ...
                   "Low pos. corr.", ...
                   "Moderate pos. corr.", ...
                   "High pos. corr.", ...
                   "Perfect pos. corr."];
    colormap(CurrAxs, jet)
else
    ColBarLims  = [0, 1];
    TicksValues = [0, 0.2, 0.4, 0.75, 1];
    TicksLabels = ["No correlation", ...
                   "Low correlation", ...
                   "Moderate correlation", ...
                   "High correlation", ...
                   "Perfect correlation"      ];
    colormap(CurrAxs, flipud(pink))
end
clim(ColBarLims);
colorbar('Location','westoutside', 'Ticks',TicksValues, 'TickLabels',TicksLabels);

title('Pearson correlation matrix', 'FontName',SlFont, 'FontSize',1.5*SlFnSz)
subtitle([DsetUsd,' Dataset; ',DsetVls,' values'], 'FontName',SlFont, 'FontSize',1*SlFnSz)

exportgraphics(CurrFig, CurrFln, 'Resolution',600);