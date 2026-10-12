function y = tx_impairments(x, txRF)
%APPLYTXRFIMPAIRMENTS_PA_IQ  Apply PA (Saleh model) nonlinearity and IQ imbalance
%
%   y = applyTxRFImpairments_PA_IQ(x, txRF)
%
%   输入：
%       x    : 理想基带信号（复数，列向量或矩阵，每列一个通道）
%       txRF : 发射机射频损伤参数结构体
%              必须包含：
%              txRF.PA.Method          - 必须为 "Saleh model"
%              txRF.PA.AMAMParameters  - 1×2 向量 [α_a β_a]
%              txRF.PA.AMPMParameters  - 1×2 向量 [α_φ β_φ]
%              txRF.IQ.GainImb_dB      - IQ 幅度不平衡（dB）
%              txRF.IQ.PhaseImb_deg    - IQ 相位不平衡（degree）
%
%   输出：
%       y    : 经过 PA 非线性 + IQ 不平衡后的信号

    
    iq = txRF.IQ;
    pa = txRF.PA;

    A  = iq.GainImb_dB;     % 幅度不平衡 dB
    P  = iq.PhaseImb_deg;   % 相位不平衡 degree

    mnl = comm.MemorylessNonlinearity( ...
        Method         = pa.Method,           ... % "Saleh model"
        AMAMParameters = pa.AMAMParameters,   ...
        AMPMParameters = pa.AMPMParameters);      % 使用给定的 Saleh 参数

    % -------- IQ 不平衡（iqimbal） ----------
    x_iq = iqimbal(x, A, P);

    % -------- PA 非线性（Saleh model） ----------
    y = mnl(x_iq);   % 通过 PA






end







