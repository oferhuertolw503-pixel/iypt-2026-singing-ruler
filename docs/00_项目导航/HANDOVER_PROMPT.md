# 新人接手提示词 — 仿真数据验证 PPT 理论

## 你的任务

用 COMSOL 仿真数据验证 PPT `ppt/尺子之歌-正方匡大德.pptx` 中的理论公式，将仿真结果嵌入 PPT 并生成独立图表。

---

## 一、先读懂 PPT 理论（Slides 12-19）

PPT 共 48 页，核心理论集中在第二部分（slides 12-19）。你必须先逐页理解以下内容：

### 1.1 模型假设（Slide 13）

欧拉-伯努利悬臂梁三大假设：

| 假设类型 | 含义 |
|---|---|
| 几何假设 | 梁截面尺寸远小于长度（L >> b, h），可忽略截面变形 |
| 材料假设 | 线弹性、各向同性、小变形 |
| 运动学假设 | 平截面假设，忽略剪切变形与转动惯量 |

### 1.2 音调理论（Slides 14-15）— 核心公式

悬臂梁第 n 阶固有频率：

```
fₙ = (βₙ²/(2πL²)) × √(EI/(ρA))
```

其中 β₁ = 1.875, β₂ = 4.694, β₃ = 7.855...

对于矩形截面（I = bh³/12, A = bh）：

```
fₙ = (βₙ²/(2πL²)) × √(Eh²/(12ρ))
```

**关键推论**（仿真必须验证的 4 条）：

| 编号 | 理论预测 | 公式依据 |
|---|---|---|
| P1 | f₁ ∝ 1/L² | f₁ = β₁²h/(4πL²) × √(E/(3ρ)) |
| P2 | f₁ ∝ h（线性过原点） | 同上，h 在分子 |
| P3 | f₁ 不随 b 变化 | 公式中 b 被约掉（I/A = h²/12） |
| P4 | f₁ ∝ √(E/ρ) | 材料参数仅以 √(E/ρ) 出现 |

### 1.3 音色理论（Slides 16-17）

- 被敲击后多模态同时激发
- 各模态振幅 Aₙ(t) 随时间衰减：Aₙ(t) = Aₙ(0) × e^(-t/τₙ)
- 高阶模态衰减快（τₙ 小），低阶持久 → 音色随时间演变
- 基频占比（第一模态能量/总能量）随时间单调递增

### 1.4 响度理论（Slide 18）

- 声压 p ∝ 振动速度 v̇ ∝ 初始位移 ∝ 冲量 J
- SPL（dB）= 20 × log₁₀(p_rms / p_ref)
- 远场声压按 1/r 衰减（球面波）
- PPT 注明手机 phyphox 不能当远场麦克风，理论仅做"定性半定量解释"

### 1.5 理论总结（Slide 19）

```
尺子参数 (L, h, b, 材料, J, x₀)
    ↓
中间变量 (基频 f₁, 模态能量分布, 初始振幅)
    ↓
声音三要素 (音调, 音色, 响度)
```

---

## 二、仿真数据源

### 2.1 结论主表（27 行 × 73 列）

```
outputs/requested_adaptive/tables/conclusion_master_table_corrected.csv
```

**自变量列**：

| 列名 | 含义 | 数据范围 |
|---|---|---|
| case_id | case 路径标识 | — |
| material | 材料 | steel / PVC / acrylic / satinwood / xuefu_board |
| L_free_cm | 自由端长度 cm | 10 / 14 / 18 / 20 / 22 / 26 |
| b_cm | 宽度 cm | 1 / 2 / 3 / 4 / 5 |
| h_mm | 厚度 mm | 1 / 2 / 3 / 4 / 5 |
| J_Ns | 冲量 N·s | 0.02 / 0.04 / 0.06 / 0.08 |
| x0_ratio | 撞击位置（归一化） | 0.25 / 0.50 / 0.75 / 0.80 |

**因变量列**：

