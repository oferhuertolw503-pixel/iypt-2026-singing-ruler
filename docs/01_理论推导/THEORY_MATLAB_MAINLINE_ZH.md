---
audience: human, agent
agent-priority: high
status: active
report-type: workflow-note
recommended-use: theory-mainline, paper-methods, defense
encoding: UTF-8
---

# MATLAB 理论计算主线：与仿真结果对齐

本文记录新增的理论计算主线。该主线不运行 COMSOL，只读取已完成仿真输出，用 Euler-Bernoulli 梁模态和一个声压灰箱模型生成与仿真结果同列对齐的理论数据。

## 1. 主入口

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
main_theory_aligned_to_simulation
```

MATLAB 文件：

```text
matlab/main_theory_aligned_to_simulation.m
```

输出根目录：

```text
outputs/theory/aligned_to_simulation/
```

## 2. 数据输入

| 输入 | 用途 |
|---|---|
| `outputs/requested_3d_air_coarse_review_light/tables/all_requested_cases.csv` | 22 个钢尺几何/冲量/敲击位置扫描 case |
| `outputs/requested_timbre_complete_enhanced_medium/tables/paper_analysis/timbre_lowJ_primary_summary.csv` | 5 材料低冲量音色主结论 |
| `outputs/requested_timbre_complete_enhanced_medium/configs/*.json` | 材料 case 的几何、冲量和敲击位置参数 |

## 3. 理论模型

频率模型使用 Euler-Bernoulli 悬臂梁前 6 阶模态：

$$
f_n=\frac{\lambda_n^2}{2\pi\sqrt{12}}\frac{h}{L^2}\sqrt{\frac{E}{\rho}}.
$$

对齐时同时保留：

| 字段 | 含义 |
|---|---|
| `theory_f1_hz` ... `theory_f6_hz` | 理论 1-6 阶梁模态频率 |
| `theory_f_aligned_hz` | 与仿真主峰最近的理论模态频率 |
| `theory_aligned_mode` | 最近模态阶数 |
| `theory_f_weighted_dom_hz` | 简单模态权重模型给出的理论主导频率 |

声压模型只做量纲对齐，不追求高精度拟合：

$$
p_\mathrm{rms}=C\frac{Jh}{L^3}\sqrt{\frac{b}{b_0}}\frac{\rho_\mathrm{steel}}{\rho}\,G_\mathrm{mode}(x_0/L).
$$

其中 $C$ 只用钢尺基准 case `J_0p04Ns` 做一次标定，使理论声压和仿真声压处于同一单位量级。该主线不对所有 case 做多参数拟合。

## 4. 输出文件

| 输出 | 内容 |
|---|---|
| `tables/steel_scan_theory_alignment.csv` | 钢尺 22 个扫描 case 的仿真-理论对齐表 |
| `tables/material_lowJ_theory_alignment.csv` | 5 材料低冲量 case 的仿真-理论对齐表 |
| `tables/all_theory_alignment.csv` | 合并表 |
| `figures/steel_scan_frequency_alignment.png` | 钢尺扫描主频对齐图 |
| `figures/steel_scan_spl_alignment.png` | 钢尺扫描 SPL 对齐图 |
| `figures/material_lowJ_frequency_alignment.png` | 材料低冲量频率对齐图 |
| `figures/material_lowJ_timbre_proxy_alignment.png` | 材料音色代理指标对齐图 |
| `summary.json` | 主线元数据、输入输出路径和标定策略 |

## 5. 使用口径

这条理论主线的目标是“结果物理量对齐”，不是“数值拟合最好”。可以用于论文理论部分、答辩中理论-仿真交叉验证，以及后续实验前的量级预估。

推荐表述：

> MATLAB 理论主线使用 Euler-Bernoulli 梁的 1-6 阶模态计算结构频率，并用单点标定的声压灰箱模型生成与 3D 空气域仿真同列的频率、声压、SPL、Q 和频谱代理指标。该模型主要用于验证趋势和物理量对应关系，而非替代 COMSOL 或实验。

## 6. 验证记录

已在 MATLAB R2025a batch 模式下运行：

```text
main_theory_aligned_to_simulation
```

运行结果：

| 项目 | 数量 |
|---|---:|
| 钢尺扫描对齐行 | 22 |
| 材料低冲量对齐行 | 5 |

静态检查：

```text
checkcode('matlab/main_theory_aligned_to_simulation.m')
```

未输出 checkcode 警告。

