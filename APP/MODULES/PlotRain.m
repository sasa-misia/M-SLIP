%% Loading
cd(fold_var)
load('StudyAreaVariables.mat')
load('GridCoordinates.mat')
load('AnalysisInformation.mat')
load('GeneralRainfall.mat')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'Best';
end

InfoDetectedExist = false;
if exist('InfoDetectedSoilSlips.mat', 'file')
    load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips')
    InfoDetectedExist = true;
end

%% For scatter dimension
RefStudyArea = 0.0417;
ExtentStudyArea = area(StudyAreaPolygon);
% ExtentStudyArea = prod(MaxExtremes-MinExtremes);
RatioRef = ExtentStudyArea/RefStudyArea;
PixelSize = .028/RatioRef;
DetPixelSize = 3*PixelSize;

%% Plot based on selection
switch RainFallType
    case {0, 1}
        %% Both for RainFallType 0 and 1
        if RainFallType==1
            load('RainInterpolated.mat')
            EventsInterpolated = RainfallDates(IndexInterpolation);
            IndPlot = listdlg('PromptString',{'Select event analysed to plot:',''}, ...
                              'ListString',EventsInterpolated);
            RainSelected = RainInterpolated(IndPlot,:);
            DataInStationSelected = GeneralRainData(:,(IndPlot+IndexInterpolation(1)-1));
            RainfallEvent = replace( strcat(string(EventsInterpolated(IndPlot)),' Rec'), {':', '/', '\'}, '-' );

            clear('RainInterpolated')
        
        elseif RainFallType==0
            load('RainInterpolated.mat', 'SelectedHoursRun');
            ForecastRunUnique = unique([SelectedHoursRun{:,2}]);
        
            for i1 = 1:length(ForecastRunUnique)
                IndexForecastRun = cellfun(@(x) x==ForecastRunUnique(i1), SelectedHoursRun(:,2));
                IndexForecastInterpolated{i1} = unique([SelectedHoursRun{IndexForecastRun,1}]);
            end
    
            RunInterpolated = string(ForecastData(ForecastRunUnique));
            ChoiceRunTime = listdlg('PromptString',{'Select the run time of the forcast model :',''}, ...
                                    'ListString',RunInterpolated);
            RunSel = datetime(RunInterpolated(ChoiceRunTime), 'Format','dd/MM/yyyy HH');
            RunSel = cellfun(@(x) x==RunSel, ForecastData(:,1));
            RunSel1 = find(RunSel);
    
            EventsInterpolated = [ForecastData{RunSel,2}(IndexForecastInterpolated{(ForecastRunUnique==RunSel1)})];
        
            IndPlot = listdlg('PromptString',{'Select interpolated rainfall:',''}, ...
                              'ListString',EventsInterpolated);
        
            cd(fold_var_rain_for)
            load(strcat('RainForecastInterpolated',num2str(RunSel1)));
        
            RainSelected  = RainForecastInterpolated(IndPlot,:);
            RainfallEvent = replace( strcat(string(EventsInterpolated(IndPlot)),' For'), {':', '/', '\'}, '-' );
        end

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
        
        cd(fold0)
        filename1 = strcat("Rain ",RainfallEvent);
        f1 = figure(1);
        ax1 = axes(f1);
        hold(ax1,'on')
        set(f1, 'Name',filename1)
        set(ax1, 'visible','off')
        
        for i2 = 1:size(xLongAll,2)
            hPlotRain = cellfun(@(x,y) scatter(xLongStudyArea{i2}(x), yLatStudyArea{i2}(x), PixelSize, 'o', ...
                                                        'MarkerFaceColor',y./255, 'MarkerEdgeColor','none'), ...
                                        RainRanges(:,i2), ColorRain, 'UniformOutput',false);
        end

        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)

        fig_settings(fold0)

        if InfoDetectedExist
            hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
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

        cd(fold_fig)
        exportgraphics(f1, strcat(filename1,'.png'), 'Resolution',600);

        % ---- Plot of Rain Gauges positions ----
        if RainFallType==1
            filename2 = 'LocationRainGauges';
            f2 = figure(2);
            ax2 = axes(f2);
            hold(ax2,'on')
            set(f2, 'Name',filename2);
            set(ax2, 'visible','off')
            
            scatter(RainGauges{2}(:,1), RainGauges{2}(:,2), '*k')

            plot(StudyAreaPolygon, 'LineWidth',1, 'FaceColor',[255 64 64]./255, ...
                                   'EdgeColor',[179 40 33]./255, 'FaceAlpha',0.3);
            
            for i1 = 1:size(DataInStationSelected,1)
                text(RainGauges{2}(i1,1)+.01, RainGauges{2}(i1,2), ...
                                strcat(RainGauges{1}(i1),'(',num2str(DataInStationSelected(i1)),')'), ...
                                'FontName',SelectedFont)
            end
            
            fig_settings(fold0)
    
            cd(fold_fig)
            exportgraphics(f2, strcat(filename2,'.png'), 'Resolution',600);
        end

    case 2
        %% For RainFallType 2
        ChoiceRecSta = listdlg('PromptString',{'Select the recording station :',''}, ...
                               'ListString',RainGauges{1});
    
        SelectedRecordingStation = RainGauges{1}(ChoiceRecSta);
    
        PosSelRecStation = find( arrayfun(@(x) strcmp(x,SelectedRecordingStation), RainGauges{1}) );
    
        filename1 = strcat('RecordedRainfall',SelectedRecordingStation);
        f1 = figure(1);

        set(f1, 'Name',filename1)

        yyaxis left
        bar(RainfallDates, GeneralRainData(PosSelRecStation,:), 'FaceColor',[0 127 255]./255);
        ylabel('{\it h_w} [mm]', 'FontName',SelectedFont)
    
        set(gca, ...
            'XLim'              , [min(RainfallDates), max(RainfallDates)], ...
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
            'XTick'             , RainfallDates(1):days(5):RainfallDates(end), ...
            'FontSize'          , SelectedFontSize, ...
            'FontName'          , SelectedFont, ...
            'YTick'             , 0:1:9, ...
            'LineWidth'         , .5)
    
        yyaxis right
        plot(RainfallDates, cumsum(GeneralRainData(PosSelRecStation,:)), 'k')
        ylabel('Cumulative [mm]', 'FontName',SelectedFont)
    
        daspect auto
        
        set(gca, ...
            'XLim'              , [min(RainfallDates), max(RainfallDates)], ...
            'YLim'              , [0 200], ...
            'Box'               , 'on', ...
            'TickDir'           , 'in', ...
            'TickLength'        , [.01 .01], ...
            'XMinorTick'        , 'off', ...
            'YMinorTick'        , 'off', ...
            'XGrid'             , 'off', ...
            'YGrid'             , 'off', ...
            'XColor'            , [0 0 0], ...
            'YColor'            , [0 0 0]./255, ...
            'XTick'             , RainfallDates(1):days(5):RainfallDates(end), ...
            'FontSize'          , 10, ...
            'FontName'          , SelectedFont, ...
            'YTick'             , 0:20:200, ...
            'LineWidth'         , .5)
    
        cd(fold_fig)
        exportgraphics(f1, strcat(filename1,'.png'), 'Resolution',600);
end