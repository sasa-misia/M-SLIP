%% Loading of variables previously created
cd(fold_var)
load('GridCoordinates.mat');
load('SoilParameters.mat');
load('LithoPolygonsStudyArea.mat');
load('UserA_Answers.mat','SpecificWindow')

%% Excel reading and coefficient matrix writing
cd(fold_user)
Sheet_DSCPar=readcell(FileName_LithoAssociation,'Sheet','DSCParameters');
Sheet_Ass=readcell(FileName_LithoAssociation,'Sheet','Association');

LU2DSC=Sheet_Ass(2:size(Sheet_Ass,1),2);
SelectedSoil=find(cellfun(@ismissing,LU2DSC)==0);

if isempty(SelectedSoil); error('L 1'); end

LUAbbr=string(Sheet_Ass(SelectedSoil+1,3)); %Plus 1 because of headers

LUColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
                        Sheet_Ass(SelectedSoil+1,4),'UniformOutput',false));  
DSCColors = cell2mat(cellfun(@(x) sscanf(x,'%d',[1 3]), ...
             Sheet_DSCPar(2:size(Sheet_DSCPar,1),7),'UniformOutput',false));

% Correspondence LU->DSC
sigle_lit=LUAbbr(:,1);
us_lit=LU2DSC(SelectedSoil,1);

% Soil parameter for the single-point assignment procedure
c_us=cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),2});
phi_us=cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),3});
kt_us=cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),4});
A_us=cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),5});
n_us=cat(1,Sheet_DSCPar{2:size(Sheet_DSCPar,1),6});

% Lithology not associated
SelectedLUByUserPolygons=LithoPolygonsStudyArea(SelectedSoil);

%% InPolygon Procedure
tic
for i1=1:size(SelectedLUByUserPolygons,2)   
    LUPolygon=SelectedLUByUserPolygons(i1);


    [pp,ee]=getnan2([LUPolygon.Vertices; nan nan]); 
    for i2=1:size(xLongAll,2)  
        if ~isempty(IndexDTMPointsInsideStudyArea{i2})       
            IndexInsideLithoPolygon=find(inpoly([xLongAll{i2}(IndexDTMPointsInsideStudyArea{i2}),...
                            yLatAll{i2}(IndexDTMPointsInsideStudyArea{i2})],pp,ee)==1);
            CohesionAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon))=c_us(LU2DSC{SelectedSoil(i1),1});
            PhiAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon))=phi_us(LU2DSC{SelectedSoil(i1),1});
            KtAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon))=kt_us(LU2DSC{SelectedSoil(i1),1});
            AAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon))=A_us(LU2DSC{SelectedSoil(i1),1});
            nAll{i2}(IndexDTMPointsInsideStudyArea{i2}(IndexInsideLithoPolygon))=n_us(LU2DSC{SelectedSoil(i1),1});
        end
    end
    disp(strcat('Finished LU',num2str(i1),'of ',num2str(size(SelectedSoil,1))))
end
toc

lu_dsc={sigle_lit us_lit};
lu_dsc_color_plot={LUColors DSCColors};
dsc_parameters={n_us phi_us c_us A_us kt_us};

%% Saving..
cd(fold_var)
save('LUDSCMapParameters.mat','lu_dsc_color_plot','LUAbbr','dsc_parameters','SelectedSoil','LU2DSC')
save('SoilParameters.mat','CohesionAll','PhiAll','KtAll','AAll','nAll');
cd(fold0)