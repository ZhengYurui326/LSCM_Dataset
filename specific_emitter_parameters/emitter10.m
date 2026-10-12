function txRF = emitter10()
%EMITTER10_PARAMS  TX RF impairment parameters - 严重损伤发射机
%
%   txRF = emitter10()
%
%   特点: 强非线性功率放大器，高IQ不平衡
%   应用场景: 低成本发射设备，老化严重的功放
%
%   参数说明:
%     - AM/AM参数 [8.50, 6.80]: 显著饱和效应
%     - AM/PM参数 [15.20, 18.50]: 强AM/PM转换
%     - IQ不平衡: 幅度 1.20dB, 相位 12.50°

    txRF = emitter_base();

    % ======== PA 非线性参数（Saleh model） ========
    % 显著非线性：功率放大器工作在深度饱和区
    %   AM/AM: A_out = (α_a * A_in) / (1 + β_a * A_in^2)
    %   AM/PM: φ = (α_φ * A_in^2) / (1 + β_φ * A_in^2)
    txRF.PA.Method         = "Saleh model";
    txRF.PA.AMAMParameters = [8.50 6.80];   % [α_a β_a] 显著饱和效应
    txRF.PA.AMPMParameters = [15.20 18.50]; % [α_φ β_φ] 强AM/PM转换

    % ======== IQ 不平衡参数 ========
    % 低质量或老化的IQ调制器，较大的不平衡
    txRF.IQ.GainImb_dB   = 1.20;    % 幅度不平衡（dB）
    txRF.IQ.PhaseImb_deg = 12.50;   % 相位不平衡（degree）

    % ======== DC 偏移（LO 泄漏）========
    txRF.DC.Offset_dB = -28;   % 严重劣化，最大的 LO 泄漏
end
