if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% Loading
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon')
load([fold_var,sl,'GridCoordinates.mat'],    'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'GeneralRainfall.mat'],    'Gauges','RecDatesEndCommon','GeneralData')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SelectedFont     = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont     = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition   = 'Best';
end

InfoDetectedExist = false;
if exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetectedExist = true;
end

%% For scatter dimension
CurrSzDEM = deg2km(abs(yLatAll{1}(1,1)-yLatAll{1}(2,1)))*1000;
FinScale  = .2*CurrSzDEM/20; % A DEM of 20 m is the reference!
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'FinScale',FinScale);

%% Options
ProgressBar.Message = 'Options...';

ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

%% Selection of events
switch RainFallType
    case {0, 1}
        %% Both for RainFallType 0 and 1
        ProgressBar.Message = 'Loading rainfalls...';
        if RainFallType == 1
            load([fold_var,sl,'RainInterpolated.mat'], 'RainInterpolated','IndexInterpolation')

            EventsInterpolated = RecDatesEndCommon(IndexInterpolation);
            IndPlot = checkbox2(string(EventsInterpolated), 'Title',{'Select event analysed to plot:'}, 'OutType','NumInd');

        elseif RainFallType == 0
            load([fold_var,sl,'RainInterpolated.mat'], 'SelectedHoursRun')

            ForecastRunUnique = unique([SelectedHoursRun{:,2}]);
        
            IndexForecastInterpolated = cell(1, length(ForecastRunUnique));
            for i1 = 1:length(ForecastRunUnique)
                IndexForecastRun = cellfun(@(x) x==ForecastRunUnique(i1), SelectedHoursRun(:,2));
                IndexForecastInterpolated{i1} = unique([SelectedHoursRun{IndexForecastRun,1}]);
            end
    
            RunInterpolated = string(ForecastData(ForecastRunUnique));
            ChoiceRunTime = listdlg2({'Select the run time of the forcast model :'}, RunInterpolated, 'OutType','NumInd');
            RunSel  = datetime(RunInterpolated(ChoiceRunTime), 'Format','dd/MM/yyyy HH');
            RunSel  = cellfun(@(x) x==RunSel, ForecastData(:,1));
            RunSel1 = find(RunSel);
    
            EventsInterpolated = [ForecastData{RunSel,2}(IndexForecastInterpolated{(ForecastRunUnique==RunSel1)})];
        
            IndPlot = checkbox2(string(EventsInterpolated), 'Title',{'Select interpolated rainfall:'}, 'OutType','NumInd');
        end

        FigToPlot = numel(IndPlot);

    case 2
        FigToPlot = 1;
end

