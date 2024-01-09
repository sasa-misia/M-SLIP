%% Os identification
if ispc
    sl = '\';
    user = string(getenv('username'));
elseif ismac
    sl = '/';
    user = string(getenv('USER'));
else
    disp('Platform not supported')
    error('PNS')
end

%% Check of toolboxes
MATLABVer = ver;
InstTools = {MATLABVer.Name};
ReqTools  = {'Image Processing Toolbox', 'Mapping Toolbox', 'Upslope Area Toolbox'};
OptTools  = {'Curve Fitting Toolbox', 'Deep Learning HDL Toolbox', 'Deep Learning Toolbox', ...
             'Lidar Toolbox', 'NCTOOLBOX Tools for read-only access to Common Data Model dataset', ...
             'Optimization Toolbox', 'Statistics and Machine Learning Toolbox'};

for i1 = 1:numel(ReqTools)
    CheckReq = any(strcmp(ReqTools{i1}, InstTools));
    if not(CheckReq)
        error(['You must install this Toolbox: ',ReqTools{i1}])
    end
end

for i1 = 1:numel(OptTools)
    CheckOpt = any(strcmp(OptTools{i1}, InstTools));
    if not(CheckOpt)
        warning(['You should install this Toolbox: ',OptTools{i1}])
    end
end

%% Removing existing variable 'folders' to create the new one
if exist('folders', 'var'); clear folders; end

%% Define folders
fold0 = pwd;

fold_raw            = strcat(fold0   , sl, 'Raw Data');
fold_raw_rain       = strcat(fold_raw, sl, 'Rainfalls');
fold_raw_rain_for   = strcat(fold_raw, sl, 'Rain Forecast');
fold_raw_det_ss     = strcat(fold_raw, sl, 'Detected Soil Slips');
fold_raw_mun        = strcat(fold_raw, sl, 'Municipalities');
fold_raw_lit        = strcat(fold_raw, sl, 'Lithology');
fold_raw_sat        = strcat(fold_raw, sl, 'Satellite Images');
fold_raw_road       = strcat(fold_raw, sl, 'Roads');
fold_raw_land_uses  = strcat(fold_raw, sl, 'Land Uses');
fold_raw_dtm        = strcat(fold_raw, sl, 'DTM');
fold_raw_veg        = strcat(fold_raw, sl, 'Vegetation');
fold_raw_temp       = strcat(fold_raw, sl, 'Temperature');
fold_raw_temp_for   = strcat(fold_raw, sl, 'Temperature Forecast');

fold_var            = strcat(fold0   , sl, 'Variables');

fold_res            = strcat(fold0   , sl, 'Results');
fold_res_fs         = strcat(fold_res, sl, 'Factors of Safety');
fold_res_ml         = strcat(fold_res, sl, 'ML Models and Predictions');
fold_res_flow       = strcat(fold_res, sl, 'Flow Paths');

fold_user           = strcat(fold0   , sl, 'User Control');

fold_fig            = strcat(fold0   , sl, 'Figures');

%% Creating folders
folders = who('-regexp','fold*');
for i = 1:length(folders)
    if ~exist(eval(folders{i}), 'dir')
        mkdir(eval(folders{i}))
    end
end

%% Saving
save('os_folders.mat', folders{:},'user','sl','CaseName');