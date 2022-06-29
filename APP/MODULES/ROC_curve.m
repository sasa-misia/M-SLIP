%% Data Import
cd(fold_var)
load('InfoDetectedSoilSlips.mat')
load('GridCoordinates.mat')
load('MorphologyParameters.mat', 'SlopeAll')

if exist('PlotSettings.mat', 'file')
    load('PlotSettings.mat')
    SelectedFont = Font;
    SelectedFontSize = FontSize;
else
    SelectedFont = 'Times New Roman';
    SelectedFontSize = 8;
end

%% Study area coordinates and slope angle
xLongStudy = cellfun(@(x,y) x(y), xLongAll, ...
                                  IndexDTMPointsInsideStudyArea, ...
                                  'UniformOutput',false);

yLatStudy = cellfun(@(x,y) x(y), yLatAll, ...
                                 IndexDTMPointsInsideStudyArea, ...
                                 'UniformOutput',false);

SlopeStudy = cellfun(@(x,y) x(y), SlopeAll, ...
                                  IndexDTMPointsInsideStudyArea, ...
                                  'UniformOutput',false);

%% Definition of area where calculate ROC Curve
% Points of max area where search for TP and FN
SizeForDetROC = 200; % This is the size in m around the detected soil slip
dXROC = km2deg(SizeForDetROC/2/1000);
BoundSoilSlipROC = [cellfun(@(x) x-dXROC, InfoDetectedSoilSlips(:,5:6)), ...
                    cellfun(@(x) x+dXROC, InfoDetectedSoilSlips(:,5:6))];
PolSoilSlipROC = arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]), ...
                                         BoundSoilSlipROC(:,1), ...
                                         BoundSoilSlipROC(:,3), ...
                                         BoundSoilSlipROC(:,2), ...
                                         BoundSoilSlipROC(:,4));
TotPolSoilSlipROC = union(PolSoilSlipROC);
[pp, ee] = getnan2([TotPolSoilSlipROC.Vertices; nan, nan]);

IndFrstPartPointROC = cellfun(@(x,y) find(inpoly([x,y],pp,ee)), ...
                                     xLongStudy, yLatStudy, ...
                                     'UniformOutput',false);

% Point where search for FP and TN
if ~all(cellfun(@isempty, IndexDTMPointsExcludedInStudyArea))
    ModeForROC = listdlg('PromptString',{'How do you want to define unconditionally stable area?',''}, ...
                         'ListString',{'With slope angle', 'With land use excluded'}, 'SelectionMode','single');
else
    ModeForROC = 1;
end

switch ModeForROC
    case 1
        SlopeUncStab = 15;
        IndScndPartPointROC = cellfun(@(x) find(x<SlopeUncStab), SlopeStudy, 'UniformOutput',false);
    case 2
        [~, IndScndPartPointROC, ~] = cellfun(@(x,y) intersect(x,y), ...
                                                     IndexDTMPointsInsideStudyArea, ...
                                                     IndexDTMPointsExcludedInStudyArea, ...
                                                     'UniformOutput',false);
end

% Union of first and second part
IndexDTMPointsForROC = cellfun(@(x,y) unique([x; y]), ...
                                      IndFrstPartPointROC, IndScndPartPointROC, ...
                                      'UniformOutput',false);

%% Study area coordinates of point to analize with ROC Curve
xLongROC = cellfun(@(x,y) x(y), xLongStudy, IndexDTMPointsForROC, 'UniformOutput',false);

yLatROC = cellfun(@(x,y) x(y), yLatStudy, IndexDTMPointsForROC, 'UniformOutput',false);

%% Main loop
ROCToPlot = listdlg('PromptString',{'How many ROC do you want to plot?',''}, ...
                    'ListString',{'1', '2', '3', '4'}, 'SelectionMode','single');

% Fig = uifigure; % Remember to comment this line if is app version
figure(Fig)
drawnow

