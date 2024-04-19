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
%   
%   - 'OutType', char : is to define what type of output you want. 'CellStr' 
%   if you want a cellstring containing the value chosen, or 'NumInd' if
%   you want the numerical index (referred to the possibilities for that
%   field), or 'LogInd' if you want a logical array. If no value is specified, 
%   then 'CellStr' will be taken as default!
%   
%   - 'DefInp', logical : is to define the default checkbox value for each
%   entry! It must have the same size of 'Values'. If no value is specified,
%   then an array with false values will be take as default.

%% Input Check
if not(iscell(Values)) && not(isstring(Values)) && not(ischar(Values)) && not(isdatetime(Values))
    error(['First input must be a cell containing string or chars, or ' ...
           'directly a string array or a char array!'])
end

Values = cellstr(Values); % Independently from the original input, now is a cellstr!

% Default sizes in y dimension
Bff = 25;
yHd = 22;
yPn = numel(Values)*25+yHd;
yCn = 60;
yHg = yPn+yCn+2*Bff;
xOb = 1;
xPn = 200;
xWd = xOb*xPn+2*Bff;

%% Settings
Title   = 'Select:'; % Default
BoxNum  = 1;         % Default
OutType = 'cellstr'; % Default

FntSize = 12;          % Default
PosWind = [800, 300, ...
           xWd, yHg];  % Default
CnfBtSz = [100, 22];   % Default
PnlSize = [xPn, yPn];  % Default
CBSize  = [xPn-5, 22]; % Default
DefInps = false(size( ...
            Values)); % Default

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false);

    InputTitle    = find(cellfun(@(x) all(strcmpi(x, "title"   )), vararginCp));
    InputPosition = find(cellfun(@(x) all(strcmpi(x, "position")), vararginCp));
    InputOutType  = find(cellfun(@(x) all(strcmpi(x, "outtype" )), vararginCp));
    InputDefInps  = find(cellfun(@(x) all(strcmpi(x, "definp"  )), vararginCp));

    if InputTitle   ; Title   = varargin{InputTitle+1    }; end
    if InputPosition; PosWind = varargin{InputPosition+1 }; end
    if InputOutType ; OutType = vararginCp{InputOutType+1}; end
    if InputDefInps ; DefInps = varargin{InputDefInps+1  }; end
end

if not(islogical(DefInps)) || (numel(DefInps) ~= numel(Values))
    error(['DefInp variable is not a logical array or it ' ...
           'does not have the same size of Values variable!'])
end

%% Initialization
MenuColor = '#F7BA94';
FigSettgs = uifigure('Name','Checkbox Window', 'WindowStyle','modal', ...
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
    PnlPos = [(FigDims(1)-PnlSize(1))/2, yCn+Bff*i1+yPn*(i1-1), PnlSize(1), PnlSize(2)];
    Panels{i1} = uipanel(FigSettgs, 'Title',Title, 'FontSize',FntSize, ...
                                    'BackgroundColor',MenuColor, 'Position',PnlPos);
end

%% Checkbox objects
ExCBSz = (PnlSize(2)-yHd)/numel(Values);
PnlCB  = cell(1, numel(Values));
for i1 = 1:BoxNum
    for i2 = 1:numel(Values)
        PnlCBPs   = [(PnlSize(1)-CBSize(1))/2, ExCBSz*(i2-1)+(ExCBSz-CBSize(2))/2, CBSize(1), CBSize(2)];
        PnlCB{i2} = uicheckbox(Panels{i1}, 'Text',Values{i2}, 'Position',PnlCBPs, 'Value',DefInps(i2));
    end
end

%% Resize
if FigSettgs.Position(4) > 600
    DiffSz = FigSettgs.Position(4)-600;

    FigSettgs.Position(4)   = FigSettgs.Position(4)-DiffSz;
    Panels{end}.Position(4) = Panels{end}.Position(4)-DiffSz;
    Panels{end}.Scrollable  = 'on';
end

ScreenSize = get(0, 'ScreenSize');
FigSettgs.Position(1:2) = (ScreenSize(3:4) - FigSettgs.Position(3:4)) ./ 2;

for i1 = 1:numel(Panels)
    yTFk = Panels{i1}.Position(4);
    FakeTxtArea = uitextarea(Panels{i1}, 'Position',[10, yTFk, 1, 1], ...
                                         'BackgroundColor',MenuColor, ...
                                         'Visible','off'); % This is necessary because with checkbox you do not have the possibility to resize!
end

%% Callback functions
function confirm
    Ind2Take = cellfun(@(x) x.Value, PnlCB);

    switch OutType
        case 'cellstr'
            OutVals = Values(Ind2Take);

        case 'numind'
            OutVals = find(Ind2Take);

        case 'logind'
            OutVals = Ind2Take;

        otherwise
            error('OutType not recognized!')
    end

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