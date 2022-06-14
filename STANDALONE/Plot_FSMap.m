clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Loading file
cd(fold_var)
load('GridCoordinates.mat')
load('SoilParameters.mat')
load('StudyAreaVariables.mat')

if exist('LegendSettings.mat', 'file')
    load('LegendSettings.mat')
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    SelectedLocation = 'Best';
end

%% Loading FS
cd(fold_res_fs)
foldFS = uigetdir('open');
[~,namefoldFS] = fileparts(foldFS);

cd(foldFS)
load('AnalysisInformation.mat');

EventsAnalysed = string(StabilityAnalysis{:,2});
Choice = listdlg('PromptString',{'Select event analysed to plot:',''}, 'ListString',EventsAnalysed);
EventFS = datetime(EventsAnalysed(Choice), 'InputFormat','dd/MM/yyyy HH:mm:ss');
IndexFS = hours(EventFS-StabilityAnalysis{2}(1))+1;
EventFS.Format = 'dd-MM-yyyy-HH-mm';

switch StabilityAnalysis{4}(1)
    case "Slip"
        load(strcat('Fs',num2str(IndexFS),'.mat'));
        Fs = FactorSafety;

        InputValues = inputdlg({'Indicate the value above which the point is stable:'
                                'Indicate the value below which the point is unstable (<= than the previous):'},'',1,...
                               {'1.5', '1'});
        MinFSForStability = eval(InputValues{1});
        MaxFsForInstability = eval(InputValues{2});
        FsLow = cellfun(@(x) x<=MaxFsForInstability & x>0, Fs, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x>MinFSForStability, Fs, 'UniformOutput',false);

        Answer = questdlg('Do you want the medium class of FS?', 'Medium Class', ...
                	      'Yes','No, only High and Low','No, only High and Low');
        if string(Answer) == "Yes"
            FsMedium = cellfun(@(x) x>MaxFsForInstability & x<=MinFSForStability, ...
                               Fs, 'UniformOutput',false);
        end

    case "Machine Learning"
        load(strcat('FsML',num2str(IndexFS),'.mat'));
        Fs = FactorSafetyMachineLearning(1,:);

        FsLow = cellfun(@(x) x==true, Fs, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x==false, Fs, 'UniformOutput',false);

    otherwise
        error('PLT 1')
end

%% Data extraction
NumInstabilityPoints = cellfun(@(x) numel(find(x)), FsLow);
IndexStudyAreaLow = cellfun(@(x,y) x(y), IndexDTMPointsInsideStudyArea, FsLow, 'UniformOutput',false);
IndexStudyAreaHigh = cellfun(@(x,y) x(y), IndexDTMPointsInsideStudyArea, FsHigh, 'UniformOutput',false);

xLongFSLow = cellfun(@(x,y) x(y), xLongAll, IndexStudyAreaLow, 'UniformOutput',false);
xLongFSHigh = cellfun(@(x,y) x(y), xLongAll, IndexStudyAreaHigh, 'UniformOutput',false);

yLatFSLow = cellfun(@(x,y) x(y), yLatAll, IndexStudyAreaLow, 'UniformOutput',false);
yLatFSHigh = cellfun(@(x,y) x(y), yLatAll, IndexStudyAreaHigh, 'UniformOutput',false);

if exist("FsMedium", "var") == 1
    IndexStudyAreaMedium = cellfun(@(x,y) x(y), IndexDTMPointsInsideStudyArea, FsMedium, 'UniformOutput',false);
    xLongFSMedium = cellfun(@(x,y) x(y), xLongAll, IndexStudyAreaMedium, 'UniformOutput',false);
    yLatFSMedium = cellfun(@(x,y) x(y), yLatAll, IndexStudyAreaMedium, 'UniformOutput',false);
end

%% Plotting
filename1 = string(EventFS);
f1 = figure(1);
set(f1 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits','centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition',[0 1 12 6],...
    'InvertHardcopy','off');
set(gcf, 'Name',filename1);

axes1 = axes('Parent',f1); 
hold(axes1,'on');

PixelSize = .2;

