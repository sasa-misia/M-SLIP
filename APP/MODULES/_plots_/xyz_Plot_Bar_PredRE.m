if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files
sl = filesep;

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');

load([fold_res_ml_curr,sl,'MLMdlA.mat'], 'MLMdl','MLPerf','ModelInfo')
load([fold_var,sl,'DatasetMLA.mat'    ], 'DatasetInfo')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize')
    SelFont = Font;
    SelFnSz = FontSize;
else
    SelFont = 'Calibri';
    SelFnSz = 8;
end

ANNMode = ModelInfo.ANNsOptions.TrainMode;
OutMode = DatasetInfo(end).Options.OutputType;
RegrANN = false;
switch OutMode
    case {'L-NL classes', '4 risk classes'}

    case 'Regression'
        RegrANN = true;

    otherwise
        error('OutMode choice not recognized!')
end

% DoubleOut = true;
% switch ANNMode
%     case {'Classic (L)', 'Classic (V)', 'Cross Validation (K-Fold M)', ...
%             'Cross Validation (K-Fold V)', 'Sensitivity Analysis', 'Auto'}
% 
%     case {'Deep (L)', 'Deep (V)', 'Logistic Regression'}
%         DoubleOut = false;
% 
%     otherwise
%         error('ANN Mode not recognized!')
% end
% 
% if RegrANN
%     DoubleOut = false; 
% end

MunList = cell(1, length(DatasetInfo));
for i1 = 1:length(DatasetInfo)
    MunsLbls = string(DatasetInfo(i1).LandslidesMunicipalities);
    if numel(MunsLbls) > 8
        MunsLbls = [MunsLbls(1:7); {'...'}];
    end
    MunList{i1} = strjoin(MunsLbls, '-');
end

%% Options
PltOpts = checkbox2({'Show plots', 'All years', 'Main events', ...
                     'Pred and real', 'Landslide magnitudo'}, 'DefInp',[0, 1, 1, 1, 1], 'OutType','LogInd');

ShowPlt = PltOpts(1);
SnglPlt = PltOpts(2);
RedPrds = PltOpts(3);
SeptPlt = PltOpts(4);
LndsMnt = PltOpts(5);

Mdl2Plt = char(listdlg2({'Models to plot'}, {{'All','Manual','AUROC'}}));

Cnt2Plt = checkbox2({'Landslide intensity', 'Predictions', 'Dataset part', ...
                     'Duration', 'NDVI', 'Rainfall', 'Temperature'}, 'Title',{'Content to plot:'}, ...
                                                                     'DefInp',[true,true,false,false,false,false,false]);

%% Plots (predictions vs real)
ProgressBar.Message = 'Predicted vs real events plots...';

IndDset2Tk = listdlg2({'Dataset to plot?'}, MunList, 'OutType','NumInd');

DsetFtsTot = DatasetInfo(IndDset2Tk).Datasets.Total.Features;

DsetLblAss = listdlg2({'Duration', 'NDVI', ...
                       'Rainfall', 'Temperature'}, DsetFtsTot.Properties.VariableNames);

switch Mdl2Plt
    case 'All'
        IndMdl2Tk = 1:size(MLMdl,2);

    case 'Manual'
        MdlNms = MLMdl.Properties.VariableNames;
        [~, Bst4AUC] = max(cell2mat(MLPerf{'ROC','Test'}{:}{'AUC',:}));
        [~, Bst4MSE] = min(MLPerf{'Err','Test'}{:}{'MSE',:});
        IndMdl2Tk = checkbox2(MdlNms, 'Title',{['Model to plot? (Best for tst AUC: ',MdlNms{Bst4AUC}, ...
                                                '; Best for tst MSE: ',MdlNms{Bst4MSE}]}, 'OutType','NumInd');

    case 'AUROC'
        ThreshAUC = str2double(inputdlg2({'Set AUROC threshold: '}, 'DefInp',{'0.7'}));
        IndMdl2Tk = find(cell2mat(MLPerf{'ROC','Test'}{:}{'AUC',:}) > ThreshAUC);

    otherwise
        error('Choice not recognized!')
end

if SnglPlt; SelFnSz = 4; end

EventsYear = year(DatasetInfo(IndDset2Tk).Datasets.Total.Dates.Start);
if SnglPlt
    EventsYearUnique = {unique(EventsYear)};
