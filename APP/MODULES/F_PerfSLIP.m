if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Data Import
sl = filesep;

[InfDetExist, InfDet2Use] = load_info_detected(fold_var);
load([fold_var,sl,'GridCoordinates.mat'      ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea','IndexDTMPointsExcludedInStudyArea')
load([fold_var,sl,'MorphologyParameters.mat' ], 'SlopeAll')

%% Study area coordinates and slope angle
xLonStudy  = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy  = cellfun(@(x,y) x(y), yLatAll , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
SlopeStudy = cellfun(@(x,y) x(y), SlopeAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

%% Options
% Point where search for FP and TN
if not(all(cellfun(@isempty, IndexDTMPointsExcludedInStudyArea)))
    StabPtsOpts = {'Slope angle'
                   'Points outside det polygons'
                   'Excluded land use'};
else
    StabPtsOpts = {'Slope angle'
                   'Points outside det polygons'};
end

ROCMode = char(listdlg2({'Unconditionally stable area?'}, StabPtsOpts));

% Points of max area where search for TP and FN
SzDetROC = 100; % This is the size in meters around the detected soil slip

%% Main loop
NumROC = listdlg2({'How many ROC curves?'}, string(1:8), 'OutType','NumInd');
NumMinUnst = 1;

[AnlTPR, AnlTNR, AnlFPR, AnlFNR, ...
    AnlAUC, BstThr, AnlLbl, AnlTpe, ThrVls, IndSgPts] = deal(cell(1, NumROC));
for i1 = 1:NumROC
    %% Definition of analysis and area where calculate ROC Curve
    fold_crrAn = uigetdir(fold_res, ['Results folder for curve ',num2str(i1)]);
    [~, LbNmAn] = fileparts(fold_crrAn);

    Ind2Mnt = true(size(InfDet2Use, 1), 1);
    if numel(unique(InfDet2Use.Datetime)) > 1
        dts2Mnt = checkbox2(unique(InfDet2Use.Datetime), 'Title','Select datetimes of InfoDet:');
        Ind2Mnt = ismember(InfDet2Use.Datetime, dts2Mnt);
    end
    
    InfDetTemp = InfDet2Use(Ind2Mnt, :);
    
    TotPlyBROC = polybuffpoint2(InfDetTemp{:,{'Longitude','Latitude'}}, sqrt(2)*SzDetROC, coordType='geo', uniquePoly=true); % This is to create polygons that contains points for ROC curves. Other points are added with Ind2ndPrtPtROC
    
    [pBnd1, eBnd1] = getnan2([TotPlyBROC.Vertices; nan, nan]);
    Ind1stPrtPtROC = cellfun(@(x,y) find(inpoly([x,y], pBnd1, eBnd1)), xLonStudy, yLatStudy, 'UniformOutput',false);
    
    switch ROCMode
        case 'Slope angle'
            SlopeUncndStab = str2double(inputdlg2('Critical slope angle (below is stable)', {'10'}));
            Ind2ndPrtPtROC = cellfun(@(x) find(x < SlopeUncndStab), SlopeStudy, 'UniformOutput',false);
        case 'Points outside det polygons'
            Ind2ndPrtPtROC = cellfun(@(x) (1:length(x))', ...
                                               IndexDTMPointsInsideStudyArea, ...
                                               'UniformOutput',false);
        case 'Excluded land use'
            [~, Ind2ndPrtPtROC, ~] = cellfun(@(x,y) intersect(x,y), ...
                                                         IndexDTMPointsInsideStudyArea, ...
                                                         IndexDTMPointsExcludedInStudyArea, ...
                                                         'UniformOutput',false);
        otherwise
            error('ROCMode not recognized!')
    end
    
    % Union of first and second part 
    IndDTMPtsROC = cellfun(@(x,y) unique([x; y]), Ind1stPrtPtROC, Ind2ndPrtPtROC, 'UniformOutput',false);
    
    % Study area coordinates of point to analize with ROC Curve
    xLonROC = cellfun(@(x,y) x(y), xLonStudy, IndDTMPtsROC, 'UniformOutput',false);
    yLatROC = cellfun(@(x,y) x(y), yLatStudy, IndDTMPtsROC, 'UniformOutput',false);

    %% Importing results of FS
    InptsCurve = inputdlg2({'Analysis label:', ...
                            'Procedure (1 -> individual points, 2 -> points in radius)', ...
                            ['Unstable radius (max ',num2str(SzDetROC),')'], ...
                            'Min number of unstable in radius (procedure 2):'}, 'DefInp',{LbNmAn, '1', '30', '1'});

    AnlLbl(i1) = InptsCurve(1);
    UnstProced = str2double(InptsCurve{2});
    SrchRadius = str2double(InptsCurve{3});
    MinUnstab  = str2double(InptsCurve{4});

    if SrchRadius > SzDetROC
        error(['Unstable radius must be <= ',num2str(SzDetROC)])
    end
    
    [UnstProb, SignThrs, ...
        AnlTpe{i1}, LimFS] = load_fs2probs(fold_crrAn, IndexDTMPointsInsideStudyArea, ...
                                                                    subIndices=IndDTMPtsROC);

    SignThrs = min(SignThrs, 1);
    
    %% Performance curve (ROC)
    SepPlys4RP = polybuffpoint2(InfDetTemp{:,{'Longitude','Latitude'}}, SrchRadius, coordType='geo', uniquePoly=false);

    [AnlFPR{i1}, AnlTPR{i1}, ThrVls{i1}, ...
        AnlAUC{i1}, IndMax, IndSgPts{i1}] = perfcurve_polygon(UnstProb, [xLonROC; yLatROC], ...
                                                              SepPlys4RP, significantThr=SignThrs, ...
                                                                          unstApproach=UnstProced, minUnstable=MinUnstab, ...
                                                                          curveType='roc', progDialog=ProgressBar);

    switch AnlTpe{i1}
        case "Slip"
            MinFS = LimFS(1); MaxFS = LimFS(2);
            BstThr{i1} = (1-ThrVls{i1}(IndMax))*(MaxFS-MinFS) + MinFS;

        case {"ML", "Hybrid"}
            BstThr{i1} = ThrVls{i1}(IndMax);

        otherwise
            error('Analysis type not recognized!')
    end
end

%% Saving...
ProgressBar.Message = 'Saving...';

VarsROC = {'AnlLbl', 'AnlFPR', 'AnlTPR', 'BstThr', 'AnlAUC', 'ThrVls', 'AnlTpe'};
save([fold_res,sl,'PerfCurveSLIP.mat'], VarsROC{:})