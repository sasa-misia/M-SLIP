if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading files
sl = filesep;

fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your ML analysis folder');
fold_raw_sat_txt = [fold_raw_sat,sl,'UrlMap.txt'];

load([fold_var,sl,'StudyAreaVariables.mat'      ], 'MaxExtremes','MinExtremes')
load([fold_var,sl,'DatasetStudy.mat'            ], 'DatasetStudyCoords')
load([fold_res_ml_curr,sl,'PredictionsStudy.mat'], 'LandPolys','PredProbs', ...
                                                   'EventsInfo','PredPlyRt')

if not(exist('LandPolys', 'var'))
    error(['In creating prediction you must select landslide ' ...
           'polygons, otherwise you can not use this script!'])
end

PltOpts = checkbox2({'Show plot', 'Ortophoto', 'Info detected', ...
                     'Use classes'}, 'DefInp',[0, 1, 1, 1], 'OutType','LogInd');
ShowPlt = PltOpts(1);
ShowOrt = PltOpts(2);
ShowIfD = PltOpts(3);
UseClss = PltOpts(4);

% If you want to implement the following lines you have to create new
% variables with elements equal to the number of polygons!!
% if ShowOrt && exist([fold_var,sl,'Orthophoto.mat'], 'file')
%     load([fold_var,sl,'Orthophoto.mat'], 'ZOrtho','xLongOrtho','yLatOrtho')
% end

if ShowIfD && exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDet2U = InfoDetectedSoilSlips{IndDefInfoDet};
    DetCoords = InfoDet2U{:,5:6};
else
    ShowIfD = false;
end

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SelFnt = Font;
    SelFSz = FontSize;
    if exist('LegendPosition', 'var')
        LegPos = LegendPosition;
    end
else
    SelFnt = 'Times New Roman';
    SelFSz = 8;
    LegPos = 'Best';
end

%% Options
ProgressBar.Message = 'Options...';

EvsNms = EventsInfo.Properties.VariableNames;
DtsTmp = [EventsInfo{'PredictionDate',:}{:}];
EvsLbl = strcat(EvsNms, '--', string(DtsTmp));
IndDts = checkbox2(EvsLbl, 'Title',{'Dates to plot:'}, 'OutType','NumInd');

if numel(IndDts) > 5 || numel(IndDts) < 1
    error('Date selection must be at least 1 and maximum 5 days!')
end

FigDts = cellstr(datetime(DtsTmp(IndDts), 'format','MMM d y'));
LndPly = LandPolys(IndDts,:);
EvsSlt = EvsNms(IndDts);
PrdPrb = PredProbs(IndDts,:); % Must have a single column (adjustment below)
EvsThr = cell2mat(PredPlyRt.ThrUsed{IndDts,:}); % Must have a single row

MdlUsd = PrdPrb.Properties.VariableNames;
if numel(MdlUsd) > 1
    IndMdl = listdlg2({'Model to use:'}, MdlUsd, 'OutType','NumInd');
    MdlUsd = MdlUsd(IndMdl);
    PrdPrb = PrdPrb(:,MdlUsd);
    EvsThr = EvsThr(:,MdlUsd);
end

if not(isvector(EvsThr)); error('EvsThr must be a vector!'); end

if not(UseClss)
    MaxClr = 256;
    ClrMap = listdlg2('Colormap to use?', {'pink','turbo','cool'}, 'DefInp',2);
end

%% Checks and indexing of points
for i1 = 1:numel(PrdPrb)
    if numel(PrdPrb{i1,1}{:}) ~= size(DatasetStudyCoords, 1)
        error(['Event ',EvsSlt{i1},' of ',FigDts{i1},' was not predicted ' ...
               'with the current dataset coordinates! Create the same ' ...
               'DatasetStudy or do not use this event.'])
    end
end

UnstPolys = LndPly{EvsSlt, 'UnstablePolygons'};
CheckEqUn = all(cellfun(@(x) isequal(UnstPolys{1}, x), UnstPolys));

StabPolys = LndPly{EvsSlt, 'StablePolygons'};
CheckEqSt = all(cellfun(@(x) isequal(StabPolys{1}, x), StabPolys));

if CheckEqSt && CheckEqUn
    UnstPolys = UnstPolys{1};
    StabPolys = StabPolys{1};
else
    error('You have selected events with different polygons!')
end

% Indices of landslide polygons points
[IndUnstPnts, IndStabPnts] = deal(cell(size(UnstPolys)));
for i1 = 1:numel(UnstPolys)
    [pp1, ee1] = getnan2([UnstPolys(i1).Vertices; nan, nan]);
    IndUnstPnts{i1} = find(inpoly([DatasetStudyCoords.Longitude,DatasetStudyCoords.Latitude], pp1,ee1));

    [pp2, ee2] = getnan2([StabPolys(i1).Vertices; nan, nan]);
    IndStabPnts{i1} = find(inpoly([DatasetStudyCoords.Longitude,DatasetStudyCoords.Latitude], pp2,ee2));
end

