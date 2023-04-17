cd(fold_var)
load('GridCoordinates.mat')
load('MorphologyParameters.mat');
load('SoilParameters.mat');
load('VegetationParameters.mat');
load('StudyAreaVariables.mat');

if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont='Times New Roman';
    SelectedFontSize=8;
    SelectedLocation='Best';
end

%%
Gs=2.7;
Lambda=0.4;
GammaW=10;
Alpha=3.4;

%%
xLongStudy=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

yLatStudy=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

Slope=cellfun(@(x,y) x(y),SlopeAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

Cohesion=cellfun(@(x,y) x(y),CohesionAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

Phi=cellfun(@(x,y) x(y),PhiAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

n=cellfun(@(x,y) x(y),nAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

A=cellfun(@(x,y) x(y),AAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

RootCohesion=cellfun(@(x,y) x(y),RootCohesionAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

%%
choice=inputdlg({'Enter initial Sr:' ...
                 'Thickness of the topsoil (m):'},'Set',1,...
                {'','1.2'});
Sr0=str2double(choice{1}); % New discretisation in meters
H=str2double(choice{2}); % New discretisation in meters

Gamma=cellfun(@(x) Gs*(1-x)*GammaW+Sr0*x*GammaW,n,'UniformOutput',false);
DmCum=cellfun(@(a,b,c,d,e,f) 1-((((1-tand(a)./tand(b)).*c.*H.*cosd(b).*sind(b))-(d+e))./(f*Sr0*(1-Sr0)^Lambda)).^(1./Alpha),...
                Phi,Slope,Gamma,Cohesion,RootCohesion,A,'UniformOutput',false);

DmCumIndex=cellfun(@(x) imag(x)==0,DmCum,'UniformOutput',false);

DmCumReduced=cellfun(@(x,y) x(y),DmCum,DmCumIndex,'UniformOutput',false);

xLongStudyReduced=cellfun(@(x,y) x(y),xLongStudy,DmCumIndex,'UniformOutput',false);

yLatStudyReduced=cellfun(@(x,y) x(y),yLatStudy,DmCumIndex,'UniformOutput',false);

mRange=[0 0.3 0.45 0.75 1];
DmCumHigh=cellfun(@(x) x>=mRange(1) & x<mRange(2),DmCumReduced,'UniformOutput',false);

DmCumMediumHigh=cellfun(@(x) x>=mRange(2) & x<mRange(3),DmCumReduced,'UniformOutput',false);
DmCumMedium=cellfun(@(x) x>=mRange(3) & x<mRange(4),DmCumReduced,'UniformOutput',false);
DmCumLow=cellfun(@(x) x>=mRange(4) & x<=mRange(5),DmCumReduced,'UniformOutput',false);

NumHigh=cellfun(@(x) numel(find(x)),DmCumHigh);
NumMediumHigh=cellfun(@(x) numel(find(x)),DmCumMediumHigh);
NumMedium=cellfun(@(x) numel(find(x)),DmCumMedium);
NumLow=cellfun(@(x) numel(find(x)),DmCumLow);

%%
filename1=strcat("Susceptibility Sr0=",num2str(Sr0));
f1=figure(1);
set(f1 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits', 'centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition', [0 1 12 6],...
    'InvertHardcopy','off');
set(gcf, 'Name' ,filename1);

axes1 = axes('Parent',f1);
hold(axes1,'on')
hLow=cellfun(@(x,y,z) scatter(x(z),y(z),2,'Marker','s',...
    'MarkerFaceColor',[229 190 1]./255,'MarkerEdgeColor','none'),...
    xLongStudyReduced,yLatStudyReduced,DmCumLow,'UniformOutput',false);

hMedium=cellfun(@(x,y,z) scatter(x(z),y(z),1.5,'Marker','s',...
    'MarkerFaceColor',[255 117 20]./255,'MarkerEdgeColor','none'),...
    xLongStudyReduced,yLatStudyReduced,DmCumMedium,'UniformOutput',false);

hMediumHigh=cellfun(@(x,y,z) scatter(x(z),y(z),1.5,'Marker','s',...
    'MarkerFaceColor',[255 0 0]./255,'MarkerEdgeColor','none'),...
    xLongStudyReduced,yLatStudyReduced,DmCumMediumHigh,'UniformOutput',false);

hHigh=cellfun(@(x,y,z) scatter(x(z),y(z),1.5,'Marker','s',...
    'MarkerFaceColor',[128 0 0]./255,'MarkerEdgeColor','none'),...
    xLongStudyReduced,yLatStudyReduced,DmCumHigh,'UniformOutput',false);

legendCaption=arrayfun(@(x,y) strcat(num2str(x)," - ",num2str(y)),mRange(1:end-1),mRange(2:end), ...
                                     'UniformOutput',false);

hLowGood=find(~cellfun(@isempty,hLow));
hMediumGood=find(~cellfun(@isempty,hMedium));
hMediumHighGood=find(~cellfun(@isempty,hMediumHigh));
hHighGood=find(~cellfun(@isempty,hHigh));

IndLeg=[all(~cellfun(@isempty,hHigh)) all(~cellfun(@isempty,hMediumHigh)) ...
    all(~cellfun(@isempty,hMedium)) all(~cellfun(@isempty,hLow))];

legendCaption=legendCaption(IndLeg);

allPlot={hHigh,hMediumHigh,hMedium,hLow};
allPlotGood={hHighGood,hMediumHighGood,hMediumGood,hLowGood};

allPlot=allPlot(IndLeg);
allPlotGood=allPlotGood(IndLeg);

allPlot2Plot=cellfun(@(x,y) x(y(1)),allPlot,allPlotGood);

hleg=legend([allPlot2Plot{:}],...
legendCaption{:}, ...
            'Location',SelectedLocation, ...
            'FontName',SelectedFont, ...
            'FontSize',SelectedFontSize);
legend('AutoUpdate','off');
legend boxoff

hleg.Title.String={'{\it m_{cr}}'};

hold on
plot(StudyAreaPolygon,'FaceColor','none','LineWidth',1)

xlim([MinExtremes(1),MaxExtremes(1)])
ylim([MinExtremes(2)-0.0005,MaxExtremes(2)+0.0005])

%%
save('SusceptibilityRes.mat','DmCum')

cd(fold_fig)
exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);
cd(fold0)

% for i2=9:size(xLongAll,2)
% 
% tic
%     Ci=(Cohesion{i2}+RootCohesion{i2})+A{i2}.*Sr0.*(1-Sr0).^Lambda.*(1-DmCum).^Alpha;
%     Wi_primo=cosd(Slope{i2}).*H.*GammaW.*(DmCum.*(n{i2}-1)+Gs.*(1-n{i2})+Sr0.*n{i2}.*(1-DmCum));
%     Wi=cosd(Slope{i2}).*H.*GammaW.*(DmCum.*n{i2}+Gs.*(1-n{i2})+Sr0.*n{i2}.*(1-DmCum));
%     FactorSafety=(Wi_primo.*cosd(Slope{i2}).*tand(Phi{i2})+Ci)./(Wi.*sind(Slope{i2}));
%     eqn=FactorSafety==1;
%     for i3=1:length(eqn)
%         Dm_eval{i3,i2}=vpasolve(eqn(i3),DmCum,[0 1]);
%         strcat('Fatto',num2str(i3),'di',num2str(length(eqn)))
%     end
% 
% 
%     toc
% end
% 
% 
% 
% tic
% Ci=cellfun(@(x,y,z) (x+y)+z*Sr0*(1-Sr0)^lambda*(1-Dm_cum)^alfa,...
% CohesionStudy,RootStudy,AStudy,'UniformOutput',false);
% 
% Wi_primo=cellfun(@(x,y) cosd(x)*H*gammaw.*(Dm_cum.*(y-1)+Gs*(1-y)+Sr0*y.*(1-Dm_cum)),...
%     SlopeStudy,nStudy,'UniformOutput',false);
% 
% Wi=cellfun(@(x,y) cosd(x)*H*gammaw.*(Dm_cum.*y+Gs*(1-y)+Sr0*y.*(1-Dm_cum)),...
%      SlopeStudy,nStudy,'UniformOutput',false);
% 
% SafetyFactor=cellfun(@(a,b,c,d,e) (a.*cosd(b).*tand(c)+d)./(e.*sind(b)),...
%     Wi_primo,SlopeStudy,PhiStudy,Ci,Wi,'UniformOutput',false);
% toc
% 
% tic
% eqn=cellfun(@(x) x==1,SafetyFactor,'UniformOutput',false);
% toc
% 
% tic
% eqn=cellfun(@sym2cell,eqn,'UniformOutput',false);
% toc
% 
% 
% eqn(1:8)=[];
% % Dm_eval=arrayfun(@(x) solve(x,Dm_cum),cellfun(@(y) cell2sym(y),eqn(1:2),'UniformOutput',false),...
% %     'UniformOutput',false);
% 
% tic
% for i1=1:length(eqn)
%     eqn1=eqn{i1};
%     Dm_eval{i1}=cellfun(@(x) double(vpasolve(x,Dm_cum,[0 1])),eqn1,'UniformOutput',false);
%     disp(strcat('Fatto',num2str(i1)))
% end
% toc
% 
% 
% %Dm_eval=cellfun(@(x) cellfun(@(y) solve(y,Dm_cum),x),eqn,'UniformOutput',false);
% %Dm_eval=cellfun(@(x) solve(x,Dm_cum),eqn(10),'UniformOutput',false);