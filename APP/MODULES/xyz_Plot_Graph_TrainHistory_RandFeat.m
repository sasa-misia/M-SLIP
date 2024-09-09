if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files
sl = filesep;

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize')
    SelFont = Font;
    SelFtSz = FontSize;
else
    SelFont = 'Calibri';
    SelFtSz = 8;
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
            Fl2LdMdl = 'MLMdlA.mat';
            load([fold_res_ml_curr,sl,Fl2LdMdl], 'MLMdl','HistInfo')
    
        case 2
            Fl2LdMdl = 'MLMdlB.mat';
            load([fold_res_ml_curr,sl,Fl2LdMdl], 'MLMdl','HistInfo')
    
        otherwise
            error('No trained ModelA or B found!')
    end
    
    if i1 == 1
        Mdls2Tk = checkbox2(MLMdl.Properties.VariableNames, 'Title','Models to take (max 5):', 'OutType','NumInd');
        if numel(Mdls2Tk) > 5 || numel(Mdls2Tk) < 1
            error('You must select 1 or more structures, up to 5!')
        end
    else
        Mdls2Tk = cellfun(@(x) find(cellfun(@(y) isequal(y, x), MLMdl{'Structure',:})), HistANNsStct{i1-1}, 'UniformOutput',false);
        IsMptCl = cellfun(@isempty, Mdls2Tk);
        if any(IsMptCl)
            error(['Some structures do not have a match in folder ',fold_res_ml_curr])
        end

        Mdls2Tk = cell2mat(Mdls2Tk);
        if numel(Mdls2Tk) ~= numel(HistANNsStct{i1-1})
            error(['Too many structures with a match in folder ',fold_res_ml_curr])
        end
    end

    HistANNsNmes{i1} = MLMdl.Properties.VariableNames(Mdls2Tk);
    HistRndFtFld{i1} = HistInfo.FeatImp.RandFeat(:,Mdls2Tk);
    HistANNsStct{i1} = MLMdl{'Structure',Mdls2Tk};
    clear('MLMdl', 'HistInfo')
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

MLStc = HistANNsStct{1};
MLNms = inputdlg2(strcat({'New name for '},HistANNsNmes{1}), 'DefInp',HistANNsNmes{1});
MLDst = inputdlg2(strcat({'New name for '},FldrsToRd), 'DefInp',FldrsToRd);

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

CurrNme = ['RF Hist for ',strjoin(MLDst, '_')];
CurrFig = figure('Position',[400, 20, 700, 200*numel(MLDst)], 'Name',CurrNme, 'Visible','off');
CurrLay = tiledlayout(numel(MLDst), 1, 'Parent',CurrFig);

[CurrAxs, LinePlt] = deal(cell(1, numel(MLDst)));
for i1 = 1:numel(MLDst)
    CurrAxs{i1} = nexttile([1, 1]);

    hold(CurrAxs{i1}, 'on')

    xlabel(CurrAxs{i1}, xLblTxt, 'FontName',SelFont, 'FontSize',SelFtSz)
    ylabel(CurrAxs{i1}, yLblTxt, 'FontName',SelFont, 'FontSize',SelFtSz)

    set(CurrAxs{i1}, 'FontName',SelFont, 'FontSize',.8*SelFtSz, ...
                     'XTick',0:25:ItrsNum, 'XLim', [0, ItrsNum], ...
                     'YTick',0:2:MaxRFIm, 'YLim', [0, MaxRFIm], ...
                     'YGrid','on', 'XGrid','on')
    % xlim(CurrAxs{i1}, [1, ItrsNum])
    % ylim(CurrAxs{i1}, [0, MaxRFIm])

    title(CurrAxs{i1}, MLDst{i1}, 'FontName',SelFont, 'FontSize',SelFtSz)

    LinePlt{i1} = cell(1, numel(MLStc));
    for i2 = 1:numel(MLStc)
        LinePlt{i1}{i2} = plot(CurrAxs{i1}, 1:ItrsNum, HistRndFtFld{i1}(:,i2).*100, '-', 'LineWidth',1.5, 'Color',StrcClr{i2});
    end
end

CurrLeg = legend([LinePlt{1}{:}], MLNms, 'FontName',SelFont, 'FontSize',SelFtSz*.7);
CurrLeg.Layout.Tile = 'East';

%% Export
ProgressBar.Message = 'Export...';

exportgraphics(CurrFig, [fold_fig,sl,CurrNme,'.png'], 'Resolution',400);

if ShowPlt
    set(CurrFig, 'visible','on');
else
    close(CurrFig)
end