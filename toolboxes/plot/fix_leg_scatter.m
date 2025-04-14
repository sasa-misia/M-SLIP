function fix_leg_scatter(legObj, legIco, legPlt, dimItm, legPos, Options)

arguments
    legObj (1,1) % matlab.graphics.illustration.Legend
    legIco (:,:) {mustBeVector} % matlab.graphics.primitive.world.Group {mustBeVector}
    legPlt (:,:) {mustBeVector} % matlab.graphics.chart.primitive.Scatter {mustBeVector}
    dimItm (1,1) double
    legPos (1,:) char
    Options.xTxtPos (1,1) double = .5
end

xTxtPos = Options.xTxtPos;

legObj.Title.Visible = 'on';

obj_ico = findobj(legIco, 'type','patch');
set(obj_ico, 'Markersize',dimItm, 'Marker','square', 'MarkerEdgeColor','k');
% for i1 = 1:size(obj_ico, 1)
%     set(obj_ico(i1), 'XData',0.5)
% end

% the addition in height needed for the title:
title_hg = legObj.Position(4)/numel(legPlt);
legObj.Position([2, 4]) = [legObj.Position(2)-title_hg legObj.Position(4)+title_hg];

% calculate new position for the elements in the legeng:
new_pos = fliplr(0.5/(numel(legPlt)+2) : 1/(numel(legPlt)+2) : 1); % +2 instead of 1 to have a blank row as separator
legObj.Title.NodeChildren.Position = [xTxtPos, new_pos(1), 0];

% set the text to the right position:
leg_txt = findobj(legIco, 'Type','Text');
txt_pos = cell2mat({leg_txt.Position}.');
txt_pos(:,1) = xTxtPos;
txt_pos(:,2) = new_pos(3:end);
for i1 = 1:size(txt_pos, 1)
    set(leg_txt(i1), 'Position',txt_pos(i1,:));
end

% set the leg_ico to the right position:
for i1 = 1:size(txt_pos, 1)
    set(obj_ico(i1), 'YData',new_pos(i1+2))
end

set(legObj, 'Location',legPos);

end