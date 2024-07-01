if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', ...
                                 'Message','Reading files...', 'Cancelable','off', ...
                                 'Indeterminate','on');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'],      'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll','AspectAngleAll','OriginallyProjected','SameCRSForAll')
load([fold_var,sl,'SoilParameters.mat'],       'PhiAll','CohesionAll')
load([fold_var,sl,'VegetationParameters.mat'], 'RootCohesionAll')
load([fold_var,sl,'UserMorph_Answers.mat'],    'OrthophotoAnswer')

if OrthophotoAnswer
    load([fold_var,sl,'Orthophoto.mat'], 'ZOrtho','xLongOrtho','yLatOrtho')
end

InfoDetectedExist = false;
if exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetectedExist = true;
end

InstDepth = 1.2;
if exist([fold_var,sl,'UserTimeSens_Answers.mat'], 'file')
    load([fold_var,sl,'UserTimeSens_Answers.mat'], 'H')
    InstDepth = H;
end

%% Options
ProgressBar.Message = 'Options...';

fold_an = uigetdir(fold_res_fs, 'Select analysis folder');
[~, FoldnameFS] = fileparts(fold_an);

figure(Fig)
drawnow

if exist([fold_an,sl,'AnalysisInformation.mat'], 'file')
    load([fold_an,sl,'AnalysisInformation.mat'], 'StabilityAnalysis');

    if strcmp(StabilityAnalysis{1, 4}, 'Slip')
        InstAnTp = 'SLIP';

        EvsAnlyz = string(StabilityAnalysis{:,2});
        IndEvFS  = listdlg2({'Event to plot:'}, EvsAnlyz, 'OutType','NumInd');
        EventFS  = datetime(EvsAnlyz(IndEvFS), 'InputFormat','dd/MM/yyyy HH:mm:ss');
        
        load([fold_an,sl,'Fs',num2str(IndEvFS),'.mat'], 'FactorSafety');

    elseif any(strcmp(StabilityAnalysis{1, 4}, 'Machine Learning'))
        InstAnTp = 'ML';
        error('Not implemented for ML!')

    else
        error('Instability analysis type not recognized in StabilityAnalysis file!')
    end

elseif exist([fold_an,sl,'TrainedANNs.mat'], 'file')
    InstAnTp = 'ANN';
    error('Not implemented for ANNs!')

else
    error('No info file recognized in your folder!')
end

SngGrdAns = uiconfirm(Fig, 'Do you want to merge all DEMs?', ...
                           'DEM Merge', 'Options',{'Yes', 'No, mantain separate'}, 'DefaultOption',2);
if strcmp(SngGrdAns,'Yes'); SngGrid = true; else; SngGrid = false; end

Options = {'Gradient descent', 'Step by step'};
PathAlg = uiconfirm(Fig, 'What type of algorithm do you want to use in path definition?', ...
                         'Path algorithm', 'Options',Options, 'DefaultOption',2);

TolAns  = inputdlg2({'Gradient tolerance:', 'Max steps:'}, 'DefInp',{'1e-3', '500'});
GradTol = str2double(TolAns{1});
StepTol = str2double(TolAns{2});

if strcmp(PathAlg,'Gradient descent')
    StepSz = str2double(inputdlg2({'Step size for gradient descent:'}, 'DefInp',{'1'}));
end

Options = {'Instability points', 'Detected points'};
StrtPnt = uiconfirm(Fig, 'What points do you want to use to define landslide bodies?', ...
                         'Lands bodies', 'Options',Options, 'DefaultOption',2);

if not(strcmp(StrtPnt,'Detected points'))
    CritFS = str2double(inputdlg2({'Critical FS (below unstable points):'}, 'DefInp',{'1.5'}));
end

EvolAns    = inputdlg2({'Gamma soil (wet):', 'A Skempton coefficient:', ...
                        'B Skempton coefficient:', 'Depth of instability:'}, ...
                                        'DefInp',{'20', '0.5', '0.8', num2str(InstDepth)});
GammaSoil  = str2double(EvolAns{1});
GammaWater = 10;
SkemptonA  = str2double(EvolAns{2});
SkemptonB  = str2double(EvolAns{3});
InstDepth  = str2double(EvolAns{4});

