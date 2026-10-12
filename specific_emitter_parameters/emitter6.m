function txRF = emitter6()
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
    txRF.PA.AMAMParameters = [1.2000 0.3700];   % [α_a β_a]
    txRF.PA.AMPMParameters = [0.3844 0.3797];   % [α_φ β_φ]

    % ======== IQ 不平衡参数 ========
    txRF.IQ.GainImb_dB   = -0.88;   % 幅度不平衡（dB）
    txRF.IQ.PhaseImb_deg = -9.57;   % 相位不平衡（degree）

    % ======== DC 偏移（LO 泄漏）========
    txRF.DC.Offset_dB = -42;   % 存在老化的 LO 泄漏
end
