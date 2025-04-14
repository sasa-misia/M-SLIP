function datasetOut = dataset_extr_filtr(dsetInfo, Options)

arguments
    dsetInfo table
    Options.fltrCase char = ''
end

fltrCase = Options.fltrCase;

if isempty(fltrCase)
    fltrCase = char(listdlg2({'Dataset to consider?'}, {'1T', '2T', 'All', 'Manual'}));
end

if not(any(strcmpi(fltrCase, {'1t', '2t', 'all', 'manual'})))
    error('fltrCase must be one between 1T, 2T, All, or Manual!')
end

datasetOut = dataset_extraction(dsetInfo);

switch fltrCase
    case '1T'
        datesToMantain = dsetInfo.EventDate(dsetInfo.LandslideEvent);

    case '2T'
        datesToMantain = [ dsetInfo.EventDate(dsetInfo.LandslideEvent)
                           dsetInfo.BeforeEventDate(dsetInfo.LandslideEvent) ];

    case 'All'
        datesToMantain = unique(datasetOut{'Total','Dates'}{:}{:,'Datetime'});

    case 'Manual'
        datesChoosable = unique(datasetOut{'Total','Dates'}{:}{:,'Datetime'});
        indsDatesChose = checkbox2(datesChoosable, 'Title',{'Choose dates: '}, 'OutType','NumInd');
        datesToMantain = datesChoosable(indsDatesChose);

    otherwise
        error('fltrCase not recognized!')
end

indsToMantain = cell(size(datasetOut,1), 1);
for i1 = 1:numel(indsToMantain)
    if iscell(datasetOut{i1,'Dates'}{:})
        indsToMantain{i1} = cell(1, numel(datasetOut{i1,'Dates'}{:}));
        for i2 = 1:numel(datasetOut{i1,'Dates'}{:})
            indsToMantTmp = arrayfun(@(x) datasetOut{i1,'Dates'}{:}{i2}{:,'Datetime'} == x, datesToMantain, 'UniformOutput',false);
            indsToMantain{i1}{i2} = any([indsToMantTmp{:}], 2);
            for i3 = 1:size(datasetOut,2)
                datasetOut{i1,i3}{:}{i2}(not(indsToMantain{i1}{i2}), :) = []; % cleaning of dates not to maintain
            end
        end
    else
        indsToMantTmp = arrayfun(@(x) datasetOut{i1,'Dates'}{:}{:,'Datetime'} == x, datesToMantain, 'UniformOutput',false);
        indsToMantain{i1} = any([indsToMantTmp{:}], 2);
        for i2 = 1:size(datasetOut,2)
            datasetOut{i1,i2}{:}(not(indsToMantain{i1}), :) = []; % cleaning of dates not to maintain
        end
    end
end

end