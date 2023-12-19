if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'],    'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon')
load([fold_var,sl,'UserMorph_Answers.mat'],  'OrthophotoAnswer')

if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'Font','FontSize','LegendPosition')
    SelFont  = Font;
    SelFntSz = FontSize;
    if exist('LegendPosition','var'); LegPos = LegendPosition; end
else
    SelFont  = 'Times New Roman';
    SelFntSz = 8;
    LegPos   = 'best';
end

InfoDetectedExist = false;
if exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
    InfoDetectedSoilSlipsToUse = InfoDetectedSoilSlips{IndDefInfoDet};
    InfoDetectedExist = true;
end

if OrthophotoAnswer
    load([fold_var,sl,'Orthophoto.mat'], 'ZOrtho','xLongOrtho','yLatOrtho')
end

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'Extremes',true); % 'RefArea',0.035

%% Options
ProgressBar.Message = 'Options...';

foldFS = uigetdir(fold_res_fs, 'Select analysis folder');
[~, namefoldFS] = fileparts(foldFS);

figure(Fig)
drawnow

load([foldFS,sl,'AnalysisInformation.mat'], 'StabilityAnalysis');

EvsAnlyz = string(StabilityAnalysis{:,2});
EventFS  = datetime(listdlg2({'Event to plot:'}, EvsAnlyz), 'InputFormat','dd/MM/yyyy HH:mm:ss');

figure(Fig)
drawnow

IndexFS = hours(EventFS-StabilityAnalysis{2}(1))+1;

ShowPlots = uiconfirm(Fig, 'Do you want to show plots?', ...
                           'Show Plots', 'Options',{'Yes','No'}, 'DefaultOption',2);
if strcmp(ShowPlots,'Yes'); ShowPlots = true; else; ShowPlots = false; end

%% Pre processing
ProgressBar.Message = 'Pre processing...';

switch StabilityAnalysis{4}(1)
    case "Slip"
        %% SLIP
        load([foldFS,sl,'Fs',num2str(IndexFS),'.mat'], 'FactorSafety');

        MaxFS = cellfun(@max, FactorSafety, 'UniformOutput',false);
        MaxFS = max([MaxFS{:}]);
        NaNFactorSafetyROC = cellfun(@(x) isnan(x), FactorSafety, 'UniformOutput',false);
        for i2 = 1:length(FactorSafety)
            FactorSafety{i2}(NaNFactorSafetyROC{i2}) = MaxFS; % NaN Points are excluded and considered as unconditionally stable
        end

        FS = FactorSafety;

        InputValues = inputdlg2({'Value above which the point is stable:', ...
                                 'Value below which the point is unstable:'}, 'DefInp',{'1.5','1'});

        figure(Fig)
        drawnow

        MinFSForStability   = str2double(InputValues{1});
        MaxFSForInstability = str2double(InputValues{2});
        FsLow  = cellfun(@(x) x<=MaxFSForInstability & x>0, FS, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x>MinFSForStability,          FS, 'UniformOutput',false);

        Answer = uiconfirm(Fig, 'Do you want the medium class of FS?', ...
                                'Window type', 'Options',{'Yes','No, only High and Low'});
        if strcmp(Answer,'Yes')
            FsMedium = cellfun(@(x) x>MaxFSForInstability & x<=MinFSForStability, FS, 'UniformOutput',false);
        end

    case "Machine Learning"
        %% ML
        load([foldFS,sl,'FsML',num2str(IndexFS),'.mat'], 'FactorSafetyMachineLearning');
        InstabilityProbabilities = cellfun(@(x) x(:,2), FactorSafetyMachineLearning(2,:), 'UniformOutput',false);

        InputValues = inputdlg2({'Prob above which the point is unstable:', ...
                                 'Prob below which the point is stable:'}, 'DefInp',{'0.8','0.3'});

        figure(Fig)
        drawnow

        MinProbForInstability = str2double(InputValues{1});
        MaxProbForStability   = str2double(InputValues{2});

        FsLow  = cellfun(@(x) x>=MinProbForInstability, InstabilityProbabilities, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x<MaxProbForStability,    InstabilityProbabilities, 'UniformOutput',false);

        Answer = uiconfirm(Fig, 'Do you want the medium class of FS?', ...
                                'Window type', 'Options',{'Yes','No, only High and Low'});
        if strcmp(Answer,'Yes')
            FsMedium = cellfun(@(x) x>=MaxProbForStability & x<MinProbForInstability, ...
                                            InstabilityProbabilities, 'UniformOutput',false);
        end

    case "Hybrid"
        %% Hybrid
        load([foldFS,sl,'FsH',num2str(IndexFS),'.mat'], 'FsHybrid');
        InstabilityProbabilities = FsHybrid;

        InputValues = inputdlg2({'Prob above which the point is unstable:', ...
                                 'Prob below which the point is stable:'}, 'DefInp',{'0.8','0.3'});

        figure(Fig)
        drawnow

        MinProbForInstability = str2double(InputValues{1});
        MaxProbForStability   = str2double(InputValues{2});

        FsLow  = cellfun(@(x) x>=MinProbForInstability, InstabilityProbabilities, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x<MaxProbForStability,    InstabilityProbabilities, 'UniformOutput',false);

        Answer = uiconfirm(Fig, 'Do you want the medium class of FS?', ...
                                'Window type', 'Options',{'Yes','No, only High and Low'});
        if strcmp(Answer,'Yes')
            FsMedium = cellfun(@(x) x>=MaxProbForStability & x<MinProbForInstability, ...
                                    InstabilityProbabilities, 'UniformOutput',false);
        end

    otherwise
        error('Analysis type not recognized!')
