% OFDM 信号生成脚本 (不含导频)
% 本脚本演示如何调用 modulation/ofdm_modulate.m 生成 OFDM 时域信号。
% 通过设置不同的 "modType" 变量，可切换所有数据子载波的调制方式。
% 若后续需要更灵活的 "每子载波自定义调制"，可在此脚本中分段调用
% ofdm_modulate 并对 dataGrid 进行拼接，或在 modulation/ofdm_modulate.m
% 中扩充相应功能。
close all;
clear; clc;

% ---------- 参数设置 ----------
% 待选调制方式：'BPSK' | 'QPSK' | '8PSK' | '16QAM' | '64QAM' | '4ASK'
modType    = 'BPSK';                        % 可根据需要修改
fftLength  = 64;                            % 子载波总数/FFT 长度
cyclicPrefixLength = fftLength / 4;         % 循环前缀长度（通常为 FFT 长度的 1/4）
nSymbols   = 100;                             % 每帧 OFDM 符号数
oversample = 2;                             % 过采样因子
seed       = 1;                             % 例如设为 12345 以获得可重复结果

snr        = 20;                            % 信噪比 (dB)

txRF = se1();

% ---------- 生成 OFDM ----------
[ofdmsignal, ofdmModulator, dataGrid, numDataSubcarriers] = ...
    ofdm_modulate(fftLength, cyclicPrefixLength, nSymbols, modType, oversample, seed);



tx_signal = tx_impairments(ofdmsignal, txRF);

channel_signal = rician_channel(tx_signal, txRF, seed, snr);

rx_signal = rx_impairments(channel_signal, txRF);




% ---------- 结果查看 ----------
% 1. 输出基本信息
fprintf('生成完成！数据子载波数: %d\n', numDataSubcarriers);

% 2. 绘制 OFDM 时域信号幅度谱 (可选)
figure; plot(abs(ofdmsignal));
xlabel('样本索引'); ylabel('幅度'); grid on;
title(sprintf('OFDM 时域信号幅度 (调制: %s)', modType));

% ---------- OFDM解调并绘制星座 ----------
ofdmDemod_rx = comm.OFDMDemodulator(ofdmModulator);
rxGrid = ofdmDemod_rx(rx_signal);
release(ofdmDemod_rx);

ofdmDemod_clean = comm.OFDMDemodulator(ofdmModulator);
idealGrid = ofdmDemod_clean(ofdmsignal);
release(ofdmDemod_clean);

scIdx = max(1, ceil(numDataSubcarriers/2));
figure; scatterplot(rxGrid(scIdx, :));
title(sprintf('子载波 %d 经过信道/损伤后的星座', scIdx)); grid on;

figure; scatterplot(idealGrid(scIdx, :));
title(sprintf('子载波 %d 理想星座', scIdx)); grid on;



