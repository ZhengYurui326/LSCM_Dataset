function txRF = emitter8()
%TX1_PARAMS  Example TX RF impairment parameters (Saleh PA + IQ imbalance)
%
%   txRF = se1()
%
%   返回一个包含 PA 非线性和 IQ 不平衡参数的结构体 txRF，
%   可直接用于 applyTxRFImpairments_PA_IQ 函数。

    txRF = emitter_base();

    % ======== PA 非线性参数（Saleh model） ========
    % 使用 Saleh TWTA 模型的典型参数（MATLAB 文档默认值）：
    %   AM/AM: A_out = (α_a * A_in) / (1 + β_a * A_in^2)
    %   AM/PM: φ = (α_φ * A_in^2) / (1 + β_φ * A_in^2)
    txRF.PA.Method         = "Saleh model";
    txRF.PA.AMAMParameters = [6.6492 3.8832];   % [α_a β_a]
    txRF.PA.AMPMParameters = [7.4528 5.5296];   % [α_φ β_φ]

    % ======== IQ 不平衡参数 ========
    txRF.IQ.GainImb_dB   = 0.82;   % 幅度不平衡（dB）
    txRF.IQ.PhaseImb_deg = 9.64;   % 相位不平衡（degree）

    % ======== DC 偏移（LO 泄漏）========
    txRF.DC.Offset_dB = -35;   % 低端设备，LO 隔离度较差
end
