if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon','MunPolygon')
load([fold_var,sl,'GridCoordinates.mat'   ], 'xLongAll','yLatAll')

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);
[InfoDetExst, InfoDet2Use] = load_info_detected(fold_var);

fold_fig_sg = [fold_fig,sl,'SoilGrids'];
if not(exist(fold_fig_sg, 'dir'))
    mkdir(fold_fig_sg)
end

%% For scatter dimension
PixelScale = 0.35 * abs(yLatAll{1}(2,1) - yLatAll{1}(1,1)) / 6e-05;
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, FinScale=PixelScale);

%% Options
PltOpts = listdlg2({'Content to plot', 'Show plot'}, {{'Clay','Sand','NDVI','VegProb'}, {'Yes','No'}});
PltCont = PltOpts{1};
if strcmp(PltOpts{2}, 'Yes'); ShowPlt = true; else; ShowPlt = false; end

switch PltCont
    case 'Clay'
        load([fold_var,sl,'StudyAreaVariables.mat'], 'ClayContentAll')
        PltObjS = reshape(ClayContentAll, 1, numel(ClayContentAll));
        PltLabl = {'ClayContent'};
        PltScTt = {'Clay [%]'};
        ClrScal = 'bone';

    case 'Sand'
        load([fold_var,sl,'StudyAreaVariables.mat'], 'SandContentAll')
        PltObjS = reshape(SandContentAll, 1, numel(SandContentAll));
        PltLabl = {'SandContent'};
        PltScTt = {'Sand [%]'};
        ClrScal = 'winter';

    case 'NDVI'
        load([fold_var,sl,'StudyAreaVariables.mat'], 'NdviAll')
        PltObjS = reshape(NdviAll, 1, numel(NdviAll));
        PltLabl = {'NDVI'};
        PltScTt = {'NDVI [-]'};
        ClrScal = 'summer';

    case 'VegProb'
        load([fold_var,sl,'StudyAreaVariables.mat'], 'VgPrAll')
        PltObjS = table2array(VgPrAll);
        PltLabl = strcat('VegProb_',VgPrAll.Properties.RowNames);
        PltScTt = repmat({'Prob. [%]'}, 1, numel(PltLabl));
        ClrScal = 'pink';

    otherwise
        error('Content to plot not recognized')
end

MinScale = min(cellfun(@(x) min(x, [], 'all'), PltObjS), [], 'all');
MaxScale = max(cellfun(@(x) max(x, [], 'all'), PltObjS), [], 'all');

%% Plot
for iP = 1:size(PltObjS, 1)
    CurrFln = ['SoilGrid-',PltLabl{iP}];
    CurrFig = figure('Visible','off', 'Name',CurrFln);
    CurrAxs = axes('Parent',CurrFig); 
    hold(CurrAxs,'on');
    
    for i1 = 1:numel(xLongAll)
        ValsScale = rescale(PltObjS{iP, i1}(:), 'InputMax',MaxScale, 'InputMin',MinScale);
        fastscattergrid(ValsScale, xLongAll{i1}, yLatAll{i1}, Mask=StudyAreaPolygon, Parent=CurrAxs, ColorMap=ClrScal);
    end
    
    plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',CurrAxs);
    plot(MunPolygon      , 'FaceColor','none', 'LineWidth',1  , 'Parent',CurrAxs);
    
    fig_settings(fold0)
    
    if InfoDetExst
        DetObjs = arrayfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDet2Use{:,5}, InfoDet2Use{:,6});
        uistack(DetObjs,'top')
    end
    
    if exist('LegPos', 'var')
        if InfoDetExst
            LegObjs = {DetObjs(1)};
            LegCaps = {"Points Analyzed"};
        end
    
        CurrLeg = legend(CurrAxs, ...
                         [LegObjs{:}], LegCaps, 'AutoUpdate','off', ...
                                                'NumColumns',2, ...
                                                'FontName',SlFont, ...
                                                'FontSize',SlFnSz, ...
                                                'Location',LegPos, ...
                                                'Box','off');
    
        CurrLeg.ItemTokenSize(1) = 5;
    
        fig_rescaler(CurrFig, CurrLeg, LegPos)
    end
    
    set(CurrAxs, 'Visible','off') % Note: also possible titles will be hide!
    
    colormap(CurrAxs, flipud(colormap(ClrScal)))
    
    LimsCol = linspace(MinScale, MaxScale, 5);
    LimsCol = round(LimsCol, 2, 'significant'); % CHECK FOR LEGEND THAT IS CUTTED AND WITH 3 DECIMAL NUMBERS, WHEN 0 IS PRESENT
    clim([LimsCol(1), LimsCol(end)])
    ColBar = colorbar('Location','westoutside', 'Ticks',LimsCol, 'TickLabels',string(LimsCol), 'FontSize',SlFnSz*.8);
    ColBarPos = get(ColBar,'Position');
    ColBarPos(1) = ColBarPos(1)-.05;
    ColBarPos(3) = ColBarPos(3)*.5;
    set(ColBar, 'Position',ColBarPos)
    title(ColBar, PltScTt{iP}, 'FontName',SlFont, 'FontSize',SlFnSz)
    
    %% Export
    exportgraphics(CurrFig, [fold_fig_sg,sl,CurrFln,'.png'], 'Resolution',600);
    
    % Show Fig
    if ShowPlt
        set(CurrFig, 'Visible','on');
    else
        close(CurrFig)
    end
end