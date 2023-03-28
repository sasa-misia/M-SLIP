function IDs = extract_id(fold_pdf, fold_shapefile)
% extract_id
%
%       extract_id(PDF_Folder)
%       extract ID from IFFI pdf (ISPRA website).

cd(fold_pdf)
Files = {dir('*.pdf').name};

StringStartID = 'Scheda Frana di 1° livello';
LengthID = 10 - 1; % Minus 1 because you will have a Enter char otherwise.
StringStartObsDate = 'Data osservazione:';
LengthObsDate = 8 - 1;

IDs = strings(1, length(Files));
ObsDate = strings(1, length(Files));
for i1 = 1:length(Files)
    StringsPDF = char(extractFileText(Files{i1}));
    IndStartID = strfind(StringsPDF, StringStartID) + length(StringStartID) + 1;
    IndStartObsDate = strfind(StringsPDF, StringStartObsDate) + length(StringStartObsDate) + 1;
    IDs(i1) = string(StringsPDF(IndStartID:IndStartID+LengthID));
    ObsDate(i1) = string(StringsPDF(IndStartObsDate:IndStartObsDate+LengthObsDate)); %yyyymmdd
end

EmptyIDsOrDate = IDs=="" | ObsDate=="";
IDs(EmptyIDsOrDate) = [];
ObsDate(EmptyIDsOrDate) = [];

[IDs, IndUnique, ~] = unique(IDs);
ObsDate = ObsDate(IndUnique);
ObsDatetime = datetime(ObsDate, 'InputFormat','yyyyMMdd');
ObsDatetimeUnique = unique(ObsDatetime);

ChoiceDatetime = listdlg('PromptString',{'Select datetime events:',''}, ...
                         'ListString',string(ObsDatetimeUnique));

IndDatetime = [];
for i1 = 1:length(ChoiceDatetime)
    IndDatetime = [IndDatetime, find(ObsDatetime == ObsDatetimeUnique(ChoiceDatetime(i1)))];
end

IDs = IDs(IndDatetime);
ObsDatetime = ObsDatetime(IndDatetime);

cd(fold_shapefile)
ShapeInfo = shapeinfo('frane_piff_opendataPoint.shp');
ReadShape = shaperead('frane_piff_opendataPoint.shp');
IDShape = extractfield(ReadShape, 'id_frana');
MunNameShape = extractfield(ReadShape, 'nome_com');
TypeShape = extractfield(ReadShape, 'nome_tipo');

Index = zeros(1, length(IDs));
for i1 = 1:length(IDs)
    Index(i1) = find(strcmp(IDShape, IDs(i1)));
end

[YlatID, XlongID] = deal(zeros(1, length(Index)));
[MunNameID, TypeID] = deal(cell(1, length(Index)));
for i1 = 1:length(Index)
    % Solo con punti è ok
    [YlatID(i1), XlongID(i1)] = projinv(ShapeInfo.CoordinateReferenceSystem, ...
                                        ReadShape(Index(i1)).X, ReadShape(Index(i1)).Y);
    MunNameID(i1) = MunNameShape(Index(i1));
    TypeID(i1) = TypeShape(Index(i1));
end

cd(fold_pdf)
% Xlong = extractfield(ReadShape, 'X');
% Ylat = extractfield(ReadShape, 'Y');
% 
% XlongID = Xlong(Index);
% YlatID = Ylat(Index);
DataToWriteHead = {'ID', 'Long', 'Lat', 'Municipality', 'Type', 'Date'};
DataToWriteCont = [cellstr(IDs)', num2cell(XlongID)', num2cell(YlatID)', MunNameID', TypeID', cellstr(ObsDatetime)'];
FileName_IDs = 'IDs.xlsx';
DataToWrite = [DataToWriteHead; DataToWriteCont];
writecell(DataToWrite, FileName_IDs)

end