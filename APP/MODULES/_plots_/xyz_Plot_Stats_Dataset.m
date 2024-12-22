if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on',  ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading
sl = filesep;

MdlType = find([exist([fold_var,sl,'DatasetMLA.mat'], 'file'), ...
                exist([fold_var,sl,'DatasetMLB.mat'], 'file')]);
if isempty(MdlType); error('No dataset MLA or MLB found!'); end

if not(isscalar(MdlType))
    MdlType = listdlg2({'What dataset?'}, {'DatasetMLA', 'DatasetMLB'}, 'OutType','NumInd');
end

DsetOpt = {'Tot', 'Pos', 'Neg'}; % Always first Total, then Positive, then Negative

switch MdlType
    case 1
        Fl2LdMdl = 'DatasetMLA.mat';
        load([fold_var,sl,Fl2LdMdl], 'DatasetInfo','StatsTbl')
        PrtNm = 'MdlA';

    case 2
        Fl2LdMdl = 'DatasetMLB.mat';
        load([fold_var,sl,Fl2LdMdl], 'DatasetInfo','StatsTbl')
        PrtNm = 'MdlB';

    otherwise
        error('No trained ModelA or B found!')
end

DsetTbl = dataset_extraction(DatasetInfo);

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

%% Options
PlotOpts = listdlg2({'Plot type', 'Plot mode', 'Dataset', ...
                     'Show plots?', 'Show titles?', 'Show quantiles?'}, ...
                     {{'BoxPlot', 'CumulativeDistribution', 'Ratio'}, ...
                      {'Unique Figure', 'Separate Figures'}, ...
                      DsetOpt, {'Yes', 'No'}, {'Yes', 'No'}, {'Yes', 'No'}});

PlotType = PlotOpts{1};
PlotChce = PlotOpts{2};
DsetPart = PlotOpts{3};
if strcmp(PlotOpts{4},'Yes'); ShowPlts = true; else; ShowPlts = false; end
if strcmp(PlotOpts{5},'Yes'); ShowTtle = true; else; ShowTtle = false; end
if strcmp(PlotOpts{6},'Yes'); QntLbVls = true; else; QntLbVls = false; end

%% Quantiles and limits
ProgressBar.Message = 'Assessment of quantiles and limits...';

FtsDset = DsetTbl{'Total', 'Feats'}{:}.Properties.VariableNames;
Fts2Plt = checkbox2(FtsDset, 'Title','Features to plot: ');
FtsLbls = array2table(inputdlg2(Fts2Plt, 'DefInp',Fts2Plt), ...
                                                 'VariableNames',Fts2Plt, ...
                                                 'RowNames',{'Label'});

IndsPosPart = DsetTbl{'Total', 'ExpOuts'}{:} ~= 0;
IndsNegPart = DsetTbl{'Total', 'ExpOuts'}{:} == 0;
[DsetPrt, DsetQts] = deal(array2table(cell(3, numel(Fts2Plt)), 'RowNames',DsetOpt, 'VariableNames',Fts2Plt));
for i1 = 1:numel(Fts2Plt)
    DsetPrt{DsetOpt{1}, Fts2Plt{i1}} = {DsetTbl{'Total', 'Feats'}{:}{:, Fts2Plt{i1}}};
    DsetPrt{DsetOpt{2}, Fts2Plt{i1}} = {DsetTbl{'Total', 'Feats'}{:}{:, Fts2Plt{i1}}(IndsPosPart)};
    DsetPrt{DsetOpt{3}, Fts2Plt{i1}} = {DsetTbl{'Total', 'Feats'}{:}{:, Fts2Plt{i1}}(IndsNegPart)};

    DsetQts{DsetOpt{1}, Fts2Plt{i1}} = {array2table(StatsTbl{strcat({'Q1','Q2','Q3'},DsetOpt{1}), Fts2Plt{i1}}, ...
                                                                                            'Rownames',{'Q1','Q2','Q3'}, ...
                                                                                            'VariableNames',{'Quantile'})};
    DsetQts{DsetOpt{2}, Fts2Plt{i1}} = {array2table(StatsTbl{strcat({'Q1','Q2','Q3'},DsetOpt{2}), Fts2Plt{i1}}, ...
                                                                                            'Rownames',{'Q1','Q2','Q3'}, ...
                                                                                            'VariableNames',{'Quantile'})};
    DsetQts{DsetOpt{3}, Fts2Plt{i1}} = {array2table(StatsTbl{strcat({'Q1','Q2','Q3'},DsetOpt{3}), Fts2Plt{i1}}, ...
                                                                                            'Rownames',{'Q1','Q2','Q3'}, ...
                                                                                            'VariableNames',{'Quantile'})};
