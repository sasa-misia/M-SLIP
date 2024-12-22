if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Message','Reading files...', ...
                                 'Cancelable','off', 'Indeterminate','on');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'   ], 'IndexDTMPointsInsideStudyArea','xLongAll','yLatAll')
load([fold_var,sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon')
load([fold_var,sl,'UserMorph_Answers.mat' ], 'OrthophotoAnswer')

[SlFont, SlFnSz, LegPos  ] = load_plot_settings(fold_var);
[InfoDetExst, InfoDet2Use] = load_info_detected(fold_var);

if OrthophotoAnswer
    load([fold_var,sl,'Orthophoto.mat'], 'ZOrtho','xLongOrtho','yLatOrtho')
end

%% For scatter dimension
PixelScale = 0.3 * abs(yLatAll{1}(2,1) - yLatAll{1}(1,1)) / 6e-05;
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, Extremes=true, FinScale=PixelScale); % 'RefArea',0.035

%% Options
ProgressBar.Message = 'Options...';

OptsAns = checkbox2({'Show plots', 'Middle instability'}, 'DefInp',[0, 1], 'OutType','LogInd');
ShowPlt = OptsAns(1);
MidClss = OptsAns(2);

UnstClr = [229, 81 , 55 ]./255;
StabClr = [189, 236, 232]./255;
MiddClr = [255, 255, 0  ]./255;

IndLeg = [true, MidClss, true];

foldFS = uigetdir(fold_res_fs, 'Select analysis folder');
[~, namefoldFS] = fileparts(foldFS);

figure(Fig)
drawnow

%% Pre processing
ProgressBar.Message = 'Pre processing...';

[UnstProbs, ~, AnlType, LimVals, AnlDate] = load_fs2probs(foldFS, IndexDTMPointsInsideStudyArea);

disp(['Range of results is [',char(strjoin(string(LimVals), '; ')),']'])

switch AnlType
    case "Slip"
        InpThr = inputdlg2({'Fs above which the point is stable:', ...
                            'Fs below which the point is unstable:'}, 'DefInp',{'1.5','1'});

        MinFsStab = str2double(InpThr{1});
        MaxFsUnst = str2double(InpThr{2});

        MinPrUnst = 1 - (MaxFsUnst - LimVals(1)) / diff(LimVals);
        MaxPrStab = 1 - (MinFsStab - LimVals(1)) / diff(LimVals);

        LegCpsT = {['High Susceptibility ({\itFS} <= ',num2str(MaxFsUnst, '%4.2f'),')'], ...
                   ['Medium Susceptibility (',num2str(MaxFsUnst, '%4.2f'),' < {\itFS} <= ',num2str(MinFsStab, '%4.2f'),')'], ...
                   ['Low Susceptibility ({\itFS} > ',num2str(MinFsStab, '%4.2f'),')']};

    case {"ML", "Hybrid"}
        InpThr = inputdlg2({'Prob above which the point is unstable:', ...
                            'Prob below which the point is stable:'}, 'DefInp',{'0.8','0.3'});

        MinPrUnst = str2double(InpThr{1});
        MaxPrStab = str2double(InpThr{2});

        LegCpsT = {['High Susceptibility ({\itProbability} >= ',num2str(MinPrUnst*100, '%4.2f'),'%)'], ...
                   ['Medium Susceptibility (',num2str(MaxPrStab*100, '%4.2f'),'% <= {\itProbability} < ',num2str(MinPrUnst*100, '%4.2f'),'%)'], ...
                   ['Low Susceptibility ({\itProbability} < ',num2str(MaxPrStab*100, '%4.2f'),'%)']};

    otherwise
        error('Analysis type not recognized!')
end

if MinPrUnst < MaxPrStab
    error('Bottom value must be > than top!')
end

IndUnstRel = cellfun(@(x) x >= MinPrUnst, UnstProbs, 'UniformOutput',false);
IndMiddRel = cellfun(@(x) (x >= MaxPrStab) & (x < MinPrUnst), UnstProbs, 'UniformOutput',false);
IndStabRel = cellfun(@(x) x <  MaxPrStab, UnstProbs, 'UniformOutput',false);

%% Creation of point included in classes of FS
NumUnst = cellfun(@(x) sum(x), IndUnstRel);

IndUnst = cellfun(@(x,y) x(y), IndexDTMPointsInsideStudyArea, IndUnstRel, 'UniformOutput',false);
IndMidd = cellfun(@(x,y) x(y), IndexDTMPointsInsideStudyArea, IndMiddRel, 'UniformOutput',false);
IndStab = cellfun(@(x,y) x(y), IndexDTMPointsInsideStudyArea, IndStabRel, 'UniformOutput',false);

xLonUnst = cellfun(@(x,y) x(y), xLongAll, IndUnst, 'UniformOutput',false);
xLonStab = cellfun(@(x,y) x(y), xLongAll, IndStab, 'UniformOutput',false);

yLatUnst = cellfun(@(x,y) x(y), yLatAll, IndUnst, 'UniformOutput',false);
yLatStab = cellfun(@(x,y) x(y), yLatAll, IndStab, 'UniformOutput',false);

xLonMidd = cellfun(@(x,y) x(y), xLongAll, IndMidd,'UniformOutput',false);
yLatMidd = cellfun(@(x,y) x(y), yLatAll , IndMidd,'UniformOutput',false);

%% Plot of FS figure
ProgressBar.Message = 'Plotting...';

CurrFln = char(datetime(AnlDate, 'Format','dd-MM-yyyy HH-mm'));
CurrFig = figure(1);
CurrAxs = axes('Parent',CurrFig);
hold(CurrAxs,'on');

set(CurrFig, 'Name',CurrFln, 'Visible','off');
set(CurrAxs, 'visible','off')

if OrthophotoAnswer
    for i1 = 1:numel(ZOrtho)
        fastscattergrid(ZOrtho{i1}, xLongOrtho{i1}, yLatOrtho{i1}, 'Mask',StudyAreaPolygon, ...
                                                                   'Parent',CurrAxs, 'Alpha',.7);
    end
end

ObjUnst = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', 'MarkerFaceColor',UnstClr, ...
                                                  'MarkerEdgeColor','none'), ...
                                            xLonUnst, yLatUnst, 'UniformOutput',false);