end

%% Creation of point included in classes of FS
NumInstabilityPoints = cellfun(@(x) numel(find(x)), FsLow);

IndexStudyAreaLow  = cellfun(@(x,y) x(y), IndexDTMPointsInsideStudyArea, FsLow,  'UniformOutput',false);
IndexStudyAreaHigh = cellfun(@(x,y) x(y), IndexDTMPointsInsideStudyArea, FsHigh, 'UniformOutput',false);

xLongFSLow  = cellfun(@(x,y) x(y), xLongAll, IndexStudyAreaLow,  'UniformOutput',false);
xLongFSHigh = cellfun(@(x,y) x(y), xLongAll, IndexStudyAreaHigh, 'UniformOutput',false);

yLatFSLow  = cellfun(@(x,y) x(y), yLatAll, IndexStudyAreaLow,  'UniformOutput',false);
yLatFSHigh = cellfun(@(x,y) x(y), yLatAll, IndexStudyAreaHigh, 'UniformOutput',false);

if exist('FsMedium', 'var')
    IndexStudyAreaMedium = cellfun(@(x,y) x(y), IndexDTMPointsInsideStudyArea, FsMedium, 'UniformOutput',false);
    
    xLongFSMedium = cellfun(@(x,y) x(y), xLongAll, IndexStudyAreaMedium,'UniformOutput',false);
    yLatFSMedium  = cellfun(@(x,y) x(y), yLatAll,  IndexStudyAreaMedium,'UniformOutput',false);
end

%% Plot of FS figure
ProgressBar.Message = 'Plotting...';

filename1 = char(datetime(EventFS, 'Format','dd-MM-yyyy HH-mm'));
f1  = figure(1);
ax1 = axes('Parent',f1);
hold(ax1,'on');

set(f1, 'Name',filename1, 'Visible','off');
set(ax1, 'visible','off')

if OrthophotoAnswer
    for i1 = 1:numel(ZOrtho)
        fastscattergrid(ZOrtho{i1}, xLongOrtho{i1}, yLatOrtho{i1}, 'Mask',StudyAreaPolygon, ...
                                                                   'Parent',ax1, 'Alpha',.7);
    end
end

hSlipLow  = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', ...
                                                    'MarkerFaceColor',[229 81 55]./255, ...
                                                    'MarkerEdgeColor','none'), ...
                                    xLongFSLow, yLatFSLow, 'UniformOutput',false);

hSlipHigh = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', ...
                                                    'MarkerFaceColor',[189 236 232]./255, ...
                                                    'MarkerEdgeColor','none'), ...
                                    xLongFSHigh, yLatFSHigh, 'UniformOutput',false);

