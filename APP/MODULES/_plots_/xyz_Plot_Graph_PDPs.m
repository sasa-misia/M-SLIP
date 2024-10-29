if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data, extraction and initialization of variables
if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SlFont = Font;
    SlFnSz = FontSize;
else
    SlFont = 'Calibri';
    SlFnSz = 8;
end

if exist('LegendPosition', 'var')
    LegPos = LegendPosition;
else
    LegPos = 'Best';
end

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
load([fold_res_ml_curr,sl,'MLMdlA.mat'], 'MLMdl','ModelInfo')

NormData = ModelInfo.DatasetInfo{1,1}.NormalizedData;
RegrANN  = false; % It should be better to include this info in ModelInfo!
if strcmp(MLMdl{'Model',1}{:}.ModelParameters.Type, 'regression')
    RegrANN = true;
end

%% User opts and selection of good models to plot
Options   = {'MATLAB', 'DIY'};
PDPsMode  = uiconfirm(Fig, 'How do you want to elaborate PDPs?', ...
                           'PDP Mode', 'Options',Options, 'DefaultOption',2);

if strcmp(PDPsMode, 'DIY')
    Options = {'AllRange', 'UniqueFeatsVals'};
    ValsAns = uiconfirm(Fig, 'What values do you want to use for PDPs?', ...
                             'Ranges PDPs', 'Options',Options, 'DefaultOption',2);
    if strcmp(ValsAns,'AllRange'); AllRange = true; else; AllRange = false; end
end

