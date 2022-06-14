clc
clear
close all

load('os_folders.mat');
if string(pwd) ~= string(fold0)
    User0_FolderCreation
end

%% Data Import
cd(fold_var)
load('InfoDetectedSoilSlips.mat');
load('GridCoordinates.mat');

if exist('LegendSettings.mat', 'file')
    load('LegendSettings.mat')
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
    SelectedLocation = 'Best';
end
 
% mdl = fitglm(pred,resp,'Distribution','binomial','Link','logit');
% 
% scores = mdl.Fitted.Probability;
% [X,Y,T,AUC] = perfcurve(species(51:end,:),scores,'virginica');

%% Study area coordinates
xLongStudy = cellfun(@(x,y) x(y), ...
                     xLongAll, IndexDTMPointsInsideStudyArea, ...
                     'UniformOutput',false);
yLatStudy = cellfun(@(x,y) x(y), ...
                    yLatAll, IndexDTMPointsInsideStudyArea, ...
                    'UniformOutput',false);

%% Main loop
ROCToPlot = listdlg('PromptString',{'How many ROC do you want to plot?',''}, ...
                    'ListString',{'1', '2', '3', '4'}, 'SelectionMode','single');

Fig = uifigure; % Remember to comment this line if is app version
figure(Fig)
drawnow

