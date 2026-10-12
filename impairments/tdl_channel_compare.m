function y = tdl_channel_compare(x, txRF, seed, varargin)
%TDL_CHANNEL_COMPARE 使用 MATLAB nrTDLChannel 的单载波 TDL 信道。
%
%   y = tdl_channel_compare(x, txRF, seed)
%   y = tdl_channel_compare(x, txRF, seed, snr)
%
%   输入：
%       x    : 单载波复基带信号（SISO 向量）
%       txRF : 参数结构体，至少包含 txRF.SampleRate
%       seed : 随机种子
%
%   输出：
%       y    : 经过 TDL-D 衰落后的单载波时域信号（不含 AWGN）
%
%   参数设置说明：
%   1. 使用 3GPP TDL-D 内置时延剖面，其包含 LOS 分量，便于和
%      rician_channel_1 进行对比；
%   2. RMS 时延扩展设为 60 ns，接近 rician_channel_1 的约 59 ns；
%   3. 目标 K 因子设为 10*log10(2) dB，对应线性 K = 2；
%   4. 最大多普勒频移、采样率、归一化方式及随机种子设置与
%      rician_channel_1 保持一致；
%   5. 第四个 snr 参数仅兼容旧调用方式，实际不在函数内加噪。

    if nargin < 3
        error('tdl_channel_compare requires at least x, txRF, and seed.');
    end

    if ~isvector(x)
        error('tdl_channel_compare expects a SISO single-carrier input vector.');
    end

    % nrTDLChannel 将向量解释为单发射天线的时域波形。
    inputWasRow = isrow(x);
    x = x(:);

    % rician_channel_1 的归一化 PDP 对应约 59 ns 的 RMS 时延扩展，
    % 此处取整为 60 ns，并采用 TDL-D 内置 LOS 时延剖面。
    tdl = nrTDLChannel( ...
        DelayProfile           = "TDL-D", ...
        DelaySpread            = 60e-9, ...
        KFactorScaling         = true, ...
        KFactor                = 10 * log10(2), ...
        MaximumDopplerShift    = 30, ...
        SampleRate             = txRF.SampleRate, ...
        NumTransmitAntennas    = 1, ...
        NumReceiveAntennas     = 1, ...
        NormalizePathGains     = true, ...
        NormalizeChannelOutputs = true, ...
        RandomStream           = "mt19937ar with seed", ...
        Seed                   = seed);

    % 直接进行时域信道滤波，适用于单载波信号；不调用 OFDM 响应接口。
    y = tdl(x);

    % 保持与输入向量相同的行/列方向，兼容现有调用方式。
    if inputWasRow
        y = y.';
    end
end
