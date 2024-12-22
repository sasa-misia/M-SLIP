function [OutVals, OutLbls] = listdlg2(Prompts, Values, varargin)
% CREATE POLYGONS OF UNSTABLE, STABLE, AND INDECISION AREAS
%   
% Outputs:
%   OutVals : cell string array.
%   or
%   [OutVals, OutLbls] : cell string array, cells containing cell string array.
%   
% Required arguments:
%   - Prompts : is a char, a string, or a cell string/char that contains
%   prompt messages for entries.
%   
%   - Values : is a string array or a cell containing different string
%   arrays in case of multiprompt.
%   
% Optional arguments:
%   - 'PairLabels', logical : is to create another entry on the left whwre 
%   you give the lable name of the entry. If no value is specified, then 'false' 
%   will be take as default.
%   
%   - 'DefLabels', logical : is to specify the default names of the new
%   labels. If 'PairLabels' is set to false it will have no effect.
%   
%   - 'SaveOut', logical : is to specify if you want to save the outputs in
%   a file. If no value is specified, outputs will not be saved.
%   
%   - 'SavePath', char : is to assign a folder where to save the output of 
%   the function. If no value is specified, the path is the current.
%   
%   - 'NameOut', char : is to assign a name to the outputs to save. If no 
%   value is specified, the name is 'LstOut'.
%   
%   - 'Position', num array : is to assign the position> If no array is
%   specified, then [800, 300, 300, numel(Prompts)*150+50] will be used!
%   
%   - 'Extendable', logical : is to allow adding fields (Add button will be 
%   shown)! If no value is specified, then 'false' will be taken as default!
%   
%   - 'OutType', char : is to define what type of output you want. 'CellStr' 
%   if you want a cellstring containing the value chosen, or 'NumInd' if
%   you want the numerical index (referred to the possibilities for that
%   field). If no value is specified, then 'CellStr' will be taken as default!
%   
%   - 'DefInp', num array : is to define the default dropdown value for each
%   entry! It must have the same size of 'Prompts' and must contain a number 
%   that not exceed the number of 'Values' for each prompt. If no value is 
%   specified, then an array with ones values will be take as default.
%   
%   - 'Unique', logical : is to define if a unique match for each entry is
%   desired. In other words, for each dropdown it is allowed only a single
%   and unique value, not chosen in other dropdown lists.

%% Input Check
if not(iscell(Prompts)) && not(isstring(Prompts)) && not(ischar(Prompts))
    error(['First input must be a cell containing string or chars, or ' ...
           'directly a string array or a char array!'])
end
if not(iscell(Values)) && not(isstring(Values)) && not(ischar(Values)) && not(isdatetime(Values))
    error(['Second input must be a cell containing string or chars, or ' ...
           'directly a string array or a char array!'])
end

if not(iscell(Values)); Values  = {cellstr(Values)}; end
if iscellstr(Values)  ; Values  = {Values}         ; end

Prompts = cellstr(Prompts); % Independently from the original input, now is a cellstr!
Values  = cellfun(@(x) cellstr(x), Values, 'UniformOutput',false);  % A repetition is necessary because if it was a cell originally, now is a cellstr (all values are chars now)!

ChckStrctVals = all(cellfun(@(x) iscellstr(x), Values));
if not(ChckStrctVals); error('There is a problem in the structure of Values input!'); end

OrNumVals = numel(Values);

CheckEqInp = (numel(Prompts) == numel(Values));
if not(CheckEqInp) && isscalar(Values)
    warning(['You have multiple prompts but just one array of options! ' ...
             'This array will be repeated for each prompt.'])
    Values = repmat(Values, 1, numel(Prompts));
elseif not(CheckEqInp) && (numel(Values) > 1)
    error('Sizes of 1st and 2nd inputs do not match!')
end

% Default sizes in y dimension
Bff = 25;
yPn = 120;
yCn = 50;
yHg = numel(Prompts)*yPn+yCn;
xOb = 1;
xPn = 200;
xWd = xOb*xPn+2*Bff;

%% Settings
CurrPth = pwd;
RnmLbls = false;      % Default
SaveOut = false;      % Default
SavePth = CurrPth;    % Default
NameOut = 'LstOut';   % Default
Extndbl = false;      % Default
OutType = 'cellstr';  % Default
UnqMtch = false;      % Default

FntSize = 12;         % Default
PosWind = [800, 300, ...
           xWd, yHg]; % Default
CnfBtSz = [100, 22];  % Default
PnlSize = [xPn, 80];  % Default
DDBtSzs = [120, 22];  % Default
DefLbls = repmat({'New label'}, 1, numel(Prompts)); % Default

