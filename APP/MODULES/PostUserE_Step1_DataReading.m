cd(fold_var)

StatusPrevAnalysis=0;
if exist('AnalysisInformation.mat')
    load('AnalysisInformation.mat','StabilityAnalysis')
    StabilityAnalysisOld=StabilityAnalysis;
    clear StabilityAnalysis
    StatusPrevAnalysis=1;
end

Variables={};
NameFile={};
VariablesInterpolation={};
AnswerRainfall={'AnswerRainfallRec','AnswerRainfallFor'};

if AnswerRainfallRec==1
    cd(fold_raw_rain)

    if isempty({dir('*.xlsx').name})
        % Fig = uifigure; % Remember to comment this line if is app version
        Answer = uiconfirm(Fig, strcat("No excel in ",fold_raw_rain), ...
                           'No file in directory', 'Options','Search file');
        % close(Fig) % Remember to comment this line if is app version
        
        copyindirectory('xlsx', fold_raw_rain, 'mode','multiple')
    end

    Files={dir('*.xlsx').name};
    choice1=listdlg('PromptString',{'Choose a file:',''},'ListString',Files);
    FileName_Rainfall=string(Files(choice1)); 
    NameFile={'FileName_Rainfall'};

    drawnow % Remember to remove if in Standalone version
    figure(Fig) % Remember to remove if in Standalone version
    
    Sheet_Sta=readcell(FileName_Rainfall,'Sheet','Stations table');
    Sheet_Rain=readcell(FileName_Rainfall,'Sheet','Data table');

    RainfallDates=unique([Sheet_Rain{cellfun(@isdatetime,Sheet_Rain)}]);
    RainfallDates(1)=[];
    RainfallDates=datetime(RainfallDates,'Format','dd/MM/yyyy HH:mm');
    RainfallDates=dateshift(RainfallDates,'start','hours','nearest');

    xLongSta=[Sheet_Sta{2:end,8}]';
    yLatSta=[Sheet_Sta{2:end,9}]';
    
    Stations=string(Sheet_Sta(2:end,1));
    StationsNumber=length(Stations);
    CoordinatesRainGauges=[xLongSta yLatSta];
    RainGauges={Stations CoordinatesRainGauges};

    HeaderLine=find(cellfun(@isdatetime,Sheet_Rain),1); % Automatically recognize excel file header line
    % HeaderLine=7; % Manually input of excel file header line
    
    HoursNum=0; 
    for i=HeaderLine:length(Sheet_Rain)
        if ~ismissing(Sheet_Rain{i,3}); HoursNum=HoursNum+1; else; break; end
    end
    
    RainNumeric=[Sheet_Rain{cellfun(@isnumeric,Sheet_Rain)}]';
    GeneralRainData=zeros(HoursNum,StationsNumber);
    
    for i=1:StationsNumber
        GeneralRainData(:,i)=RainNumeric((i-1)*(HoursNum)+1:(i-1)*(HoursNum)+(HoursNum));
    end
    
    GeneralRainData(isnan(GeneralRainData))=0;
    GeneralRainData(GeneralRainData==-999)=0;
    GeneralRainData=GeneralRainData';
    
    GeneralDatesStart=dateshift([Sheet_Rain{HeaderLine:HoursNum+HeaderLine-1,1}]','start','hours','nearest');
    GeneralDatesEnd=dateshift([Sheet_Rain{HeaderLine:HoursNum+HeaderLine-1,2}]','start','hours','nearest');


    
    %% Building of datetime format
    for i=1:size(GeneralDatesStart,1)
        if isnat(GeneralDatesStart(i))==1 && i==1
            GeneralDatesStart(i,:)=GeneralDatesStart(i+1,:)-hours(1);
        elseif isnat(GeneralDatesStart(i))==1 && i>1
            GeneralDatesStart(i,:)=GeneralDatesStart(i-1,:)+hours(1);
        end
    end
    
    for i=1:size(GeneralDatesEnd,1)
        if isnat(GeneralDatesEnd(i))==1 && i==1
            GeneralDatesEnd(i,:)=GeneralDatesEnd(i+1,:)-hours(1);
        elseif isnat(GeneralDatesEnd(i))==1 && i>1
            GeneralDatesEnd(i,:)=GeneralDatesEnd(i-1,:)+hours(1);
        end
    end
    Variables={'GeneralRainData','RainGauges','RainfallDates'};
end
    
if AnswerRainfallFor==1
    
    cd(fold_raw_rain_for)
    Files={dir('*.').name,dir('*.grib').name}; % '*.' is for file without extension
    Files(1:2)=[];
    choice2=listdlg('PromptString',{'Choose a file:',''},'ListString',Files);
    FileName_Forecast=strcat(fold_raw_rain_for,sl,char(Files(choice2)));
    try setup_nctoolbox; catch; disp('A problem has occurred in nctoolbox'); end

    drawnow % Remember to remove if in Standalone version
    figure(Fig) % Remember to remove if in Standalone version
    
    ForecastData=cell(size(choice2,2),5);
    
    for i1=1:size(choice2,2)
        GribData=ncdataset(FileName_Forecast(i1,:));  
        GribLat=double(GribData.data('lat'));
        GribLong=double(GribData.data('lon'));
        [MeshLong, MeshLat] =meshgrid(GribLong,GribLat);
        RainTemp=double(GribData.data('Total_precipitation_surface_1_Hour_DifferenceFromEnd'));
        Instants=GribData.time('time1_bounds');
        InstantsTime=datetime(Instants,'ConvertFrom','datenum');
        ModelRunTime=InstantsTime(1,1);
        ForecastTime=InstantsTime(:,2);   
        
        HoursForecast=ForecastTime-ModelRunTime;
        ForecastData{i1,1}=ModelRunTime;
        ForecastData{i1,2}=ForecastTime;
        ForecastData{i1,3}=HoursForecast;
        ForecastData{i1,4}=RainTemp;

        GridForecastModel={MeshLong,MeshLat};
    end
    Variables=[Variables,{'ForecastData','GridForecastModel'}];
    NameFile=[NameFile,{'FileName_Forecast'}];
end

%% Analysis type
cd(fold_var)
switch AnalysisCase
    case 'SLIP'
        
        dTRecordings=RainfallDates(2)-RainfallDates(1);
        AnalysisDateMaxRange=[min(RainfallDates)+days(30)+dTRecordings,max(RainfallDates)];
        AnalysisDates=AnalysisDateMaxRange(1):dTRecordings:AnalysisDateMaxRange(2);
        AnalysisDates=datetime(AnalysisDates,'Format','dd/MM/yyyy HH:mm:ss');


        if AnswerRainfallFor==1
            for i1=1:size(choice2,2)
                ForecastTime=ForecastData{i1,2};
                IndexForecast=find(ForecastTime-days(30)>RainfallDates(1));   
                if ~isempty(IndexForecast)
                    ForecastData{i1,5}=ForecastTime(IndexForecast);
                end
            end
            AnalysisDates=unique(cat(1,ForecastData{:,5}));

            if isempty(AnalysisDates)
                error('DT 1')                
            end
        end   

        EventChoice = listdlg('PromptString',{'Select event(s) to analyse through SLIP:',''},...
                        'ListString',AnalysisDates);
        AnalysisEvents = AnalysisDates(EventChoice);
        
        drawnow % Remember to remove if in Standalone version
        figure(Fig) % Remember to remove if in Standalone version

        RainfallSetInterval={AnalysisEvents(1)-days(30)-dTRecordings,AnalysisEvents(end)-dTRecordings}; % From 30 days before the first event to the hour before the last event
        RainfallSetIndex=[find(abs(minutes(GeneralDatesStart-RainfallSetInterval{1}))<=1)...
                  find(abs(minutes(GeneralDatesStart-RainfallSetInterval{2}))<=1)];

        StabilityEventsAnalysed=hours(AnalysisEvents(end)-AnalysisEvents(1))+1; % Number of stability analysis
        StabilityAnalysis={StabilityEventsAnalysed,AnalysisEvents,RainfallSetIndex};

        if StatusPrevAnalysis==1 & StabilityAnalysis{1}~=StabilityAnalysisOld{1} 
            StatusPrevAnalysis=0;
        elseif StatusPrevAnalysis==1 & StabilityAnalysis{1}==StabilityAnalysisOld{1} & all(StabilityAnalysis{2}~=StabilityAnalysisOld{2}) & all(StabilityAnalysis{3}~=StabilityAnalysisOld{3})
            StatusPrevAnalysis=0;
        end
           
        IndexInterpolation=RainfallSetIndex(1):RainfallSetIndex(end);
        VariablesInterpolation={'IndexInterpolation'};
        RainfallEvents=AnalysisEvents;

        if AnswerRainfallFor==1
            ForecastChoice=AnalysisDates(choice1);
        end
                    
        Variables_AnalysisSLIP={'StabilityAnalysis','AnalysisDateMaxRange','StatusPrevAnalysis'};
        save('AnalysisInformation.mat',Variables_AnalysisSLIP{:});

    case 'Other'
        if AnswerRainfallFor==1
            RainfallDates=unique(cat(1,ForecastData{:,2}));
        end
        
        choice1=listdlg('PromptString',{'Select event(s):',''},...
                        'ListString',RainfallDates);
        RainfallEvents=string(RainfallDates(choice1));
        RainfallEvents=datetime(RainfallEvents,'Format','dd/MM/yyyy HH:mm');

        drawnow;
        if AnswerRainfallFor==1
            ForecastChoice=RainfallDates(choice1);
        else

        GeneralDatesStart=datetime(GeneralDatesStart,'Format','dd/MM/yyyy HH:mm:ss');
        for i3=1:size(RainfallEvents,2)
            RainfallSetIndex(i3)=find(abs(minutes(GeneralDatesStart-RainfallEvents(i3)))<=1);
        end
        VariablesInterpolation={'RainfallSetIndex'};
        end
end

if AnswerRainfallFor==1
    for i1=1:size(ForecastChoice,1)
        Ind1=1;
        RunNumber=[];
        PossibleHours=[];
        for i2=1:size(ForecastData,1)
            Indgood=find(ForecastChoice(i1)==ForecastData{i2,2});
            if ~isempty(Indgood)
                RunNumber(Ind1)=i2;
                PossibleHours(Ind1)=hours(ForecastData{i2,3}(Indgood));
                Ind1=Ind1+1;
            end
        end
        
        if size(ForecastChoice,1)==1
            choice3=listdlg('PromptString',{'Select forcasted hours:',''},...
                'ListString',string(PossibleHours));
            SelectedHoursRun{1,1}=PossibleHours(choice3);
            SelectedHoursRun{1,2}=RunNumber(choice3);
        else
            [SelectedHoursRun{i1,1},posmin]=min(PossibleHours);
            SelectedHoursRun{i1,2}=RunNumber(posmin);
        end


    end    

    if strcmp(AnalysisCase,'SLIP')
        SelectedHoursRun(:,1)=cellfun(@(x) 1:x,SelectedHoursRun(:,1),'UniformOutput',false);
    end

        VariablesInterpolation=[VariablesInterpolation,{'SelectedHoursRun'}];

end

save('UserE_Answers.mat',NameFile{:},'AnalysisCase',AnswerRainfall{:});

if exist('RainInterpolated.mat')
    save('RainInterpolated.mat',VariablesInterpolation{:}, '-append');
else
    save('RainInterpolated.mat',VariablesInterpolation{:}, '-v7.3');
end

save('GeneralRainfall.mat',Variables{:});