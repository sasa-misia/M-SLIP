cd(fold_var)
load('InfoDetectedSoilSlips.mat');
load('GeneralRainfall.mat','RainfallDates');

if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont='Times New Roman';
    SelectedFontSize=8;
    SelectedLocation='Best';
end

%%

Municipalities={InfoDetectedSoilSlips{:,1}};
Locations={InfoDetectedSoilSlips{:,2}};


DTMIncludingPoint=[InfoDetectedSoilSlips{:,3}]';
NearestPoint=[InfoDetectedSoilSlips{:,4}]';


cd(fold_res_fs)

foldFS=uigetdir('open');
[~,namefoldFS] = fileparts(foldFS);

cd(foldFS)
load('AnalysisInformation.mat');

ExtremeDates=StabilityAnalysis{3};
DateRain=RainfallDates(ExtremeDates(1):ExtremeDates(2));
NumberAnalysis=StabilityAnalysis{1};
DateAnalysis=StabilityAnalysis{2};

for i1=1:length(DateAnalysis)
    IndRainAnalysis(i1)=find(DateRain==DateAnalysis(i1));
end

if ~exist('PunctualData.mat') 

    for i3=1:NumberAnalysis
        load(strcat('Fs',num2str(i3)));
        Fs(i3,:)=FactorSafety;
    end


    cd(fold_var)

    %mettere ui loading
    load('RainInterpolated.mat');

    %full serve per trasformare sparse in matrice normale. Altrimenti cellfun
    %non va. Dice di usare spfun ma non va nemmeno
    
    for i1=1:size(DTMIncludingPoint,1)
       Rain{i1}=cellfun(@(x) full(x(NearestPoint(i1),1)),...
            RainInterpolated(:,DTMIncludingPoint(i1)),'UniformOutput',false);

        FsAll(:,i1)=cellfun(@(x) x(NearestPoint(i1),1),...
            Fs(:,DTMIncludingPoint(i1)),'UniformOutput',false);
    end

    cd(foldFS)

    save('PunctualData.mat','Rain','FsAll')
else
    load('PunctualData.mat')
end


%Selection Location to plot
MunUnique=unique(Municipalities);

for i2=1:size(MunUnique,2)
    IndMun{i2}=cellfun(@(x) strcmp(x,MunUnique{i2}),Municipalities);
end

MunUnique=string(MunUnique);

choice1=listdlg('PromptString',...
    {'Select Municipality:',''},'ListString',MunUnique);

SelectedMun=MunUnique(choice1);

Locations=string(Locations);
choice2=listdlg('PromptString',...
    {'Select Location:',''},'ListString',Locations(IndMun{choice1}));

SelectedLoc=Locations(choice2);

%Forse meglio mettere doppio strcmp ma non mi funziona
Ind=cellfun(@(x) strcmp(x,SelectedLoc),...
    InfoDetectedSoilSlips(:,2),'UniformOutput',false);

Ind=cell2mat(Ind);

Fs2Plot=[FsAll{:,Ind}];

IndFsUnstab=Fs2Plot<1;

%%
filename1=strcat("FS ",SelectedLoc);
f1=figure(1);
set(f1 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits', 'centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition', [0 1 12 4],...
    'InvertHardcopy','off');
set( gcf ,'Name' , filename1);

yyaxis left
line(DateAnalysis,Fs2Plot,'Marker','^','MarkerSize',2,...
    'Color','k')
hold on
plot([DateAnalysis(1) DateAnalysis(end)],[1 1],'--r','LineWidth',0.5);
hold on
scatter(DateAnalysis(IndFsUnstab),Fs2Plot(IndFsUnstab),'or')
hold on

ylabel('{\it F_s}','FontName',SelectedFont)

set(gca,...
'XLim'        , [min(DateAnalysis) max(DateAnalysis)]    , ...
    'YLim'        , [0.5 max(Fs2Plot)]    , ...
    'Box'         , 'on'      , ...
    'TickDir'     , 'in'     , ...
    'TickLength'  , [.01 .01] , ...
    'XMinorTick'  , 'on'      , ...
    'YMinorTick'  , 'on'      , ...
    'XGrid'       , 'off'     , ...
    'YGrid'       , 'off'     , ...
    'XColor'      , [0 0 0]   , ...
    'YColor'      , [0 0 0]   , ...
    'XTick',DateAnalysis(1):hours(6):DateAnalysis(end),...
    'YTick'       , 0:0.2:max(Fs2Plot)    , 'FontSize',10, 'FontName',SelectedFont,...
    'LineWidth'   , .5,...
    'SortMethod', 'depth')



yyaxis right
bar(DateRain,cell2mat(Rain{Ind}),'FaceColor',[0 127 255]./255);
%title(strcat(SelectedLoc,'(',SelectedMun,')'));
ylabel('{\it h_w} [mm]','FontName',SelectedFont)

set(gca,...
'XLim'        , [min(DateAnalysis) max(DateAnalysis)]    , ...
    'YLim'        , [0 max(cell2mat(Rain{Ind}(IndRainAnalysis)))+2]    , ...
    'Box'         , 'on'      , ...
    'TickDir'     , 'in'     , ...
    'TickLength'  , [.01 .01] , ...
    'XMinorTick'  , 'off'      , ...
    'YMinorTick'  , 'off'      , ...
    'XGrid'       , 'off'     , ...
    'YGrid'       , 'off'     , ...
    'XColor'      , [0 0 0]   , ...
    'YColor'      , [0 127 255]./255   , ...
    'XTick',DateAnalysis(1):hours(6):DateAnalysis(end),...
    'YTick'       , 0:1:max(cell2mat(Rain{Ind}(IndRainAnalysis)))+2   , 'FontSize',10, 'FontName',SelectedFont,...
    'LineWidth'   , .5        )



exportgraphics(f1,strcat(filename1,'.png'),'Resolution',600);






