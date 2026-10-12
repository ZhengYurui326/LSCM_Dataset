function [ofdmSymbols, ofdmModulator, dataGrid, numDataSubcarriers] = ofdm_modulate(fftLength, cyclicPrefixLength, nSymbols, mod_type_str, oversample, seed)
%OFDM_MODULATE_SIMPLIFIED - 简化的OFDM调制函数（固定使用64-QAM）
%
% 使用正交频分复用(OFDM)调制，基于comm.OFDMModulator系统对象。
% 子载波固定采用64-QAM调制。
%
% 语法:
%   ofdmSymbols = ofdm_modulate_simplified(nSymbols)
%   ofdmSymbols = ofdm_modulate_simplified(nSymbols, seed)
%   [ofdmSymbols, bitMatrix] = ofdm_modulate_simplified(nSymbols, seed)
%
% 输入参数:
%   nSymbols - 要生成的OFDM符号数量
%   seed - (可选) 随机数生成器种子，默认为[] (不设置种子)
%
% 输出参数:
%   ofdmSymbols - OFDM调制后的复数时域信号 (列向量)
%   bitMatrix - 生成的原始比特矩阵 (可选输出)
%
% 示例:
%   % 生成10个OFDM符号
%   symbols = ofdm_modulate_simplified(10);
%   % 使用固定种子并获取原始比特
%   [symbols, bits] = ofdm_modulate_simplified(10, 12345);

    
    % 固定OFDM和调制参数
    numGuardBandCarriers = [fftLength / 16; fftLength / 16];
    numDataSubcarriers = fftLength - sum(numGuardBandCarriers) - 1;     % 计算数据子载波数
    
    totalSymbols = numDataSubcarriers * nSymbols;       % 计算总符号数


    switch mod_type_str
        case '4ASK'
            dataSymbols = ask_modulate(4, totalSymbols, seed);
        case 'BPSK'
            dataSymbols = psk_modulate(2, totalSymbols, seed);
        case 'QPSK'
            dataSymbols = psk_modulate(4, totalSymbols, seed);
        case '8PSK'
            dataSymbols = psk_modulate(8, totalSymbols, seed);    
        case '16QAM'
            dataSymbols = qam_modulate(16, totalSymbols, seed);
        case '64QAM'
            dataSymbols = qam_modulate(64, totalSymbols, seed);           
        otherwise
            % 检测到不支持的调制方式，触发错误并终止程序执行
            error('不支持的调制方式: %s\n', mod_type_str);
    end

    dataGrid = reshape(dataSymbols, numDataSubcarriers, nSymbols);      % 串并转换
    
    % --- 4. OFDM调制 (矢量化处理) ---
    ofdmModulator = comm.OFDMModulator(...
        'FFTLength',            fftLength, ...
        'NumGuardBandCarriers', numGuardBandCarriers, ...
        'InsertDCNull',         true, ...
        'PilotInputPort',       false, ...
        'CyclicPrefixLength',   cyclicPrefixLength, ...
        'OversamplingFactor',   oversample, ...
        'NumSymbols',           nSymbols, ...
        'NumTransmitAntennas',  1); 

    ofdmSymbols = ofdmModulator(dataGrid);
    
    release(ofdmModulator);

end
