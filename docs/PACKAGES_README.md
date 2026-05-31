# 服务器仿真包文档

> 更新: 2026-05-17 | 服务器: user@<your-linux-server>:~/comsol_work/the_singing_ruler/

---

## 包总览

| 包名 | 配置 JSON | 物理 | 关键修正 | 状态 | 输出目录 |
|---|---|---|---|---|---|
| base | `requested_cases.json` | 线性弹性 | eigen_shift=1Hz | ✅ | `materials_eigenfix` |
| combined | `materials_combined.json` | 线性弹性 | **阻尼+冲量** | ✅ | `materials_combined` |
| nonlinear | `materials_only.json` + gNL | 几何非线性 (Green-Lagrange) | 无 | ✅ | `materials_nonlinear` |
| adaptive | `requested_cases.json` | 线性弹性 (27 cases) | FFT 频率校正 | ✅ | `requested_adaptive` |
| hyperelastic | (待开发) | Neo-Hookean | — | ⏳ | — |

所有包共享同一套代码 (`the_singing_ruler_full_server_source/`)，通过不同 `--case-definition` JSON 文件区分仿真内容。

---

## COMSOL 模块

所有包使用相同的两个模块：

| 模块 | 接口 | 用途 |
|---|---|---|
| **Structural Mechanics** | Solid Mechanics (3D) | 尺子瞬态弹性动力学 |
| **Pressure Acoustics, Transient** | Pressure Acoustics (3D) | 空气域声压波传播 |

求解顺序：Eigenfrequency (sol1) → Structure Transient (sol2) → Acoustics Transient (sol3, 单向耦合)

---

## 1. base — 线性基准包

**已完成输出**: `outputs/materials_eigenfix/`

**物理**:
- 各向同性线弹性 + Rayleigh 阻尼 (ζ=0.015)
- 半正弦脉冲激励 (J=0.04 N·s, τ=2ms)
- 单向声-结构耦合
- **eigen_shift=1Hz** — 正确捕获所有 6 阶模态

**5 材料 × 1 几何 (L=20cm, b=3cm, h=2mm)**:

| 材料 | f₁ (Hz) | SPL (dB) | τ₁ (ms) | 探针峰值 (mm) |
|---|---|---|---|---|
| steel | 40.3 | 82.2 | 716 | 2.3 |
| PVC | 12.2 | 103.5 | 40 | 87.3 |
| acrylic | 13.4 | 103.7 | 34 | 92.1 |
| satinwood | 32.3 | 106.8 | 124 | 71.5 |
| xuefu_board | 7.9 | 112.1 | 15 | 248.7 |

**局限**: 所有材料使用相同 J=0.04 和 ζ=0.015。非钢材料 SPL 和位移均高得不切实际。

---

## 2. combined — 阻尼+冲量联合修正

**已完成输出**: `outputs/materials_combined/`

**物理修正**:

### 冲量修正 (Hertz 接触)
钢锤敲击不同材料时, 传递冲量取决于接触刚度:

$$J_\text{eff} = J_\text{steel} \times \left(\frac{E_\text{target}}{E_\text{steel}}\right)^{1/3}$$

物理机制: 软靶材 → 低接触刚度 → 更长的接触时间 → 更少的能量传入尺子 → 大部分能量随锤反弹。

### 阻尼修正 (材料损耗)
聚合物分子链内耗 >> 金属晶格内耗。文献损耗因子 η → 阻尼比 ζ = η/2。

| 材料 | ζ | J_eff (Ns) | J_scale | 修正依据 |
|---|---|---|---|---|
| steel | 0.015 | 0.0400 | 1.000 | 基准 |
| PVC | 0.07 | 0.0100 | 0.250 | η≈0.14 (PVC 文献), E=3.0GPa |
| acrylic | 0.06 | 0.0102 | 0.255 | η≈0.12 (PMMA 文献), E=3.2GPa |
| satinwood | 0.04 | 0.0087 | 0.218 | η≈0.08 (木材文献估算), E=2.0GPa |
| xuefu_board | 0.10 | 0.0062 | 0.154 | η≈0.20 (PVC 泡沫板估算), E=1.0GPa |

**结果**:

| 材料 | f₁ (Hz) | SPL (dB) | τ₁ (ms) | 探针峰值 (mm) |
|---|---|---|---|---|
| steel | 40.3 | 86.3 | 289 | 4.70 |
| PVC | 12.1 | 85.4 | ~1618* | 17.41 |
| acrylic | 13.5 | 86.6 | ~242* | 19.82 |
| satinwood | 13.8 | 91.0 | ~116* | 30.12 |
| xuefu_board | 8.2 | 87.7 | — | 23.94 |

