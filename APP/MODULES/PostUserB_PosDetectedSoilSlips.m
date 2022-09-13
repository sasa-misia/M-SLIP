cd(fold_var)
load('GridCoordinates.mat');

cd(fold_raw_det_ss)
Files = {dir('*.xlsx').name};
Choice = listdlg('PromptString',{'Choose a file:',''},'ListString',Files);
FileDetectedSoilSlip = string(Files(Choice)); 

detssData = readcell(FileDetectedSoilSlip);
EmptyPositions = cellfun(@(x) all(ismissing(x)), detssData);
detssData(EmptyPositions) = {'Not specified'};

Municipalities = detssData(2:end,1);
Locations = detssData(2:end,2);

Coordinates_DetectedSoilSlip = flip( ...
                                    reshape( ...
                                            [detssData{cellfun(@isnumeric,detssData)}], ...
                                            [], 2), 2);

LocationSs = string(detssData(2:end,2));
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

% Fig = uifigure; % Remember to comment if in app version
Options = {'Yes', 'No'};
ChoiceSubArea = uiconfirm(Fig, 'Would you like to create a sub area for each point detected?', ...
                               'Sub areas', 'Options',Options);
if strcmp(ChoiceSubArea,'Yes'); ChoiceSubArea = true; else; ChoiceSubArea = false; end
if ChoiceSubArea
    InfoPointsNearDetectedSoilSlips = cell(size(Coordinates_DetectedSoilSlip,1), 4);
    AreaRadius = km2deg(str2double(inputdlg("Set radius that will include points (m)", '', 1, {'100'}))/1000);
    VariablesInfoDet = [VariablesInfoDet, {'InfoPointsNearDetectedSoilSlips'}];
end

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

    if ChoiceSubArea
        CheckNearestPoints = cellfun(@(x) x<=AreaRadius, Distance(DTMIncludingPoint), 'UniformOutput',false);
        NearestPoints = find([CheckNearestPoints{:}]);
        InfoPointsNearDetectedSoilSlips(i1,1:3) = {Municipalities{i1}; Locations{i1}; Point1};
        InfoPointsNearDetectedSoilSlips{i1,4} = num2cell([repmat(DTMIncludingPoint,size(NearestPoints)), NearestPoints]);
    end

end

cd(fold_var)
save('InfoDetectedSoilSlips.mat', VariablesInfoDet{:})
cd(fold0)