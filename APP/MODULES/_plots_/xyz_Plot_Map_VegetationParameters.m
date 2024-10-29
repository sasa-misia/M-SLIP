if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading Files
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'  ], 'StudyAreaPolygon','MunPolygon')
load([fold_var,sl,'VUDVCMapParameters.mat'  ], 'VegAssociation','VegParameters')

[SlFont, SlFnSz, LegPos  ] = load_plot_settings(fold_var);
[InfoDetExst, InfoDet2Use] = load_info_detected(fold_var);

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'RefArea',.035, 'Extremes',true);

%% Plotting
for iCase = [NumFigPlot(:)]' % To ensure that it will be horizontal
    %% Names
    switch iCase
        case 1
            CurrFln = 'VegetationMap';
            LegName = CurrFln;
            VegCaps = cellstr(VegAssociation{:, 'Acronym'});
            VegPlys = VegAssociation{:, 'Polygon'};
            VegClrs = VegAssociation{:, 'Color'};
    
        case 2
            CurrFln = 'RootCohesionMap';
            LegName = '{\it c_r} [kPa]';
            VegCaps = cellstr(string(VegParameters{:, 'cr'}));
            VegPlys = VegParameters{:, 'Polygon'};
            VegClrs = VegParameters{:, 'Color'};
    
        case 3
            CurrFln = 'BetastarMap';
            LegName = '{\it \beta^*} [-]';
            VegCaps = cellstr(string(VegParameters{:, 'beta'}));
            VegPlys = VegParameters{:, 'Polygon'};
            VegClrs = VegParameters{:, 'Color'};
    
        case 4
            CurrFln = 'VegetationUnit';
            LegName = 'VC';
            VegCaps = cellstr(string(VegParameters{:, 'UC'}));
            VegPlys = VegParameters{:, 'Polygon'};
            VegClrs = VegParameters{:, 'Color'};
    
        otherwise
            error('Plot case not recognized!')
    end

    %% Union of equal classes
    LegCaps = unique(VegCaps);
    LegPlys = repmat(polyshape, size(LegCaps));
    LegClrs = cell(size(LegCaps));
    for i2 = 1:numel(LegCaps)
        IndTemp = find(strcmp(VegCaps, LegCaps(i2)));
        LegPlys(i2) = union(VegPlys(IndTemp));
        LegClrs(i2) = VegClrs(IndTemp(1));
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

        CurrLeg = legend(CurrAxs, ...
                         [LegObjs{:}], LegCaps, 'AutoUpdate','off', ...
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