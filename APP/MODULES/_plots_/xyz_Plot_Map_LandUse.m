if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'LandUsesVariables.mat' ], 'FileNameLandUsesAssociation','LandUsePolygonsStudyArea','AllLandUnique','LandToRemovePolygon')
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon')

OrthoAnswer = 0;
if exist([fold_var,sl,'Orthophoto.mat'], 'file')
    load([fold_var,sl,'Orthophoto.mat'], 'ROrtho','ZOrtho')
    OrthoAnswer = 1;
end

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SlFont = Font;
    SlFnSz = FontSize;
    if exist('LegendPosition', 'var'); LegPos = LegendPosition; end
else
    SlFont = 'Calibri';
    SlFnSz = 8;
    LegPos = 'Best';
end

InfoDetExst = false;
if exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDet2Use = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetExst = true;
end

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'RefArea',.035, 'Extremes',true);

%% Loading Excel
Sheet_Ass  = readcell(strcat(fold_user,sl,FileNameLandUsesAssociation), 'Sheet','Association');
CheckColor = cellfun(@ismissing, Sheet_Ass(2:end,3), 'UniformOutput',false);

if all([CheckColor{:}])
    Options = {'Yes, thanks', 'No, for God!'};
    AssignRndColors = uiconfirm(Fig, ['No colors are set in the Excel association. ' ...
                                      'Do you want to assign a random triplet'], ...
                                     'Window type', 'Options',Options);
    switch AssignRndColors
        case 'Yes, thanks'
            LUColors = rand(length(CheckColor),3).*255;
        case 'No, for God!'
            return
    end
else
    LUColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
                                        Sheet_Ass(2:end,3), 'UniformOutput',false)); 
end

%% Plot based on user selection
ProgressBar.Message = 'Plotting...';
for iCase = [NumFigPlot(:)]' % To ensure that it will be horizontal
    %% Names
    switch iCase
        case 1
            CurrFln = 'AllLandUse';
            LegName = '';
    
        case 2
            CurrFln = 'ExcludedLandUse';
            LegName = '';
    
        otherwise
            error('Plot case not recognized!')
    end

    %% Figure initialization
    CurrFig = figure(iCase);
    CurrAxs = axes('Parent',CurrFig); 
    hold(CurrAxs,'on');
    set(CurrFig, 'Name',CurrFln);  
    
    %% Object plot
    switch iCase
        case 1
            PolygonsPlot = cell(1, size(LandUsePolygonsStudyArea,2));
            for i1 = 1:size(LandUsePolygonsStudyArea,2)
                PolygonsPlot{i1} = plot(LandUsePolygonsStudyArea(i1), 'FaceColor',LUColors(i1,:)./255, ...
                                                                      'FaceAlpha',1, 'EdgeColor','none');
            end

            if exist('LegPos', 'var')
                LegObjs = PolygonsPlot;
                LegCapt = cellstr(AllLandUnique);
            end
    
        case 2
            if OrthoAnswer
                cellfun(@(x,y) geoshow(x, y, 'FaceAlpha',.5), ZOrtho, ROrtho);
            end
    
            LUExcludedPlot = cell(1, numel(LandToRemovePolygon));
            for i1 = 1:numel(LandToRemovePolygon)
                LUExcludedPlot{i1} = plot(LandUsePolygonsStudyArea(LandToRemovePolygon(i1)), ...
                                                        'FaceColor',LUColors(LandToRemovePolygon(i1),:)./255, ...
                                                        'FaceAlpha',1, 'EdgeColor','none');
            end

            if exist('LegPos', 'var')
                LegObjs = LUExcludedPlot;
                LegCapt = cellstr(AllLandUnique(LandToRemovePolygon));
            end
    end

    %% Finalizing
    plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)
    
    fig_settings(fold0)

    if InfoDetExst
        DetObjs = arrayfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDet2Use{:,5}, InfoDet2Use{:,6});
        uistack(DetObjs,'top')
    end
    
    if exist('LegPos', 'var')
        if InfoDetExst
            LegObjs = [LegObjs, {DetObjs(1)}];
            LegCaps = [LegCaps; {"Points Analyzed"}];
        end

        CurrLeg = legend(CurrAxs, ...
                         [LegObjs{:}], LegCaps, 'AutoUpdate','off', ...
                                                'NumColumns',1, ...
                                                'FontName',SlFont, ...
                                                'FontSize',SlFnSz, ...
                                                'Location',LegPos, ...
                                                'Box','off');

        CurrLeg.ItemTokenSize(1) = 5;

        % title(CurrLeg, LegName, 'FontName',SlFont, 'FontSize',SlFnSz*1.2, 'FontWeight','bold')

        fig_rescaler(CurrFig, CurrLeg, LegPos)
    end

    set(CurrAxs, 'visible','off')

    exportgraphics(CurrFig, [fold_fig,sl,CurrFln,'.png'], 'Resolution',600);
end