% Search for Suggested Inputs
DefInps = ones(size(Prompts)); % Default
for i1 = 1:numel(DefInps)
    SpltStr = strsplit(Prompts{i1});
    SuggInd = find(contains(Values{i1}, wildcardPattern+SpltStr{1}+wildcardPattern));
    if not(isempty(SuggInd)); DefInps(i1) = SuggInd(1); end
end

if ~isempty(varargin)
    StringPart = cellfun(@(x) (ischar(x) || isstring(x)), varargin);

    vararginCp = cellstr(strings(size(varargin))); % It is necessary because you want to find indices only for the string part
    vararginCp(StringPart) = cellfun(@(x) lower(string(x)), varargin(StringPart),  'Uniform',false); % Here same content but low case and nothing if not string!

    InputRnmLbls = find(cellfun(@(x) all(strcmpi(x, "pairlabels")), vararginCp));
    InputSaveOut = find(cellfun(@(x) all(strcmpi(x, "saveout"   )), vararginCp));
    InputSavePth = find(cellfun(@(x) all(strcmpi(x, "savepath"  )), vararginCp));
    InputPosWind = find(cellfun(@(x) all(strcmpi(x, "position"  )), vararginCp));
    InputNameOut = find(cellfun(@(x) all(strcmpi(x, "nameout"   )), vararginCp));
    InputExtndbl = find(cellfun(@(x) all(strcmpi(x, "extendable")), vararginCp));
    InputOutType = find(cellfun(@(x) all(strcmpi(x, "outtype"   )), vararginCp));
    InputDefInps = find(cellfun(@(x) all(strcmpi(x, "definp"    )), vararginCp));
    InputUnqMtch = find(cellfun(@(x) all(strcmpi(x, "unique"    )), vararginCp));
    InputDefLbls = find(cellfun(@(x) all(strcmpi(x, "deflabels" )), vararginCp));

    if InputRnmLbls; RnmLbls = varargin{InputRnmLbls+1  }; end
    if InputSaveOut; SaveOut = varargin{InputSaveOut+1  }; end
    if InputSavePth; SavePth = varargin{InputSavePth+1  }; end
    if InputPosWind; PosWind = varargin{InputPosWind+1  }; end
    if InputNameOut; NameOut = varargin{InputNameOut+1  }; end
    if InputExtndbl; Extndbl = varargin{InputExtndbl+1  }; end
    if InputOutType; OutType = vararginCp{InputOutType+1}; end
    if InputDefInps; DefInps = varargin{InputDefInps+1  }; end
    if InputUnqMtch; UnqMtch = varargin{InputUnqMtch+1  }; end
    if InputDefLbls; DefLbls = varargin{InputDefLbls+1  }; end
end

if RnmLbls && not(any(InputPosWind))
    xOb = 2;
    xWd = xOb*xPn+2*Bff;
    PosWind(3) = xWd;
    PnlSize(1) = xOb*xPn;
end

if Extndbl && (OrNumVals > 1)
    error('You can not use "Extendable" command if you have multiple arrays of values!')
end

if not(isnumeric(DefInps)) || (numel(DefInps) ~= numel(Prompts))
    error(['DefInp variable is not a numeric array or it ' ...
           'does not have the same size of Prompts variable!'])
end

DefLbls = cellstr(DefLbls);
if (numel(DefLbls) ~= numel(Prompts))
    error('DefLbls variable does not have the same size of Prompts variable!')
end

for i1 = 1:numel(DefInps)
    if (DefInps(i1) > numel(Values{i1})) || (DefInps(i1) < 1)
        error(['DefInp index n. ',num2str(i1),' is ', ...
               'out of range (1 - number of Values)!'])
    end
end