end

%% Plot filename
if strcmp(PlotType, 'BoxPlot')
    BaseName = [PrtNm,' - Stat Box Plot - '];
elseif strcmp(PlotType, 'CumulativeDistribution')
    BaseName = [PrtNm,' - Stat Distrib - '];
elseif strcmp(PlotType, 'Ratio')
    BaseName = [PrtNm,' - Ratio Mean - '];
end

if strcmp(PlotChce, 'Unique Figure')
    Clls2Plt = {Fts2Plt};
    BaseName = [BaseName,'All Feats '];
    ColsNumb = 5;
    RowsNumb = ceil(numel(Fts2Plt)/ColsNumb);
else
    Clls2Plt = num2cell(Fts2Plt);
    BaseName = [BaseName,'Feat '];
    ColsNumb = 1;
    RowsNumb = 1;
end

fold_fig_stat = [fold_fig,sl,'Statistics'];
if not(exist(fold_fig_stat, 'dir'))
    mkdir(fold_fig_stat)
end

%% Plot figures
ProgressBar.Message = 'Plot...';

for i1 = 1:numel(Clls2Plt)
    switch PlotChce
        case 'Unique Figure'
            CurrNme = BaseName;

        case 'Separate Figures'
            CurrNme = [BaseName,' ',Clls2Plt{i1}{1}];

        otherwise
            error(['Plot choice not recognized! ', ...
                   'It must be Unique, Separate.'])
    end

    FigDimX = 320*ColsNumb;
    FigDimY = 200*RowsNumb;

    if strcmp(PlotType, 'Ratio')
        FigDimX = 25*numel(Fts2Plt);
        FigDimY = 350;
        [ColsNumb, RowsNumb] = deal(1);
    end

    CurrFig = figure('Position',[20, 20, FigDimX, FigDimY], 'Name',CurrNme, 'Visible','off');
    CurrLay = tiledlayout(RowsNumb, ColsNumb, 'Parent',CurrFig);

    %% Plot axes
    if any(strcmpi(PlotType, {'BoxPlot', 'CumulativeDistribution'}))
        CurrAxs = deal(cell(1, numel(Clls2Plt{i1})));
        for i2 = 1:numel(Clls2Plt{i1})
            CurrAxs{i2} = nexttile([1, 1]);
            hold(CurrAxs{i2}, 'on')
    
            set(CurrAxs{i2}, 'FontName',SlFont, 'FontSize',SlFnSz)
    
            LabelsTemp = FtsLbls{'Label' , Clls2Plt{i1}{i2}};
            ValuesTemp = DsetPrt{DsetPart, Clls2Plt{i1}{i2}}{:};
            QuantsTemp = DsetQts{DsetPart, Clls2Plt{i1}{i2}}{:};
    
            IQR    = QuantsTemp{'Q3','Quantile'} - QuantsTemp{'Q1','Quantile'};
            UppFnc = QuantsTemp{'Q3','Quantile'} + 1.5*IQR;
            LowFnc = QuantsTemp{'Q1','Quantile'} - 1.5*IQR;
    
            switch PlotType
                case 'BoxPlot'
                    boxplot(CurrAxs{i2}, ValuesTemp, LabelsTemp, ...
                                            'Notch','on', 'OutlierSize',4, ...
                                            'Symbol',['.'; 'm']);
    
                    xlim([0.75, 1.25])
                    ylim([0.98*LowFnc, 1.05*UppFnc])
                    pbaspect([1, 1.5, 1])
    
                case 'CumulativeDistribution'
                    if QntLbVls
                        QntLbls = {[num2str(round(QuantsTemp{'Q1','Quantile'}, 3)),' (Q1)'], ...
                                   [num2str(round(QuantsTemp{'Q2','Quantile'}, 3)),' (Q2)'], ...
                                   [num2str(round(QuantsTemp{'Q3','Quantile'}, 3)),' (Q3)']};
                    else
                        QntLbls = {'Q1', 'Q2', 'Q3'};
                    end
                    CumLn   = cdfplot(ValuesTemp);
                    CumLn.LineWidth = .7;
                    CumLn.Color     = [0, .45, .74];
                    xline(QuantsTemp{'Q1','Quantile'}, ...
                                'Color','#800020', 'Label',QntLbls{1}, 'FontWeight','bold', ...
                                'LabelVerticalAlignment','bottom', 'LabelHorizontalAlignment','center', ...
                                'LineStyle','--', 'LineWidth',.6, 'FontName',SlFont, 'FontSize',SlFnSz);
                    xline(QuantsTemp{'Q2','Quantile'}, ...
                                'Color','#800020', 'Label',QntLbls{2}, 'FontWeight','bold', ...
                                'LabelVerticalAlignment','middle', 'LabelHorizontalAlignment','center', ...
                                'LineStyle','--', 'LineWidth',.6, 'FontName',SlFont, 'FontSize',SlFnSz);
                    xline(QuantsTemp{'Q3','Quantile'}, ...
                                'Color','#800020', 'Label',QntLbls{3}, 'FontWeight','bold', ...
                                'LabelVerticalAlignment','top', 'LabelHorizontalAlignment','center', ...
                                'LineStyle','--', 'LineWidth',.6, 'FontName',SlFont, 'FontSize',SlFnSz);
                    xlabel(LabelsTemp{:})
                    ylabel('Cumulative frequency')
    
                    LeftDlt  = QuantsTemp{'Q1','Quantile'} - 7*(QuantsTemp{'Q2','Quantile'} - QuantsTemp{'Q1','Quantile'});
                    RightDlt = QuantsTemp{'Q3','Quantile'} + 7*(QuantsTemp{'Q3','Quantile'} - QuantsTemp{'Q2','Quantile'});
                    LeftLim  = max(LeftDlt , min(ValuesTemp));
                    RightLim = min(RightDlt, max(ValuesTemp));
                    if RightLim == LeftLim; RightLim = LeftLim + .1; end
                    xlim([LeftLim, RightLim])
    
                    pbaspect([2,1,1])
            end
            
            if ShowTtle; title(char(96+i2), 'FontName',SlFont, 'FontSize',1.5*SlFnSz); end
        end

    elseif strcmpi(PlotType, {'Ratio'})
        CurrAxs = nexttile([1, 1]);
        hold(CurrAxs, 'on')

        set(CurrAxs, 'FontName',SlFont, 'FontSize',SlFnSz)

        LabelsTemp = FtsLbls{'Label' , Clls2Plt{1}};
        ValPosTemp = StatsTbl{'MeanPos', Fts2Plt};
        ValNegTemp = StatsTbl{'MeanNeg', Fts2Plt};
        RtPsNgTemp = ValPosTemp./ValNegTemp.*100; % In percentage!
    
        BarPlt = bar(CurrAxs, LabelsTemp, RtPsNgTemp, 'LineWidth',1, 'FaceColor','#336699');

        xtickangle(90)
    
        yline(100, 'Color','#800020',  'LineStyle','--', 'LineWidth',.6)

        DiffSzY = max(RtPsNgTemp) - min(RtPsNgTemp);
        MaxLimY = max(max(RtPsNgTemp) + .03*DiffSzY, 105);
        MinLimY = min(min(RtPsNgTemp) - .03*DiffSzY, 0  );

        TckIntr = 0:25:max(RtPsNgTemp);
        if min(RtPsNgTemp) < 0
            TckIntr = [fliplr(0:-25:min(RtPsNgTemp)), 0];
        end
    
        ylim(CurrAxs, [MinLimY, MaxLimY])

        ylabel('Ratio L / NL [%]')

        pbaspect([4*numel(Fts2Plt)/26, 1, 1])
    end

    %% Showing plot and saving...
    exportgraphics(CurrFig, [fold_fig_stat,sl,CurrNme,'.png'], 'Resolution',600);
    
    if ShowPlts
        set(CurrFig, 'visible','on')
        pause
    end

    close(CurrFig)
end