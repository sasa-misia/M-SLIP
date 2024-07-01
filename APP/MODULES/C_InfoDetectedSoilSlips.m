if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading Files
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'   ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygonClean')

%% Preliminary operations
FilesExcl = {dir([fold_raw_det_ss,sl,'*.xlsx']).name};
FlDetSlSp = string(checkbox2(FilesExcl, 'Title',{'Choose file (even multiple):'})); % Maybe it is better the full path!

FilesDetectedSoilSlip = FlDetSlSp;
FullPthDetectSoilSlip = strcat(fold_raw_det_ss,sl,FlDetSlSp);
VrInfDt = {'FilesDetectedSoilSlip', 'FullPthDetectSoilSlip'};

SbArAns = checkbox2({'Sub area for each point', 'Allow overlap of DTMs', ...
                     'Datetimes'}, 'DefInp',[0,0,0], 'OutType','LogInd');
SubArea = SbArAns(1);
OvrlDTM = SbArAns(2);
UseDttm = SbArAns(3);

if SubArea
    MetNearPnts = listdlg2(strcat("Near points area, file ",FlDetSlSp), {'Circle', 'ImportPolygons'});
end

VrInfDt = [VrInfDt, {'SubArea'}];

TbCnTpF = {"", "", NaN, NaN, NaN, NaN, NaN, NaN, NaN, "", NaN, NaN, NaN, NaN, NaN, "", NaN, NaN, "", NaT}; % To initialize rows of table!
TbCnNmF = {'Municipality', 'Location', 'DTM n.', 'Nearest point', ...
           'Longitude', 'Latitude', 'Elevation', 'Slope', 'Aspect', ...
           'Soil', 'Cohesion', 'Phi', 'kt', 'A', 'n', ...
           'Vegetation', 'Beta*', 'Root cohesion', 'Land use', 'Datetime'};

TbCnNmR = {'Municipality', 'Location', 'Actual coordinates', ...
           'Info points', 'Soil', 'Vegetation', 'Land use', 'Datetime'};

TbCnTpM = TbCnTpF(3:end-1); % end-1 to remove Datetime!
TbCnNmM = TbCnNmF(3:end-1); % end-1 to remove Datetime!

