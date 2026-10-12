function [y, rxCfg] = rx_impairments_v2(x, txRF, rxCfg, sampleStartIdx)
%RX_IMPAIRMENTS_V2  阵列感知接收机射频损伤建模.
%   施加顺序: 逐天线 LNA 非线性 -> 逐天线 IQ 失衡 -> 共享 CFO/初相旋转.
%
%   关键设计: CFO 频偏和初相对所有天线施加相同旋转, 保持阵列流形的空间相干性,
%   确保 DOA 信息不被破坏.
%
%   输入:
%       x              : [N, M] 复矩阵, 每列对应一根天线
%       txRF.SampleRate: 采样率 (Hz)
%       rxCfg          : 空则随机采样一组 RX 硬件参数, 非空则复用 (模拟固定接收机)
%       sampleStartIdx : x(1,:) 在长信号中的 1-based 绝对采样索引 (用于 CFO 相位累积)
%
%   输出:
%       y     : 损伤后复阵列信号 [N, M]
%       rxCfg : RX 硬件参数配置 (含 LNA/IQ/CFO)

    if isvector(x)
        x = x(:);
    end

    % 首次调用或显式传入空时, 随机采样一组 RX 硬件参数.
    if nargin < 3 || isempty(rxCfg)
        rxCfg = sample_rx_cfg(size(x, 2));
    end

    % 未指定绝对采样索引时默认从 1 开始 (兼容单帧独立调用场景).
    if nargin < 4 || isempty(sampleStartIdx)
        sampleStartIdx = 1;
    end

    [num_samples, num_antennas] = size(x);

    if rxCfg.NumAntennas ~= num_antennas
        error('rxCfg.NumAntennas (%d) does not match input antenna count (%d).', ...
            rxCfg.NumAntennas, num_antennas);
    end

    % LNA System objects 惰性构造: 只在 rxCfg 首次创建时生成.
    if ~isfield(rxCfg, 'LNAObjects') || numel(rxCfg.LNAObjects) ~= num_antennas
        rxCfg.LNAObjects = build_lna_objects(rxCfg);
    end

    y = zeros(num_samples, num_antennas, 'like', x);

    % 阶段 1+2: 逐天线独立 LNA 非线性 + IQ 失衡.
    % 各天线硬件参数独立随机, 模拟多通道间硬件差异.
    for ant_idx = 1:num_antennas
        ant_signal = rxCfg.LNAObjects{ant_idx}(x(:, ant_idx));
        ant_signal = iqimbal(ant_signal, ...
            rxCfg.IQ.GainImb_dB(ant_idx), ...
            rxCfg.IQ.PhaseImb_deg(ant_idx));
        y(:, ant_idx) = ant_signal;
    end

    % 阶段 3: 共享 CFO 频偏 + 初相旋转.
    % 使用绝对采样索引计算相位, 保证滑窗截取时 CFO 相位在帧间连续.
    absolute_sample_idx = (sampleStartIdx - 1) + (0:num_samples-1).';
    phase_rad = deg2rad(rxCfg.CFO.InitialPhaseDeg) + ...
        2 * pi * rxCfg.CFO.FrequencyOffset / txRF.SampleRate * absolute_sample_idx;
    shared_rotation = exp(1j * phase_rad);
    y = bsxfun(@times, y, shared_rotation);
end


function rxCfg = sample_rx_cfg(num_antennas)
% 随机采样一组 RX 硬件损伤参数, 各天线参数独立以模拟多通道硬件差异.
%
%   损伤参数范围:
%     LNA (Saleh模型): 基础 AM/AM 参数 [1.0~1.3, 0.05~0.20]
%                      基础 AM/PM 参数 [0.1~0.3, 0.1~0.3]
%                      各天线在基础值上乘以 ±2% 的随机缩放因子
%     IQ 失衡:        GainImb_dB   [-0.1, +0.1] dB
%                      PhaseImb_deg [-0.2, +0.2] 度
%     CFO:             频偏 [100, 500] Hz
%                      初相 [0, 360) 度

    % 基础 Saleh LNA 参数: [α_a, β_a], [α_φ, β_φ].
    base_amam = [1.0 + 0.3 * rand(), 0.05 + 0.15 * rand()];
    base_ampm = [0.1 + 0.2 * rand(), 0.1 + 0.2 * rand()];

    % 每根天线在基础参数上施加 ±2% 的扰动, 模拟通道间增益差异.
    lna_scale = 1 + 0.02 * (2 * rand(num_antennas, 2) - 1);
    amam = max(eps, base_amam .* lna_scale);
    ampm = max(eps, base_ampm .* lna_scale);

    rxCfg = struct();
    rxCfg.NumAntennas = num_antennas;
    rxCfg.LNA = struct( ...
        'BaseAMAMParameters', base_amam, ...
        'BaseAMPMParameters', base_ampm, ...
        'AMAMParameters', amam, ...
        'AMPMParameters', ampm);
    rxCfg.IQ = struct( ...
        'GainImb_dB',   -0.1 + 0.2 * rand(num_antennas, 1), ...
        'PhaseImb_deg',  -0.2 + 0.4 * rand(num_antennas, 1));
    rxCfg.CFO = struct( ...
        'FrequencyOffset',  100 + 400 * rand(), ...
        'InitialPhaseDeg',  360 * rand());
    rxCfg.LNAObjects = {};   % 惰性构造, 首次调用时由 build_lna_objects 填充.
end


function lna_objects = build_lna_objects(rxCfg)
% 为每根天线构造 Saleh LNA 非线性 System object.
%   使用 comm.MemorylessNonlinearity 的 Saleh model,
%   各天线使用独立的 AM/AM 和 AM/PM 参数, 模拟多通道硬件差异.
%   这些 System object 可被反复 step() 调用, 处理不同帧的信号.
    num_antennas = rxCfg.NumAntennas;
    lna_objects = cell(1, num_antennas);

    for ant_idx = 1:num_antennas
        lna_objects{ant_idx} = comm.MemorylessNonlinearity( ...
            'Method', "Saleh model", ...
            'AMAMParameters', rxCfg.LNA.AMAMParameters(ant_idx, :), ...
            'AMPMParameters', rxCfg.LNA.AMPMParameters(ant_idx, :));
    end
end
