# The Singing Ruler 项目运行目标

> 生成日期：2026-05-02
> 数据来源：本地 `outputs/` 实际扫描结果
> 用途：给 Claude Code 在本地项目中的执行指引
>
> **本文件定义当前 Singing Ruler 项目的具体运行目标和执行边界。
> 通用流水线架构见 [`WORKFLOW_ARCHITECTURE.md`](WORKFLOW_ARCHITECTURE.md)。**

## 0. 总原则

```text
先读取本地已有结果 → 判断是否足够 → 缺失才建议补跑
不凭空指定"基准数据"
不生成合成数据或伪结果
不把 COMSOL/LiveLink 作为自动化依赖
```

---

## 1. 当前项目主线

活跃主线为 **3D 实体尺子 + 真实 3D 空气域**：

```text
models/linear/acoustic_field_3d_air/
```

物理链条：

```text
3D solid ruler (linear elastic)
  → structural transient (sol2)
  → stored boundary acceleration
  → real 3D pressure acoustics transient (sol3)
  → mic pressure time series at 2 cm
```

当前默认参数（`outputs/linear/acoustic_field_3d_air/summary.json`）：

| 参数 | 值 |
|---|---|
| L_free | 0.20 m |
| b | 0.03 m |
| h | 0.002 m |
| 材料 | steel (ρ=7930, E=193e9, ν=0.29) |
| x0 | 0.85·L_free |
| J | 0.04 N·s |
| tau_imp | 2 ms (half_sine) |
| mic_offset | 0.02 m (z 方向, 位于 L_free/2) |
| air_radius | 0.12 m (球形辐射边界) |
| 耦合方式 | 严格顺序单向（结构→空气, 无反作用） |
| 阻尼 | Rayleigh (ζ≈0.015, f_low=40Hz, f_high=700Hz) |

---

## 2. 已有结果盘点

### 2.1 主线 3D 空气域 (单 case)

| 路径 | 完整度 |
|---|---|
| `outputs/linear/acoustic_field_3d_air/` | **完整** |

CSV：frequencies ✓, structure_probe_timeseries ✓, mode_shapes ✓, mic_pressure_timeseries ✓, impact_force_timeseries ✓, mic_pressure_fft ✓

在当前已扫描结果中，此 case 可作为默认线性基准。
如果后续发现参数更接近论文口径的完整 3D air case，应允许更新 baseline_selection_report.md。

### 2.2 钢尺扫描 (requested_3d_air_coarse_review_light)

Study root: `outputs/requested_3d_air_coarse_review_light/`

Figures: timbre 材料分布图 ✓, steel pitch 扫描图 ✓, steel sound pressure 扫描图 ✓, impulse force-time 图 ✓

| 扫描类型 | case 数 | CSV 完整 | 说明 |
|---|---|---|---|
| L_free 扫描 | 10, 14, 18, 22, 26 cm (5 cases) | ✓ 全部完整 | 含 imp/mic/struct/mode |
| b 扫描 | 1, 2, 3, 4, 5 cm (5 cases) | ✓ 全部完整 | |
| h 扫描 | 1, 2, 3, 4, 5 mm (5 cases) | ✓ 全部完整 | |
| x0_ratio 扫描 | 0.25, 0.5, 0.75 (3 cases) | ✓ 全部完整 | |
| J 扫描 | 0.02, 0.04, 0.06, 0.08 N·s (4 cases) | ✓ 全部完整 | |

**总计 22 个钢尺扫描 case，全部完整。可直接用于制图和论文。**

### 2.3 材料音色 (requested_3d_air_coarse_review_light)

| 材料 | CSV | summary |
|---|---|---|
| steel | ✓ 完整 | ✓ |
| PVC | ✓ 完整 | ✗ 缺 summary.json（仅 run_summary） |
| acrylic | ✓ 完整 | ✗ 缺 summary.json |
| satinwood (缎木) | ✓ 完整 | ✗ 缺 summary.json |
| xuefu_board (雪弗板) | ✓ 完整 | ✗ 缺 summary.json |

注意：非钢材料参数为工程近似值，不是实验测量值。

### 2.4 1D 梁 sweep (旧线，历史留存)

Study root: `outputs/linear/sweep/study_param_smoke_public_20260422/`

| case | CSV 完整 |
|---|---|
| baseline | ✓ |
| J=0.1N·s | ✓ |
| L_free=10cm | ✓ |
| x0_ratio=0.7 | ✓ |
| b=5cm | ✓ |
| h=5mm | ✓ |

此线为 1D Euler-Bernoulli 梁模型，不是 3D 实体尺子。仅作对比参考。

### 2.5 已有输出图表

在 `outputs/requested_3d_air_coarse_review_light/` 下：

```text
figures/timbre_material_frequency_distribution.png      ← 五材料频谱分布
figures/timbre_material_frequency_duration_panels.png   ← 各材料频率持续时间面板
figures/timbre_steel_frequency_duration.png             ← 钢尺频率持续时间
figures/steel_pitch_frequency_scan.png                  ← 钢尺音高扫描
figures/steel_sound_pressure_scan.png                   ← 钢尺声压扫描
figures/impulse_force_time.png                          ← 冲量力时程
```

