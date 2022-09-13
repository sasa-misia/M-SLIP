cd(fold_var)
load('GridCoordinates.mat')
load('SoilParameters.mat')
load('StudyAreaVariables.mat')
load('UserB_Answers.mat', 'OrthophotoAnswer')

RefStudyArea = 0.035; % 0.0417;
ExtentStudyArea = area(StudyAreaPolygon);
RatioRef = ExtentStudyArea/RefStudyArea;

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
end

if OrthophotoAnswer
    load("Orthophoto.mat")
end

%%
cd(fold_res_fs)

foldFS = uigetdir('open');
[~,namefoldFS] = fileparts(foldFS);

cd(foldFS)
load('AnalysisInformation.mat');

EventsAnalysed = string(StabilityAnalysis{:,2});
Choice = listdlg('PromptString',{'Select event analysed to plot:',''}, 'ListString',EventsAnalysed);
EventFS = datetime(EventsAnalysed(Choice), 'InputFormat','dd/MM/yyyy HH:mm:ss');
IndexFS = hours(EventFS-StabilityAnalysis{2}(1))+1;

Event_FS1=datetime(EventFS,'Format','dd-MM-yyyy HH-mm');

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
        MinFSForStability = eval(InputValues{1});
        MaxFSForInstability = eval(InputValues{2});
        FsLow = cellfun(@(x) x<=MaxFSForInstability & x>0, Fs, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x>MinFSForStability, Fs, 'UniformOutput',false);

        Answer = questdlg('Do you want the medium class of FS?', 'Medium Class', ...
                	      'Yes','No, only High and Low','No, only High and Low');
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
                                'Indicate the probability below which the point is stable (<= than the previous):'},'',1,...
                               {'0.8', '0.3'});
        MinProbForInstability = eval(InputValues{1});
        MaxProbForStability = eval(InputValues{2});

        FsLow = cellfun(@(x) x>=MinProbForInstability, InstabilityProbabilities, 'UniformOutput',false);
        FsHigh = cellfun(@(x) x<MaxProbForStability, InstabilityProbabilities, 'UniformOutput',false);

        Answer = questdlg('Do you want the medium class of FS?', 'Medium Class', ...
                	      'Yes','No, only High and Low','No, only High and Low');
        if string(Answer) == "Yes"
            FsMedium = cellfun(@(x) x>=MaxProbForStability & x<MinProbForInstability, ...
                                    InstabilityProbabilities, 'UniformOutput',false);
        end

    otherwise
        error('PLT 1')
end

%%
NumInstabilityPoints=cellfun(@(x) numel(find(x)),FsLow);

IndexStudyAreaLow = cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, FsLow,'UniformOutput',false);
IndexStudyAreaHigh = cellfun(@(x,y) x(y), ...
    IndexDTMPointsInsideStudyArea, FsHigh,'UniformOutput',false);

xLongFSLow = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaLow,'UniformOutput',false);
xLongFSHigh = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaHigh,'UniformOutput',false);

yLatFSLow = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaLow,'UniformOutput',false);
yLatFSHigh = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaHigh,'UniformOutput',false);

if exist("FsMedium") == 1
    IndexStudyAreaMedium = cellfun(@(x,y) x(y), ...
        IndexDTMPointsInsideStudyArea, FsMedium,'UniformOutput',false);
    
    xLongFSMedium = cellfun(@(x,y) x(y),xLongAll,IndexStudyAreaMedium,'UniformOutput',false);
    
    yLatFSMedium = cellfun(@(x,y) x(y),yLatAll,IndexStudyAreaMedium,'UniformOutput',false);
end

%%
filename1=string(Event_FS1);
f1=figure(1);
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

PixelSize = .1/RatioRef;


if OrthophotoAnswer
    cellfun(@(x,y) geoshow(x,y), ZOrtho, ROrtho);
    hold on
end

hSLIP_Low=cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', 'MarkerFaceColor',[229 81 55]./255, ...
                  'MarkerEdgeColor','none'), xLongFSLow, yLatFSLow, 'UniformOutput',false);
hSLIP_High=cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', 'MarkerFaceColor',[189 236 232]./255, ...
                   'MarkerEdgeColor','none'), xLongFSHigh, yLatFSHigh, 'UniformOutput',false);

% hSLIP_High=cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', 'MarkerFaceColor',[0 127 255]./255, ...
%                  'MarkerEdgeColor','none'), xLongFSHigh, yLatFSHigh, 'UniformOutput',false);



