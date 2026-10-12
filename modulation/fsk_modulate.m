function [fskSymbols, bitMatrix] = fsk_modulate(modulationOrder, nSymbols, seed)
% FSK_MODULATE - FSK调制函数
% 通常情况下，FSK调制不需要进行额外的脉冲成型
%
% 使用频率偏移实现FSK调制，自动生成随机比特序列
%
% 语法:
%   fskSymbols = fsk_modulate(modulationOrder, nSymbols)
%   fskSymbols = fsk_modulate(modulationOrder, nSymbols, seed)
%   [fskSymbols, bitMatrix] = fsk_modulate(modulationOrder, nSymbols, seed)
%
% 输入参数:
%   modulationOrder - FSK调制阶数 (如 2=BFSK, 4=4-FSK 等)
%   nSymbols - 要生成的符号数量
%   seed - (可选) 随机数生成器种子，默认为[] (不设置种子)
%
% 输出参数:
%   fskSymbols - FSK调制符号
%   bitMatrix - 生成的比特矩阵 (可选输出)

    % 设置默认参数
    if nargin < 3
        seed = [];
    end
    
    % 计算每个符号的比特数
    bitsPerSymbol = log2(modulationOrder);
    
    % 使用独立 RandStream 生成随机比特序列，避免干扰全局随机流
    if ~isempty(seed)
        stream = RandStream('mt19937ar', 'Seed', seed);
    else
        stream = RandStream.getGlobalStream;
    end

    % 生成随机十进制数 [0, modulationOrder-1]
    decimalValues = randi(stream, [0, modulationOrder-1], nSymbols, 1);
    
    % 将十进制数转换为比特矩阵用于输出
    bitMatrix = zeros(bitsPerSymbol, nSymbols);
    for i = 1:nSymbols
        for j = 1:bitsPerSymbol
            bitMatrix(j, i) = bitget(decimalValues(i), j);
        end
    end
    
    % 使用FSK调制，每个符号对应不同的频率
    % 频率间隔设置为适应调制阶数的值
    % 对于高阶FSK，需要更小的频率间隔以避免超过Nyquist频率
    frequencySpacing = 0.5 / modulationOrder;
    
    % 使用MATLAB内置的FSK调制功能
    % fskmod(x, M, freq_sep, nsamp, Fs, phase_cont)
    % 我们需要设置采样点数，这里使用最小值2
    nsamp = 8;  % 每个符号的采样点数
    fskSymbols = fskmod(decimalValues, modulationOrder, frequencySpacing, nsamp);
    
    % 确保输出为复数形式
    if ~any(imag(fskSymbols) ~= 0)
        fskSymbols = complex(fskSymbols, 0);
    end
end