---
audience: agent
agent-priority: high
canonical-rules: true
last-reviewed: 2026-05-02
context-budget: 6KB
agent-summary: "输出目录规范、CSV/PNG/summary/report 标准、数据完整性规则、已有结果优先策略"
---

# 输出规范

<!-- rule-table: RULES_OUTPUT -->

## O1 数据完整性

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| O101 | 不凭空指定基准数据 — 以已有 CSV 和 summary 为准 | error | RUN §0, ARCH §8 |
| O102 | 不生成合成数据、伪结果或未标注推断结果 | error | RUN §0 |
| O103 | 不重用插值或合成频谱补缺失数据 | error | ARCH §8 |
| O104 | 不允许在未检查 outputs/ 的情况下重跑 | error | ARCH §8 |
| O105 | 论文/报告类输出必须能追溯到真实 CSV、summary 或 manifest | error | RUN §0 |

## O2 已有结果优先

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| O201 | 先读取本地已有结果 → 判断是否足够 → 缺失才建议补跑 | error | RUN §0 |
| O202 | 当前数据基础：22 个 steel 扫描 case + 5 材料 case 完整 CSV | info | RUN §2 |
| O203 | 活跃主线：3D 实体尺子 + 真实 3D 空气域 | info | RUN §1 |
| O204 | 优先用已有 CSV 生成论文所需图表和分析 | error | RUN §8 |
| O205 | 不把非线性结果混入线性主线 | error | ARCH §8 |

## O3 输出目录结构

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| O301 | 单次 case：outputs/<line>/<model>/data/*.csv, figures/*.png, summary.json, logs/<model>_matlab_manifest.json | error | ARCH §1 |
| O302 | 扫描/扫参：outputs/sweeps/<line>/<model>/<sweep_id>/ | error | ARCH §1 |
| O303 | 全自动报告：outputs/automation/matlab_full_automation_report.md | error | ARCH §5.1 |
| O304 | 论文级 CSV 表格：outputs/requested_*/tables/article_csv/ | info | RUN §2.5 |
| O305 | 输出图表：outputs/requested_*/figures/ | info | RUN §2.5 |

## O4 原始 CSV 格式

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| O401 | 格式：% col1,col2,...（注释头行），后接数值行 | error | AUTO §11 |
| O402 | frequencies.csv 列：mode, freq_hz | error | AUTO §11 |
| O403 | tip_timeseries.csv 列：t_s, w_m | error | AUTO §11 |
| O404 | structure_probe_timeseries.csv 列：t_s, uz_m | error | AUTO §11 |
| O405 | mic_pressure_timeseries.csv 列：t_s, p_pa | error | AUTO §11 |
| O406 | impact_force_timeseries.csv 列：t_s, force_z_N | error | AUTO §11 |
| O407 | mic_pressure_fft.csv 列：freq_hz, amp_pa | error | AUTO §11 |
| O408 | mode_shapes.csv 列：x_over_L, w_mode1... | error | AUTO §11 |
| O409 | 若 case 没有 tip 输出则允许缺失 tip_timeseries.csv，但必须在 summary 中标注 | warn | spec |

## O5 派生 CSV 格式

从原始 CSV 自动计算生成，不依赖 COMSOL LiveLink。所有派生指标对已有 CSV 的 case 可随时 batch 生成。

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| O501 | acoustic_metrics.csv：p_rms_pa, p_peak_pa, spl_rms_db, spl_peak_db, f_dom_hz, spectral_centroid_hz, spectral_bandwidth_hz, rolloff85_hz, band_30_120_ratio, band_120_500_ratio, band_500_2000_ratio；精度扩展列：f_dom_refined_hz, f_dom_bin_amp_pa, fft_resolution_hz, spectral_flatness, high_low_energy_ratio | error | compute_acoustic_metrics.m |
| O502 | structural_metrics.csv：probe_peak_m, probe_rms_m, tip_peak_m, tip_rms_m, dominant_structure_freq_hz, q_estimate, log_decrement, q_source, f1_hz..f6_hz（最多 6 阶）| error | compute_structural_metrics.m |
| O503 | modal_acoustic_coupling.csv：mode, mode_freq_hz, nearest_mic_peak_hz, delta_hz, rel_delta_pct, peak_amp_pa, snr_db, match_quality（excellent/good/fair/poor）；精度扩展列：nearest_mic_peak_refined_hz, delta_refined_hz, rel_delta_refined_pct | error | compute_modal_acoustic_coupling.m |
| O504 | band_decay_metrics.csv：band_id, f_low_hz, f_high_hz, peak_time_s, active_duration_10pct_s, active_duration_1pct_s, decay_to_10pct_s, decay_to_1pct_s, band_energy（4 频带：30-90/180-330/450-850/1100-1700 Hz）| error | compute_band_decay_metrics.m |
| O505 | case_metrics.csv：单行汇总，合并音调/响度/音色/结构幅值/模态/激励/关键参数 | error | compute_case_metrics.m |
| O506 | 缺原始 CSV 的 case 只标记 missing_input，不补点、不插值、不合成 | error | RUN §0 |
| O507 | 缺 tip_timeseries.csv 时，tip_peak_m/tip_rms_m/q_estimate/log_decrement 必须为 NaN，q_source 必须为 missing_tip；不得把 structure_probe_timeseries.csv 静默冒充 tip | error | compute_structural_metrics.m |