cd(fold_var)
if exist('InfoDetectedSoilSlips.mat', 'file')
    load('InfoDetectedSoilSlips.mat')
    hdetected = cellfun(@(x,y) scatter(x, y, 5, '^k','Filled'),InfoDetectedSoilSlips(:,5),InfoDetectedSoilSlips(:,6));
    % cellfun(@(x,y,z) text(x,y+0.001,z,'FontName',SelectedFont,'FontSize',4),InfoDetectedSoilSlips(:,5),InfoDetectedSoilSlips(:,6),InfoDetectedSoilSlips(:,2));
end
cd(fold0)

switch StabilityAnalysis{4}(1)
    case "Slip"
        legendCaption = ([strcat("High Susceptibility ({\itFS} <= ",compose("%4.2f",MaxFSForInstability),")"), ...
                          strcat("Medium Susceptibility (",compose("%4.2f",MaxFSForInstability)," < {\itFS} <= ",compose("%4.2f",MinFSForStability),")"), ...
                          strcat("Low Susceptibility ({\itFS} > ",compose("%4.2f",MinFSForStability),")")]);
    case "Machine Learning"
        legendCaption = ([strcat("High Susceptibility ({\itProbability} >= ",compose("%4.2f",MinProbForInstability*100),"%)"), ...
                          strcat("Medium Susceptibility (",compose("%4.2f",MaxProbForStability*100),"% <= {\itProbability} < ",compose("%4.2f",MinProbForInstability*100),"%)"), ...
                          strcat("Low Susceptibility ({\itProbability} < ",compose("%4.2f",MaxProbForStability*100),"%)")]);
end

hSLIP_LowGood = find(~cellfun(@isempty,hSLIP_Low));
hSLIP_HighGood = find(~cellfun(@isempty,hSLIP_High));

IndLeg = [any(~cellfun(@isempty,hSLIP_Low)), false, any(~cellfun(@isempty,hSLIP_High))];

allPlot={hSLIP_Low, hSLIP_High};
allPlotGood={hSLIP_LowGood, hSLIP_HighGood};

if exist('FsMedium', 'var') == 1
    hSLIP_Medium = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', 'MarkerFaceColor',[255 255 0]./255, ...
                           'MarkerEdgeColor','none'), xLongFSMedium, yLatFSMedium, 'UniformOutput',false);

    hSLIP_MediumGood = find(~cellfun(@isempty,hSLIP_Medium));

    IndLeg = [any(~cellfun(@isempty,hSLIP_Low)), any(~cellfun(@isempty,hSLIP_Medium)), any(~cellfun(@isempty,hSLIP_High))];

    allPlot = {hSLIP_Low, hSLIP_Medium, hSLIP_High};
    allPlotGood = {hSLIP_LowGood, hSLIP_MediumGood, hSLIP_HighGood};

    for i1 = 1:length(hSLIP_Low)
        uistack(hSLIP_Medium{i1},'top')
    end
end

for i1 = 1:length(hSLIP_Low)
    uistack(hSLIP_Low{i1},'top')
end

cd(fold_var)
if exist('InfoDetectedSoilSlips.mat', 'file')
    uistack(hdetected,'top')
end
cd(fold0)

legendCaption = legendCaption(IndLeg);

allPlot=allPlot(IndLeg);
allPlotGood=allPlotGood(IndLeg);

allPlot2Plot=cellfun(@(x,y) x(y(1)),allPlot,allPlotGood);

cd(fold_var)
if exist('InfoDetectedSoilSlips.mat', 'file')
    handPlot=[[allPlot2Plot{:}] hdetected(1)];
    legendCaption = [legendCaption, "Detected Soil slips"];
else
    handPlot=[allPlot2Plot{:}];
end
cd(fold0)

if exist('LegendPosition', 'var')
    hleg=legend(handPlot,...
                legendCaption{:},...
                'Location',LegendPosition,...
                'FontName',SelectedFont,...
                'FontSize',SelectedFontSize);
    legend('AutoUpdate','off');
    legend boxoff
    hold on
    plot(StudyAreaPolygon,'FaceColor','none','EdgeColor','k','LineWidth',1,'LineStyle','--')
    hold on
end

set(gca, 'visible','off')

% hSS113=line(Street(:,1),Street(:,2),'LineWidth',1.5,'Color',[239 239 239]./255);
% hTunnel=line(Street(StartEndPointsTunnel(1):StartEndPointsTunnel(2),1),Street(StartEndPointsTunnel(1):StartEndPointsTunnel(2),2),'LineWidth',4,'Color','c');

fig_settings(fold0)

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