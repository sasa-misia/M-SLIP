cd(fold_var)
load('InfoDetectedSoilSlips.mat');
load('GridCoordinates.mat');

if exist('LegendSettings.mat')
    load('LegendSettings.mat')
else
    SelectedFont='Times New Roman';
    SelectedFontSize=8;
    SelectedLocation='Best';
end

%%
xLongStudy=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea,...
    'UniformOutput',false);

yLatStudy=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea,...
    'UniformOutput',false);

%%

cd(fold_res_fs)

foldFS=uigetdir('open');
[~,namefoldFS] = fileparts(foldFS);

cd(foldFS)
load('AnalysisInformation.mat');

EventsAnalysed=string(StabilityAnalysis{:,2});
choice1=listdlg('PromptString',...
    {'Select event analysed to plot:',''},'ListString',EventsAnalysed);
Event_FS=EventsAnalysed(choice1);

Event_FS=datetime(Event_FS,'InputFormat','dd/MM/yyyy HH:mm:ss');
FS_index=hours(Event_FS-StabilityAnalysis{2}(1))+1;

Event_FS1=datetime(Event_FS,'Format','dd-MM-yyyy HH-mm');

load(strcat('Fs',num2str(FS_index),'.mat'));
Fs=FactorSafety;

Fs_Treshold=1:.5:10;

dX=km2deg(0.04);

BoundSoilSlip=[cellfun(@(x) x-dX,InfoDetectedSoilSlips(:,5:6))...
    cellfun(@(x) x+dX,InfoDetectedSoilSlips(:,5:6))];

PolSoilSlip=arrayfun(@(x1,x2,y1,y2) polyshape([x1 x2 x2 x1],[y1 y1 y2 y2]),...
    BoundSoilSlip(:,1),BoundSoilSlip(:,3),BoundSoilSlip(:,2),BoundSoilSlip(:,4));

for i1=1:length(Fs_Treshold)
    Fs_less_index=cellfun(@(x) x<=Fs_Treshold(i1) & x>0,Fs,'UniformOutput',false);
    Fs_more_index=cellfun(@(x) x>Fs_Treshold(i1),Fs,'UniformOutput',false);

    Fs_less_indexNotEmpty=cellfun(@any,Fs_less_index); %Delete empty array
    Fs_more_indexNotEmpty=cellfun(@any,Fs_more_index); 

    Fs_less_index=Fs_less_index(Fs_less_indexNotEmpty);
    Fs_more_index=Fs_more_index(Fs_more_indexNotEmpty);


    Fs_less_index_good=cellfun(@(x) x(x),Fs_less_index,...
        'UniformOutput',false);
    Fs_more_index_good=cellfun(@(x) x(x),Fs_more_index,...
        'UniformOutput',false);



%     NumTN=cellfun(@(x) nnz(~x),Fs_more_index);
%     NumFP=cellfun(@nnz,Fs_less_index);

    
    xLongStudyUnstable=cellfun(@(x,y) x(y),...
        xLongStudy(Fs_less_indexNotEmpty),Fs_less_index,...
        'UniformOutput',false);
    
    yLatStudyUnstable=cellfun(@(x,y) x(y),...
        yLatStudy(Fs_less_indexNotEmpty),Fs_less_index,...
        'UniformOutput',false);
    
    xLongStudyStable=cellfun(@(x,y) x(y),...
        xLongStudy(Fs_more_indexNotEmpty),Fs_more_index,...
        'UniformOutput',false);
    
    yLatStudyStable=cellfun(@(x,y) x(y),...
        yLatStudy(Fs_more_indexNotEmpty),Fs_more_index,...
        'UniformOutput',false);

    

    NumFN=0;
    NumTP=0;

    for i2=1:length(PolSoilSlip)
        [pp,ee]=getnan2(PolSoilSlip(i2).Vertices);
        PositiveInsidePolygon=cellfun(@(x,y) find(inpoly([x,y],pp,ee)),...
            xLongStudyUnstable(cellfun(@(x) ~isempty(x),xLongStudyUnstable)),yLatStudyUnstable(cellfun(@(x) ~isempty(x),xLongStudyUnstable)),...
            'UniformOutput',false);

             
        NegativeInsidePolygon=cellfun(@(x,y) find(inpoly([x,y],pp,ee)),xLongStudyStable,yLatStudyStable,...
            'UniformOutput',false);

        DTMPositiveInsidePolygon=find(cellfun(@(x) ~isempty(x),PositiveInsidePolygon));
        DTMNegativeInsidePolygon=find(cellfun(@(x) ~isempty(x),NegativeInsidePolygon));


        if isempty(DTMPositiveInsidePolygon)
            NumFN=NumFN+1;
            for i3=1:length(DTMNegativeInsidePolygon)
                Fs_more_index_good{DTMNegativeInsidePolygon(i3)}(NegativeInsidePolygon{DTMNegativeInsidePolygon(i3)})=false;
            end
        else
            NumTP=NumTP+1;
            for i3=1:length(DTMPositiveInsidePolygon)
                Fs_less_index_good{DTMPositiveInsidePolygon(i3)}(PositiveInsidePolygon{DTMPositiveInsidePolygon(i3)})=false;
            end
        end


        if ~isempty(DTMNegativeInsidePolygon)
            for i3=1:length(DTMNegativeInsidePolygon)
                Fs_more_index_good{DTMNegativeInsidePolygon(i3)}(NegativeInsidePolygon{DTMNegativeInsidePolygon(i3)})=false;
            end
        end
          

    end

    %NumTN=cellfun(@(x) nnz(~x),Fs_more_index); % Potrebbe essere questa ~
    NumTN=sum(cellfun(@(x) nnz(x),Fs_more_index_good)); 
    NumFP=sum(cellfun(@nnz,Fs_less_index_good)); % Questo è ok

    TNR(i1)=NumTN/(NumFP+NumTN);
    TPR(i1)=NumTP/(NumTP+NumFN);

end



TNR=[1 TNR 0];
TPR=[0 TPR 1];

AUC=abs(trapz(TNR,TPR))

%%

f1=figure(1);
set(f1 , ...
    'Color',[1 1 1],...
    'PaperType','a4',...
    'PaperSize',[29.68 20.98 ],...    
    'PaperUnits', 'centimeters',...
    'PaperPositionMode','manual',...
    'PaperPosition', [0 1 12 6],...
    'InvertHardcopy','off');
%set( gcf ,'Name' , filename1);

axes1 = axes('Parent',f1); 
hold(axes1,'on');

plot(TNR,TPR)
hold on
plot([1 0],[0 1])

xlim([0 1])
ylim([0 1])
xlabel('TNR','FontName',SelectedFont)
ylabel('TPR','FontName',SelectedFont)


