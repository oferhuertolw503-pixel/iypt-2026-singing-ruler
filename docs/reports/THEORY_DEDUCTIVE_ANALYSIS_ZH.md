---
audience: human, agent
agent-priority: high
status: active
report-type: theory-analysis
recommended-use: paper-theory, defense, experiment-design
source-reference: "Obsidian/物理学术竞赛/Main 13  The Singing Ruler/理论模型（终版）.md"
data-roots:
  - outputs/requested_3d_air_coarse_review_light
  - outputs/requested_timbre_complete_enhanced_medium
  - outputs/requested_theory_steel_mic2cm
encoding: UTF-8
---

# The Singing Ruler 理论分析：从悬臂梁到实验可测声学指标

> 写作目标：用演绎法从基础力学和声学假设推出与仿真结论相同的结果物理量，并把每个理论推论落到实验可测量指标和已有仿真结果图上。
>
> 核心口径：本文中的“音色”指仿真频谱音色代理指标，包括频谱质心、频谱平坦度、频带能量比例、谱峰数量、主峰/次峰比、Q 因子和衰减时间；不直接等同于完整主观听感。

## 0. 要解释的物理链条

尺子发声不是一个单一的“声音问题”，而是一个结构-声学链条：

```text
几何/材料/夹持
  -> 悬臂梁弯曲模态
  -> 敲击冲量选择并激发模态
  -> 阻尼控制自由衰减
  -> 尺子表面运动辐射声压
  -> 麦克风声压时程 p(t)
  -> FFT/STFT/包络后处理得到音调、响度、音色代理指标
```

因此理论分析的最终输出不应停在“固有频率公式”，而应落到和仿真图相同的观测量：

| 物理层级 | 理论对象 | 仿真/实验结果物理量 |
|---|---|---|
| 结构模态 | $f_n, \phi_n(x), q_n(t)$ | `freq_hz`, `mode_shapes`, tip/probe 位移 |
| 声压时程 | $p(t)$ | `p_rms_pa`, `p_peak_pa`, `spl_rms_db` |
| 音调 | 声压频谱主峰 | `f_dom_hz`, `f_dom_refined_hz`, `second_peak_freq_hz` |
| 响度 | 声压有效值 | `spl_rms_db`, `p_rms_pa` |
| 频域音色 | 频谱分布 | `spectral_centroid_hz`, `spectral_flatness`, 能量比例、谱峰数量 |
| 时域音色 | 衰减包络 | `q_estimate`, `log_decrement`, `decay_time_50pct_s`, `energy_decay_85pct_s` |
| 线性边界 | 振幅相对尺度 | `probe_peak_over_L` |

## 1. 公设与建模假设

### 1.1 基本公设

1. 尺子是均匀矩形截面弹性体，自由段长度为 $L$，宽度为 $b$，厚度为 $h$，密度为 $\rho$，杨氏模量为 $E$。
2. 小挠度、线弹性范围内，弯曲振动可以先用 Euler-Bernoulli 悬臂梁描述。
3. 敲击时间远短于主要振动周期时，敲击可以等效为位于 $x_0$ 的短时冲量 $J=\int F(t)\,dt$。
4. 空气声场在当前声压范围内线性，麦克风压力是结构模态响应的线性观测。
5. 阻尼足够小，使每个主要模态可以用指数衰减正弦描述。

这些假设对应仿真中的主线模型：3D 实体尺子 + 真实 3D 空气域 + 线性声学瞬态。Euler-Bernoulli 梁不是替代 3D COMSOL，而是给出可检验的标度律和解释框架。

### 1.2 坐标与截面量

矩形截面有

$$
A=bh,\qquad I=\frac{bh^3}{12}.
$$

其中 $A$ 是截面积，$I$ 是关于弯曲中性轴的截面二次矩。注意 $I/A=h^2/12$，这会导致一阶梁理论中的频率对宽度 $b$ 一阶不敏感。

## 2. 从梁方程推出音调标度律

### 2.1 控制方程

线性 Euler-Bernoulli 梁的横向挠度 $y(x,t)$ 满足

$$
\rho A\frac{\partial^2 y}{\partial t^2}
+EI\frac{\partial^4 y}{\partial x^4}
=F(t)\delta(x-x_0).
$$

理想悬臂边界条件为

