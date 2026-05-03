# Medium 品质补算计划：Tip/Q 因子与频带衰减验证

> 生成日期：2026-05-03
> 目标：补强论文结果与讨论中的两个局限项（Q 因子缺失、频带衰减仅为初步证据）
> 策略：少量代表 case + medium 优先，验证链路后视需要扩展

---

## 1. 补算目标

当前 27 个 coarse case 的分析表明两个关键局限：

1. **Q 因子缺失**：无 `tip_timeseries.csv`，所有 case 的 `q_source = "missing_tip"`，`q_estimate = NaN`。
2. **频带衰减仅为初步证据**：0.10 s 时间窗不足，STFT 衰减估计受截断效应影响。

本次补算通过以下修改解决：

- **Java 模板**：新增 `cptTip` 探针（`x=L_free, y=0, z=0`）输出 `data/tip_timeseries.csv`，列为 `t_s, w_m`
- **5 个代表 case**：覆盖不同几何/材料场景，使用 medium 品质（0.5 s / 2e-4 s）
- **验收函数**：`validate_medium_tip_decay_outputs` 专检 tip/Q/decay 链路

### 预期论文收益

| 局限 | 补算后状态 | 论文表述 |
|---|---|---|
| Q 因子缺失 | 至少 5 个 case 有 `q_estimate` | "对于代表性几何和材料，实测 Q 在 X–Y 范围" |
| 频带衰减初步 | 可验证 0.5 s 窗口下衰减趋势 | "中品质数据表明高频衰减趋势与粗品质一致/不一致" |
| 方法可靠性 | tip 数据可用后 q_source=tip | "仿真后处理链路经 tip 数据验证" |

---

## 2. 新增/修改文件清单

| 文件 | 修改类型 | 说明 |
|---|---|---|
| `models/.../Linear_Acoustic_Field_3D_Air.java` | 修改 | 添加 `cptTip` + `exportPointCsv` 导出 tip_timeseries.csv |
| `models/.../run.ps1` | 修改 | CSV header normalizer 增加 tip_timeseries.csv |
| `matlab/validate/validate_medium_tip_decay_outputs.m` | 新增 | 专用验收函数 |
| `docs/reports/MEDIUM_TIP_DECAY_RERUN_PLAN_ZH.md` | 新增 | 本计划文档 |
| `outputs/requested_medium_tip_decay_validation/*/` | 新增（未跟踪） | 补算输出 |

---

## 3. 首批 5 个代表 Case

### 选取原则

1. 覆盖全部 6 组扫描参数中的 5 组（J 扫描因不影响 Q/衰减，优先级最低）
2. 每个 case 的地理和材料参数选择最极端或最具代表性的水平
3. 整个补算总耗时控制在使用 medium 品质 × 5 case 的合理范围

### Case 配置

#### Case 1: `baseline_steel_medium`

| 参数 | 值 | 说明 |
|---|---|---|
| L_free | 0.20 m | 默认自由段长度 |
| b | 0.03 m | 默认宽度 |
| h | 0.002 m | 默认厚度 |
| E | 193 GPa | 钢 |
| rho | 7930 kg/m³ | 钢 |
| x0 | 0.85 * L_free | 默认敲击位置 |
| J | 0.04 Ns | 默认脉冲 |

**选择理由**：基准对照。与现有 coarse 数据中 J_0p04Ns / b_3cm / h_2mm / L_free_18cm 对应，便于 direct medium-vs-coarse 对比。

#### Case 2: `L_free_26cm_medium`

| 参数 | 值 | 说明 |
|---|---|---|
| L_free | 0.26 m | 最长自由段 |
| 其余 | 同 baseline | |

**选择理由**：最长自由段 → 最低主频 (23.8 Hz)。衰减时间最长，最能检验 medium 时间窗 (0.5 s) 是否足够捕获完整衰减。

#### Case 3: `x0_ratio_0p5_medium`

| 参数 | 值 | 说明 |
|---|---|---|
| x0 | 0.5 * L_free | 中点敲击 |
| 其余 | 同 baseline | |

**选择理由**：中点敲击产生最高 SPL (102.3 dB)，激发约 245 Hz 高阶模态。高频模态衰减更快，适合验证 band_decay 的中高频段。

#### Case 4: `b_5cm_medium`

| 参数 | 值 | 说明 |
|---|---|---|
| b | 0.05 m | 最宽尺子 |
| 其余 | 同 baseline | |

**选择理由**：宽梁 (b ≥ 4 cm) 时模态匹配误差升至 5.20%。验证 medium 品质下匹配质量是否改善，以及宽梁的 Q 值与窄梁的差异。

#### Case 5: `material_xuefu_board_medium`