> *Mode 1 τ₁ 在 fast 质量 (0.25s) 下 R² < 0.7，需延长 time_end 重跑获取可靠值

**关键发现**:
- 非钢材料 SPL 降低 18-24 dB (从 103-112 → 85-91 dB)，更符合实际
- 位移减小 5-10× (从 87-249 mm → 17-30 mm)
- 频率与线性基准一致 (f 不受 J, ζ 影响)

**局限**:
- fast 质量 time_end=0.25s 对低频谱 (f₁<15Hz) 太短
- ζ 值来自文献估算，非直接测量
- J_scale 的 E^(1/3) 是简化近似 (Hertz 球形接触)，实际方形锤头存在偏差

---

## 3. nonlinear — 几何非线性

**已完成输出**: `outputs/materials_nonlinear/`

**方法**: Solid Mechanics → "Include geometric nonlinearity" (Green-Lagrange 应变张量, 大变形)

**结论**:

| 材料 | 位移变化 (%) | f₁ 变化 (%) |
|---|---|---|
| steel | -3 | < 1 |
| PVC | -33 | < 1 |
| acrylic | -24 | < 1 |
| satinwood | -30 | < 1 |
| xuefu_board | -18 | < 1 |

- **频率不变**: 固有频率是线性特征值问题，与振幅无关
- **位移修正**: 非钢材料减少 18-33%，但单用不足以解释 5-10× 的大幅降低
- **结论**: 几何非线性有效但不够，需联合阻尼+冲量修正

**局限**: 钢尺 ε_yield ≈ 0.2%，在非线性显著之前已屈服。Green-Lagrange 适用于中等变形 (w/h < 5)。

---

## 4. adaptive — 27 例全扫描

**已完成输出**: `outputs/requested_adaptive/` (17 GB 服务器 / 53 MB 本地 CSV)

**实验设计**:

| 自变量 | 值 (5-5-5-5-4-5 设计) | 自适应质量 |
|---|---|---|
| L_free (cm) | 14, 17, 20, 23, 26 | fast (f ∝ 1/L²) |
| h (mm) | 0.5, 1.0, 2.0, 3.5, 5.0 | fast (f ∝ h) |
| material | steel, PVC, acrylic, satinwood, xuefu_board | fast (E, ζ sensitive) |
| b (cm) | 2, 3, 4, 5 | eco (弱依赖) |
| J (N·s) | 0.01, 0.02, 0.04, 0.08, 0.16 | eco (振幅 only) |
| x₀/L | 0.3, 0.5, 0.8, 0.95 | eco (振幅 only) |

**已知问题**:
- eigen_shift=1000Hz bug — 8/27 cases 低频谱丢失，已通过 FFT 校正 (`correct_frequencies_from_fft.m`)
- 非钢材料使用统一 J=0.04 和 ζ=0.015 (未修正)，SPL/位移偏大
- 使用校正表: `conclusion_master_table_corrected.csv`

**用于**: 钢尺参数扫描 (L, b, h, J, x₀) 的论文图表

---

## 5. hyperelastic — 超弹性 (待开发)

**状态**: ⏳ 低优先级

**原因**: 弯曲主导变形应变 < 5%，Neo-Hookean 在此范围内与线弹性几乎一致。仅在大变形 + 非线性材料 (如橡胶) 场景下有必要。

---

## 质量档位对照

| 参数 | full | medium | fast | eco |
|---|---|---|---|---|
| mesh_numelem | 80 | 60 | 40 | 30 |
| time_end (s) | 0.5 | 0.35 | 0.25 | 0.15 |
| time_step (s) | 5e-5 | 1e-4 | 2e-4 | 5e-4 |
| 单 case (min) | ~180 | ~90 | ~25 | ~5 |

**自适应策略**:
- `fast`: 频率/衰减敏感参数 (material, L, h) — 需要足够频谱精度
- `eco`: 纯振幅参数 (b, J, x₀) — 只需幅值信息

---

## 运行命令

```bash
# 单 case
cd ~/comsol_work/the_singing_ruler/the_singing_ruler_full_server_source
./run_single_full.sh --study-id my_test

# 批处理 — combined 材料 (5 cases × 12 cores)
python3 -B tools/run_requested_full.py \
  --study-id materials_combined \
  --case-definition config/materials_combined.json \
  --quality fast --max-parallel 5 --comsol-np 12

# 批处理 — 自适应 27 cases
python3 -B tools/run_requested_full.py \
  --study-id requested_adaptive \
  --case-definition config/requested_cases.json \
  --adaptive --max-parallel 5 --comsol-np 12

# Dry-run 预览 (不调用 COMSOL)
python3 -B tools/run_requested_full.py --study-id preview --dry-run
```

---

*维护者: ldaniel | 更新: 2026-05-17*
