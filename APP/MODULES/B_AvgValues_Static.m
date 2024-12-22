if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% Reading files
sl = filesep;
load([fold_var,sl,'StudyAreaVariables.mat'   ], 'MunPolygon')
load([fold_var,sl,'UserStudyArea_Answers.mat'], 'MunSel')
load([fold_var,sl,'GridCoordinates.mat'      ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'MorphologyParameters.mat' ], 'AspectAngleAll','ElevationAll','SlopeAll', ...
                                                'MeanCurvatureAll','ProfileCurvatureAll','PlanformCurvatureAll')

AvgExist = false;
if exist([fold_var,sl,'AverageValues.mat'], 'file')
    AvgExist = true;
    load([fold_var,sl,'AverageValues.mat'], 'AvgValsStatic')
    if exist('AvgValsStatic', 'var')
        OverwriteAns = uiconfirm(Fig, ['Average of static properties already exist. ' ...
                                       'Do you want to overwrite it?'], ...
                                      'Overwrite', 'Options',{'Yes', 'No'}, 'DefaultOption',2);
        if strcmp(OverwriteAns, 'No')
            return
        end
    end
end

AvgValsStatic = table('RowNames',{'Content','OrigSource'});

%% Preliminary operations
ContName = {'AspectAngle', 'Elevation', 'Slope'};
ContData = {AspectAngleAll, ElevationAll, SlopeAll};

if exist('MeanCurvatureAll', 'var')
    ContName = [ContName, {'MainCurv', 'ProfCurv', 'PlanCurv'}];
    ContData = [ContData, {MeanCurvatureAll, ProfileCurvatureAll, PlanformCurvatureAll}];
end

FileRead = repmat({[fold_var,sl,'MorphologyParameters.mat']}, 1, numel(ContData));

%% Extraction and average of values
ProgressBar.Message = 'Indexing points...';

[ppMun, eeMun, IndDTMPointsInMuns] = deal(cell(1, numel(MunPolygon)));
for i1 = 1:numel(MunPolygon)
    [ppMun{i1}, eeMun{i1}] = getnan2([MunPolygon(i1).Vertices; nan, nan]);
    IndDTMPointsInMuns{i1} = cell(1, numel(xLongAll));
    for i2 = 1:numel(xLongAll)
        IndDTMPointsInMuns{i1}{i2} = find(inpoly([xLongAll{i2}(:), yLatAll{i2}(:)], ppMun{i1}, eeMun{i1})==1);
    end
end

for i1 = 1:numel(ContData)
    ProgressBar.Message = ['Processing static feature ',num2str(i1),' of ',num2str(numel(ContName))];

    ContStudy = cellfun(@(x,y) x(y), ContData{i1}, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
    ContStCat = cat(1, ContStudy{:});
    ContStCat(isnan(ContStCat) | isinf(ContStCat)) = [];
    AvgValStA = mean(ContStCat);

    AvgValMns = zeros(1, numel(MunPolygon));
    for i2 = 1:numel(MunPolygon)
        ContMunic = cellfun(@(x,y) x(y), ContData{i1}, IndDTMPointsInMuns{i2}, 'UniformOutput',false);
        ContMnCat = cat(1, ContMunic{:});
        ContMnCat(isnan(ContMnCat) | isinf(ContMnCat)) = [];
        AvgValMns(i2) = mean(ContMnCat);
    end

    AvgValsTbl = array2table([AvgValStA, AvgValMns], 'VariableNames',[{'StudyArea'}, reshape(MunSel, 1, numel(MunSel))]);
    
    AvgValsStatic({'Content','SourceFile'}, ContName(i1)) = {AvgValsTbl; FileRead(i1)};
end

%% Saving
ProgressBar.Message = 'Saving...';

if AvgExist
    save([fold_var,sl,'AverageValues.mat'], 'AvgValsStatic', '-append')
else
    save([fold_var,sl,'AverageValues.mat'], 'AvgValsStatic')
end