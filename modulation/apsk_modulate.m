function [apskSymbols, bitMatrix] = apsk_modulate(modulationOrder, nSymbols, seed)
%APSK_MODULATE - APSK调制函数
%
% 使用MATLAB内置的APSK调制器进行APSK调制
%
% 语法:
%   apskSymbols = apsk_modulate(modulationOrder, nSymbols)
%   apskSymbols = apsk_modulate(modulationOrder, nSymbols, seed)
%   [apskSymbols, bitMatrix] = apsk_modulate(modulationOrder, nSymbols, seed)
%
% 输入参数:
%   modulationOrder - APSK调制阶数 (如 8, 16, 32, 64 等)
%   nSymbols - 要生成的符号数量
%   seed - (可选) 随机数生成器种子，默认为[] (不设置种子)
%
% 输出参数:
%   apskSymbols - APSK调制符号
%   bitMatrix - 生成的比特矩阵 (可选输出)

    % 设置默认参数
    if nargin < 3
        seed = [];
    end
    
    % 计算每个符号的比特数
    bitsPerSymbol = log2(modulationOrder);
    
    % 生成随机比特序列
    if ~isempty(seed)
        oldState = rng(seed);  % 使用rng代替RandStream
    end
    
    % 生成随机比特矩阵
    totalBits = bitsPerSymbol * nSymbols;
    bitVector = randi([0, 1], totalBits, 1);  % 生成列向量
    bitMatrix = reshape(bitVector, bitsPerSymbol, nSymbols);
    
    % 恢复随机数生成器状态
    if ~isempty(seed)
        rng(oldState);
    end
    
    % APSK调制 - 使用预定义配置
    switch modulationOrder
        case 16
            % 16-APSK (2层，4:12配置)
            % 将比特矩阵转换为列向量用于调制
            bitVectorForMod = reshape(bitMatrix, [], 1);
            apskSymbols = apskmod(bitVectorForMod, ...
                [4 12], [0.5, 1], ...  % 调整半径比例
                'InputType', 'bit');
            
        case 32
            % 32-APSK (3层，4:12:16配置)
            % 将比特矩阵转换为列向量用于调制
            bitVectorForMod = reshape(bitMatrix, [], 1);
            apskSymbols = apskmod(bitVectorForMod, ...
                [4 12 16], [0.5 1.5 2], ...  % 调整半径比例
                'InputType', 'bit');
            
        case 64
            % 64-APSK (4层，4:12:20:28配置)
            % 将比特矩阵转换为列向量用于调制
            bitVectorForMod = reshape(bitMatrix, [], 1);
            apskSymbols = apskmod(bitVectorForMod, ...
                [4 12 20 28], [0.5 1.0 1.5 2.0], ...  % 调整半径比例
                'InputType', 'bit');
            
        case {4, 8}
            % 对于4和8阶，使用PSK调制替代
            warning('调制阶数%d不支持APSK，使用PSK调制替代', modulationOrder);
            % 将比特矩阵转换为列向量用于调制
            bitVectorForMod = reshape(bitMatrix, [], 1);
            apskSymbols = pskmod(bitVectorForMod, ...
                modulationOrder, ...
                'InputType', 'bit');
            
        otherwise
            % 对于其他阶数，使用通用的PSK调制
            warning('调制阶数%d不支持APSK，使用PSK调制替代', modulationOrder);
            % 将比特矩阵转换为列向量用于调制
            bitVectorForMod = reshape(bitMatrix, [], 1);
            apskSymbols = pskmod(bitVectorForMod, ...
                modulationOrder, ...
                'InputType', 'bit');
    end
end