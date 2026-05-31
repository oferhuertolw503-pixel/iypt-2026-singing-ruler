# 材料对比数据审计报告

> 本报告对所有已使用数据进行逐 case 审计，标记数据源、时间窗口、物理量一致性。
> 审计结果用于修正材料对比结论和数据标注。

---

## 1. 关键发现

### 1.1 数据源标签大面积错误

| 数据来源 | 原先误标 | 审计后实际品质 | 时间窗 | dt | 点数 |
|---|---|---|---|---|---|
| 27 case 钢尺扫描 (J/L_free/b/h/x0) | coarse | **coarse** | 0–0.10 s | 1e-3 s | 101 |
| 5 timbre material (acrylic/PVC/steel/...) | coarse | **实际是 medium 参数** | 0–0.50 s | 2e-4 s | 2501 |
| 5 medium 补算 case (baseline/L_free/...) | medium | **medium** | 0–0.50 s | 2e-4 s | 2501 |

**结论：** timbre_material 的 5 个 case 虽然在 "coarse_review" 数据集下，但其 `params_resolved.json` 显示 `time_end=0.5[s]`、`time_step=2e-4[s]`、`numelem=80`，实际为 medium 品质。不应再称其为 "coarse"。

### 1.2 f_dom 与第一阶特征频率的差距

| Case | f_dom_refined (Hz) | 第 1 阶 eigenfrequency (Hz) | 差距 (Hz) | 说明 |
|---|---|---|---|---|
| Acrylic | 13.5 | 521.1 | **508** | 声学主频远低于 eigen 最低模态 |
| PVC | 12.1 | 462.3 | **450** | 同上 |
| Satinwood | 32.1 | 201.4 | **169** | 声学主频低于 eigen 最低模态 |
| Steel (timbre) | 40.1 | 40.3 | **0.2** | 声学主频 = 结构基频 ✅ |
| Xuefu board | 276.5 | 681.6 | **405** | 声学主频低于 eigen 最低模态 |
| baseline_steel_medium | 40.2 | 40.3 | **0.1** | ✅ |
| **L_free_26cm_medium** | **144.8** | 350.7 | **206** | ⚠️ |
| x0_ratio_0p5_medium | 246.5 | 40.3 | **206** | 声学主导为高阶模态 (244–249 Hz) |
| b_5cm_medium | 40.4 | 253.2 | **213** | 声学主频 40 Hz 未被 eigen 分析捕获 |

**结论：** **只有 Steel 的基频被 eigenfrequency solver 捕获。** 其余材料 × b_5cm × L_free_26cm 的声学主频与 eigen 分析的最低模态之间有 169–508 Hz 的差距。原因是 COMSOL 模板中 `eig.shift=1000[Hz]` 使求解器偏向搜索 1 kHz 附近的模态，低阶弯曲模态被跳过。模态匹配算法虽然显示 "6 阶匹配"，但匹配的是 400–1400 Hz 的高阶模态，而非决定声学输出的主导模态。

### 1.3 L_free_26cm_medium f_dom 偏移

| 数据源 | f_dom_refined | 解释 |
|---|---|---|
| Coarse L_free_26cm (0.10s, dt=1ms) | **23.8 Hz** | 短窗仅捕捉到基频弯曲模态 |
| Medium L_free_26cm (0.50s, dt=0.2ms) | **144.8 Hz** | 长窗揭示 144.8 Hz 声学峰值幅度是 23.8 Hz 的 2× |

**结论：** 两者都正确。Coarse 数据因窗口短、频率分辨率粗 (2.4 Hz/bin)，144.8 Hz 峰的幅度被低估。Medium 数据用更精细的网格和更长窗口揭示了实际声辐射中 144.8 Hz 成分占主导。L_free_26cm 的结论必须绑定所用数据源，不能混用。

---

## 2. 审计表

