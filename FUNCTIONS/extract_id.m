function IDs = extract_id(fold_pdf)
% extract_id
%
%       extract_id(PDF_Folder)
%       extract ID from IFFI pdf (ISPRA website).

cd(fold_pdf)
Files = {dir('*.pdf').name};

IDs = strings(1, length(Files));
for i1 = 1:length(Files)
    StringsPDF = char(extractFileText(Files{i1}));
    IDs(i1) = string(StringsPDF(31:40));
end

IDs = unique(IDs);

ShapeInfo = shapeinfo('frane_piff_opendataPoint.shp');
ReadShape = shaperead('frane_piff_opendataPoint.shp');
IDShape = extractfield(ReadShape, 'id_frana');
for i1 = 1:length(IDs)
    Index(i1) = find(strcmp(IDShape,IDs(i1)));
end

for i1 = 1:length(Index)
    % Solo con punti è ok
    [YlatID(i1), XlongID(i1)] = projinv(ShapeInfo.CoordinateReferenceSystem, ...
                                        ReadShape(Index(i1)).X, ReadShape(Index(i1)).Y);
end

% Xlong = extractfield(ReadShape, 'X');
% Ylat = extractfield(ReadShape, 'Y');
% 
% XlongID = Xlong(Index);
% YlatID = Ylat(Index);
DataToWriteHead = {'ID', 'Long', 'Lat'};
DataToWriteCont = [cellstr(IDs)', num2cell(XlongID)', num2cell(YlatID)'];
FileName_IDs = 'IDs.xlsx';
DataToWrite = [DataToWriteHead; DataToWriteCont];
writecell(DataToWrite, FileName_IDs)

end