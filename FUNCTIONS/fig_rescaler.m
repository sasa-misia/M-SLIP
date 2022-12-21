function [] = fig_rescaler(fig_object, leg_object, leg_position)
% RESCALER DI FIGURE
%   Quando hai una legenda che va fuori dai bordi dell'immagine fa un
%   rescale per mantenere il plot delle stesse dimensioni e aggiungere la
%   legenda. Se non lo fai la tua figura diventa più piccola per dare
%   spazio alla legenda.

set(fig_object, 'unit','pixels')
set(leg_object, 'unit','pixels')

FigSize = get(fig_object, 'position');
LegSize = get(leg_object, 'position');

if lower(string(leg_position)) == "northoutside"
    FigSize([2, 4]) = [FigSize(2)-LegSize(4), FigSize(2)+LegSize(4)];
elseif lower(string(leg_position)) == "southoutside"
    FigSize([2, 4]) = [FigSize(2)+LegSize(4), FigSize(2)+LegSize(4)];
elseif lower(string(leg_position)) == "eastoutside"
    FigSize([1, 3]) = [FigSize(1)-LegSize(3), FigSize(1)+LegSize(3)];
elseif lower(string(leg_position)) == "westoutside"
    FigSize([1, 3]) = [FigSize(1)+LegSize(3), FigSize(1)+LegSize(3)];
end

set(fig_object, 'position',FigSize)
end