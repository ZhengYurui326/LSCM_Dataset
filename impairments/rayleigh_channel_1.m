function y = rayleigh_channel_1(x, txRF, seed, snr)
%RAYLEIGH_CHANNEL_1  Apply a multipath Rayleigh fading channel to input signal
%
%   y = rayleigh_channel_1(x, txRF, seed, snr)
%
%   输入：
%       x    : 输入基带信号（列向量或矩阵，每列一个通道）
%       txRF : 结构体，至少需要字段：
%              txRF.SampleRate  - 采样率 (Hz)
%       seed: 随机种子
%       snr  : 信噪比 (dB)
%
%   输出：
%       y    : 通过 Rayleigh 多径信道后的输出信号
%
%   说明：
%   - 室内环境（NLOS场景），5 路多径模型：
%       pathDelays = [0, 40, 90, 160, 240] ns
%       pathVariance = [0.70, 0.18, 0.08, 0.03, 0.01]
%   - Rayleigh 衰落（无直射路径，无KFactor参数）
%   - Jakes 多普勒谱，最大多普勒 5 Hz（低速移动或静止）
%   - 使用 NormalizePathGains = true，使总平均功率为 0 dB
%
%   如果希望多次调用保持同一个信道实现，可以保留这个 persistent
%   设计：第一次调用创建信道，之后重复使用。

    persistent rayleighchan

    if isempty(rayleighchan)
        % ====== 路径参数 ======
        pathDelays = [0, 40e-9, 90e-9, 160e-9, 240e-9];  % 秒
        pathVariance = [0.70, 0.18, 0.08, 0.03, 0.01];  % 线性功率
        pathGains_dB = 10*log10(pathVariance);            % 转成 dB

        % ====== 构建 Rayleigh 信道对象 ======
        rayleighchan = comm.RayleighChannel( ...
            SampleRate           = txRF.SampleRate, ...
            PathDelays           = pathDelays, ...
            AveragePathGains     = pathGains_dB, ...
            DopplerSpectrum      = doppler("Jakes"), ...
            MaximumDopplerShift  = 5, ...                 % Hz (低速移动或静止)
            NormalizePathGains   = true, ...
            RandomStream         = "mt19937ar with seed", ...
            Seed                 = seed);
    end

    % ====== 通过 Rayleigh 信道滤波 ======
    y_channel = rayleighchan(x);

    % ====== 加 AWGN 噪声 ======
    % 使用 'measured' 选项：以 y_channel 实际功率为参考加噪
    y = awgn(y_channel, snr, 'measured');

end
