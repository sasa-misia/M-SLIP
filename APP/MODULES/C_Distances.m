if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'   ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'StudyAreaVariables.mat'], 'MaxExtremes','MinExtremes','StudyAreaPolygon')

ProjCRS = load_prjcrs(fold_var);

%% Conversion in planar coordinates
ProgressBar.Message = 'Conversion in planar coordinates...';

[xPlnAll, yPlnAll] = deal(cell(size(xLongAll)));
for i1 = 1:numel(xLongAll)
    [xPlnAll{i1}, yPlnAll{i1}] = projfwd(ProjCRS, yLatAll{i1}, xLongAll{i1});
end

xLonStudy = cellfun(@(x,y) x(y), xLongAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy = cellfun(@(x,y) x(y), yLatAll , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

if numel(xPlnAll) > 1
    [xPlnMrg, yPlnMrg] = fast_merge_dems(xPlnAll, yPlnAll);
else
    xPlnMrg = xPlnAll{1};
    yPlnMrg = yPlnAll{1};
end

dX = abs(mean(diff(xPlnMrg, 1, 2), 'all'));
dY = abs(mean(diff(yPlnMrg, 1, 1), 'all'));

% clear('xLongAll','yLatAll')

%% Options
LoadOld = false;
if exist([fold_var,sl,'Distances.mat'], 'file')
    OldAns = uiconfirm(Fig, ['Distances.mat already exists, do ' ...
                             'you want to expand it or overwrite it?'], 'Old file', ...
                            'Options',{'Expand', 'Overwrite'}, 'DefaultOption',2);
    if strcmp(OldAns,'Expand'); LoadOld = true; end
end

DstMode = 1; % The fastest
if ceil(round(dX)) ~= ceil(round(dY)) % possible problem with DistMode 1
    DstChc = uiconfirm(Fig, ['Distances in direction X are different from Y, ' ...
                             'if you continue the process could be EXTREMELY slow. ' ...
                             'Do you want to continue?'], 'Mismatch X Y', ...
                            'Options',{'Yes', 'No, I will use another DEM'}, 'DefaultOption',2);
    if strcmp(DstChc,'Yes'); DstMode = 2; else; return; end
end

DstOpts = listdlg2({'Interpolation mode:', 'Distance classes:'}, ...
                   {{'nearest', 'linear', 'natural'}, {'Merged', 'Separated'}});

IntMode = DstOpts{1};
if strcmp(DstOpts{2}, 'Merged'); MrgObjD = true; else; MrgObjD = false; end

%% Reading polygons
switch DistType
    case 'ObjShape'
        ProgressBar.Message = 'Reading shapefile...';
        shpObjDstPath = [fold_raw_road,sl,FileName_ObjDst];
        shpInfoObjDst = shapeinfo(shpObjDstPath);
        shpFld4ObjDst = listdlg2({'Field to use: '}, {shpInfoObjDst.Attributes.Name});

        [ObjDstGeo, ObjDstNms] = ...
                polyshapes_from_shapefile(shpObjDstPath, shpFld4ObjDst, ...
                                          polyBound=StudyAreaPolygon, pointsLim=500000, ...
                                          maskOutPoly=false, progDialog=ProgressBar);

    case 'LandUse'
        load([fold_var,sl,'LandUsesVariables.mat'], 'AllLandUnique','LandUsePolygonsStudyArea')

        IndSelLnd = find(ismember(AllLandUnique, SelLndUse));
        if numel(SelLndUse) ~= numel(IndSelLnd)
            error('Some selected land uses were not found in AllLandUnique!')
        end

        ObjDstGeo = LandUsePolygonsStudyArea(IndSelLnd);
        ObjDstNms = cellstr(AllLandUnique(IndSelLnd)); % To ensure it is a cellstring

    otherwise
        error('DistType not recognized!')
end

%% Merging and intersecting
ProgressBar.Message = 'Merging and intersecting polygons...';

ObjDstPln = projfwdpoly(ObjDstGeo, ProjCRS);
ObjDstStA = intersect(ObjDstGeo, StudyAreaPolygon);

if MrgObjD && (numel(ObjDstPln) > 1) % Merging
    if (numel(ObjDstPln) > 500)
        ObjDstPln = fast_union(ObjDstPln);
        ObjDstStA = fast_union(ObjDstStA);
    else
        ObjDstPln = union(ObjDstPln);
        ObjDstStA = union(ObjDstStA);
    end
end

SuggLbl = ObjDstNms;
if numel(ObjDstNms) ~= numel(ObjDstStA)
    SuggLbl = {'Merged class'};
end

ObjDstNmM = inputdlg2(strcat({'Name for polygon '},SuggLbl), 'DefInp',SuggLbl);

%% Calculating distances
ProgressBar.Message = 'Calculating distances...';

Dst2ObjAll = cell(1, numel(ObjDstPln)); % Initializing
for i1 = 1:numel(Dst2ObjAll)
    Dst2ObjAll{i1} = cellfun(@(x) zeros(size(x)), xPlnAll, 'UniformOutput',false); % Initializing
end

switch DstMode
    case 1 % Black-white distance (very fast, but with few points, slower than DstMode 2)
        for i1 = 1:numel(ObjDstPln)
            [ppObj, eeObj] = getnan2([ObjDstPln(i1).Vertices; nan, nan]);
            IndsObj = find(inpoly([xPlnMrg(:),yPlnMrg(:)], ppObj, eeObj));
    
            Rst4Dst = zeros(size(xPlnMrg));
            Rst4Dst(IndsObj) = 1;
    
            ProgressBar.Message = 'Generating interpolation...';
            MinDstM = dX*bwdist(Rst4Dst);
            DstMdlF = scatteredInterpolant(xPlnMrg(:), yPlnMrg(:), double(MinDstM(:)), IntMode);

            for i2 = 1:numel(xLonStudy)
                ProgressBar.Message = ['Distances for class ',num2str(i1),'; DTM ',num2str(i2),' of ',num2str(numel(xLonStudy))];
    
                Dst2ObjAll{i1}{i2}(:) = DstMdlF(xPlnAll{i2}(:), yPlnAll{i2}(:));
            end
        end

    case 2 % Distance from point to poly (exteremly slow with lot of points)
        xPlnStudy = cellfun(@(x,y) x(y), xPlnAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
        yPlnStudy = cellfun(@(x,y) x(y), yPlnAll, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

        ProgressBar.Indeterminate = 'off';
        for i1 = 1:numel(ObjDstPln)
            ProgressBar.Value = i1/numel(ObjDstPln);
            ProgressBar.Message = ['Distances for class ',num2str(i1),' of ',num2str(numel(ObjDstPln))];

            if numel(ObjDstPln(i1).Vertices(:,1)) < 8000
                Dst2ObjStT = cellfun(@(x,y) p_poly_dist( x, y, ObjDstPln(i1).Vertices(:,1), ...
                                                               ObjDstPln(i1).Vertices(:,2) ), ...
                                                   xPlnStudy, yPlnStudy, 'UniformOutput',false);
            else % To avoid "Out of memory" error
                Prt4Grd = 1; % Increase it in case of "Out of memory"
                Pts4Prt = cellfun(@(x) ceil(numel(x)/Prt4Grd), xPlnStudy, 'UniformOutput',false);
                PolyPrt = divide_poly_grids(ObjDstPln(i1), 5, 6); % 30 smaller polygons, instead of 1 too big
                Dst2Prt = cell(Prt4Grd, numel(xLonStudy));
                for i2 = 1:(Prt4Grd)
                    if i2 < Prt4Grd
                        xPlnPrt = cellfun(@(x,y) x( ((i2-1)*y+1) : i2*y ), xPlnStudy, Pts4Prt, 'UniformOutput',false);
                        yPlnPrt = cellfun(@(x,y) x( ((i2-1)*y+1) : i2*y ), yPlnStudy, Pts4Prt, 'UniformOutput',false);
                    else
                        xPlnPrt = cellfun(@(x,y) x( ((i2-1)*y+1) : end ),  xPlnStudy, Pts4Prt, 'UniformOutput',false);
                        yPlnPrt = cellfun(@(x,y) x( ((i2-1)*y+1) : end ),  yPlnStudy, Pts4Prt, 'UniformOutput',false);
                    end
    
                    Dst2PrtTmp = cell(numel(PolyPrt), numel(xPlnPrt));
                    for i3 = 1:numel(PolyPrt)
                        Dst2PrtTmp(i3,:) = cellfun(@(x,y) p_poly_dist( x,y, PolyPrt(i3).Vertices(:,1), ...
                                                                            PolyPrt(i3).Vertices(:,2) ), ...
                                                                xPlnPrt, yPlnPrt, 'UniformOutput',false);
                    end
    
                    for i3 = 1:numel(xLonStudy)
                        Dst2Prt{i2,i3} = min([Dst2PrtTmp{:,i3}], [], 2);
                    end
                end

                Dst2ObjStT = cell(1, numel(xLonStudy));
                for i2 = 1:numel(xLonStudy)
                    Dst2ObjStT{i1} = cat(1, Dst2Prt{:,i2});
                end
            end

            for i2 = 1:numel(xLonStudy)
                Dst2ObjAll{i1}{i2}(IndexDTMPointsInsideStudyArea{i2}) = Dst2ObjStT{i2};
            end
        end
        ProgressBar.Indeterminate = 'on';

    otherwise
        error('Distance Mode not recognized!')
end

%% Plot for check
ProgressBar.Message = 'Plot for check...';

selObj = 1;
if numel(ObjDstStA) > 1
    selObj = listdlg2({'Polygon class to check'}, ObjDstNmM, 'OutType','NumInd');
end

fig_check = figure(2);
axs_check = axes(fig_check);
hold(axs_check,'on')

DistRoadsStudy = cellfun(@(x,y) x(y), Dst2ObjAll{1}, IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
for i1 = 1:numel(xLonStudy)
    fastscatter(xLonStudy{i1}(:), yLatStudy{i1}(:), DistRoadsStudy{i1}(:))
end
colormap(axs_check, flipud(colormap('turbo')))

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',axs_check);
plot(ObjDstStA       , 'FaceColor','none', 'LineWidth',1  , 'Parent',axs_check);

title('Distances to roads check plot')

fig_settings(fold0, 'AxisTick');

%% Creation of table and merge with possible old one
Distances = table('RowNames',{'Objects', 'Distances'});
if LoadOld
    load([fold_var,sl,'Distances.mat'], 'Distances')
end

ObjDstStC = num2cell(ObjDstStA);
Distances = [Distances, ...
    array2table([{ObjDstStC{:}}; Dst2ObjAll], 'RowNames',{'Objects', 'Distances'}, ... % {ObjDstStC{:}} and {ObjDstNmM{:}} is to have them horizontal!
                                              'VariableNames',{ObjDstNmM{:}})];

%% Saving...
ProgressBar.Message = 'Saving...';

VarDstnc = {'Distances'};
VarsUser = {'DistType', 'LoadOld', 'DstMode', 'IntMode', 'MrgObjD', 'FileName_ObjDst'};

saveswitch([fold_var,sl,'Distances.mat'      ], VarDstnc)
save([fold_var,sl,'UserDistances_Answers.mat'], VarsUser{:})