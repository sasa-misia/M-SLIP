if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% Reading files
sl = filesep;
load([fold0,sl,'os_folders.mat'              ], 'fold_raw_avg')
load([fold_var,sl,'StudyAreaVariables.mat'   ], 'StudyAreaPolygonClean','MunPolygon')
load([fold_var,sl,'UserStudyArea_Answers.mat'], 'MunSel')

if exist([fold_var,sl,'AverageValues.mat'], 'file')
    load([fold_var,sl,'AverageValues.mat'], 'AverageValues')
else
    AverageValues = table('RowNames',{'Content','OrigSource','CopyInAvg'});
end

PthFldRasts = uigetdir(pwd, 'Choose folders with rasters');
FilesInFold = { dir([PthFldRasts,sl,'*.tif']).name, ...
                dir([PthFldRasts,sl,'*.nc' ]).name }; % UP TO NOW YOU CAN USE ONLY GEOTIFF AND NC!!!
FilesToRead = strcat(PthFldRasts,sl,checkbox2(FilesInFold, 'Title',{'Files with same data:'}));

%% Options
ProgressBar.Message = 'Options...';

MsrdValInFl = char(inputdlg2({'Content of files?'}, 'DefInp',{'NDVI'}));

Patt2Search = {digitsPattern(2) + wildcardPattern(1) + digitsPattern(2) + wildcardPattern(1) + digitsPattern(4) + ...
               wildcardPattern(1) + ...
               digitsPattern(2) + wildcardPattern(1) + digitsPattern(2) + wildcardPattern(1) + digitsPattern(4), ...
               digitsPattern(7)};

%% Extraction and average of values
PolyMask = StudyAreaPolygonClean;
[ppSA, eeSA] = getnan2([PolyMask.Vertices; nan, nan]);

[ppMun, eeMun] = deal(cell(1, length(MunPolygon)));
for i1 = 1:length(MunPolygon)
    PolygonMaskMun = MunPolygon(i1);
    [ppMun{i1}, eeMun{i1}] = getnan2([PolygonMaskMun.Vertices; nan, nan]);
end

Flds2Read = {}; EPSGCode = [];
AvgValSA  = zeros(length(FilesToRead), 1);
AvgValMns = zeros(length(FilesToRead), length(MunPolygon));
[DateStrt, ...
    DateEnd] = deal(NaT(length(FilesToRead), 1));