$$
y(0,t)=0,\quad y_x(0,t)=0,
$$

$$
y_{xx}(L,t)=0,\quad y_{xxx}(L,t)=0.
$$

### 2.2 固有频率

令 $y=\phi(x)e^{i\omega t}$，可得特征方程

$$
\cos \lambda_n \cosh \lambda_n+1=0,
$$

其中前几阶根为

| 阶数 | $\lambda_n=\beta_nL$ | $f_n/f_1$ |
|---:|---:|---:|
| 1 | 1.875 | 1.00 |
| 2 | 4.694 | 6.27 |
| 3 | 7.855 | 17.55 |
| 4 | 10.996 | 34.39 |

固有频率为

$$
f_n=\frac{\lambda_n^2}{2\pi L^2}\sqrt{\frac{EI}{\rho A}}.
$$

代入 $I=bh^3/12$ 和 $A=bh$：

$$
\boxed{
f_n=\frac{\lambda_n^2}{2\pi\sqrt{12}}\frac{h}{L^2}\sqrt{\frac{E}{\rho}}
}
$$

这是理论部分最核心的演绎结果。

### 2.3 直接推论

固定材料和厚度：

$$
\boxed{f\propto L^{-2}}
$$

固定材料和长度：

$$
\boxed{f\propto h}
$$

固定长度、厚度、材料：

$$
\boxed{f\ \text{对}\ b\ \text{一阶不敏感}}
$$

改变材料：

$$
\boxed{f\propto \sqrt{E/\rho}}
$$

这些推论对应钢尺音调仿真图 `steel_pitch_frequency_scan.png`。coarse 3D 空气域扫描中，长度组满足

| $L$ (cm) | 仿真主频 (Hz) | $fL^2$ (Hz cm²) |
|---:|---:|---:|
| 10 | 161.743 | 16174 |
| 14 | 82.397 | 16150 |
| 18 | 49.438 | 16018 |
| 22 | 32.959 | 15952 |
| 26 | 23.804 | 16091 |

厚度组满足

| $h$ (mm) | 仿真主频 (Hz) | $f/h$ (Hz/mm) |
|---:|---:|---:|
| 1 | 20.142 | 20.14 |
| 2 | 40.283 | 20.14 |
| 3 | 60.425 | 20.14 |
| 4 | 79.956 | 19.99 |
| 5 | 100.098 | 20.02 |

宽度组在 $b=1$ 到 5 cm 内主频均为约 40.283 Hz，正是 $b$ 在 $I/A$ 中抵消后的结果。

## 3. 从冲量激励推出响度和敲击位置规律

### 3.1 模态展开

将位移写成模态叠加：

$$
y(x,t)=\sum_n q_n(t)\phi_n(x).
$$

代入梁方程并投影到第 $n$ 阶模态，得到

$$
\ddot q_n+2\zeta_n\omega_n\dot q_n+\omega_n^2q_n
=\frac{\phi_n(x_0)}{M_n}F(t),
$$

其中

$$
M_n=\int_0^L \rho A\phi_n^2(x)\,dx.
$$

### 3.2 短冲量极限

若敲击持续时间远短于振动周期，则对方程在冲击瞬间积分：

$$
\boxed{
\dot q_n(0^+)=\frac{J\phi_n(x_0)}{M_n}
}
$$

这条式子给出两个关键结论：

1. 冲量 $J$ 只线性放大模态响应幅值，不改变 $\omega_n$。
2. 敲击位置 $x_0$ 通过 $\phi_n(x_0)$ 选择模态；打在某阶模态节点附近，该阶模态几乎不被激发。

### 3.3 对仿真量的推论

在线性范围内，声压幅值与结构响应幅值成正比，因此

$$
p_\mathrm{rms}\propto J,
$$

而

$$
\mathrm{SPL}=20\log_{10}\left(\frac{p_\mathrm{rms}}{p_\mathrm{ref}}\right),
\qquad p_\mathrm{ref}=20\ \mu\mathrm{Pa}.
$$

所以冲量放大 2 倍，SPL 理论上增加约 6.02 dB；冲量放大 4 倍，SPL 增加约 12.04 dB。coarse 3D 空气域扫描中：

