# 项目进度 — 麦克风距离扫描 + 自适应精度分析

> 更新：2026-05-16

## 一、整体进度

| 阶段 | 状态 | 完成时间 |
|---|---|---|
| COMSOL 仿真修改（Java 模板） | ✅ | 5/14 |
| 自适应质量 profile（fast/eco/decay） | ✅ | 5/15 |
| 服务器 27 case 计算 | ✅ | 5/15 |
| 数据下载到本地 | ✅ | 5/16 |
| MATLAB 派生指标（B 批处理） | ✅ | 5/16 |
| 结论汇总表（C 汇总） | ✅ | 5/16 |
| 论文图表（8 张 PNG） | ✅ | 5/16 |
| eigen_shift=1000Hz bug 修复（代码） | ✅ | 5/16 |
| 频率 FFT 校正（8 个 case） | ✅ | 5/16 |
| 非钢材料 eigen_shift=1Hz 重跑 | 🔄 进行中 | 服务器 PID 252449 |
| 非钢材料非线性建模 | ⏳ 下一阶段 | — |

## 二、服务器仿真修改

### 新增功能
- **10 点对数间距 mic sweep**：`mic_pressure_timeseries_sweep_01~10.csv` + `mic_sweep_distances.csv`
- 距离范围：0.02m → 空气层边界（动态计算），对数间距（近场密集，远场稀疏）
- **自适应质量分配**：material/L_free/h → fast (0.25s)；b/J/x0_ratio → eco (0.12s)
- **eigen_shift 已修正**：1000Hz → 1Hz（Java 模板 + run_case.py），未来不再丢低频模态

### 服务器输出
```
~/comsol_work/the_singing_ruler/the_singing_ruler_full_server_source/outputs/
├── requested_adaptive/    ← 27 case 主结果（eigen_shift=1000Hz，有 8 case 频率错误）
├── materials_eigenfix/    ← 5 材料重跑（eigen_shift=1Hz），进行中
└── smoke_*                ← 各种 smoke test
```

## 三、MATLAB 后处理流水线

### 核心文件

| 文件 | 功能 |
|---|---|
| `matlab/extract/compute_modal_decay.m` | 带通滤波 → 指数衰减拟合 → τ, Q, R² per mode |
| `matlab/extract/correct_frequencies_from_fft.m` | FFT 修正 eigen_shift bug |
| `matlab/report/batch_derived_metrics.m` | 27 case 批量派生指标 |
| `matlab/report/aggregate_conclusion_table.m` | 结论主表（73 列 × 27 行） |
| `matlab/plot/plot_paper_figures_zh.m` | 中文论文图表（8 张） |
| `matlab/plot/replot_corrected_figures.m` | 修正后的图表 |

### 本地输出

```
outputs/requested_adaptive/
├── tables/
│   ├── conclusion_master_table.csv          ← 原始（含 eigen_shift bug）
│   ├── conclusion_master_table_corrected.csv ← FFT 修正版
│   └── derived_metrics_validation.csv       ← 27/27 PASS
├── figures/
│   ├── fig1_pitch_vs_L_corrected.png   ← 频率 vs 长度
│   ├── fig1b_pitch_decay_vs_h_corrected.png ← 频率+衰减 vs 厚度
│   ├── fig2_timbre_corrected.png       ← 音色映射
│   ├── fig4_spl_distance_corrected.png ← 声压空间衰减
│   └── fig6_linearity_corrected.png    ← 非线性判定
└── cases/
    └── */data/  ← 每个 case 17 个 CSV
```

## 四、已知问题

### eigen_shift=1000Hz bug（已修复）
- 原因：COMSOL 特征值求解器找离 shift 最近的 6 阶。shift=1000Hz 导致低频 ruler（长/薄/低 E）的基频被跳过
- 影响范围：8/27 case
- 代码修复：`eigen_shift: "1000[Hz]" → "1[Hz]"`（run_case.py + Java template）
- 数据修正：`correct_frequencies_from_fft.m` 从 mic FFT 提取真实频率
- 非钢材料正在用修正后的 eigen_shift 重跑中

### 非线性问题（未修复）
- 所有非钢材料（PVC、acrylic、satinwood、xuefu_board）probe_peak/L > 10%
- xuefu_board 最严重：probe_peak = 249mm (124% L)
- 当前线性模型对这些材料的频率/衰减/SPL 数据不可信
- 需要：几何非线性 SolidMechanics 模型

## 五、论文图表清单

| 图号 | 内容 | 数据来源 |
|---|---|---|
| Fig1 | f₁ vs L (f ∝ 1/L² 验证) | steel L_free scan |
| Fig1b | f₁ + τ₁ vs h | steel h scan |
| Fig2 | 频谱质心/平坦度 vs 材料 | 5 材料 timbre |
| Fig3 | SPL vs J, SPL vs x₀ | J scan + x0 scan |
| Fig4 | SPL vs mic 距离（5 材料） | mic sweep |
| Fig5 | τ, Q vs 频率（Rayleigh 验证） | modal_decay |
| Fig6 | 线性/非线性判定 | probe_peak/L |
| Fig7 | 位移 vs J（线性验证） | J scan |

## 六、下一阶段

1. **非钢材料非线性建模**：`models/nonlinear/` 新模型线，几何非线性 SolidMechanics
2. **非钢材料重跑**：非线性模型 + eigen_shift=1Hz，预计每个 case 更多时间
3. **论文正文**：基于现有钢数据可写音调/响度部分，音色部分待非线性数据