% Creation of folder
if UseClss; FldTxt = 'Class'; else; FldTxt = 'Probs'; end
[~, rel_fold_res_ml_curr] = fileparts(fold_res_ml_curr);
CurrRelPltDir = [fold_fig,sl,rel_fold_res_ml_curr,'_PolyPreds_',FldTxt];
if not(exist(CurrRelPltDir, 'dir'))
    mkdir(CurrRelPltDir)
end

%% Polygons
[ExtContour, ExtlCoords] = deal(cell(1, numel(UnstPolys)));
for i1 = 1:numel(UnstPolys)
    ExtContour{i1} = rmholes(StabPolys(i1));

    [ppExt, eeExt] = getnan2([ExtContour{i1}.Vertices; nan, nan]);

    ExtlCoords{i1} = [ min(ppExt(:,1)), min(ppExt(:,2));
                       max(ppExt(:,1)), min(ppExt(:,2));
                       max(ppExt(:,1)), max(ppExt(:,2));
                       min(ppExt(:,1)), max(ppExt(:,2)) ];
end

%% Ortophoto check
if ShowOrt && not(exist('ZOrtho', 'var'))
    [ZOrtho, xLongOrtho, yLatOrtho] = deal(cell(1, numel(UnstPolys)));
    for i1 = 1:numel(UnstPolys)
        LonLimits = [min(ExtlCoords{i1}(:,1)), max(ExtlCoords{i1}(:,1))];
        LatLimits = [min(ExtlCoords{i1}(:,2)), max(ExtlCoords{i1}(:,2))];
    
        [ZOrtho{i1}, xLongOrtho{i1}, yLatOrtho{i1}] = readortophoto(fold_raw_sat_txt, LonLimits, LatLimits, Resolution=2048);
    end
end

