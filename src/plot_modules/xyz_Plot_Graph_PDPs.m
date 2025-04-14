if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data, extraction and initialization of variables
[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');

MdlType = find([exist([fold_res_ml_curr,sl,'MLMdlA.mat'], 'file'), ...
                exist([fold_res_ml_curr,sl,'MLMdlB.mat'], 'file')]);
if isempty(MdlType); error('No model MLA or MLB found!'); end

if not(isscalar(MdlType))
    MdlType = listdlg2({'What dataset?'}, {'MLA', 'MLB'}, 'OutType','NumInd');
end

switch MdlType
    case 1
        load([fold_res_ml_curr,sl,'MLMdlA.mat'], 'MLMdl','ModelInfo')

    case 2
        load([fold_res_ml_curr,sl,'MLMdlB.mat'], 'MLMdl','ModelInfo')
end

%% User opts and selection of good models to plot
PDPsOpts = listdlg2({'Mode', 'Values', 'View actual correlations?', ...
                     'Actual correlations type', 'Dataset', 'Show plots'}, ...
                    {{'MATLAB','DIY'}, {'AllRange','UniqueFeatsVals'}, {'Yes','No'}, ...
                     {'Points','Line'}, {'Only Train','Only Test','Train + Test'}, {'Yes','No'}});

PDPsMode = PDPsOpts{1};
if strcmp(PDPsOpts{2},'AllRange'); AllRange = true; else; AllRange = false; end
if strcmp(PDPsOpts{3},'Yes'); RealCorr = true; else; RealCorr = false; end
CorrType = PDPsOpts{4};
DsetChce = PDPsOpts{5};
if strcmp(PDPsOpts{6},'Yes'); ShowPlt = true; else; ShowPlt = false; end

if RealCorr
    FilterAns = uiconfirm(Fig, 'Do you want to exclude 0 values?', ...
                               'Filter', 'Options',{'Yes','No'}, 'DefaultOption',2);
    if strcmp(FilterAns,'Yes'); Filter = true; else; Filter = false; end
end

MarkSz = 4;

%% Definition of dataset
DsetTbl = dataset_extraction(ModelInfo.DatasetInfo{:});

switch DsetChce
    case 'Only Train'
        Dset2Use = DsetTbl{'Train','Feats'  }{:};
        ExpO2Use = DsetTbl{'Train','ExpOuts'}{:};

    case 'Only Test'
        Dset2Use = DsetTbl{'Test','Feats'  }{:};
        ExpO2Use = DsetTbl{'Test','ExpOuts'}{:};

    case 'Train + Test'
        Dset2Use = DsetTbl{'Total','Feats'  }{:};
        ExpO2Use = DsetTbl{'Total','ExpOuts'}{:};
end

FeatsMdl = Dset2Use.Properties.VariableNames;

%% Partial Dependence (DIY Mode)
if strcmp(PDPsMode, 'DIY')
    ProgressBar.Indeterminate = 'off';
    PdpCurveVals = cell(1, size(MLMdl,2));
    for i1 = 1:size(MLMdl,2)
        ProgressBar.Value   = i1/size(MLMdl,2);
        ProgressBar.Message = strcat("Elaborating values of PDP for mdl n. ", ...
                                     string(i1)," of ", string(size(MLMdl,2)));

        CurrMdl  = MLMdl{'Model',i1}{:};

        PdpCurveVals{i1} = table('RowNames',{'xVals','yVals','yMins','yMaxs'});
        PdpCurveVals{i1}{:,FeatsMdl} = {missing};
        for i2 = 1:length(FeatsMdl)
            ProgressBar.Message = strcat("Elaborating values of PDP for mdl n. ", ...
                                         string(i1)," of ", string(size(MLMdl,2)), ". Feat: ",FeatsMdl{i2});
            if AllRange
                MinValTmp = min(Dset2Use{:, FeatsMdl{i2}});
                MaxValTmp = max(Dset2Use{:, FeatsMdl{i2}});
                PdpCurveVals{i1}{'xVals',FeatsMdl{i2}} = {(0 : 0.1 : 1)' .* (MaxValTmp - MinValTmp) + MinValTmp};
            else
                PdpCurveVals{i1}{'xVals',FeatsMdl{i2}} = {unique( round(Dset2Use.(FeatsMdl{i2}), 2) )'};
            end

            NumSets = length(PdpCurveVals{i1}{'xVals',FeatsMdl{i2}}{:});
            OutVals = zeros(size(Dset2Use,1), NumSets);
            CurrSet = Dset2Use;
            for i3 = 1:NumSets
                CurrSet{:, FeatsMdl{i2}} = PdpCurveVals{i1}{'xVals',FeatsMdl{i2}}{:}(i3);
                OutVals(:,i3) = mdlpredict(CurrMdl, CurrSet);
            end

            PdpCurveVals{i1}{'yVals',FeatsMdl{i2}} = {mean(OutVals, 1)};
            PdpCurveVals{i1}{'yMins',FeatsMdl{i2}} = {min(OutVals, [], 1)};
            PdpCurveVals{i1}{'yMaxs',FeatsMdl{i2}} = {max(OutVals, [], 1)};
        end
    end
    ProgressBar.Indeterminate = 'on';
end

%% Plots folder
[~, AnalysisFoldName] = fileparts(fold_res_ml_curr);
fold_fig_curr = [fold_fig,sl,'PDPs',sl,AnalysisFoldName];

if ~exist(fold_fig_curr, 'dir')
    mkdir(fold_fig_curr)
end

%% Plot
for i1 = 1:size(MLMdl,2)
    for i2 = 1:length(FeatsMdl)

        CurrFln = ['PDPs_Mdl_',num2str(i1),'-',DsetChce,'-',FeatsMdl{i2}];
        CurrFig = figure('Visible','off', 'Name',CurrFln, 'Position', [280, 100, 500, 300]);

        GrdPlts = [1, 1];

        CurrAxs = subplot(GrdPlts(1),GrdPlts(2),1, 'Parent',CurrFig);
        hold(CurrAxs,'on');
        if RealCorr
            yyaxis(CurrAxs, 'left')
            set(CurrAxs, 'ycolor','#A2142F')
        end
        switch PDPsMode
            case 'MATLAB'
                plotPartialDependence(MLMdl{'Model',i1}{:}, FeatsMdl(i2), 1, 'Parent',CurrAxs) % 'Conditional','absolute'

            case 'DIY'
                plot(PdpCurveVals{i1}{'xVals',FeatsMdl(i2)}{:}, PdpCurveVals{i1}{'yVals',FeatsMdl(i2)}{:}, ...
                                                    'LineWidth',1, 'Marker','.', 'Color','#A2142F', 'Parent',CurrAxs)
        end

        xlabel('Feature value', 'FontName',SlFont, 'FontSize',SlFnSz)
        ylabel('Avg prob.', 'FontName',SlFont, 'FontSize',SlFnSz)
        title([FeatsMdl{i2},' PDP'], 'FontName',SlFont, 'FontSize',SlFnSz)

        if RealCorr
            yyaxis(CurrAxs, 'right')
            set(CurrAxs, 'ycolor','#77AC30')

            switch CorrType
                case 'Points'
                    scatter(Dset2Use.(FeatsMdl{i2}), ExpO2Use, ...
                                                        MarkSz, 'MarkerEdgeColor','#77AC30', ...
                                                                    'MarkerFaceColor','#77AC30', ...
                                                                    'Marker','o', 'Parent',CurrAxs)

                case 'Line'
                    TempMatrx = [round(Dset2Use.(FeatsMdl{i2}), 2), ExpO2Use];
                    if Filter
                        IdxToRem = (TempMatrx(:,2) == 0);
                        TempMatrx(IdxToRem,:) = [];
                    end
                    [~, OrdC] = sort(TempMatrx(:,1));
                    TempMatrx = TempMatrx(OrdC, :);

                    xVals = unique(TempMatrx(:,1));
                    yVals = zeros(size(xVals));
                    for i3 = 1:length(yVals)
                        yVals(i3) = mean(TempMatrx(xVals(i3)==TempMatrx(:,1), 2));
                    end

                    if Filter
                        IdxToRem = (yVals == 0);
                        xVals(IdxToRem) = [];
                        yVals(IdxToRem) = [];
                    end

                    plot(xVals, yVals, 'LineWidth',0.7, 'Marker','.', 'Color','#77AC30', 'Parent',CurrAxs)

                    ylabel('Landslides', 'FontName',SlFont, 'FontSize',SlFnSz)

                otherwise
                    error('Real correlation type not recognized!')
            end
        end

        CurrAxs.XAxis.FontSize = SlFnSz;
        for i3 = 1:length(CurrAxs.YAxis)
            CurrAxs.YAxis(i3).FontSize = SlFnSz;
        end

        if ShowPlt
            set(CurrFig, 'Visible','on');
            pause
        end
    
        exportgraphics(CurrFig, strcat(fold_fig_curr,sl,CurrFln,'.png'), 'Resolution',600);
        close(CurrFig)

    end
end