| 参数 | 值 | 说明 |
|---|---|---|
| L_free | 0.20 m | — |
| b | 0.03 m | — |
| h | 0.002 m | — |
| E | 0.7 GPa | 学府板等效杨氏模量 |
| rho | 700 kg/m³ | 学府板密度 |
| nu | 0.35 | 泊松比 |
| x0 | 0.8 * L_free | 与原始 coarse case 一致 |
| J | 0.04 Ns | — |

**选择理由**：材料差异最大的 case（主频 276.5 Hz，6.9× 钢）。检验 tip 探针在极高频率下的求值稳定性，以及 band_decay 在高频段的表现。

---

## 4. 运行命令模板

### 4.1 编译与求解（COMSOL Batch）

```powershell
# Baseline
powershell -ExecutionPolicy Bypass -File .\models\linear\acoustic_field_3d_air\run.ps1 `
  -Quality medium `
  -OutputRoot outputs\requested_medium_tip_decay_validation\baseline_steel_medium

# L_free_26cm（需自定义 config，覆盖 L_free）
powershell -ExecutionPolicy Bypass -File .\models\linear\acoustic_field_3d_air\run.ps1 `
  -Quality medium `
  -ConfigPath outputs\requested_medium_tip_decay_validation\configs\L_free_26cm_medium.json `
  -OutputRoot outputs\requested_medium_tip_decay_validation\L_free_26cm_medium

# x0_ratio_0p5（需自定义 config，覆盖 x0）
powershell -ExecutionPolicy Bypass -File .\models\linear\acoustic_field_3d_air\run.ps1 `
  -Quality medium `
  -ConfigPath outputs\requested_medium_tip_decay_validation\configs\x0_ratio_0p5_medium.json `
  -OutputRoot outputs\requested_medium_tip_decay_validation\x0_ratio_0p5_medium

# b_5cm（需自定义 config，覆盖 b）
powershell -ExecutionPolicy Bypass -File .\models\linear\acoustic_field_3d_air\run.ps1 `
  -Quality medium `
  -ConfigPath outputs\requested_medium_tip_decay_validation\configs\b_5cm_medium.json `
  -OutputRoot outputs\requested_medium_tip_decay_validation\b_5cm_medium

# xuefu_board（需自定义 config，覆盖 material）
powershell -ExecutionPolicy Bypass -File .\models\linear\acoustic_field_3d_air\run.ps1 `
  -Quality medium `
  -ConfigPath outputs\requested_medium_tip_decay_validation\configs\material_xuefu_board_medium.json `
  -OutputRoot outputs\requested_medium_tip_decay_validation\material_xuefu_board_medium
```

### 4.2 MATLAB 后处理

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath outputs\requested_medium_tip_decay_validation\baseline_steel_medium\logs\acoustic_field_3d_air_matlab_manifest.json
```

（其余 case 同理替换 ManifestPath 中的 case 名称。）

### 4.3 验收命令

```matlab
% 基础验收（格式 + 精度）
validate_derived_metrics_output(...
  'outputs/requested_medium_tip_decay_validation/baseline_steel_medium', ...
  RequirePrecision=true)

% 专项验收（tip/Q/decay）
validate_medium_tip_decay_outputs(...
  'outputs/requested_medium_tip_decay_validation/baseline_steel_medium')