| 列名 | 含义 |
|---|---|
| f1_hz ~ f6_hz | 6 阶模态频率 (Hz) |
| spl_rms_db, spl_peak_db | 声压级 (dB) |
| p_rms_pa, p_peak_pa | 声压 (Pa) |
| spectral_centroid_hz | 频谱质心 (Hz) |
| spectral_flatness | 频谱平坦度 (0~1) |
| rolloff85_hz | 85% 能量滚降频率 |
| f_dom_hz, f_dom_refined_hz | 主频 / 精修主频 |
| tau1_s ~ tau6_s | 各阶衰减时间常数 (s) |
| Q1 ~ Q6 | 各阶品质因数 |
| r2_1 ~ r2_6 | 衰减拟合 R² |
| alpha_dM_est, beta_dK_est | Rayleigh 阻尼参数估计 |
| rayleigh_valid | 阻尼模型是否有效 (0/1) |
| mic_sweep_spl_01~10_db | 10 距离麦克风 SPL |
| mic_sweep_dist_01~10_m | 对应距离 (m) |
| probe_peak_mm | 探针峰值位移 (mm) |
| shift_issue | 频率是否经 FFT 校正 (true/false) |

### 2.2 联合修正数据 (阻尼+冲量)

```
outputs/materials_combined/tables/conclusion_master_table.csv
```

5 种材料 (steel/PVC/acrylic/satinwood/xuefu_board)，统一几何 (L=20cm, b=3cm, h=2mm)，含 Hertz 接触冲量缩放 + 材料阻尼修正。**这是非钢材料最可靠的对比数据**。

### 2.3 几何非线性数据

```
outputs/materials_nonlinear/tables/conclusion_master_table.csv
```

5 种材料，Green-Lagrange 大变形。结论：频率不变，位移 -3%~-33%。

### 2.4 每 case 原始数据

```
outputs/requested_adaptive/cases/
├── timbre_material/         ← 5 种材料 (material_steel / _PVC / _acrylic / _satinwood / _xuefu_board)
├── steel_scan/L_free/       ← 5 种长度 (L_free_10cm ~ L_free_26cm)
├── steel_scan/h/            ← 5 种厚度 (h_1mm ~ h_5mm)
├── steel_scan/b/            ← 5 种宽度 (b_1cm ~ b_5cm)
├── steel_scan/J/            ← 4 种冲量 (J_0p02Ns ~ J_0p08Ns)
└── steel_scan/x0_ratio/     ← 3 种撞击位置 (x0_0p25 ~ x0_0p75)
```

每个 case 的 `data/` 子目录含：`frequencies.csv`、`mic_pressure_timeseries.csv`、`structure_probe_timeseries.csv`、`modal_decay.csv`、`acoustic_metrics.csv`、`mode_shapes.csv`、`mic_pressure_timeseries_sweep_01~10.csv`、`mic_sweep_distances.csv` 等。

---

## 三、四个验证方向

### 3.1 音调验证（f vs L/h/b/J）— 对应 PPT Slides 24-28

用主表拟合以下关系，与理论公式对比：

| 理论 | 数据子集 | 拟合方法 | 期望结果 |
|---|---|---|---|
| f₁ = k/L² | steel_scan/L_free (5 点) | 幂律拟合 f₁ = a × L^n | n ≈ -2 |
| f₁ = k×h | steel_scan/h (5 点) | 线性过原点 f₁ = a×h | R² ≈ 1 |
| f₁ ≠ f(b) | steel_scan/b (5 点) | 水平线验证 | Δf₁/f₁ < 1% |
| f₁ ≠ f(J) | steel_scan/J (4 点) | 水平线验证 | Δf₁/f₁ < 0.1% |

**每张图标注**：拟合公式、R²、理论值（虚线）、仿真值（实心点）、相对误差。

**数据加载示例**：

```python
import pandas as pd
import numpy as np
from scipy.optimize import curve_fit

T = pd.read_csv('outputs/requested_adaptive/tables/conclusion_master_table_corrected.csv')

# L_free scan (钢, 固定 h=2mm, b=3cm, J=0.04Ns)
steel_L = T[T.case_id.str.contains('L_free')]

# 幂律拟合 f1 = a * L^n
def power_law(x, a, n):
    return a * x**n

popt, _ = curve_fit(power_law, steel_L['L_free_cm'], steel_L['f1_hz'])
# 检查 n 是否 ≈ -2
```

### 3.2 音色验证（centroid / flatness / decay）— 对应 PPT Slides 29-30

#### 钢材料音色

| 分析 | 数据列 | 图表类型 |
|---|---|---|
| 频谱质心 vs 参数 | spectral_centroid_hz | 多系列折线 |
| 频谱平坦度 vs 参数 | spectral_flatness | 多系列折线 |
| τₙ vs fₙ（衰减 vs 频率） | tau1~tau6 + f1~f6 | 散点图 + 幂律拟合 |
| 品质因数 Q vs mode | Q1~Q6 | 柱状图 |

