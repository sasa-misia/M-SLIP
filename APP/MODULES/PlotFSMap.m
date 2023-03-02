%% File loading
cd(fold_var)
load('GridCoordinates.mat')
load('SoilParameters.mat')
load('StudyAreaVariables.mat')
load('UserB_Answers.mat', 'OrthophotoAnswer')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    LegendPosition = 'best';
end

InfoDetectedExist = false;
if exist('InfoDetectedSoilSlips.mat', 'file')
    load('InfoDetectedSoilSlips.mat', 'InfoDetectedSoilSlips')
    InfoDetectedExist = true;
end

if OrthophotoAnswer
    load('Orthophoto.mat')
end

%% For scatter dimension
RefStudyArea = 0.035;
% ExtentStudyArea = area(StudyAreaPolygon);
ExtentStudyArea = prod(MaxExtremes-MinExtremes);
RatioRef = ExtentStudyArea/RefStudyArea;
PixelSize = .028/RatioRef;
DetPixelSize = 7.5*PixelSize;

%% Choice of stability type
cd(fold_res_fs)

foldFS = uigetdir('open');
[~,namefoldFS] = fileparts(foldFS);

figure(Fig)
drawnow

cd(foldFS)
load('AnalysisInformation.mat');

EventsAnalysed = string(StabilityAnalysis{:,2});
Choice = listdlg('PromptString',{'Select event analysed to plot:',''}, 'ListString',EventsAnalysed);

figure(Fig)
drawnow

EventFS = datetime(EventsAnalysed(Choice), 'InputFormat','dd/MM/yyyy HH:mm:ss');
IndexFS = hours(EventFS-StabilityAnalysis{2}(1))+1;

% Fig = uifigure; % Remember to comment if in app version
switch StabilityAnalysis{4}(1)
    case "Slip"
        load(strcat('Fs',num2str(IndexFS),'.mat'));

        %% Give a value to NaN and plot them
        MaxFS = cellfun(@max, FactorSafety, 'UniformOutput',false);
        MaxFS = max([MaxFS{:}]);
        NaNFactorSafetyROC = cellfun(@(x) isnan(x), FactorSafety, 'UniformOutput',false);
        for i2 = 1:length(FactorSafety)
            FactorSafety{i2}(NaNFactorSafetyROC{i2}) = MaxFS; % NaN Points are excluded and considered as unconditionally stable
        end

        Fs = FactorSafety;

        InputValues = inputdlg({'Indicate the value above which the point is stable:'
                                'Indicate the value below which the point is unstable (<= than the previous):'},'',1,...
                               {'1.5', '1'});

        figure(Fig)
        drawnow

        MinFSForStability = eval(InputValues{1});
        MaxFSForInstability = eval(InputValues{2});
        FsLow = cellfun(@(x) x<=MaxFSForInstability & x>0, Fs, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x>MinFSForStability, Fs, 'UniformOutput',false);

        Answer = uiconfirm(Fig, 'Do you want the medium class of FS?', ...
                                'Window type', 'Options',{'Yes','No, only High and Low'});
        if string(Answer) == "Yes"
            FsMedium = cellfun(@(x) x>MaxFSForInstability & x<=MinFSForStability, ...
                               Fs, 'UniformOutput',false);
        end

    case "Machine Learning"
        load(strcat('FsML',num2str(IndexFS),'.mat'));
        InstabilityProbabilities = cellfun(@(x) x(:,2), ...
                                                FactorSafetyMachineLearning(2,:), ...
                                                'UniformOutput',false);

        InputValues = inputdlg({'Indicate the probability above which the point is unstable:'
                                ['Indicate the probability below which the point is stable ' ...
                                 '(<= than the previous):']}, '', 1, {'0.8', '0.3'});

        figure(Fig)
        drawnow

        MinProbForInstability = eval(InputValues{1});
        MaxProbForStability = eval(InputValues{2});

        FsLow = cellfun(@(x) x>=MinProbForInstability, InstabilityProbabilities, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x<MaxProbForStability, InstabilityProbabilities, 'UniformOutput',false);

        Answer = uiconfirm(Fig, 'Do you want the medium class of FS?', ...
                                'Window type', 'Options',{'Yes','No, only High and Low'});
        if string(Answer) == "Yes"
            FsMedium = cellfun(@(x) x>=MaxProbForStability & x<MinProbForInstability, ...
                                    InstabilityProbabilities, 'UniformOutput',false);
        end

        case "Hybrid"
        load(strcat('FsH',num2str(IndexFS),'.mat'));
        InstabilityProbabilities = FsHybrid;

        InputValues = inputdlg({'Indicate the probability above which the point is unstable:'
                                ['Indicate the probability below which the point is stable ' ...
                                 '(<= than the previous):']}, '', 1, {'0.8', '0.3'});

        figure(Fig)
        drawnow

        MinProbForInstability = eval(InputValues{1});
        MaxProbForStability = eval(InputValues{2});

        FsLow = cellfun(@(x) x>=MinProbForInstability, InstabilityProbabilities, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x<MaxProbForStability, InstabilityProbabilities, 'UniformOutput',false);

        Answer = uiconfirm(Fig, 'Do you want the medium class of FS?', ...
                                'Window type', 'Options',{'Yes','No, only High and Low'});
        if string(Answer) == "Yes"
            FsMedium = cellfun(@(x) x>=MaxProbForStability & x<MinProbForInstability, ...
                                    InstabilityProbabilities, 'UniformOutput',false);
        end

    otherwise
        error('PLT 1')
