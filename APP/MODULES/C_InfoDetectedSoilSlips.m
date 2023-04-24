% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Reading data', ...
                                 'Message','Reading files...', 'Cancelable','off', ...
                                 'Indeterminate','on');
drawnow

%% Loading Files
cd(fold_var)
load('GridCoordinates.mat',    'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load('StudyAreaVariables.mat', 'StudyAreaPolygonClean')

%% Preliminary operations
cd(fold_raw_det_ss)
Files = {dir('*.xlsx').name};
Choice = listdlg('PromptString',{'Choose files (even multiple file, i.e. events): ',''}, ...
                 'ListString',Files, 'SelectionMode','multiple');
FilesDetectedSoilSlip = string(Files(Choice));

if length(FilesDetectedSoilSlip) == 1
    IndDefInfoDet = 1;
else
    IndDefInfoDet = listdlg('PromptString',{'Choose the default event: ',''}, ...
                            'ListString',FilesDetectedSoilSlip, 'SelectionMode','single');
end

VariablesInfoDet = {'FilesDetectedSoilSlip', 'IndDefInfoDet'};

drawnow % Remember to remove if in Standalone version
figure(Fig) % Remember to remove if in Standalone version

Options = {'Yes', 'No'};
ChoiceSubArea = uiconfirm(Fig, 'Would you like to create a sub area for each point detected?', ...
                               'Sub areas', 'Options',Options);

if strcmp(ChoiceSubArea,'Yes'); SubArea = true; else; SubArea = false; end

VariablesInfoDet = [VariablesInfoDet, {'SubArea'}];

%% Extraction of points inside study area
xLongStudy         = cellfun(@(x,y) x(y)      , xLongAll  , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy          = cellfun(@(x,y) x(y)      , yLatAll   , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
GridPointsStudyCat = cellfun(@(x,y) cat(2,x,y), xLongStudy, yLatStudy                    , 'UniformOutput',false);

yLatMean      = mean(cellfun(@(x) mean(x), yLatStudy));

%% Creation of tables - Start of loop
[InfoDetectedSoilSlips, InfoDetectedSoilSlipsAverage, InfoPointsNearDetectedSoilSlips] = deal(cell(1, length(FilesDetectedSoilSlip)));
for i1 = 1:length(FilesDetectedSoilSlip)
    %% Data extraction
    ProgressBar.Message = 'Data extraction...';
    
    DetSSData = readcell(FilesDetectedSoilSlip(i1));
    EmptyPositions = cellfun(@(x) all(ismissing(x)), DetSSData);
    DetSSData(EmptyPositions) = {'Not specified'};
    
    Municipalities = DetSSData(2:end,1);
    Locations = DetSSData(2:end,2);
    
    CoordDetSoilSlip = flip( reshape([DetSSData{cellfun(@isnumeric,DetSSData(:,1:5))}], [], 2), 2);
    
    %% Pre Processing and Initialization
    ProgressBar.Message = 'Processing...';
    [pp1, ee1] = getnan2([StudyAreaPolygonClean.Vertices; nan, nan]);
    IndexPointsInsideStudyArea = find(inpoly([CoordDetSoilSlip(:,1), CoordDetSoilSlip(:,2)], pp1, ee1)==1);

    Municipalities   = Municipalities(IndexPointsInsideStudyArea);
    Locations        = Locations(IndexPointsInsideStudyArea);
    CoordDetSoilSlip = CoordDetSoilSlip(IndexPointsInsideStudyArea, :);
    
    if length(IndexPointsInsideStudyArea) ~= length(Municipalities)
        DeletedPoints = length(Municipalities)-length(IndexPointsInsideStudyArea);
        warning(strcat(string(DeletedPoints),' points were deleted!'))
    end
    
    InfoDetectedSoilSlips{i1} = cell(size(CoordDetSoilSlip,1), 19); % Array initialization
    if SubArea
        InfoDetectedSoilSlipsAverage{i1}    = cell(1,2); % Array initialization
        InfoDetectedSoilSlipsAverage{i1}{1} = repmat(polyshape, 1, size(CoordDetSoilSlip,1)); % Array initialization
        InfoPointsNearDetectedSoilSlips{i1} = cell(size(CoordDetSoilSlip,1), 7); % Array initialization

        Options = {'Circle', 'ImportPolygons'};
        MethodForNearPoints = uiconfirm(Fig, ['How do you want to define area to average for file "', ...
                                              char(FilesDetectedSoilSlip(i1)),'"?'], ...
                                             'Sub areas', 'Options',Options);
        switch MethodForNearPoints
            case 'Circle'
                AreaRadius = str2double(inputdlg(['Set radius [m] that will include points for file n. ',num2str(i1)], '', 1, {'100'}));
    
            case 'ImportPolygons'
                cd(fold_var)
                if exist('SoilSlipPolygonsStudyArea.mat', 'file')
                    load('SoilSlipPolygonsStudyArea.mat', 'IDsAllUnique','IDsPolygonsStudyArea')
                else
                    error('You have to import the shapefile first (C_DetectedSoilSLips.m script)')
                end
                IDsDetSoilSlip = DetSSData(2:end,2);
                cd(fold_raw_det_ss)
        end
    end

    %% Processing
    for i2 = 1:size(CoordDetSoilSlip,1)
        InfoDetectedSoilSlips{i1}{i2,1} = Municipalities{i2};
        InfoDetectedSoilSlips{i1}{i2,2} = Locations{i2};
    
        Point1 = CoordDetSoilSlip(i2,:);
    
        Distance = cellfun(@(x) pdist2(x,Point1), GridPointsStudyCat, 'UniformOutput',false); 
        MinDistanceInEachDTM = cellfun(@min, Distance, 'UniformOutput',false);
        MinDistanceAll = min([MinDistanceInEachDTM{:}]);
    
        CheckDTMIncludingPoint = cellfun(@(x) x==MinDistanceAll, MinDistanceInEachDTM, 'UniformOutput',false);
    
        tf = cellfun(@isempty, CheckDTMIncludingPoint);
        CheckDTMIncludingPoint(tf) = {0}; % Zeros when Index are empty
    
        DTMIncludingPoint = find([CheckDTMIncludingPoint{:}]);
        InfoDetectedSoilSlips{i1}{i2,3} = DTMIncludingPoint;
    
        CheckNearestPoint = cellfun(@(x) x==MinDistanceAll, Distance(DTMIncludingPoint), 'UniformOutput',false);
        NearestPoint = find([CheckNearestPoint{:}]); % This is an index of indices
        InfoDetectedSoilSlips{i1}{i2,4} = NearestPoint;
    
        InfoDetectedSoilSlips{i1}{i2,5} = xLongStudy{DTMIncludingPoint}(NearestPoint);
        InfoDetectedSoilSlips{i1}{i2,6} = yLatStudy{DTMIncludingPoint}(NearestPoint);
    
        if SubArea
            switch MethodForNearPoints
                case 'Circle'
                    dLatRadius  = rad2deg(AreaRadius/2/earthRadius); % /2 to have half of the size from the centre
                    dLongRadius = rad2deg(acos( (cos(AreaRadius/2/earthRadius)-sind(yLatMean)^2)/cosd(yLatMean)^2 )); % /2 to have half of the size from the centre
    
                    Angles       = linspace(0, 2*pi, 50);
                    xLongEllTemp = dLongRadius*cos(Angles) + InfoDetectedSoilSlips{i1}{i2,5};
                    yLatEllTemp  = dLatRadius*sin(Angles)  + InfoDetectedSoilSlips{i1}{i2,6};

                    PolTemp = polyshape(xLongEllTemp, yLatEllTemp);

                    InfoDetectedSoilSlipsAverage{i1}{1}(i2) = PolTemp;
    
                case 'ImportPolygons'
                    CurrID = IDsDetSoilSlip{i2};
                    IndCurrID = find(strcmp(CurrID, IDsAllUnique));

                    PolTemp = IDsPolygonsStudyArea(IndCurrID);

                    InfoDetectedSoilSlipsAverage{i1}{1}(i2) = PolTemp;
            end

            [pp2, ee2] = getnan2([PolTemp.Vertices; nan, nan]);
            NearestPoints   = cellfun(@(x) find(inpoly(x, pp2,ee2)), GridPointsStudyCat, 'UniformOutput',false); % These are indices of indices
            DTMIntersecated = find(~cellfun(@isempty, NearestPoints)); % Check where is NOT empty thanks to ~
            InfoPointsNearDetectedSoilSlips{i1}(i2,1:3) = {Municipalities{i2}; Locations{i2}; Point1};
            
            OverlapDTMs = false; % GIVE THE CHOICE TO USER!!
            if OverlapDTMs
                InfoPointsNearTemp = [repmat(DTMIntersecated(1),size(NearestPoints{DTMIntersecated(1)})), ...
                                      NearestPoints{DTMIntersecated(1)}];
                if length(DTMIntersecated)>1
                    for i3 = 2:length(DTMIntersecated)
                        InfoPointsNearTemp = [ InfoPointsNearTemp;
                                              [repmat(DTMIntersecated(i3),size(NearestPoints{DTMIntersecated(i3)})), NearestPoints{DTMIntersecated(i3)}] ];
                    end
                end
                InfoPointsNearDetectedSoilSlips{i1}{i2,4} = num2cell(InfoPointsNearTemp);
            else  
                [~, DTMWithMorePoints] = max(cellfun(@length, NearestPoints));
                InfoPointsNearDetectedSoilSlips{i1}{i2,4} = num2cell( [repmat(DTMWithMorePoints,size(NearestPoints{DTMWithMorePoints})), ...
                                                                       NearestPoints{DTMWithMorePoints}] );
            end
        end

    end
end

%% Adding variables names to save
VariablesInfoDet = [VariablesInfoDet, {'InfoDetectedSoilSlips'}];
if SubArea
    VariablesInfoDet = [VariablesInfoDet, {'InfoPointsNearDetectedSoilSlips', 'InfoDetectedSoilSlipsAverage'}];
end

%% Saving...
ProgressBar.Message = 'Saving...';
cd(fold_var)
save('InfoDetectedSoilSlips.mat', VariablesInfoDet{:})
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in standalone version