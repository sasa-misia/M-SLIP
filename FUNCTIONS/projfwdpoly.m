function PolyOut = projfwdpoly(PolyIn, ProjCRS)

% This is a function to convert polygons in geographic coordinates to planar
%
% Syntax
%
%   - PolyOut = projfwdpoly(PolyIn, ProjCRS)
%   
% Required arguments:
%   - PolyIn : is the polyshape object (geographic coordinates)
%   
%   - ProjCRS : is the projcrs object containing the CRS refernce system of
%   the desired output polygon, PolyOut

%% Input Check
if not( isa(PolyIn,'polyshape') && isa(ProjCRS,'projcrs') )
    error('1st input must be a polyshape and 2nd must be the projcrs of coordinates!')
end

%% Settings

%% Core
PolyOut = PolyIn;
for i1 = 1:numel(PolyOut)
    [xPlan, yPlan] = projfwd(ProjCRS, PolyIn(i1).Vertices(:,2), PolyIn(i1).Vertices(:,1)); % First you select lat (2nd column)
    
    PolyOut(i1).Vertices = [xPlan, yPlan];
end

end