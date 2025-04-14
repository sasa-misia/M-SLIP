if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon','MaxExtremes','MinExtremes','MunPolygon')
load([fold_var,sl,'UserMorph_Answers.mat'],  'NewDx')
load([fold_var,sl,'DatasetStudy.mat'],       'DatasetStudyCoords')

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');
load([fold_res_ml_curr,sl,'PredictionsStudy.mat'], 'PredProbs','LandPolys', ...
                                                   'EventsInfo','EventsPerf')
load([fold_res_ml_curr,sl,'MLMdlB.mat'          ], 'MLMdl','MLPerf')

[~, AnalFold] = fileparts(fold_res_ml_curr);
fold_fig_curr = [fold_fig,sl,'Susceptibility maps',sl,AnalFold];

%% Options
PrdOpts = checkbox2({'Plot filter', 'Show plots', 'Use FS (experimental)'}, 'OutType','LogInd');
FiltMdl = PrdOpts(1);
ShowPlt = PrdOpts(2);
UseFs2P = PrdOpts(3); % It is experimental and temporary, please fix that part!

DatePred = [EventsInfo{'PredictionDate',:}{:}];
if isscalar(DatePred)
    Date2Use = {DatePred};
    EvNm2Use = {EventsInfo.Properties.VariableNames};
else
    IndSelDt = checkbox2(DatePred, 'Title',{'Datetime to plot:'}, 'OutType','NumInd');
    Date2Use = num2cell(DatePred(IndSelDt));
    EvNm2Use = num2cell(EventsInfo.Properties.VariableNames(IndSelDt));
end

TestMSE = MLPerf{'Err','Test'}{:}{'MSE',:};
GoodMdl = true(size(TestMSE));
if FiltMdl
    MaxLoss = str2double(inputdlg2({['Max MSE filter (max: ',num2str(max(TestMSE)), ...
                                     '; min: ',num2str(min(TestMSE))]}, 'DefInp',{num2str(min(TestMSE)*5)}));
    GoodMdl = TestMSE <= MaxLoss;
end

IndMdl = checkbox2(PredProbs.Properties.VariableNames, 'Title','Model to plot', ...
                                'DefInp',true(size(PredProbs.Properties.VariableNames)), 'OutType','NumInd');
IndMdl = reshape(IndMdl, 1, numel(IndMdl));

TrnVal = inputdlg2({'Polygons transparency [0 - 1]:', 'Results transparency [0 - 1]:'}, 'DefInp',{'0.35', '0.8'});
PlyTrn = str2double(TrnVal{1});
ResTrn = str2double(TrnVal{2});

ClrBar = 'pink';

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'RefArea',.035, 'Extremes',true);

%% Replacement of results with FS analyses
if UseFs2P
    load([fold_var,sl,'GridCoordinates.mat'], 'IndexDTMPointsInsideStudyArea')

    PredProbs{:,:} = cell(size(PredProbs)); % Predictions are now empty!

    ContFsF = dir(fold_res_fs);
    ListFld = {ContFsF.name};
    IsDirLs = [ContFsF.isdir]; IsDirLs(1:2) = false;
    Flds2Ld = checkbox2(ListFld(IsDirLs), 'Title','Folders to use:');

    for i1 = 1:numel(Flds2Ld)
        fold_res_fs_curr = [fold_res_fs,sl,Flds2Ld{i1}];
        load([fold_res_fs_curr,sl,'AnalysisInformation.mat'], 'StabilityAnalysis')
        for i2 = 1:StabilityAnalysis{1}
            [TempUnstPrb, ~, TempAnlType, ~, TempAnlDate] = load_fs2probs(fold_res_fs_curr, IndexDTMPointsInsideStudyArea, indAn2Load=i2);
            [MinDiff, Ind2Wrt] = min(abs(hours([EventsInfo{'PredictionDate',:}{:}] - TempAnlDate)));
            if not(isscalar(Ind2Wrt)); error('Ind2Wrt must be scalar!'); end
            if MinDiff > 12
                warning('More than 72h of difference, this event will be skipped!')
            else
                if isempty(PredProbs{Ind2Wrt, 1}{:})
                    PredProbs{Ind2Wrt, :} = repmat({single(round(cat(1, TempUnstPrb{:}), 2))}, 1, size(PredProbs, 2));
                else
                    error('This event was already written!')
                end
            end
        end
    end

    switch lower(TempAnlType)
        case 'hybrid'
            ExpLabl = 'Hybrid';

        case 'slip'
            ExpLabl = 'SLIP';

        otherwise
            error('Fs analysis not recognized!')
    end

    fold_fig_curr = [fold_fig,sl,'Susceptibility maps',sl,ExpLabl];
end

%% New grid
GridSize = NewDx; % In meters
yLatMean = (MaxExtremes(2)+MinExtremes(2))/2;

