function y = rician_channel_1(x, txRF, seed, varargin)
%RICIAN_CHANNEL_2  仅执行多径 Rician 衰落，不在内部注入噪声，主数据集使用的信道模型
%
%   y = rician_channel_2(x, txRF, seed)
%   y = rician_channel_2(x, txRF, seed, snr)
%
%   输入：
%       x    : 输入基带信号（列向量或矩阵，每列一个通道）
%       txRF : 结构体，至少需要字段：
%              txRF.SampleRate  - 采样率 (Hz)
%       seed : 随机种子
%
%   输出：
%       y    : 通过 Rician 多径信道后的输出信号（不含 AWGN）
%
%   说明：
%   1. 当前 DOA 数据生成链路要求先做阵列导向投影，再给各阵元独立加噪；
%   2. 因此本函数只保留衰落部分，AWGN 由主脚本在阵列形成后注入；
%   3. 第四个参数 snr 仍然保留，仅用于兼容旧调用方式，实际不会使用。
%   4. 城市微蜂窝环境，7 路多径 Rician 衰落模型：
%       pathDelays = [0, 30, 80, 130, 180, 250, 320] ns
%       pathVariance = [0.55, 0.20, 0.12, 0.07, 0.04, 0.015, 0.005]
%   5. Rician K = 2, Jakes 多普勒谱, 最大多普勒 30 Hz
%   6. 每次调用都会重新创建信道对象，使当前 seed 和 SampleRate 生效。

    if nargin < 3
        error('rician_channel_2 requires at least x, txRF, and seed.');
    end

    if nargin >= 4
        % 兼容旧接口：允许传入 snr，但此处不使用。
    end

    % ====== 路径参数 ======
    pathDelays = [0, 30e-9, 80e-9, 130e-9, 180e-9, 250e-9, 320e-9];  % 秒
    pathVariance = [0.55, 0.20, 0.12, 0.07, 0.04, 0.015, 0.005];  % 线性功率
    pathGains_dB = 10*log10(pathVariance);            % 转成 dB

    % ====== 构建 Rician 信道对象 ======
    ricianchan = comm.RicianChannel( ...
        SampleRate           = txRF.SampleRate, ...
        PathDelays           = pathDelays, ...
        AveragePathGains     = pathGains_dB, ...
        KFactor              = 2, ...
        DopplerSpectrum      = doppler("Jakes"), ...
        MaximumDopplerShift  = 30, ...
        NormalizePathGains   = true, ...
        RandomStream         = "mt19937ar with seed", ...
        Seed                 = seed);

    % 输出为衰落后的复基带信号，后续是否加噪由调用方决定。
    y = ricianchan(x);
end
