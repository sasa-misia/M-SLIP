if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% Loading
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon')
load([fold_var,sl,'GridCoordinates.mat'   ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'GeneralRainfall.mat'   ], 'Gauges','RecDatesEndCommon','GeneralData','GenDataProps')

GnData = GeneralData{1};
if not(isscalar(GenDataProps))
    IdRain = listdlg2('Select property with cumulative rainfall:', GenDataProps, 'OutType','NumInd');
    GnData = GeneralData{IdRain};
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

            EvsIntp = RecDatesEndCommon(IndexInterpolation);
            IndPlot = checkbox2(string(EvsIntp), 'Title',{'Select datetime to plot:'}, 'OutType','NumInd');

        elseif RainFallType == 0
            load([fold_var,sl,'RainInterpolated.mat'], 'SelectedHoursRun')

            ForecastRunUnique = unique([SelectedHoursRun{:,2}]);
        
            IndexForecastInterpolated = cell(1, length(ForecastRunUnique));
            for i1 = 1:length(ForecastRunUnique)
                IndexForecastRun = cellfun(@(x) x==ForecastRunUnique(i1), SelectedHoursRun(:,2));
                IndexForecastInterpolated{i1} = unique([SelectedHoursRun{IndexForecastRun,1}]);
            end
    
            RunInt = string(ForecastData(ForecastRunUnique));
            ChoiceRunTime = listdlg2({'Select the run time of the forcast model :'}, RunInt, 'OutType','NumInd');
            RunSel  = datetime(RunInt(ChoiceRunTime), 'Format','dd/MM/yyyy HH');
            RunSel  = cellfun(@(x) x==RunSel, ForecastData(:,1));
            RunSel1 = find(RunSel);
    
            EvsIntp = [ForecastData{RunSel,2}(IndexForecastInterpolated{(ForecastRunUnique==RunSel1)})];
        
            IndPlot = checkbox2(string(EvsIntp), 'Title',{'Select interpolated rainfall:'}, 'OutType','NumInd');
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
                RainSel = RainInterpolated(IndPlot(iFig),:);
                DatStSl = GnData((IndPlot(iFig) + IndexInterpolation(1) - 1), :);
                RainEvt = replace( [char(EvsIntp(IndPlot(iFig))),' Rec'], {':', '/', '\'}, '-' );
    
                % clear('RainInterpolated')
            
            elseif RainFallType == 0
                load([fold_var_rain_for,sl,'RainForecastInterpolated',num2str(RunSel1),'.mat'], 'RainForecastInterpolated');
            
                RainSel = RainForecastInterpolated(IndPlot(iFig),:);
                RainEvt = replace( [char(EvsIntp(IndPlot(iFig))),' For'], {':', '/', '\'}, '-' );
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
            
            [xLonStudy, yLatStudy, RainStudy] = deal(cell(size(xLongAll)));
            RainRanges = cell(size(ColorRain,1), length(xLongAll));
            for i1 = 1:size(RainRanges,2)
                xLonStudy{i1} = xLongAll{i1}(IndexDTMPointsInsideStudyArea{i1});
                yLatStudy{i1} = yLatAll{i1}(IndexDTMPointsInsideStudyArea{i1});
                % RainStudy{i1} = RainSelected{i1}(IndexDTMPointsInsideStudyArea{i1});
                
                RainRanges{1  ,i1} = find(RainSel{i1}<=RainRangeVal(1));
                RainRanges{end,i1} = find(RainSel{i1}>=RainRangeVal(6));
                for i2 = 2:(size(RainRanges,1) - 1)
                    RainRanges{i2, i1} = find(RainSel{i1}>RainRangeVal(i2-1) & RainSel{i1}<=RainRangeVal(i2));
                end
            end
            
            ProgressBar.Message = 'Plotting...';
    
            CurrFln1 = ['Rain ',RainEvt];
            CurrFig1 = figure(1);
            CurrAxs1 = axes(CurrFig1);
    
            set(CurrFig1, 'Name',CurrFln1, 'Visible','off')
            set(CurrAxs1, 'Visible','off')
            hold(CurrAxs1,'on')
            
            for i2 = 1:size(xLongAll,2)
                hPlotRain = cellfun(@(x,y) scatter(xLonStudy{i2}(x), yLatStudy{i2}(x), PixelSize, 'o', ...
                                                            'MarkerFaceColor',y./255, 'MarkerEdgeColor','none'), ...
                                                RainRanges(:,i2), ColorRain, 'UniformOutput',false);
            end
    
            plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)
    
            fig_settings(fold0)
    
            if InfoDetExst
                hdetected = arrayfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDet2Use{:,5}, InfoDet2Use{:,6});
                uistack(hdetected,'top')
            end
            
            if exist('LegPos', 'var')
                LegObjs = hPlotRain;
                LegCaps = {'< 1', '1 - 1.5', '1.5 - 2', '2 - 2.5', '2.5 - 3', '3 - 4', '> 4'};
    
                if InfoDetExst
                    LegObjs = [LegObjs; {hdetected(1)}];
                    LegCaps = [LegCaps, {"Points Analyzed"}];
                end
        
                hleg = legend([LegObjs{:}], LegCaps, 'NumColumns',2, ...
                                                     'FontName',SlFont, ...
                                                     'Location',LegPos, ...
                                                     'FontSize',SlFnSz, ...
                                                     'Box','off');
        
                hleg.ItemTokenSize(1) = 10;
                
                legend('AutoUpdate','off');
                
                title(hleg, 'Rain [mm]', 'FontName',SlFont, ...
                            'FontSize',SlFnSz*1.2, 'FontWeight','bold')
    
                fig_rescaler(CurrFig1, hleg, LegPos)
            end
    
            exportgraphics(CurrFig1, [fold_fig,sl,CurrFln1,'.png'], 'Resolution',600);
    
            if ShowPlots; set(CurrFig1, 'visible','on'); else; close(CurrFig1); end
    
            % ---- Plot of Rain Gauges positions ----
            if RainFallType == 1
                CurrFln2 = ['RainGauges ',RainEvt];
                CurrFig2 = figure(2);
                CurrAxs2 = axes(CurrFig2);
                
                set(CurrFig2, 'Name',CurrFln2, 'Visible','off');
                set(CurrAxs2, 'Visible','off')
                hold(CurrAxs2,'on')
                
                scatter(Gauges{2}(:,1), Gauges{2}(:,2), '*k')
    
                plot(StudyAreaPolygon, 'LineWidth',1, 'FaceColor',[255 64 64]./255, ...
                                       'EdgeColor',[179 40 33]./255, 'FaceAlpha',0.3);
                
                for i1 = 1:size(DatStSl, 2)
                    text(Gauges{2}(i1,1)+.01, Gauges{2}(i1,2), ...
                            [char(Gauges{1}(i1)),' (',num2str(DatStSl(:, i1)),' mm)'], ...
                                                 'FontName',SlFont, 'FontSize',SlFnSz)
                end
                
                fig_settings(fold0)
        
                exportgraphics(CurrFig2, [fold_fig,sl,CurrFln2,'.png'], 'Resolution',600);
    
                if ShowPlots; set(CurrFig2, 'visible','on'); else; close(CurrFig2); end
            end
    
        case 2
            %% For RainFallType 2
            ProgressBar.Message = 'Plotting...';
    
            SelRecSta = char(listdlg2({'Select the recording station :'}, Gauges{1}));
            IndRecSta = find( arrayfun(@(x) strcmp(x,SelRecSta), Gauges{1}) );
        
            CurrFln1 = ['RecordedRainfall',SelRecSta];
            CurrFig1 = figure(1);
    
            set(CurrFig1, 'Name',CurrFln1, 'Visible','off')
    
            yyaxis left
            bar(RecDatesEndCommon, GnData(:, IndRecSta), 'FaceColor',[0 127 255]./255);
            ylabel('{\it h_w} [mm]', 'FontName',SlFont)
        
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
                'FontSize'          , SlFnSz, ...
                'FontName'          , SlFont, ...
                'YTick'             , 0:1:9, ...
                'LineWidth'         , .5)
        
            yyaxis right
            plot(RecDatesEndCommon, cumsum(GnData(:, IndRecSta)), 'k')
            ylabel('Cumulative [mm]', 'FontName',SlFont)
        
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
                'FontName'          , SlFont, ...
                'YTick'             , 0:20:200, ...
                'LineWidth'         , .5)
        
            exportgraphics(CurrFig1, [fold_fig,sl,CurrFln1,'.png'], 'Resolution',600);
    
            if ShowPlots; set(CurrFig1, 'visible','on'); else; close(CurrFig1); end
    end
end