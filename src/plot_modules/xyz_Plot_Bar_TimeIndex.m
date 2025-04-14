if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Options
FldCntn = {dir(fold_res_ml).name};
IndSbFl = [dir(fold_res_ml).isdir];
PssFlds = FldCntn([false, false, IndSbFl(3:end)]); % To remove not folders and first 2 hidden folders!
Flds2Rd = checkbox2(PssFlds);

PltOpts = checkbox2({'Show plots', 'Average results of events'}, 'DefInp',[0, 1], 'OutType','LogInd');
ShowPlt = PltOpts(1);
AvrgEvs = PltOpts(2);

%% Loading files
sl = filesep;

if numel(Flds2Rd) > 6
    error('Too much models! Please select max 6 models.')
end

MdlsTI = cell(4, numel(Flds2Rd));
for i1 = 1:numel(Flds2Rd)
    fold_res_ml_curr = [fold_res_ml,sl,Flds2Rd{i1}];
    load([fold_res_ml_curr,sl,'TimeScoreIndex.mat'], 'TimeScore','Thresholds')

    SelANN = listdlg2('Model to use:', TimeScore.Properties.VariableNames);
    Series = TimeScore{'Series', SelANN}{:};
    TimeIn = TimeScore{'TimeScore', SelANN}{:};

    [~, MdlNme, ~] = fileparts(fold_res_ml_curr);
    MdlNmR = strrep(MdlNme, '_', '-');

    TimeEv = cellfun(@(x) x(end), Series{1,:}); % Time of events

    if (size(TimeIn, 2) ~= 1) && not(AvrgEvs)
        Ind2Avg = checkbox2(TimeEv, 'Title',{'Events to consider (averaged):'}, 'OutType','NumInd');
        TimeEv(:, Ind2Avg);
        TimeIn(:, Ind2Avg);
    end

    MdlsTI(:, i1) = {MdlNmR; mean(cell2mat(table2array(TimeIn)), 2); TimeEv; Thresholds};
end

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

%% Filtering
MinThrComm = max(cellfun(@min, MdlsTI(4, :)));
MaxThrComm = min(cellfun(@max, MdlsTI(4, :)));
IndThrComm = cellfun(@(x) find(x == MinThrComm) : find(x == MaxThrComm), MdlsTI(4, :), 'UniformOutput',false);

ChckSzComm = isscalar(unique(cellfun(@numel, IndThrComm)));
if not(ChckSzComm)
    error('Your events have different thresholds between common min and max ones!')
end

CommThr = MdlsTI{4, 1}(IndThrComm{1});
CommTIs = cellfun(@(x, y) x(y), MdlsTI(2, :), IndThrComm, 'UniformOutput',false);
CommTIs = cellfun(@(x) x', CommTIs, 'UniformOutput',false);
CommNms = MdlsTI(1, :);

%% Plot
CurrNme = 'TimeIndexComparison';
CurrFig = figure('Position',[100, 100, 220*numel(Flds2Rd), 400], 'Name',CurrNme, 'Visible','off');
CurrAxs = subplot(1, 1, 1, 'Parent',CurrFig);
hold(CurrAxs, 'on')

CmmNmsC = categorical(CommNms);
CmmNmsC = reordercats(CmmNmsC, CommNms);
PltBrOb = bar(CmmNmsC, cat(1, CommTIs{:}), 'Parent',CurrAxs);

ylim([0 100])
ylabel('TI [%]', 'FontName',SlFont, 'FontSize',SlFnSz)

xlabel('Model', 'FontName',SlFont, 'FontSize',SlFnSz)

LgndTxt = strcat({'TH = '}, num2str(CommThr'),{' %'});
LgndObj = legend(LgndTxt{:}, 'FontName',SlFont, ...
                             'FontSize',SlFnSz, ...
                             'Location',LegPos, ...
                             'Box','off');
LgndObj.ItemTokenSize(1) = 10;

set(CurrAxs, 'YTick',0:20:100, 'FontName',SlFont, 'FontSize',SlFnSz);

exportgraphics(CurrFig, [fold_fig,sl,CurrNme,'.png'], 'Resolution',400);

% Show Fig
if ShowPlt
    set(CurrFig, 'visible','on');
else
    close(CurrFig)
end