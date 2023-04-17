function fix_leg_scatter(leg_obj, leg_ico, leg_plots, DimItems, Location)

leg_obj.Title.Visible = 'on';

obj_ico = findobj(leg_ico, 'type','patch');
set(obj_ico, 'Markersize',DimItems, 'Marker','square', 'MarkerEdgeColor','k');
% for i1 = 1:size(obj_ico, 1)
%     set(obj_ico(i1), 'XData',0.5)
% end

% the addition in height needed for the title:
title_hight = leg_obj.Position(4)/numel(leg_plots);
leg_obj.Position([2 4]) = [leg_obj.Position(2)-title_hight leg_obj.Position(4)+title_hight];

% calculate new position for the elements in the legeng:
new_pos = fliplr(0.5/(numel(leg_plots)+2):1/(numel(leg_plots)+2):1); % +2 instead of 1 to have a blank row as separator
leg_obj.Title.NodeChildren.Position = [0.5 new_pos(1) 0];

% set the text to the right position:
leg_txt = findobj(leg_ico,'Type','Text');
txt_pos = cell2mat({leg_txt.Position}.');
txt_pos(:,1) = .5;
txt_pos(:,2) = new_pos(3:end);
for i1 = 1:size(txt_pos, 1)
    set(leg_txt(i1), 'Position',txt_pos(i1,:));
end

% set the leg_ico to the right position:
for i1 = 1:size(txt_pos, 1)
    set(obj_ico(i1), 'YData',new_pos(i1+2))
end

set(leg_obj, 'Location',Location);

end