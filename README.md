# LSCM_Dataset

面向 **AMC**（自动调制识别）、**SEI**（特定辐射源识别）、**DOA**（波达方向估计）三任务联合的合成数据集生成器：基于 8 元均匀圆阵（UCA）生成带射频损伤的复基带 I/Q 样本。

## 信号链路

```
调制基带 → 上采样 + RRC 成形（FSK/GMSK 直接输出波形）
  → 发射机射频损伤：IQ 不平衡 → 直流偏置 → 相位噪声 → 功放非线性(Saleh)
  → 瑞利衰落信道
  → UCA 导向矢量投影：s(t) × a(θ)ᵀ   （单通道 → 8 通道）
  → 各阵元独立 AWGN
  → 接收机射频损伤：逐阵元 LNA(Saleh) → 逐阵元 IQ 不平衡 → 共享 CFO 旋转
  → 全局 L2 归一化 → I/Q 拆分
```

## 数据集格式

每个样本为 `[8, 2, 128]` 的 float32 张量（8 阵元 × I/Q × 128 时间点）。输出 `.mat` 文件包含以下字段：

| 字段 | 形状 | 类型 | 说明 |
|---|---|---|---|
| `batch_data` | [B, 8, 2, 128] | single | I/Q 采样，通道 0 = 实部，1 = 虚部 |
| `label_mod` | [B, 1] | int32 | 调制类别（0-based，12 类） |
| `label_emitter` | [B, 1] | int32 | 发射机类别（0-based，10 类） |
| `label_doa` | [B, 1] | int32 | 角度类别（0-based，映射到 -90:90°） |
| `label_doa_deg` | [B, 1] | single | 真实方位角（度） |
| `label_snr` | [B, 1] | single | 信噪比（dB） |

## 关键参数

| 参数 | 值 |
|---|---|
| 发射机数 | 10 |
| 调制类型 | 12：4ASK, BPSK, QPSK, 8PSK, 16PSK, 16QAM, 64QAM, 128QAM, 2FSK, 4FSK, 8FSK, GMSK |
| SNR 范围 | -20:4:32 dB（14 档） |
| 接收阵列 | 8 元 UCA，相邻阵元弦长 = λ/2 |
| DOA 网格 | -90° ~ 90°，步进 1°（181 类） |
| 每角度重复次数 | 10（每条件 1810 帧） |
| 帧长 / 滑窗步进 | 128 / 96（50% 重叠） |
| 过采样因子 / RRC 滚降 | 8 / 0.3 |
| 总样本数 | 10 × 12 × 14 × 1810 = **3,040,800** |

## 运行

```matlab
dataset_generate_doa            % 单进程
dataset_generate_doa_parallel   % parfor 按发射机并行，写临时文件后合并
```

两个脚本启动时都会执行 `addpath(genpath(pwd))`，请在项目根目录运行。输出写入 `data/` 目录。

## 目录结构

| 目录 / 文件 | 说明 |
|---|---|
| `dataset_generate_doa.m` | 主生成脚本（单进程） |
| `dataset_generate_doa_parallel.m` | 并行版本 |
| `dataset_generate_doa_256.m` | 帧长 256 的变体 |
| `build_uca_steering_table.m` | 构造 UCA 导向矢量表 |
| `modulation/` | 调制函数（ASK/PSK/QAM/APSK/FSK/GMSK/OFDM）与 RRC 成形 |
| `impairments/` | 收发端射频损伤与信道模型 |
| `specific_emitter_parameters/` | `emitter_base.m` + `emitter1..10.m`，逐发射机的 Saleh / IQ / DC 参数 |
| `original/` | 早期原型脚本，不属于当前管线 |

## 说明

- 发射机之间的差异**完全**由发射端射频损伤参数（Saleh 功放非线性、IQ 不平衡、直流偏置）体现；10 个发射机共用 2 GHz 载频，因此阵列几何与导向矢量表结构一致。
- DOA 施加于接收机损伤**之前**，空间几何先于接收硬件失真；CFO 在各阵元间共享，以保持空间相干性。
- DOA 角度约定：`0°` 为正前方（`+y`），负角在左（`-x` 侧），正角在右（`+x` 侧）。
- 每个 `(发射机, 调制, SNR)` 条件下角度序列被打乱，但每个角度出现次数均等。
- 每个条件使用确定性种子 `e_idx*1e7 + (snr+50)*1e4 + mod_idx*1e2`，结果可复现。
- 生成的数据集体积约 46 GB，未包含在本仓库中。

## License

[MIT](LICENSE)
