function steering_table = build_uca_steering_table(num_antennas, carrier_freq, doa_grid_deg)
%BUILD_UCA_STEERING_TABLE Build narrowband UCA steering vectors.
%   steering_table = BUILD_UCA_STEERING_TABLE(num_antennas, carrier_freq, doa_grid_deg)
%   returns a [num_antennas x num_angles] complex steering table for an
%   equally spaced UCA lying on the x-y plane.
%
%   Geometry and angle convention:
%   - 8-element UCA by default in the dataset scripts
%   - element 1 is placed at the front direction (+y axis)
%   - positive DOA angles point to the right (+x), negative angles to the left (-x)
%   - all steering vectors are referenced to element 1, so row 1 is always 1
%
%   The radius is chosen such that the chord length between adjacent
%   elements equals lambda/2, preserving the original half-wavelength
%   spatial sampling density used by the ULA version.

    c = physconst('LightSpeed');
    lambda = c / carrier_freq;

    % Keep the adjacent chord length equal to lambda/2.
    radius = lambda / (4 * sin(pi / num_antennas));

    % Element 1 is at the front (+y), then elements proceed clockwise.
    element_azimuth_rad = pi / 2 - (0:num_antennas-1).' * (2 * pi / num_antennas);
    positions_xy = radius * [cos(element_azimuth_rad), sin(element_azimuth_rad)];
    relative_positions_xy = positions_xy - positions_xy(1, :);

    % Front = +y, right = +x, left = -x.
    direction_vectors = [sind(doa_grid_deg); cosd(doa_grid_deg)];
    phase_offsets = relative_positions_xy * direction_vectors;
    steering_table = exp(-1j * 2 * pi * phase_offsets / lambda);
end
