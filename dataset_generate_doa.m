%% AMC/SEI/DOA 三任务联合数据集生成脚本
% 信号链路:
% 调制基带 -> 发射机射频损伤 -> 瑞利衰落信道
% -> UCA 阵列导向投影 -> 各阵元独立 AWGN -> 接收机射频损伤
%
% 输出字段固定为:
%   batch_data     : [B_total, 8, 2, target_len]
%   label_mod      : [B_total, 1]
%   label_emitter  : [B_total, 1]
%   label_doa      : [B_total, 1]，0-based 分类标签
%   label_doa_deg  : [B_total, 1]，真实角度值
%   label_snr      : [B_total, 1]
close all; clear; clc;

addpath(genpath(pwd));

dataset_filename = 'data/sei_mod_snr_doa_uca_rayleigh_compare.mat';
num_emitters = 10;
snr_values = -20:4:32;
target_len = 128;

% 滑窗裁剪参数:
% 每条长信号先生成，再用固定窗口从中截取多个训练样本。
stride = 96;
start_offset = 100;

mod_list = {'4ASK','BPSK','QPSK','8PSK','16PSK','16QAM', ...
    '64QAM','128QAM','2FSK','4FSK','8FSK','GMSK'};
oversample = 8;
rolloff = 0.3;

num_antennas = 8;
doa_grid_deg = -90:90;
doa_repeats_per_angle = 10;
% 每个 (emitter, modulation, snr) 条件下，
% 每个角度重复 doa_repeats_per_angle 次，因此总样本数固定。
frames_per_condition = numel(doa_grid_deg) * doa_repeats_per_angle;

% 为了保证可以截出足够多的滑窗，需要先反推整条基带信号的最小长度。
total_samples_needed = start_offset + (frames_per_condition - 1) * stride + target_len;
nSymbols = ceil(total_samples_needed / oversample) + 20;

% 总样本数 = 发射机类别数 × 调制类别数 × SNR 档位数 × 每条件样本数
B_total = num_emitters * numel(mod_list) * numel(snr_values) * frames_per_condition;

outdir = fileparts(dataset_filename);
if ~isempty(outdir) && ~exist(outdir, 'dir')
    mkdir(outdir);
end

if exist(dataset_filename, 'file')
    delete(dataset_filename);
end

dataFile = matfile(dataset_filename, 'Writable', true);

% 先在 mat 文件中预分配固定字段，避免循环中不断扩容。
dataFile.batch_data(B_total, num_antennas, 2, target_len) = single(0);
dataFile.label_mod(B_total, 1) = int32(0);
dataFile.label_emitter(B_total, 1) = int32(0);
dataFile.label_doa(B_total, 1) = int32(0);
dataFile.label_doa_deg(B_total, 1) = single(0);
dataFile.label_snr(B_total, 1) = single(0);

fprintf('=== Start generating AMC/SEI/DOA dataset ===\n');
fprintf('Emitters: %d | Modulations: %d | SNRs: %d | Samples/condition: %d\n', ...
    num_emitters, numel(mod_list), numel(snr_values), frames_per_condition);
fprintf('Total samples: %d\n', B_total);

write_ptr = 1;

