function y = rician_channel_3b(x, txRF, seed, varargin)
%RICIAN_CHANNEL_3B  仅执行多径 Rician 衰落，不在内部注入噪声
%
%   y = rician_channel_3b(x, txRF, seed)
%   y = rician_channel_3b(x, txRF, seed, snr)
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
%      因此本函数只保留衰落部分，AWGN 由主脚本在阵列形成后注入；
%   2. 第四个参数 snr 仍然保留，仅用于兼容旧调用方式，实际不会使用；
%   3. 城市微蜂窝弱 LOS，7 路多径 Rician 衰落模型（中等指数式衰减；
%      相比信道 1，主径略弱、中后部多径略强）：
%       pathDelays   = [0, 30, 80, 130, 180, 250, 320] ns
%       pathVariance = [0.500, 0.220, 0.130, 0.075, 0.040, 0.025, 0.010]（线性，和为 1）
%       pathGains_dB = [-3.01, -6.58, -8.86, -11.25, -13.98, -16.02, -20.00]
%   4. Rician K = 2, Jakes 多普勒谱, 最大多普勒 30 Hz；
%   5. 每次调用都会重新创建信道对象，使当前 seed 和 SampleRate 生效。

    if nargin < 3
        error('rician_channel_3b requires at least x, txRF, and seed.');
    end

    if nargin >= 4
        % 兼容旧接口：允许传入 snr，但此处不使用。
    end

    % ====== 路径参数 ======
    pathDelays = [0, 30e-9, 80e-9, 130e-9, 180e-9, 250e-9, 320e-9];  % 秒
    pathVariance = [0.500, 0.220, 0.130, 0.075, 0.040, 0.025, 0.010];  % 线性功率
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
