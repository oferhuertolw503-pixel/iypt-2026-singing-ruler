# 全量高精度派生指标统一验证报告

> 生成日期：2026-05-03
> 数据根目录：`outputs/requested_3d_air_coarse_review_light`
> 对应提交：本报告随 `Add batch derived metrics rollup` 提交

---

## 1. 总体结果

| 指标 | 值 |
|---|---|
| 发现 case 总数 | **27** |
| Format 验证通过 | **27/27** (100%) |
| 精度验证通过 | **27/27** (100%) |
| 总体通过 | **27/27** (100%) |
| Band decay 可用 | 27/27 (100%) |
| Metrics 状态 | 全部 `complete` |

## 2. 分组覆盖

| 分组 | 扫描参数 | Case 数 |
|---|---|---|
| `J` | 脉冲激励幅值 (0.02–0.08 Ns) | 4 |
| `L_free` | 自由段长度 (10–26 cm) | 5 |
| `b` | 宽度 (1–5 cm) | 5 |
| `h` | 厚度 (1–5 mm) | 5 |
| `x0_ratio` | 敲击位置比例 (0.25–0.75) | 3 |
| `timbre_material` | 材料种类 (钢/亚克力/PVC/花梨木/学府板) | 5 |

## 3. 关键指标范围

| 指标 | 最小值 | 最大值 | 说明 |
|---|---|---|---|
| `spl_rms_db` | 82.3 (b_1cm) | 109.2 (xuefu_board) | 声压级范围约 27 dB |
| `f_dom_refined_hz` | 12.1 (PVC) | 276.5 (xuefu_board) | 主频跨 2 个数量级 |
| `spectral_centroid_hz` | 47.9 (steel) | 353.5 (x0_ratio_0p25) | 音色亮度高度可调 |
| `spectral_flatness` | 0.0005 (L_free_10cm) | 0.0187 (x0_ratio_0p75) | 接近纯音 (≈0) 到类噪声 (>0.01) |
| `probe_peak_mm` | 0.78 (h_5mm) | 248.7 (xuefu_board) | 振动幅度跨 300 倍 |
| `best_match_rel_delta_pct` | 0.02% (x0_ratio_0p5) | 5.96% (xuefu_board) | 模态声学耦合匹配误差 |
| `n_modal_matches` | 6 | 6 | 全部 case 匹配到 6 阶模态 |

### 3.1 物理一致性检查

- **J 扫描**：SPL 随脉冲幅值单调递增 (83.0→95.0 dB)，主频稳定在 40.2 Hz（几何未变）
- **L_free 扫描**：主频随自由段增长单调下降 (161.5→23.8 Hz)，符合梁理论 f ∝ 1/L²
- **h 扫描**：主频随厚度增加单调上升 (20.3→100.0 Hz)，符合 f ∝ h
- **b 扫描**：宽度对主频影响小 (40.0→40.4 Hz)，但模态匹配误差随宽度增加而增大（窄梁假设逐渐失效）
- **x0_ratio 扫描**：敲击位置偏中 (0.5) 激发最高 SPL (102.3 dB)，偏端 (0.25) 激发更高阶模态 (249 Hz)
- **材料扫描**：主频从亚克力 (13.5 Hz) 到学府板 (276.5 Hz)，反映刚度/密度比的巨大差异

## 4. 方法说明

### 4.1 FFT 参数

| 参数 | 值 |
|---|---|
| 窗函数 | Hann (手动实现, `0.5 - 0.5*cos(2π*n/N)`) |
| 零填充因子 | 4× |
| FFT 长度 | `2^nextpow2(4 * n_samples)` |
| 幅度归一化 | `abs(fft(win .* y, nfft)) / sum(win)`，单侧谱 ×2 |
| 峰值精炼 | 对数域三点抛物线插值 |

### 4.2 模态声学耦合

| 参数 | 值 |
|---|---|
| 频谱峰值检测 | `detect_local_spectral_peaks`，最小突起 3 dB |
| 匹配方法 | 结构特征频率 → 最近声学峰值（优先使用精炼后频率） |
| 匹配质量 | <2% + >20dB → excellent; <5% + >10dB → good; <10% → fair |

### 4.3 频带衰减 (STFT)

| 参数 | 值 |
|---|---|
| 频带 | 30–90, 180–330, 450–850, 1100–1700 Hz |
| 窗 | Hann, 0.020 s |
| Hop | 0.005 s |
| 零填充 NFFT | `2^nextpow2(4 * win_len)` |

## 5. 已知限制

1. **Coarse 时间窗口 (0.10 s)**：当前所有 case 使用 `coarse` 品质的短时间窗，FFT 频率分辨率有限（约 10 Hz/ bin）。带衰减标记为 `preliminary_coarse_time_window`，不足以得出强衰减结论。
2. **Q 估计缺失**：所有 case 无 `tip_timeseries.csv`，结构探针数据正确标记为 `q_source=missing_tip`，`q_estimate=NaN`。Q 值需 medium/full 品质数据和真实 tip 时程。
3. **高频模态退化**：高阶模态匹配质量受限于粗分辨率。最极端 case (xuefu_board, 5.96%) 仍在可接受范围。
4. **宽度效应**：b ≥ 4 cm 时窄梁假设逐渐失效，模态匹配误差升至 4.83%–5.20%。
5. **材料非均匀性**：学府板 (xuefu_board) 为复合材料，主频最高 (276.5 Hz)，振动幅值最大 (249 mm)，表明材料参数与均质钢差异显著。

## 6. 后续论文分析建议

- **验证性绘图**：基于 `derived_metrics_validation.csv` 绘制 f_dom 与 L_free/h 的理论关系曲线
- **音色量化**：用 spectral_centroid + spectral_flatness 建立音色空间，区分不同材料和几何
- **模态耦合对比**：cross-case 对比 match_quality，评估窄梁假设的适用边界
- **Q 估计补全**：在 medium/full 品质运行中增加 `tip_timeseries.csv` 输出，使 `q_estimate` 可用
- **带衰减分析**：在 medium/full 时间窗口下重新计算 band_decay_metrics，得出有效衰减时间

---

*本报告仅保存全量指标统一与验证的事实底座，不作论文级结论解释。*
