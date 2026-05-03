---
audience: agent
agent-priority: high
last-reviewed: 2026-05-02
context-budget: 6KB
agent-summary: "当前项目状态与目标清单：活跃主线、已有结果盘点、缺口优先级、下一步执行清单。数据完整性规则见 docs/rules/RULES_OUTPUT.md"
---

# 项目运行目标

> 生成日期：2026-05-02
> 数据来源：本地 `outputs/` 实际扫描结果
> **输出规则见 `docs/rules/RULES_OUTPUT.md`。**
> **通用流水线架构见 `docs/WORKFLOW_ARCHITECTURE.md`。**

---

## 1. 活跃主线

**3D 实体尺子 + 真实 3D 空气域：**

```text
models/linear/acoustic_field_3d_air/
```

物理链条：3D solid ruler → structural transient (sol2) → stored boundary acceleration → real 3D pressure acoustics transient (sol3) → mic pressure time series

当前默认参数：

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
| 阻尼 | Rayleigh (ζ≈0.015, f_low=40Hz, f_high=700Hz) |

## 2. 已有结果

### 2.1 主线 3D 空气域（单 case）

| 路径 | 完整度 |
|---|---|
| `outputs/linear/acoustic_field_3d_air/` | **完整**（CSV 全、summary.json 全）|

### 2.2 钢尺扫描（22 cases 全部完整）

扫描根：`outputs/requested_3d_air_coarse_review_light/`

| 扫描 | cases | CSV 状态 |
|---|---|---|
| L_free | 10/14/18/22/26 cm（5）| 全部完整 |
| b | 1/2/3/4/5 cm（5）| 全部完整 |
| h | 1/2/3/4/5 mm（5）| 全部完整 |
| x0_ratio | 0.25/0.5/0.75（3）| 全部完整 |
| J | 0.02/0.04/0.06/0.08 N·s（4）| 全部完整 |

### 2.3 材料音色（5 材料）

| 材料 | CSV | summary.json |
|---|---|---|
| steel | 完整 | 有 |
| PVC | 完整 | **缺** |
| acrylic | 完整 | **缺** |
| satinwood | 完整 | **缺** |
| xuefu_board | 完整 | **缺** |

### 2.4 已有输出图表

```text
figures/timbre_material_frequency_distribution.png
figures/timbre_material_frequency_duration_panels.png
figures/timbre_steel_frequency_duration.png
figures/steel_pitch_frequency_scan.png
figures/steel_sound_pressure_scan.png
figures/impulse_force_time.png
```

论文级 CSV 表在 `tables/article_csv/`，覆盖音色、音调、声压、冲量。

## 3. 优先级

| 优先级 | 项目 | 状态 |
|---|---|---|
| P0 | 论文核心图表已有可用数据，需正式盘点 | 待生成盘点报告 |
| P1 | 非钢材料 summary.json 补全（4 材料已有 CSV）| 待补 |
| P2 | 麦克风距离扩展（4/6/8/10 cm）| 需新 COMSOL build |
| P3 | 几何非线性大振幅支线 | 需新模型 |
| P4 | 材料参数实测验证 | 需文献/实验值 |

## 4. 当前重点

**以本地已有 22 个 steel 扫描 case + 5 材料 case 为数据基础，优先用已有 CSV 生成论文所需图表和分析；只在明确缺失时补跑，不重跑已有结果。**