else
    EventsYearUnique = num2cell(unique(EventsYear));
end

MdlNames = MLMdl.Properties.VariableNames;
for IndCurr = IndMdl2Tk
    CurrMdl = MLMdl{'Model',IndCurr}{:};

    PredOutsRaw = mdlpredict(CurrMdl, DsetFtsTot);

    if RegrANN
        [PredOutsM, PredOutsS] = deal(rescale(PredOutsRaw));
    else
        PredOutsM = PredOutsRaw;
        PredOutsS = sum(PredOutsRaw, 2);
    end
    
    fold_fig_curr = [fold_fig,sl,'Model A preds'];
    if ~exist(fold_fig_curr, 'dir')
        mkdir(fold_fig_curr)
    end
    
    for i1 = 1:length(EventsYearUnique)
        if isscalar(EventsYearUnique)
            EvsLabel = 'all';
        else
            EvsLabel = char(strjoin(string(EventsYearUnique{i1}), '-'));
        end
        CurrNme = [MdlNames{IndCurr},' preds rain - yr ',EvsLabel,' - ',char(MunList{IndDset2Tk})];

        IndsEventsInYear = arrayfun(@(x) x == EventsYear, EventsYearUnique{i1}, 'UniformOutput',false);
        IndsEventsInYear = any(cat(2, IndsEventsInYear{:}), 2);

        if RedPrds
            CurrNme   = [CurrNme,' - red'];
            TrgRainAm = DsetFtsTot.(DsetLblAss{3})(IndsEventsInYear);
            TrgRainLm = quantile(TrgRainAm, [.05, .95]);
            TrgEvsInd = (TrgRainAm <= TrgRainLm(1)) | (TrgRainAm >= TrgRainLm(2));
            LndEvsInd = DatasetInfo(IndDset2Tk).Datasets.Total.Dates.LandsNum(IndsEventsInYear) >= 1;
            IndEvs2Tk = TrgEvsInd | LndEvsInd;
        else
            IndEvs2Tk = IndsEventsInYear;
        end

        StartDatesToPlot = categorical(string(datetime(DatasetInfo(IndDset2Tk).Datasets.Total.Dates.Start(IndEvs2Tk), 'Format','dd-MMM-yyyy')));
        StartDatesToPlot = reordercats(StartDatesToPlot, string(datetime(DatasetInfo(IndDset2Tk).Datasets.Total.Dates.Start(IndEvs2Tk), 'Format','dd-MMM-yyyy'))); % DON'T DELETE THIS ROW!!! It is necessary!

        CurrFig = figure('Position',[80, 50, 6*sum(IndEvs2Tk), 125*numel(Cnt2Plt)]);
        CurrLay = tiledlayout(numel(Cnt2Plt), 1, 'Parent',CurrFig);
        CurrAxs = deal(cell(1, numel(Cnt2Plt)));

        set(CurrFig, 'visible','off', 'Name',CurrNme)

        AxsRat = [3.5*length(StartDatesToPlot)/25, 1, 1];

        EvType = zeros(1, length(StartDatesToPlot));
        for i2 = 1:length(EvType)
            if any(datetime(string(StartDatesToPlot(i2))) == DatasetInfo(IndDset2Tk).Datasets.Train.Dates.Start)
                EvType(i2) = 1;
            elseif any(datetime(string(StartDatesToPlot(i2))) == DatasetInfo(IndDset2Tk).Datasets.Test.Dates.Start)
                EvType(i2) = 2;
            end
        end

        iAx = 1;
        xLb = 'Start datetime of RE';

        % Plot for number of landslides
        if any(strcmp(Cnt2Plt, 'Landslide intensity'))
            CurrAxs{iAx} = nexttile([1, 1]);
            hold(CurrAxs{iAx}, 'on')
        
            NumOfLandsToPlot = DatasetInfo(IndDset2Tk).Datasets.Total.Dates.LandsNum(IndEvs2Tk);
    
            if LndsMnt
                BarPlotLand = bar(CurrAxs{iAx}, StartDatesToPlot, double(NumOfLandsToPlot>=1), 'FaceColor','flat', 'BarWidth',1, 'EdgeColor','k');
    
                BarColors = repmat(1-rescale(NumOfLandsToPlot), 1, 3);
                BarPlotLand.CData = BarColors;
    
                UpYLim = 1;
    
                yLabTxt = 'Intensity';
            else
                BarPlotLand = bar(CurrAxs{iAx}, StartDatesToPlot, NumOfLandsToPlot, 'FaceColor','flat', 'BarWidth',1, 'CData',[128, 128, 128]./255, 'EdgeColor','k');
            
                UpYLim = max(1.05*max(NumOfLandsToPlot), 5);
    
                yLabTxt = 'Number of LE';
            end
    
            ylim([0, UpYLim])
            ylabel(yLabTxt, 'FontName',SelFont, 'FontSize',SelFnSz)

            if LndsMnt
                yticks([0, UpYLim])
                yticklabels({'', ''})
            end
        
            xtickangle(CurrAxs{iAx}, 90)
            xlabel(xLb, 'FontName',SelFont, 'FontSize',SelFnSz)
            
            % pbaspect(CurrAxs{iAx}, AxsRat)
            box on
    
            xTick = get(CurrAxs{iAx},'XTickLabel');
            set(CurrAxs{iAx}, 'XTickLabel',xTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            yTick = get(CurrAxs{iAx},'YTickLabel');
            set(CurrAxs{iAx}, 'YTickLabel',yTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            title('Real Landslides', 'FontName',SelFont, 'FontSize',1.5*SelFnSz)

            if LndsMnt
                subtitle('gray scaled (darker means more landslides)', 'FontName',SelFont, 'FontSize',0.7*SelFnSz)
            else
            end

            iAx = iAx + 1;
        end

        % Plot for prediction probabilities
        if any(strcmp(Cnt2Plt, 'Predictions'))
            CurrAxs{iAx} = nexttile([1, 1]);
            hold(CurrAxs{iAx}, 'on')
    
            if SeptPlt
                PredOutsToPlot = 100*PredOutsM(IndEvs2Tk,:);
            
                BarPlotPreds = bar(CurrAxs{iAx}, StartDatesToPlot, PredOutsToPlot, 'stacked', 'FaceColor','flat', 'BarWidth',1, 'EdgeColor','k');
    
                TestColors  = flipud(autumn(size(PredOutsToPlot,2)));
                TrainColors = flipud(gray(size(PredOutsToPlot,2)+2));
                for i2 = 1:size(PredOutsToPlot,2)
                    BarColors   = zeros(length(EvType), 3);
                    IndTestPart = (EvType == 2);
                    BarColors(IndTestPart,:)      = repmat(TestColors(i2,:)   , sum(IndTestPart)     , 1);
                    BarColors(not(IndTestPart),:) = repmat(TrainColors(i2+1,:), sum(not(IndTestPart)), 1);
                    BarPlotPreds(i2).CData = BarColors;
                end
            else   
                RealProbsToPlot = 100*min(NumOfLandsToPlot, 1);
                PredOutsToPlot  = 100*PredOutsS(IndEvs2Tk);
            
                BarPlotPreds = bar(CurrAxs{iAx}, StartDatesToPlot, [RealProbsToPlot, PredOutsToPlot], 'FaceColor','flat', 'BarWidth',1);
            
                BarPlotPreds(1).CData = repmat([0, 153, 76 ]./255, length(RealProbsToPlot), 1);
                BarPlotPreds(2).CData = repmat([0, 128, 255]./255, length(RealProbsToPlot), 1);
            end
    
            UpYLim = 100;
            
            ylim([0, UpYLim])
            ylabel('Probability', 'FontName',SelFont, 'FontSize',SelFnSz)
        
            xtickangle(CurrAxs{iAx}, 90)
            xlabel(xLb, 'FontName',SelFont, 'FontSize',SelFnSz)
            
            % pbaspect(CurrAxs{iAx}, AxsRat)
            box on
    
            xTick = get(CurrAxs{iAx},'XTickLabel');
            set(CurrAxs{iAx}, 'XTickLabel',xTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            yTick = get(CurrAxs{iAx},'YTickLabel');
            set(CurrAxs{iAx}, 'YTickLabel',yTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            title('Predictions', 'FontName',SelFont, 'FontSize',1.5*SelFnSz)
            if SeptPlt
                subtitle('gray = training/validation; red = test', 'FontName',SelFont, 'FontSize',0.7*SelFnSz)
            else
                subtitle('green -> real ; blue -> prediction', 'FontName',SelFont, 'FontSize',0.7*SelFnSz)
            end

            iAx = iAx + 1;
        end

        % Plot for event dataset
        if any(strcmp(Cnt2Plt, 'Part of dataset'))
            CurrAxs{iAx} = nexttile([1, 1]);
            hold(CurrAxs{iAx}, 'on')
    
            imagesc(CurrAxs{iAx}, EvType)
    
            colormap(CurrAxs{iAx}, jet) % TO CHANGE WITH FIXED COLORS!!!
    
            EdgsX = repmat((0:size(EvType,2))+0.5, size(EvType,1)+1, 1);
            EdgsY = repmat((0:size(EvType,1))+0.5, size(EvType,2)+1, 1)';
            plot(CurrAxs{iAx}, EdgsX  , EdgsY  , 'k') % Vertical lines of grid
            plot(CurrAxs{iAx}, EdgsX.', EdgsY.', 'k') % Horizontal lines of grid
    
            % daspect(CurrAxs{iAx}, [1, 1, 1])
            % pbaspect(CurrAxs{iAx}, AxsRat)
            box on
    
            xticks(CurrAxs{iAx}, 1:size(EvType,2))
            yticks(CurrAxs{iAx}, 1:size(EvType,2))
            
            xticklabels(string(StartDatesToPlot))
            yticklabels("")
            
            xtickangle(CurrAxs{iAx}, 90)
            xlabel(xLb, 'FontName',SelFont, 'FontSize',SelFnSz)
    
            xlim(CurrAxs{iAx}, [0, size(EvType,2)+1])
            ylim(CurrAxs{iAx}, [0, size(EvType,1)+1])
    
            xTick = get(CurrAxs{iAx},'XTickLabel');
            set(CurrAxs{iAx}, 'XTickLabel',xTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            yTick = get(CurrAxs{iAx},'YTickLabel');
            set(CurrAxs{iAx}, 'YTickLabel',yTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
    
            set(CurrAxs{iAx}, 'TickLength',[0 .1])
    
            title('Type of event', 'FontName',SelFont, 'FontSize',1.5*SelFnSz)
            subtitle('green -> train ; red -> test ; blu -> excluded', 'FontName',SelFont, 'FontSize',0.7*SelFnSz)

            iAx = iAx + 1;
        end

        % Plot for Duration
        if any(strcmp(Cnt2Plt, 'Duration'))
            CurrAxs{iAx} = nexttile([1, 1]);
            hold(CurrAxs{iAx}, 'on')
    
            DurToPlot = DsetFtsTot.(DsetLblAss{1})(IndEvs2Tk);
    
            BarPlotDur = bar(CurrAxs{iAx}, StartDatesToPlot, DurToPlot, 'FaceColor','flat', 'BarWidth',1, 'CData',[1, 0.8, 0.9], 'EdgeColor','k');
    
            ylim([0.98*min(DurToPlot), 1.02*max(DurToPlot)])
            ylabel('Duration [h]', 'FontName',SelFont, 'FontSize',SelFnSz)
        
            xtickangle(CurrAxs{iAx}, 90)
            xlabel(xLb, 'FontName',SelFont, 'FontSize',SelFnSz)
            
            % pbaspect(CurrAxs{iAx}, AxsRat)
            box on
    
            xTick = get(CurrAxs{iAx},'XTickLabel');
            set(CurrAxs{iAx}, 'XTickLabel',xTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            yTick = get(CurrAxs{iAx},'YTickLabel');
            set(CurrAxs{iAx}, 'YTickLabel',yTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            title('Duration', 'FontName',SelFont, 'FontSize',1.5*SelFnSz)
    
            iAx = iAx + 1;
        end

        % Plot for NDVI
        if any(strcmp(Cnt2Plt, 'NDVI'))
            CurrAxs{iAx} = nexttile([1, 1]);
            hold(CurrAxs{iAx}, 'on')
    
            NDVIToPlot = DsetFtsTot.(DsetLblAss{2})(IndEvs2Tk);
    
            BarPlotNDVI = bar(CurrAxs{iAx}, StartDatesToPlot, NDVIToPlot, 'FaceColor','flat', 'BarWidth',1, 'CData',[0, 0.5, 0.5], 'EdgeColor','k');
    
            ylim([0.98*min(NDVIToPlot), 1.02*max(NDVIToPlot)])
            ylabel('NDVI values [-]', 'FontName',SelFont, 'FontSize',SelFnSz)
        
            xtickangle(CurrAxs{iAx}, 90)
            xlabel(xLb, 'FontName',SelFont, 'FontSize',SelFnSz)
            
            % pbaspect(CurrAxs{iAx}, AxsRat)
            box on
    
            xTick = get(CurrAxs{iAx},'XTickLabel');
            set(CurrAxs{iAx}, 'XTickLabel',xTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            yTick = get(CurrAxs{iAx},'YTickLabel');
            set(CurrAxs{iAx}, 'YTickLabel',yTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            title('NDVI', 'FontName',SelFont, 'FontSize',1.5*SelFnSz)
    
            iAx = iAx + 1;
        end

        % Plot for Rainfall
        if any(strcmp(Cnt2Plt, 'Rainfall'))
            CurrAxs{iAx} = nexttile([1, 1]);
            hold(CurrAxs{iAx}, 'on')
    
            RainToPlot = DsetFtsTot.(DsetLblAss{3})(IndEvs2Tk);
    
            BarPlotRain = bar(CurrAxs{iAx}, StartDatesToPlot, RainToPlot, 'FaceColor','flat', 'BarWidth',1, 'CData',[102, 178, 255]./255, 'EdgeColor','k');
    
            ylim([0.98*min(RainToPlot), 1.02*max(RainToPlot)])
            ylabel('Rainfall [mm]', 'FontName',SelFont, 'FontSize',SelFnSz)
        
            xtickangle(CurrAxs{iAx}, 90)
            xlabel(xLb, 'FontName',SelFont, 'FontSize',SelFnSz)
            
            % pbaspect(CurrAxs{iAx}, AxsRat)
            box on
    
            xTick = get(CurrAxs{iAx},'XTickLabel');
            set(CurrAxs{iAx}, 'XTickLabel',xTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            yTick = get(CurrAxs{iAx},'YTickLabel');
            set(CurrAxs{iAx}, 'YTickLabel',yTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            title('Rainfall', 'FontName',SelFont, 'FontSize',1.5*SelFnSz)
    
            iAx = iAx + 1;
        end

        % Plot for Temperature
        if any(strcmp(Cnt2Plt, 'Temperature'))
            CurrAxs{iAx} = nexttile([1, 1]);
            hold(CurrAxs{iAx}, 'on')
    
            TempToPlot = DsetFtsTot.(DsetLblAss{4})(IndEvs2Tk); % REMEMBER TO PUT AGAIN MEAN instead of Min!
    
            BarPlotTemp = bar(CurrAxs{iAx}, StartDatesToPlot, TempToPlot, 'FaceColor','flat', 'BarWidth',1, 'CData',[255, 178, 102]./255, 'EdgeColor','k');
    
            ylim([0.98*min(TempToPlot), 1.02*max(TempToPlot)])
            ylabel('Temperature [°c]', 'FontName',SelFont, 'FontSize',SelFnSz)
        
            xtickangle(CurrAxs{iAx}, 90)
            xlabel(xLb, 'FontName',SelFont, 'FontSize',SelFnSz)
            
            % pbaspect(CurrAxs{iAx}, AxsRat)
            box on
    
            xTick = get(CurrAxs{iAx},'XTickLabel');
            set(CurrAxs{iAx}, 'XTickLabel',xTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            yTick = get(CurrAxs{iAx},'YTickLabel');
            set(CurrAxs{iAx}, 'YTickLabel',yTick, 'FontName',SelFont,'fontsize',0.8*SelFnSz)
        
            title('Temperature', 'FontName',SelFont, 'FontSize',1.5*SelFnSz)
    
            iAx = iAx + 1;
        end

        % Axes tick asjustment
        if SnglPlt
            cellfun(@(x) set(x, 'TickLength',[0 .1]), CurrAxs)
        end
    
        % Showing plot and saving...
        if ShowPlt
            set(CurrFig, 'visible','on');
            pause
        end
    
        exportgraphics(CurrFig, [fold_fig_curr,sl,CurrNme,'.png'], 'Resolution',600);
        close(CurrFig)
    end
end