function SplittedPolyFlat = divide_poly_grids(poly,gridX,gridY)

%Input
%poly: a single polyshape to subdivide (NO ARRAY).
%gridX: Number of divisions in x direction
%gridY: Number of divisions in y direction

%Output
%SplittedPolyFlat: a flatted array containing your subdivided polygons

Extremes = [ min(poly.Vertices, [], 1)
             max(poly.Vertices, [], 1) ];

dX = (Extremes(2,1) - Extremes(1,1))/gridX;
dY = (Extremes(2,2) - Extremes(1,2))/gridY;

NumOfPolyGrids = gridX*gridY;
PolyGrids    = repmat(polyshape, gridY, gridX); % Initialize polyshape array
SplittedPoly = repmat(polyshape, gridY, gridX); % Initialize polyshape array
for i1 = 1:gridX
    for i2 = 1:gridY
        xLeft   = Extremes(1,1)+(i1-1)*dX;
        xRight  = Extremes(1,1)+(i1)*dX;
        yBottom = Extremes(1,2)+(i2-1)*dY;
        yTop    = Extremes(1,2)+(i2)*dY;
        PolyGrids(i2, i1)    = polyshape([xLeft, xRight, xRight, xLeft], [yBottom, yBottom, yTop, yTop]);
        SplittedPoly(i2, i1) = intersect(poly, PolyGrids(i2, i1));
    end
end

SplittedPolyFlat = SplittedPoly(:);
IndEmpty = arrayfun(@(x) isempty(x.Vertices), SplittedPolyFlat);
SplittedPolyFlat(IndEmpty) = [];

end