## O6 PNG 规格

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| O601 | 标准图形尺寸：800×450（Position [100, 100, 800, 450]）| error | plot_*.m |
| O602 | 模式振型图尺寸：800×220（Position [100, 100, 800, 220]）| error | plot_mode_shapes.m |
| O603 | 输出分辨率：150 DPI（exportgraphics Resolution=150）| error | plot_*.m |
| O604 | 输出方式：exportgraphics(fig, path, "Resolution", 150) | error | plot_*.m |
| O605 | 标准 PNG 文件清单（basic 1D beam）：frequencies_bar.png, tip_timeseries.png, tip_fft.png, pgmode_mode*.png（各模态）| info | pipeline code |
| O606 | 含麦克风时附加：mic_pressure_timeseries.png, mic_pressure_fft.png | info | pipeline code |
| O607 | 派生 PNG：modal_acoustic_coupling.png（频谱 + 模态叠加，900×500）| info | pipeline code |
| O608 | 派生 PNG：band_decay_envelope.png（4 频带能量包络，900×600）| info | pipeline code |
| O609 | 派生 PNG：mode_shapes.png（复合模式振型覆盖图，900×500）| info | plot_mode_shapes_composite.m |

## O7 summary.json 格式

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| O701 | summary.json 必须包含：模型参数、计算指标（固有频率 f1-f6、SPL、RMS、Q 因子等）、文件清单 | info | pipeline code |
| O702 | summary.json 存入 case 根目录（outputs/<line>/<model>/summary.json）| info | ARCH §1 |
| O703 | summary.json 派生字段：acoustic_metrics（含 p_rms_pa, p_peak_pa, spl_rms_db, spl_peak_db, f_dom_hz, spectral_centroid_hz, spectral_bandwidth_hz, rolloff85_hz, band_30_120_ratio, band_120_500_ratio, band_500_2000_ratio）| error | enhance_summary_with_metrics |
| O704 | summary.json 派生字段：structural_metrics（含 probe_peak_m, probe_rms_m, tip_peak_m, tip_rms_m, dominant_structure_freq_hz, q_estimate, log_decrement, q_source, num_modes, f1_hz..f6_hz）| error | enhance_summary_with_metrics |
| O705 | summary.json 派生字段：modal_acoustic_coupling_summary（含 n_modes, n_excellent, n_good, n_fair, n_poor, best_match_rel_delta_pct, worst_match_rel_delta_pct）| error | enhance_summary_with_metrics |
| O706 | summary.json 派生字段：band_decay_summary（含 per-band decay_to_10pct_s/active_duration_10pct_s、preliminary_high_frequency_decay_supported、status、method、win_sec、hop_sec、nfft）| error | enhance_summary_with_metrics |
| O707 | summary.json 派生字段：metrics_outputs（文件列表）、metrics_status（complete/partial）| error | enhance_summary_with_metrics |
| O708 | 每次宣称输出格式通过时，必须绑定明确 case_root，并通过 validate_derived_metrics_output(case_root)；不得把一个 case 的 PASS 结论套用到另一个 case | error | validate_derived_metrics_output.m |
| O709 | summary.json 派生字段：precision_metadata（含 fft_window, zero_padding_factor, peak_refinement_method, raw_time_step_s, raw_duration_s, raw_fs_hz, band_decay_method, band_decay_win_sec, band_decay_hop_sec）| error | enhance_summary_with_metrics |

## O8 质量档位

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| O801 | Quality 档位统一管理求解控制参数（网格、时间步等）| error | ARCH §2.2 |
| O802 | coarse：mesh 40-50, time_end 0.10s, time_step 1e-3s, mode 61-81 | info | ARCH §2.2 |
| O803 | medium：mesh 90-120, time_end 0.5s, time_step 2e-4s, mode 161 | info | ARCH §2.2 |
| O804 | full：mesh 120-160, time_end 1.0s, time_step 1e-4s, mode 241 | info | ARCH §2.2 |