%% Core
for i1 = 1:numel(UnstPolys)    
    CurrDtExst = false;
    if ShowIfD
        IndCurrDet = find(inpoly(DetCoords, ppExt, eeExt));
        if isempty(IndCurrDet)
            warning(['There are no detected soil slips in ' ...
                     'landslide polygon n. ',num2str(i1)])
        else
            CurrDtCrds = DetCoords(IndCurrDet, :);
            CurrDtExst = true;
        end
    end

    EvNumPrt = extract(EvsSlt, digitsPattern);
    if numel(unique(EvNumPrt)) ~= numel(EvNumPrt)
        error(['Numerical parts of event names are not unique! ', ...
               'You can not create an ID for the figure! Contact support.'])
    end

    ScrnSzs = get(0, 'ScreenSize');
    CurrIDn = strjoin(EvNumPrt, '-');
    CurrNme = ['Pred_LP',num2str(i1),'_Ev',CurrIDn];
    CurrFig = figure(i1);

    CurrFSz = CurrFig.Position;
    NmSubBx = numel(FigDts);
    if exist('LegPos', 'var')
        NmSubBx = NmSubBx+1; % +1 because of legend!
    end
    WidthSz = 300*NmSubBx;
    HeighSz = 350;
    CurrFSz = max(1, [(ScrnSzs(3)-WidthSz)/2, (ScrnSzs(4)-HeighSz)/2, WidthSz, HeighSz]);

    set(CurrFig, 'Name',CurrNme, 'Visible','off', 'Position',CurrFSz);

    for i2 = 1:numel(FigDts)
        CurrAxs = subplot(1, NmSubBx, i2);
        hold(CurrAxs, 'on')

        %% Coordinates and probabilities
        CoordStArPnts = DatasetStudyCoords{IndStabPnts{i1},:};
        CoordUnArPnts = DatasetStudyCoords{IndUnstPnts{i1},:};
        
        CoordStArPrbs = full(PrdPrb{i2,MdlUsd}{:}(IndStabPnts{i1}));
        CoordUnArPrbs = full(PrdPrb{i2,MdlUsd}{:}(IndUnstPnts{i1})); % These are probabilities of having landslide!
        
        CoordStArClTU = CoordStArPrbs >= EvsThr(i2);
        CoordUnArClTU = CoordUnArPrbs >= EvsThr(i2);
    
        %% Orthophoto    
        if ShowOrt
            fastscattergrid(ZOrtho{i1}, xLongOrtho{i1}, yLatOrtho{i1}, 'Mask',ExtContour{i1}, 'Parent',CurrAxs);
        end
    
        %% Print        
        plot(StabPolys(i1), 'EdgeColor','#00B050', 'FaceColor',"none", 'LineWidth',1, 'LineStyle','-')
        plot(UnstPolys(i1), 'EdgeColor','#C00000', 'FaceColor',"none", 'LineWidth',1, 'LineStyle','-')
        
        if UseClss
            StabPntsInStAr = scatter(CoordStArPnts(not(CoordStArClTU),1), ...
                                     CoordStArPnts(not(CoordStArClTU),2), 5, ...
                                               'Marker','o', 'MarkerFaceColor',"#92D050", ...
                                               'MarkerEdgeColor','none','MarkerFaceAlpha',1, 'Parent',CurrAxs);
    
            UnstPntsInStAr = scatter(CoordStArPnts(CoordStArClTU,1), ...
                                     CoordStArPnts(CoordStArClTU,2), 5, ...
                                               'Marker','o', 'MarkerFaceColor',"#FF0000", ...
                                               'MarkerEdgeColor','none','MarkerFaceAlpha',1, 'Parent',CurrAxs);
            
            StabPntsInUnAr = scatter(CoordUnArPnts(not(CoordUnArClTU),1), ...
                                     CoordUnArPnts(not(CoordUnArClTU),2), 5, ...
                                               'Marker','o', 'MarkerFaceColor',"#92D050", ...
                                               'MarkerEdgeColor','none','MarkerFaceAlpha',1, 'Parent',CurrAxs);
            
            UnstPntsInUnAr = scatter(CoordUnArPnts(CoordUnArClTU,1), ...
                                     CoordUnArPnts(CoordUnArClTU,2), 5, ...
                                               'Marker','o', 'MarkerFaceColor',"#FF0000", ...
                                               'MarkerEdgeColor','none','MarkerFaceAlpha',1, 'Parent',CurrAxs);
            
        else
            PossClrs = eval([ClrMap,'(MaxClrPltt);']);
            if strcmp(ClrMap,'pink')
                PossClrs = flipud(PossClrs);
            end

            IndClrStAr = max(ceil(CoordStArPrbs*MaxClr), 1);
            IndClrUnAr = max(ceil(CoordUnArPrbs*MaxClr), 1);
            StArClrPlt = PossClrs(IndClrStAr,:);
            UnArClrPlt = PossClrs(IndClrUnAr,:);

            ResPntsInStAr = scatter(CoordStArPnts(:,1), CoordStArPnts(:,2), 5, ...
                                    StArClrPlt, 'Marker','o', 'MarkerEdgeColor','none', ...
                                                'MarkerFaceAlpha',1, 'MarkerFaceColor','flat', 'Parent',CurrAxs);
            ResPntsInUnAr = scatter(CoordUnArPnts(:,1), CoordUnArPnts(:,2), 5, ...
                                    UnArClrPlt, 'Marker','o', 'MarkerEdgeColor','none', ...
                                                'MarkerFaceAlpha',1, 'MarkerFaceColor','flat', 'Parent',CurrAxs);
        end
        
        if ShowIfD && not(isempty(IndCurrDet))
            hdetected = arrayfun(@(x,y) scatter(x, y, 30, '^k','Filled', 'Parent',CurrAxs), CurrDtCrds(:,1), CurrDtCrds(:,2));
        end

        % Put pred points on top
        if UseClss
            uistack(StabPntsInStAr,'top')
            uistack(UnstPntsInStAr,'top')
            uistack(StabPntsInUnAr,'top')
            uistack(UnstPntsInUnAr,'top')

        else
            uistack(ResPntsInStAr,'top')
            uistack(ResPntsInUnAr,'top')
        end

        %% Resizing and formatting
        fig_settings(fold0, 'SetExtremes',ExtlCoords{i1})

        title(CurrAxs, FigDts{i2})
        
        set(CurrAxs, 'FontName',SelFnt, ...
                     'Box','on', ...
                     'TickLength',[0 0], ...
                     'XTickLabel',[], ...
                     'YTickLabel',[], ...
                     'XLim',[ExtlCoords{i1}(1,1), ExtlCoords{i1}(2,1)], ...
                     'YLim',[ExtlCoords{i1}(1,2), ExtlCoords{i1}(3,2)])
    end

    % Plot legend
    if exist('LegPos', 'var') && UseClss
        CurrAxs = subplot(1, NmSubBx, NmSubBx);

        LegendObjects = {StabPntsInStAr(1), UnstPntsInStAr(1)};
        LegendCaption = {"Not landslide", "Landslide"};
    
        if ShowIfD && not(isempty(IndCurrDet))
            LegendObjects = [LegendObjects, {hdetected(1)}];
            LegendCaption = [LegendCaption, {"Detected Landslide Points"}];
        end

        hleg1 = legend([LegendObjects{:}], LegendCaption, ...
                       'FontName',SelFnt, ...
                       'FontSize',SelFSz, ...
                       'Location','south'); % LegPos);
        
        hleg1.ItemTokenSize(1) = 3;

        title(hleg1, 'Classification')

        set(CurrAxs, 'FontName',SelFnt, 'Box','off', 'Visible','off')

        CurrAxsPos = CurrAxs.Position;
        CurrLegPos = hleg1.Position;
        delete(CurrAxs)

        hleg1.Position(1:2) = CurrAxsPos(1:2) + [0, CurrAxsPos(4)/2-CurrLegPos(4)/2];
        
        % fig_rescaler(CurrFig, hleg1, LegPos)
    end

    exportgraphics(CurrFig, [CurrRelPltDir,sl,CurrNme,'.png'], 'Resolution',400);

    % Show Fig
    if ShowPlt
        set(CurrFig, 'visible','on');
    else
        close(CurrFig)
    end
end