%% 初始化环境
close all; clear; clc;

% 添加必要的子目录到搜索路径
addpath(genpath(pwd));  % 递归添加当前目录及其所有子目录

% 检查并启动并行池（用于并行计算4个信道模型）
if isempty(gcp('nocreate'))
    parpool('local', 16);  % 根据CPU核心数调整worker数量
end

% --- 1. 参数配置 ---
dataset_filename = 'data/sei_mod_snr_raw_sample8mhz_4channels.mat'; % 暂存为MAT文件（-v7.3 支持大数据）
num_emitters = 10;                         % 发射机数量（emitter1 ~ emitter8）
snr_values = -16:4:32;                    % SNR 范围（步长 2dB）
frames_per_condition = 3200;              % 每个(发射机, 调制, SNR)下的样本数（4个信道×1500样本）
target_len = 512;                        % 目标信号长度 (IQ点数)

% 调制与信号参数（保持与 emitter_only_dataset.m 一致的链路）
mod_list = {'4ASK','BPSK','QPSK','8PSK','16PSK','16QAM','64QAM','2ASK','4FSK','GMSK'}; % 需要遍历的调制类型
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
            % 配置信道模型列表
            channel_models = {@rician_channel_1, @rician_channel_2, ...
                              @rayleigh_channel_1, @rayleigh_channel_2};
            samples_per_channel = frames_per_condition / 4;  % 每个信道模型生成800条信号

            fprintf('    SNR: %d dB ...\n', snr);

            % 为了利用多核加速，使用 parfor 并行处理4个信道模型
            % 使用 cell 数组收集每个信道的数据（避免 parfor 变量分类问题）
            channel_data = cell(1, 4);

            % 外层循环：遍历4个信道模型（并行执行）
            parfor ch_idx = 1:4
                channel_func = channel_models{ch_idx};

                % 每个信道生成自己的数据块
                channel_batch = zeros(samples_per_channel, 2, target_len, 'single');

                % 内层循环：对每个信道模型生成信号
                for k = 1:samples_per_channel
                    % 初始化符号变量（确保在所有使用前已定义）
                    symbols = [];

                    % --- A. 生成随机种子 ---
                    % 保证每帧数据的调制符号和信道噪声都不一样
                    % 种子逻辑: 发射机ID * 1e7 + (SNR偏移) * 1e4 + 调制ID * 1e2 + 信道ID * 1e0 + 帧ID
                    current_seed = e_idx * 1e7 + (snr + 50) * 1e4 + mod_idx * 1e2 + ch_idx * 1e0 + k;

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
                        case '16PSK'
                            symbols = apsk_modulate(16, nSymbols, current_seed);
                        case '16QAM'
                            symbols = qam_modulate(16, nSymbols, current_seed);
                        case '64QAM'
                            symbols = qam_modulate(64, nSymbols, current_seed);
                        case '2ASK'
                            symbols = ask_modulate(2, nSymbols, current_seed);
                        case '4FSK'
                            symbols = fsk_modulate(4, nSymbols, current_seed);
                        case 'GMSK'
                            symbols = gmsk_modulate(nSymbols, current_seed);
                        otherwise
                            error('不支持的调制类型: %s', modName);
                    end

                    % --- C. 上采样与成型滤波 ---
                    % GMSK和4FSK已在调制函数内部完成过采样，跳过此步骤
                    if ~ismember(modName, {'GMSK', '4FSK'})
                        [tx_ideal, ~] = upsample_and_shape(symbols, oversample, rolloff);
                    else
                        % 对于GMSK和4FSK，直接使用调制输出（已过采样）
                        tx_ideal = symbols;
                    end

                    % --- D. 发射机射频损伤 ---
                    tx_signal = tx_impairments(tx_ideal, txRF);

                    % --- E. 通过信道 (调用当前信道模型) ---
                    ch_signal = channel_func(tx_signal, txRF, current_seed, snr);

                    % --- F. 接收机损伤 ---
                    rx_signal_full = rx_impairments(ch_signal, txRF);

                    % --- G. 数据切片与格式化 ---
                    % rx_signal_full 长度 = nSymbols * oversample + 滤波器延迟
                    % 我们只需要中间稳定的 512 个点
                    % 简单切片策略：跳过前 64 个点 (约8个符号) 避开滤波器瞬态
                    start_idx = 129;
                    end_idx = start_idx + target_len - 1;
                    signal_segment = rx_signal_full(start_idx:end_idx);

                    % 幅度归一化（避免不同条件下量纲差异）
                    energy = sum(abs(signal_segment));
                    if energy > 0
                        signal_segment = signal_segment / energy;
                    end

                    % 存入当前信道的数据块
                    channel_batch(k, 1, :) = real(signal_segment);
                    channel_batch(k, 2, :) = imag(signal_segment);
                end

                % 将当前信道的数据存入 cell 数组
                channel_data{ch_idx} = channel_batch;
            end

            % 在 parfor 外合并所有信道的数据
            batch_data = zeros(frames_per_condition, 2, target_len, 'single');
            for ch_idx = 1:4
                idx_start = (ch_idx - 1) * samples_per_channel + 1;
                idx_end = ch_idx * samples_per_channel;
                batch_data(idx_start:idx_end, :, :) = channel_data{ch_idx};
            end
            clear channel_data;

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
