# 唱歌的尺子 — 项目总体文档

> 版本: 2026-05-17 | 语言: 简体中文 | 目标: 物理竞赛论文级文档

---

## 目录

1. [研究目标](#1-研究目标)
2. [物理模型](#2-物理模型)
3. [COMSOL 模块与求解架构](#3-comsol-模块与求解架构)
4. [仿真包体系](#4-仿真包体系)
5. [参数空间与实验设计](#5-参数空间与实验设计)
6. [关键结果](#6-关键结果)
7. [局限性与已知问题](#7-局限性与已知问题)
8. [未来计划](#8-未来计划)
9. [数据产物清单](#9-数据产物清单)

---

## 1. 研究目标

**核心问题**：一把钢尺在受到脉冲敲击后，振动如何通过空气传播为人耳可闻的声音？材料的更换、几何参数的改变如何影响音调、响度和音色？

**研究维度**：

| 维度 | 物理量 | 自变量 |
|---|---|---|
| 音调 (Pitch) | 固有频率 f₁~f₆ | 自由端长度 L, 厚度 h, 材料 E/ρ |
| 响度 (Loudness) | SPL (声压级) | 冲量 J, 撞击位置 x₀, 麦克风距离 d |
| 音色 (Timbre) | 频谱质心、平坦度、滚降 | 材料 (E, ρ, ζ) |
| 衰减 (Decay) | 模态时间常数 τₙ | 材料阻尼 ζ, 模态阶数 n |
| 空间衰减 | SPL vs 距离 | 麦克风距离 d (0.02–0.10 m) |

---

## 2. 物理模型

### 2.1 结构域 — 弹性尺子

**控制方程** (3D 线弹性动力学):

$$\rho \frac{\partial^2 \mathbf{u}}{\partial t^2} = \nabla \cdot \mathbf{S} + \mathbf{F}$$

其中 $\mathbf{S}$ 为应力张量 (各向同性 Hooke 定律)，$\rho$ 为密度，$\mathbf{u}$ 为位移场。

**本构关系** (各向同性线弹性):

$$\sigma = \frac{E}{1+\nu}\varepsilon + \frac{\nu E}{(1+\nu)(1-2\nu)}\text{tr}(\varepsilon)\mathbf{I}$$

**边界条件**:
- 固定端 (x=0): $\mathbf{u} = \mathbf{0}$ (理想固支)
- 自由端 (x=L): $\mathbf{S} \cdot \mathbf{n} = \mathbf{0}$
- 其他表面: 自由边界

**Rayleigh 阻尼** (结构):

$$\mathbf{C} = \alpha \mathbf{M} + \beta \mathbf{K}$$

其中 $\zeta_n = \frac{\alpha}{2\omega_n} + \frac{\beta\omega_n}{2}$。实际配置简化为单一 $\zeta$ 等效值。

### 2.2 声学域 — 空气压力声学

**控制方程** (瞬态压力声学, 波动方程):

$$\frac{1}{\rho_a c_a^2}\frac{\partial^2 p}{\partial t^2} + \nabla \cdot \left(-\frac{1}{\rho_a}\nabla p\right) = 0$$

其中 $p$ 为声压, $\rho_a = 1.225~\text{kg/m}^3$, $c_a = 343~\text{m/s}$。

**辐射边界条件** (球面):

$$\mathbf{n} \cdot \left(-\frac{1}{\rho_a}\nabla p\right) + \frac{1}{\rho_a c_a}\frac{\partial p}{\partial t} = 0$$

**声-结构耦合** (单向):

$$-\mathbf{n} \cdot \left(-\frac{1}{\rho_a}\nabla p\right) = \mathbf{n} \cdot \mathbf{a}_\text{struct}$$

其中 $\mathbf{a}_\text{struct}$ 为结构表面法向加速度，从瞬态固体力学解导入。

### 2.3 激励 — Hertz 脉冲敲击

**脉冲波形** (半正弦):

$$F(t) = \begin{cases} \frac{\pi J}{2\tau_\text{imp}} \sin\left(\frac{\pi t}{\tau_\text{imp}}\right) & 0 \le t \le \tau_\text{imp} \\ 0 & t > \tau_\text{imp} \end{cases}$$

其中 $J$ 为传递冲量 (N·s)，$\tau_\text{imp} = 2~\text{ms}$ 为脉冲持续时间。

**Hertz 接触冲量修正** (非钢材料):

钢锤敲击不同材料时，有效冲量取决于接触刚度:

$$J_\text{eff} \propto E^{*1/3}$$

其中 $E^*$ 为有效弹性模量，由锤和尺的弹性模量共同决定。软尺 (低 E) → 接触刚度低 → 大部分能量留在锤中 → 传递冲量减少。

| 材料 | E (GPa) | J_scale = (E/E_steel)^(1/3) | J_eff (Ns) |
|---|---|---|---|
| steel | 200 | 1.000 | 0.0400 |
| acrylic | 3.2 | 0.255 | 0.0102 |
| PVC | 3.0 | 0.250 | 0.0100 |
| satinwood | 2.0 | 0.218 | 0.0087 |
| xuefu_board | 1.0 | 0.154 | 0.0062 |

### 2.4 模态衰减

各模态的指数衰减:

$$p_n(t) = A_n e^{-t/\tau_n} \sin(2\pi f_n t + \phi_n)$$

时间常数 $\tau_n$ 通过 Hilbert 包络的线性回归提取:

$$\ln|p_n^\text{env}(t)| = -\frac{t}{\tau_n} + \text{const}$$

品质因数: $Q_n = \pi f_n \tau_n$

### 2.5 欧拉-伯努利梁理论 (验证参考)

基频理论预测:

$$f_1 = \frac{1.875^2}{2\pi L^2}\sqrt{\frac{EI}{\rho A}} \propto \frac{h}{L^2}\sqrt{\frac{E}{\rho}}$$

其中 $I = bh^3/12$ 为截面惯性矩。

---

## 3. COMSOL 模块与求解架构

### 3.1 使用的 COMSOL 模块

| 模块 | 用途 |
|---|---|
| **Structural Mechanics** | 3D 实体线弹性力学 (Solid Mechanics 接口) |
| **Pressure Acoustics, Transient** | 3D 空气域瞬态压力声学 |
| **Acoustic-Structure Boundary** | 单向声-结构耦合 (加速度边界条件) |

不依赖额外模块 (无需 AC/DC、CFD、Microfluidics 等)。

### 3.2 求解流程 (三研究顺序求解)

```
Study 1: Eigenfrequency (sol1)
  └─ 求解前 6 阶固有频率和振型 (eigen_shift=1Hz)

Study 2: Time Dependent — Structure (sol2)
  └─ 脉冲力施加, 瞬态固体力学
  └─ 输出: 结构表面加速度存储 (acc_i)

Study 3: Time Dependent — Acoustics (sol3)
  └─ 导入 acc_i 作为声学边界条件
  └─ 瞬态压力声学求解
  └─ 输出: CutPoint3D 麦克风压力时程
```

**关键设计决策 — 单向耦合**:
- 声压对结构的反作用可忽略 ($\rho_a / \rho_\text{solid} \approx 1.5\times10^{-4}$)
- 单向耦合避免了每时间步的迭代，求解速度大幅提升
- 声学域求解时间与结构域相同

### 3.3 网格与离散化

- **尺子**: 扫掠六面体网格, `numelem` 控制每边单元数
  - full: 80, medium/fast: 60, coarse: 40, eco: 30
- **空气域**: 自由四面体网格, 最大单元尺寸 λ/4 @ 1000Hz
- **时间步进**: 广义-α (Generalized Alpha), 自适应时间步长

### 3.4 麦克风阵列 (CutPoint3D)

空气域求解完成后，通过 CutPoint3D 探针在任意空间位置评估 p(t)。**几乎零额外算力**，因为不需求解新的 PDE。

默认扫描位置 (10 点, 对数分布):
$$d_i = 0.02 \times \exp\left(\frac{\log(0.10/0.02) \times i}{9}\right), \quad i = 0,1,...,9$$

距离从尺子表面起算: $z = h/2 + d_i$

---

## 4. 仿真包体系

所有包位于服务器 `user@<your-linux-server>:~/comsol_work/the_singing_ruler/`

### 4.1 包总览

| 包 | 目录 | 物理模型 | 关键修正 | 状态 | 输出 |
|---|---|---|---|---|---|
| **base** | `the_singing_ruler_full_server_source/` | 线性弹性 | eigen_shift=1Hz | ✅ | `materials_eigenfix` (5 cases) |
| **combined** | 同上, `config/materials_combined.json` | 线性弹性 | **阻尼+冲量** | ✅ | `materials_combined` (5 cases) |
| **nonlinear** | 同上, `config/materials_only.json` + gNL | 几何非线性 | 无 | ✅ | `materials_nonlinear` (5 cases) |
| **adaptive** | 同上, `config/requested_cases.json` | 线性弹性 | eigen_shift=1000Hz (bug) | ✅ FFT已校正 | `requested_adaptive` (27 cases) |

### 4.2 base — 线性基准

- **参数**: 5 种材料 (steel, PVC, acrylic, satinwood, xuefu_board), 统一几何 (L=20cm, b=3cm, h=2mm)
- **eigen_shift=1Hz**: 正确捕获低频谱 (尤其是非钢材料 f₁<50Hz)
- **用途**: 材料对比基准线，验证频率与理论的吻合

### 4.3 combined — 阻尼+冲量联合修正

- **新增参数**: 每种材料的 ζ (阻尼比) 和 J_scale (冲量缩放)
- **物理依据**: Hertz 接触 (J_scale ∝ E^(1/3)) + 文献损耗因子 (ζ = η/2)
- **效果**: 非钢材料 SPL 从 103-112 dB 降至 85-91 dB (更符合实际)，位移减小 5-10×

### 4.4 nonlinear — 几何非线性

- **方法**: Solid Mechanics 开启 "Include geometric nonlinearity" (Green-Lagrange 应变)
- **结论**: 频率不变，位移修正 -3%~-33%。单用不足以解释非钢材料的大振幅衰减
- **局限**: 钢尺在非线性显著之前已屈服 (ε_yield ≈ 0.2%)

### 4.5 adaptive — 27 例全扫描

- **自变量**: L_free (5 值), b (4 值), h (5 值), J (5 值), x₀ (4 值), material (5 种) = 27 cases
- **自适应质量**: f-sensitive (material/L/h) → fast; amplitude-only (b/J/x₀) → eco
- **eigen_shift bug**: 部分 case 特征频率错误 (shift=1000Hz → 漏掉低频模态)，已通过 FFT 校正

---

## 5. 参数空间与实验设计

### 5.1 基线参数

| 参数 | 值 | 单位 |
|---|---|---|
| L_free | 20 | cm |
| b (宽度) | 3 | cm |
| h (厚度) | 2 | mm |
| J (冲量) | 0.04 | N·s |
| x₀/L (撞击位置) | 0.8 | — |
| 麦克风距离 | 0.02 | m |
| 空气球半径 | 0.121 | m |

### 5.2 材料参数

| 材料 | ρ (kg/m³) | E (GPa) | ν | ζ (阻尼) | J_scale |
|---|---|---|---|---|---|
| steel | 7850 | 200 | 0.30 | 0.015 | 1.000 |
| PVC | 1380 | 3.0 | 0.38 | 0.07 | 0.250 |
| acrylic | 1190 | 3.2 | 0.35 | 0.06 | 0.255 |
| satinwood | 700 | 2.0 | 0.30 | 0.04 | 0.218 |
| xuefu_board | 500 | 1.0 | 0.30 | 0.10 | 0.154 |

### 5.3 扫描范围 (27-case adaptive)

| 自变量 | 扫描值 | 单位 | 自适应质量 |
|---|---|---|---|
| L_free | 14, 17, 20, 23, 26 | cm | fast |
| b | 2, 3, 4, 5 | cm | eco |
| h | 0.5, 1.0, 2.0, 3.5, 5.0 | mm | fast |
| J | 0.01, 0.02, 0.04, 0.08, 0.16 | N·s | eco |
| x₀/L | 0.3, 0.5, 0.8, 0.95 | ratio | eco |
| material | steel, PVC, acrylic, satinwood, xuefu_board | category | fast |

### 5.4 COMSOL 求解质量档位

| 参数 | full | medium | fast | eco |
|---|---|---|---|---|
| mesh_numelem | 80 | 60 | 40 | 30 |
| time_end (s) | 0.5 | 0.35 | 0.25 | 0.15 |
| time_step (s) | 5e-5 | 1e-4 | 2e-4 | 5e-4 |
| 单 case 耗时 | ~3h | ~1.5h | ~25min | ~5min |

---

## 6. 关键结果

### 6.1 频率验证

- **f₁ ∝ 1/L²**: 钢尺 L 扫描 R² > 0.99, 完美吻合 Euler-Bernoulli 理论
- **f₁ ∝ h**: 钢尺 h 扫描线性关系确认 (薄板区 f₁ ∝ h, 厚板区偏离)
- **f₁ 与 b 无关**: 验证一维梁假设 (f₁ 对宽度不敏感, 变化 < 2%)
- **f₁ 与 J 无关**: 验证线性系统的振幅-频率解耦

### 6.2 材料对比 (combined 修正后)

| 材料 | f₁ (Hz) | SPL (dB) | τ₁ (ms) | 探针峰值 (mm) |
|---|---|---|---|---|
| steel | 40.3 | 86.3 | 289 | 4.70 |
| PVC | 12.1 | 85.4 | ~1618* | 17.41 |
| acrylic | 13.5 | 86.6 | ~242* | 19.82 |
| satinwood | 13.8 | 91.0 | ~116* | 30.12 |
| xuefu_board | 8.2 | 87.7 | — | 23.94 |

> *Mode 1 衰减拟合在 fast 质量 0.25s 时间窗下不可靠 (R² < 0.7)，需延长 time_end

### 6.3 空间声压衰减

麦克风距离 0.02→0.10m, SPL 衰减约 8-10 dB。符合几何扩散预期 (6 dB/倍距)，近场有额外衰减（近场效应、空气域边界）。

### 6.4 频谱特征 (音色)

| 材料 | 频谱质心 (Hz) | 平坦度 | 85% 滚降 (Hz) |
|---|---|---|---|
| steel | 63 | 低 | 150 |
| satinwood | 59 | 中 | 120 |
| acrylic | 49 | 中 | 95 |
| PVC | 55 | 中高 | 110 |
| xuefu_board | 137 | 高 | 280 |

钢尺音色"明亮" (高质心、低平坦度)，雪弗板音色"柔和但宽频" (高平坦度)。

---

## 7. 局限性与已知问题

### 7.1 模型局限

1. **理想固支**: 实际夹持非完全刚性，会导致频率略低于仿真值，尤其对高阶模态影响更大
2. **各向同性假设**: 缎木 (satinwood) 和雪弗板 (xuefu_board) 非各向同性 —— 木纹方向对 E 影响可达 10-50×
3. **线性阻尼模型**: Rayleigh 阻尼简化了实际粘弹性行为，聚合物 (PVC, acrylic) 的频率相关阻尼更复杂
4. **点载荷近似**: 实际敲击有时间/空间分布，0.01×0.006 m 冲击贴片是对真实接触面积的近似
5. **单向耦合**: 忽略声压对结构的反作用（重流体效应），在空气中合理但在水中不成立

### 7.2 仿真局限

6. **eigen_shift bug** (历史): shift=1000Hz 导致长/薄/低 E 尺子的低频谱丢失。已在 combined/nonlinear/base 包中修复 (shift=1Hz)，adaptive 包通过 FFT 校正恢复
7. **fast 质量时间窗**: time_end=0.25s 对 f₁<12Hz 材料 (PVC, satinwood, acrylic, xuefu_board) 只有 2-3 个周期，模态衰减拟合不可靠
8. **空气域边界效应**: 麦克风 sweep 的 d8-d9 (0.08-0.10m) 靠近空气球边界 (r=0.121m), SPL 出现非单调异常
9. **未考虑热粘性损耗**: 空气域采用无损耗压力声学方程，高频 (>5kHz) 衰减被低估

### 7.3 数据局限

10. **缺少实验验证**: 所有结论基于纯仿真数据，未用加速度计/传声器实验数据校核
11. **tip_timeseries 缺失**: 部分 case 无 tip 位移时程，Q 估计仅能通过结构探针间接获取
12. **频域分辨率**: 0.25s 时间窗 → 4Hz 频率分辨率。低频谱的精确峰值定位受限

---

## 8. 未来计划

### 8.1 近期 (已完成或进行中)

- [x] 线性基准: eigen_shift=1Hz, 5 材料 ✓
- [x] 几何非线性: 5 材料, Green-Lagrange 应变 ✓
- [x] 联合修正: 阻尼 + Hertz 冲量缩放, 5 材料 ✓
- [x] 27-case 自适应扫描: 6 自变量全组合 ✓
- [ ] **时间延长重跑**: combined 包 time_end → 1.0s, 获取可靠低频谱衰减常数

### 8.2 中期

- [ ] **钢尺极端几何扫描**: L=30-50cm, h=0.5-1.0mm, 几何非线性开启, 验证大振幅行为
- [ ] **空气域边界修正**: 增大 air_radius 或改用 PML 层, 消除远场麦克风异常
- [ ] **两相流 Level Set 仿真** (可行性已验证): 若需分析流体-结构相互作用 (如水中尺子)
- [ ] **超弹性模型** (低优先级): Neo-Hookean 模型对木材/聚合物, 弯曲应变 <5% 时与线弹性一致

### 8.3 远期

- [ ] **实验验证**: 加速度计 (尺端) + 传声器 (多距离), 与仿真对比
- [ ] **有限元声学逆问题**: 从实测声压反推材料参数 (E, ζ)
- [ ] **多物理场扩展**: 热弹性阻尼, 声辐射力

---

## 9. 数据产物清单

### 9.1 有用产物 (保留)

| 产物 | 位置 | 大小 | 说明 |
|---|---|---|---|
| 27-case adaptive | `outputs/requested_adaptive/` | 53 MB (CSV) / 17 GB (服务器) | 全扫描, FFT 校正后可用 |
| materials_eigenfix | `outputs/materials_eigenfix/` | 11 MB / 4.7 GB | 线性基准, 5 材料 |
| materials_combined | `outputs/materials_combined/` | 4 MB / 4.7 GB | 阻尼+冲量修正 |
| materials_nonlinear | `outputs/materials_nonlinear/` | 13 MB / 4.7 GB | 几何非线性 |
| 论文图 | `outputs/requested_adaptive/figures/` | — | 300 DPI PNG × 9 |

### 9.2 历史产物 (建议清理)

| 产物 | 大小 | 原因 |
|---|---|---|
| `outputs/history/` | 10 GB | 5 份重复的旧 coarse mph 文件 |
| `outputs/linear/` | 1.8 GB | 早期模型版本, 已被新模型取代 |
| `outputs/requested_medium_tip_decay_validation/` | 10.5 GB | 单 case 中等质量, 已被 adaptive 取代 |
| `outputs/requested_timbre_complete_enhanced_medium/` | 57 GB | 10 个 5.7GB mph 文件, 中等质量, 已被 combined 取代 |
| 服务器 `smoke_*`, `quick_*` | ~13 GB | 开发阶段的冒烟测试和快速验证 |
| `outputs/*.tar.gz` | 若干 | 临时下载包 |

---

## 附录 A: 文件结构

```
the_singing_ruler/
├── models/linear/acoustic_field_3d_air/  # 主模型 (Java + 配置)
├── matlab/
│   ├── core/       # 管线、衍生指标计算
│   ├── extract/    # FFT、SPL、模态衰减、音色特征
│   ├── plot/       # 论文图表 (300 DPI)
│   ├── report/     # 批处理、结论汇总表
│   └── validate/   # 输出验证
├── scripts/        # PowerShell 编排
├── docs/
│   ├── reports/    # 中文论文级报告
│   └── rules/      # 代理行为规则
├── outputs/        # 仿真结果 (不入 Git)
└── the_singing_ruler_full_server_source/  # Linux 服务器包
```

## 附录 B: 关键命令

```powershell
# 本地 build (Windows, COMSOL 6.3)
pwsh -NoProfile -File .\scripts\build_comsol_model.ps1

# 服务器单 case (Linux, COMSOL 6.1)
./run_single_full.sh --study-id my_study

# 服务器批处理
python3 -B tools/run_requested_full.py --study-id my_study \
  --case-definition config/materials_combined.json \
  --quality fast --max-parallel 5 --comsol-np 12

# MATLAB 后处理
batch_derived_metrics(proj_root, 'outputs/materials_combined')
aggregate_conclusion_table(proj_root, 'outputs/materials_combined')
```

---

*文档维护者: ldaniel | 最后更新: 2026-05-17*
