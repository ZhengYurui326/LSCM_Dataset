function [shapedSignal, filterCoeffs] = upsample_and_shape(iqSignal, sps, rolloff)
%UPSAMPLE_AND_SHAPE - 上采样与脉冲成形函数
%
% 对IQ信号进行上采样和脉冲成形处理，使用升余弦滤波器
%
% 语法:
%   shapedSignal = upsample_and_shape(iqSignal, sps)
%   [shapedSignal, filterCoeffs] = upsample_and_shape(iqSignal, sps)
%
% 输入参数:
%   iqSignal - 输入的IQ信号 (复数向量，符号级信号)
%   sps - 每符号采样数 (过采样因子)
%
% 输出参数:
%   shapedSignal - 上采样和脉冲成形后的信号
%   filterCoeffs - 滤波器系数 (可选输出)
%
% 示例:
%   % 生成随机符号
%   symbols = randn(100,1) + 1i*randn(100,1);
%   % 上采样和脉冲成形 (4倍过采样)
%   shapedSignal = upsample_and_shape(symbols, 4);
    
    % 固定参数设置
    span = 6;       % 固定符号跨度  
    shape = 'sqrt'; % 固定滤波器类型为平方根升余弦
    
    % 确保输入信号为列向量
    iqSignal = iqSignal(:);
    
    % 设计升余弦滤波器
    filterCoeffs = rcosdesign(rolloff, span, sps, shape);
    
    % 上采样 - 在符号间插入零点
    upsampledSignal = upsample(iqSignal, sps);
    
    % 应用脉冲成形滤波器
    shapedSignal = filter(filterCoeffs, 1, upsampledSignal);
    
end