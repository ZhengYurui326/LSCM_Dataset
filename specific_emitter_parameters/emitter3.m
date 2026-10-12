function txRF = emitter3()
%EMITTER3_PARAMS  TX RF impairment parameters - 中等线性度发射机
%
%   txRF = emitter3()
%
%   特点: 
%     - 中等非线性 (介于高性能E9和典型商用E1/E2之间)
%     - 中等IQ不平衡 (填补了良好设备与故障设备之间的空白)
%     - 易于与E9区分，且不与E6/E2重叠

    txRF = emitter_base();

    % ======== PA 非线性参数（Saleh model） ========
    % 调整策略: beta_a 设为 0.65，填补了 E6(0.37) 和 E2(0.99) 的空白
    txRF.PA.Method         = "Saleh model";
    txRF.PA.AMAMParameters = [1.65 0.65];   % [α_a β_a] 中等增益压缩
    txRF.PA.AMPMParameters = [1.20 0.80];   % [α_φ β_φ] 轻微相位失真

    % ======== IQ 不平衡参数 ========
    % 调整策略: 相位误差 4.2度，显著区别于E9(<1度)和E6(>9度)
    txRF.IQ.GainImb_dB   = 0.55;    % 幅度不平衡（dB）
    txRF.IQ.PhaseImb_deg = 4.20;    % 相位不平衡（degree）

    % ======== DC 偏移（LO 泄漏）========
    txRF.DC.Offset_dB = -38;   % 中等偏上的 LO 泄漏

    % ===== 统一字段 (防止代码报错) =====
    txRF.CFO.Range_ppm   = [0 0];
    txRF.Phase.Range_deg = [0 0];
end