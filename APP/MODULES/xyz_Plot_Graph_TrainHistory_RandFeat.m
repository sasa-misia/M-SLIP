if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files
sl = filesep;

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize')
    SelFont = Font;
    SelFnSz = FontSize;
else
    SelFont = 'Calibri';
    SelFnSz = 8;
end

FoldCntnt = {dir(fold_res).name};
IndSubFld = [dir(fold_res).isdir];
PossFldrs = sort(FoldCntnt([false, false, IndSubFld(3:end)])); % To remove not folders and first 2 hidden folders!
FldrsToRd = checkbox2(PossFldrs);

if numel(FldrsToRd) > 4; error('Please, select less folders!'); end

[HistRndFtFld, HistANNsNmes, HistANNsStct] = deal(cell(1, length(FldrsToRd)));
for i1 = 1:length(FldrsToRd)
    fold_res_ml_curr = [fold_res,sl,FldrsToRd{i1}];
    MdlType = find([exist([fold_res_ml_curr,sl,'ANNsMdlA.mat'], 'file'), ...
                    exist([fold_res_ml_curr,sl,'ANNsMdlB.mat'], 'file')]);
    if not(isscalar(MdlType)); error('More than one model found in your folder!'); end
    switch MdlType
        case 1
            Fl2LdMdl = 'ANNsMdlA.mat';
            load([fold_res_ml_curr,sl,Fl2LdMdl], 'ANNs','HistInfo')
    
        case 2
            Fl2LdMdl = 'ANNsMdlB.mat';
            load([fold_res_ml_curr,sl,Fl2LdMdl], 'ANNs','HistInfo')
    
        otherwise
            error('No trained ModelA or B found!')
    end
    
    if i1 == 1
        Mdls2Tk = checkbox2(ANNs.Properties.VariableNames, 'Title','Models to take (max 5):', 'OutType','NumInd');
        if numel(Mdls2Tk) > 5 || numel(Mdls2Tk) < 1
            error('You must select 1 or more structures, up to 5!')
        end
    else
        Mdls2Tk = cellfun(@(x) find(cellfun(@(y) isequal(y, x), ANNs{'Structure',:})), HistANNsStct{i1-1}, 'UniformOutput',false);
        IsMptCl = cellfun(@isempty, Mdls2Tk);
        if any(IsMptCl)
            error(['Some structures do not have a match in folder ',fold_res_ml_curr])
        end

        Mdls2Tk = cell2mat(Mdls2Tk);
        if numel(Mdls2Tk) ~= numel(HistANNsStct{i1-1})
            error(['Too many structures with a match in folder ',fold_res_ml_curr])
        end
    end

    HistANNsNmes{i1} = ANNs.Properties.VariableNames(Mdls2Tk);
    HistRndFtFld{i1} = HistInfo.FeatImp.RandFeat(:,Mdls2Tk);
    HistANNsStct{i1} = ANNs{'Structure',Mdls2Tk};
    clear('ANNs', 'HistInfo')
end

if not(all(cellfun(@(x) isequal(x, HistANNsStct{1}), HistANNsStct)))
    error('Structures that you are trying to use are not identical!')
end

HistLngth = cellfun(@(x) size(x,1), HistRndFtFld);
if numel(unique(HistLngth)) > 1
    warning('Length of history is not the same for each folder! It will be adjusted.')
    for i1 = 1:numel(HistRndFtFld)
        HistRndFtFld{i1} = HistRndFtFld{i1}(1:min(HistLngth), :);
    end
end

%% Options
ProgressBar.Message = 'Options...';

ANNsStc = HistANNsStct{1};
ANNsNms = inputdlg2(strcat({'New name for '},HistANNsNmes{1}), 'DefInp',HistANNsNmes{1});
ANNsDst = inputdlg2(strcat({'New name for '},FldrsToRd), 'DefInp',FldrsToRd);

PltOpts = checkbox2({'Show plots'}, 'OutType','LogInd');
ShowPlt = PltOpts(1);

LnWidth = .8;
StrcClr = {'#739373', '#d3643c', '#0097df', '#caa6ed', '#c73866'}; % Colors
yLblTxt = 'Random Feature Importance [%]';
xLblTxt = 'Number of iterations [-]';
ItrsNum = min(HistLngth);
MaxRFIm = 8; % In percentage

%% Plot core
ProgressBar.Message = 'Plot...';

CurrNme = ['RF Hist for ',strjoin(ANNsDst, '_')];
CurrFig = figure('Position',[400, 20, 700, 200*numel(ANNsDst)], 'Name',CurrNme, 'Visible','off');
CurrLay = tiledlayout(numel(ANNsDst), 1, 'Parent',CurrFig);

[CurrAxs, LinePlt] = deal(cell(1, numel(ANNsDst)));
for i1 = 1:numel(ANNsDst)
    CurrAxs{i1} = nexttile([1, 1]);

    hold(CurrAxs{i1}, 'on')

    xlabel(CurrAxs{i1}, xLblTxt, 'FontName',SelFont, 'FontSize',SelFnSz)
    ylabel(CurrAxs{i1}, yLblTxt, 'FontName',SelFont, 'FontSize',SelFnSz)

    set(CurrAxs{i1}, 'FontName',SelFont, 'FontSize',.8*SelFnSz, ...
                     'XTick',0:25:ItrsNum, 'XLim', [0, ItrsNum], ...
                     'YTick',0:2:MaxRFIm, 'YLim', [0, MaxRFIm], ...
                     'YGrid','on', 'XGrid','on')
    % xlim(CurrAxs{i1}, [1, ItrsNum])
    % ylim(CurrAxs{i1}, [0, MaxRFIm])

    title(CurrAxs{i1}, ANNsDst{i1}, 'FontName',SelFont, 'FontSize',SelFnSz)

    LinePlt{i1} = cell(1, numel(ANNsStc));
    for i2 = 1:numel(ANNsStc)
        LinePlt{i1}{i2} = plot(CurrAxs{i1}, 1:ItrsNum, HistRndFtFld{i1}(:,i2).*100, '-', 'LineWidth',1.5, 'Color',StrcClr{i2});
    end
end

CurrLeg = legend([LinePlt{1}{:}], ANNsNms, 'FontName',SelFont, 'FontSize',SelFnSz*.7);
CurrLeg.Layout.Tile = 'East';

%% Export
ProgressBar.Message = 'Export...';

exportgraphics(CurrFig, [fold_fig,sl,CurrNme,'.png'], 'Resolution',400);

if ShowPlt
    set(CurrFig, 'visible','on');
else
    close(CurrFig)
end