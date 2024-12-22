if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Options
sl = filesep;
load([fold0,sl,'os_folders.mat'        ], 'fold_res_fs','fold_res_ml','fold_var')
load([fold_var,sl,'GridCoordinates.mat'], 'IndexDTMPointsInsideStudyArea')

FsFolderName = char(inputdlg2({['New analysis folder name (inside ', ...
                                'Results->Factors of Safety):']}, 'DefInp',{'EventDate-Hybrid'}));

if exist([fold_res_fs,sl,FsFolderName], 'dir')
    Options = {'Yes, thanks', 'No, for God!'};
    DelAnsw = uiconfirm(Fig, [FsFolderName,' is an existing folder. Do you want to overwrite it?'], ...
                            'Overwrite', 'Options',Options);
    switch DelAnsw
        case 'Yes, thanks.'
            rmdir([fold_res_fs,sl,FsFolderName],'s')
            mkdir([fold_res_fs,sl,FsFolderName])
        case 'No, for God!'
            return
    end
else
    mkdir([fold_res_fs,sl,FsFolderName])
end

fold_res_fs_new = [fold_res_fs,sl,FsFolderName];

ImpSLIP = str2double(char(inputdlg2({'SLIP importance (from 0 to 1):'}, 'DefInp',{'0.5'})));
if ImpSLIP <= 0 || ImpSLIP >= 1
    error('Importance of SLIP must be greater than 0 and smaller than 1!')
end

tolHours = 72; % 24 is better if you want more precise results

%% Data loading
[fold_anls_src, PossDatetimes, AnalysisTypes] = deal(cell(1, 2));

% SLIP
fold_anls_src{1} = char(uigetdir(fold_res_fs, strcat('Select SLIP folder')));

load([fold_anls_src{1},sl,'AnalysisInformation.mat'], 'StabilityAnalysis')

AnalysisTypes{1} = char(StabilityAnalysis{4}(1));
PossDatetimes{1} = StabilityAnalysis{2};

% ML
fold_anls_src{2} = char(uigetdir(fold_res_ml, strcat('Select ML folder')));

load([fold_anls_src{2},sl,'PredictionsStudy.mat'], 'EventsInfo')
load([fold_anls_src{2},sl,'MLMdlB.mat'          ], 'ModelInfo')

AnalysisTypes{2} = char(ModelInfo.Type);
PossDatetimes{2} = [EventsInfo{'PredictionDate',:}{:}];

% General info
Dttm2TakeML = zeros(1, numel(PossDatetimes{1}));
for i1 = 1:numel(Dttm2TakeML)
    [MinDiffBtwnDttm, TmpInd] = min(abs(PossDatetimes{2} - PossDatetimes{1}(i1)));
    if hours(MinDiffBtwnDttm) > tolHours
        error(['No date near to ',char(PossDatetimes{1}(i1)), ...
               ' in ML predictions (more than 24 hours of difference)!'])
    else
        Dttm2TakeML(i1) = TmpInd;
    end
end

%% Core
StabilityAnalysis{4} = "Hybrid";
save([fold_res_fs_new,sl,'AnalysisInformation.mat'], 'StabilityAnalysis');

ProgressBar.Indeterminate = 'off';
for i1 = 1:numel(PossDatetimes{1})
    ProgressBar.Value = i1/numel(PossDatetimes{1});
    ProgressBar.Message = ['Combination n. ',num2str(i1),' of ',num2str(numel(PossDatetimes{1}))];

    for i2 = 1:numel(fold_anls_src)
        if strcmpi(AnalysisTypes{i2}, 'Slip')
            PrbSLIP = load_fs2probs(fold_anls_src{i2}, IndexDTMPointsInsideStudyArea, indAn2Load=i1);

        else
            PrbMLrn = load_fs2probs(fold_anls_src{i2}, IndexDTMPointsInsideStudyArea, indAn2Load=Dttm2TakeML(i1));
        end
    end

    FsHybrid = cellfun(@(x,y) x*ImpSLIP + y*(1 - ImpSLIP), PrbSLIP, PrbMLrn, 'UniformOutput',false); % Probability to have landslide occurrence
    
    save([fold_res_fs_new,sl,'FsH',num2str(i1),'.mat'], 'FsHybrid')
end
ProgressBar.Indeterminate = 'on';