%% Plot based on selection
for iFig = 1:FigToPlot
    switch RainFallType
        case {0, 1}
            %% Both for RainFallType 0 and 1
            ProgressBar.Message = 'Loading rainfalls...';
            if RainFallType == 1
                RainSelected = RainInterpolated(IndPlot(iFig),:);
                DataInStationSelected = GeneralData(:,(IndPlot(iFig)+IndexInterpolation(1)-1));
                RainfallEvent = replace( [char(EventsInterpolated(IndPlot(iFig))),' Rec'], {':', '/', '\'}, '-' );
    
                % clear('RainInterpolated')
            
            elseif RainFallType == 0
                load([fold_var_rain_for,sl,'RainForecastInterpolated',num2str(RunSel1),'.mat'], 'RainForecastInterpolated');
            
                RainSelected  = RainForecastInterpolated(IndPlot(iFig),:);
                RainfallEvent = replace( [char(EventsInterpolated(IndPlot(iFig))),' For'], {':', '/', '\'}, '-' );
            end
    
            ProgressBar.Message = 'Data extraction...';
    
            % ---- Range and Color assignment ----
            RainRangeVal = [1, 1.5, 2, 2.5, 3, 4];
            
            ColorRain = { [228, 229, 224]
                          [171, 189, 227]
                          [169, 200, 244]
                          [048, 127, 226]
                          [000, 000, 255]
                          [018, 010, 143]
                          [019, 041, 075] };
            
            [xLongStudyArea, yLatStudyArea, RainStudyArea] = deal(cell(size(xLongAll)));
            RainRanges = cell(size(ColorRain,1), length(xLongAll));
            for i1 = 1:size(RainRanges,2)
                xLongStudyArea{i1} = xLongAll{i1}(IndexDTMPointsInsideStudyArea{i1});
                yLatStudyArea{i1}  = yLatAll{i1}(IndexDTMPointsInsideStudyArea{i1});
                % RainStudyArea{i1} = RainSelected{i1}(IndexDTMPointsInsideStudyArea{i1});
                
                RainRanges{1  ,i1} = find(RainSelected{i1}<=RainRangeVal(1));
                RainRanges{end,i1} = find(RainSelected{i1}>=RainRangeVal(6));
                for i2 = 2:(size(RainRanges,1) - 1)
                    RainRanges{i2, i1} = find(RainSelected{i1}>RainRangeVal(i2-1) & RainSelected{i1}<=RainRangeVal(i2));
                end
            end
            
            ProgressBar.Message = 'Plotting...';
    
            filename1 = ['Rain ',RainfallEvent];
            f1  = figure(1);
            ax1 = axes(f1);
    
            set(f1, 'Name',filename1, 'Visible','off')
            set(ax1, 'Visible','off')
            hold(ax1,'on')
            
            for i2 = 1:size(xLongAll,2)
                hPlotRain = cellfun(@(x,y) scatter(xLongStudyArea{i2}(x), yLatStudyArea{i2}(x), PixelSize, 'o', ...
                                                            'MarkerFaceColor',y./255, 'MarkerEdgeColor','none'), ...
                                                RainRanges(:,i2), ColorRain, 'UniformOutput',false);
            end
    
            plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)
    
            fig_settings(fold0)
    
            if InfoDetectedExist
                hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                        InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
                uistack(hdetected,'top')
            end
            
            if exist('LegendPosition', 'var')
                LegendObjects = hPlotRain;
                LegendCaption = {'< 1', '1 - 1.5', '1.5 - 2', '2 - 2.5', '2.5 - 3', '3 - 4', '> 4'};
    
                if InfoDetectedExist
                    LegendObjects = [LegendObjects; {hdetected(1)}];
                    LegendCaption = [LegendCaption, {"Points Analyzed"}];
                end
        
                hleg = legend([LegendObjects{:}], ...
                              LegendCaption, ...
                              'NumColumns',2, ...
                              'FontName',SelectedFont, ...
                              'Location',LegendPosition, ...
                              'FontSize',SelectedFontSize, ...
                              'Box','off');
        
                hleg.ItemTokenSize(1) = 10;
                
                legend('AutoUpdate','off');
                
                title(hleg, 'Rain [mm]', 'FontName',SelectedFont, ...
                            'FontSize',SelectedFontSize*1.2, 'FontWeight','bold')
    
                fig_rescaler(f1, hleg, LegendPosition)
            end
    
            exportgraphics(f1, [fold_fig,sl,filename1,'.png'], 'Resolution',600);
    
            if ShowPlots; set(f1, 'visible','on'); else; close(f1); end
    
            % ---- Plot of Rain Gauges positions ----
            if RainFallType == 1
                filename2 = 'LocationRainGauges';
                f2  = figure(2);
                ax2 = axes(f2);
                
                set(f2, 'Name',filename2, 'Visible','off');
                set(ax2, 'Visible','off')
                hold(ax2,'on')
                
                scatter(Gauges{2}(:,1), Gauges{2}(:,2), '*k')
    
                plot(StudyAreaPolygon, 'LineWidth',1, 'FaceColor',[255 64 64]./255, ...
                                       'EdgeColor',[179 40 33]./255, 'FaceAlpha',0.3);
                
                for i1 = 1:size(DataInStationSelected,1)
                    text(Gauges{2}(i1,1)+.01, Gauges{2}(i1,2), ...
                            [char(Gauges{1}(i1)),' (',num2str(DataInStationSelected(i1)),' mm)'], ...
                                                'FontName',SelectedFont, 'FontSize',SelectedFontSize)
                end
                
                fig_settings(fold0)
        
                exportgraphics(f2, [fold_fig,sl,filename2,'.png'], 'Resolution',600);
    
                if ShowPlots; set(f2, 'visible','on'); else; close(f2); end
            end
    
        case 2
            %% For RainFallType 2
            ProgressBar.Message = 'Plotting...';
    
            SelRecStation = char(listdlg2({'Select the recording station :'}, Gauges{1}));
            IndSelRecStat = find( arrayfun(@(x) strcmp(x,SelRecStation), Gauges{1}) );
        
            filename1 = ['RecordedRainfall',SelRecStation];
            f1 = figure(1);
    
            set(f1, 'Name',filename1, 'Visible','off')
    
            yyaxis left
            bar(RecDatesEndCommon, GeneralData(IndSelRecStat,:), 'FaceColor',[0 127 255]./255);
            ylabel('{\it h_w} [mm]', 'FontName',SelectedFont)
        
            set(gca, ...
                'XLim'              , [min(RecDatesEndCommon), max(RecDatesEndCommon)], ...
                'YLim'              , [0, 9], ...
                'Box'               , 'on', ...
                'TickDir'           , 'in', ...
                'TickLength'        , [.01, .01], ...
                'XMinorTick'        , 'off', ...
                'YMinorTick'        , 'off', ...
                'XGrid'             , 'off', ...
                'YGrid'             , 'off', ...
                'XColor'            , [0, 0, 0], ...
                'YColor'            , [0, 127, 255]./255, ...
                'XTick'             , RecDatesEndCommon(1):days(5):RecDatesEndCommon(end), ...
                'FontSize'          , SelectedFontSize, ...
                'FontName'          , SelectedFont, ...
                'YTick'             , 0:1:9, ...
                'LineWidth'         , .5)
        
            yyaxis right
            plot(RecDatesEndCommon, cumsum(GeneralData(IndSelRecStat,:)), 'k')
            ylabel('Cumulative [mm]', 'FontName',SelectedFont)
        
            daspect auto
            
            set(gca, ...
                'XLim'              , [min(RecDatesEndCommon), max(RecDatesEndCommon)], ...
                'YLim'              , [0, 200], ...
                'Box'               , 'on', ...
                'TickDir'           , 'in', ...
                'TickLength'        , [.01, .01], ...
                'XMinorTick'        , 'off', ...
                'YMinorTick'        , 'off', ...
                'XGrid'             , 'off', ...
                'YGrid'             , 'off', ...
                'XColor'            , [0, 0, 0], ...
                'YColor'            , [0, 0, 0]./255, ...
                'XTick'             , RecDatesEndCommon(1):days(5):RecDatesEndCommon(end), ...
                'FontSize'          , 10, ...
                'FontName'          , SelectedFont, ...
                'YTick'             , 0:20:200, ...
                'LineWidth'         , .5)
        
            exportgraphics(f1, [fold_fig,sl,filename1,'.png'], 'Resolution',600);
    
            if ShowPlots; set(f1, 'visible','on'); else; close(f1); end
    end
end