| $J$ (N s) | 主频 (Hz) | $p_\mathrm{rms}$ (Pa) | SPL (dB) |
|---:|---:|---:|---:|
| 0.02 | 40.283 | 0.2818 | 82.98 |
| 0.04 | 40.283 | 0.5579 | 88.91 |
| 0.06 | 40.283 | 0.8398 | 92.46 |
| 0.08 | 40.283 | 1.1211 | 94.97 |

主频不随 $J$ 改变，SPL 随 $J$ 按对数增加。对应仿真图为 `impulse_force_time.png` 和 `steel_sound_pressure_scan.png`。

敲击位置扫描中，仿真结果为

| $x_0/L$ | 主频 (Hz) | $p_\mathrm{rms}$ (Pa) | SPL (dB) |
|---:|---:|---:|---:|
| 0.25 | 249.023 | 1.499 | 97.50 |
| 0.50 | 249.023 | 2.618 | 102.34 |
| 0.75 | 244.141 | 0.684 | 90.69 |

该结果说明当前声压主峰并不总是一阶基频，而是由“模态形状 $\phi_n(x_0)$ × 声辐射效率 × 麦克风观测位置”共同选择出来的可听主导模态。

## 4. 从结构运动到麦克风声压

### 4.1 线性观测模型

在固定麦克风位置、固定空气域和线性声学范围内，可以把麦克风压力写成模态响应的线性观测：

$$
\boxed{
p_\mathrm{mic}(t)=\sum_n H_n q_n(t)
}
$$

或在加速度敏感近似下写成

$$
\boxed{
p_\mathrm{mic}(t)=\sum_n \tilde H_n \ddot q_n(t)
}
$$

$H_n$ 或 $\tilde H_n$ 吸收声辐射效率、麦克风距离、空气域边界、桌面/夹具耦合等因素。这个式子解释了为什么结构频率和麦克风主峰通常相关，但不必完全相同：麦克风测到的是“结构模态 × 声学传递函数”的结果。

### 4.2 单模态校准压力模型

为了生成与仿真图物理量一致的理论 CSV/PNG，项目中还使用了一个单模态灰箱模型：

$$
\boxed{
p_\mathrm{rms}=C\frac{Jh}{L^3}\left|\phi_1(x_0/L)\right|
}
$$

其中 $C$ 由 3D 空气域基准 case 标定。该式不是普适绝对声压定律，而是用于把理论曲线落到和仿真相同的观测量：`pressure_rms_pa` 与 `spl_db`。

对应输出位于 `outputs/requested_theory_steel_mic2cm/`：

| 理论图 | 物理量 |
|---|---|
| `figures/zh/frequency_theory_panels_zh.png` | 理论主频 |
| `figures/zh/pressure_theory_panels_zh.png` | 理论 $p_\mathrm{rms}$ |
| `figures/zh/spl_theory_panels_zh.png` | 理论 SPL |

该理论模型给出与仿真相同的三类结果物理量：频率、声压有效值、声压级。

## 5. 从声压时程推出音调、响度和频域音色

实验和仿真的共同原始对象是麦克风声压时程 $p(t)$。对 $p(t)$ 做 FFT 得到复频谱 $P(f)$，令能量谱为 $S(f)=|P(f)|^2$。

### 5.1 音调指标

主频定义为有效频带内最大谱峰：

$$
\boxed{
f_\mathrm{dom}=\arg\max_{f\in[f_\mathrm{min},f_\mathrm{max}]} |P(f)|
}
$$

项目后处理中，对麦克风音调主峰使用 20-2500 Hz 有效频带；0-20 Hz 显示在频谱中，但不作为音调和持续时间主峰。

为了降低 FFT bin 误差，正式结果使用抛物线精化后的 `f_dom_refined_hz`。实验上对应：录音或麦克风采集后做窗函数、FFT、峰值插值。

### 5.2 响度代理指标

声压有效值为

$$
\boxed{
p_\mathrm{rms}=\sqrt{\frac{1}{T}\int_0^T p^2(t)\,dt}
}
$$

声压级为

$$
\boxed{
\mathrm{SPL}_\mathrm{rms}=20\log_{10}\left(\frac{p_\mathrm{rms}}{20\ \mu\mathrm{Pa}}\right)
}
$$

仿真中的 `spl_rms_db` 是固定麦克风位置处的声压级代理，不等于完整主观 loudness。实验时必须固定麦克风距离、角度和增益，并关闭自动增益控制。