[TPR, TNR, FPR, FNR, AUC, BestThreshold, Labels, AnalysisType] = deal(cell(1,ROCToPlot));
for i1 = 1:ROCToPlot
    %% FS import
    cd(fold_res_fs)
    foldFS = uigetdir('open');
    [~, namefoldFS] = fileparts(foldFS);

    Choices = inputdlg({'Label of this analysis (for plot):' ...
                         'Indicate side of the border where check for TP (m):'},'', 1, ...
                        {'No Vegetation' ...
                         '80'});
    
    Labels(i1) = Choices(1);
    Side = Choices(2);
    
    cd(foldFS)
    load('AnalysisInformation.mat');
    
    EventsAnalysed = string(StabilityAnalysis{2});
    Choice = listdlg('PromptString',{strcat("Select event n. ",string(i1)),''}, ...
                     'ListString',EventsAnalysed, 'SelectionMode','single');
    EventFS = datetime(EventsAnalysed(Choice), 'InputFormat','dd/MM/yyyy HH:mm:ss');
    IndexFS = hours(EventFS-StabilityAnalysis{2}(1))+1;

    AnalysisType{i1} = StabilityAnalysis{4}(1);
    
    switch StabilityAnalysis{4}(1)
        case "Slip"
            load(strcat('Fs',num2str(IndexFS),'.mat'));
            MaxFS = max(cellfun(@max, FactorSafety));
            MinFS = min(cellfun(@min, FactorSafety));
            InstabilityFrequencies = cellfun(@(x) 1-(x-MinFS)/(MaxFS-MinFS), ...
                                             FactorSafety, ...
                                             'UniformOutput',false);
            ThresholdFS = [MinFS-0.1, MinFS, 0:0.1:2, 2.5:0.5:30, 35:5:70, MaxFS, MaxFS+0.1];
            InstabilityThresholds = arrayfun(@(x) 1-(x-MinFS)/(MaxFS-MinFS), ThresholdFS);

        case "Machine Learning"
            load(strcat('FsML',num2str(IndexFS),'.mat'));
            InstabilityFrequencies = cellfun(@(x) x(:,2), ...
                                             FactorSafetyMachineLearning(2,:), ...
                                             'UniformOutput',false);
            InstabilityThresholds = 1.01:-.01:-.01;
            InstabilityValues = flip(unique(cell2mat( ...
                                     cellfun(@(x) unique(x(:,2)), FactorSafetyMachineLearning(2,:), ...
                                     'UniformOutput',false)')));
            if length(InstabilityValues)>100
                for i2 = 3:101
                    InstabilityThresholds(i2) = InstabilityValues(uint64((i2-1)*length(InstabilityValues)/101));
                end
            end

        otherwise
            error('S.a. type not specified')
    end
    
    %% Bounding for TP
    dX = km2deg(eval(Side{1})/2/1000);
    BoundSoilSlip = [cellfun(@(x) x-dX, InfoDetectedSoilSlips(:,5:6)), ...
                     cellfun(@(x) x+dX, InfoDetectedSoilSlips(:,5:6))];
    PolSoilSlip = arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]), ...
                           BoundSoilSlip(:,1), BoundSoilSlip(:,3), BoundSoilSlip(:,2), BoundSoilSlip(:,4));
    
    %% Finding TP, TN, FP, FN
    ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Initializing');
    drawnow
    Steps = length(InstabilityThresholds);
    
    [TPR{i1}, TNR{i1}, FPR{i1}, FNR{i1}] = deal(zeros(1,length(InstabilityThresholds)));
    for i2 = 1:length(InstabilityThresholds)
        StablePointsInd = cellfun(@(x) x<InstabilityThresholds(i2), ...
                                  InstabilityFrequencies, 'UniformOutput',false);
        UnstablePointsInd = cellfun(@(x) x>=InstabilityThresholds(i2), ...
                                    InstabilityFrequencies, 'UniformOutput',false);
    
        StableNotEmpty = cellfun(@any, StablePointsInd); % Delete empty array
        UnstableNotEmpty = cellfun(@any, UnstablePointsInd); 
    
        StablePointsInd = StablePointsInd(StableNotEmpty);
        UnstablePointsInd = UnstablePointsInd(UnstableNotEmpty);
    
        StablePointsIndGood = cellfun(@(x) x(x), StablePointsInd, 'UniformOutput',false); % This is necessary to clean vector from unstable points
        UnstablePointsIndGood = cellfun(@(x) x(x), UnstablePointsInd, 'UniformOutput',false);
    
        xLongStudyStable = cellfun(@(x,y) x(y), xLongStudy(StableNotEmpty), StablePointsInd, 'UniformOutput',false);
        yLatStudyStable = cellfun(@(x,y) x(y), yLatStudy(StableNotEmpty), StablePointsInd, 'UniformOutput',false);
        
        xLongStudyUnstable = cellfun(@(x,y) x(y), xLongStudy(UnstableNotEmpty), UnstablePointsInd, 'UniformOutput',false);
        yLatStudyUnstable = cellfun(@(x,y) x(y), yLatStudy(UnstableNotEmpty), UnstablePointsInd, 'UniformOutput',false);
    
        NumFN = 0;
        NumTP = 0;
    
        TotPolSoilSlip = union(PolSoilSlip); % Otherwise in the next for loop you have a low speed
        [pp, ee] = getnan2([TotPolSoilSlip.Vertices; nan, nan]);
    
        PositiveInsidePolygonTot = cellfun(@(x,y) find(inpoly([x,y],pp,ee)), ...
                                           xLongStudyUnstable, yLatStudyUnstable, ...
                                           'UniformOutput',false);
        NegativeInsidePolygonTot = cellfun(@(x,y) find(inpoly([x,y],pp,ee)), ...
                                           xLongStudyStable, yLatStudyStable, ...
                                           'UniformOutput',false);
    
        if ~isempty(PositiveInsidePolygonTot)
            CoordUnstableInDetected = [cellfun(@(x,y) x(y), xLongStudyUnstable, PositiveInsidePolygonTot, 'UniformOutput',false)
                                       cellfun(@(x,y) x(y), yLatStudyUnstable, PositiveInsidePolygonTot, 'UniformOutput',false)];
            CoordUnstableInDetected(3,:) = num2cell(1:size(CoordUnstableInDetected, 2));
            CoordUnstableInDetected = CoordUnstableInDetected(:, ~cellfun('isempty',CoordUnstableInDetected(1,:)));
        end
        
        if ~isempty(NegativeInsidePolygonTot)
            CoordStableInDetected = [cellfun(@(x,y) x(y), xLongStudyStable, NegativeInsidePolygonTot, 'UniformOutput',false)
                                     cellfun(@(x,y) x(y), yLatStudyStable, NegativeInsidePolygonTot, 'UniformOutput',false)];
            CoordStableInDetected(3,:) = num2cell(1:size(CoordStableInDetected, 2));
            CoordStableInDetected = CoordStableInDetected(:, ~cellfun('isempty',CoordStableInDetected(1,:)));
        end
    
        for i3 = 1:length(PolSoilSlip)
            [pp, ee] = getnan2([PolSoilSlip(i3).Vertices; nan, nan]);
    
            if ~isempty(PositiveInsidePolygonTot)
                PositiveInsidePolygon = cellfun(@(x,y) find(inpoly([x,y],pp,ee)), ...
                                                CoordUnstableInDetected(1,:), ...
                                                CoordUnstableInDetected(2,:), ...
                                                'UniformOutput',false);
            else
                PositiveInsidePolygon = {};
            end
            
            if ~isempty(NegativeInsidePolygonTot)
                NegativeInsidePolygon = cellfun(@(x,y) find(inpoly([x,y],pp,ee)), ...
                                                CoordStableInDetected(1,:), ...
                                                CoordStableInDetected(2,:), ...
                                                'UniformOutput',false);
            else
                NegativeInsidePolygon = {};
            end
    
            DTMPositiveInsidePolygon = find(cellfun(@(x) ~isempty(x), PositiveInsidePolygon));
            DTMNegativeInsidePolygon = find(cellfun(@(x) ~isempty(x), NegativeInsidePolygon));
    
            if ~isempty(DTMPositiveInsidePolygon)
                for i4 = 1:length(DTMPositiveInsidePolygon)
                    DTMPositiveAll = CoordUnstableInDetected{3, DTMPositiveInsidePolygon(i4)};
                    RelIndInPolygonPos = PositiveInsidePolygon{DTMPositiveInsidePolygon(i4)};
                    UnstablePointsIndGood{ DTMPositiveAll } ...
                                         ( PositiveInsidePolygonTot{DTMPositiveAll}(RelIndInPolygonPos) ) ...
                                          = false;
                end
            end
    
            if ~isempty(DTMNegativeInsidePolygon)
                for i4 = 1:length(DTMNegativeInsidePolygon)
                    DTMNegativeAll = CoordStableInDetected{3, DTMNegativeInsidePolygon(i4)};
                    RelIndInPolygonNeg = NegativeInsidePolygon{DTMNegativeInsidePolygon(i4)};
                    StablePointsIndGood{ DTMNegativeAll } ...
                                       ( NegativeInsidePolygonTot{DTMNegativeAll}(RelIndInPolygonNeg)) ...
                                        = false;
                end
            end
    
            if isempty(DTMPositiveInsidePolygon)
                NumFN = NumFN+1;
            else
                NumTP = NumTP+1;
            end
        end
    
        NumFP = sum(cellfun(@nnz, UnstablePointsIndGood));
        NumTN = sum(cellfun(@nnz, StablePointsIndGood)); 
    
        TPR{i1}(i2) = NumTP/(NumTP+NumFN);
        TNR{i1}(i2) = NumTN/(NumFP+NumTN);
        FPR{i1}(i2) = NumFP/(NumFP+NumTN);
        FNR{i1}(i2) = NumFN/(NumFN+NumTP);
    
        ProgressBar.Value = i2/Steps;
        ProgressBar.Message = strcat("Threshold n. ", string(i2)," of ", string(Steps));
        drawnow
    end
    
    AUC{i1} = trapz(FPR{i1}, TPR{i1})*100;
    
    [~, IndMax] = max(TPR{i1}./FPR{i1});
    switch StabilityAnalysis{4}(1)
        case "Slip"
            BestThreshold{i1} = (1-InstabilityThresholds(IndMax))*(MaxFS-MinFS)+MinFS;
        case "Machine Learning"
            BestThreshold{i1} = InstabilityThresholds(IndMax);
    end