%% Extraction of points inside study area
xLongStudy = cellfun(@(x,y) x(y)      , xLongAll  , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy  = cellfun(@(x,y) x(y)      , yLatAll   , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
GrPtsStCat = cellfun(@(x,y) cat(2,x,y), xLongStudy, yLatStudy                    , 'UniformOutput',false);

yLatMean = mean(cellfun(@(x) mean(x), yLatStudy));

%% Creation of tables - start of loop
[InfoDetectedSoilSlips, InfoDetectedSoilSlipsAverage, InfoPointsNearDetectedSoilSlips] = deal(cell(1, length(FlDetSlSp)));
Ids2Rem = false(size(InfoDetectedSoilSlips));
for i1 = 1:length(FlDetSlSp)
    %% Data extraction
    ProgressBar.Message = 'Data extraction...';
    
    DetSSData = readcell(FullPthDetectSoilSlip(i1));
    EmptyPosn = cellfun(@(x) all(ismissing(x)), DetSSData);
    DetSSData(EmptyPosn) = {'Not specified'};
    
    Municipls = DetSSData(2:end,1);
    Locations = DetSSData(2:end,2);
    CrdDetSSs = [cell2mat(DetSSData(2:end,4)), cell2mat(DetSSData(2:end,3))]; % MAKE THIS LINE AUTOMATIC!!!
    if UseDttm
        DttmClmns = listdlg2({'Choose the datetime column'}, DetSSData(1,:), 'OutType','NumInd');
        Datetimes = DetSSData{2:end,DttmClmns};
        if not(isdatetime(Datetimes))
            warning(['The specified column did not contain datetimes! ', ...
                     'The Infodetected column will contain just NaT!'])
            Datetimes = NaT(size(DetSSData(2:end,1)));
        end
    end
    
    %% Pre Processing and Initialization
    ProgressBar.Message = 'Processing...';
    [pp1, ee1] = getnan2([StudyAreaPolygonClean.Vertices; nan, nan]);
    IndexPointsInsideStudyArea = find(inpoly([CrdDetSSs(:,1), CrdDetSSs(:,2)], pp1, ee1)==1);

    Municipls = Municipls(IndexPointsInsideStudyArea);
    Locations = Locations(IndexPointsInsideStudyArea);
    CrdDetSSs = CrdDetSSs(IndexPointsInsideStudyArea, :);
    
    if length(IndexPointsInsideStudyArea) ~= length(DetSSData(2:end,1))
        DeletedPoints = length(DetSSData(2:end,1))-length(IndexPointsInsideStudyArea);
        warning(strcat(string(DeletedPoints),' points deleted!'))
        if isempty(IndexPointsInsideStudyArea)
            warning(['After removing points outside Study Area, no one left! ', ...
                     'The file ',char(FilesDetectedSoilSlip(i1)),' will be removed!'])
            Ids2Rem(i1) = true;
            continue
        end
    end
    
    InfoDetectedSoilSlips{i1} = cell2table(repmat(TbCnTpF, size(CrdDetSSs,1), 1), 'VariableNames',TbCnNmF); % Initialization
    if SubArea
        InfoDetectedSoilSlipsAverage{i1}    = cell(1,2); % Array initialization
        InfoDetectedSoilSlipsAverage{i1}{1} = repmat(polyshape, 1, size(CrdDetSSs,1)); % Array initialization
        InfoPointsNearDetectedSoilSlips{i1} = array2table(cell(size(CrdDetSSs,1), numel(TbCnNmR)), 'VariableNames',TbCnNmR); % Array initialization

        switch MetNearPnts{i1}
            case 'Circle'
                AreaDiamet = str2double(inputdlg2(['Set diameter [m] for file n. ',num2str(i1)], 'DefInp',{'50'}));
    
            case 'ImportPolygons'
                if exist([fold_var,sl,'SoilSlipPolygonsStudyArea.mat'], 'file')
                    load([fold_var,sl,'SoilSlipPolygonsStudyArea.mat'], 'IDsAllUnique','IDsPolygonsStudyArea')
                else
                    error('You have to import the shapefile first (C_DetectedSoilSLips.m script)')
                end
                IDsDetSoilSlip = string(Locations);

            otherwise
                error('Near points method not recognized!')
        end
    end

    %% Processing
    for i2 = 1:size(CrdDetSSs,1)
        InfoDetectedSoilSlips{i1}{i2,1} = string(Municipls{i2});
        InfoDetectedSoilSlips{i1}{i2,2} = string(Locations{i2});
    
        CurrPnt = CrdDetSSs(i2,:);
    
        CurrDistns = cellfun(@(x) pdist2(x,CurrPnt), GrPtsStCat, 'UniformOutput',false); 
        MinDst4DTM = cellfun(@min, CurrDistns, 'UniformOutput',false);
        MinDistAll = min([MinDst4DTM{:}]);
    
        CkPntInDTM = cellfun(@(x) x==MinDistAll, MinDst4DTM, 'UniformOutput',false);
    
        tf = cellfun(@isempty, CkPntInDTM);
        CkPntInDTM(tf) = {0}; % Zeros when Index are empty
    
        DTMIncludingPoint = find([CkPntInDTM{:}]);
        InfoDetectedSoilSlips{i1}{i2,3} = DTMIncludingPoint;
    
        CheckNearestPoint = cellfun(@(x) x==MinDistAll, CurrDistns(DTMIncludingPoint), 'UniformOutput',false);
        NearestPoint = find([CheckNearestPoint{:}]); % This is an index of indices
        InfoDetectedSoilSlips{i1}{i2,4} = NearestPoint;
    
        InfoDetectedSoilSlips{i1}{i2,5} = xLongStudy{DTMIncludingPoint}(NearestPoint);
        InfoDetectedSoilSlips{i1}{i2,6} = yLatStudy{DTMIncludingPoint}(NearestPoint);

        if UseDttm
            InfoDetectedSoilSlips{i1}{i2,20} = Datetimes(i2);
        end
    
        if SubArea
            switch MetNearPnts{i1}
                case 'Circle'
                    dLatRadius  = rad2deg(AreaDiamet/2/earthRadius); % /2 to have half of the size from the centre
                    dLongRadius = rad2deg(acos( (cos(AreaDiamet/2/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % /2 to have half of the size from the centre
    
                    Angles       = linspace(0, 2*pi, 50);
                    xLongEllTemp = dLongRadius*cos(Angles) + InfoDetectedSoilSlips{i1}{i2,5};
                    yLatEllTemp  = dLatRadius*sin(Angles)  + InfoDetectedSoilSlips{i1}{i2,6};

                    PolTemp = polyshape(xLongEllTemp, yLatEllTemp);

                    InfoDetectedSoilSlipsAverage{i1}{1}(i2) = PolTemp;
    
                case 'ImportPolygons'
                    CurrID = IDsDetSoilSlip(i2);
                    IndCurrID = find(strcmp(CurrID, string(IDsAllUnique)));

                    if isempty(IndCurrID)
                        error(strcat("The polygon with ID: ",CurrID," was not found!")); 
                    elseif isscalar(IndCurrID)
                        PolTemp = IDsPolygonsStudyArea(IndCurrID);
                    elseif numel(IndCurrID) > 1
                        PolTemp = union(IDsPolygonsStudyArea(IndCurrID));
                        warning(strcat("The polygon with ID: ",CurrID," has ",string(numel(IndCurrID))," matches. These polygons were merged!")); 
                    end

                    InfoDetectedSoilSlipsAverage{i1}{1}(i2) = PolTemp;

                otherwise
                    error('Method for near points not recognized!')
            end

            [pp2, ee2] = getnan2([PolTemp.Vertices; nan, nan]);
            NearestPoints   = cellfun(@(x) find(inpoly(x, pp2,ee2)), GrPtsStCat, 'UniformOutput',false); % These are indices of indices
            DTMIntersecated = find(~cellfun(@isempty, NearestPoints)); % Check where is NOT empty thanks to ~
            InfoPointsNearDetectedSoilSlips{i1}{i2,1:3} = {Municipls{i2}, Locations{i2}, CurrPnt};
            if UseDttm
                InfoPointsNearDetectedSoilSlips{i1}{i2,8} = {Datetimes(i2)};
            end
            
            if OvrlDTM
                InfoPointsNearTemp = [repmat(DTMIntersecated(1),size(NearestPoints{DTMIntersecated(1)})), ...
                                      NearestPoints{DTMIntersecated(1)}];
                if length(DTMIntersecated)>1
                    for i3 = 2:length(DTMIntersecated)
                        InfoPointsNearTemp = [ InfoPointsNearTemp;
                                              [repmat(DTMIntersecated(i3),size(NearestPoints{DTMIntersecated(i3)})), NearestPoints{DTMIntersecated(i3)}] ];
                    end
                end
            else  
                [~, DTMWithMorePoints] = max(cellfun(@length, NearestPoints));
                InfoPointsNearTemp = [repmat(DTMWithMorePoints,size(NearestPoints{DTMWithMorePoints})), NearestPoints{DTMWithMorePoints}];
            end

            InfoPointsNearDetectedSoilSlips{i1}{i2,4} = {cell2table(repmat(TbCnTpM, size(InfoPointsNearTemp,1), 1), 'Variablenames',TbCnNmM)};
            InfoPointsNearDetectedSoilSlips{i1}{i2,4}{:}{:,1:2} = InfoPointsNearTemp;
        end

    end
end

%% Cleaning of empty objects
FilesDetectedSoilSlip(Ids2Rem) = [];
FullPthDetectSoilSlip(Ids2Rem) = [];
InfoDetectedSoilSlips(Ids2Rem) = [];
if SubArea
    InfoPointsNearDetectedSoilSlips(Ids2Rem) = [];
    InfoDetectedSoilSlipsAverage(Ids2Rem)    = [];
end

IndDefInfoDet = 1;
if not(isscalar(FilesDetectedSoilSlip))
    IndDefInfoDet = listdlg2({'Default event:'}, FilesDetectedSoilSlip, 'OutType','NumInd');
end

%% Adding variables names to save
VrInfDt = [VrInfDt, {'IndDefInfoDet', 'InfoDetectedSoilSlips'}];
if SubArea
    VrInfDt = [VrInfDt, {'InfoPointsNearDetectedSoilSlips', 'InfoDetectedSoilSlipsAverage'}];
end

%% Saving...
ProgressBar.Message = 'Saving...';

saveswitch([fold_var,sl,'InfoDetectedSoilSlips.mat'], VrInfDt)