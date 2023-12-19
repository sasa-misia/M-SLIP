function PolyOut = projinvpoly(PolyIn, ProjCRS)

% This is a function to convert polygons in planar coordinates to lat lon
%
% Syntax
%
%   - PolyOut = projinvpoly(PolyIn, ProjCRS)
%   
% Required arguments:
%   - PolyIn : is the polyshape object
%   
%   - ProjCRS : is the projcrs object containing the CRS refernce system of
%   the current PolyIn

%% Input Check
if not( isa(PolyIn,'polyshape') && isa(ProjCRS,'projcrs') )
    error('1st input must be a polyshape and 2nd must be the projcrs of coordinates!')
end

%% Settings

%% Core
PolyOut = PolyIn;
for i1 = 1:numel(PolyOut)
    [LatPoly, LonPoly] = projinv(ProjCRS, PolyIn(i1).Vertices(:,1), PolyIn(i1).Vertices(:,2));
    
    PolyOut(i1).Vertices = [LonPoly, LatPoly];
end

end