# The Singing Ruler — 项目闭环

> 2026-05-19 | 最终版本  
> 4 材料, 14 case, 7 理论模块, 全部指标验证完毕

---

## 1. 项目产出一览

### 1.1 仿真数据

| 数据集 | 材料 | case 数 | 质量 | 关键参数 |
|---|---|---|---|---|
| `unified_v2_4mat` | Steel, Acrylic, Satinwood, PVC | **4** | unified (1.0s, mesh=60) | 逐材料 Rayleigh, gNL=on (PVC off) |
| `steel_gnl_on_v2` | Steel ×5 geometries | **5** | fast (0.25s, mesh=40) | 逐材料 Rayleigh, gNL=on |
| `steel_gnl_off_v2` | Steel ×5 geometries | **5** | fast (0.25s, mesh=40) | 逐材料 Rayleigh, gNL=off |

每个 case 包含 25+ CSV 文件，均通过 `validate_csv_bundle` 验证。

### 1.2 文档

| 文档 | 内容 |
|---|---|
| `THEORY_OF_THE_SINGING_RULER.md` | **最终理论框架** — 7 理论模块 + 全量验证 |
| `MODAL_TYPE_TIMBRE_ANALYSIS.md` | 模态分类 (z-bending vs in-plane) |
| `STEEL_GNL_ANALYSIS.md` | 钢 gNL 5×2 扫掠 |
| `UNIFIED_PACKAGE_CONCLUSION.md` | 统一包 4 材料详细结果 |
| `ppt_review_from_simulation.md` | 16 张 PPT 内容 (含方向性声学、Hertz 撞击、动画) |

### 1.3 动画

| 来源 | 文件 | 状态 |
|---|---|---|
| MATLAB 模态叠加 | `ruler_vibration_steel.gif` (8 帧, 0.3s) | ✅ 可用 |
| COMSOL 原生 | — | ❌ Security Manager 阻止文件写入 |

---

## 2. 最终音色数据

### 2.1 频率

| 材料 | f₁ (Hz) | f₂_b (Hz) | f₃_b (Hz) | f₄_b (Hz) | EB 误差 |
|---|---|---|---|---|---|
| **Steel** | 41.2 | 258.1 | 723.5 | 1420.6 | +1.1% |
| **Acrylic** | 13.5 | 84.2 | 236.1 | 464.0 | +1.6% |
| **Satinwood** | 13.8 | 86.4 | 242.3 | 475.7 | +1.1% |
| **PVC** | 12.1 | 76.0 | 213.0 | 418.9 | +1.9% |

仅统计弯曲模态 [1,2,5,6]。

### 2.2 衰减

| 材料 | τ₁ (s) | R² | Q₁ | 阻尼特征 |
|---|---|---|---|---|
| **Steel** | 0.218 | 0.982 | 28.2 | 弱阻尼 |
| **Satinwood** | 0.256 | 0.973 | 11.1 | 中阻尼 |
| **PVC** | 0.196 | 0.971 | 7.5 | 中阻尼 |
| **Acrylic** | 0.174 | 0.964 | 7.4 | 中阻尼 |

逐材料 Rayleigh 调谐后 τ₁ 误差 <5% (含数值耗散)。

### 2.3 声学

| 材料 | SPL RMS | 探头振幅 | 音色 |
|---|---|---|---|
| **Satinwood** | 81.7 dB | 32.6 mm | 最响、大振幅 |
| **Steel** | 79.3 dB | 4.6 mm | 高频丰富、金属亮色 |
| **Acrylic** | 77.6 dB | 22.5 mm | 较闷 |
| **PVC** | 75.8 dB | 20.8 mm | 最安静 |

### 2.4 方向性声学

| 方向 | 辐射面 | 相对 SPL |
|---|---|---|
| **⊥ 振动面 (+z)** | 30mm 宽面 | 基准 |
| **∥ 振动面 (±y)** | 2mm 窄边 | **-23.5 dB** |
| in-plane 模态 | — | **-34~42 dB** (实测) |

### 2.5 gNL 效应

probe/L ≤ 9.2% 时，gNL 对所有指标修正 **< 2%**。

---

## 3. 理论验证汇总

| 理论 | 验证 | 精度 |
|---|---|---|
| Euler-Bernoulli | 4/4 ✅ | < 2% |
| 模态分类 (z-bend vs in-plane) | 4/4 ✅ | < 3% |
| 逐材料 Rayleigh 调谐 | 4/4 ✅ | < 5%* |
| Green-Lagrange gNL | 5/5 ✅ | < 2% |
| Hertz 球撞击 | 定性 ✅ | < 1% (基频) |
| 声辐射阻尼 | ✅ | < 0.02% (可忽略) |
| 方向性 SPL | ✅ | 面积比 = 23.5dB |

\* 含 generalized-α 数值耗散 (~15% ζ)

---

## 4. 未完成项

| 项目 | 原因 |
|---|---|
| Xuefu board | 从未在 unified 质量下收敛 |
| COMSOL 原生动画 | Security Manager 阻止批量模式文件写入 |
| 实验对标 | 无物理实验数据 |

---

*项目闭环于 2026-05-19。全部数据、代码、文档位于 `the_singing_ruler/` 仓库。*
