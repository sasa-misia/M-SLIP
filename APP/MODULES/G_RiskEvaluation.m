load('GridCoordinates.mat');
load('Distances.mat');
load('SusceptibilityRes.mat');

xLongStudy=cellfun(@(x,y) x(y),xLongAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

yLatStudy=cellfun(@(x,y) x(y),yLatAll,IndexDTMPointsInsideStudyArea,...
        'UniformOutput',false);

DmCumIndex=cellfun(@(x) imag(x)==0,DmCum,'UniformOutput',false);

DmCumReduced=cellfun(@(x,y) x(y),DmCum,DmCumIndex,...
        'UniformOutput',false);

MinDistanceLUReduced=cellfun(@(x,y) x(y),MinDistanceLU,DmCumIndex,...
        'UniformOutput',false);


xLongStudyReduced=cellfun(@(x,y) x(y),xLongStudy,DmCumIndex,...
        'UniformOutput',false);

yLatStudyReduced=cellfun(@(x,y) x(y),yLatStudy,DmCumIndex,...
        'UniformOutput',false);

mRange=[0 0.3 0.45 0.75 1];

DmCumHigh=cellfun(@(x) x>=mRange(1) & x<mRange(2),DmCumReduced,'UniformOutput',false);
DmCumMediumHigh=cellfun(@(x) x>=mRange(2) & x<mRange(3),DmCumReduced,'UniformOutput',false);
DmCumMedium=cellfun(@(x) x>=mRange(3) & x<mRange(4),DmCumReduced,'UniformOutput',false);
DmCumLow=cellfun(@(x) x>=mRange(4) & x<=mRange(5),DmCumReduced,'UniformOutput',false);

DmCumHighWeight=cellfun(@(x) x*4,DmCumHigh,'UniformOutput',false);
DmCumMediumHighWeight=cellfun(@(x) x*3,DmCumMediumHigh,'UniformOutput',false);
DmCumMediumWeight=cellfun(@(x) x*2,DmCumMedium,'UniformOutput',false);
DmCumLowWeight=cellfun(@(x) x*1,DmCumLow,'UniformOutput',false);

DmCumWeightAll=cellfun(@(a,b,c,d) a+b+c+d,...
    DmCumHighWeight,DmCumMediumHighWeight,DmCumMediumWeight,DmCumLowWeight,...
   'UniformOutput',false);


DistRange=[0 40 80 120]./1000;

ExpHigh=cellfun(@(x) x>=DistRange(1) & x<DistRange(2),MinDistanceLUReduced,'UniformOutput',false);
ExpMediumHigh=cellfun(@(x) x>=DistRange(2) & x<DistRange(3),MinDistanceLUReduced,'UniformOutput',false);
ExpMedium=cellfun(@(x) x>=DistRange(3) & x<DistRange(4),MinDistanceLUReduced,'UniformOutput',false);
ExpLow=cellfun(@(x) x>=DistRange(4),MinDistanceLUReduced,'UniformOutput',false);

ExpHighWeight=cellfun(@(x) x*4,ExpHigh,'UniformOutput',false);
ExpMediumHighWeight=cellfun(@(x) x*3,ExpMediumHigh,'UniformOutput',false);
ExpMediumWeight=cellfun(@(x) x*2,ExpMedium,'UniformOutput',false);
ExpLowWeight=cellfun(@(x) x*1,ExpLow,'UniformOutput',false);

ExpWeightAll=cellfun(@(a,b,c,d) a+b+c+d,...
    ExpHighWeight,ExpMediumHighWeight,ExpMediumWeight,ExpLowWeight,...
   'UniformOutput',false);

RiskWeightAll=cellfun(@(x,y) x.*y,DmCumWeightAll,ExpWeightAll,...
    'UniformOutput',false);

cellfun(@(x,y,z) fastscatter(x,y,z),xLongStudyReduced,yLatStudyReduced,RiskWeightAll,'UniformOutput',false);
    hcol=colorbar;


NumHigh=cellfun(@(x) numel(find(x)),ExpHigh);
NumMediumHigh=cellfun(@(x) numel(find(x)),ExpMediumHigh);
NumMedium=cellfun(@(x) numel(find(x)),ExpMedium);
NumLow=cellfun(@(x) numel(find(x)),ExpLow);