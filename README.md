# LSCM_Dataset

A synthetic dataset generator for three joint tasks — **AMC** (automatic modulation classification), **SEI** (specific emitter identification), and **DOA** (direction of arrival) estimation — producing complex baseband I/Q samples received by an 8-element uniform circular array (UCA).

## Signal chain

```
Modulation baseband → Upsample + RRC pulse shaping (direct waveform for FSK/GMSK)
  → TX RF impairments: IQ imbalance → DC offset → phase noise → PA nonlinearity (Saleh)
  → Rayleigh fading channel
  → UCA steering vector projection: s(t) × a(θ)ᵀ   (1 channel → 8 channels)
  → Per-antenna independent AWGN
  → RX RF impairments: per-antenna LNA (Saleh) → per-antenna IQ imbalance → shared CFO rotation
  → Global L2 normalization → I/Q split
```

## Dataset format

Each sample is a `[8, 2, 128]` float32 tensor (8 antennas × I/Q × 128 time samples). The output `.mat` file contains the following variables:

| Variable | Shape | Type | Description |
|---|---|---|---|
| `batch_data` | [B, 8, 2, 128] | single | I/Q samples, channel 0 = real, 1 = imag |
| `label_mod` | [B, 1] | int32 | Modulation class (0-based, 12 classes) |
| `label_emitter` | [B, 1] | int32 | Emitter class (0-based, 10 classes) |
| `label_doa` | [B, 1] | int32 | Angle class index (0-based, maps to -90:90°) |
| `label_doa_deg` | [B, 1] | single | True azimuth angle in degrees |
| `label_snr` | [B, 1] | single | SNR in dB |

## Key parameters

| Parameter | Value |
|---|---|
| Emitters | 10 |
| Modulation types | 12: 4ASK, BPSK, QPSK, 8PSK, 16PSK, 16QAM, 64QAM, 128QAM, 2FSK, 4FSK, 8FSK, GMSK |
| SNR range | -20:4:32 dB (14 steps) |
| Receive array | 8-element UCA, adjacent-element chord length = λ/2 |
| DOA grid | -90° to 90°, 1° step (181 classes) |
| Repeats per angle | 10 (1810 frames per condition) |
| Frame length / stride | 128 / 96 (50% overlap) |
| Oversampling / RRC roll-off | 8 / 0.3 |
| Total samples | 10 × 12 × 14 × 1810 = **3,040,800** |

## Usage

```matlab
dataset_generate_doa            % serial (single worker)
dataset_generate_doa_parallel   % parfor over emitters, writes temp files then merges
```

Both scripts run `addpath(genpath(pwd))` on startup, so run them from the project root. Output is written to the `data/` directory.

## Repository layout

| File / directory | Description |
|---|---|
| `dataset_generate_doa.m` | Main generation script (serial) |
| `dataset_generate_doa_parallel.m` | Parallel version |
| `dataset_generate_doa_256.m` | Variant with frame length 256 |
| `build_uca_steering_table.m` | Builds the UCA steering vector table |
| `modulation/` | Modulation functions (ASK/PSK/QAM/APSK/FSK/GMSK/OFDM) and RRC pulse shaping |
| `impairments/` | TX/RX RF impairment models and channel models |
| `specific_emitter_parameters/` | `emitter_base.m` + `emitter1..10.m`, per-emitter Saleh / IQ / DC parameters |
| `original/` | Early prototype scripts, not part of the current pipeline |

## Notes

- Emitter differentiation comes **entirely** from TX RF impairment parameters (Saleh PA nonlinearity, IQ imbalance, DC offset). All 10 emitters share the same 2 GHz carrier, hence the same array geometry and steering table structure.
- DOA is applied **before** RX impairments: spatial geometry precedes receiver hardware distortion. The CFO is shared across antennas to preserve spatial coherence.
- DOA angle convention: `0°` is straight ahead (`+y`), negative angles are to the left (`-x` side), positive angles are to the right (`+x` side).
- Within each `(emitter, modulation, SNR)` condition the angle sequence is shuffled, but every angle appears equally often.
- Each condition uses a deterministic seed `e_idx*1e7 + (snr+50)*1e4 + mod_idx*1e2`, making results reproducible.
- The generated dataset is roughly 46 GB and is **not** included in this repository.

## License

[MIT](LICENSE)