%% Creation of PathsInfo
PathsInfo = table({InstAnTp}, {fold_an}, EventFS, SngGrid, {PathAlg}, ...
                  GradTol, StepTol, {StrtPnt}, 'VariableNames',{'InstabilityAnalysisType', ...
                                                                'OriginalAnalysisFolder', ...
                                                                'EventAnalyzed', ...
                                                                'DEMsMerged', ...
                                                                'PathAlgorithm', ...
                                                                'GradientTolerance', ...
                                                                'StepTolerance', ...
                                                                'StartPointsMode'}, 'RowNames',{'Ev1'});

if strcmp(PathAlg,'Gradient descent')
    PathsInfo.StepSizeGD = StepSz;
end

if not(strcmp(StrtPnt,'Detected points'))
    PathsInfo.CriticalFS = CritFS;
end

%% Geo to planar conversion, NOTE: IT IS IMPORTANT TO HAVE METERS AS COORDINATES!
ProgressBar.Message = 'Conversion of coordinates from geo to plan...';

if OriginallyProjected && SameCRSForAll
    load([fold_var,sl,'MorphologyParameters.mat'], 'OriginalProjCRS')

    ProjCRS = OriginalProjCRS;
else
    EPSG    = str2double(inputdlg2({['DTM EPSG (Sicily -> 32633, ' ...
                                     'Emilia Romagna -> 25832):']}, 'DefInp',{'25832'}));
    ProjCRS = projcrs(EPSG);
end

[xPlanAll, yPlanAll] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    [xPlanAll{i1}, yPlanAll{i1}] = projfwd(ProjCRS, yLatAll{i1}, xLongAll{i1});
end

DetLandsGeo = cell2mat(InfoDetectedSoilSlipsToUse(:, 5:6));
[DetLandsPln(:,1), DetLandsPln(:,2)] = projfwd(ProjCRS, DetLandsGeo(:,2), DetLandsGeo(:,1));

%% Update of PathsInfo
PathsInfo.PlanarProjCRS = ProjCRS;

%% Optional merging of DEMs
if SngGrid
    error('Not yet implemented, please contact the support!')
end
% TO IMPLEMENT! (A function should be already written!)

%% Loop over all DEM cells
[DBScanValues, GrdSize] = deal(cell(1, length(xLongAll)));
PathsHistCol = strcat("DEM ",string(1:numel(xLongAll)));
PathsHistory = array2table(cell(3, numel(PathsHistCol)), 'VariableNames',PathsHistCol, ...
                                                         'RowNames',{'LandsBody','LandsStart','LandsPath'});
