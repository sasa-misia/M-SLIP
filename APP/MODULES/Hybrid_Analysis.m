% Fig = uifigure; % Remember to comment this line if is app version
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Indeterminate','on');
drawnow

%% Cretion of folder
cd(fold_res_fs)
FsFolderName = string(inputdlg({'Choose analysis folder name (inside Results->Factors of Safety):'}, ...
                                '', 1, {'Hybrid-Event-SLIP-RF-v1'}));

if exist(FsFolderName,'dir')
    Options = {'Yes, thanks', 'No, for God!'};
    Answer = uiconfirm(Fig, strcat(FsFolderName, " is an existing folder. " + ...
                                   "Do you want to overwrite it?"), ...
                            'Window type', 'Options',Options);
    switch Answer
        case 'Yes, thanks.'
            rmdir(FsFolderName,'s')
            mkdir(FsFolderName)
        case 'No, for God!'
            return
    end
else
    mkdir(FsFolderName)
end

fold_res_fs_new = strcat(fold_res_fs,sl,FsFolderName);

%% Analyses combination
AnalysisTypes = strings(1, 2);
fold_res_fs_an = strings(1, 2);
NumberOfAnalyses = zeros(1,2);
for i1 = 1:2
    cd(fold_res_fs)
    fold_res_fs_an(i1) = string(uigetdir('open', strcat('Select Folder n. ',string(i1))));
    
    cd(fold_res_fs_an(i1))

    load('AnalysisInformation.mat')
    AnalysisTypes(i1) = StabilityAnalysis{4}(1);
    if AnalysisTypes(i1) == "Machine Learning"; MLType = StabilityAnalysis{4}(2); end
    NumberOfAnalyses(i1) = StabilityAnalysis{1};

end

StabilityAnalysis{4} = ["Hybrid", strcat("SLIP and ML: ", MLType)];
cd(fold_res_fs_new)
save('AnalysisInformation.mat','StabilityAnalysis');

if NumberOfAnalyses(1) ~= NumberOfAnalyses(2); error('Incompatible analysis sizes'); end

SlipPercentage = .5; % Give the possibility to choose to the user!
MLPercentage   = .5;

ProgressBar.Indeterminate = 'off';
for i1 = 1:NumberOfAnalyses(1)
    ProgressBar.Value = i1/NumberOfAnalyses(1);
    ProgressBar.Message = strcat("Combination n. ", string(i1)," of ", string(NumberOfAnalyses(1)));
    drawnow

    for i2 = 1:2
        cd(fold_res_fs_an(i2))
        if AnalysisTypes(i2) == "Slip"
            load(strcat('Fs',num2str(i1),'.mat'));
            FsSlip = FactorSafety;
            clear('FactorSafety')
        elseif AnalysisTypes(i2) == "Machine Learning"
            load(strcat('FsML',num2str(i1),'.mat'));
            FsML = cellfun(@(x) x(:,2),FactorSafetyMachineLearning(2,:), 'UniformOutput',false);
            clear('FactorSafetyMachineLearning')
        end
    end

    FsSlipProbability = cellfun(@(x) 1-(x./(1+x)), FsSlip, 'UniformOutput',false); % Probability to have landslide occurrence
    FsSlipProbabilityMin = min(cellfun(@min, FsSlipProbability));
    FsSlipProbabilityIndexNan = cellfun(@isnan, FsSlipProbability, 'UniformOutput',false);
    for i2 = 1:length(FsSlipProbability)
        FsSlipProbability{i2}(FsSlipProbabilityIndexNan{i2}) = FsSlipProbabilityMin;
    end
    FsHybrid = cellfun(@(x,y) x*SlipPercentage+y*MLPercentage, FsSlipProbability, FsML, 'UniformOutput',false); % Probability to have landslide occurrence
    cd(fold_res_fs_new)
    save(strcat('FsH',num2str(i1),'.mat'), 'FsHybrid')
    
end
close(ProgressBar) % ProgressBar instead of Fig if on the app version
cd(fold0)

% Another idea to implement is to catch the best threshold for both
% analysys and combine rescaling probabilities from that value (see odd
% explanation, instead of having 1 for slip as watershed from o to inf you
% will have the best threshold; same for ML)