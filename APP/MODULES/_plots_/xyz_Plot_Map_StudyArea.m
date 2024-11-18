if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% File loading
sl = filesep;

load([fold_var,sl,'UserStudyArea_Answers.mat'], 'MunSel')
load([fold_var,sl,'StudyAreaVariables.mat'   ], 'MunPolygon','StudyAreaPolygon')

[SlFont, SlFnSz, LegPos  ] = load_plot_settings(fold_var);
[InfoDetExst, InfoDet2Use] = load_info_detected(fold_var);

if isscalar(MunSel) && strcmp(MunSel, 'None')
    MunSel = inputdlg2({'Name of area:'}, 'DefInp',{'Study Area'});
end

%% For scatter dimension
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'RefArea',.035, 'Extremes',true);

%% Loading Excel
MunClrs = zeros(length(MunPolygon),3);
Options = {'Yes, thanks', 'No, manually'};
RndClrs = uiconfirm(Fig, 'Do you want to assign random RGB triplets?', ...
                                 'Window type', 'Options',Options);
switch RndClrs
    case 'Yes, thanks'
        MunClrs = rand(length(MunPolygon),3);
    case 'No, manually'
        for i1 = 1:length(MunPolygon)
            MunClrs(i1,:) = uisetcolor(strcat("Select a color for municipality n. ",string(i1)));
        end
end

%% Plot of study area
CurrFln = 'Municipalities';
CurrFig = figure(1);
CurrAxs = axes(CurrFig);
hold(CurrAxs,'on')

set(CurrFig, 'Name',CurrFln);

PlysObjs = cell(1, size(MunPolygon,2));
for i1 = 1:size(MunPolygon,2)
    PlysObjs{i1} = plot(MunPolygon(i1), 'FaceColor',MunClrs(i1,:), 'FaceAlpha',1);
end

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1.5)

fig_settings(fold0)

if InfoDetExst
    DetObj = arrayfun(@(x,y) scatter(x, y, DetPixelSize, '^k','Filled'), InfoDet2Use{:,5}, InfoDet2Use{:,6});
    uistack(DetObj,'top')
end

if exist('LegPos', 'var')
    LegObjs = PlysObjs;
    LegCaps = MunSel;

    if InfoDetExst
        LegObjs = [LegObjs, {DetObj(1)}];
        LegCaps = [LegCaps; {'Points Analyzed'}];
    end

    hleg1 = legend([LegObjs{:}], LegCaps, ...
                   'FontName',SlFont, ...
                   'FontSize',SlFnSz, ...
                   'Location',LegPos, ...
                   'NumColumns',2, ...
                   'Box','off');
    
    hleg1.ItemTokenSize(1) = 3;
    
    legend('AutoUpdate','off')

    fig_rescaler(CurrFig, hleg1, LegPos)
end

set(CurrAxs, 'visible','off')

%% Export png
exportgraphics(CurrFig, [fold_fig,sl,CurrFln,'.png'], 'Resolution',600);