### 5.3 频谱质心

频谱质心定义为能量加权平均频率：

$$
\boxed{
f_c=\frac{\int fS(f)\,df}{\int S(f)\,df}
}
$$

它不是主频，而是描述频谱“重心”。同样主频下，若中高频能量更多，$f_c$ 会升高。

### 5.4 频谱平坦度

频谱平坦度为

$$
\boxed{
\mathrm{flatness}
=\frac{\exp\left(\langle \ln S(f)\rangle\right)}
{\langle S(f)\rangle}
}
$$

平坦度低表示少数尖锐谱峰主导；平坦度高表示频谱更宽、更复杂。

### 5.5 频带能量比例

把有效频带分成低/中/高频区间，定义

$$
\boxed{
R_k=\frac{\int_{B_k}S(f)\,df}{\int S(f)\,df}
}
$$

其中 $k$ 可为 low、mid、high。它比单一质心更适合解释“音色差异来自哪些频段”。

## 6. 从衰减包络推出 Q 因子和时间音色

若某一模态的自由衰减近似为

$$
q_n(t)=A_ne^{-\alpha_nt}\cos(\omega_{d,n}t+\varphi_n),
$$

则 Q 因子为

$$
\boxed{
Q_n=\frac{\pi f_n}{\alpha_n}
}
$$

如果用相邻峰值 $A_k$ 提取对数衰减率

$$
\delta=\ln\left(\frac{A_k}{A_{k+1}}\right),
$$

小阻尼下有

$$
\boxed{
Q\approx\frac{\pi}{\delta}
}
$$

这对应仿真表中的 `q_estimate` 和 `log_decrement`。实验上可用激光位移、加速度计或麦克风包络拟合；若目标是材料阻尼，优先用结构位移或速度测量，麦克风衰减会混入房间和声学传播效应。

## 7. 材料音色的演绎解释

材料改变 $E$、$\rho$ 和阻尼。由频率公式可知：

$$
f_n\propto \sqrt{E/\rho}.
$$

材料还通过阻尼改变 $Q$，通过声辐射效率和模态耦合改变麦克风频谱。因此材料音色不能只看主频，应同时看主频、SPL、频谱质心、平坦度、频带能量比例和 Q。

增强 medium 低冲量仿真给出：

| 材料 | $f_\mathrm{dom}$ (Hz) | SPL (dB) | 质心 (Hz) | 平坦度 | Q | 低/中/高频能量 | 线性状态 |
|---|---:|---:|---:|---:|---:|---|---|
| Steel | 39.7 | 62.0 | 67.4 | 0.0066 | 67.9 | 98.2% / 1.3% / 0.5% | linear |
| Acrylic | 13.5 | 81.0 | 140.2 | 0.0161 | 29.6 | 85.9% / 8.4% / 5.8% | linear |
| PVC | 12.1 | 80.7 | 235.0 | 0.0255 | 28.6 | 73.0% / 17.3% / 9.7% | linear |
| Satinwood | 32.1 | 82.8 | 62.1 | 0.0053 | 55.1 | 98.9% / 0.6% / 0.5% | linear |
| Xuefu board | 8.2 | 88.2 | 800.3 | 0.0615 | 31.1 | 77.9% / 2.1% / 20.0% | nonlinear_risk |

演绎解释如下：

1. Steel 和 Satinwood 的低频能量占比超过 98%，频谱质心低、平坦度低，因此表现为低频离散谱峰主导。
2. Acrylic 和 PVC 的主频较低，但质心和中高频能量比例更高，说明声学输出不是单纯低频，而是更多副峰参与。
3. PVC 在四个线性主材料中平坦度和高频比例最高，可作为宽频复杂频谱的代表。
4. Xuefu board 的频谱最复杂，但 `probe_peak_over_L=0.119` 超过线性强结论阈值，因此只能作为诊断性结果。

对应仿真图为：

| 图 | 解释对象 |
|---|---|
| `outputs/requested_timbre_complete_enhanced_medium/figures/paper_analysis/timbre_lowJ_material_map.png` | 质心-平坦度-SPL 音色空间 |
| `outputs/requested_timbre_complete_enhanced_medium/figures/paper_analysis/timbre_lowJ_energy_bands.png` | 低/中/高频能量比例 |
| `outputs/requested_timbre_complete_enhanced_medium/figures/paper_analysis/timbre_lowJ_q_frequency.png` | Q 因子与主频关系 |
| `outputs/requested_timbre_complete_enhanced_medium/figures/paper_analysis/timbre_J_sensitivity.png` | 双冲量线性风险 |

