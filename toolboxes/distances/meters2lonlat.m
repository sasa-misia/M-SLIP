function [dLon, dLat] = meters2lonlat(sizeInMeters, latReference)

arguments
    sizeInMeters (:,:) double {mustBeVector}
    latReference (:,:) double {mustBeVector}
end

if numel(sizeInMeters) ~= numel(latReference)
    if isscalar(latReference)
        latReference = repmat(latReference, size(sizeInMeters));
    elseif isscalar(sizeInMeters)
        sizeInMeters = repmat(sizeInMeters, size(latReference));
    else
        error('Sizes of the first two arguments must match!')
    end
end

if any(latReference > 90, 'all') || any(latReference < -90, 'all')
    error('Latitude references (2nd argument) must be given in deg and must be in the range [-90, 90]!')
end

[dLat, dLon] = deal(zeros(size(sizeInMeters)));
for i1 = 1:numel(sizeInMeters)
    dLat(i1) = rad2deg(sizeInMeters(i1)/earthRadius); % sizeInMeters expressed in lat (see Sa notes)
    dLon(i1) = rad2deg(acos( (cos(sizeInMeters(i1)/earthRadius) - sind(latReference(i1))^2) / cosd(latReference(i1))^2 )); % sizeInMeters expressed in lon (see Sa notes)
end

end