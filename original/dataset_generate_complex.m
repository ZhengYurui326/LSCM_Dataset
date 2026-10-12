%% 初始化环境
close all; clear; clc;

% 添加必要的子目录到搜索路径
addpath(genpath(pwd));  % 递归添加当前目录及其所有子目录

% 检查并启动并行池
if isempty(gcp('nocreate'))
    parpool('local', 16);  % 根据CPU核心数调整worker数量
end

% --- 1. 参数配置 ---
dataset_filename = 'data/sei_mod_snr_raw_sample8mhz.mat'; % 暂存为MAT文件（-v7.3 支持大数据）
num_emitters = 10;                         % 发射机数量（emitter1 ~ emitter10）
snr_values = -16:4:32;                    % SNR 范围（步长 4dB）
frames_per_condition = 2000;              % 每个(发射机, 调制, SNR)下的样本数
target_len = 128;                         % 目标信号长度 (IQ点数)

% 滑动窗口参数
stride = 96;                              % 窗口滑动步长
start_offset = 100;                        % 第一个窗口的起始位置

% 调制与信号参数（保持与 emitter_only_dataset.m 一致的链路）
mod_list = {'4ASK','BPSK','QPSK','8PSK','16PSK','16QAM','64QAM','128QAM','2FSK','4FSK','8FSK','GMSK'}; % 需要遍历的调制类型
oversample = 8;
rolloff = 0.3;
% 计算所需总样本数: start_offset + (frames-1)*stride + target_len
% = 100 + 1999*96 + 128 = 192132
% nSymbols 需要最大化以生成足够长的信号
total_samples_needed = start_offset + (frames_per_condition - 1) * stride + target_len;
nSymbols = ceil(total_samples_needed / oversample) + 20;  % +20 margin for filter transients

% 创建数据容器 (Struct)
% 结构示例: data_struct.emitter1_mod_QPSK_snr_10 = [1000, 2, 1024]
outdir = fileparts(dataset_filename);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

% 创建 matfile 对象用于高效写入（避免 save -append 的性能瓶颈）
if ~exist(dataset_filename, 'file')
    % 创建空的 MAT 文件（-v7.3 格式支持大于2GB的文件）
    save(dataset_filename, '-v7.3');
end
dataFile = matfile(dataset_filename, 'Writable', true);

fprintf('=== 开始生成多调制数据集 ===\n');
fprintf('发射机: %d 个 | 调制: %d 种 | SNR范围: %d~%d dB | 每组样本: %d\n', ...
    num_emitters, numel(mod_list), min(snr_values), max(snr_values), frames_per_condition);

%% --- 2. 三层循环遍历 (发射机 -> 调制 -> SNR) ---
for e_idx = 1:num_emitters
    % 2.1 动态调用发射机参数函数 (emitter1 ~ emitter10)
    emitter_func_name = sprintf('emitter%d', e_idx);
    emitter_func = str2func(emitter_func_name);
    txRF = emitter_func(); % 获取当前发射机的硬件参数

    fprintf('正在处理: %s ...\n', emitter_func_name);

    for mod_idx = 1:numel(mod_list)
        modName = mod_list{mod_idx};
        fprintf('  调制: %s ...\n', modName);

        for snr = snr_values
            fprintf('    SNR: %d dB ...\n', snr);

            % 为该条件生成唯一的种子
            current_seed = e_idx * 1e7 + (snr + 50) * 1e4 + mod_idx * 1e2;

            % --- A. 生成长基带符号序列 ---
            switch modName
                case '4ASK'
                    symbols = ask_modulate(4, nSymbols, current_seed);
                case 'BPSK'
                    symbols = psk_modulate(2, nSymbols, current_seed);
                case 'QPSK'
                    symbols = psk_modulate(4, nSymbols, current_seed);
                case '8PSK'
                    symbols = psk_modulate(8, nSymbols, current_seed);
                case '16PSK'
                    symbols = apsk_modulate(16, nSymbols, current_seed);
                case '16QAM'
                    symbols = qam_modulate(16, nSymbols, current_seed);
                case '64QAM'
                    symbols = qam_modulate(64, nSymbols, current_seed);
                case '128QAM'
                    symbols = qam_modulate(128, nSymbols, current_seed);
                case '2FSK'
                    symbols = fsk_modulate(2, nSymbols, current_seed);
                case '4FSK'
                    symbols = fsk_modulate(4, nSymbols, current_seed);
                case '8FSK'
                    symbols = fsk_modulate(8, nSymbols, current_seed);
                case 'GMSK'
                    symbols = gmsk_modulate(nSymbols, current_seed);
                otherwise
                    error('不支持的调制类型: %s', modName);
            end

            % --- B. 上采样与脉冲成形 ---
            if ~ismember(modName, {'GMSK', '4FSK', '8FSK'})
                [tx_ideal, ~] = upsample_and_shape(symbols, oversample, rolloff);
            else
                tx_ideal = symbols;
            end

            % --- C. 发射机射频损伤 ---
            tx_signal = tx_impairments_v2(tx_ideal, txRF);

            % --- D. 通过信道 ---
            ch_signal = rayleigh_channel_1(tx_signal, txRF, current_seed, snr);

            % --- E. 接收机损伤 ---
            rx_signal_full = rx_impairments_v2(ch_signal, txRF);

            % --- F. 滑动窗口截取 ---
            temp_data = zeros(frames_per_condition, target_len);
            for k = 1:frames_per_condition
                start_idx = start_offset + (k - 1) * stride;
                end_idx = start_idx + target_len - 1;

                if end_idx > length(rx_signal_full)
                    error('信号长度不足: 需要 %d 点, 实际 %d 点', end_idx, length(rx_signal_full));
                end

                signal_segment = rx_signal_full(start_idx:end_idx);

                energy = sum(abs(signal_segment));
                if energy > 0
                    signal_segment = signal_segment / energy;
                end

                temp_data(k, :) = signal_segment;
            end

            batch_data = zeros(frames_per_condition, 2, target_len, 'single');
            batch_data(:, 1, :) = real(temp_data);
            batch_data(:, 2, :) = imag(temp_data);

            % 2.3 生成结构体字段名 (Key)
            % MATLAB 字段名不能有负号，用字符串替换处理: -20 -> minus20
            if snr < 0
                field_name = sprintf('%s_mod_%s_snr_minus%d', emitter_func_name, modName, abs(snr));
            else
                field_name = sprintf('%s_mod_%s_snr_%d', emitter_func_name, modName, snr);
            end

            % 使用 matfile 对象直接写入（高效，避免 save -append 的性能瓶颈）
            dataFile.(field_name) = batch_data;
            clear batch_data;
        end
    end
end

%% --- 3. 保存数据 ---
fprintf('生成完成: %s\n', dataset_filename);
