function txRF = emitter_base()
%EMITTER_BASE  发射机公共参数
%
%   返回包含所有发射机共享字段的 struct，各 emitter 文件在此基础上添加特有参数。

    txRF = struct();

    txRF.SampleRate   = 8e6;     % 8 MHz 采样率
    txRF.CarrierFreq  = 2e9;     % 2 GHz 载波

end
