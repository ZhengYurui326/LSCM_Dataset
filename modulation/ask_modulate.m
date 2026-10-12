function [askSymbols, bitMatrix] = ask_modulate(modulationOrder, nSymbols, seed)
%ASK_MODULATE - ASK调制函数
%
% 使用PAM调制实现ASK调制，自动生成随机比特序列
%
% 语法:
%   askSymbols = ask_modulate(modulationOrder, nSymbols)
%   askSymbols = ask_modulate(modulationOrder, nSymbols, seed)
%   [askSymbols, bitMatrix] = ask_modulate(modulationOrder, nSymbols, seed)
%
% 输入参数:
%   modulationOrder - ASK调制阶数 (如 2=BASK, 4=4-ASK 等)
%   nSymbols - 要生成的符号数量
%   seed - (可选) 随机数生成器种子，默认为[] (不设置种子)
%
% 输出参数:
%   askSymbols - ASK调制符号
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
    
    % 生成随机十进制数，然后转换为比特
    decimalValues = randi([0, modulationOrder-1], nSymbols, 1);
    
    % 将十进制数转换为比特矩阵
    bitMatrix = zeros(bitsPerSymbol, nSymbols);
    for i = 1:bitsPerSymbol
        bitMatrix(i, :) = bitget(decimalValues, i);
    end

    % 恢复随机数生成器状态
    if ~isempty(seed)
        RandStream.setGlobalStream(oldState);
    end
    
    % 使用PAM调制实现ASK调制，并进行幅度归一化确保平均功率为1
    % 参考ChangShuoRadioData项目中ASK类的实现
    amplitudeNormalization = 1 / sqrt(mean(abs(pammod(0:modulationOrder - 1, modulationOrder)) .^ 2));
    realSymbols = amplitudeNormalization * pammod(decimalValues, modulationOrder);
    
    % 将ASK信号转换为复数形式（实部为ASK信号，虚部为0）
    askSymbols = complex(realSymbols, 0);
end