%% Initialization
MenuColor = '#F7BA94';
FigSettgs = uifigure('Name','List Window', 'WindowStyle','modal', ...
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

%% Drop down objects
PnlDDPs = [xPn*(xOb-1)+(xPn-DDBtSzs(1))/2, (PnlSize(2)-DDBtSzs(2))/2-0.2*PnlSize(2), DDBtSzs(1), DDBtSzs(2)];
PnlDD   = cell(1, numel(Prompts));
for i1 = 1:numel(Prompts)
    PnlDD{i1} = uidropdown(Panels{i1}, 'Items',Values{i1}, 'Position',PnlDDPs, 'Value',Values{i1}(DefInps(i1)));
end

%% Text area objects
if RnmLbls
    PnlTAPs = [(xPn-DDBtSzs(1))/2, (PnlSize(2)-DDBtSzs(2))/2-0.2*PnlSize(2), DDBtSzs(1), DDBtSzs(2)];
    PnlTA   = cell(1, numel(Prompts));
    for i1 = 1:numel(Prompts)
        PnlTA{i1} = uitextarea(Panels{i1}, 'Value',DefLbls{i1}, 'Position',PnlTAPs);
    end
end

%% Label objects
PnlDDLgPs = [xPn*(xOb-1)+(xPn-DDBtSzs(1))/2, (PnlSize(2)-DDBtSzs(2))/2+0.05*PnlSize(2), DDBtSzs(1), DDBtSzs(2)];
PnlDDLgnd = cell(1, numel(Prompts));
for i1 = 1:numel(Prompts)
    PnlDDLgnd{i1}  = uilabel(Panels{i1}, 'Text','Select:', 'Position',PnlDDLgPs);
end

if RnmLbls
    PnlTALgPs = [(xPn-DDBtSzs(1))/2, (PnlSize(2)-DDBtSzs(2))/2+0.05*PnlSize(2), DDBtSzs(1), DDBtSzs(2)];
    PnlTALgnd = cell(1, numel(Prompts));
    for i1 = 1:numel(Prompts)
        PnlTALgnd{i1} = uilabel(Panels{i1}, 'Text','Write:', 'Position',PnlTALgPs);
    end
end

%% Resize
if FigSettgs.Position(4) > 600
    DiffSz = FigSettgs.Position(4)-600;

    FigSettgs.Position(4) = FigSettgs.Position(4)-DiffSz;
    GenPanl.Position(4)   = GenPanl.Position(4)-DiffSz;
    GenPanl.Scrollable    = 'on';
end

ScreenSize = get(0, 'ScreenSize');
FigSettgs.Position(1:2) = (ScreenSize(3:4) - FigSettgs.Position(3:4)) ./ 2;

%% Callback functions
function confirm
    if strcmp(OutType,'cellstr')
        OutVals = cellfun(@(x) x.Value, PnlDD, 'UniformOutput',false);
    elseif strcmp(OutType,'numind')
        OutVals = cellfun(@(x,y) find(strcmp(x.Value, y), 1), PnlDD, Values);
    else
        error('OutType not recognized!')
    end

    if UnqMtch && (numel(unique(OutVals)) ~= numel(OutVals))
        error('You must select a unique value for each dropdown!')
    end

    if RnmLbls
        OutLbls = cellfun(@(x) x.Value{:}, PnlTA, 'UniformOutput',false);
    else
        OutLbls = cell(size(OutVals));
    end

    if SaveOut
        sl = filesep;
        save([SavePth,sl,NameOut,'.mat'], 'OutVals','OutLbls')
    end
    close(FigSettgs)
    return
end

function add
    OldFigSz = FigSettgs.Position;
    OldGPnSz = GenPanl.Position;
    OldPnlSz = Panels{end}.Position;
    OldDDSz  = PnlDD{end}.Position;
    OldDDLSz = PnlDDLgnd{end}.Position;
    if RnmLbls
        OldTASz  = PnlTA{end}.Position;
        OldTALSz = PnlTALgnd{end}.Position;
    end

    if isscalar(Panels)
        yPnNew = Panels{1}.Position(4) + 30;
    else
        yPnNew = Panels{2}.Position(2) - Panels{1}.Position(2);
    end

    if FigSettgs.Position(4) + yPnNew < 600
        FigSettgs.Position(4) = OldFigSz(4) + yPnNew;
        GenPanl.Position(4)   = OldGPnSz(4) + yPnNew;
    end

    for z1 = 1:numel(Panels)
        Panels{z1}.Position(3:4) = OldPnlSz(3:4);

        PnlDD{z1}.Position       = OldDDSz;
        PnlDDLgnd{z1}.Position   = OldDDLSz;
        if RnmLbls
            PnlTA{z1}.Position     = OldTASz;
            PnlTALgnd{z1}.Position = OldTALSz;
        end
    end

    Values    = [Values, Values(end)];
    NewPnlPs  = [OldPnlSz(1), yPnNew*numel(Panels)+(yPnNew-OldPnlSz(4))/2, OldPnlSz(3), OldPnlSz(4)];
    Panels    = [Panels, {uipanel(GenPanl, 'Title','New Entry', 'FontSize',FntSize, ...
                                           'BackgroundColor',MenuColor, 'Position',NewPnlPs)}];
    PnlDD     = [PnlDD, {uidropdown(Panels{end}, 'Items',Values{end}, 'Position',OldDDSz)}];
    PnlDDLgnd = [PnlDDLgnd, {uilabel(Panels{end}, 'Text','Select:', 'Position',OldDDLSz)}];

    if RnmLbls
        PnlTA     = [PnlTA, {uitextarea(Panels{end}, 'Value','New label', 'Position',OldTASz)}];
        PnlTALgnd = [PnlTALgnd, {uilabel(Panels{end}, 'Text','Write:', 'Position',OldTALSz)}];
    end

    % Scroll enable
    if FigSettgs.Position(4) + yPnNew >= 600
        GenPanl.Scrollable    = 'on';
    end
    return
end

uiwait(FigSettgs)

end