function [qamSymbols, bitMatrix] = qam_modulate(modulationOrder, nSymbols, seed)
%QAM_MODULATE - QAM调制函数
%
% 使用MATLAB内置的RectangularQAMModulator进行QAM调制
%
% 语法:
%   qamSymbols = qam_modulate(modulationOrder, nSymbols)
%   qamSymbols = qam_modulate(modulationOrder, nSymbols, seed)
%   [qamSymbols, bitMatrix] = qam_modulate(modulationOrder, nSymbols, seed)
%
% 输入参数:
%   modulationOrder - QAM调制阶数 (如 4, 16, 64, 256)
%   nSymbols - 要生成的符号数量
%   seed - (可选) 随机数生成器种子，默认为[] (不设置种子)
%
% 输出参数:
%   qamSymbols - QAM调制符号
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
    
    % 将比特转换为十进制数
    decimalValues = zeros(nSymbols, 1);
    for i = 1:bitsPerSymbol
        decimalValues = decimalValues + bitMatrix(i, :).' * (2^(i-1));
    end
    
    % QAM调制
    qamSymbols = qammod(bitMatrix, modulationOrder, 'InputType', 'bit', "UnitAveragePower", true);
end

