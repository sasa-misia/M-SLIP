%% Loading of variables previously created
cd(fold_var)
load('GridCoordinates.mat');
load('VegetationParameters.mat');
load('VegPolygonsStudyArea.mat');

%% Excel reading and coefficient matrix writing
% Fig = uifigure; % Remember to comment if in app version
cd(fold_user)
Sheet_DVCPar = readcell(FileName_VegAssociation,'Sheet','DVCParameters');
Sheet_Ass = readcell(FileName_VegAssociation,'Sheet','Association');

VU2DVC = Sheet_Ass(2:size(Sheet_Ass,1),2);
SelectedVeg = find(cellfun(@ismissing,VU2DVC)==0);

if isempty(SelectedVeg); error('V 1'); end

VUAbbr = string(Sheet_Ass(SelectedVeg+1,3)); % Plus 1 because of headers

Options = {'Yes', 'No, yet assigned in excel'};
ChoiceVU = questdlg('Would you like to choose VU color?','Color of VU', ...
                                        Options{1},Options{2},Options{2});
ChoiceDVC = questdlg('Would you like to choose DVC color?','Color of DVC', ...
                                        Options{1},Options{2},Options{2});
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
        DVCColors = uint8(rand(size(Sheet_DVCPar,1),3).*255);
    end

elseif string(ChoiceDVC) == string(Options{1})

    for i1 = 1:size(Sheet_DVCPar,1)
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
tic
for i1 = 1:size(SelectedVUByUserPolygons,2)   
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
toc

VegAttribution = true;

VU_DVC = {VegAcronyms, DVC};
VU_DVCPlotColors = {VUColors, DVCColors};
DVCParameters = {DVC_cr, DVC_betastar};

VariablesAnswerD = {'VegAttribution'};
VariablesVUPar = {'VU_DVCPlotColors', 'VU_DVC', 'VUAbbr', 'DVCParameters', 'SelectedVeg'};
VariablesVegPar = {'RootCohesionAll', 'BetaStarAll'};

%% Saving..
cd(fold_var)
save('UserD_Answers.mat', VariablesAnswerD{:}, '-append');
save('VUDVCMapParameters.mat', VariablesVUPar{:})
save('VegetationParameters.mat', VariablesVegPar{:});
cd(fold0)