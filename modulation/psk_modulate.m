function [pskSymbols, bitMatrix] = psk_modulate(modulationOrder, nSymbols, seed)
%PSK_MODULATE - PSK调制函数
%
% 使用MATLAB内置的PSK调制器进行PSK调制
%
% 语法:
%   pskSymbols = psk_modulate(modulationOrder, nSymbols)
%   pskSymbols = psk_modulate(modulationOrder, nSymbols, seed)
%   [pskSymbols, bitMatrix] = psk_modulate(modulationOrder, nSymbols, seed)
%
% 输入参数:
%   modulationOrder - PSK调制阶数 (如 2=BPSK, 4=QPSK, 8=8-PSK 等)
%   nSymbols - 要生成的符号数量
%   seed - (可选) 随机数生成器种子，默认为[] (不设置种子)
%
% 输出参数:
%   pskSymbols - PSK调制符号
%   bitMatrix - 生成的比特矩阵 (可选输出)

    % 设置默认参数
    if nargin < 3
        seed = [];
    end
    
    % 计算每个符号的比特数
    bitsPerSymbol = log2(modulationOrder);
    
    % 生成随机比特序列
    if ~isempty(seed)
        oldState = RandStream.getGlobalStream;
        stream = RandStream('mt19937ar', 'Seed', seed);
        RandStream.setGlobalStream(stream);
    end
    
    % 生成随机比特矩阵 [bitsPerSymbol × nSymbols]
    bitMatrix = randi([0, 1], bitsPerSymbol, nSymbols);
    bitMatrix = reshape(bitMatrix, [], 1);
    
    % 恢复随机数生成器状态
    if ~isempty(seed)
        RandStream.setGlobalStream(oldState);
    end
    
    % PSK调制 - 使用比特输入，根据调制阶数选择相位偏移
    if modulationOrder == 2 || modulationOrder == 4
        phaseOffset = pi/4;
    elseif modulationOrder == 8
        phaseOffset = pi/8;
    else
        phaseOffset = pi/4;  % 默认相位偏移
    end
    pskSymbols = pskmod(bitMatrix, modulationOrder, phaseOffset, 'InputType', 'bit');
end

