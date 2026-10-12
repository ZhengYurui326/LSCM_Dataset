function y = rician_channel_2(x, txRF, seed, varargin)
%RICIAN_CHANNEL_3 Rician channel with a LOS-dominant, low-delay-spread PDP.
%
%   y = rician_channel_3(x, txRF, seed)
%   y = rician_channel_3(x, txRF, seed, snr)
%
% The optional fourth input is accepted only for compatibility with older
% channel-call sites. AWGN is intentionally not added in this function.
%
% All rician_channel_2 through rician_channel_6 functions use the same
% path delays. Their only difference is the average power of each path.

    if nargin < 3
        error('rician_channel_3 requires at least x, txRF, and seed.');
    end

    % Fixed delay grid shared by all new channel variants (seconds).
    pathDelays = [0, 30e-9, 80e-9, 130e-9, 180e-9, 250e-9, 320e-9];

    % LOS-dominant profile: most power is concentrated in early paths.
    % The entries sum to one, so this changes the PDP shape only.
    pathVariance = [0.75, 0.14, 0.06, 0.025, 0.013, 0.008, 0.004];
    pathGains_dB = 10 * log10(pathVariance);

    ricianchan = comm.RicianChannel( ...
        SampleRate          = txRF.SampleRate, ...
        PathDelays          = pathDelays, ...
        AveragePathGains    = pathGains_dB, ...
        KFactor             = 2, ...
        DopplerSpectrum     = doppler("Jakes"), ...
        MaximumDopplerShift = 30, ...
        NormalizePathGains  = true, ...
        RandomStream        = "mt19937ar with seed", ...
        Seed                = seed);

    y = ricianchan(x);
end