[TPR, TNR, FPR, FNR, AUC, BestThreshold, Labels, AnalysisType, ThresholdValues] = deal(cell(1,ROCToPlot));
for i1 = 1:ROCToPlot
    %% FS import
    cd(fold_res_fs)
    foldFS = uigetdir('open');
    [~, namefoldFS] = fileparts(foldFS);

    Choices = inputdlg({'Label of this analysis (for plot):', ...
                        strcat("Side of the area where check for TP (max ",string(SizeForDetROC)," m):") ...
                        ['Procedure:                                        '
                         '1 -> individual point evaluation in Landslide area'
                         '2 -> point group evaluation in Landslide area     ']},'', 1, ...
                       {'No Vegetation', '80', '1'});
    figure(Fig)
    drawnow

    Labels(i1) = Choices(1);
    Side = Choices(2);
    Procedure = eval(Choices{3});
    
    cd(foldFS)
    load('AnalysisInformation.mat');
    
    EventsAnalysed = string(StabilityAnalysis{2});
    Choice = listdlg('PromptString',{strcat("Select event n. ",string(i1)),''}, ...
                     'ListString',EventsAnalysed, 'SelectionMode','single');
    EventFS = datetime(EventsAnalysed(Choice), 'InputFormat','dd/MM/yyyy HH:mm:ss');
    IndexFS = hours(EventFS-StabilityAnalysis{2}(1))+1;

    AnalysisType{i1} = StabilityAnalysis{4}(1);

    drawnow
    figure(Fig)
    
    switch StabilityAnalysis{4}(1)
        case "Slip"
            load(strcat('Fs',num2str(IndexFS),'.mat'));
            FactorSafetyROC = cellfun(@(x,y) x(y), FactorSafety, ...
                                                   IndexDTMPointsForROC, ...
                                                   'UniformOutput',false);

            MaxFS = cellfun(@max, FactorSafetyROC, 'UniformOutput',false);
            MaxFS = max([MaxFS{:}]);

            MinFS = cellfun(@min, FactorSafetyROC, 'UniformOutput',false);
            MinFS = min([MinFS{:}]); 

            NaNFactorSafetyROC = cellfun(@(x) isnan(x), FactorSafetyROC, 'UniformOutput',false);
            for i2 = 1:length(FactorSafetyROC)
                FactorSafetyROC{i2}(NaNFactorSafetyROC{i2}) = MaxFS; % NaN Points are excluded and considered as unconditionally stable
            end

            InstabilityProbabilities = cellfun(@(x) 1-(x-MinFS)/(MaxFS-MinFS), ...
                                                    FactorSafetyROC, ...
                                                    'UniformOutput',false);
            ThresholdFS = [MinFS-1, MinFS, 0:0.1:2, 2.5:0.5:30, 35:5:70, MaxFS, MaxFS+1];
            IndSignificantPoints = find(ismember(ThresholdFS, [1, 1.5, 2]));
            InstabilityThresholds = arrayfun(@(x) 1-(x-MinFS)/(MaxFS-MinFS), ThresholdFS);

            ThresholdValues{i1} = ThresholdFS;

        case "Machine Learning"
            load(strcat('FsML',num2str(IndexFS),'.mat'));
            FactorSafetyMachineLearningROC = cellfun(@(x,y) x(y,:), ...
                                                            FactorSafetyMachineLearning, ...
                                                            repmat(IndexDTMPointsForROC, size(FactorSafetyMachineLearning, 1), 1), ...
                                                            'UniformOutput',false); % Check if it is correct

            InstabilityProbabilities = cellfun(@(x) x(:,2), FactorSafetyMachineLearningROC(2,:), ...
                                                            'UniformOutput',false);
            InstabilityThresholds = 1.01:-.01:-.01;
            InstabilityValues = flip( unique(cell2mat( ...
                                      cellfun(@(x) unique(x(:,2)), FactorSafetyMachineLearningROC(2,:), ...
                                      'UniformOutput',false)')) );
            if length(InstabilityValues)>100
                for i2 = 3:101
                    InstabilityThresholds(i2) = InstabilityValues(uint64((i2-1)*length(InstabilityValues)/101));
                end
            end

            ThresholdValues{i1} = InstabilityThresholds;
            
        otherwise
            error('S.a. type not specified')
    end
    
    %% Bounding for TP
    drawnow
    figure(Fig)
    
    dX = km2deg(eval(Side{1})/2/1000);

    BoundSoilSlip = [cellfun(@(x) x-dX, InfoDetectedSoilSlips(:,5:6)), ...
                     cellfun(@(x) x+dX, InfoDetectedSoilSlips(:,5:6))];

    PolSoilSlip = arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]), ...
                                          BoundSoilSlip(:,1), ...
                                          BoundSoilSlip(:,3), ...
                                          BoundSoilSlip(:,2), ...
                                          BoundSoilSlip(:,4));
    
    %% Finding TP, TN, FP, FN
    ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Initializing');
    drawnow
    Steps = length(InstabilityThresholds);
    
    [TPR{i1}, TNR{i1}, FPR{i1}, FNR{i1}] = deal(zeros(1,length(InstabilityThresholds)));
    for i2 = 1:length(InstabilityThresholds)
        ProgressBar.Value = i2/Steps;
        ProgressBar.Message = strcat("Threshold n. ", string(i2)," of ", string(Steps));
        drawnow

        StablePointsInd = cellfun(@(x) x<InstabilityThresholds(i2), ...
                                  InstabilityProbabilities, 'UniformOutput',false);

        UnstablePointsInd = cellfun(@(x) x>=InstabilityThresholds(i2), ...
                                    InstabilityProbabilities, 'UniformOutput',false);
    
        StableNotEmpty = cellfun(@any, StablePointsInd); % Delete empty array
        UnstableNotEmpty = cellfun(@any, UnstablePointsInd); 
    
        StablePointsInd = StablePointsInd(StableNotEmpty);
        UnstablePointsInd = UnstablePointsInd(UnstableNotEmpty);
    
        StablePointsIndGood = cellfun(@(x) x(x), StablePointsInd, 'UniformOutput',false); % Necessary to clean vector from unstable points
        UnstablePointsIndGood = cellfun(@(x) x(x), UnstablePointsInd, 'UniformOutput',false);
    
        xLongROCStable = cellfun(@(x,y) x(y), xLongROC(StableNotEmpty), ...
                                              StablePointsInd, ...
                                              'UniformOutput',false);

        yLatROCStable = cellfun(@(x,y) x(y), yLatROC(StableNotEmpty), ...
                                             StablePointsInd, ...
                                             'UniformOutput',false);
        
        xLongROCUnstable = cellfun(@(x,y) x(y), xLongROC(UnstableNotEmpty), ...
                                                UnstablePointsInd, ...
                                                'UniformOutput',false);

        yLatROCUnstable = cellfun(@(x,y) x(y), yLatROC(UnstableNotEmpty), ...
                                               UnstablePointsInd, ...
                                               'UniformOutput',false);
    
        NumFN = 0;
        NumTP = 0;
    
        TotPolSoilSlip = union(PolSoilSlip); % Otherwise in the next for loop you have a low speed
        [pp, ee] = getnan2([TotPolSoilSlip.Vertices; nan, nan]);
    
        PositiveInsidePolygonTot = cellfun(@(x,y) find(inpoly([x,y],pp,ee)), ...
                                                  xLongROCUnstable, yLatROCUnstable, ...
                                                  'UniformOutput',false);

        NegativeInsidePolygonTot = cellfun(@(x,y) find(inpoly([x,y],pp,ee)), ...
                                                  xLongROCStable, yLatROCStable, ...
                                                  'UniformOutput',false);

        %% Procedure 1
        if Procedure == 1
            NumTP = sum(cellfun(@numel,PositiveInsidePolygonTot));
            NumFN = sum(cellfun(@numel,NegativeInsidePolygonTot));
            NumFP = sum(cellfun(@numel,xLongROCUnstable))-NumTP;
            NumTN = sum(cellfun(@numel,xLongROCStable))-NumFN;
    
            TPR{i1}(i2) = NumTP/(NumTP+NumFN);
            TNR{i1}(i2) = NumTN/(NumFP+NumTN);
            FPR{i1}(i2) = NumFP/(NumFP+NumTN);
            FNR{i1}(i2) = NumFN/(NumFN+NumTP);
            continue % This will skip the 2nd procedure and go directly to the next loop
        end

        %% Procedure 2
        if Procedure == 2
            if ~isempty(PositiveInsidePolygonTot)
                CoordUnstableInDetected = [ cellfun(@(x,y) x(y), xLongROCUnstable, PositiveInsidePolygonTot, 'UniformOutput',false)
                                            cellfun(@(x,y) x(y), yLatROCUnstable, PositiveInsidePolygonTot, 'UniformOutput',false)  ];
                CoordUnstableInDetected(3,:) = num2cell(1:size(CoordUnstableInDetected, 2));
                CoordUnstableInDetected = CoordUnstableInDetected(:, ~cellfun('isempty',CoordUnstableInDetected(1,:)));
            end
            
            if ~isempty(NegativeInsidePolygonTot)
                CoordStableInDetected = [ cellfun(@(x,y) x(y), xLongROCStable, NegativeInsidePolygonTot, 'UniformOutput',false)
                                          cellfun(@(x,y) x(y), yLatROCStable, NegativeInsidePolygonTot, 'UniformOutput',false)  ];
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
                                           ( NegativeInsidePolygonTot{DTMNegativeAll}(RelIndInPolygonNeg) ) ...
                                            = false;
                    end
                end
        
                if isempty(DTMPositiveInsidePolygon)
                    NumFN = NumFN+1;
                else
                    NumTP = NumTP+1;
                end
            end
        
            NumFP = sum( cellfun(@nnz, UnstablePointsIndGood) );
            NumTN = sum( cellfun(@nnz, StablePointsIndGood) ); 
        
            TPR{i1}(i2) = NumTP/(NumTP+NumFN);
            TNR{i1}(i2) = NumTN/(NumFP+NumTN);
            FPR{i1}(i2) = NumFP/(NumFP+NumTN);
            FNR{i1}(i2) = NumFN/(NumFN+NumTP);
        end

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
close(ProgressBar) % ProgressBar instead of Fig if on the app version