if InfoDetectedExist
    hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                    InfoDetectedSoilSlipsToUse(:,5), InfoDetectedSoilSlipsToUse(:,6));
end

switch StabilityAnalysis{4}(1)
    case "Slip"
        LegendCaption = ([strcat("High Susceptibility ({\itFS} <= ",compose("%4.2f",MaxFSForInstability),")"), ...
                          strcat("Medium Susceptibility (",compose("%4.2f",MaxFSForInstability)," < {\itFS} <= ",compose("%4.2f",MinFSForStability),")"), ...
                          strcat("Low Susceptibility ({\itFS} > ",compose("%4.2f",MinFSForStability),")")]);
    case {"Machine Learning", "Hybrid"}
        LegendCaption = ([strcat("High Susceptibility ({\itProbability} >= ",compose("%4.2f",MinProbForInstability*100),"%)"), ...
                          strcat("Medium Susceptibility (",compose("%4.2f",MaxProbForStability*100),"% <= {\itProbability} < ",compose("%4.2f",MinProbForInstability*100),"%)"), ...
                          strcat("Low Susceptibility ({\itProbability} < ",compose("%4.2f",MaxProbForStability*100),"%)")]);
end

hSlipLowGood = find(~cellfun(@isempty, hSlipLow));
hSlipHighGood = find(~cellfun(@isempty, hSlipHigh));

IndLeg = [any(~cellfun(@isempty, hSlipLow)), ...
          false, ...
          any(~cellfun(@isempty, hSlipHigh))];

AllPlot = {hSlipLow, [], hSlipHigh};
AllPlotGood = {hSlipLowGood, [], hSlipHighGood};

if exist('FsMedium', 'var') == 1
    hSlipMedium = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', ...
                                                          'MarkerFaceColor',[255 255 0]./255, ...
                                                          'MarkerEdgeColor','none'), ...
                                      xLongFSMedium, yLatFSMedium, 'UniformOutput',false);

    hSlipMediumGood = find(~cellfun(@isempty, hSlipMedium));

    IndLeg = [any(~cellfun(@isempty, hSlipLow)), ...
              any(~cellfun(@isempty, hSlipMedium)), ...
              any(~cellfun(@isempty, hSlipHigh))];

    AllPlot     = {hSlipLow, hSlipMedium, hSlipHigh};
    AllPlotGood = {hSlipLowGood, hSlipMediumGood, hSlipHighGood};

    for i1 = 1:length(hSlipLow)
        uistack(hSlipMedium{i1},'top')
    end
end

for i1 = 1:length(hSlipLow)
    uistack(hSlipLow{i1},'top')
end

if InfoDetectedExist
    uistack(hdetected,'top')
end

plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1, 'LineStyle','--')

fig_settings(fold0)

if exist('LegPos', 'var')
    AllPlot = AllPlot(IndLeg);
    AllPlotGood = AllPlotGood(IndLeg);

    LegendObjects = cellfun(@(x,y) x(y(1)), AllPlot, AllPlotGood);
    LegendCaption = cellstr(LegendCaption(IndLeg));

    if InfoDetectedExist
        LegendObjects = [LegendObjects, {hdetected(1)}];
        LegendCaption = [LegendCaption, {"Points Analyzed"}];
    end

    hleg = legend([LegendObjects{:}], ...
                  LegendCaption, ...
                  'Location',LegPos, ...
                  'FontName',SelFont, ...
                  'FontSize',SelFntSz, ...
                  'Box','off');

    legend('AutoUpdate','off');

    fig_rescaler(f1, hleg, LegPos)
end

% title(strcat("Safety Factors of ",string(EventFS)," event"),...
%             'FontName',SelFont,'FontSize',SelFntSz*1.4)

%% Saving...
ProgressBar.Message = 'Saving...';

if ~exist([fold_fig,sl,namefoldFS], 'dir')
    mkdir([fold_fig,sl,namefoldFS])
end

exportgraphics(f1, [fold_fig,sl,namefoldFS,sl,filename1,'.png'], 'Resolution',600);

%% Show Fig
if ShowPlots
    set(f1, 'visible','on');
else
    close(f1)
end