if not(exist('Fig', 'var')); Fig = uifigure; end
ProgressBar = uiprogressdlg(Fig, 'Title','Please wait', 'Indeterminate','on', ...
                                 'Cancelable','off', 'Message','Reading files...');
drawnow

%% Data import and initialization
sl              = filesep;
FilenameRainRG  = "C:\Users\salva\OneDrive - Università degli Studi di Parma\Landslides Datasets\Emilia Romagna\Piogge\Piogge Giornaliere Emilia.xlsx";
FilenameRainSat = "C:\Users\salva\OneDrive - Università degli Studi di Parma\MATLAB\Analisi ML\Emillia Romagna Fast NN\Variables\AverageRainSat.mat";
FilenameRainSyn = "C:\Users\salva\OneDrive - Università degli Studi di Parma\MATLAB\Analisi ML\Emillia Romagna Fast NN\Variables\SynthetizedRain.mat";
FilenameTempRG  = "C:\Users\salva\OneDrive - Università degli Studi di Parma\Landslides Datasets\Emilia Romagna\Temperature\Temperature Giornaliere Emilia.xlsx";
FilenameTempSat = "C:\Users\salva\OneDrive - Università degli Studi di Parma\MATLAB\Analisi ML\Emillia Romagna Fast NN\Variables\AverageTempSat.mat";
FilenameGenSumm = "C:\Users\salva\OneDrive - Università degli Studi di Parma\MATLAB\Analisi ML\Emillia Romagna Fast NN\Variables\GeneralLandslidesSummary.mat";
FilenameMunLand = "C:\Users\salva\OneDrive - Università degli Studi di Parma\MATLAB\Analisi ML\Emillia Romagna Fast NN\Variables\LandslidesCountPerMun.mat";
FilenameAvgNDVI = "C:\Users\salva\OneDrive - Università degli Studi di Parma\MATLAB\Analisi ML\Emillia Romagna Fast NN\Variables\AverageNDVI.mat";
PathForDataset  = "C:\Users\salva\OneDrive - Università degli Studi di Parma\MATLAB\Analisi ML\Emillia Romagna Fast NN\Variables";