VariablesROC = {'TPR', 'TNR', 'FPR', 'FNR', 'BestThreshold', 'AUC', 'ThresholdValues'};

%% Image Creation
PlotChoice = listdlg('PromptString',{strcat("What type of chart do you want to plot?",string(i1)),''}, ...
                     'ListString',{'TPR / FPR', 'TPR / TNR'}, 'SelectionMode','single');

fig_ROC = figure(1);
set(fig_ROC , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits', 'centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition', [0 1 12 6],...
    'InvertHardcopy','off');
axes1 = axes('Parent',fig_ROC); 
hold(axes1,'on');

% Colors = ['#808080'; '#007F7F'; '#E8a94a'; '#4ae8e6'];
% Colors = reshape(sscanf(Colors(:,2:end).','%2x'),3,[]).'/255;
Colors = [128   128     128
          0     127.5   127.5
          122   100     70
          66    230     170  ]./255;

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

if exist('LegendPosition', 'var')
    LegendLabels = strcat(string(Labels)'," (","{\itAUC}"," = ",compose("%4.1f",[AUC{:}]')," %)");
    hleg1 = legend(LegendLabels, ...
                   'AutoUpdate','off',...
                   'Location',LegendPosition,...
                   'NumColumns',1,...
                   'FontName',SelectedFont,...
                   'FontSize',SelectedFontSize,...
                   'Box','on');
    % hleg1.Title.String = 'AUC';
    hleg1.ItemTokenSize = [10, 5];
end

for i1 = 1:ROCToPlot
    if AnalysisType{i1} == "Slip"
        for i2 = IndSignificantPoints
            if PlotChoice == 2
                plot(TNR{i1}(i2), TPR{i1}(i2), 'Marker',MarkTypes(i1), ...
                     'MarkerEdgeColor',Colors(i1,:), 'MarkerFaceColor',Colors(i1,:))
            else
                plot(FPR{i1}(i2), TPR{i1}(i2), 'Marker',MarkTypes(i1), ...
                     'MarkerEdgeColor',Colors(i1,:), 'MarkerFaceColor',Colors(i1,:))
            end
        end
    end
end

xlim([0 1])
ylim([0 1])
xlabel('\itFPR', 'FontName',SelectedFont)
ylabel('\itTPR', 'FontName',SelectedFont)

%% Saving...
cd(fold_var)
save('ROC_Curve.mat', VariablesROC{:});

%% Export png
cd(fold_fig)
filename1 = string(inputdlg({'PNG export name:'},'', 1, {'NoVeg_vs_Veg'}));
exportgraphics(fig_ROC, strcat(filename1,'.png'), "Resolution",600);
cd(fold0)