end
close(Fig) % ProgressBar instead of Fig if on the app version

%% Image Creation
PlotChoice = listdlg('PromptString',{strcat("What type of chart do you want to plot?",string(i1)),''}, ...
                     'ListString',{'TPR / FPR', 'TPR / TNR'}, 'SelectionMode','single');

f1 = figure(1);
set(f1 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits', 'centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition', [0 1 12 6],...
    'InvertHardcopy','off');
axes1 = axes('Parent',f1); 
hold(axes1,'on');

Colors = ['#808080'; '#007F7F'; '#E8a94a'; '#4ae8e6'];
Colors = reshape(sscanf(Colors(:,2:end).','%2x'),3,[]).'/255;

LineTypes = ["-", "-.", "-.", "-."];
MarkTypes = ["d", "o", "-s", "^"];

for i1 = 1:ROCToPlot
    if PlotChoice == 2
        plot(TNR{i1},TPR{i1}, LineTypes(i1), 'Color',Colors(i1,:))
    else
        plot(FPR{i1},TPR{i1}, LineTypes(i1), 'Color',Colors(i1,:))
    end
    hold on
end

if PlotChoice == 2
    plot([0 1],[1 0], '--', 'Color','r')
else
    plot([0 1],[0 1], '--', 'Color','r')
end

LegendLabels = strcat(string(Labels)'," (","{\itAUC}"," = ",compose("%4.1f",[AUC{:}]')," %)");
hleg1 = legend(LegendLabels, ...
               'AutoUpdate','on',...
               'Location',SelectedLocation,...
               'NumColumns',1,...
               'FontName',SelectedFont,...
               'FontSize',SelectedFontSize,...
               'Box','on');
hleg1.Title.String = 'AUC';
hleg1.ItemTokenSize = [10, 5];

for i1 = 1:ROCToPlot
    if AnalysisType{i1} == "Slip"
        for i2 = [13, 18, 23] % Remember to automize this process because if you change threshold you have to change it
            if PlotChoice == 2
                plot(TNR{i1}(i2), TPR{i1}(i2), 'Marker',MarkTypes(i1), ...
                     'MarkerEdgeColor', Colors(i1,:), 'MarkerFaceColor',Colors(i1,:))
            else
                plot(FPR{i1}(i2), TPR{i1}(i2), 'Marker',MarkTypes(i1), ...
                     'MarkerEdgeColor', Colors(i1,:), 'MarkerFaceColor',Colors(i1,:))
            end
        end
    end
end

xlim([0 1])
ylim([0 1])
xlabel('\itFPR', 'FontName',SelectedFont)
ylabel('\itTPR', 'FontName',SelectedFont)

%% Export png
cd(fold_fig)
filename1 = string(inputdlg({'PNG export name:'},'', 1, {'NoVeg_vs_Veg'}));
exportgraphics(f1,strcat(filename1,'.png'),"Resolution",600);
cd(fold0)