for e_idx = 1:num_emitters
    % 每个 emitterX.m 定义一种发射机硬件指纹参数。
    emitter_func_name = sprintf('emitter%d', e_idx);
    emitter_func = str2func(emitter_func_name);
    txRF = emitter_func();

    % 同一个发射机载频固定，因此对应的 UCA 导向矢量表也可复用。
    steering_table = build_uca_steering_table(num_antennas, txRF.CarrierFreq, doa_grid_deg);

    fprintf('Processing %s ...\n', emitter_func_name);

    for mod_idx = 1:numel(mod_list)
        modName = mod_list{mod_idx};
        fprintf('  Modulation: %s ...\n', modName);

        for snr_idx = 1:numel(snr_values)
            snr = snr_values(snr_idx);
            current_seed = e_idx * 1e7 + (snr + 50) * 1e4 + mod_idx * 1e2;

            fprintf('    SNR: %d dB ...\n', snr);

            symbols = generate_symbols(modName, nSymbols, current_seed);

            % 线性调制需要上采样和脉冲成形；FSK/GMSK 直接使用各自调制输出。
            if ~ismember(modName, {'GMSK', '2FSK', '4FSK', '8FSK'})
                [tx_ideal, ~] = upsample_and_shape(symbols, oversample, rolloff);
            else
                tx_ideal = symbols;
            end

            % 先完成单通道链路: TX 损伤 + 瑞利衰落。
            tx_signal = tx_impairments_v2(tx_ideal, txRF);
            ch_signal = rayleigh_channel_compare(tx_signal, txRF, current_seed);

            % 将 181 个角度各重复 10 次后打乱，保证每个条件内角度分布均衡。
            doa_sequence_deg = build_doa_sequence(doa_grid_deg, doa_repeats_per_angle, current_seed);
            condition_data = zeros(frames_per_condition, num_antennas, 2, target_len, 'single');
            condition_label_mod = repmat(int32(mod_idx - 1), frames_per_condition, 1);
            condition_label_emitter = repmat(int32(e_idx - 1), frames_per_condition, 1);
            condition_label_doa = int32(doa_sequence_deg(:) + 90);
            condition_label_doa_deg = single(doa_sequence_deg(:));
            condition_label_snr = repmat(single(snr), frames_per_condition, 1);

            % 单独给阵元噪声使用一个随机流，避免和 RX 损伤参数采样相互耦合。
            noise_stream = RandStream('mt19937ar', 'Seed', current_seed + 500001);
            rng(current_seed + 7919, 'twister');
            % 同一个条件内复用同一组 RX 硬件参数，模拟固定接收机。
            rxCfg = [];

            for k = 1:frames_per_condition
                % 从长信号中按固定步长裁出一个时间片段。
                start_idx = start_offset + (k - 1) * stride;
                end_idx = start_idx + target_len - 1;

                if end_idx > length(ch_signal)
                    error('Signal length is insufficient: need %d samples, got %d.', end_idx, length(ch_signal));
                end

                signal_segment = ch_signal(start_idx:end_idx);
                doa_label_idx = double(condition_label_doa(k)) + 1;
                steering_vec = steering_table(:, doa_label_idx).';

                % 先由单通道信号与导向矢量生成理想阵列接收信号。
                array_segment = signal_segment(:) * steering_vec;

                % 再对每个阵元按相同 SNR 独立加噪，保证噪声彼此独立。
                % 这里按列计算功率，因此 8 个阵元的目标 SNR 一致，
                % 但具体噪声样本互不相同。
                signal_power_per_ant = mean(abs(array_segment).^2, 1);
                valid_ant_mask = signal_power_per_ant > 0;
                if any(valid_ant_mask)
                    noise_power_per_ant = signal_power_per_ant(valid_ant_mask) ./ (10^(snr / 10));
                    noise_sigma_per_ant = sqrt(noise_power_per_ant / 2);
                    noise = zeros(size(array_segment), 'like', array_segment);
                    raw_noise = randn(noise_stream, size(array_segment)) + ...
                        1j * randn(noise_stream, size(array_segment));
                    noise(:, valid_ant_mask) = raw_noise(:, valid_ant_mask) .* noise_sigma_per_ant;
                    array_segment = array_segment + noise;
                end

                % 阵列版 RX 损伤会保持共享 CFO/初相位，从而不破坏空间相干性。
                [array_segment, rxCfg] = rx_impairments_v2(array_segment, txRF, rxCfg, start_idx);

                % 归一化必须对整个时空块统一进行，不能逐阵元单独归一化。
                norm_val = sqrt(sum(abs(array_segment(:)).^2));
                if norm_val > 0
                    array_segment = array_segment / norm_val;
                end

                % 输出格式固定为 [样本, 阵元, I/Q, 时间]。
                condition_data(k, :, 1, :) = reshape( ...
                    single(real(array_segment.')), [1, num_antennas, 1, target_len]);
                condition_data(k, :, 2, :) = reshape( ...
                    single(imag(array_segment.')), [1, num_antennas, 1, target_len]);
            end

            % 每个条件写入 MAT 文件中的连续区间，方便后续顺序读取。
            write_range = write_ptr:(write_ptr + frames_per_condition - 1);
            dataFile.batch_data(write_range, :, :, :) = condition_data;
            dataFile.label_mod(write_range, 1) = condition_label_mod;
            dataFile.label_emitter(write_range, 1) = condition_label_emitter;
            dataFile.label_doa(write_range, 1) = condition_label_doa;
            dataFile.label_doa_deg(write_range, 1) = condition_label_doa_deg;
            dataFile.label_snr(write_range, 1) = condition_label_snr;

            write_ptr = write_ptr + frames_per_condition;
        end
    end
end

fprintf('Generation complete: %s\n', dataset_filename);


function symbols = generate_symbols(modName, nSymbols, current_seed)
% 根据调制类型分派到对应的调制函数，输出一整条长基带符号流。
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
            error('Unsupported modulation type: %s', modName);
    end
end


function doa_sequence_deg = build_doa_sequence(doa_grid_deg, doa_repeats_per_angle, seed)
% 将所有角度均匀重复后打乱，得到当前条件下的 DOA 标签顺序。
    doa_sequence_deg = repmat(doa_grid_deg, 1, doa_repeats_per_angle);
    doa_stream = RandStream('mt19937ar', 'Seed', seed);
    perm_idx = randperm(doa_stream, numel(doa_sequence_deg));
    doa_sequence_deg = doa_sequence_deg(perm_idx);
end
