%% 初始化环境
close all; clear; clc;

% --- 1. 参数配置 ---
dataset_filename = 'data/sei_mod_snr_raw_sample8mhz.mat'; % 暂存为MAT文件（-v7.3 支持大数据）
num_emitters = 8;                         % 发射机数量（emitter1 ~ emitter8）
snr_values = -16:4:32;                    % SNR 范围（步长 2dB）
frames_per_condition = 2000;              % 每个(发射机, 调制, SNR)下的样本数
target_len = 1024;                        % 目标信号长度 (IQ点数)

% 调制与信号参数（保持与 emitter_only_dataset.m 一致的链路）
mod_list = {'4ASK','BPSK','QPSK','8PSK','16QAM','64QAM'}; % 需要遍历的调制类型
oversample = 8;
rolloff = 0.3;
% 计算所需的符号数: 至少需要 1024/8 = 128 个符号。
% 设为 200 保证切去头尾瞬态后依然够长
nSymbols = 170;

% 创建数据容器 (Struct)
% 结构示例: data_struct.emitter1_mod_QPSK_snr_10 = [1000, 2, 1024]
outdir = fileparts(dataset_filename);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

fprintf('=== 开始生成多调制数据集 ===\n');
fprintf('发射机: %d 个 | 调制: %d 种 | SNR范围: %d~%d dB | 每组样本: %d\n', ...
    num_emitters, numel(mod_list), min(snr_values), max(snr_values), frames_per_condition);

%% --- 2. 三层循环遍历 (发射机 -> 调制 -> SNR) ---
for e_idx = 1:num_emitters
    % 2.1 动态调用发射机参数函数 (emitter1 ~ emitter8)
    emitter_func_name = sprintf('emitter%d', e_idx);
    emitter_func = str2func(emitter_func_name);
    txRF = emitter_func(); % 获取当前发射机的硬件参数

    fprintf('正在处理: %s ...\n', emitter_func_name);

    for mod_idx = 1:numel(mod_list)
        modName = mod_list{mod_idx};
        fprintf('  调制: %s ...\n', modName);

        for snr = snr_values
            % 2.2 准备数据容器 [Batch, Channel, Time] -> [1000, 2, 1024]
            % 使用 single 类型节省存储空间
            batch_data = zeros(frames_per_condition, 2, target_len, 'single');

            fprintf('    SNR: %d dB ...\n', snr);

            % 为了利用多核加速，建议使用 parfor (如果报错请改为 for)
            for k = 1:frames_per_condition
                % --- A. 生成随机种子 ---
                % 保证每帧数据的调制符号和信道噪声都不一样
                % 种子逻辑: 发射机ID * 1e7 + (SNR偏移) * 1e4 + 调制ID * 1e2 + 帧ID
                current_seed = e_idx * 1e7 + (snr + 50) * 1e4 + mod_idx * 1e2 + k;

                % --- B. 基带符号生成（按调制类型调用相应函数） ---
                switch modName
                    case '4ASK'
                        symbols = ask_modulate(4, nSymbols, current_seed);
                    case 'BPSK'
                        symbols = psk_modulate(2, nSymbols, current_seed);
                    case 'QPSK'
                        symbols = psk_modulate(4, nSymbols, current_seed);
                    case '8PSK'
                        symbols = psk_modulate(8, nSymbols, current_seed);
                    case '16QAM'
                        symbols = qam_modulate(16, nSymbols, current_seed);
                    case '64QAM'
                        symbols = qam_modulate(64, nSymbols, current_seed);
                    otherwise
                        error('不支持的调制类型: %s', modName);
                end

                % --- C. 上采样与成型滤波 ---
                [tx_ideal, ~] = upsample_and_shape(symbols, oversample, rolloff);

                % --- D. 发射机射频损伤 ---
                tx_signal = tx_impairments(tx_ideal, txRF);

                % --- E. 通过信道 (Rician + AWGN) ---
                ch_signal = rician_channel(tx_signal, txRF, current_seed, snr);

                % --- F. 接收机损伤 ---
                rx_signal_full = rx_impairments(ch_signal, txRF);

                % --- G. 数据切片与格式化 ---
                % rx_signal_full 长度 = nSymbols * oversample + 滤波器延迟
                % 我们只需要中间稳定的 1024 个点
                % 简单切片策略：跳过前 64 个点 (约8个符号) 避开滤波器瞬态
                start_idx = 129;
                end_idx = start_idx + target_len - 1;
                signal_segment = rx_signal_full(start_idx:end_idx);

                % 幅度归一化（避免不同条件下量纲差异）
                energy = sum(abs(signal_segment));
                if energy > 0
                    signal_segment = signal_segment / energy;
                end

                % 存入矩阵: 维度 (2, 1024)
                % 第一行存 I路 (Real), 第二行存 Q路 (Imag)
                batch_data(k, 1, :) = real(signal_segment);
                batch_data(k, 2, :) = imag(signal_segment);
            end

            % 2.3 生成结构体字段名 (Key)
            % MATLAB 字段名不能有负号，用字符串替换处理: -20 -> minus20
            if snr < 0
                field_name = sprintf('%s_mod_%s_snr_minus%d', emitter_func_name, modName, abs(snr));
            else
                field_name = sprintf('%s_mod_%s_snr_%d', emitter_func_name, modName, snr);
            end

            S = struct();
            S.(field_name) = batch_data;
            if exist(dataset_filename, 'file')
                save(dataset_filename, '-struct', 'S', '-append');
            else
                save(dataset_filename, '-struct', 'S', '-v7.3');
            end
            clear S batch_data;
        end
    end
end

%% --- 3. 保存数据 ---
fprintf('生成完成: %s\n', dataset_filename);
