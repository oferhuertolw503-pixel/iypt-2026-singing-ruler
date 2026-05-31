# 音色增强 Medium 仿真分析报告

> 数据根目录：`outputs/requested_timbre_complete_enhanced_medium`
> 分析脚本：`matlab/report/timbre_enhanced_analysis.m`
> 生成日期：2026-05-04

---

## 1. 数据口径

本轮音色分析使用 5 种材料、2 个冲量水平，共 10 个完整 3D air case。所有 case 均已完成 COMSOL 求解、MATLAB 高精度派生指标、tip/Q 验收和扩展音色指标输出。

| 参数 | 值 |
|---|---|
| 时间窗 | 0.75 s |
| 时间步 | 1e-4 s |
| 网格控制 | 100 elem |
| 模态点数 | 241 |
| 低频模态 | `eigen_shift=20 Hz` |
| 主结论冲量 | `J_low=0.004 N·s` |
| 对照冲量 | `J_orig=0.04 N·s` |

`J_low` 用作论文主结论来源；`J_orig` 仅用于诊断冲量放大后的线性风险和与旧结果的可比性。

---

## 2. 低冲量主结论

| 材料 | f_dom (Hz) | SPL (dB) | 频谱质心 (Hz) | 平坦度 | Q | probe_peak/L | 用途 |
|---|---:|---:|---:|---:|---:|---:|---|
| Steel | 39.7 | 62.0 | 67.4 | 0.0066 | 67.9 | 0.002 | 主结论 |
| Acrylic | 13.5 | 81.0 | 140.2 | 0.0161 | 29.6 | 0.044 | 主结论 |
| PVC | 12.1 | 80.7 | 235.0 | 0.0255 | 28.6 | 0.042 | 主结论 |
| Satinwood | 32.1 | 82.8 | 62.1 | 0.0053 | 55.1 | 0.034 | 主结论 |
| Xuefu board | 8.2 | 88.2 | 800.3 | 0.0615 | 31.1 | 0.119 | 降级解释 |

结论：Steel、Acrylic、PVC 和 Satinwood 的低冲量结果满足线性阈值，可作为材料音色主结论。Xuefu board 即使在低冲量下仍接近非线性风险区，应作为降级解释或诊断性材料案例。

---

## 3. 冲量敏感性

`J_orig` 相对 `J_low` 的 SPL 增益约 19.5–20.0 dB，符合冲量放大导致声压级增加的预期。但除 Steel 外，其余材料在原始冲量下均出现明显非线性风险：

| 材料 | SPL 增益 (dB) | 主频偏移 (Hz) | 原始冲量线性状态 |
|---|---:|---:|---|
| Steel | 20.0 | 0.3 | linear |
| Acrylic | 19.5 | 0.0 | nonlinear_risk |
| PVC | 19.6 | 0.0 | nonlinear_risk |
| Satinwood | 20.0 | 0.1 | nonlinear_risk |
| Xuefu board | 19.7 | 267.9 | nonlinear_risk |

因此，原始冲量结果不再用于材料音色主结论，只保留为“冲量过大时线性假设失效”的诊断证据。

---

## 4. 生成文件

表格位于 `outputs/requested_timbre_complete_enhanced_medium/tables/paper_analysis/`：

| 文件 | 内容 |
|---|---|
| `timbre_enhanced_summary.csv` | 10 case 全量汇总 |
| `timbre_lowJ_primary_summary.csv` | 5 材料低冲量主结论表 |
| `timbre_J_sensitivity.csv` | 双冲量差异与线性风险 |

图表位于 `outputs/requested_timbre_complete_enhanced_medium/figures/paper_analysis/`：

| 文件 | 内容 |
|---|---|
| `timbre_lowJ_material_map.png` | 低冲量音色空间图 |
| `timbre_lowJ_energy_bands.png` | 低/中/高频能量比例 |
| `timbre_lowJ_q_frequency.png` | 主频与 Q 因子对比 |
| `timbre_J_sensitivity.png` | 冲量增益与线性风险 |

---

## 5. 论文使用口径

论文中应写“仿真频谱音色代理指标”，不要写成完整的人耳听觉音色。当前可用指标包括主频、SPL、频谱质心、频谱平坦度、频带能量比例、谱峰数量、主峰/次峰比、Q 因子和衰减时间。

推荐结论表述：

> 增强 medium 低冲量仿真表明，材料会显著改变尺子辐射声的频谱代理音色指标。Steel 和 Satinwood 的频谱质心较低、平坦度较小，表现为低频离散谱峰主导；Acrylic 和 PVC 主频较低但频谱质心更高，说明中高频成分占比更大；Xuefu board 的频谱质心和平坦度最高，但其低冲量响应仍接近非线性边界，因此仅作为降级解释。

---

## 6. 限制

- 当前材料参数仍来自模型设定，未进行独立实验测量。
- 当前音色分析未包含 A-weighting、Bark/Mel、听觉掩蔽或真人听感实验。
- Xuefu board 的线性边界仍不理想，若要作为强结论，需要进一步降低冲量或采用非线性分支验证。
- `outputs/` 保持本机保存，不入 Git；本报告只记录分析口径和可追溯文件名。
