cd(fold_var)
load('MorphologyParameters.mat');
load('SoilParameters.mat');
load('VegetationParameters.mat');
load('GridCoordinates.mat');
load('InfoDetectedSoilSlips.mat');
load('UserC_Answers.mat');

if exist('UserD_Answers.mat')
    load('UserD_Answers.mat')
    if AnswerAttributionVegetationParameter~=0
        load('VegPolygonsStudyArea.mat')
    end
else
    AnswerAttributionVegetationParameter=0;
end

DTMIncludingPoint=[InfoDetectedSoilSlips{:,3}]';
NearestPoint=[InfoDetectedSoilSlips{:,4}]';

xLongStudy=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

yLatStudy=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

ElevationStudy=cellfun(@(x,y) x(y),ElevationAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

SlopeStudy=cellfun(@(x,y) x(y),SlopeAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

AspectStudy=cellfun(@(x,y) x(y),AspectAngleAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

CohesionStudy=cellfun(@(x,y) x(y),CohesionAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

PhiStudy=cellfun(@(x,y) x(y),PhiAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

nStudy=cellfun(@(x,y) x(y),nAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

kStudy=cellfun(@(x,y) x(y),KtAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

AStudy=cellfun(@(x,y) x(y),AAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

nStudy=cellfun(@(x,y) x(y),nAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

betastarStudy=cellfun(@(x,y) x(y),BetaStarAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

RootStudy=cellfun(@(x,y) x(y),RootCohesionAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);



if AnswerAttributionSoilParameter~=0
    load('LithoPolygonsStudyArea.mat')
end


for i1=1:size(DTMIncludingPoint,1)

    InfoDetectedSoilSlips{i1,5}=xLongStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,6}=yLatStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,7}=ElevationStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,8}=SlopeStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,9}=AspectStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));

    if AnswerAttributionSoilParameter==0
        InfoDetectedSoilSlips{i1,10}='Uniform';
    else
        [pp,ee]=arrayfun(@(x) getnan2(x.Vertices),LithoPolygonsStudyArea,'UniformOutput',false);
        LithoPolygon = find(cellfun(@(x,y) inpoly([xLongStudy{DTMIncludingPoint(i1)}(NearestPoint(i1)),...
                            yLatStudy{DTMIncludingPoint(i1)}(NearestPoint(i1))],x,y),pp,ee));
        InfoDetectedSoilSlips{i1,10}=LithoAllUnique{LithoPolygon};
    end

    InfoDetectedSoilSlips{i1,11}=CohesionStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,12}=PhiStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,13}=kStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,14}=AStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,15}=nStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));

    if AnswerAttributionVegetationParameter==0
        InfoDetectedSoilSlips{i1,16}='Uniform';
    else
        [pp_veg,ee_veg]=arrayfun(@(x) getnan2(x.Vertices),VegPolygonsStudyArea,'UniformOutput',false);
        VegPolygon = find(cellfun(@(x,y) inpoly([xLongStudy{DTMIncludingPoint(i1)}(NearestPoint(i1)),...
                    yLatStudy{DTMIncludingPoint(i1)}(NearestPoint(i1))],x,y),pp_veg,ee_veg));

        InfoDetectedSoilSlips{i1,16}=VegetationAllUnique{VegPolygon};
    end

    InfoDetectedSoilSlips{i1,17}=betastarStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));
    InfoDetectedSoilSlips{i1,18}=RootStudy{DTMIncludingPoint(i1)}(NearestPoint(i1));


end

TabParameters=array2table(InfoDetectedSoilSlips);

TabParameters.Properties.VariableNames={'Municipality','Location','N. DTM','Pos Elem','Long (°)','Lat (°)',...
    'Elevation (m)','beta (°)','Aspect (°)', 'Soil type','c''(kPa)','phi (°)','kt(1/h)',...
    'A (kPa)', 'n (-)', 'Vegetation type','beta* (-)','cr (kPa)'};

ColumnName={'Municipality','Location','N. DTM','Pos Elem','Long (°)','Lat (°)',...
    'Elevation (m)','beta (°)','Aspect (°)', 'Soil type','c''(kPa)','phi (°)','kt(1/h)',...
    'A (kPa)', 'n (-)', 'Vegetation type', 'beta* (-)','cr (kPa)'};

fig=figure(1);
tab = uitable('Data',TabParameters{:,:}, 'ColumnName',ColumnName, ...
              'Units','normalized', 'Position',[0.01 0.01 0.99 0.99]);
tab.ColumnName=ColumnName;

save('InfoDetectedSoilSlips.mat','InfoDetectedSoilSlips')