hSLIP_Low = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','s', 'MarkerFaceColor',[229 81 55]./255, ...
                    'MarkerEdgeColor','none'), xLongFSLow, yLatFSLow, 'UniformOutput',false);
hSLIP_High = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','s', 'MarkerFaceColor',[189 236 232]./255, ...
                     'MarkerEdgeColor','none'), xLongFSHigh, yLatFSHigh, 'UniformOutput',false);

cd(fold_var)
if exist('InfoDetectedSoilSlips.mat', 'file')
    load('InfoDetectedSoilSlips.mat')
    hdetected = cellfun(@(x,y) scatter(x, y, 5, '^k','Filled'), InfoDetectedSoilSlips(:,5), InfoDetectedSoilSlips(:,6));
    % cellfun(@(x,y,z) text(x,y+0.001,z,'FontName',SelectedFont,'FontSize',4),InfoDetectedSoilSlips(:,5),InfoDetectedSoilSlips(:,6),InfoDetectedSoilSlips(:,2));
end
cd(fold0)

legendCaption = (["High Susceptibility", "Low Susceptibility"]);

hSLIP_LowGood = find(~cellfun(@isempty, hSLIP_Low));
hSLIP_HighGood = find(~cellfun(@isempty, hSLIP_High));

IndLeg = [all(~cellfun(@isempty, hSLIP_Low)), all(~cellfun(@isempty, hSLIP_High))];

allPlot = {hSLIP_Low, hSLIP_High};
allPlotGood = {hSLIP_LowGood, hSLIP_HighGood};

if exist("FsMedium", "var") == 1
    legendCaption = (["High Susceptibility", "Medium Susceptibility", "Low Susceptibility"]);

    hSLIP_Medium = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','s', 'MarkerFaceColor',[255 255 150]./255, ...
                           'MarkerEdgeColor','none'), xLongFSMedium, yLatFSMedium, 'UniformOutput',false);

    hSLIP_MediumGood = find(~cellfun(@isempty, hSLIP_Medium));

    IndLeg = [all(~cellfun(@isempty, hSLIP_Low)), all(~cellfun(@isempty, hSLIP_Medium)), all(~cellfun(@isempty, hSLIP_High))];

    allPlot = {hSLIP_Low, hSLIP_Medium, hSLIP_High};
    allPlotGood = {hSLIP_LowGood, hSLIP_MediumGood, hSLIP_HighGood};
end

for i1 = 1:length(hSLIP_Low)
    uistack(hSLIP_Low{i1},'top')
end

uistack(hdetected,'top')

legendCaption = legendCaption(IndLeg);

allPlot = allPlot(IndLeg);
allPlotGood = allPlotGood(IndLeg);

allPlot2Plot = cellfun(@(x,y) x(y(1)), allPlot, allPlotGood);

if exist('InfoDetectedSoilSlips.mat', 'file')
    handPlot = [[allPlot2Plot{:}], hdetected(1)];
    legendCaption = [legendCaption,"Detected Soil slips"];
else
    handPlot = [allPlot2Plot{:}];
end

hleg = legend(handPlot, legendCaption{:},...
              'Location',SelectedLocation,...
              'FontName',SelectedFont,...
              'FontSize',SelectedFontSize);

legend('AutoUpdate','off');
legend boxoff
hold on
plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1)
hold on

fig_extra('CompassRose')

set(gca, 'visible','off')

% hSS113=line(Street(:,1),Street(:,2),'LineWidth',1.5,'Color',[239 239 239]./255);
% hTunnel=line(Street(StartEndPointsTunnel(1):StartEndPointsTunnel(2),1),Street(StartEndPointsTunnel(1):StartEndPointsTunnel(2),2),'LineWidth',4,'Color','c');

% xlim([MinExtremes(1),MaxExtremes(1)])
% ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])
% title(strcat("Safety Factors of ",string(EventFS)," event"),...
%             'FontName',SelectedFont,'FontSize',SelectedFontSize*1.4)

%% Export png
cd(fold_fig)
if ~exist(namefoldFS,'dir'); mkdir(namefoldFS); end
cd(namefoldFS)
exportgraphics(f1,strcat(filename1,'.png'),"Resolution",600);
cd(fold0)