for i1 = 1:length(xLongAll)
    %% Data extraction
    ProgressBar.Message = 'Data Extraction';

    MatIndicesAll  = int32([repmat((1:size(ElevationAll{i1},1))',  size(ElevationAll{i1},2), 1), ...    % Row indices in the first column
                            repelem((1:size(ElevationAll{i1},2))', size(ElevationAll{i1},1)   ) ]);     % Column indices in the second column
    MatIndsStArea  = MatIndicesAll(IndexDTMPointsInsideStudyArea{i1}, :);
    xLongStudyArea = xLongAll{i1}(IndexDTMPointsInsideStudyArea{i1});
    yLatStudyArea  = yLatAll{i1}(IndexDTMPointsInsideStudyArea{i1});
    xPlCrStudyArea = xPlanAll{i1}(IndexDTMPointsInsideStudyArea{i1});
    yPlCrStudyArea = yPlanAll{i1}(IndexDTMPointsInsideStudyArea{i1});
    ElevStudyArea  = ElevationAll{i1}(IndexDTMPointsInsideStudyArea{i1});
    AsAngStudyArea = AspectAngleAll{i1}(IndexDTMPointsInsideStudyArea{i1});
    RIndsStudyArea = (1:numel(IndexDTMPointsInsideStudyArea{i1}))';

    RelIndsAll = zeros(size(xLongAll{i1}));
    RelIndsAll(IndexDTMPointsInsideStudyArea{i1}) = RIndsStudyArea;
    
    FsStudyArea = FactorSafety{i1}; % FsStudyArea have same dimension of IndexDTMPointsInsideStudyArea

    % Basic sizes for grid
    dX   = abs(xPlanAll{i1}(1,2)-xPlanAll{i1}(1,1));
    dY   = abs(yPlanAll{i1}(2,1)-yPlanAll{i1}(1,1)); % You could use floor(......) to have an integer number (stored as float)
    dXdY = (sqrt(dY^2+dX^2));

    GrdSize{i1} = [dX, dY];

    % Gradient of planar coordinates
    [PlGradE, PlGradN] = gradient(ElevationAll{i1}, dX, dY);
    
    %% Search for critical points
    switch StrtPnt
        case 'Instability points'
            IndUnstPntsRaw = find(FsStudyArea(:) <= CritFS & FsStudyArea(:) >= 0);

        case 'Detected points'
            IndWithCurrDTM = cell2mat(InfoDetectedSoilSlipsToUse(:, 3)) == i1;
            IndUnstPntsRaw = cell2mat(InfoDetectedSoilSlipsToUse(IndWithCurrDTM, 4));

        otherwise
            error('Type of points for land bodies not recognized!')
    end

    if isempty(IndUnstPntsRaw)
        warning(['DEM n. ',num2str(i1),' skipped. No unstable points!'])
        continue 
    end

    UnstCoordsRaw  = [xPlCrStudyArea(IndUnstPntsRaw), yPlCrStudyArea(IndUnstPntsRaw)];
    UnstGeoCrdsRaw = [xLongStudyArea(IndUnstPntsRaw), yLatStudyArea(IndUnstPntsRaw)];
    UnstAspctRaw   = AsAngStudyArea(IndUnstPntsRaw);
    UnstElevRaw    = ElevStudyArea(IndUnstPntsRaw);
    UnstGridIndRaw = MatIndsStArea(IndUnstPntsRaw, :);
    
    %% Clusterization of near points
    ProgressBar.Message = 'Clusterization';
    
    dbScInp = inputdlg2({['Max radius around each point (DEM size is ',num2str(dX),' m):'], ...
                         ['Min number of points per cluster (DEM size is ',num2str(dX),' m):']}, 'DefInp',{num2str(dX*3), '1'});
    MaxRad  = str2double(dbScInp{1});
    MinPnts = str2double(dbScInp{2});
    ClstVal = dbscan(UnstCoordsRaw, MaxRad, MinPnts); % Coordinates, max dist each core point, min n. of point for each core point

    if numel(unique(ClstVal)) && (unique(ClstVal) == -1)
        error('With your radius and min number of points there are no clusters!')
    end
    
    NumOfCl  = unique(ClstVal);
    IndPntCl = deal(cell(2, numel(NumOfCl))); % First row contain indices of landslide body, Second row just the index of the bottom point
    for i2 = 1:numel(NumOfCl)
        IndPntCl{1, i2} = find(ClstVal == NumOfCl(i2)); % The indices of landslide bodies, referred to UnstCoordsRaw!
    
        ElevTemp     = UnstElevRaw(IndPntCl{1, i2});
        [~, IndBott] = min(ElevTemp); % The bottom point of the landslide body (start point of the path)
    
        IndPntCl{2, i2} = IndPntCl{1, i2}(IndBott); % The index of the bottom point, referred to UnstCoordsRaw!
    end
    
    if any(NumOfCl == -1)
        Ind2Rem = find(NumOfCl == -1);
        NoiseVl = numel(IndPntCl{1, Ind2Rem});
    
        NumOfCl(Ind2Rem)     = [];
        IndPntCl(:, Ind2Rem) = [];
    
        warning(['There was noise in your dataset -> ',num2str(NoiseVl),' points were deleted!'])
    end
    
    ProgressBar.Cancelable    = 'on';
    ProgressBar.Indeterminate = 'off';
    LndPolys = deal(cell(4, numel(NumOfCl)));
    BodyArea = deal(cell(1, numel(NumOfCl)));
    for i2 = 1:numel(NumOfCl)
        ProgressBar.Value   = i2/numel(NumOfCl);
        ProgressBar.Message = ['Landslide polygon n. ',num2str(i2),' of ',num2str(numel(NumOfCl))];
    
        if ProgressBar.CancelRequested; break; end
        
        CoordsTemp      = UnstCoordsRaw(IndPntCl{1, i2}, :);
        PolyUnstPlnTmp  = polybuffpoint2(CoordsTemp, [1.01*dX/2, 1.01*dY/2], 'UniquePoly',true); % 1.01 to allow the merging of single polygons!
        [CntPX, CntPY]  = centroid(PolyUnstPlnTmp);
        PolyUnstGeoTmp  = projinvpoly(PolyUnstPlnTmp, ProjCRS);
        [CntGX, CntGY]  = centroid(PolyUnstGeoTmp);
    
        LndPolys{1, i2} = PolyUnstPlnTmp;
        LndPolys{2, i2} = [CntPX, CntPY];
        LndPolys{3, i2} = PolyUnstGeoTmp;
        LndPolys{4, i2} = [CntGX, CntGY];

        BodyArea{1, i2} = size(CoordsTemp, 1)*dX*dY;
    end
    if ProgressBar.CancelRequested; return; end
    ProgressBar.Indeterminate = 'on';
    
    % REMEMBER TO CREATE A FILTER FOR ASPECT (EVENTUALLY ALSO THE SPLIT IN MORE 
    % CLASSES FROM ONE WITH TOO DIFFERENCES BETWEEN ASPECTS)
    
    ColLndNames  = strcat("Land",string(1:size(IndPntCl, 2)));
    IndForStart  = [IndPntCl{2, :}]; % The indices of the start point for each landslide body, referred to Raw arrays!
    
    LandsBodies  = table('RowNames',{'IndStudy', 'IndGridAll', 'CoordsPlan', ...
                                     'CoordsGeo', 'Aspect', 'Elevation', 'PolyPlan', ...
                                     'CentrPlan', 'PolyGeo', 'CentrGeo', 'BodyArea'});
    LandsStrtPnt = table('RowNames',{'IndStudy', 'IndGridAll', 'CoordsPlan', ...
                                     'CoordsGeo', 'Aspect', 'Elevation'});
    
    LandsBodies{:, ColLndNames}  = [cellfun(@(x) IndUnstPntsRaw(x),    IndPntCl(1,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstGridIndRaw(x, :), IndPntCl(1,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstCoordsRaw(x, :),  IndPntCl(1,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstGeoCrdsRaw(x, :), IndPntCl(1,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstAspctRaw(x),      IndPntCl(1,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstElevRaw(x),       IndPntCl(1,:), 'UniformOutput',false); ...
                                    LndPolys(1, :); ...
                                    LndPolys(2, :); ...
                                    LndPolys(3, :); ...
                                    LndPolys(4, :); ...
                                    BodyArea(1, :)                                                                ];
    
    LandsStrtPnt{:, ColLndNames} = [cellfun(@(x) IndUnstPntsRaw(x),    IndPntCl(2,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstGridIndRaw(x, :), IndPntCl(2,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstCoordsRaw(x, :),  IndPntCl(2,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstGeoCrdsRaw(x, :), IndPntCl(2,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstAspctRaw(x),      IndPntCl(2,:), 'UniformOutput',false); ...
                                    cellfun(@(x) UnstElevRaw(x),       IndPntCl(2,:), 'UniformOutput',false)     ];
    
    DBScanValues{i1} = [MaxRad, MinPnts];
    
    %% Raw path processing
    PathHistRaw = cell(4, size(LandsStrtPnt,2));
    switch PathAlg
        case 'Gradient descent'
            %% Gradient descent evolution
            if int64(dX) ~= int64(dY)
                warning('Grid spacing in X and Y are different!')
            end

            for i2 = 1:size(LandsStrtPnt,2)
                % Creation of raw paths
                CurrStep = 1;
                CurrRow  = LandsStrtPnt{'IndGridAll',i2}{:}(1);
                CurrCol  = LandsStrtPnt{'IndGridAll',i2}{:}(2);
                CurrGrad = [PlGradE(CurrRow,CurrCol), PlGradN(CurrRow,CurrCol)];
                [PthHstGeoR, PthHstPlnR, GrdIndHstR] = deal(nan(StepTol, 2));
                StAIndHstR = nan(StepTol, 1);
                while ( abs(norm(CurrGrad(CurrStep,:))) >= GradTol ) && ( CurrStep < StepTol )
                    PthHstGeoR(CurrStep, :) = [xLongAll{i1}(CurrRow,CurrCol), yLatAll{i1}(CurrRow,CurrCol) ];
                    PthHstPlnR(CurrStep, :) = [xPlanAll{i1}(CurrRow,CurrCol), yPlanAll{i1}(CurrRow,CurrCol)];
                    GrdIndHstR(CurrStep, :) = [CurrRow, CurrCol];
                    StAIndHstR(CurrStep   ) = RelIndsAll(CurrRow, CurrCol);

                    if (CurrStep >= 2) && isequal(PthHstPlnR(CurrStep, :), PthHstPlnR(CurrStep-1, :))
                        CurrGrad(CurrStep, :) = CurrGrad(CurrStep, :) + CurrGrad(CurrStep-1, :); % Forcing the movement to the next point, increasing the gradient!
                    end

                    NextPnt = PthHstPlnR(CurrStep, :) - StepSz*[dX, dY].*CurrGrad(CurrStep,:); % dX or dY makes no difference because are equal!

                    [~, CurrCol] = min((abs(xPlanAll{i1}(1,:) - NextPnt(1,1)))); % Snap to nearest point in grid!
                    [~, CurrRow] = min((abs(yPlanAll{i1}(:,1) - NextPnt(1,2)))); % Snap to nearest point in grid!

                    % Too slow (old way)
                    % [~, RelIdNx] = min(sum(([xPlanAll{i1}(:), yPlanAll{i1}(:)] - NextPnt).^2, 2));
                    % 
                    % CurrRow = MatIndicesAll(RelIdNx, 1);
                    % CurrCol = MatIndicesAll(RelIdNx, 2);

                    BordTouched = (CurrRow <= 1) || (CurrRow >= size(xPlanAll{i1},1)) || ...
                                  (CurrCol <= 1) || (CurrCol >= size(xPlanAll{i1},2));
                    if BordTouched
                        warning(['Path n.',num2str(i2),' reached the border of the DEM grid -> stopped there!'])
                        break
                    end

                    CurrStep = CurrStep + 1;
                    CurrGrad(CurrStep, :) = [PlGradE(CurrRow, CurrCol), PlGradN(CurrRow, CurrCol)];
                end

                PathHistRaw(:, i2) = {PthHstGeoR, PthHstPlnR, GrdIndHstR, StAIndHstR};
            end
    
        case 'Step by step'
            %% Step by step evolution
            for i2 = 1:size(LandsStrtPnt,2)
                CurrStep = 1;
                CurrRow  = LandsStrtPnt{'IndGridAll',i2}{:}(1);
                CurrCol  = LandsStrtPnt{'IndGridAll',i2}{:}(2);
                CurrGrad = [PlGradE(CurrRow,CurrCol), PlGradN(CurrRow,CurrCol)];
                [PthHstGeoR, PthHstPlnR, GrdIndHstR] = deal(nan(StepTol, 2));
                StAIndHstR = nan(StepTol, 1);
                while ( abs(norm(CurrGrad(CurrStep,:))) >= GradTol ) && ( CurrStep < StepTol )
                    CurrPntGeo = [ xLongAll{i1}(CurrRow,CurrCol), ...
                                   yLatAll{i1}(CurrRow,CurrCol)      ];
                    CurrPnt    = [ xPlanAll{i1}(CurrRow,CurrCol), ...
                                   yPlanAll{i1}(CurrRow,CurrCol)     ];
                    ElevCurrnt = ElevationAll{i1}(CurrRow, CurrCol);

                    % Storing of current point
                    PthHstGeoR(CurrStep, :) = CurrPntGeo;
                    PthHstPlnR(CurrStep, :) = CurrPnt;
                    GrdIndHstR(CurrStep, :) = [CurrRow, CurrCol];
                    StAIndHstR(CurrStep   ) = RelIndsAll(CurrRow, CurrCol);

                    % Points around
                    PntArounds = [ CurrPnt(1,1)-dX, CurrPnt(1,2)   ; ...
                                   CurrPnt(1,1)+dX, CurrPnt(1,2)   ; ...
                                   CurrPnt(1,1)   , CurrPnt(1,2)-dY; ...
                                   CurrPnt(1,1)   , CurrPnt(1,2)+dY; ...
                                   CurrPnt(1,1)-dX, CurrPnt(1,2)-dY; ...
                                   CurrPnt(1,1)+dX, CurrPnt(1,2)+dY; ...
                                   CurrPnt(1,1)+dX, CurrPnt(1,2)-dY; ...
                                   CurrPnt(1,1)-dX, CurrPnt(1,2)+dY     ];

                    PntGrdInds = [ CurrRow-1, CurrCol  ; ...
                                   CurrRow+1, CurrCol  ; ...
                                   CurrRow  , CurrCol-1; ...
                                   CurrRow  , CurrCol+1; ...
                                   CurrRow-1, CurrCol-1; ...
                                   CurrRow+1, CurrCol+1; ...
                                   CurrRow+1, CurrCol-1; ...
                                   CurrRow-1, CurrCol+1     ];

                    ElevAround = zeros(size(PntGrdInds,1), 1);
                    for i3 = 1:numel(ElevAround)
                        ElevAround(i3) = ElevationAll{i1}(PntGrdInds(i3,1), PntGrdInds(i3,2));
                    end
                    
                    SlpPntArnd = (ElevCurrnt - ElevAround) ./ vecnorm(CurrPnt-PntArounds, 2, 2);
                    [~, RIdNx] = max(SlpPntArnd);

                    if numel(RIdNx) ~= 1; error('Not single point for next step!'); end

                    CurrRow  = PntGrdInds(RIdNx, 1);
                    CurrCol  = PntGrdInds(RIdNx, 2);

                    BordTouched = (CurrRow <= 1) || (CurrRow >= size(xPlanAll{i1},1)) || ...
                                  (CurrCol <= 1) || (CurrCol >= size(xPlanAll{i1},2));
                    if BordTouched
                        warning(['Path n.',num2str(i2),' reached the border of the DEM grid -> stopped there!'])
                        break
                    end

                    CurrStep = CurrStep + 1;
                    CurrGrad(CurrStep, :) = [PlGradE(CurrRow, CurrCol), PlGradN(CurrRow, CurrCol)];
                end

                PathHistRaw(:, i2) = {PthHstGeoR, PthHstPlnR, GrdIndHstR, StAIndHstR};
            end
    
        otherwise 
            error('Path algorithm not recognized!')
    end

    %% Clean paths and further properties
    PthHstRws = {'PthHistGeo', 'PthHistPln', 'GridIndHist', 'StAIndHist', ...
                 'PthProgLn', 'PthElvation', 'PthPhi', 'PthCohesion', 'PthStp1DLen', ...
                 'PthStpSlope', 'PthStpAccel', 'PthStpTime', 'PthHistSpeed', ...
                 'PthStpAvSpeed', 'PthMeanSpeed', 'PthMaxSpeed', 'PthStartFS', ...
                 'PthBottomFS', 'PthTopFS', 'PthErodedDpth', 'PthVolume'};
    PathHist  = array2table(cell(21, size(LandsStrtPnt,2)), 'RowNames',PthHstRws, ...
                                                            'VariableNames',ColLndNames);
    for i2 = 1:size(LandsStrtPnt,2)
        PthHstGeoR = PathHistRaw{1, i2};
        PthHstPlnR = PathHistRaw{2, i2};
        GrdIndHstR = PathHistRaw{3, i2};
        StAIndHstR = PathHistRaw{4, i2};

        RowNans = isnan(PthHstGeoR(:, 1));
        PthHstGeoR(RowNans, :) = [];
        PthHstPlnR(RowNans, :) = [];
        GrdIndHstR(RowNans, :) = [];
        StAIndHstR(RowNans   ) = [];
    
        CurrInd  = 1;
        CurrReps = 0;
        [PthHstGeo, PthHstPln, GrdIndHst] = deal(nan(size(PthHstPlnR)));
        StAIndHst = nan(size(PthHstPlnR, 1), 1);
        for CurrStep = 1:size(PthHstPlnR, 1)
            if CurrStep >= 2 && any(ismember(PthHstPlnR(CurrStep,:), PthHstPlnR(CurrStep-1 : -1 : 1, :), 'rows'))
                CurrReps = CurrReps + 1;
            else
                PthHstGeo(CurrInd, :) = PthHstGeoR(CurrStep,:);
                PthHstPln(CurrInd, :) = PthHstPlnR(CurrStep,:);
                GrdIndHst(CurrInd, :) = GrdIndHstR(CurrStep,:);
                StAIndHst(CurrInd)    = StAIndHstR(CurrStep  );
    
                CurrInd = CurrInd + 1;
            end
        end
    
        RowNans = isnan(PthHstGeo(:, 1));
        PthHstGeo(RowNans, :) = [];
        PthHstPln(RowNans, :) = [];
        GrdIndHst(RowNans, :) = [];
        StAIndHst(RowNans)    = [];
    
        if size(PthHstPln, 1) == 1; error(['Cleaned path n.',num2str(i2),' has a single point!']); end
        
        % Planar progressive length of steps
        PthPrLn = deal(zeros(size(PthHstPln, 1), 1));
        for i3 = 2:size(PthHstPln, 1)
            PthPrLn(i3) = PthPrLn(i3-1, 1) + norm( PthHstPln(i3, :) - PthHstPln(i3-1, :) );
        end

        % Elevation, phi, and cohesion of paths
        [PthElvt, PthPhi, PthCohe] = deal(zeros(size(PthHstPln, 1), 1));
        for i3 = 1:size(PthElvt, 1)
            PthElvt(i3) = ElevationAll{i1}(GrdIndHst(i3,1), GrdIndHst(i3,2));
            PthPhi(i3)  = PhiAll{i1}(GrdIndHst(i3,1), GrdIndHst(i3,2));
            PthCohe(i3) = CohesionAll{i1}(GrdIndHst(i3,1), GrdIndHst(i3,2)) + ...
                          RootCohesionAll{i1}(GrdIndHst(i3,1), GrdIndHst(i3,2));
        end

        % Replacing of missing phi values
        Ind2Rep = (PthPhi < 0) | (PthPhi > 100) | (isnan(PthPhi));
        if any(Ind2Rep)
            warning(['Some values of phi and cohesion are undefined or out ' ...
                     'of common ranges! Insert replacing value in next prompt!'])

            RepAns  = inputdlg2({'New soil friction (just where needed):', ...
                                 'New soil cohesion (just where needed):'}, 'DefInp',{'9.5', '20'});
            RepPhi  = str2double(RepAns{1});
            RepCohe = str2double(RepAns{2});

            PthPhi(Ind2Rep)  = RepPhi;
            PthCohe(Ind2Rep) = RepCohe;
        end

        % 1D length, slope, and acceleration of steps
        [PthStpML, PthStpSl, PthStpAc] = deal(zeros(size(PthHstPln, 1) - 1, 1));
        for i3 = 1:size(PthStpML, 1)
            PhiTpMssTmp  = PthPhi(i3)*2/3;
            PthStpML(i3) = norm([PthPrLn(i3+1) - PthPrLn(i3), PthElvt(i3+1) - PthElvt(i3)]);
            PthStpSl(i3) = atand((PthElvt(i3) - PthElvt(i3+1)) / (PthPrLn(i3+1) - PthPrLn(i3))); % In degree
            PthStpAc(i3) = 9.81 * sind(PthStpSl(i3)) * ( 1 - tand(PhiTpMssTmp) / tand(PthStpSl(i3)) );
        end

        % Writing initial FS
        StartFS = FsStudyArea(StAIndHst(1));

        % Replacing of the first acceleration (if greater than before)
        FrstAcc = 9.81 * sind(PthStpSl(1)) * (1 - StartFS);
        if FrstAcc > PthStpAc(1)
            PthStpAc(1) = FrstAcc;
        end

        % Speeds and times of steps
        [PthStpTm, PthStpAS] = deal(nan(size(PthStpAc, 1) , 1));
        PthStpSp = deal(zeros(size(PthHstPln, 1), 1)); % An extra entry because these are punctual speeds and not averages of the steps!
        for i3 = 1:size(PthStpTm, 1)
            if (PthStpSp(i3)^2 + 2*PthStpAc(i3)*PthStpML(i3)) >= 0
                PthStpTm(i3)   = ( -PthStpSp(i3) + sqrt(PthStpSp(i3)^2 + 2*PthStpAc(i3)*PthStpML(i3)) ) / PthStpAc(i3);
                PthStpSp(i3+1) = PthStpSp(i3) + PthStpAc(i3)*PthStpTm(i3,1);
                PthStpAS(i3)   = (PthStpSp(i3+1) + PthStpSp(i3)) / 2;
            else
                break
            end
        end

        % Cleaning of the part not followed of the path
        Ind2Rem = isnan(PthStpTm);
        PthStpTm(Ind2Rem) = [];
        PthStpSp(Ind2Rem) = [];
        PthStpAS(Ind2Rem) = [];

        % Mean and max speeds
        PthMnSp = sum(PthStpAS .* PthStpTm) / sum(PthStpTm);
        PthMxSp = max(PthStpSp);

        % Writing bottom/top FS and volume
        StrtArea = LandsBodies{'BodyArea',i2}{:};
        PthVol   = deal(zeros(size(PthHstPln, 1), 2));
        PthVol(1, :) = [InstDepth*StrtArea, 1];
        [ErodDpt, CrrBdyH] = deal(InstDepth);
        [CoheTop, CoheBot] = deal(PthCohe);
        [PthDltH, PthTopFS, PthBotFS] = deal(zeros(size(PthStpAc, 1), 1));
        for i3 = 1:size(PthDltH, 1)
            [PhiBot, PhiTop] = deal(mean(PthPhi(i3),PthPhi(i3+1))*2/3);
            PthTopFS(i3) = CoheTop(i3) / (GammaSoil*CrrBdyH*sind(PthStpSl(i3))*cosd(PthStpSl(i3))) + ...
                           ( 1 - SkemptonB*(1 + SkemptonA*tand(PthStpSl(i3))) )*tand(PhiTop) / tand(PthStpSl(i3));
            PthBotFS(i3) = CoheBot(i3) / (GammaSoil*(CrrBdyH+ErodDpt)*sind(PthStpSl(i3))*cosd(PthStpSl(i3))) + ...
                           tand(PhiBot)*( CrrBdyH + ErodDpt - SkemptonB*CrrBdyH*(1 + SkemptonA* ...
                                          tand(PthStpSl(i3))) + ErodDpt*GammaWater/GammaSoil    ) / ...
                           ((CrrBdyH + ErodDpt)*tand(PthStpSl(i3)));

            if (PthTopFS(i3) < 1) && (PthBotFS(i3) >= 1)
                PthDltH(i3) = ErodDpt * (1-PthTopFS(i3)) / (PthBotFS(i3)-PthTopFS(i3));
            elseif PthBotFS(i3) < 1
                PthDltH(i3) = ErodDpt;
            else
                PthDltH(i3) = 0;
            end

            CrrBdyH = CrrBdyH + 0.1*PthDltH(i3); % Remember that not the entire depth removed remain vertical but spreads over the plane... You should adjust it, now it is just 10%!

            PthVol(i3+1, :) = [CrrBdyH*StrtArea, ...
                               CrrBdyH*StrtArea / (InstDepth*StrtArea)];
        end
    
        % Writing table
        PathHist{'PthHistGeo',    i2} = {PthHstGeo};
        PathHist{'PthHistPln',    i2} = {PthHstPln};
        PathHist{'GridIndHist',   i2} = {GrdIndHst};
        PathHist{'StAIndHist',    i2} = {StAIndHst};
        PathHist{'PthProgLn',     i2} = {PthPrLn};
        PathHist{'PthElvation',   i2} = {PthElvt};
        PathHist{'PthPhi',        i2} = {PthPhi};
        PathHist{'PthCohesion',   i2} = {PthCohe};
        PathHist{'PthStp1DLen',   i2} = {PthStpML};
        PathHist{'PthStpSlope',   i2} = {PthStpSl};
        PathHist{'PthStpAccel',   i2} = {PthStpAc};
        PathHist{'PthStpTime',    i2} = {PthStpTm};
        PathHist{'PthHistSpeed',  i2} = {PthStpSp};
        PathHist{'PthStpAvSpeed', i2} = {PthStpAS};
        PathHist{'PthMeanSpeed',  i2} = {PthMnSp};
        PathHist{'PthMaxSpeed',   i2} = {PthMxSp};
        PathHist{'PthStartFS',    i2} = {StartFS};
        PathHist{'PthBottomFS',   i2} = {PthBotFS};
        PathHist{'PthTopFS',      i2} = {PthTopFS};
        PathHist{'PthErodedDpth', i2} = {PthDltH};
        PathHist{'PthVolume',     i2} = {PthVol};
    end

    PathsHistory{:, PathsHistCol(i1)} = {LandsBodies; LandsStrtPnt; PathHist};
end

%% Update of PathsInfo
PathsInfo.DBScanParameters = DBScanValues;
PathsInfo.InstabilityDepth = InstDepth;
PathsInfo.GridSize         = GrdSize;

%% Saving...
ProgressBar.Message = 'Saving...';

VariablesPaths = {'PathsHistory', 'PathsInfo'};
saveswitch([fold_res_flow,sl,FoldnameFS,sl,'LandslidesPaths.mat'], VariablesPaths);