function y = rician_channel_6(x, txRF, seed, varargin)
%RICIAN_CHANNEL_6 Three-path Rician channel with a sparse PDP.
%
%   y = rician_channel_6(x, txRF, seed)
%   y = rician_channel_6(x, txRF, seed, snr)
%
% The optional fourth input is accepted only for compatibility with older
% channel-call sites. AWGN is intentionally not added in this function.

    if nargin < 3
        error('rician_channel_6 requires at least x, txRF, and seed.');
    end

    % Use the first three taps of the common delay grid (seconds).
    pathDelays = [0, 30e-9, 80e-9];

    % Sparse three-path environment: a dominant earliest path is followed
    % by two successively weaker reflections. Linear powers sum to 1.
    pathVariance = [0.68, 0.22, 0.10];
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
