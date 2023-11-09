function [OutVals] = inputdlg2(Prompts, varargin)
% CREATE POLYGONS OF UNSTABLE, STABLE, AND INDECISION AREAS
%   
% Outputs:
%   OutVals : cell string array.
%   
% Required arguments:
%   - Prompts : is a char, a string, or a cell string/char that contains
%   prompt messages for entries.
%   
% Optional arguments:
%   - 'DefInp', char/string/cell char : is to specify initial values in fields 
%   of input. If no value is specified, then '' will be take as default.
%   
%   - 'Position', num array : is to assign the position> If no array is
%   specified, then [800, 300, 300, numel(Prompts)*150+50] will be used!
%   
%   - 'Extendable', logical : is to allow adding fields (Add button will be 
%   shown)! If no value is specified, then 'false' will be taken as default!

%% Input Check
if not(iscell(Prompts)) && not(isstring(Prompts)) && not(ischar(Prompts))
    error(['First input must be a cell containing string or chars, or ' ...
           'directly a string array or a char array!'])
end

Prompts = cellstr(Prompts); % Independently from the original input, now is a cellstr!

% Default sizes in y dimension
Bff = 25;
yPn = 60;
yCn = 50;
yHg = numel(Prompts)*yPn+yCn;
xOb = 1;
xPn = 200;
xWd = xOb*xPn+2*Bff;

%% Settings
DefInps = repmat({''}, 1, numel(Prompts)); % Default
Extndbl = false; % Default

FntSize = 12;         % Default
PosWind = [800, 300, ...
           xWd, yHg]; % Default
CnfBtSz = [100, 22];  % Default
PnlSize = [xPn, 40];  % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(StringPart) = varargin(StringPart);

    InputDefInps  = find(cellfun(@(x) all(strcmpi(x, "definp"    )), vararginCopy));
    InputPosition = find(cellfun(@(x) all(strcmpi(x, "position"  )), vararginCopy));
    InputExtndbl  = find(cellfun(@(x) all(strcmpi(x, "extendable")), vararginCopy));

    if InputDefInps ; DefInps = cellstr(varargin{InputDefInps+1 }); end
    if InputPosition; PosWind = varargin{InputPosition+1}         ; end
    if InputExtndbl ; Extndbl = varargin{InputExtndbl+1 }         ; end
end

%% Initialization
MenuColor = '#F7BA94';
FigSettgs = uifigure('Name','Input Window', 'WindowStyle','modal', ...
                     'Color',MenuColor, 'Position',PosWind);
FigDims   = FigSettgs.Position(3:4);

%% Buttons
ConfirmButton = uibutton(FigSettgs, 'Text','Confirm', ...
                                    'Position',[(FigDims(1)-CnfBtSz(1))/2, ...
                                                (yCn-CnfBtSz(2))/2, ...
                                                CnfBtSz(1), CnfBtSz(2)], ...
                                    'ButtonPushedFcn',@(src,event)confirm);

if Extndbl
    AddButton = uibutton(FigSettgs, 'Text','Add', ...
                                    'Position',[(FigDims(1)-CnfBtSz(1)/2)/2 - 0.20*FigDims(1), ...
                                                (yCn-CnfBtSz(2))/2, ...
                                                CnfBtSz(1)/2, CnfBtSz(2)], ...
                                    'ButtonPushedFcn',@(src,event)add);
    OldPosCn = ConfirmButton.Position;
    ConfirmButton.Position(1) = OldPosCn(1) + 0.20*FigDims(1);
end

%% General panel object
GPnlPos = [(FigDims(1)-PnlSize(1))/2, yCn, PnlSize(1), yHg-yCn];
GenPanl = uipanel(FigSettgs, 'FontSize',FntSize, 'BorderType','none', ...
                             'BackgroundColor',MenuColor, 'Position',GPnlPos);

%% Panel objects
ExtBrd = 1;
Panels = cell(1, numel(Prompts));
for i1 = 1:numel(Prompts)
    PnlPos = [ExtBrd, yPn*(i1-1)+(yPn-PnlSize(2))/2, PnlSize(1)-2*ExtBrd, PnlSize(2)];
    Panels{i1} = uipanel(GenPanl, 'Title',Prompts{i1}, 'FontSize',FntSize, ...
                                  'BackgroundColor',MenuColor, 'Position',PnlPos);
end

%% Text area objects
PnlTAPs = [0, 0, PnlSize(1)-2*ExtBrd, PnlSize(2)-20];
PnlTA   = cell(1, numel(Prompts));
for i1 = 1:numel(Prompts)
    PnlTA{i1} = uitextarea(Panels{i1}, 'Value',DefInps{i1}, 'Position',PnlTAPs);
end

%% Resize
if FigSettgs.Position(4) > 600
    DiffSz = FigSettgs.Position(4)-600;

    FigSettgs.Position(4) = FigSettgs.Position(4)-DiffSz;
    GenPanl.Position(4)   = GenPanl.Position(4)-DiffSz;
    GenPanl.Scrollable    = 'on';
end

%% Callback functions
function confirm
    OutVals = cellfun(@(x) x.Value{:}, PnlTA, 'UniformOutput',false);

    close(FigSettgs)
    return
end

function add % Probably to fix for sizes (when scrollable)
    OldFigSz = FigSettgs.Position;
    OldGPnSz = GenPanl.Position;
    OldPnlSz = Panels{end}.Position;
    OldTASz  = PnlTA{end}.Position;

    yPnNew = Panels{2}.Position(2) - Panels{1}.Position(2);
    if FigSettgs.Position(4) + yPnNew < 600
        FigSettgs.Position(4) = OldFigSz(4) + yPnNew;
        GenPanl.Position(4)   = OldGPnSz(4) + yPnNew;
    end

    for z1 = 1:numel(Panels)
        Panels{z1}.Position(3:4) = OldPnlSz(3:4);
        PnlTA{z1}.Position       = OldTASz;
    end

    NewPnlPs  = [OldPnlSz(1), yPnNew*numel(Panels)+(yPnNew-OldPnlSz(4))/2, OldPnlSz(3), OldPnlSz(4)];
    Panels    = [Panels, {uipanel(GenPanl, 'Title','New Entry', 'FontSize',FntSize, ...
                                           'BackgroundColor',MenuColor, 'Position',NewPnlPs)}];
    PnlTA     = [PnlTA, {uitextarea(Panels{end}, 'Value','New label', 'Position',OldTASz)}];

    % Scroll enable
    if FigSettgs.Position(4) + yPnNew >= 600
        GenPanl.Scrollable    = 'on';
    end
    return
end

uiwait(FigSettgs)

end