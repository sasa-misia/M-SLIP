% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Reading data', ...
                                 'Message','Reading files...', 'Cancelable','off', ...
                                 'Indeterminate','on');
drawnow

%% Loading Files
cd(fold_var)
load('GridCoordinates.mat')
load('StudyAreaVariables.mat', 'StudyAreaPolygonClean')

cd(fold_raw_det_ss)
Files = {dir('*.xlsx').name};
Choice = listdlg('PromptString',{'Choose a file:',''},'ListString',Files);
FileDetectedSoilSlip = string(Files(Choice));

drawnow % Remember to remove if in Standalone version
figure(Fig) % Remember to remove if in Standalone version

%% Data extraction
ProgressBar.Message = 'Data extraction...';

detssData = readcell(FileDetectedSoilSlip);
EmptyPositions = cellfun(@(x) all(ismissing(x)), detssData);
detssData(EmptyPositions) = {'Not specified'};

Municipalities = detssData(2:end,1);
Locations = detssData(2:end,2);

Coordinates_DetectedSoilSlip = flip( ...
                                    reshape( ...
                                            [detssData{cellfun(@isnumeric,detssData(:,1:5))}], ...
                                            [], 2), 2);

%% Prcessing
ProgressBar.Message = 'Processing...';
[pp1, ee1] = getnan2([StudyAreaPolygonClean.Vertices; nan, nan]);
IndexPointsInsideStudyArea = find(inpoly([Coordinates_DetectedSoilSlip(:,1), Coordinates_DetectedSoilSlip(:,2)], pp1, ee1)==1);

if length(IndexPointsInsideStudyArea) ~= length(Municipalities)
    DeletedPoints = length(Municipalities)-length(IndexPointsInsideStudyArea);
    warning(strcat(string(DeletedPoints),' points were deleted!'))
end

Municipalities = Municipalities(IndexPointsInsideStudyArea);
Locations = Locations(IndexPointsInsideStudyArea);
Coordinates_DetectedSoilSlip = Coordinates_DetectedSoilSlip(IndexPointsInsideStudyArea, :);

% LocationSs = string(detssData(2:end,2)); % Maybe not necessary
% dateSs = detssData(2:end,5); % Maybe not necessary

xLongStudy = cellfun(@(x,y) x(y), xLongAll, ...
                                  IndexDTMPointsInsideStudyArea, ...
                                  'UniformOutput',false);

yLatStudy = cellfun(@(x,y) x(y), yLatAll, ...
                                 IndexDTMPointsInsideStudyArea, ...
                                 'UniformOutput',false);

GridPointsAll = cellfun(@(x,y) cat(2,x,y), xLongStudy, ...
                                           yLatStudy, ...
                                           'UniformOutput',false);

VariablesInfoDet = {'InfoDetectedSoilSlips', 'ChoiceSubArea'};

Options = {'Yes', 'No'};
ChoiceSubArea = uiconfirm(Fig, 'Would you like to create a sub area for each point detected?', ...
                               'Sub areas', 'Options',Options);
if strcmp(ChoiceSubArea,'Yes'); ChoiceSubArea = true; else; ChoiceSubArea = false; end
if ChoiceSubArea
    InfoDetectedSoilSlipsAverage = cell(1,2);
    InfoPointsNearDetectedSoilSlips = cell(size(Coordinates_DetectedSoilSlip,1), 7);

    AreaRadius = str2double(inputdlg("Set radius that will include points (m)", '', 1, {'100'}));
    AreaRadiusDegree = km2deg(AreaRadius/1000);
    InfoDetectedSoilSlipsAverage{1} = AreaRadius;
    VariablesInfoDet = [VariablesInfoDet, {'InfoPointsNearDetectedSoilSlips', 'InfoDetectedSoilSlipsAverage'}];
end

InfoDetectedSoilSlips = cell(size(Coordinates_DetectedSoilSlip,1), 19);
for i1 = 1:size(Coordinates_DetectedSoilSlip,1)

    InfoDetectedSoilSlips{i1,1} = Municipalities{i1};
    InfoDetectedSoilSlips{i1,2} = Locations{i1};

    Point1 = Coordinates_DetectedSoilSlip(i1,:);

    Distance = cellfun(@(x) pdist2(x,Point1), GridPointsAll, 'UniformOutput',false); 
    MinDistanceInEachDTM = cellfun(@min, Distance, 'UniformOutput',false);
    MinDistanceAll = min([MinDistanceInEachDTM{:}]);

    CheckDTMIncludingPoint = cellfun(@(x) x==MinDistanceAll, MinDistanceInEachDTM, 'UniformOutput',false);

    tf = cellfun(@isempty, CheckDTMIncludingPoint);
    CheckDTMIncludingPoint(tf) = {0}; % Zeros when Index are empty

    DTMIncludingPoint = find([CheckDTMIncludingPoint{:}]);
    InfoDetectedSoilSlips{i1,3} = DTMIncludingPoint;

    CheckNearestPoint = cellfun(@(x) x==MinDistanceAll, Distance(DTMIncludingPoint), 'UniformOutput',false);
    NearestPoint = find([CheckNearestPoint{:}]);
    InfoDetectedSoilSlips{i1,4} = NearestPoint;

    InfoDetectedSoilSlips{i1,5} = xLongStudy{DTMIncludingPoint}(NearestPoint);
    InfoDetectedSoilSlips{i1,6} = yLatStudy{DTMIncludingPoint}(NearestPoint);

    if ChoiceSubArea
        DTMIntersecated = find(cellfun(@(x) any(x<=AreaRadiusDegree), Distance));
        NearestPoints = cellfun(@(x) find(x<=AreaRadiusDegree), Distance, 'UniformOutput',false);
        InfoPointsNearDetectedSoilSlips(i1,1:3) = {Municipalities{i1}; Locations{i1}; Point1};
        
        OverlapDTMs = false; % GIVE THE CHOICE TO USER!!
        if OverlapDTMs
            InfoPointsNearTemp = [repmat(DTMIntersecated(1),size(NearestPoints{DTMIntersecated(1)})), ...
                                  NearestPoints{DTMIntersecated(1)}];
            if length(DTMIntersecated)>1
                for i2 = 2:length(DTMIntersecated)
                    InfoPointsNearTemp = [ InfoPointsNearTemp;
                                          [repmat(DTMIntersecated(i2),size(NearestPoints{DTMIntersecated(i2)})), NearestPoints{DTMIntersecated(i2)}] ];
                end
            end

            InfoPointsNearDetectedSoilSlips{i1,4} = num2cell(InfoPointsNearTemp);

        else
            
            [~, DTMWithMorePoints] = max(cellfun(@length, NearestPoints));
            InfoPointsNearDetectedSoilSlips{i1,4} = num2cell( [repmat(DTMWithMorePoints,size(NearestPoints{DTMWithMorePoints})), ...
                                                               NearestPoints{DTMWithMorePoints}] );
        end
    end

end

%% Saving...
ProgressBar.Message = 'Saving...';
cd(fold_var)
save('InfoDetectedSoilSlips.mat', VariablesInfoDet{:})
cd(fold0)
close(ProgressBar) % Fig instead of ProgressBar if in standalone version