**核心验证**：高频衰减快 → τₙ 应随 fₙ 单调递减

#### 非钢材料（仅做音色对比）

| 分析 | 图表 |
|---|---|
| 5 种材料的 spectral_centroid | 柱状图 |
| 5 种材料的 spectral_flatness | 柱状图 |
| 材料音色 map: centroid × flatness × SPL | 气泡图 |

⚠️ **非线性警告 — 两种修正方案已运行**：

**线性基准 (未修正)**：

| 材料 | probe_peak_mm | probe/L (%) | 线性假设 |
|---|---|---|---|
| steel | 2.3 | 1.2% | ✓ 有效 |
| PVC | 87.3 | 43.7% | ✗ 严重违反 |
| acrylic | 92.1 | 46.1% | ✗ 严重违反 |
| satinwood | 71.5 | 35.8% | ✗ 严重违反 |
| xuefu_board | 248.7 | 124.4% | ✗ 完全失效 |

**联合修正后 (阻尼 ζ + Hertz 冲量缩放)**：

| 材料 | probe_peak_mm | probe/L (%) | 修正因子 |
|---|---|---|---|
| steel | 4.7 | 2.4% | J×1.0, ζ=0.015 |
| PVC | 17.4 | 8.7% | J×0.25, ζ=0.07 |
| acrylic | 19.8 | 9.9% | J×0.255, ζ=0.06 |
| satinwood | 30.1 | 15.1% | J×0.218, ζ=0.04 |
| xuefu_board | 23.9 | 12.0% | J×0.154, ζ=0.10 |

**修正后非钢材料位移降低 5-10×**，但仍超出小变形假设 (probe/L > 5%)。建议 PPT 中同时呈现两种结果并讨论修正的必要性。

**参考文档**:
- `docs/reports/PROJECT_MASTER_DOCUMENT_ZH.md` — 项目总体文档（含物理机制、局限、未来计划）
- `docs/PACKAGES_README.md` — 服务器包详细说明
- `matlab/README.md` — MATLAB 后处理模块说明
- `the_singing_ruler_full_server_source/README.md` — 服务器仿真包使用说明

### 3.3 响度验证（SPL vs J/x₀/distance）— 对应 PPT Slides 31-35

| 理论 | 数据子集 | 拟合方法 |
|---|---|---|
| SPL ∝ J（近似线性 in dB vs log J） | J scan (4 点) | spl_rms_db vs J_Ns |
| probe_peak ∝ J（振幅线性） | J scan (4 点) | probe_peak_mm vs J_Ns，线性拟合 |
| SPL vs x₀ | x0_ratio scan (3 点) | spl_rms_db vs x0_ratio |
| SPL 距离衰减（1/r → -6dB/倍距） | mic_sweep 10 点 | SPL vs distance，log-log 拟合 |

**距离衰减是仿真独有数据**（PPT 实验仅在 5cm 和 30cm 两点测量），可做 10 点精细曲线。

### 3.4 模态衰减分析（新增 — PPT 无对应）

PPT 未涉及模态衰减的定量分析。仿真提供独特数据：

| 分析内容 | 数据列 | 意义 |
|---|---|---|
| 6 阶模态 τ 和 Q | tau1~tau6, Q1~Q6 | 量化"高频消失快" |
| τ vs f 关系 | 全部 case | 验证衰减机制 |
| Rayleigh 阻尼参数 | alpha_dM_est, beta_dK_est | 物理阻尼建模 |
| 阻尼模型有效性 | rayleigh_valid | 哪些 case 符合 Rayleigh 假设 |
| 衰减拟合质量 | r2_1~r2_6, decay_quality | 数据可信度评估 |

**图表**：
1. τ vs f 散点图（6 阶 × 22 钢 case），拟合 τ = c × f^(-α)
2. Q vs mode number 柱状图
3. Rayleigh 阻尼 (α, β) 散点，标注 valid/invalid

---

## 四、PPT 操作规则

| 序号 | 规则 | 说明 |
|---|---|---|
| 1 | **不删不改原有内容** | 所有仿真内容以新增幻灯片插入 |
| 2 | 插入位置 | 每段仿真插在对应实验页**之后**（如仿真音调插在 slide 28 之后） |
| 3 | 版式一致 | 沿用 PPT 现有风格（深色背景、白色字体） |
| 4 | 幻灯片结构 | 标题 + "仿真验证"标签 + 图表 + 一句话结论 |
| 5 | 图表双保存 | 嵌入 PPT 的同时保存 PNG 到 `outputs/requested_adaptive/figures/` |
| 6 | 新增标记 | 非钢材料页必须含 ⚠ 非线性警告 |
| 7 | 模态衰减位置 | 作为新第 3.6 节插在 slide 35 之后、课题总结之前 |