```

---

## 5. 自定义 Config 文件

对于非默认参数的 case，需创建 JSON 配置文件。示例（`b_5cm_medium.json`）：

```json
{
  "model": "linear_acoustic_field_3d_air",
  "geometry": {
    "L_free": "0.20[m]",
    "b": "0.05[m]",
    "h": "0.002[m]"
  },
  "material": {
    "rho": "7930[kg/m^3]",
    "E": "193e9[Pa]",
    "nu": "0.29"
  },
  "excitation": {
    "x0": "0.85*L_free",
    "J": "0.04[N*s]"
  },
  "damping": {
    "zeta_struct": "0.015"
  },
  "mesh": {
    "numelem": 80
  }
}
```

各 case 的 config 差异字段：

| Case | 覆盖字段 | 值 |
|---|---|---|
| baseline_steel_medium | （使用默认 config） | — |
| L_free_26cm_medium | geometry.L_free | "0.26[m]" |
| x0_ratio_0p5_medium | excitation.x0 | "0.5*L_free" |
| b_5cm_medium | geometry.b | "0.05[m]" |
| material_xuefu_board_medium | material.rho / E / nu | "700[kg/m³]" / "0.7e9[Pa]" / "0.35" |

---

## 6. 验收标准

### 6.1 必须满足（硬条件）

| 检查项 | 方法 | 条件 |
|---|---|---|
| run.ps1 正常退出 | 无 PowerShell 异常 | exit code 0 |
| MPH 文件生成 | `Assert-NewerThan` | 出现在 `mph/` 目录 |
| frequencies.csv 导出 | `Assert-NewerThan` | 出现在 `data/` 目录 |
| **tip_timeseries.csv 导出** | `Assert-NewerThan` | **出现在 `data/` 目录** |
| MATLAB 后处理完成 | `run_matlab_model.ps1` | 正常退出 |
| `validate_derived_metrics_output(RequirePrecision=true)` | format_pass=1, precision_pass=1 | **PASS** |
| **`validate_medium_tip_decay_outputs`** | 专用验收 | **PASS** |

### 6.2 专项验收条件（来自 `validate_medium_tip_decay_outputs`）

| 字段 | 要求 |
|---|---|
| `tip_exists` | 1 |
| `tip_has_data` | 1（≥ 3 行数据） |
| `q_source_valid` | 1（q_source ≠ "missing_tip"） |
| `q_estimate_valid` | 1（有限且 > 0） |
| `log_decrement_valid` | 1（有限且 > 0） |
| `tip_peak_valid` | 1（有限且 > 0） |
| `band_decay_exists` | 1 |
| `band_decay_has_bands` | 1（≥ 4 个频带） |
| `pass` | 1（全部通过） |

### 6.3 辅助验证（非硬条件，但建议记录）

| 检查项 | 方法 | 预期 |
|---|---|---|
| q_estimate 量级合理性 | 与 zeta_struct=0.015 对比 | Q ≈ 1/(2ζ) ≈ 33 |
| band_decay_status | 检查 summary.json | 非 `preliminary_coarse_time_window` |
| medium vs coarse 主频偏差 | 与现有 coarse 数据对比 | < 5%（粗网格偏差） |
| tip_peak 与 probe_peak 比例 | tip / probe 位移幅值 | tip ≈ (2–5)× probe |

---

## 7. 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|---|---|---|---|
| COMSOL 许可证不可用 | 中 | 无法运行 | 计划阶段不需许可证，运行前确认 |
| `cptTip` 边界点求值失败 | 低 | tip CSV 为空或 NaN | Java 模板已备 `L_free-1e-6[m]` 回退方案 |
| medium 网格使求解超时 | 低 | 时间成本增加 | numelem=80 已在 xuefu_board coarse 中验证 |
| MATLAB 后处理不识别 tip_csv | 低 | q_source 仍为 missing_tip | `run_derived_metrics.m` 已有 tip 检测逻辑；补充 `run_matlab_model.ps1` 重跑 |
| 5 个 case 总耗时超出预期 | 中 | 占用开发时间 | 先从 baseline_steel_medium 开始，通过后再继续 |

---

## 8. 运行顺序建议

```
第 1 步：baseline_steel_medium
  → 验证 tip 导出、Q 估计、band_decay 全链路
  → 通过后进入第 2 步

第 2 步：L_free_26cm_medium + x0_ratio_0p5_medium
  → 验证长衰减 + 高频衰减场景
  → 通过后进入第 3 步

第 3 步：b_5cm_medium + material_xuefu_board_medium
  → 验证宽梁 + 高刚度材料的 tip 和 decay
  → 全部验收通过后生成汇总报告
```

---

## 9. Medium 品质参数确认

| 参数 | Coarse（现有） | Medium（本次补算） |
|---|---|---|
| mesh_numelem | 40 | 80 |
| time_end | 0.10 s | **0.5 s** |
| time_step | 1e-3 s | **2e-4 s** |
| mode_points | 61 | 161 |
| 频率分辨率（约） | 10 Hz | **2 Hz** |
| FFT 点数（×4 padding） | ~400 | **~10,000** |

Medium 品质的 5× 时间窗长和 5× 采样率提升将使：
- 频带衰减的 STFT 窗长可以覆盖更多振荡周期，衰减估计更可靠
- Q 因子估计有足够的衰减周期数（> 10 个周期）以获得稳定结果
- 模态匹配因频率分辨率提升（10 Hz → 2 Hz）而更精确

---

## 10. 验收后工作

1. 更新 `PAPER_ANALYSIS_27_CASE_ZH.md`：在 Band Decay 和 Q 因子章节增加 medium 验证结果
2. 新增 medium vs coarse 对比图表（`figures/paper_analysis/` 本地）
3. 更新 `PAPER_DRAFT_RESULTS_DISCUSSION_ZH.md`：补充 medium 品质结论
4. 若需额外 case，参考首批结果决定是否扩展到全部 27 个 case

---

*本文档供 Co 参考，不包含实际运行命令的执行记录。配置文件和自定义 JSON 由用户/Co在运行时创建。*
