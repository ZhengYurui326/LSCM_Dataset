function y = rayleigh_channel_compare(x, txRF, seed, varargin)
%RAYLEIGH_CHANNEL_COMPARE 用于和 Rician 信道公平对比的 Rayleigh 信道。
%
%   y = rayleigh_channel_compare(x, txRF, seed)
%   y = rayleigh_channel_compare(x, txRF, seed, snr)
%
%   输入：
%       x    : 输入复基带信号（列向量或矩阵，每列一个通道）
%       txRF : 参数结构体，至少包含 txRF.SampleRate
%       seed : 随机种子
%
%   输出：
%       y    : 经过多径 Rayleigh 衰落后的信号（不含 AWGN）
%
%   对比原则：
%   1. 除衰落分布外，其余信道参数均与 rician_channel_1 相同；
%   2. 本函数使用 Rayleigh 衰落，不设置 Rician K 因子；
%   3. 第四个 snr 参数仅用于兼容旧调用方式，实际不在函数内加噪；
%   4. 每次调用重新创建信道对象，使当前 seed 和 SampleRate 生效。

    if nargin < 3
        error('rayleigh_channel_compare requires at least x, txRF, and seed.');
    end

    % ====== 路径参数：与 rician_channel_1 完全一致 ======
    pathDelays = [0, 30e-9, 80e-9, 130e-9, 180e-9, 250e-9, 320e-9];  % 秒
    pathVariance = [0.55, 0.20, 0.12, 0.07, 0.04, 0.015, 0.005];     % 线性功率
    pathGains_dB = 10*log10(pathVariance);

    % ====== 构建 Rayleigh 信道对象 ======
    rayleighchan = comm.RayleighChannel( ...
        SampleRate           = txRF.SampleRate, ...
        PathDelays           = pathDelays, ...
        AveragePathGains     = pathGains_dB, ...
        DopplerSpectrum      = doppler("Jakes"), ...
        MaximumDopplerShift  = 30, ...
        NormalizePathGains   = true, ...
        RandomStream         = "mt19937ar with seed", ...
        Seed                 = seed);

    % AWGN 由外部数据生成流程在需要的位置统一添加。
    y = rayleighchan(x);
end
