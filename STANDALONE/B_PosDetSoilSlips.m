clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Import and elaboration of data
cd(fold_var)
load('GridCoordinates.mat');

cd(fold_raw_det_ss)
Files = {dir('*.xlsx').name};
Choice = listdlg('PromptString',{'Choose a file:',''}, 'ListString',Files);
FileDetectedSoilSlip = string(Files(Choice)); 
DetSSData = readcell(FileDetectedSoilSlip);
cd(fold0)

Municipalities = DetSSData(2:end,1);
Locations = DetSSData(2:end,2);
LocationSS = string(DetSSData(2:end,2));
DateSS  = DetSSData(2:end,5);

Coordinates_DetectedSoilSlip = reshape([DetSSData{cellfun(@isnumeric, DetSSData)}], [], 2);
Coordinates_DetectedSoilSlip = [Coordinates_DetectedSoilSlip(:,2), Coordinates_DetectedSoilSlip(:,1)];

xLongStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy = cellfun(@(x,y) x(y), yLatAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
GridPointsAll = cellfun(@(x,y) cat(2,x,y), xLongStudy, yLatStudy, 'UniformOutput',false);

for i1 = 1:size(Coordinates_DetectedSoilSlip, 1)
    InfoDetectedSoilSlips{i1,1} = Municipalities{i1};
    InfoDetectedSoilSlips{i1,2} = Locations{i1};

    Point1 = Coordinates_DetectedSoilSlip(i1, :);

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
end

%% Saving..
cd(fold_var)
save('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips')
cd(fold0)