end

%% Creation of point included in classes of FS
NumInstabilityPoints = cellfun(@(x) numel(find(x)), FsLow);

IndexStudyAreaLow = cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, FsLow,'UniformOutput',false);
IndexStudyAreaHigh = cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, FsHigh,'UniformOutput',false);

xLongFSLow = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaLow,'UniformOutput',false);
xLongFSHigh = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaHigh,'UniformOutput',false);

yLatFSLow = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaLow,'UniformOutput',false);
yLatFSHigh = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaHigh,'UniformOutput',false);

if exist('FsMedium', 'var') == 1
    IndexStudyAreaMedium = cellfun(@(x,y) x(y), ...
        IndexDTMPointsInsideStudyArea, FsMedium,'UniformOutput',false);
    
    xLongFSMedium = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaMedium,'UniformOutput',false);
    
    yLatFSMedium = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaMedium,'UniformOutput',false);
end

%% Plot of FS figure
filename1 = string(datetime(EventFS,'Format','dd-MM-yyyy HH-mm'));
f1 = figure(1);
ax1 = axes('Parent',f1);
hold(ax1,'on');

set(gcf, 'Name',filename1);

if OrthophotoAnswer
    cellfun(@(x,y) geoshow(x,y), ZOrtho, ROrtho);
end

hSlipLow = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', ...
                                        'MarkerFaceColor',[229 81 55]./255, ...
                                        'MarkerEdgeColor','none'), ...
                            xLongFSLow, yLatFSLow, 'UniformOutput',false);

hSlipHigh = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', ...
                                        'MarkerFaceColor',[189 236 232]./255, ...
                                        'MarkerEdgeColor','none'), ...
                            xLongFSHigh, yLatFSHigh, 'UniformOutput',false);

if InfoDetectedExist
    hdetected = cellfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), ...
                                InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
    % cellfun(@(x,y,z) text(x, y+0.001, z, 'FontName',SelectedFont, 'FontSize',4), ...
    %                   InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6), InfoDetectedSoilSlips(:,2));
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

    AllPlot = {hSlipLow, hSlipMedium, hSlipHigh};
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

if exist('LegendPosition', 'var')
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
                  'Location',LegendPosition, ...
                  'FontName',SelectedFont, ...
                  'FontSize',SelectedFontSize, ...
                  'Box','off');

    legend('AutoUpdate','off');

    fig_rescaler(f1, hleg, LegendPosition)
end

set(gca, 'visible','off')

% hSS113=line(Street(:,1),Street(:,2),'LineWidth',1.5,'Color',[239 239 239]./255);
% hTunnel=line(Street(StartEndPointsTunnel(1):StartEndPointsTunnel(2),1),Street(StartEndPointsTunnel(1):StartEndPointsTunnel(2),2),'LineWidth',4,'Color','c');

% title(strcat("Safety Factors of ",string(EventFS)," event"),...
%             'FontName',SelectedFont,'FontSize',SelectedFontSize*1.4)

%% Export png
cd(fold_fig)
if ~exist(namefoldFS,'dir')
    mkdir(namefoldFS)
end
cd(namefoldFS)
exportgraphics(f1, strcat(filename1,'.png'), 'Resolution',600);
cd(fold0)