function [OutVals] = checkbox2(Values, varargin)
% CREATE POLYGONS OF UNSTABLE, STABLE, AND INDECISION AREAS
%   
% Outputs:
%   OutVals : cell string array.
%   
% Required arguments:
%   - Values : is a char, a string, or a cell string/char that contains
%   values of checkboxes.
%   
% Optional arguments:
%   - 'Title', char/string/cell char : is the title of the checkbox. If no 
%   value is specified, then 'Select:' will be take as default.
%   
%   - 'Position', num array : is to assign the position> If no array is
%   specified, then [800, 300, 300, numel(Values)*150+50] will be used!

%% Input Check
if not(iscell(Values)) && not(isstring(Values)) && not(ischar(Values))
    error(['First input must be a cell containing string or chars, or ' ...
           'directly a string array or a char array!'])
end

Values = cellstr(Values); % Independently from the original input, now is a cellstr!

% Default sizes in y dimension
Bff = 25;
yPn = numel(Values)*25;
yCn = 60;
yHg = yPn+yCn;
xOb = 1;
xPn = 200;
xWd = xOb*xPn+2*Bff;

%% Settings
Title  = 'Select: '; % Default
BoxNum = 1;          % Default

FntSize = 12;          % Default
PosWind = [800, 300, ...
           xWd, yHg];  % Default
CnfBtSz = [100, 22];   % Default
PnlSize = [xPn, yHg-2* ...
           Bff-yCn];   % Default
CBSize  = [xPn-5, 22]; % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);
    varargin(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart), 'Uniform',false);

    vararginCopy = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCopy(StringPart) = varargin(StringPart);

    InputTitle    = find(cellfun(@(x) all(strcmpi(x, "title"   )), vararginCopy));
    InputPosition = find(cellfun(@(x) all(strcmpi(x, "position")), vararginCopy));

    if InputTitle   ; Title   = varargin{InputTitle+1   }; end
    if InputPosition; PosWind = varargin{InputPosition+1}; end
end

%% Initialization
MenuColor = '#F7BA94';
FigSettgs = uifigure('Name','Plot Settings', 'WindowStyle','modal', ...
                     'Color',MenuColor, 'Position',PosWind);
FigDims   = FigSettgs.Position(3:4);

%% Buttons
ConfirmButton = uibutton(FigSettgs, 'Text','Confirm', ...
                                    'Position',[(FigDims(1)-CnfBtSz(1))/2, ...
                                                (yCn-CnfBtSz(2)*1.1)/2, ...
                                                CnfBtSz(1), CnfBtSz(2)], ...
                                    'ButtonPushedFcn',@(src,event)confirm);

SelAllButton = uibutton(FigSettgs, 'Text','Select all', ...
                                   'Position',[(FigDims(1)-CnfBtSz(1))/2, ...
                                               (yCn+CnfBtSz(2)*1.1)/2, ...
                                               CnfBtSz(1), CnfBtSz(2)], ...
                                   'ButtonPushedFcn',@(src,event)selall);

%% Panel objects
Panels = cell(1, BoxNum);
for i1 = 1:BoxNum
    PnlPos = [(FigDims(1)-PnlSize(1))/2, yCn+yPn*(i1-1)+(yPn-PnlSize(2))/2, PnlSize(1), PnlSize(2)];
    Panels{i1} = uipanel(FigSettgs, 'Title',Title, 'FontSize',FntSize, ...
                                    'BackgroundColor',MenuColor, 'Position',PnlPos);
end

%% Checkbox objects
ExCBSz = (PnlSize(2)-22)/numel(Values);
PnlCB  = cell(1, numel(Values));
for i1 = 1:BoxNum
    for i2 = 1:numel(Values)
        PnlCBPs   = [(PnlSize(1)-CBSize(1))/2, ExCBSz*(i2-1)+(ExCBSz-CBSize(2))/2, CBSize(1), CBSize(2)];
        PnlCB{i2} = uicheckbox(Panels{i1}, 'Text',Values{i2}, 'Position',PnlCBPs);
    end
end

%% Resize
if FigSettgs.Position(4) > 600
    DiffSz = FigSettgs.Position(4)-600;

    FigSettgs.Position(4)   = FigSettgs.Position(4)-DiffSz;
    Panels{end}.Position(4) = Panels{end}.Position(4)-DiffSz;
    Panels{end}.Scrollable  = 'on';
end

%% Callback functions
function confirm
    Ind2Take = cellfun(@(x) x.Value, PnlCB);
    OutVals  = Values(Ind2Take);
    close(FigSettgs)
    return
end

function selall
    for z1 = 1:numel(PnlCB)
        PnlCB{z1}.Value = true;
    end
    return
end

uiwait(FigSettgs)

end