RealCorrAns = uiconfirm(Fig, 'Do you want to plot also real correlations?', ...
                             'PDP Mode', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(RealCorrAns,'Yes'); RealCorr = true; else; RealCorr = false; end

if RealCorr
    Options  = {'Points', 'Line'};
    CorrType = uiconfirm(Fig, 'How do you want them?', ...
                                 'PDP Mode', 'Options',Options, 'DefaultOption',1);

    FilterAns = uiconfirm(Fig, 'Do you want to exclude 0 values?', ...
                               'Filter', 'Options',{'Yes','No'}, 'DefaultOption',2);
    if strcmp(FilterAns,'Yes'); Filter = true; else; Filter = false; end
end

Options = {'Only Train', 'Only Test', 'Train + Test'};
DatasetChoice = uiconfirm(Fig, 'What dataset do you want to use to define PDPs?', ...
                               'PDPs Dataset', 'Options',Options, 'DefaultOption',1);

ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

SizeMarker = 4;

%% Definition of dataset
switch DatasetChoice
    case 'Only Train'
        DatasetFullToUse = ModelInfo.DatasetFeatsTrain{:};
        ExpOutputsToUse  = ModelInfo.ExpextedOutsTrain{:};

    case 'Only Test'
        DatasetFullToUse = ModelInfo.DatasetFeatsTest{:};
        ExpOutputsToUse  = ModelInfo.ExpextedOutsTest{:};

    case 'Train + Test'
        DatasetFullToUse = [ModelInfo.DatasetFeatsTrain{:}; ModelInfo.DatasetFeatsTest{:}];
        ExpOutputsToUse  = [ModelInfo.ExpextedOutsTrain{:}; ModelInfo.ExpextedOutsTest{:}];
end

%% Partial Dependence (DIY Mode)
if strcmp(PDPsMode, 'DIY')
    ProgressBar.Indeterminate = 'off';
    PdpCurveVals = cell(1, size(MLMdl,2));
    for i1 = 1:size(MLMdl,2)
        ProgressBar.Value   = i1/size(MLMdl,2);
        ProgressBar.Message = strcat("Elaborating values of PDP for mdl n. ", ...
                                     string(i1)," of ", string(size(MLMdl,2)));

        CurrMdl  = MLMdl{'Model',i1}{:};
        FeatsMdl = CurrMdl.ExpandedPredictorNames;

        PdpCurveVals{i1} = table('RowNames',{'xVals','yVals','yMins','yMaxs'});
        PdpCurveVals{i1}{:,FeatsMdl} = {missing};
        for i2 = 1:length(FeatsMdl)
            ProgressBar.Message = strcat("Elaborating values of PDP for mdl n. ", ...
                                         string(i1)," of ", string(size(MLMdl,2)), ". Feat: ",FeatsMdl{i2});
            if AllRange
                if not(NormData); error('AllRange can be used only with normalized datasets!'); end
                PdpCurveVals{i1}{'xVals',FeatsMdl{i2}} = {(0 : 0.1 : 1)'};
            else
                PdpCurveVals{i1}{'xVals',FeatsMdl{i2}} = {unique( round(DatasetFullToUse.(FeatsMdl{i2}), 2) )'};
            end

            NumSets = length(PdpCurveVals{i1}{'xVals',FeatsMdl{i2}}{:});
            OutVals = zeros(size(DatasetFullToUse,1), NumSets);
            CurrSet = DatasetFullToUse;
            for i3 = 1:NumSets
                CurrSet{:, FeatsMdl{i2}} = PdpCurveVals{i1}{'xVals',FeatsMdl{i2}}{:}(i3);
                if RegrANN
                    OutVals(:,i3) = predict(CurrMdl, CurrSet);
                else
                    [~, TmpPreds] = predict(CurrMdl, CurrSet);
                    OutVals(:,i3) = sum(TmpPreds(:,2:end), 2);
                end
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
    filename = ['PDPs of models n - ',num2str(i1),' - Dataset ',DatasetChoice];
    curr_fig = figure(i1);
    set(curr_fig, 'visible','off', 'Name',filename, 'Position', [280, 100, 1040, 980])

    curr_ax = cell(1, length(FeatsMdl));
    NumCols = 4;
    GrdPlts = [ceil(length(FeatsMdl)/NumCols), NumCols];
    for i2 = 1:length(FeatsMdl)
        curr_ax{i2} = subplot(GrdPlts(1),GrdPlts(2),i2, 'Parent',curr_fig);
        hold(curr_ax{i2},'on');
        if RealCorr
            yyaxis(curr_ax{i2}, 'left')
            set(curr_ax{i2}, 'ycolor','#A2142F')
        end
        switch PDPsMode
            case 'MATLAB'
                plotPartialDependence(MLMdl{'Model',i1}{:}, FeatsMdl(i2), 1, 'Parent',curr_ax{i2}) % 'Conditional','absolute'

            case 'DIY'
                plot(PdpCurveVals{i1}{'xVals',FeatsMdl(i2)}{:}, PdpCurveVals{i1}{'yVals',FeatsMdl(i2)}{:}, ...
                                                    'LineWidth',1, 'Marker','.', 'Color','#A2142F', 'Parent',curr_ax{i2})
        end

        xlabel('', 'FontName',SlFont, 'FontSize',0.6*SlFnSz)
        ylabel('Avg prob.', 'FontName',SlFont, 'FontSize',0.6*SlFnSz)
        title([FeatsMdl{i2},' PDP'], 'FontName',SlFont, 'FontSize',0.6*SlFnSz)

        if RealCorr
            yyaxis(curr_ax{i2}, 'right')
            set(curr_ax{i2}, 'ycolor','#77AC30')

            switch CorrType
                case 'Points'
                    scatter(DatasetFullToUse.(FeatsMdl{i2}), ExpOutputsToUse, ...
                                                        SizeMarker, 'MarkerEdgeColor','#77AC30', ...
                                                                    'MarkerFaceColor','#77AC30', ...
                                                                    'Marker','o', 'Parent',curr_ax{i2})

                case 'Line'
                    TempMatrx = [round(DatasetFullToUse.(FeatsMdl{i2}), 2), ExpOutputsToUse];
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

                    plot(xVals, yVals, 'LineWidth',0.7, 'Marker','.', 'Color','#77AC30', 'Parent',curr_ax{i2})

                    ylabel('Landslides', 'FontName',SlFont, 'FontSize',0.6*SlFnSz)

                otherwise
                    error('Real correlation type not recognized!')
            end
        end

        curr_ax{i2}.XAxis.FontSize = 0.6*SlFnSz;
        for i3 = 1:length(curr_ax{i2}.YAxis)
            curr_ax{i2}.YAxis(i3).FontSize = 0.6*SlFnSz;
        end
    end

    if ShowPlots
        set(curr_fig, 'visible','on');
        pause
    end

    exportgraphics(curr_fig, strcat(fold_fig_curr,sl,filename,'.png'), 'Resolution',600);
    close(curr_fig)
end