% Fig = uifigure; % Remember to comment if in app version
ProgressBar = uiprogressdlg(Fig, 'Title','Attribution of vegetation parameters', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Loading of variables previously created
cd(fold_var)
load('GridCoordinates.mat');
load('VegetationParameters.mat');
load('VegPolygonsStudyArea.mat');

%% Excel reading and coefficient matrix writing
ProgressBar.Message = 'Reading excel...';

cd(fold_user)
Sheet_DVCPar = readcell(FileName_VegAssociation,'Sheet','DVCParameters');
Sheet_Ass = readcell(FileName_VegAssociation,'Sheet','Association');

VU2DVC = Sheet_Ass(2:size(Sheet_Ass,1),2);
SelectedVeg = find(cellfun(@ismissing,VU2DVC)==0);

if isempty(SelectedVeg); error('V 1'); end

VUAbbr = string(Sheet_Ass(SelectedVeg+1,3)); % Plus 1 because of headers

Options = {'Yes', 'No, yet assigned in excel'};
ChoiceVU = uiconfirm(Fig, 'Would you like to choose VU color?', ...
                          'Window type', 'Options',Options);
ChoiceDVC = uiconfirm(Fig, 'Would you like to choose DVC color?', ...
                           'Window type', 'Options',Options);

if string(ChoiceVU) == string(Options{2})

    try
        VUColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
                                Sheet_Ass(SelectedVeg+1,4), 'UniformOutput',false));
    catch me
        getReport(me)
        uialert(Fig, ['An error occurred reading colors (see MATLAB command), ' ...
                      'VU Colors will be randomly generated...'], ...
                      'VU Color Error')
        VUColors = uint8(rand(size(SelectedVeg,1),3).*255);
    end

elseif string(ChoiceVU) == string(Options{1})

    for i1 = 1:size(SelectedVeg,1)
        VUColors(i1,:) = uisetcolor(strcat("Chose a color for ",VUAbbr(i1))).*255;
    end

end

if string(ChoiceDVC) == string(Options{2})

    try
        DVCColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
                 Sheet_DVCPar(2:size(Sheet_DVCPar,1),4), 'UniformOutput',false));
    catch me
        getReport(me)
        uialert(Fig, ['An error occurred reading colors (see MATLAB command), ' ...
                      'DVC Colors will be randomly generated...'], ...
                      'DVC Color Error')
        DVCColors = uint8(rand(size(Sheet_DVCPar,1)-1, 3).*255);
    end

elseif string(ChoiceDVC) == string(Options{1})

    for i1 = 1:(size(Sheet_DVCPar,1)-1)
        DVCColors(i1,:) = uisetcolor(strcat("Chose a color for UV ",num2str(i1))).*255;
    end

end

% Correspondence VU->DVC
VegAcronyms = VUAbbr(:,1);
DVC = VU2DVC(SelectedVeg,1);

% Vegetation parameter for the single-point assignment procedure
DVC_cr = [Sheet_DVCPar{2:size(Sheet_DVCPar,1),2}]';
DVC_betastar = [Sheet_DVCPar{2:size(Sheet_DVCPar,1),3}]';

% Vegetation non associated
SelectedVUByUserPolygons = VegPolygonsStudyArea(SelectedVeg);

%% InPolygon Procedure
cd(fold_var)
MantainVegOfSS = 'No';
if exist('InfoDetectedSoilSlips.mat', 'file')
    Options = {'Yes', 'No', 'Average'};
    MantainVegOfSS = uiconfirm(Fig, 'Do you want to mantain soil slip points with no vegetation?', ...
                               'Window type', 'Options',Options);
    if strcmp(MantainVegOfSS, 'Yes') || strcmp(MantainVegOfSS, 'Average')
        load('InfoDetectedSoilSlips.mat')
        DTMi = InfoDetectedSoilSlips(:,3);
        Indexi = InfoDetectedSoilSlips(:,4);
        IndexAlli = cellfun(@(x,y) IndexDTMPointsInsideStudyArea{x}(y), DTMi, Indexi, 'UniformOutput',false);
        RootCohesionToMantain = cellfun(@(x,y) RootCohesionAll{x}(y), DTMi, IndexAlli);
        BetaStarToMantain = cellfun(@(x,y) BetaStarAll{x}(y), DTMi, IndexAlli);
    end
end

tic
ProgressBar.Indeterminate = 'off';
for i1 = 1:size(SelectedVUByUserPolygons,2)
    ProgressBar.Message = strcat("Attributing parameters of VU n. ",num2str(i1)," of ", num2str(size(SelectedVUByUserPolygons,2)));
    ProgressBar.Value = i1/size(SelectedVUByUserPolygons,2);

    VUPolygon = SelectedVUByUserPolygons(i1);
    [pp,ee] = getnan2([VUPolygon.Vertices;nan nan]); % Conversion NaN-delimited polygon format to node-edge topological layout required by inpoly2
    for i2 = 1:size(xLongAll,2)    

        IndexGridPointInsideVegPolygon = find(inpoly([xLongAll{i2}(IndexDTMPointsInsideStudyArea{i2}),...
                    yLatAll{i2}(IndexDTMPointsInsideStudyArea{i2})],pp,ee)==1);
        
        RootCohesionAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexGridPointInsideVegPolygon)) = ...
                                            DVC_cr(VU2DVC{SelectedVeg(i1),1});
        if DVC_betastar(VU2DVC{SelectedVeg(i1),1})~=0
            BetaStarAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexGridPointInsideVegPolygon)) = ...
                                            DVC_betastar(VU2DVC{SelectedVeg(i1),1});
        end
    end
    disp(strcat('Finished VU',num2str(i1),'of ',num2str(size(SelectedVUByUserPolygons,2))))
end

if strcmp(MantainVegOfSS, 'Yes') || strcmp(MantainVegOfSS, 'Average')
    for i1 = 1:length(BetaStarToMantain)
        if strcmp(MantainVegOfSS, 'Average')
            RootCohesionAll{DTMi{i1}}(IndexAlli{i1}) = (RootCohesionToMantain(i1)+RootCohesionAll{DTMi{i1}}(IndexAlli{i1}))/2;
            BetaStarAll{DTMi{i1}}(IndexAlli{i1}) = (BetaStarToMantain(i1)+BetaStarAll{DTMi{i1}}(IndexAlli{i1}))/2;
        else
            RootCohesionAll{DTMi{i1}}(IndexAlli{i1}) = RootCohesionToMantain(i1);
            BetaStarAll{DTMi{i1}}(IndexAlli{i1}) = BetaStarToMantain(i1);
        end
    end
end
toc

VegAttribution = true;

VU_DVC = {VegAcronyms, DVC};
VU_DVCPlotColors = {VUColors, DVCColors};
DVCParameters = {DVC_cr, DVC_betastar};

VariablesAnswerD = {'VegAttribution'};
VariablesVUPar = {'VU_DVCPlotColors', 'VU_DVC', 'VUAbbr', 'DVCParameters', 'SelectedVeg', 'VU2DVC'};
VariablesVegPar = {'RootCohesionAll', 'BetaStarAll'};

ProgressBar.Indeterminate = 'on';
ProgressBar.Message = 'Finising...';

%% Saving..
cd(fold_var)
save('UserD_Answers.mat', VariablesAnswerD{:}, '-append');
save('VUDVCMapParameters.mat', VariablesVUPar{:})
save('VegetationParameters.mat', VariablesVegPar{:});
cd(fold0)

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version