---

## 五、数据加载模板（Python）

```python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.optimize import curve_fit
from pathlib import Path

# === 加载主表 ===
BASE = Path(r'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler')
T = pd.read_csv(BASE / 'outputs/requested_adaptive/tables/conclusion_master_table_corrected.csv')

# === 数据子集 ===
# 钢 L_free scan
steel_L = T[T.case_id.str.contains('L_free')]

# 钢 h scan
steel_h = T[T.case_id.str.contains('/h/')]

# 钢 b scan
steel_b = T[T.case_id.str.contains('/b/')]

# 钢 J scan
steel_J = T[T.case_id.str.contains('/J/')]

# 钢 x0 scan
steel_x0 = T[T.case_id.str.contains('x0_ratio')]

# 5 种材料对比
materials = T[T.case_id.str.contains('material_')]

# === 理论值计算 ===
# 钢: E=200GPa, ρ=7850 kg/m³
E_steel = 200e9
rho_steel = 7850
beta1 = 1.8751

def f1_theory(L_m, h_m, E, rho):
    """悬臂梁一阶固有频率理论值"""
    return (beta1**2 / (2 * np.pi * L_m**2)) * np.sqrt(E * h_m**2 / (12 * rho))

# === 注意事项 ===
# 1. shift_issue=True 的行频率已经 FFT 校正，可直接使用
# 2. 非钢材料 probe_peak_mm 极大，标记线性失效
# 3. rayleigh_valid=0 时阻尼参数不可信
```

---

## 六、交付物清单

| # | 交付物 | 路径 | 说明 |
|---|---|---|---|
| 1 | 修改后的 PPTX | `ppt/尺子之歌-正方匡大德.pptx` | 新增仿真幻灯片，不删原有 |
| 2 | 独立 PNG 图表 | `outputs/requested_adaptive/figures/` | 所有仿真图表的高分辨率 PNG |
| 3 | PPT 修改意见文档 | `docs/reports/ppt_review_from_simulation.md` | Markdown 格式 |
| 4 | 拟合计算中间表 | `outputs/requested_adaptive/tables/fitting_results.csv` | 含公式、R²、误差 |

### 修改意见文档应覆盖：

1. **理论吻合度**：哪些公式与仿真高度一致（如 f₁∝1/L², f₁∝h），哪些有系统偏差
2. **实验设计建议**：自变量覆盖是否全面（如原 PPT 缺少 mic 距离精细扫描）
3. **误差溯源**：仿真 vs 实验差异来源（传感器精度、夹持边界条件、三维效应）
4. **线性假设局限**：非钢材料 EB 梁理论完全不适用，必须加入讨论
5. **可新增内容**：模态衰减定量分析、Rayleigh 阻尼验证、10 距离声压衰减曲线
6. **图表改进建议**：现有 PPT 图表的标注完整性、拟合公式可见性

---

## 七、执行顺序建议

```
Step 1: 加载 CSV，检查数据完整性（27 行 × 73 列是否齐全）
Step 2: 音调拟合 → 4 张图 → 计算理论 vs 仿真相对误差
Step 3: 音色分析 → 材料对比图 + 衰减 vs 频率图
Step 4: 响度分析 → SPL vs J/x₀ + 距离衰减曲线
Step 5: 模态衰减 → τ-f 关系 + Rayleigh 参数
Step 6: 生成所有 PNG 到 figures/
Step 7: 修改 PPTX（python-pptx 库），插入新幻灯片
Step 8: 撰写修改意见文档
Step 9: 导出 fitting_results.csv
```

---

## 八、技术注意事项

1. **PPTX 操作**：使用 `python-pptx` 库。读取现有 PPT，追加新 slide，保持母版/版式一致
2. **图表风格**：深色背景 (#1a1a2e 或类似)，白色坐标轴/文字，与 PPT 视觉统一
3. **中文字体**：图表中使用 `SimHei` 或 `Microsoft YaHei`，确保中文正常显示
4. **分辨率**：PNG 输出 300 dpi，宽度 ≥ 1920px
5. **数据完整性**：每个数据点追溯到真实 COMSOL case，禁止插值/合成
