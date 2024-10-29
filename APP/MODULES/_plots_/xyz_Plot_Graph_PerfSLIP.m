if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files
sl = filesep;

load([fold_res,sl,'PerfCurveSLIP.mat'], 'AnlLbl','AnlFPR','AnlTPR','AnlAUC','AnlTpe')

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
    LegPos = 'eastoutside';
end

%% Options
PltOpts = checkbox2({'Show plot'}, 'DefInp',0, 'OutType','LogInd');
CurrFln = char(inputdlg2({'PNG export name:'}, 'DefInp',{'Performance Comparison'}));
PltChc  = listdlg2('Type of chart?', {'TPR / FPR', 'TPR / TNR'}, 'OutType','NumInd');

ShowPlt = PltOpts(1);

%% Extraction
NumROC = numel(AnlAUC);

[AnlTNR, AnlFNR] = deal(cell(size(AnlTPR)));
for i1 = 1:NumROC
    AnlTNR{i1} = 1 - AnlFPR{i1};
    AnlFNR{i1} = 1 - AnlTPR{i1};
end

%% Image Creation
CurrFig = figure('Position',[400, 20, 700, 500], 'Visible','off', 'Name',CurrFln);
CurrAxs = axes('Parent',CurrFig, 'FontName',SlFont, 'FontSize',SlFnSz);
hold(CurrAxs,'on');

LnClrs = hex2rgb([ '#808080'; '#008080'; '#7A6446'; '#42E6AA'; ...
                   '#9616E6'; '#373737'; '#4B7A6F'; '#58587A' ]);
LnTyps = ["-", "-.", "--", ":", "-.", "--", ":", "-."];
MkTyps = ["d", "o" , "-s", "^", "+" , "x" , "p", ">" ];

switch PltChc
    case 1
        for i1 = 1:NumROC
            plot(AnlFPR{i1}, AnlTPR{i1}, LnTyps(i1), 'Color',LnClrs(i1,:))
        end

        plot([0 1],[0 1], '--', 'Color','r')

        for i1 = 1:NumROC
            if strcmp(AnlTpe{i1}, 'Slip')
                for i2 = IndSgPts{i1}
                    plot(AnlFPR{i1}(i2), AnlTPR{i1}(i2), 'Marker',MkTyps(i1), ...
                                'MarkerEdgeColor',LnClrs(i1,:), 'MarkerFaceColor',LnClrs(i1,:))
                end
            end
        end

    case 2
        for i1 = 1:NumROC
            plot(AnlTNR{i1}, AnlTPR{i1}, LnTyps(i1), 'Color',LnClrs(i1,:))
        end

        plot([0 1],[1 0], '--', 'Color','r')

        for i1 = 1:NumROC
            if strcmp(AnlTpe{i1}, 'Slip')
                for i2 = IndSgPts{i1}
                    plot(AnlTNR{i1}(i2), AnlTPR{i1}(i2), 'Marker',MkTyps(i1), ...
                                'MarkerEdgeColor',LnClrs(i1,:), 'MarkerFaceColor',LnClrs(i1,:))
                end
            end
        end

    otherwise
        error('Plot choice not recognized!')
end

LegLbls = strcat(string(AnlLbl)'," (","{\itAUC}"," = ",compose("%4.1f",[AnlAUC{:}]')," %)");
CurrLeg = legend(LegLbls, 'AutoUpdate','off',...
                          'Location',LegPos,...
                          'NumColumns',1,...
                          'FontName',SlFont,...
                          'FontSize',SlFnSz,...
                          'Box','on');
% CurrLeg.Title.String = 'AUC';
CurrLeg.ItemTokenSize = [10, 5];

daspect([1, 1.5, 1])
xlim([0 1])
ylim([0 1])
xlabel('\itFPR', 'FontName',SlFont, 'FontSize',1.6*SlFnSz)
ylabel('\itTPR', 'FontName',SlFont, 'FontSize',1.6*SlFnSz)

%% Export png
ProgressBar.Message = 'Export...';

exportgraphics(CurrFig, [fold_fig,sl,CurrFln,'.png'], 'Resolution',600);

if ShowPlt
    set(CurrFig, 'visible','on');
else
    close(CurrFig)
end