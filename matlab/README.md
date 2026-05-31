# MATLAB 后处理模块

> 路径: `matlab/` | 语言: MATLAB R2025a | 依赖: Signal Processing Toolbox, Statistics and Machine Learning Toolbox

## 模块结构

```
matlab/
├── core/          # 管线入口 + 通用工具
├── extract/       # 信号处理、特征提取
├── plot/          # 300 DPI 论文图表
├── report/        # 批处理、结论汇总表
├── validate/      # 输出完整性验证
├── export/        # 输出打包导出
└── main_*.m       # 各模型的主入口 (LiveLink 模式)
```

## 核心模块

### core/ — 管线与工具

| 文件 | 功能 |
|---|---|
| `run_derived_metrics.m` | **衍生指标计算枢纽**: SPL、模态衰减、音色特征、结构指标、模态耦合 |
| `run_beam_model_pipeline.m` | 通用梁模型管线 (离线 CSV 优先, LiveLink 后备) |
| `ensure_dir.m` | 目录创建 (幂等) |
| `read_matlab_handoff_manifest.m` | 读取 PowerShell→MATLAB 交接 manifest |

### extract/ — 信号处理

| 文件 | 物理量 | 方法 |
|---|---|---|
| `compute_single_sided_fft.m` | 频谱 | Hann 窗 + 4× 零填充 + 抛物线峰值精修 |
| `compute_spl_from_pressure.m` | SPL (dB) | RMS 压力 → dB (ref 20μPa) |
| `compute_modal_decay.m` | τₙ, Qₙ | 带通滤波 → Hilbert 包络 → log 线性回归 |
| `compute_acoustic_metrics.m` | SPL, 主导频率, 频谱特征 | 时域 SPL + FFT |
| `compute_timbre_metrics_extended.m` | 频谱质心、平坦度、滚降 | 频谱矩 |
| `compute_structural_metrics.m` | 探针位移峰值、Q | 时域位移分析 |
| `compute_modal_acoustic_coupling.m` | 声-结构模态匹配 | 频率匹配 + 相对误差 |
| `read_exported_numeric_csv.m` | CSV 导入 | COMSOL 导出格式解析 (含单位剥离) |
| `correct_frequencies_from_fft.m` | FFT 频率校正 | 补偿 eigen_shift bug 的错频 |
| `detect_local_spectral_peaks.m` | 频谱峰值检测 | 局部极大值 + 阈值 |
| `estimate_q_from_tip.m` | Q 估计 | 自由端衰减对数减量法 |
| `compute_band_decay_metrics.m` | 频带衰减 | 1/3 倍频程带衰减分析 |

### plot/ — 论文图表

| 文件 | 产出 |
|---|---|
| `plot_paper_figures_final.m` | **9 张论文图** (Fig1-Fig9): 频率 vs L, 频率+衰减 vs h, τ vs f, SPL vs J/x₀, SPL vs 距离, 音色映射, 线性判定, 频率稳定性, 振型 |
| `plot_paper_figures_zh.m` | 中文标注版 |
| `replot_corrected_figures.m` | 用 FFT 校正后数据重绘图 |
| `plot_band_decay_envelope.m` | 带通滤波 + Hilbert 包络可视化 |
| `plot_modal_acoustic_coupling.m` | 声-结构耦合可视化 |
| `plot_mode_shapes_composite.m` | 多阶振型叠加图 |

### report/ — 批处理与汇总

| 文件 | 功能 |
|---|---|
| `batch_derived_metrics.m` | **批处理入口**: 发现所有 case → 逐一计算衍生指标 → 验证 → 汇总报告 |
| `aggregate_conclusion_table.m` | **汇总表**: 73 列 × N cases 主结论表 |
| `paper_analysis_27_case.m` | 27-case 论文分析 |
| `timbre_enhanced_analysis.m` | 增强音色分析 (含线性/非线性分类) |
| `quick_conclusion.m` | 快速结论输出 |

### validate/ — 验证

| 文件 | 功能 |
|---|---|
| `validate_derived_metrics_output.m` | 衍生指标格式+精度验证 (RequirePrecision=true) |

## 典型工作流

### 离线 CSV 模式 (推荐)

```matlab
proj = 'C:\Users\...\the_singing_ruler';

% 1. 批处理: 对所有 case 计算衍生指标
batch_derived_metrics(proj, 'outputs/materials_combined');

% 2. 生成汇总表
T = aggregate_conclusion_table(proj, 'outputs/materials_combined');

% 3. 画论文图
plot_paper_figures_final();
```

### 数据流

```
COMSOL CSV 导出
  ├─ frequencies.csv           → f₁...f₆
  ├─ mic_pressure_timeseries.csv → SPL, 频谱, 音色
  ├─ structure_probe_timeseries.csv → 位移峰值, Q
  ├─ mode_shapes.csv            → 振型可视化
  ├─ impact_force_timeseries.csv → 实际冲量验证
  ├─ mic_sweep_*.csv (×10)     → 空间衰减
  └─ tip_timeseries.csv (可选)  → Q 直接估计
         │
         ▼
  run_derived_metrics.m
         │
         ├─ acoustic_metrics.csv
         ├─ structural_metrics.csv
         ├─ modal_decay.csv
         ├─ modal_acoustic_coupling.csv
         └─ timbre_metrics.csv
              │
              ▼
  aggregate_conclusion_table.m
         │
         └─ conclusion_master_table.csv (73 columns)
              │
              ▼
  plot_paper_figures_final.m
         │
         └─ fig1~fig9.png (300 DPI)
```

## 配置

- **绘图字体**: 微软雅黑 (中文) + TeX 数学公式
- **导出分辨率**: 300 DPI (via `exportgraphics`)
- **SPL 参考**: 20 μPa (空气中)
- **FFT 参数**: Hann 窗, 4× 零填充, 抛物线精修

## 局限性

1. **频域分辨率**: 0.25s 窗口 → 4 Hz 分辨率。f₁ < 15 Hz 时峰值定位精度受限
2. **模态衰减**: 低频谱 (< 15 Hz) 需要 > 0.5s 时间窗口才能可靠拟合指数衰减
3. **离线 CSV 优先**: MATLAB 不直接连接 COMSOL LiveLink (除非显式授权且 CSV 缺失)