| case | data_group | quality | t_range | n_pts | dt(s) | f_dom(Hz) | f1_eig(Hz) | gap | fft_res | q_source | has_tip | eigen_notes |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| acrylic | timbre_material | medium_params | 0–0.50 | 2501 | 2e-4 | 13.5 | 521.1 | 508 | 0.305 | missing_tip | N | shift=1000Hz 跳过基频 |
| pvc | timbre_material | medium_params | 0–0.50 | 2501 | 2e-4 | 12.1 | 462.3 | 450 | 0.305 | missing_tip | N | shift=1000Hz 跳过基频 |
| satinwood | timbre_material | medium_params | 0–0.50 | 2501 | 2e-4 | 32.1 | 201.4 | 169 | 0.305 | missing_tip | N | shift=1000Hz 跳过基频 |
| steel | timbre_material | medium_params | 0–0.50 | 2501 | 2e-4 | 40.1 | 40.3 | 0.2 | 0.305 | missing_tip | N | 正常匹配 |
| xuefu_board | timbre_material | medium_params | 0–0.50 | 2501 | 2e-4 | 276.5 | 681.6 | 405 | 0.305 | missing_tip | N | shift=1000Hz 跳过基频 |
| baseline_steel | medium_5case | medium | 0–0.50 | 2501 | 2e-4 | 40.2 | 40.3 | 0.1 | 0.305 | tip | Y | ✅ 全链路 |
| L_free_26cm | medium_5case | medium | 0–0.50 | 2501 | 2e-4 | **144.8** | 350.7 | 206 | 0.305 | tip | Y | f_dom≠粗窗值，已确认 |
| x0_ratio_0p5 | medium_5case | medium | 0–0.50 | 2501 | 2e-4 | 246.5 | 40.3 | 206 | 0.305 | tip | Y | 高阶模态主导声学输出 |
| b_5cm | medium_5case | medium | 0–0.50 | 2501 | 2e-4 | 40.4 | 253.2 | 213 | 0.305 | tip | Y | 声学主频 40Hz 非 eigen 模态 |
| xuefu_board | medium_5case | medium | 0–0.50 | 2501 | 2e-4 | 276.6 | 681.6 | 405 | 0.305 | tip | Y | 同 timbre 版 |

---

## 3. 修正后的结论体系

### 3.1 材料音色对比（数据源：5 timbre material, medium_params, n=2500/s）

图片：`material_timbre_coarse.png` → 改名为 `material_timbre_map.png`（数据实际上已是 medium_params）

- 5 材料在主频、频谱质心、频谱平坦度上形成可区分聚类 ✅
- 频谱质心 47.9–353.5 Hz，平坦度 0.0008–0.0187 ✅
- 所有数据实际为 0.50s 窗口，DT=2e-4s，FFT 分辨率 0.305 Hz ✅
- **结论强度：strong**（数据品质好，5 材料差异明显）

### 3.2 Q 因子验证（数据源：5 medium 补算 case, medium, 含 tip）

图片：`medium_q_decay_validation.png`

- 5 case 均成功获取 tip CSV → q_source="tip"
- Q 值范围：38.5 (xuefu) – 96.4 (x0_ratio)
- **结论强度：strong**（5 case 全链路验证通过，但仍为代表 case 非全量）

### 3.3 Eigenfrequency shift 影响（数据源：全部 10 case 的 acoustic_metrics + frequencies.csv）

图片：`eigen_acoustic_gap_materials.png`

- **仅 steel 的声学主频与第一阶 eigenfrequency 一致**（差距 < 1 Hz）
- 其余材料/几何的差距为 169–508 Hz
- 原因：`eig.set("shift", "1000[Hz]")` 使求解器偏向 1 kHz 邻域
- 模态匹配的 "6 阶" 匹配的是 350–1400 Hz 的结构模态，非声学主导模态
- **结论强度：moderate**（诊断性发现，需调整 eigen 求解器设置后验证）

### 3.4 L_free_26cm 频率偏移（数据源：coarse L_free_26cm + medium L_free_26cm）

- Coarse (0.10s): f_dom=23.8 Hz → 短窗基频主导
- Medium (0.50s): f_dom=144.8 Hz → 长窗揭示 144.8 Hz 是更强声学成分
- 两者皆非错误，但在论文中必须注明数据源和窗口差异
- **结论强度：moderate**（物理上有解释，但令人意外，需在论文中明确说明）

---

## 4. 论文表述修正

### 4.1 材料音色段落

原先错误："由于 coarse 分辨率，高频区域能量分布可能不准确"
修正后：数据来自 0.50s / 2e-4s 参数（实际为 medium 品质），FFT 分辨率 0.305 Hz，高频段解析充分

### 4.2 频带衰减文字

原先错误：将 timbre 材料数据标为 coarse 并混入 medium 补算结论
修正后：5 材料对比仅用 5 个 timbre medium_params case；衰减趋势单独标注数据源

### 4.3 L_free 扫描中的 L_free_26cm

原先：将 coarse 的 23.8 Hz 与 medium tip Q=42.1 并列
修正后：必须标注 coarse (23.8 Hz, 0.10s) vs medium (144.8 Hz, 0.50s) 为两个独立数据点

---

*本审计报告同时作为 `PAPER_DRAFT_RESULTS_DISCUSSION_ZH.md` 中材料相关段落的修正依据。所有涉及材料对比的结论需根据本审计表重写。*
