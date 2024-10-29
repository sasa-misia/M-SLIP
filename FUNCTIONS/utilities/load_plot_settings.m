function [selFont, selFontSize, selLegendPosition] = load_plot_settings(fold_var)

arguments
    fold_var (1,:) char {mustBeFolder}
end

sl = filesep;

selLegendPosition = '';
if exist([fold_var,sl,'PlotSettings.mat'], 'file')
    load([fold_var,sl,'PlotSettings.mat'], 'LegendPosition','Font','FontSize')
    selFont = Font;
    selFontSize = FontSize;
    if exist('LegendPosition', 'var'); selLegendPosition = LegendPosition; end
else
    selFont = 'Calibri';
    selFontSize = 8;
    selLegendPosition = 'Best';
end

end