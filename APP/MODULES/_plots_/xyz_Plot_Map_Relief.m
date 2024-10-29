if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;
load([fold_var,sl,'StudyAreaVariables.mat'  ], 'StudyAreaPolygon','MunPolygon')
load([fold_var,sl,'GridCoordinates.mat'     ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'MorphologyParameters.mat'], 'ElevationAll','OriginallyProjected','SameCRSForAll')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SlFont = Font;
    SlFnSz = FontSize;
    if exist('LegendPosition', 'var'); LegPos = LegendPosition; else; LegPos = 'Best'; end
else
    SlFont = 'Calibri';
    SlFnSz = 8;
    LegPos = 'Best';
end

InfoDetExst = false;
if exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDet2Use = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetExst = true;
end

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon);

%% Options
PltOpAns = checkbox2({'Gray plot', 'Show municipalities', 'Show plots', ...
                      'Group years'}, 'DefInp',[0, 1, 0, 0], 'OutType','LogInd');

GrayPlot = PltOpAns(1);
ShowMuns = PltOpAns(2);
ShowPlot = PltOpAns(3);
GrpYears = PltOpAns(4);

if any(isnat(InfoDet2Use{:,'Datetime'}))
    warning('Some NaT datetimes were found! They will be replaced with the input prompt.')
    Dttm2Use = datetime(inputdlg2({'Datetime of this dataset:'}, 'DefInp',{'dd-mm-yyyy'}), 'InputFormat','dd-MM-yyyy');
    InfoDet2Use{isnat(InfoDet2Use{:,'Datetime'}),'Datetime'} = repmat(Dttm2Use, sum(isnat(InfoDet2Use{:,'Datetime'})), 1);
end

%% Group years
DetYears = num2cell(unique(year(InfoDet2Use{:,'Datetime'}))); % The default if no grouping
if GrpYears
    BinsNumb = int64(str2double(inputdlg2({'Number of gropus (max 18):'}, 'DefInp',{'4'})));
    if (BinsNumb < 1) || (BinsNumb > 18)
        error('Number of groups outside the range [1, 18]!')
    end
    YrsToUse = cell2mat(DetYears);
    DetYears = cell(1, BinsNumb); % The eventual grouped one
    for i1 = 1:BinsNumb
        if isempty(YrsToUse)
            error(['No elements left for your group n. ',num2str(i1)])
        end
        Ind2Take = checkbox2(string(YrsToUse), 'OutType','NumInd');
        DetYears{i1} = YrsToUse(Ind2Take);
        YrsToUse(Ind2Take) = [];
    end
end

IdsDetXYr = cellfun(@(x) ismember(year(InfoDet2Use{:,'Datetime'}), x), DetYears, 'UniformOutput',false);

YearColor = {"#a2142f", "#4dbeee", "#77ac30", "#7e2f8e", "#edb120", "#d95319", "#0072bd", "#7d00d9", "#88b9c5", ...
             "#998866", "#ff0084", "#ffe0bd", "#8b7b8b", "#ff0062", "#ffd1d9", "#effefe", "#f2eedf", "#000080"};

%% Merge DTMs
ProgressBar.Message = "Merging DTMs...";

if OriginallyProjected && SameCRSForAll
    load([fold_var,sl,'MorphologyParameters.mat'], 'OriginalProjCRS')

    ProjCRS = OriginalProjCRS;
else
    EPSG = str2double(inputdlg2({'Set DTM EPSG (Sicily -> 32633, Emilia Romagna -> 25832)'}, 'DefInp',{'25832'}));
    ProjCRS = projcrs(EPSG);
end

[xPlanAll, yPlanAll, dx, dy] = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    [xPlanAll{i1}, yPlanAll{i1}] = projfwd(ProjCRS, yLatAll{i1}, xLongAll{i1});

    dx{i1} = abs(xPlanAll{i1}(ceil(end/2),2)-xPlanAll{i1}(ceil(end/2),1));
    dy{i1} = abs(yPlanAll{i1}(1,ceil(end/2))-yPlanAll{i1}(2,ceil(end/2)));
end

dxMean = mean([dx{:}]); dyMean = mean([dy{:}]);

xPlanMin = min(cellfun(@(x) min(x, [], 'all'), xPlanAll));
xPlanMax = max(cellfun(@(x) max(x, [], 'all'), xPlanAll));
yPlanMin = min(cellfun(@(x) min(x, [], 'all'), yPlanAll));
yPlanMax = max(cellfun(@(x) max(x, [], 'all'), yPlanAll));
[xPlanMerged, yPlanMerged] = meshgrid(xPlanMin:dxMean:xPlanMax, yPlanMax:-dyMean:yPlanMin);

xPlanAllCat = cellfun(@(x) x(:), xPlanAll, 'UniformOutput',false);
xPlanAllCat = cat(1, xPlanAllCat{:});
yPlanAllCat = cellfun(@(x) x(:), yPlanAll, 'UniformOutput',false);
yPlanAllCat = cat(1, yPlanAllCat{:});
ElevAllCat  = cellfun(@(x) x(:), ElevationAll, 'UniformOutput',false);
ElevAllCat  = cat(1, ElevAllCat{:});