论文级 CSV 表格在 `tables/article_csv/` 下，覆盖音色、音调、声压、冲量四大类。

---

## 3. 线性基准选择

### 3.1 基准 case

```text
outputs/linear/acoustic_field_3d_air/
```

理由：唯一有完整 summary.json（含 f1-f6、SPL、RMS、Q 等全量指标）的 3d_air case，参数最接近 PACKAGE_README 中描述的默认研究口径。

### 3.2 基准对照用途

```text
材料变化对比它；
麦克风距离变化对比它；
强敲击非线性变化对比它；
后续重跑也对比它。
```

---

## 4. 当前缺口与优先级

### P0：论文核心图表已有可用数据，但需正式盘点

已有 22 个 steel 扫描 case + 5 材料 case 的完整 CSV 和图表。Claude Code 应首先生成正式盘点报告，再据此判断缺口。

### P1：非钢材料 summary 补全

4 个材料 case 缺少 `summary.json`（PVC、acrylic、satinwood、xuefu_board）。这些 case 已有完整 CSV，MATLAB batch 模式可以直接补生成 summary。

约束：
- 若已有 manifest：直接运行 `run_matlab_model.ps1`。
- 若没有 manifest：不得凭空生成；应先根据已有 `output_root`、`config_path`、CSV 文件生成 review-only manifest，并在报告中标记为 `reconstructed`。

### P2：麦克风距离扩展

当前仅 2 cm 一个距离。如需研究距离衰减规律：

建议新增距离：4 cm, 6 cm, 8 cm, 10 cm（固定 steel, L_free=20cm, 其他不变）。

注意：
- 空气域半径需随 mic 距离增大（`air_radius >= mic_offset + 0.05 m`）
- 需要新的 COMSOL build（shell 阶段）+ MATLAB 后处理
- 建议用 coarse 质量先做趋势，确认无误再补 medium

### P3：几何非线性大振幅支线

目标：研究强敲击下线性模型失效边界。

```text
新建 models/nonlinear/large_deflection_structure/
先做结构-only（几何非线性开, 空气域关）
再做非线性声学
```

建议扫描：J = 0.01, 0.02, 0.04, 0.08, 0.12, 0.16 N·s

非线性判据：
```text
A_tip / L_free < 0.02：线性
0.02 ≤ A_tip / L_free < 0.05：轻微非线性
0.05 ≤ A_tip / L_free < 0.10：明显非线性
A_tip / L_free ≥ 0.10：大变形强非线性
```

### P4：材料参数实测验证

非钢材料（PVC、acrylic、satinwood、xuefu_board）的 E、ρ、ν 是工程近似值。如有条件，应替换为：
- 文献值（标注来源）
- 实测值（标注测量方法）
- 至少标注不确定性范围

---

---

## 5. 下一步最小执行清单

```text
1. 生成 docs/existing_results_inventory.md
2. 生成 outputs/_inventory/existing_results_inventory.csv
3. 生成 docs/baseline_selection_report.md
4. 检查 4 个非钢材料 summary 是否可由已有 CSV 补全（P1）
5. 给出 mic_distance 扩展的最小 case 配置建议（P2）
6. 给出 nonlinear structure-only 的目录和最小模型计划（P3）
```

---

## 6. Claude Code 自动化边界

### 可以自动做的事

```text
扫描 outputs/ 目录，盘点已有结果
读取 summary.json 提取指标
读取 CSV 做数据分析和绘图
运行 matlab -batch 对有 CSV 的 manifest 做后处理
生成盘点报告和对比表
运行 matlab 静态检查 (check_matlab_code)
运行 matlab 单元测试
检查 manifest/status 状态
```

### 不能默认自动做的事

```text
启动 COMSOL LiveLink（需交互式 MATLAB）
配置、修复或绕过 COMSOL 许可证
在没有 CSV 的 manifest 上运行 matlab -batch
```

以下操作需要用户明确授权且环境就绪后才允许：

```text
构建新的 COMSOL case（shell + comsolcompile + comsolbatch）
  前提：COMSOL_BIN 可用、许可证可用、目标 case 配置已生成
```

---

## 7. 关键文件路径速查

| 用途 | 路径 |
|---|---|
| 3D 空气域主线 | `outputs/linear/acoustic_field_3d_air/` |
| 基准 summary | `outputs/linear/acoustic_field_3d_air/summary.json` |
| 钢尺扫描汇总 | `outputs/requested_3d_air_coarse_review_light/` |
| 材料音色数据 | `outputs/requested_3d_air_coarse_review_light/cases/timbre_material/` |
| 论文 CSV 表 | `outputs/requested_3d_air_coarse_review_light/tables/article_csv/` |
| 输出图表 | `outputs/requested_3d_air_coarse_review_light/figures/` |
| MATLAB batch 方案 | `docs/MATLAB_BATCH_WORKFLOW.md` |
| COMSOL LiveLink 纠错 | `docs/MATLAB_BATCH_COMSOL_ERRATA.md` |
| MATLAB 用户流程 | `docs/MATLAB_USER_WORKFLOW.md` |

---

## 8. 一句话目标

**以本地已有 22 个 steel 扫描 case + 5 材料 case 为数据基础，优先用已有 CSV 生成论文所需图表和分析；只在明确缺失时补跑，不重跑已有结果。**
