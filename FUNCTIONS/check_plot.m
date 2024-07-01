function [FigObj, AxsObj] = check_plot(fold0)

arguments
    fold0 (1,:) char
end

FigObj = figure(1);
AxsObj = axes(FigObj);
hold(AxsObj,'on')

sl = filesep;
load([fold0,sl,'Variables',sl,'StudyAreaVariables.mat'], 'StudyAreaPolygon')

plot(StudyAreaPolygon, 'FaceColor','none', 'EdgeColor','k', 'LineWidth',1.5);
fig_settings(fold0, 'AxisTick');

end