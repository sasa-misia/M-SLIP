function plot_settings(varargin)
% Plot settings menu
% Devi inserire come argomento la cartella dove salvare le opzioni scelte.

curr_path = pwd;
if isempty(varargin); save_path = curr_path; else save_path = varargin{1}; end

FigSettings = uifigure('Name','Plot Settings', 'WindowStyle','modal', ...
                       'Color',[0.97, 0.73, 0.58], 'Position',[800, 300, 400, 400]);

FigDimensions = FigSettings.Position(3:4);

%% Options
FontList = listfonts;
FontSizeList = string(4:2:80);
Locations = {'north', 'south', 'east', 'west', 'northeast', 'northwest', ...
             'southeast', 'southwest', 'best', 'layout', 'northoutside', ...
             'southoutside', 'eastoutside', 'westoutside'};

LocationsRed = {'northeast', 'northwest', 'southeast', 'southwest'};

%% Confirm button
ConfirmButton = uibutton(FigSettings, 'Text','Confirm', ...
                                      'Position',[(FigDimensions(1)-100)/2, ...
                                                  (FigDimensions(2)-22)/2-155, 100, 22], ...
                                      'ButtonPushedFcn',@(src,event)confirm);

%% Panel objects
PanelFont = uipanel(FigSettings, 'Title','Font settings', 'FontSize',12, ...
                                 'BackgroundColor',[0.97, 0.73, 0.58], ...
                                 'Position',[(FigDimensions(1)-300)/2, 320, 300, 60]);

PanelLgnd = uipanel(FigSettings, 'Title','Legend settings', 'FontSize',12, ...
                                 'BackgroundColor',[0.97, 0.73, 0.58], ...
                                 'Position',[(FigDimensions(1)-300)/2, 250, 300, 60]);

PanelScBar = uipanel(FigSettings, 'Title','ScaleBar settings', 'FontSize',12, ...
                                  'BackgroundColor',[0.97, 0.73, 0.58], ...
                                  'Position',[(FigDimensions(1)-300)/2, 180, 300, 60]);

PanelCmpRose = uipanel(FigSettings, 'Title','Compass rose settings', 'FontSize',12, ...
                                    'BackgroundColor',[0.97, 0.73, 0.58], ...
                                    'Position',[(FigDimensions(1)-300)/2, 110, 300, 60]);

PanelTickAx = uipanel(FigSettings, 'BackgroundColor',[0.97, 0.73, 0.58], ...
                                   'Position',[(FigDimensions(1)-150)/2, 70, 150, 30]);

%% Label objects
LblFontSize = uilabel(PanelFont, 'Text','Size', 'Position',[30 7 40 30]);
LblFont = uilabel(PanelFont, 'Text','Style', 'Position',[145 7 40 30]);

LblLgndPos = uilabel(PanelLgnd, 'Text','Positon', 'Position',[135 7 100 30]);

LblScBarPos = uilabel(PanelScBar, 'Text','Positon', 'Position',[135 7 100 30]);

LblCmpRosePos = uilabel(PanelCmpRose, 'Text','Positon', 'Position',[135 7 100 30]);

%% Check box objects
ChBoxLgnd = uicheckbox(PanelLgnd, 'Text','Visible', 'Position',[35 7 100 30]);

ChBoxScBar = uicheckbox(PanelScBar, 'Text','Visible', 'Position',[35 7 100 30]);

ChBoxCmpRose = uicheckbox(PanelCmpRose, 'Text','Visible', 'Position',[35 7 100 30]);

ChBoxTickAx = uicheckbox(PanelTickAx, 'Text','Tick on axes', 'Position',[36 1 100 30]);

%% Drop down objects
FontDD = uidropdown(PanelFont, 'Items',FontList, 'Position',[180, 11, 100, 22]);
FontSizeDD = uidropdown(PanelFont, 'Items',FontSizeList, 'Editable','on', ...
                                   'Position',[60, 11, 47, 22]);

LgndPosDD = uidropdown(PanelLgnd, 'Items',Locations, 'Position',[180, 11, 100, 22]);

ScBarPosDD = uidropdown(PanelScBar, 'Items',LocationsRed, 'Position',[180, 11, 100, 22]);

CmpRosePosDD = uidropdown(PanelCmpRose, 'Items',LocationsRed, 'Position',[180, 11, 100, 22]);

    %% Callback functions
    function confirm
        FigSettingsInputs = {};
        Font = FontDD.Value;
        FontSize = eval(FontSizeDD.Value);
        VariablesSettings = {'Font', 'FontSize', 'FigSettingsInputs'};

        if ChBoxLgnd.Value
            LegendPosition = LgndPosDD.Value;
            VariablesSettings = [VariablesSettings, {'LegendPosition'}];
        end

        if ChBoxScBar.Value
            ScaleBarPosition = ScBarPosDD.Value;
            VariablesSettings = [VariablesSettings, {'ScaleBarPosition'}];
            FigSettingsInputs = [FigSettingsInputs, {'ScaleBar', 'PositionScaleBar', ScaleBarPosition}];
        end

        if ChBoxCmpRose.Value
            CompassRosePosition = CmpRosePosDD.Value;
            VariablesSettings = [VariablesSettings, {'CompassRosePosition'}];
            FigSettingsInputs = [FigSettingsInputs, {'CompassRose', 'PositionCompassRose', CompassRosePosition}];
        end

        if ChBoxTickAx.Value
            FigSettingsInputs = [FigSettingsInputs, {'AxisTick'}];
        end

        cd(save_path)
        save('PlotSettings.mat', VariablesSettings{:})
        cd(curr_path)
        close(FigSettings)
    end

end