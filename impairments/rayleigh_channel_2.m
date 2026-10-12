function y = rayleigh_channel_2(x, txRF, seed, varargin)
%RAYLEIGH_CHANNEL_2 仅执行多径 Rayleigh 衰落，不在内部注入噪声
%
%   y = rayleigh_channel_2(x, txRF, seed)
%   y = rayleigh_channel_2(x, txRF, seed, snr)
%
%   说明：
%   1. 当前 DOA 数据生成链路要求先做阵列导向投影，再给各阵元独立加噪；
%   2. 因此本函数只保留衰落部分，AWGN 由主脚本在阵列形成后注入；
%   3. 第四个参数 snr 仍然保留，仅用于兼容旧调用方式，实际不会使用。

    if nargin < 3
        error('rayleigh_channel_2 requires at least x, txRF, and seed.');
    end

    if nargin >= 4
        % 兼容旧接口：允许传入 snr，但此处不使用。
    end

    % 城市宏蜂窝 NLOS 场景的 8 径瑞利衰落模型。
    pathDelays = [0, 100e-9, 200e-9, 400e-9, 600e-9, 850e-9, 1100e-9, 1400e-9];
    pathVariance = [0.40, 0.25, 0.15, 0.10, 0.05, 0.03, 0.015, 0.005];
    pathGains_dB = 10 * log10(pathVariance);

    % 使用固定随机种子初始化信道对象，保证相同条件下可复现。
    rayleighchan = comm.RayleighChannel( ...
        'SampleRate', txRF.SampleRate, ...
        'PathDelays', pathDelays, ...
        'AveragePathGains', pathGains_dB, ...
        'DopplerSpectrum', doppler("Jakes"), ...
        'MaximumDopplerShift', 50, ...
        'NormalizePathGains', true, ...
        'RandomStream', "mt19937ar with seed", ...
        'Seed', seed);

    % 输出为衰落后的复基带信号，后续是否加噪由调用方决定。
    y = rayleighchan(x);
end
