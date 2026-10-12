function txRF = emitter9()
%EMITTER9_PARAMS  TX RF impairment parameters - 高性能参考发射机
%
%   txRF = emitter9()
%
%   特点: 极高线性度，极低IQ不平衡
%   作为数据集中的"黄金标准" (Ground Truth reference)

    txRF = emitter_base();

    % ======== PA 非线性参数（Saleh model） ========
    % 接近理想的线性放大器
    txRF.PA.Method         = "Saleh model";
    txRF.PA.AMAMParameters = [1.10 0.08];   % [α_a β_a] 极低饱和
    txRF.PA.AMPMParameters = [0.15 0.10];   % [α_φ β_φ] 几乎无相位失真

    % ======== IQ 不平衡参数 ========
    % 接近理想的IQ调制
    txRF.IQ.GainImb_dB   = -0.05;   % 极小幅度误差
    txRF.IQ.PhaseImb_deg = 0.15;    % 极小相位误差

    % ======== DC 偏移（LO 泄漏）========
    txRF.DC.Offset_dB = -55;   % 黄金标准，极低的 LO 泄漏
end