function y = rician_channel_4(x, txRF, seed, varargin)
%RICIAN_CHANNEL_4 Five-path Rician channel with a diffuse PDP.
%
%   y = rician_channel_4(x, txRF, seed)
%   y = rician_channel_4(x, txRF, seed, snr)
%
% The optional fourth input is accepted only for compatibility with older
% channel-call sites. AWGN is intentionally not added in this function.

    if nargin < 3
        error('rician_channel_4 requires at least x, txRF, and seed.');
    end

    % Use the first five taps of the common delay grid (seconds).
    pathDelays = [0, 30e-9, 80e-9, 130e-9, 180e-9];

    % Diffuse five-path environment: decay is slower than in channel 3, so
    % delayed reflections retain more power. Linear powers sum to 1.
    pathVariance = [0.40, 0.25, 0.16, 0.11, 0.08];
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