## 8. 线性边界与非线性风险

线性理论要求小挠度。项目用

$$
\boxed{
\chi=\frac{\text{probe\_peak}}{L}
}
$$

作为工程判据：

| 判据 | 解释 | 论文使用 |
|---|---|---|
| $\chi\le 0.05$ | 小挠度线性可信 | 主结论 |
| $0.05<\chi\le 0.10$ | 接近边界 | 谨慎趋势 |
| $\chi>0.10$ | 非线性风险高 | 诊断或降级解释 |

双冲量仿真中，$J_\mathrm{orig}=0.04$ N s 相对 $J_\mathrm{low}=0.004$ N s 放大 10 倍。若系统线性，SPL 应增加约 20 dB，主频基本不变。结果中 Steel 保持 linear；Acrylic、PVC、Satinwood 在原始冲量下 `probe_peak_over_L` 增至 0.34-0.44，不能作为线性材料主结论；Xuefu board 在低冲量下也已进入 nonlinear_risk。

因此理论部分的严谨结论是：冲量改变主要影响响度，但只有在 $\chi$ 足够小时，才能把这种变化解释为线性幅值缩放。

## 9. 与仿真结果图一一对应的理论推论

| 理论推论 | 仿真结果物理量 | 已有仿真图 | 实验可测指标 |
|---|---|---|---|
| $f\propto L^{-2}$ | `f_dom_hz`, `f_dom_refined_hz` | `outputs/requested_3d_air_coarse_review_light/figures/steel_pitch_frequency_scan.png` | 改变外伸长度，麦克风 FFT 主峰或激光测振频率；画 $f$ vs $1/L^2$ |
| $f\propto h$ | `f_dom_hz` | `steel_pitch_frequency_scan.png` | 不同厚度尺，测主频；画 $f$ vs $h$ |
| $f$ 对 $b$ 一阶不敏感 | `f_dom_hz` | `steel_pitch_frequency_scan.png` | 不同宽度同材料样条，测主频 |
| $p_\mathrm{rms}\propto J$，SPL 随 $20\log J$ 变化 | `p_rms_pa`, `spl_db` | `steel_sound_pressure_scan.png`, `impulse_force_time.png` | 摆锤/落锤标定冲量，固定麦克风测 RMS 声压 |
| 敲击位置选择模态 | `f_dom_hz`, `second_peak_freq_hz`, SPL | `steel_pitch_frequency_scan.png`, `steel_sound_pressure_scan.png` | 改变 $x_0/L$，测主频、次峰、主峰/次峰比 |
| 材料改变 $f,\ Q,$ 频谱分布 | `spectral_centroid_hz`, `spectral_flatness`, 能量比例、Q | `timbre_lowJ_material_map.png`, `timbre_lowJ_energy_bands.png`, `timbre_lowJ_q_frequency.png` | 多材料样本，固定几何和冲量，录音 FFT + 包络拟合 |
| 线性边界由相对振幅控制 | `probe_peak_over_L` | `timbre_J_sensitivity.png` | 高速视频/激光测振测峰值位移，计算 $A/L$ |
| 衰减决定时间音色 | `q_estimate`, `log_decrement`, `decay_time_50pct_s` | `timbre_material_frequency_duration_panels.png`, `timbre_steel_frequency_duration.png` | 声压或位移包络指数拟合；统计有效频率持续时间 |

## 10. 实验测量闭环

### 10.1 必测输入量

| 输入量 | 测量方法 | 用途 |
|---|---|---|
| $L,b,h$ | 直尺、游标卡尺，多点取平均 | 验证 $f\propto L^{-2}$、$f\propto h$ |
| 材料密度 $\rho$ | 称质量 / 测体积 | 估计 $\sqrt{E/\rho}$ |
| 冲量 $J$ | 摆锤质量和速度、力传感器积分或反弹速度估算 | 验证 SPL-冲量关系 |
| 敲击位置 $x_0/L$ | 标尺定位 | 验证模态选择 |
| 麦克风距离和角度 | 固定支架 | 保证 SPL 可比较 |
| 夹紧条件 | 台钳、扭矩或夹紧角度记录 | 控制边界柔度 |