ElevInterpModel = scatteredInterpolant(xPlanAllCat, yPlanAllCat, double(ElevAllCat), 'nearest');

ElevationMerged    = zeros(size(xPlanMerged));
ElevationMerged(:) = ElevInterpModel(xPlanMerged(:), yPlanMerged(:));

%% Elaboration of relief shaded plot
ProgressBar.Message = "Processing of shaded colors...";

Temp = dem(mean(xPlanMerged, 1), mean(yPlanMerged, 2), ElevationMerged, 'Azimuth',-30, ...
                                                                        'Contrast',1, 'Lake', ...
                                                                        'NoDecim', 'noplot');

ShdColorsMerged = Temp.rgb;
clear('Temp')

RedTemp   = ShdColorsMerged(:,:,1);
GreenTemp = ShdColorsMerged(:,:,2);
BlueTemp  = ShdColorsMerged(:,:,3);

IndColorsMdl = scatteredInterpolant(xPlanMerged(:), yPlanMerged(:), (1:numel(xPlanMerged))', 'nearest'); % You could also use directly ShdColorsMerged but in this way you will have consistency (waiting a little bit ;) )

[yLatMerged, xLongMerged] = projinv(ProjCRS, xPlanMerged, yPlanMerged);

[pp1, ee1] = getnan2([StudyAreaPolygon.Vertices; nan, nan]);
IndPointsInSA = inpoly([xLongMerged(:), yLatMerged(:)], pp1, ee1);

RedTemp(not(IndPointsInSA))   = 1;
GreenTemp(not(IndPointsInSA)) = 1;
BlueTemp(not(IndPointsInSA))  = 1;

ShdColorsMerged(:,:,1) = RedTemp;
ShdColorsMerged(:,:,2) = GreenTemp;
ShdColorsMerged(:,:,3) = BlueTemp;

ShdColorsAll = deal(cell(size(xLongAll)));
for i1 = 1:length(xLongAll)
    IdxToUse = IndColorsMdl(xPlanAll{i1}(:), yPlanAll{i1}(:));

    ShdColorsAll{i1}    = zeros(size(xLongAll{i1}, 1), size(xLongAll{i1}, 2), 3);
    ShdColorsAll{i1}(:) = [RedTemp(IdxToUse); GreenTemp(IdxToUse); BlueTemp(IdxToUse)];
    if GrayPlot
        ShdColorsAll{i1} = repmat(rgb2gray(ShdColorsAll{i1}), 1, 1, 3);
    end
end

%% Plot
ProgressBar.Message = "Plotting...";

filename1 = 'Hillshade';
curr_fig  = figure('Visible','off');
curr_ax   = axes('Parent',curr_fig); 
hold(curr_ax,'on');

if GrayPlot
    filename1 = [filename1,'BW'];
end

set(curr_fig, 'Name',filename1);

for i1 = 1:length(xLongAll)
    imagesc(curr_ax, xLongAll{i1}(:), yLatAll{i1}(:), ShdColorsAll{i1});
end

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5, 'Parent',curr_ax)
if ShowMuns
    plot(MunPolygon, 'FaceColor','none', 'LineWidth',1, 'Parent',curr_ax)
end

fig_settings(fold0)

if InfoDetExst
    hDet = cell(1, length(IdsDetXYr));
    for i1 = 1:length(IdsDetXYr)
        hDet{i1} = arrayfun(@(x,y) scatter(x, y, DetPixelSize, 'filled', 'MarkerFaceColor',YearColor{i1}, ...
                                                               'Marker','o', 'MarkerEdgeColor','k', ...
                                                               'LineWidth',PixelSize, 'Parent',curr_ax), ...
                                              InfoDet2Use{IdsDetXYr{i1},'Longitude'}, ...
                                              InfoDet2Use{IdsDetXYr{i1},'Latitude' });
        uistack(hDet{i1},'top')
    end
end

if exist('LegPos', 'var')
    LegendObjects = {};
    LegendCaption = {};

    if InfoDetExst
        LegendObjects = [LegendObjects; cellfun(@(x) x(1), hDet, 'UniformOutput',false)'];
        LegendCaption = [LegendCaption; cellstr(strcat("Landslides Year ", cellfun(@(x) strcat(string(x(1))," - ",string(x(end))), DetYears)))'];
    end

    hLeg = legend([LegendObjects{:}], ...
                   LegendCaption, ...
                  'NumColumns',2, ...
                  'FontName',SlFont, ...
                  'FontSize',0.7*SlFnSz, ...
                  'Location',LegPos, ...
                  'Box','off');
    
    legend('AutoUpdate','off');
    hLeg.ItemTokenSize(1) = 5;
    
    title(hLeg, 'Hillshade plot', 'FontName',SlFont, 'FontSize',SlFnSz*1.2, 'FontWeight','bold')

    fig_rescaler(curr_fig, hLeg, LegPos)

end

set(curr_ax, 'visible','off')

if ShowPlot
    set(curr_fig, 'visible','on');
    pause
end

%% Saving
ProgressBar.Message = "Saving...";

exportgraphics(curr_fig, [fold_fig,sl,filename1,'.png'], 'Resolution',600);

close(curr_fig)