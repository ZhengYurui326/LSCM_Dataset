function [gmskSymbols, bitMatrix] = gmsk_modulate(nSymbols, seed)
%GMSK_MODULATE - GMSK调制函数
%
% 使用高斯最小频移键控(GMSK)调制，基于comm.GMSKModulator系统对象
% GMSK是连续相位调制，具有恒定包络和良好的频谱效率
%
% 语法:
%   gmskSymbols = gmsk_modulate(nSymbols)
%   gmskSymbols = gmsk_modulate(nSymbols, seed)
%   gmskSymbols = gmsk_modulate(nSymbols, seed, btProduct)
%   gmskSymbols = gmsk_modulate(nSymbols, seed, btProduct, samplesPerSymbol)
%   [gmskSymbols, bitMatrix] = gmsk_modulate(nSymbols, seed, btProduct, samplesPerSymbol)
%
% 输入参数:
%   nSymbols - 要生成的符号数量（每个符号对应1个比特）
%   seed - (可选) 随机数生成器种子，默认为[] (不设置种子)
%   btProduct - (可选) 带宽时间乘积，默认0.3 (GMSK标准值)
%   samplesPerSymbol - (可选) 每个符号的采样点数，默认8
%
% 输出参数:
%   gmskSymbols - GMSK调制符号（复数基带信号）
%   bitMatrix - 生成的比特矩阵 (可选输出)
%
% 示例:
%   % 基本使用
%   symbols = gmsk_modulate(100);
%   % 自定义参数
%   symbols = gmsk_modulate(100, 12345, 0.5, 16);
%   % 获取比特矩阵
%   [symbols, bits] = gmsk_modulate(50, 12345);

    % 设置默认参数
    samplesPerSymbol = 8;
    btProduct = 0.3;
    
    if nargin < 2
        seed = [];
    end
    
    % 生成随机比特序列
    if ~isempty(seed)
        oldState = RandStream.getGlobalStream;
        stream = RandStream('mt19937ar', 'Seed', seed);
        RandStream.setGlobalStream(stream);
    end
    
    % 生成随机比特矩阵 [1 × nSymbols]（GMSK每个符号1个比特）
    bitMatrix = randi([0, 1], 1, nSymbols);
    
    % 恢复随机数生成器状态
    if ~isempty(seed)
        RandStream.setGlobalStream(oldState);
    end
    
    % 将比特矩阵转换为列向量用于调制
    bitVector = reshape(bitMatrix, [], 1);
    
    % 创建GMSK调制器系统对象
    gmskModulator = comm.GMSKModulator(...
        'BitInput', true, ...                    % 输入为比特
        'BandwidthTimeProduct', btProduct, ...     % 带宽时间乘积
        'SamplesPerSymbol', samplesPerSymbol, ...  % 每符号采样点数
        'PulseLength', 4, ...            % 脉冲长度
        'InitialPhaseOffset', 0, ...  % 初始相位偏移
        'OutputDataType', 'double');                % 输出数据类型
    
    % 进行GMSK调制
    gmskSymbols = gmskModulator(bitVector);
    
    % 确保输出为复数形式（GMSK输出已经是复数）
    % if ~isreal(gmskSymbols)
    %     gmskSymbols = complex(real(gmskSymbols), imag(gmskSymbols));
    % end
    
    % 释放系统对象
    release(gmskModulator);
end