ObjStab = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', 'MarkerFaceColor',StabClr, ...
                                                  'MarkerEdgeColor','none'), ...
                                            xLonStab, yLatStab, 'UniformOutput',false);

ObjMidd = {};
if MidClss
    ObjMidd = cellfun(@(x,y) scatter(x, y, PixelSize, 'Marker','o', 'MarkerFaceColor',MiddClr, ...
                                                      'MarkerEdgeColor','none'), ...
                                                xLonMidd, yLatMidd, 'UniformOutput',false);
end

if InfoDetExst
    ObjDet = arrayfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDet2Use{:,5}, InfoDet2Use{:,6});
end

ObjsPlt = {ObjUnst, ObjMidd, ObjStab};

if MidClss
    for i1 = 1:length(ObjUnst)
        uistack(ObjMidd{i1},'top')
    end
end

if InfoDetExst
    uistack(ObjDet,'top')
end

for i1 = 1:length(ObjUnst)
    uistack(ObjUnst{i1},'top')
end

plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1, 'LineStyle','--')

fig_settings(fold0)

if not(isempty(LegPos))
    ObjsPlt = ObjsPlt(IndLeg);
    LegObjs = cellfun(@(x) x(1), ObjsPlt);
    LegCaps = LegCpsT(IndLeg);

    if InfoDetExst
        LegObjs = [LegObjs, {ObjDet(1)}];
        LegCaps = [LegCaps, {'Analyzed points'}];
    end

    [CurrLeg, CurrLIc, ...
        CurrLPl] = legend([LegObjs{:}], LegCaps, 'Location',LegPos, ...
                                                 'FontName',SlFont, ...
                                                 'FontSize',SlFnSz, ...
                                                 'Box','off');

    fix_leg_scatter(CurrLeg, CurrLIc, CurrLPl, 5, LegPos, xTxtPos=.2)

    % legend('AutoUpdate','off');

    fig_rescaler(CurrFig, CurrLeg, LegPos)
end

% title(strcat("Safety Factors of ",string(EventFS)," event"),...
%             'FontName',SelFont,'FontSize',SelFntSz*1.4)

%% Saving...
ProgressBar.Message = 'Saving...';

if ~exist([fold_fig,sl,namefoldFS], 'dir')
    mkdir([fold_fig,sl,namefoldFS])
end

exportgraphics(CurrFig, [fold_fig,sl,namefoldFS,sl,CurrFln,'.png'], 'Resolution',600);

%% Show Fig
if ShowPlt
    set(CurrFig, 'Visible','on');
else
    close(CurrFig)
end