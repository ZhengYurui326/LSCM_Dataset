function y = rician_channel_5(x, txRF, seed, varargin)
%RICIAN_CHANNEL_5 Four-path Rician channel with a compact PDP.
%
%   y = rician_channel_5(x, txRF, seed)
%   y = rician_channel_5(x, txRF, seed, snr)
%
% The optional fourth input is accepted only for compatibility with older
% channel-call sites. AWGN is intentionally not added in this function.

    if nargin < 3
        error('rician_channel_5 requires at least x, txRF, and seed.');
    end

    % Use the first four taps of the common delay grid (seconds).
    pathDelays = [0, 30e-9, 80e-9, 130e-9];

    % Compact four-path environment: most power arrives in the first two
    % paths and each later reflection is weaker. Linear powers sum to 1.
    pathVariance = [0.58, 0.24, 0.12, 0.06];
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
