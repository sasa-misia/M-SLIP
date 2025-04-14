function ObjOut = check_plot_mdlb(ANNs, ANNsPrf, DsetTbl, Polys, SngPoly, PixlSz, SelDay, fold0)

arguments
    ANNs    (:,:) table
    ANNsPrf (:,:) table
    DsetTbl (:,:) table
    Polys   (1,3) cell
    SngPoly (1,:) logical = false
    PixlSz  (1,1) double = 30
    SelDay  (1,1) logical = false
    fold0   (1,:) char = pwd
end

UnstPolys = Polys{1};
IndePolys = Polys{2};
StabPolys = Polys{3};

PerfNms = ANNsPrf{'ROC','Test'}{:}.Properties.VariableNames;
ANNsNms = ANNs.Properties.VariableNames;
[~, BstMdl4Tst] = max(cell2mat(ANNsPrf{'ROC','Test'}{:}{'AUC',:}));
[~, BstMdl4Trn] = max(cell2mat(ANNsPrf{'ROC','Train'}{:}{'AUC',:}));
Mdl2Plt = listdlg2(['Model to use? (best test: ',PerfNms{BstMdl4Tst}, ...
                    '; best train: ',PerfNms{BstMdl4Trn},')'], ANNsNms, 'DefInp',BstMdl4Tst);

if SngPoly; SelDay = true; end

PltOpt = 1;
if SelDay
    PossDates = unique(DsetTbl{'Total', 'Dates'}{:}{:,'Datetime'});
    DateChdId = listdlg2('Event to plot:', PossDates, 'OutType','NumInd');
    DateChsed = PossDates(DateChdId);

    IdEv2Take = (DsetTbl{'Total', 'Dates'}{:}{:,'Datetime'} == DateChsed);

    LandsEvnt = all(DsetTbl{'Total', 'Dates'}{:}{:,'LandslideEvent'}(IdEv2Take));
    if LandsEvnt; PltOpt = 2; else; PltOpt = 3; end
end

BstThrTrn = ANNsPrf{'ROC','Train'}{:}{'BestThreshold',Mdl2Plt}{:};
BstThrTst = ANNsPrf{'ROC','Test' }{:}{'BestThreshold',Mdl2Plt}{:};

CurrMdl = ANNs{'Model',Mdl2Plt}{:};

switch PltOpt
    case 1
        PrdPrbsTrn = mdlpredict(CurrMdl, DsetTbl{'Train', 'Feats'}{:});
        PrdPrbsTst = mdlpredict(CurrMdl, DsetTbl{'Test' , 'Feats'}{:});
        PrdClTrnBT = PrdPrbsTrn >= BstThrTrn;
        PrdClTstBT = PrdPrbsTst >= BstThrTst;

    case {2, 3}
        PrdPrbSlEv = mdlpredict(CurrMdl, DsetTbl{'Total', 'Feats'}{:}(IdEv2Take,:));
        PrdClSelEv = PrdPrbSlEv >= (BstThrTrn + BstThrTst)/2;
end

switch PltOpt
    case {1, 2}
        UnstColor = '#d87e7e';
    case 3
        UnstColor = '#5aa06b';
end

