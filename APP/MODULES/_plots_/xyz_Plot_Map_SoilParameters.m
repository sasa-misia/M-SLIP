if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading Files
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon','MunPolygon')
load([fold_var,sl,'LUDSCMapParameters.mat'], 'SoilAssociation','SoilParameters')

[SlFont, SlFnSz, LegPos  ] = load_plot_settings(fold_var);
[InfoDetExst, InfoDet2Use] = load_info_detected(fold_var);

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon);

%% Plotting
for iCase = [NumFigPlot(:)]' % To ensure that it will be horizontal
    %% Names
    switch iCase
        case 1
            CurrFln = 'Lithology';
            LegName = CurrFln;
            SoilCps = cellstr(SoilAssociation{:, 'Acronym'});
            SoilPly = SoilAssociation{:, 'Polygon'};
            SoilClr = SoilAssociation{:, 'Color'};
    
        case 2
            CurrFln = 'EffectiveCohesionMap';
            LegName = '{\it c''} [kPa]';
            SoilCps = cellstr(string(SoilParameters{:, 'c'}));
            SoilPly = SoilParameters{:, 'Polygon'};
            SoilClr = SoilParameters{:, 'Color'};
    
        case 3
            CurrFln = 'FrictionMap';
            LegName = '{\it \phi''} [°]';
            SoilCps = cellstr(string(SoilParameters{:, 'phi'}));
            SoilPly = SoilParameters{:, 'Polygon'};
            SoilClr = SoilParameters{:, 'Color'};
    
        case 4
            CurrFln = 'SoilUnit';
            LegName = 'SC';
            SoilCps = cellstr(string(SoilParameters{:, 'UC'}));
            SoilPly = SoilParameters{:, 'Polygon'};
            SoilClr = SoilParameters{:, 'Color'};
    
        case 5
            CurrFln = 'KtMap';
            LegName = '{\it k_t} [1/h]';
            SoilCps = cellstr(string(SoilParameters{:, 'kt'}));
            SoilPly = SoilParameters{:, 'Polygon'};
            SoilClr = SoilParameters{:, 'Color'};
    
        case 6
            CurrFln = 'AMap';
            LegName = '{\it A} [kPa]';
            SoilCps = cellstr(string(SoilParameters{:, 'A'}));
            SoilPly = SoilParameters{:, 'Polygon'};
            SoilClr = SoilParameters{:, 'Color'};
    
        otherwise
            error('Plot case not recognized!')
    end

    %% Union of equal classes
    LegCaps = unique(SoilCps);
    LegPlys = repmat(polyshape, size(LegCaps));
    LegClrs = cell(size(LegCaps));
    for i2 = 1:numel(LegCaps)
        IndTemp = find(strcmp(SoilCps, LegCaps(i2)));
        LegPlys(i2) = union(SoilPly(IndTemp));
        LegClrs(i2) = SoilClr(IndTemp(1));
    end

    %% Figure initialization
    CurrFig = figure(iCase);
    CurrAxs = axes('Parent',CurrFig); 
    hold(CurrAxs,'on');
    set(CurrFig, 'Name',CurrFln);

    %% Object plot
    LegObjs = cell(size(LegPlys));
    for i2 = 1:numel(LegPlys)
        LegObjs{i2} = plot(LegPlys(i2), 'FaceColor',LegClrs{i2}./255, ...
                                        'FaceAlpha',1, 'EdgeColor','none');
    end

    %% Finalizing
    plot(MunPolygon, 'FaceColor','none', 'LineWidth',1)
    
    fig_settings(fold0)

    if InfoDetExst
        DetObjs = arrayfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDet2Use{:,5}, InfoDet2Use{:,6});
        uistack(DetObjs,'top')
    end
    
    if not(isempty(LegPos))
        if InfoDetExst
            LegObjs = [LegObjs; {DetObjs(1)}];
            LegCaps = [LegCaps; {"Points Analyzed"}];
        end

        CurrLeg = legend([LegObjs{:}], LegCaps, 'AutoUpdate','off', ...
                                                'NumColumns',1, ...
                                                'FontName',SlFont, ...
                                                'FontSize',SlFnSz, ...
                                                'Location',LegPos, ...
                                                'Box','off');

        CurrLeg.ItemTokenSize(1) = 10;

        title(CurrLeg, LegName, 'FontName',SlFont, 'FontSize',SlFnSz*1.2, 'FontWeight','bold')

        fig_rescaler(CurrFig, CurrLeg, LegPos)
    end

    set(CurrAxs, 'visible','off')

    exportgraphics(CurrFig, [fold_fig,sl,CurrFln,'.png'], 'Resolution',600);
end