if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Options
fold_res_ml_curr = uigetdir(fold_res_ml, 'Chose your analysis folder');

UseBTAns = uiconfirm(Fig, 'Do you want to use auto best threshold?', ...
                          'Best threshold', 'Options',{'Yes', 'No'}, 'DefaultOption',1);
if strcmp(UseBTAns,'Yes'); UseBstThr = true; else; UseBstThr = false; end

if UseBstThr
    PrcBstThr = str2double(inputdlg2({'Percentage of best threshold:'}, 'DefInp',{'0.95'})); % [0, 1] Ex: if BestThr = 0.99 and PrcBstThr = 0.85, then ThrToUse = 0.85*0.99
else
    ThrToUse  = str2double(inputdlg2({'Threshold to use:'}, 'DefInp',{'0.5'}));
end

%% Loading
sl = filesep;

load([fold_var,sl,'DatasetStudy.mat'            ], 'DatasetStudyCoords')
load([fold_res_ml_curr,sl,'PredictionsStudy.mat'], 'PredProbs','LandPolys','EventsPerf')

%% Writing nans elements for BT
NumricBT = table2array(EventsPerf.BT); 
for i1 = 1:size(NumricBT, 2)
    RowsFull = find(not(isnan(NumricBT(:,i1))));
    ValsInBT = NumricBT(RowsFull,i1);
    
    NumricBT(1:RowsFull(1), i1) = ValsInBT(1);
    if numel(RowsFull) > 1
        for i2 = 2:numel(RowsFull)
            NumricBT(RowsFull(i2-1)+1 : RowsFull(i2), i1) = ValsInBT(i2);
        end
    end
    NumricBT(RowsFull(end):end, i1) = ValsInBT(end);
end
EventsPerf.BT{:,:} = NumricBT;

%% Core
ProgressBar.Indeterminate = 'off';
[Perc_L_U, Perc_NL_S, PercThr2U] = deal(cell(size(PredProbs)));
for i1 = 1:size(PredProbs, 2)
    for i2 = 1:size(PredProbs, 1)
        ProgressBar.Message = ['PPR and NPR for event n. ',num2str(i2),' of ', ...
                               num2str(size(PredProbs,1)),'. Model ', ...
                               PredProbs.Properties.VariableNames{i1}];
        ProgressBar.Value   = i2/size(PredProbs,1);
    
        UnstPolys = LandPolys.UnstablePolygons{i2};
        StabPolys = LandPolys.StablePolygons{i2};
        
        if i2 == 1 || ( i2 > 1 && not(isequal(UnstPolys, LandPolys.UnstablePolygons{i2-1}) && ...
                                      isequal(StabPolys, LandPolys.StablePolygons{i2-1})) )
            [IndPntsUnst, IndPntsStab] = deal(cell(size(UnstPolys)));
            for i3 = 1:numel(UnstPolys)
                [pp1, ee1] = getnan2([UnstPolys(i3).Vertices; nan, nan]);
                IndPntsUnst{i3} = find(inpoly([DatasetStudyCoords.Longitude,DatasetStudyCoords.Latitude], pp1,ee1));
            
                [pp2, ee2] = getnan2([StabPolys(i3).Vertices; nan, nan]);
                IndPntsStab{i3} = find(inpoly([DatasetStudyCoords.Longitude,DatasetStudyCoords.Latitude], pp2,ee2));
            end
        
            TotPntsStabPly = cellfun(@numel, IndPntsStab); % Numero totale di punti
            TotPntsUnstPly = cellfun(@numel, IndPntsUnst); % Numero totale di punti
        end
    
        PrdPrbs4PlyUnst = cellfun(@(x) PredProbs{i2,i1}{:}(x), IndPntsUnst, 'UniformOutput',false);
        PrdPrbs4PlyStab = cellfun(@(x) PredProbs{i2,i1}{:}(x), IndPntsStab, 'UniformOutput',false);
    
        if UseBstThr
            ThrToUse = PrcBstThr*EventsPerf.BT{i2,i1};
        end
    
        ClassesThresholdU = cellfun(@(x) round(x,4) >= ThrToUse, ...
                                            PrdPrbs4PlyUnst, 'UniformOutput',false);
        ClassesThresholdS = cellfun(@(x) round(x,4) >= ThrToUse, ...
                                            PrdPrbs4PlyStab, 'UniformOutput',false);
        
        NumPxlL  = cellfun(@(x) numel(find(x==1)), ClassesThresholdU);
        NumPxlNL = cellfun(@(x) numel(find(x==0)), ClassesThresholdS);
    
        Perc_L_U{ i2, i1} = NumPxlL ./TotPntsUnstPly.*100;
        Perc_NL_S{i2, i1} = NumPxlNL./TotPntsStabPly.*100;
    
        PercThr2U{i2, i1} = ThrToUse;
    end
end
ProgressBar.Indeterminate = 'on';

PredPlyRt = struct();
PredPlyRt.PercLsInUnst = array2table(Perc_L_U,  'VariableNames',PredProbs.Properties.VariableNames, ...
                                                'RowNames',PredProbs.Properties.RowNames);
PredPlyRt.PercNlInStab = array2table(Perc_NL_S, 'VariableNames',PredProbs.Properties.VariableNames, ...
                                                'RowNames',PredProbs.Properties.RowNames);
PredPlyRt.ThrUsed      = array2table(PercThr2U, 'VariableNames',PredProbs.Properties.VariableNames, ...
                                                'RowNames',PredProbs.Properties.RowNames);

%% Saving
ProgressBar.Message  = 'Saving files...';

VariablesToAdd = {'PredPlyRt'};
save([fold_res_ml_curr,sl,'PredictionsStudy.mat'], VariablesToAdd{:}, '-append')