ProgressBar.Indeterminate = 'off';
for i1 = 1:length(FilesToRead)
    ProgressBar.Message = ['Computing average NDVI for file n. ',num2str(i1),' of ',num2str(length(FilesToRead))];
    ProgressBar.Value   = i1/length(FilesToRead);

    [~, TmpNm] = fileparts(FilesToRead(i1));
    NumPttrns  = cellfun(@(x) extract(TmpNm, x), Patt2Search, 'UniformOutput',false);
    
    IndPttDet  = find(not(cellfun(@isempty, NumPttrns)));
    if isempty(IndPttDet)
        error(['The following file doen not contain a pattern like ', ...
               'dd_MM_YYYY-dd_MM_YYYY (start-finish) or YYYYnnn (YYYY ', ...
               'year and nnn number of day, ex. 032 is 1st of february): ',FilesToRead{i1}])
    end

    if any(cellfun(@(x) numel(x) > 1, NumPttrns))
        error('More than one pattern like dd_MM_YYYY-dd_MM_YYYY or YYYYnnn detected!')
    end

    if numel(IndPttDet) > 1
        warning('More type of patterns were detected in filename!')
        IndPttDet = listdlg2({'Correct pattern?'}, NumPttrns(IndPttDet), 'OutType','NumInd');
    end
    
    switch IndPttDet
        case 1
            DateStrt(i1) = datetime([NumPttrns{1}{:}(1:2)  ,'/',NumPttrns{1}{:}(4:5)  ,'/',NumPttrns{1}{:}(7:10) ], 'InputFormat','dd/MM/yyyy');
            DateEnd(i1)  = datetime([NumPttrns{1}{:}(12:13),'/',NumPttrns{1}{:}(15:16),'/',NumPttrns{1}{:}(18:21)], 'InputFormat','dd/MM/yyyy');

        case 2
            DateStrt(i1) = datetime(['01/01/',NumPttrns{2}{:}(1:4)], 'InputFormat','dd/MM/yyyy') + days(str2double(NumPttrns{2}{:}(5:7)) - 1);
            DateEnd(i1)  = DateStrt(i1) + days(1);

        otherwise
            error('Pattern type not yet implemented! Contact support...')
    end

    if DateEnd(i1) <= DateStrt(i1)
        error(['The following file contains an end data < than the start: ',FilesToRead{i1}])
    end

    [RastValues, RastRef, RasterInfo, ...
        EPSGCode, Flds2Read] = readgeorast2(FilesToRead(i1), 'OutputType','native', ...
                                                             'FieldNC',Flds2Read, 'EPSG',EPSGCode);
        
    if RastRef.CoordinateSystemType == "planar"
        [xPlnRast, yPlnRast] = worldGrid(RastRef);
        [yLatRast, xLonRast] = projinv(RastRef.ProjectedCRS, xPlnRast, yPlnRast);

    elseif RastRef.CoordinateSystemType == "geographic"
        [yLatRast, xLonRast] = geographicGrid(RastRef);
    end
    
    if isempty(RasterInfo.MissingDataIndicator)
        % NoDataValue = min(RastValues, [], 'all');
        NoDataValue = nan;
    else
        NoDataValue = RasterInfo.MissingDataIndicator;
    end

    if not(exist('RastRefPrev', 'var')) ||  not(isequal(RastRefPrev, RastRef))
        % Study Area
        IndPntsInSA = find( (RastValues(:) ~= NoDataValue) & ...
                            (inpoly([xLonRast(:),yLatRast(:)], ppSA,eeSA)) );

        if isempty(IndPntsInSA)
            [LonCentr, LatCentr] = centroid(StudyAreaPolygonClean);
            Dist = sqrt(sum(([xLonRast(:),yLatRast(:)] - [LonCentr,LatCentr]).^2, 2));
            [~, IndPntsInSA] = min(Dist);
        end
    
        % Municipalities
        IndPntsInMns = cellfun(@(x,y) find((RastValues(:) ~= NoDataValue) & ...
                                           (inpoly([xLonRast(:),yLatRast(:)], x,y))), ...
                                    ppMun, eeMun, 'UniformOutput',false);

        if any(cellfun(@isempty, IndPntsInMns))
            EmptyInds = cellfun(@isempty, IndPntsInMns);
            [LonCenMn, LatCenMn] = arrayfun(@centroid, MunPolygon(EmptyInds));

            Inds2FillTmp = cell(1, length(LonCenMn));
            for i2 = 1:numel(LonCenMn)
                Dist = sqrt(sum(([xLonRast(:),yLatRast(:)] - [LonCenMn(i2),LatCenMn(i2)]).^2, 2));
                [~, Inds2FillTmp{i2}] = min(Dist);
            end

            IndPntsInMns(EmptyInds) = Inds2FillTmp;
        end

        RastRefPrev = RastRef;
    end

    AvgValSA(i1,:)  = mean(double(RastValues(IndPntsInSA)));
    AvgValMns(i1,:) = cellfun(@(x) mean(double(RastValues(x))), IndPntsInMns);
end
ProgressBar.Indeterminate = 'on';

AvgValsTbl = table(DateStrt, DateEnd, AvgValSA, 'VariableNames',{'StartDate', 'EndDate', 'StudyArea'});
AvgValsTbl = [AvgValsTbl, array2table(AvgValMns, 'VariableNames',MunSel')];
AvgValsTbl = sortrows(AvgValsTbl, 'StartDate','ascend');

%% Copy of files inside project directory
ProgressBar.Message = 'Copying files...';

CpyInAvgFld = false;
CntntDirRaw = strcat(fold_raw,sl,{dir(fold_raw).name});
if exist('fold_raw_avg', 'var')
    CntntDirRaw = [CntntDirRaw, strcat(fold_raw_avg,sl,{dir(fold_raw_avg).name})];
end
if not(any(strcmp(PthFldRasts, CntntDirRaw)))
    fold_raw_avg = [fold_raw,sl,'Avg'];
    if not(exist(fold_raw_avg, 'dir'))
        mkdir(fold_raw_avg)
        save([fold0,sl,'os_folders.mat'], 'fold_raw_avg', '-append')
    end
    fold_raw_avg_val = [fold_raw_avg,sl,MsrdValInFl];
    if not(exist(fold_raw_avg_val, 'dir'))
        mkdir(fold_raw_avg_val)
    end
    copyindirectory('all', fold_raw_avg_val, 'mode','multiple', 'file2copy',FilesToRead)
    CpyInAvgFld = true;
end

%% Update of AverageValues
ProgressBar.Message = 'Update of variables...';

AverageValues({'Content','OrigSource','CopyInAvg'}, MsrdValInFl) = {AvgValsTbl; FilesToRead; CpyInAvgFld};

%% Saving
ProgressBar.Message = 'Saving...';

save([fold_var,sl,'AverageValues.mat'], 'AverageValues')