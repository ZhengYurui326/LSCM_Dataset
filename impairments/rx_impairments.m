function [y, fOffset, initial_phase_deg] = rx_impairments(x, txRF)
%RX_IMPAIRMENTS  Apply CFO + PhaseOffset + PhaseNoise to received signal
%
%   y = rx_impairments(x, txRF)
%
%   输入：
%       x    : 输入基带信号
%       txRF : 包含 SampleRate 和 CarrierFreq（但 CFO 范围不再使用）
%
%   输出：
%       y    : 经 CFO + 初相位 + 相位噪声后的信号

    fOffset = 100 + (500 - 100) * rand();   % Hz（均匀分布）

    initial_phase_deg = 360 * rand();

    pf_offset = comm.PhaseFrequencyOffset( ...
        SampleRate      = txRF.SampleRate,   ...
        FrequencyOffset = fOffset,           ...
        PhaseOffset     = initial_phase_deg);        % 单位是度


    y = pf_offset(x);

    
end