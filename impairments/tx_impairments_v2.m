function y = tx_impairments_v2(x, txRF)
%TX_IMPAIRMENTS_NEW  发射机射频损伤建模
%
%   损伤施加顺序:
%     输入基带信号 → IQ失衡 → DC偏移 → 相位噪声 → PA非线性(Saleh) → 输出
%
%   输入:
%       x    : 理想基带信号（复数向量）
%       txRF : 损伤参数结构体，需包含:
%              txRF.SampleRate
%              txRF.IQ.GainImb_dB / txRF.IQ.PhaseImb_deg
%              txRF.PA.AMAMParameters / txRF.PA.AMPMParameters
%              可选: txRF.DC.Offset_dB, txRF.PhaseNoise.*

    % [1] IQ 失衡
    y = iqimbal(x, txRF.IQ.GainImb_dB, txRF.IQ.PhaseImb_deg);

    % [2] DC 偏移
    if isfield(txRF, 'DC') && isfield(txRF.DC, 'Offset_dB')
        offset = 10^(txRF.DC.Offset_dB / 10) * exp(1j * 2*pi*rand());
        y = y + offset;
    end

    % [3] 相位噪声
    if isfield(txRF, 'PhaseNoise') && isfield(txRF.PhaseNoise, 'Level')
        pn = comm.PhaseNoise( ...
            'Level', [-80 -100], ...
            'FrequencyOffset', [100 500], ...
            'SampleRate', txRF.SampleRate);
        y = pn(y);
    end

    % [4] PA 非线性 (Saleh model)
    pa = comm.MemorylessNonlinearity( ...
        'Method', "Saleh model", ...
        'AMAMParameters', txRF.PA.AMAMParameters, ...
        'AMPMParameters', txRF.PA.AMPMParameters);
    y = pa(y);

end