### 10.2 必测输出量

| 输出量 | 推荐传感器 | 对应仿真字段 |
|---|---|---|
| 声压时程 $p(t)$ | 外置麦克风/录音笔，关闭 AGC | `mic_pressure_timeseries.csv` |
| 主频和次峰 | FFT/STFT | `f_dom_refined_hz`, `second_peak_freq_hz` |
| RMS 声压和 SPL | 校准麦克风 | `p_rms_pa`, `spl_rms_db` |
| 自由端或探针位移 | 激光测振、高速视频、光杠杆 | `tip_peak_m`, `probe_peak_m` |
| Q 因子和对数衰减 | 位移或声压包络拟合 | `q_estimate`, `log_decrement` |
| 频谱质心/平坦度/能量比例 | 录音后处理 | `spectral_centroid_hz`, `spectral_flatness`, energy ratios |

### 10.3 最小实验矩阵

为了让理论、仿真和实验形成闭环，建议最小矩阵为：

| 扫描 | 建议取值 | 核心验证 |
|---|---|---|
| 外伸长度 $L$ | 10, 14, 18, 22, 26 cm | $fL^2$ 是否近似常数 |
| 厚度 $h$ | 1, 2, 3, 4, 5 mm | $f/h$ 是否近似常数 |
| 宽度 $b$ | 1, 2, 3, 4, 5 cm | 主频是否一阶不敏感，SPL 是否随辐射面积变化 |
| 冲量 $J$ | 至少 4 档 | 主频是否不变，SPL 是否按 $20\log J$ 增加 |
| 敲击位置 $x_0/L$ | 0.25, 0.50, 0.75 | 模态选择和主峰/次峰变化 |
| 材料 | Steel, Acrylic, PVC, Satinwood, Xuefu board | 频谱音色代理指标对比 |

## 11. 理论结论

1. 悬臂梁理论演绎出 $f_n=\lambda_n^2 h(2\pi\sqrt{12}L^2)^{-1}\sqrt{E/\rho}$，直接解释仿真中的长度平方反比、厚度正比和宽度一阶不敏感。
2. 短冲量模态投影给出 $\dot q_n(0^+)=J\phi_n(x_0)/M_n$，直接解释冲量只改变响度、不改变主频，以及敲击位置会改变主导模态和频谱。
3. 线性声学观测模型 $p_\mathrm{mic}(t)=\sum H_nq_n(t)$ 把结构响应连接到麦克风声压，因此理论最终输出必须是 `f_dom`, `p_rms`, `SPL`, 频谱指标和衰减指标，而不只是结构固有频率。
4. 材料音色的可比结论应建立在低冲量、小挠度条件下；当前 Steel、Acrylic、PVC、Satinwood 可作为主结论材料，Xuefu board 需降级解释。
5. 实验验证的核心不是复现 COMSOL 的所有场变量，而是测量同一组可观测指标：主频、RMS 声压/SPL、频谱质心、平坦度、频带能量比例、Q 因子、相对振幅和有效频率持续时间。

## 12. 本文档使用的本地数据源

| 数据源 | 用途 |
|---|---|
| `D:\Learning Resources\Obsidian\Archive\物理学术竞赛\Main 13  The Singing Ruler\理论模型（终版）.md` | 理论框架参考 |
| `outputs/requested_3d_air_coarse_review_light/tables/all_requested_cases.csv` | 27 个 3D 空气域 coarse 结果 |
| `outputs/requested_3d_air_coarse_review_light/summary.json` | 仿真结果图路径和后处理口径 |
| `outputs/requested_timbre_complete_enhanced_medium/tables/paper_analysis/timbre_lowJ_primary_summary.csv` | 增强 medium 低冲量材料音色主结论 |
| `outputs/requested_timbre_complete_enhanced_medium/tables/paper_analysis/timbre_J_sensitivity.csv` | 双冲量线性风险 |
| `outputs/requested_theory_steel_mic2cm/csv/all_theory_points.csv` | 理论曲线离散点 |
| `outputs/requested_theory_steel_mic2cm/summary.json` | 理论模型公式和标定参数 |

