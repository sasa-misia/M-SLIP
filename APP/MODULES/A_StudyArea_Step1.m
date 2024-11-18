if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Processing shapefile of study area', ...
                                 'Message','Reading file', 'Cancelable','on', ...
                                 'Indeterminate','on');
drawnow

%% Initialization
sl = filesep;

StudyAreaPolygonExcluded = polyshape();

if strcmp(FileName_StudyArea, 'None of these') && not(SpecificWindow)
    error(['If there is no shapefile (None of these), ', ...
           'then you must select the Win checkbox!'])
end

%% Options
if SpecificWindow
    ChoiceWindow = 'SingleWindow';
    if exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
        load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet')
        Options = {'SingleWindow', 'MultiWindows'};
        ChoiceWindow = uiconfirm(Fig, ['Would you like to create a single window or ' ...
                                       'multiple windows based on detected soil slip'], ...
                                       'Window type', 'Options',Options);
    end
end
    
%% StudyAreaPolygon and MunPolygon creation
if not(strcmp(FileName_StudyArea, 'None')) % Only if a shapefile is present!
    stArShapePath = [fold_raw_mun,sl,char(FileName_StudyArea)];
    [MunPolygon, MunSel] = ...
                    polyshapes_from_shapefile(stArShapePath, MunFieldName, selFilter=MunSel, ...
                                              pointsLim=500000, progDialog=ProgressBar);
end

if SpecificWindow % Only if SpecificWindow checkbox is active
    ProgressBar.Message = 'Creation of specific window...';

    switch ChoiceWindow
        case 'SingleWindow'
            CoordsWin = inputdlg2({'Lon min [°]:', 'Lon max [°]:', ...
                                       'Lat min [°]:', 'Lat max [°]:'}); 
            CoordsWin = cat(1, cellfun(@eval,CoordsWin));
            PolWindow = polyshape( [CoordsWin(1), CoordsWin(2), ...
                                        CoordsWin(2), CoordsWin(1)], ...
                                   [CoordsWin(3), CoordsWin(3), ...
                                        CoordsWin(4), CoordsWin(4)] );

        case 'MultiWindows'
            xLonDet = [InfoDetectedSoilSlips{IndDefInfoDet}{:,5}];
            yLatDet = [InfoDetectedSoilSlips{IndDefInfoDet}{:,6}];
            WndSide = str2double(inputdlg2('Side of each window [m]', 'DefInp',{'1200'}));
            dLatHlf = rad2deg(WndSide/2/earthRadius); % /2 to have half of the size from the centre

            PolWindow = repmat(polyshape, 1, length(xLonDet));
            for i1 = 1:length(xLonDet)
                dLonHlf = rad2deg(acos( (cos(WndSide/2/earthRadius)-sind(yLatDet(i1))^2)/cosd(yLatDet(i1))^2 )); % /2 to have half of the size from the centre
                PolWindow(i1) = polyshape( [xLonDet(i1)-dLonHlf, xLonDet(i1)+dLonHlf, ...
                                                xLonDet(i1)+dLonHlf, xLonDet(i1)-dLonHlf], ...
                                           [yLatDet(i1)-dLatHlf, yLatDet(i1)-dLatHlf, ...
                                                yLatDet(i1)+dLatHlf, yLatDet(i1)+dLatHlf] );
            end
    end

    if exist('MunPolygon', 'var')
        for i1 = 1:length(MunPolygon)
            MunPolygon(i1) = intersect(union(PolWindow), MunPolygon(i1));
        end
    else
        MunSel = cellstr(strcat("Poly ",string(1:numel(PolWindow))));
        MunPolygon = PolWindow;
    end
end

%% Union of Polygons
ProgressBar.Message = 'Union of polygons...';

StudyAreaPolygon = union(MunPolygon);
StudyAreaPolygonClean = StudyAreaPolygon;

%% Limit of study area
MaxExtremes = max(StudyAreaPolygon.Vertices);
MinExtremes = min(StudyAreaPolygon.Vertices);

%% Saving..
ProgressBar.Message = 'Finising...';

VarsStudyArea = {'MunPolygon', 'StudyAreaPolygon', 'StudyAreaPolygonClean', ...
                      'StudyAreaPolygonExcluded', 'MaxExtremes', 'MinExtremes'};
if SpecificWindow; VarsStudyArea = [VarsStudyArea, {'PolWindow'}]; end
VarsUserStudy = {'FileName_StudyArea', 'MunFieldName', 'MunSel', 'SpecificWindow'};

save([fold_var,sl,'StudyAreaVariables.mat'   ], VarsStudyArea{:});
save([fold_var,sl,'UserStudyArea_Answers.mat'], VarsUserStudy{:});

close(ProgressBar) % Fig instead of ProgressBar if in Standalone version