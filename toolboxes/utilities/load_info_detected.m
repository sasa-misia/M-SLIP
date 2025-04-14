function [infoDetExst, infoDet2Use] = load_info_detected(fold_var, Options)

arguments
    fold_var (1,:) char {mustBeFolder}
    Options.manual (1,1) logical = true;
end

manual = Options.manual;

sl = filesep;

infoDetExst = false;
infoDet2Use = table;
if exist([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'file')
    load([fold_var,sl,'InfoDetectedSoilSlips.mat'], 'InfoDetectedSoilSlips','IndDefInfoDet','FilesDetectedSoilSlip')
    if manual && (numel(InfoDetectedSoilSlips) > 1)
        selInfoDet  = listdlg2({'Select the InfoDetected to use:'}, FilesDetectedSoilSlip, 'OutType','NumInd');
        infoDet2Use = InfoDetectedSoilSlips{selInfoDet};
    else
        infoDet2Use = InfoDetectedSoilSlips{IndDefInfoDet};
    end
    infoDetExst = true;
end

end