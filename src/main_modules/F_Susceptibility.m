if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Message','Reading files...', 'Cancelable','off');
drawnow

%% Loading data
sl = filesep;

load([fold_var,sl,'GridCoordinates.mat'     ], 'xLongAll','yLatAll','IndexDTMPointsInsideStudyArea')
load([fold_var,sl,'MorphologyParameters.mat'], 'SlopeAll')
load([fold_var,sl,'SoilParameters.mat'      ], 'CohesionAll','PhiAll','nAll','AAll')
load([fold_var,sl,'VegetationParameters.mat'], 'RootCohesionAll')
load([fold_var,sl,'StudyAreaVariables.mat'  ], 'StudyAreaPolygon')

[SlFont, SlFnSz, LegPos] = load_plot_settings(fold_var);

%% Inputs
InpVls = inputdlg2({'Indicate soil Gs [-]:', 'Indicate lambda λ [-]:', ...
                    'Indicate alpha α [-]:', 'Sr0 [-]', 'Analysis depth [m]'}, ...
                                'DefInp',{'2.7', '0.4', '3.4', '0.7', '1.2'});

Gs     = str2double(InpVls{1});
Lambda = str2double(InpVls{2});
Alpha  = str2double(InpVls{3});
Sr0    = str2double(InpVls{4});
H      = str2double(InpVls{5});
GammaW = 10;

SusceptibilityInfo = table(Gs, Lambda, Alpha, Sr0, H, 'VariableNames',{'Gs', 'Lambda', 'Alpha', 'Sr0', 'H'});

%% Extraction of parameters
xLonStudy = cellfun(@(x,y) x(y), xLongAll        , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
yLatStudy = cellfun(@(x,y) x(y), yLatAll         , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
SlopStudy = cellfun(@(x,y) x(y), SlopeAll        , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
CoheStudy = cellfun(@(x,y) x(y), CohesionAll     , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
PhiStudy  = cellfun(@(x,y) x(y), PhiAll          , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
nPorStudy = cellfun(@(x,y) x(y), nAll            , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
AparStudy = cellfun(@(x,y) x(y), AAll            , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);
RChsStudy = cellfun(@(x,y) x(y), RootCohesionAll , IndexDTMPointsInsideStudyArea, 'UniformOutput',false);

%% Core
GSoil = cellfun(@(x) Gs*(1-x)*GammaW + Sr0*x*GammaW, nPorStudy, 'UniformOutput',false);
SusceptibilityFactor = cellfun(@(a,b,c,d,e,f) 1 - ( (((1-tand(a)./tand(b)).*c.*H.*cosd(b).*sind(b))-(d+e)) ...
                                                     ./ (f*Sr0*(1-Sr0)^Lambda) ).^(1./Alpha),...
                                        PhiStudy, SlopStudy, GSoil, CoheStudy, RChsStudy, AparStudy, 'UniformOutput',false);

IndCmplx = cellfun(@(x) imag(x)~=0, SusceptibilityFactor, 'UniformOutput',false); % If imaginary part is different than 0, the number is complex and will be excluded!
for i1 = 1:numel(SusceptibilityFactor)
    SusceptibilityFactor{i1}(IndCmplx{i1}) = NaN;
    SusceptibilityFactor{i1} = real(SusceptibilityFactor{i1}); % To convert in real!
end

IndNaNs = cellfun(@(x) find(not(isnan(x))), SusceptibilityFactor, 'UniformOutput',false);
AllNaNs = cellfun(@isempty, IndNaNs);
if all(AllNaNs)
    error('No susceptibility values inside your area! Please check the script...')
end

%% Saving
saveswitch([fold_var,sl,'Susceptibility.mat'], {'SusceptibilityFactor', 'SusceptibilityInfo'})

%% Plot (to move in a separate script)
%% Preliminary operations
[PixelSize, DetPixelSize] = pixelsize(StudyAreaPolygon, 'Extremes',true); % 'RefArea',0.035

%% Definition of classes
SuscRngs = [0, 0.3, 0.45, 0.75, 1];
SuscHigh = cellfun(@(x) x>=SuscRngs(1) & x<SuscRngs(2) , SusceptibilityFactor, 'UniformOutput',false);
SuscMdHg = cellfun(@(x) x>=SuscRngs(2) & x<SuscRngs(3) , SusceptibilityFactor, 'UniformOutput',false);
SuscMidd = cellfun(@(x) x>=SuscRngs(3) & x<SuscRngs(4) , SusceptibilityFactor, 'UniformOutput',false);
SuscLow  = cellfun(@(x) x>=SuscRngs(4) & x<=SuscRngs(5), SusceptibilityFactor, 'UniformOutput',false);

SuscHgCl = [128,   0,   0]./255;
SuscMHCl = [255,   0,   0]./255;
SuscMdCl = [255, 117,  20]./255;
SuscLwCl = [229, 190,   1]./255;

%% Plot
CurrFln = ['Susceptibility (Sr0=',num2str(Sr0),')'];
CurrFig = figure(1);
CurrAxs = axes('Parent',CurrFig);

set(CurrFig, 'Name',CurrFln, 'Visible','on')
hold(CurrAxs,'on')

plot(StudyAreaPolygon, 'FaceColor','none', 'LineWidth',1)

ObjHigh = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                          'MarkerFaceColor',SuscHgCl, ...
                                                          'MarkerEdgeColor','none'), ...
                                xLonStudy, yLatStudy, SuscHigh, 'UniformOutput',false);

ObjMdHg = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                          'MarkerFaceColor',SuscMHCl, ...
                                                          'MarkerEdgeColor','none'), ...
                                xLonStudy, yLatStudy, SuscMdHg, 'UniformOutput',false);

ObjMidd = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                          'MarkerFaceColor',SuscMdCl, ...
                                                          'MarkerEdgeColor','none'), ...
                                xLonStudy, yLatStudy, SuscMidd, 'UniformOutput',false);

ObjLow  = cellfun(@(x,y,z) scatter(x(z), y(z), PixelSize, 'Marker','o', ...
                                                          'MarkerFaceColor',SuscLwCl, ...
                                                          'MarkerEdgeColor','none'), ...
                                xLonStudy, yLatStudy, SuscLow , 'UniformOutput',false);

ObjPlot = {ObjHigh, ObjMdHg, ObjMidd, ObjLow};
LegObjs = cellfun(@(x) x(1), ObjsPlt);

LegCaps = arrayfun(@(x,y) [num2str(x),' - ',num2str(y)], SuscRngs(1:end-1), SuscRngs(2:end), 'UniformOutput',false);

fig_settings(fold0)

LegObj = legend([LegObjs{:}], LegCaps{:}, 'Location',LegPos, ...
                                          'FontName',SlFont, ...
                                          'FontSize',SlFnSz);

LegObj.Title.String={'{\it m_{cr}}'};

fig_rescaler(CurrFig, LegObj, LegPos)

exportgraphics(CurrFig, [fold_fig,sl,CurrFln,'.png'], 'Resolution',600);