close all;
clear; clc;

modType    = 'BPSK';
nSymbols   = 1280;
oversample = 8;
rolloff    = 0.3;
seed       = 1;
snr        = 1000;

% 发射端参数 / 射频配置
txRF = emitter1();

%% 1. 生成已调基带符号
switch modType
    case '4ASK'
        symbols = ask_modulate(4, nSymbols, seed);
    case 'BPSK'
        symbols = psk_modulate(2, nSymbols, seed);
    case 'QPSK'
        symbols = psk_modulate(4, nSymbols, seed);
    case '8PSK'
        symbols = psk_modulate(8, nSymbols, seed);
    case '16QAM'
        symbols = qam_modulate(16, nSymbols, seed);
    case '64QAM'
        symbols = qam_modulate(64, nSymbols, seed);
    otherwise
        error('Unsupported modulation: %s', modType);
end

%% 2. 上采样 + 成形滤波（理想发射基带）
[tx_ideal, filterCoeffs] = upsample_and_shape(symbols, oversample, rolloff);

%% 3. 发射端损伤 + 信道 + 接收端损伤
tx_signal = tx_impairments(tx_ideal, txRF);
ch_signal = rician_channel(tx_signal, txRF, seed, snr);

% rx_impairments 返回接收信号 + 频偏(Hz) + 初始相位(度)
[rx_signal, fOffset, initial_phase_deg] = rx_impairments(ch_signal, txRF);

% % 简单能量归一化（避免数值太大）
% energy = sum(abs(rx_signal));   % L1 范数：幅度之和
% if energy > 0
%     rx_signal = rx_signal / energy;
% end

%% 4. 时域 I/Q 波形对比
figure;
subplot(2,2,1); plot(real(tx_ideal)); grid on; xlabel('n'); ylabel('I'); title('理想发送信号 I');
subplot(2,2,2); plot(imag(tx_ideal)); grid on; xlabel('n'); ylabel('Q'); title('理想发送信号 Q');
subplot(2,2,3); plot(real(rx_signal)); grid on; xlabel('n'); ylabel('I'); title('接收信号 I');
subplot(2,2,4); plot(imag(rx_signal)); grid on; xlabel('n'); ylabel('Q'); title('接收信号 Q');
sgtitle(sprintf('接收信号 I/Q (调制: %s)', modType));

%% 5. 匹配滤波 + 降采样，得到符号率星座（未补偿）
rx_mf  = filter(filterCoeffs, 1, rx_signal);
rx_sym = downsample(rx_mf, oversample);

%% 6. 使用 fOffset + initial\_phase\_deg 做频偏+相位补偿（sin/cos 形式）
%%% === 关键补偿代码开始 ===

% 采样率：这里假设 emitter1() 里有采样率字段，根据你工程实际修改
% 例如 txRF.Fs 或 txRF.SampleRate 等（自己对照 emitter1 的定义）

Fs = txRF.SampleRate;  % 如果是 System object


% fOffset 是 Hz，下采样前的 rx_signal 仍然是采样率 Fs
% 离散时间的角频偏(单位: rad/sample)：
omega_hat = 2*pi*fOffset / Fs;    % ω̂

% 初始相位估计：从度转换为弧度
phi0_hat = initial_phase_deg * pi/180;

% 对 rx_signal 的每一个采样点做补偿
N = length(rx_signal);
n = (0:N-1).';                    % 样点索引

% 相位轨迹: θ̂[n] = ω̂·n + φ̂0
theta_hat = omega_hat*n + phi0_hat;   % (N x 1)

% 构造补偿用单位复数 phasor: e^{-jθ̂[n]} = cos(θ̂[n]) - j sin(θ̂[n])
u_real = cos(theta_hat);              % 实部
u_imag = -sin(theta_hat);             % 虚部 (注意负号)

% 拆分接收信号 I/Q
I_rx = real(rx_signal);
Q_rx = imag(rx_signal);

% 显式 I/Q 形式做复数乘法: (I + jQ)*(u_real + j u_imag)
I_comp = I_rx .* u_real - Q_rx .* u_imag;
Q_comp = I_rx .* u_imag + Q_rx .* u_real;

rx_signal_comp = I_comp + 1j*Q_comp;  % 已补偿的接收基带信号

%%% === 关键补偿代码结束 ===

%% 7. 对补偿后的信号再做匹配滤波 + 降采样
rx_mf_comp  = filter(filterCoeffs, 1, rx_signal_comp);
rx_sym_comp = downsample(rx_mf_comp, oversample);

%% 8. 画星座：理想 / 未补偿 / 补偿后

% 理想星座（发射符号）
figure;
plot(real(symbols), imag(symbols), '.');
xlim([-2 2]);
ylim([-2 2]);
grid on; axis equal;
title(sprintf('理想星座 (%s)', modType));
xlabel('In-Phase'); ylabel('Quadrature');

% 未补偿的接收星座
figure;
plot(real(rx_sym), imag(rx_sym), '.');
xlim([-3 3]);
ylim([-3 3]);
grid on; axis equal;
title(sprintf('接收星座 (未补偿, %s)', modType));
xlabel('In-Phase'); ylabel('Quadrature');

% 补偿后的接收星座
figure;
plot(real(rx_sym_comp), imag(rx_sym_comp), '.');
xlim([-3 3]);
ylim([-3 3]);
grid on; axis equal;
title(sprintf('修正星座 (频偏+相位补偿, %s)', modType));
xlabel('In-Phase'); ylabel('Quadrature');