dLat = rad2deg(GridSize/earthRadius); % 1 m in lat
dLon = rad2deg(acos( (cos(GridSize/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long

yRows = MaxExtremes(2) : -dLat : MinExtremes(2);
xCols = MinExtremes(1) :  dLon : MaxExtremes(1);

[xLonNew, yLatNew] = meshgrid(xCols, yRows);

ProbsGrid = zeros(size(xLonNew));

[pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
IndsInStudy = inpoly([xLonNew(:), yLatNew(:)], pp1, ee1);

%% Plot
if not(exist(fold_fig_curr, 'dir'))
    mkdir(fold_fig_curr)
end

for iF = 1:numel(EvNm2Use)
    LandsDay = LandPolys{EvNm2Use{iF}, 'LandslideDay'}{:};
    UnstPoly = LandPolys{EvNm2Use{iF}, 'UnstablePolygons'}{:};
    StabPoly = LandPolys{EvNm2Use{iF}, 'StablePolygons'}{:};
    if length(UnstPoly) > 1
        UnstPoly = union(UnstPoly);
    end
    if length(StabPoly) > 1
        StabPoly = union(StabPoly);
    end
    
    StabColor = '#7FFF00';
    if LandsDay
        UnstColor = '#CC5500';
    else
        UnstColor = StabColor;
    end
    
    for i1 = IndMdl
        ProgressBar.Message = ['Plotting fig. ',num2str(iF),' of ',num2str(numel(EvNm2Use)),' (Mdl ',num2str(i1),')'];
    
        if isempty(PredProbs{EvNm2Use{iF}, i1}{:}) || not(GoodMdl(i1))
            continue % To skip the cycle in case there are no predictions
        end
    
        CurrFig = figure('Visible','off');
        CurrAxs = axes(CurrFig, 'FontName',SlFont);
        hold(CurrAxs,'on')
    
        EvntStr = strrep(char(Date2Use{iF}), '/', ' ');
        EvntStr = strrep(EvntStr, ':', ' ');
        CurrFln = ['SuscMap_',EvntStr,'_ANN-Mdl-',num2str(i1)];
    
        CurrentMSE = EventsPerf.MSE{EvNm2Use{iF},i1};
        CurrentAUC = EventsPerf.AUROC{EvNm2Use{iF},i1};
        LayerStrct = MLMdl{'Model',i1}{:}.LayerSizes;
    
        ProbsScatt = double(full(PredProbs{EvNm2Use{iF}, i1}{:}));
    
        ProbsFunct = scatteredInterpolant(DatasetStudyCoords.Longitude, DatasetStudyCoords.Latitude, ProbsScatt, 'nearest');
    
        ProbsGrid(:) = min(max( ProbsFunct(xLonNew(:), yLatNew(:)), 0), 1);
    
        ProbsGrid(not(IndsInStudy)) = 0;
    
        fastscattergrid(ProbsGrid(:), xLonNew, yLatNew, Parent=CurrAxs, Alpha=ResTrn, ColorMap=ClrBar);

        plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1 , 'Parent',CurrAxs)
        plot(MunPolygon      , 'FaceColor','none', 'LineWidth',.6, 'Parent',CurrAxs)
    
        plot(UnstPoly, 'FaceColor',UnstColor, 'FaceAlpha',PlyTrn, 'LineWidth',2*PixelSize, 'Parent',CurrAxs)
        plot(StabPoly, 'FaceColor',StabColor, 'FaceAlpha',PlyTrn, 'LineWidth',2*PixelSize, 'Parent',CurrAxs)

        fig_settings(fold0)

        SubStr = ['ANN Struct: [',strjoin({num2str(LayerStrct)}),']']; % ['Event MSE: ',num2str(CurrentMSE),'; Event AUC: ',num2str(CurrentAUC),'; ANN Struct: [',strjoin({num2str(LayerStrct)}),']'];
        if UseFs2P; SubStr = ExpLabl; CurrFln = ['SuscMap_',EvntStr,'_',ExpLabl]; end
        title('Sesceptibility map', 'FontName',SlFont, 'FontSize',SlFnSz)
        subtitle(SubStr, 'FontName',SlFont, 'FontSize',.8*SlFnSz)
    
        ClrBarLims = [0, 1];
        TickValues = [0, 0.2, 0.5, 0.8, 1];
        TickLabels = ["Low susc.", ...
                      "Med. low susc.", ...
                      "Med. susc.", ...
                      "Med. high susc.", ...
                      "High susc."];
    
        colormap(CurrAxs, flipud(colormap(ClrBar)))
    
        clim(ClrBarLims);
        ColBar = colorbar('Location','eastoutside', 'Ticks',TickValues, 'TickLabels',TickLabels, 'FontName',SlFont, 'FontSize',.7*SlFnSz);
        ColPos = get(ColBar,'Position');
        ColPos(3) = ColPos(3)*.5;
        ColPos(4) = ColPos(4)*.6;
        ColPos(1) = ColPos(1)+.07;
        ColPos(2) = ColPos(2)+.08;
        set(ColBar, 'Position',ColPos)
    
        axis off
        % set(CurrAxs, 'Visible','off')
        % set(findall(ax_curr, 'type', 'text'), 'visible', 'on') % To show again titles
    
        exportgraphics(CurrFig, [fold_fig_curr,sl,CurrFln,'.png'], 'Resolution',1200);
    
        % Showing plot and saving...
        if ShowPlt
            set(CurrFig, 'visible','on');
            pause
        end
    
        close(CurrFig)
    end
end