yLatMean = mean(DsetTbl{'Total', 'Coordinates'}{:}.Latitude);
dLat1Met = rad2deg(1/earthRadius); % 1 m in lat
dLon1Met = rad2deg(acos( (cos(1/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % 1 m in long
RtLatLon = dLat1Met/dLon1Met;

if SngPoly
    StPlyFl = rmholes(StabPolys);
    if numel(UnstPolys) > 1
        if not(isequal(numel(UnstPolys), numel(IndePolys), numel(StabPolys)))
            error(['Number of polygons must be identical ', ...
                   'for unstable, indecision, and stable!'])
        end
        UnstPlysSplt = UnstPolys;
        IndePlysSplt = IndePolys;
        StabPlysSplt = StabPolys;
    else
        [StbPlyLonSp, ...
            StbPlyLatSp] = polysplit(StPlyFl.Vertices(:,1), StPlyFl.Vertices(:,2));
        SatbPlysSpGr = cellfun(@(x, y) polyshape(x, y), StbPlyLonSp, StbPlyLatSp, 'UniformOutput',false);
    
        StabPlysSplt = cellfun(@(x) intersect(x, StabPolys), SatbPlysSpGr);
        IndePlysSplt = cellfun(@(x) intersect(x, IndePolys), SatbPlysSpGr);
        UnstPlysSplt = cellfun(@(x) intersect(x, UnstPolys), SatbPlysSpGr);
    end
    
    IdxPntStab = cell(size(StabPlysSplt));
    for i1 = 1:numel(StabPlysSplt)
        [ppSt, eeSt] = getnan2([StabPlysSplt(i1).Vertices; nan, nan]);
        IdxPntStab{i1} = find(inpoly([DsetTbl{'Total', 'Coordinates'}{:}.Longitude, ...
                                      DsetTbl{'Total', 'Coordinates'}{:}.Latitude ], ppSt,eeSt));
    end

    IdxPntInde = cell(size(IndePlysSplt));
    for i1 = 1:numel(IndePlysSplt)
        [ppIn, eeIn] = getnan2([IndePlysSplt(i1).Vertices; nan, nan]);
        IdxPntInde{i1} = find(inpoly([DsetTbl{'Total', 'Coordinates'}{:}.Longitude, ...
                                      DsetTbl{'Total', 'Coordinates'}{:}.Latitude ], ppIn,eeIn));
    end

    IdxPntUnst = cell(size(UnstPlysSplt));
    for i1 = 1:numel(UnstPlysSplt)
        [ppUn, eeUn] = getnan2([UnstPlysSplt(i1).Vertices; nan, nan]);
        IdxPntUnst{i1} = find(inpoly([DsetTbl{'Total', 'Coordinates'}{:}.Longitude, ...
                                      DsetTbl{'Total', 'Coordinates'}{:}.Latitude ], ppUn,eeUn));
    end

    % Plot for check
    SelPly = listdlg2({'Polygon to plot?'}, string(1:numel(StabPlysSplt)), 'OutType','NumInd');

    xPntUnst = DsetTbl{'Total', 'Coordinates'}{:}{IdxPntUnst{SelPly}, 'Longitude'};
    yPntUnst = DsetTbl{'Total', 'Coordinates'}{:}{IdxPntUnst{SelPly}, 'Latitude' };

    xPntStab = DsetTbl{'Total', 'Coordinates'}{:}{IdxPntStab{SelPly}, 'Longitude'};
    yPntStab = DsetTbl{'Total', 'Coordinates'}{:}{IdxPntStab{SelPly}, 'Latitude' };

    xPntPred = DsetTbl{'Total', 'Coordinates'}{:}{IdEv2Take, 'Longitude'}(PrdClSelEv);
    yPntPred = DsetTbl{'Total', 'Coordinates'}{:}{IdEv2Take, 'Latitude' }(PrdClSelEv);

    [ppCr, eeCr] = getnan2([StPlyFl(SelPly).Vertices; nan, nan]);
    IdCurrPl = find(inpoly([xPntPred,yPntPred], ppCr,eeCr));

    xPntPred = xPntPred(IdCurrPl);
    yPntPred = yPntPred(IdCurrPl);

    FigChk = figure();
    AxsChk = axes(FigChk);
    hold(AxsChk,'on')

    plot(StabPlysSplt(SelPly), 'FaceAlpha',.5, 'FaceColor','#5aa06b', 'Parent',AxsChk);
    plot(IndePlysSplt(SelPly), 'FaceAlpha',.5, 'FaceColor','#fff2cc', 'Parent',AxsChk);
    plot(UnstPlysSplt(SelPly), 'FaceAlpha',.5, 'FaceColor',UnstColor, 'Parent',AxsChk);

    ObjPred{1} = scatter(xPntPred, yPntPred, PixlSz*2/3, 'Marker','s', 'MarkerFaceColor','#000000', ...
                                                         'MarkerEdgeColor','none', 'Parent',AxsChk);

    ObjReal{1} = scatter(xPntUnst, yPntUnst, PixlSz/4, 'Marker','hexagram', ...
                                        'MarkerFaceColor',"#ff0c01", 'MarkerEdgeColor','none', ...
                                        'MarkerFaceAlpha',0.5, 'Parent',AxsChk);
    
    ObjReal{2} = scatter(xPntStab, yPntStab, PixlSz/2, 'Marker','hexagram', ...
                                        'MarkerFaceColor',"#77AC30", 'MarkerEdgeColor','none', ...
                                        'MarkerFaceAlpha',0.5, 'Parent',AxsChk);

else
    [~, AxsChk] = check_plot(fold0);
    
    if length(UnstPolys) > 1
        UnstPolyMrgd = union(UnstPolys);
        IndePolyMrgd = union(IndePolys);
        StabPolyMrgd = union(StabPolys);
    else
        UnstPolyMrgd = UnstPolys;
        IndePolyMrgd = IndePolys;
        StabPolyMrgd = StabPolys;
    end
    
    plot(UnstPolyMrgd, 'FaceAlpha',.5, 'FaceColor',UnstColor, 'Parent',AxsChk);
    plot(IndePolyMrgd, 'FaceAlpha',.5, 'FaceColor','#fff2cc', 'Parent',AxsChk);
    plot(StabPolyMrgd, 'FaceAlpha',.5, 'FaceColor','#5aa06b', 'Parent',AxsChk);
    
    switch PltOpt
        case 1
            ObjPred{1} = scatter(DsetTbl{'Test', 'Coordinates'}{:}.Longitude(PrdClTstBT), ...
                                 DsetTbl{'Test', 'Coordinates'}{:}.Latitude(PrdClTstBT), PixlSz, 'Marker','d', 'MarkerFaceColor','#000000', ...
                                                                                                 'MarkerEdgeColor','none', 'Parent',AxsChk);
            
            ObjPred{2} = scatter(DsetTbl{'Train', 'Coordinates'}{:}.Longitude(PrdClTrnBT), ...
                           	     DsetTbl{'Train', 'Coordinates'}{:}.Latitude(PrdClTrnBT), PixlSz, 'Marker','s', 'MarkerFaceColor','#000000', ...
                                                                                                  'MarkerEdgeColor','none', 'Parent',AxsChk);
    
        case {2, 3}
            ObjPred{1} = scatter(DsetTbl{'Total', 'Coordinates'}{:}{IdEv2Take, 'Longitude'}(PrdClSelEv), ...
                                 DsetTbl{'Total', 'Coordinates'}{:}{IdEv2Take, 'Latitude' }(PrdClSelEv), ...
                                                                                    PixlSz, 'Marker','s', 'MarkerFaceColor','#000000', ...
                                                                                            'MarkerEdgeColor','none', 'Parent',AxsChk);
    end
    
    switch PltOpt
        case 1
            ExpcOuts = DsetTbl{'Total','ExpOuts'}{:};
    
            xPntUnst = DsetTbl{'Total', 'Coordinates'}{:}.Longitude(logical(ExpcOuts));
            yPntUnst = DsetTbl{'Total', 'Coordinates'}{:}.Latitude(logical(ExpcOuts));
    
            xPntStab = DsetTbl{'Total', 'Coordinates'}{:}.Longitude(not(logical(ExpcOuts)));
            yPntStab = DsetTbl{'Total', 'Coordinates'}{:}.Latitude(not(logical(ExpcOuts)));
    
        case {2, 3}
            ExOt4Plt = DsetTbl{'Total', 'ExpOuts'}{:}(IdEv2Take, :);
    
            xPntUnst = DsetTbl{'Total', 'Coordinates'}{:}{IdEv2Take, 'Longitude'}(logical(ExOt4Plt));
            yPntUnst = DsetTbl{'Total', 'Coordinates'}{:}{IdEv2Take, 'Latitude' }(logical(ExOt4Plt));
    
            xPntStab = DsetTbl{'Total', 'Coordinates'}{:}{IdEv2Take, 'Longitude'}(not(logical(ExOt4Plt)));
            yPntStab = DsetTbl{'Total', 'Coordinates'}{:}{IdEv2Take, 'Latitude' }(not(logical(ExOt4Plt)));
    end
    
    ObjReal{1} = scatter(xPntUnst, yPntUnst, PixlSz/4, 'Marker','hexagram', ...
                                        'MarkerFaceColor',"#ff0c01", 'MarkerEdgeColor','none', ...
                                        'MarkerFaceAlpha',0.5, 'Parent',AxsChk);
    
    ObjReal{2} = scatter(xPntStab, yPntStab, PixlSz/2, 'Marker','hexagram', ...
                                        'MarkerFaceColor',"#77AC30", 'MarkerEdgeColor','none', ...
                                        'MarkerFaceAlpha',0.5, 'Parent',AxsChk);
    
    switch PltOpt
        case 1
            title('Train and Test')
        case {2, 3}
            title(['Datetime: ',char(DateChsed)])
        otherwise
            error('Plot option not defined')
    end
end

daspect([1, RtLatLon, 1])

ObjOut = {ObjPred, ObjReal};

end