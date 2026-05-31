# 摘要与引言

> 本文档为论文摘要和引言章节的初稿，与 `PAPER_DRAFT_RESULTS_DISCUSSION_ZH.md`（结果与讨论）配合使用。
> 所有结果基于 COMSOL 三维声场有限元仿真，数据来源于 `outputs/requested_timbre_complete_enhanced_medium/`。

---

## 摘要

悬臂尺子的敲击发声是一个经典的结构-声学耦合现象，其音调、响度和音色受几何参数、激励条件和材料性质的共同影响。本文采用 COMSOL Multiphysics 三维声-结构耦合有限元仿真，系统研究了 5 种材料（钢、亚克力、PVC、绸木、学府板）在 27 个仿真 case 下的声学输出，覆盖自由段长度（10–26 cm）、厚度（1–5 mm）、宽度（1–5 cm）、脉冲幅值（0.02–0.08 N·s）和敲击位置（x₀/L = 0.25–0.75）的参数扫描。

仿真主频与经典悬臂梁理论定量吻合：频率与自由段长度的平方成反比（f × L² = 16106 ± 28 Hz·cm²，变异系数 0.17%），与厚度成正比（f/h = 20.10 ± 0.11 Hz/mm，R² > 0.999）。脉冲幅值在弹性范围内仅影响声压级（增幅 +12.0 dB）而不改变主频（波动 < 0.01 Hz），验证了系统线性行为。

为比较不同材料的频谱音色，本文采用增强 medium 品质仿真（0.75 s 时间窗、1×10⁻⁴ s 时间步、100 网格单元）和双冲量策略：低冲量 J_low = 0.004 N·s 作为主结论来源，原始冲量 J_orig = 0.04 N·s 作为线性风险诊断对照。结果显示，5 种材料在由频谱质心（62–800 Hz）、频谱平坦度（0.005–0.062）和低/中/高频能量比例构成的"音色代理空间"中形成可区分分布。Q 因子在 28.6–67.9 之间，趋势与 Rayleigh 阻尼模型一致。模态声学耦合分析表明，全部 27 个 case 的结构特征频率与声学频谱峰值均成功匹配，匹配误差在窄梁条件下低于 1%。其中钢、亚克力、PVC 和绸木的 J_low 结果满足小挠度线性阈值（probe_peak/L ≤ 0.05），可作为材料音色主结论；学府板虽在 J_low 下仍接近非线性边界（probe_peak/L = 0.119），需降级解释。本文展示了有限元仿真代理指标用于材料音色比较的可行性和局限性。

**关键词：** 悬臂梁；声-结构耦合；有限元仿真；音色；频谱质心；Q 因子

---

## 1. 引言

### 1.1 研究背景

尺子伸出桌边、拨动后发出的"嗒嗒"声是日常生活中常见的物理现象。这一现象虽看似简单，却包含了连续介质力学和声学的核心问题：弹性结构在瞬态激励下发生弯曲振动，表面运动通过空气辐射形成可听声。从工程角度看，这是一个典型的结构-声学耦合问题；从乐器声学角度看，它与音板、簧片等振动体的发声机制具有相同的物理基础。

与乐器声学研究中广泛关注的弦、膜、板等结构不同，悬臂尺子的几何形态（细长梁，一端固支，一端自由）决定了其振动以低阶弯曲模态为主，频谱结构相对简单。这种简化使其成为一个理想的模型系统：一方面，梁弯曲振动的理论解完整已知（Euler-Bernoulli 和 Timoshenko 梁理论），为仿真结果提供了精确的定量验证基准；另一方面，材料参数的变化可以直接映射到声学输出的变化上，为隔离研究材料对音色的影响提供了可控的实验平台。

### 1.2 现有研究回顾

**梁振动理论**

悬臂梁的弯曲振动频率由 Rayleigh [1] 和 Timoshenko [2] 奠定的经典理论给出。对于均匀等截面 Euler-Bernoulli 梁，第 n 阶固有频率为

$$f_n = \frac{C_n^2}{2\pi} \cdot \frac{h}{L^2} \sqrt{\frac{E}{12\rho}}$$

其中 C_n 为特征值（C₁ ≈ 1.875，C₂ ≈ 4.694），L 为自由段长度，h 为厚度，E 为杨氏模量，ρ 为密度。该公式揭示了频率与几何、材料参数之间的显式依赖关系，为本研究的仿真验证提供了理论基准。

在数值仿真方面，有限元方法已被广泛用于梁和板的振动分析[3,4]。COMSOL Multiphysics 等商业软件通过三维实体单元和声-结构耦合边界条件，能够同时捕获结构振动和远场声压，为声学输出指标的高精度提取提供了计算基础。

**音色的仿真代理指标**

传统音色研究依赖心理声学实验和主观评价[5]。近年来，基于频谱的音色描述符被广泛用于乐器声学和音频分析[6]，包括频谱质心（spectral centroid）、频谱平坦度（spectral flatness）、频谱滚降点（rolloff）、频谱斜率（spectral slope）和频带能量比例等。这些指标已在乐器分类[7]、音源识别[8]和音乐信息检索[9]中取得广泛应用。然而，在物理仿真-声学输出链路中，这些指标作为材料比较的代理工具尚未得到系统验证。

**阻尼与衰减**

Q 因子（品质因子）和对数衰减率是描述结构阻尼特性的关键参数[10]。在 Rayleigh 阻尼模型下，低频模态的等效阻尼比通常高于高频模态，即 Q 值随频率升高而增大。对于复合材料（如学府板），内部界面的摩擦耗能可能显著增加等效阻尼，导致 Q 值降低[11]。

### 1.3 研究空白与本文动机

现有梁振动研究主要关注结构的力学响应（应力、应变、模态频率），将力学响应传递至远场声压后对声学输出做系统分析的工作相对较少。具体而言，以下问题尚未得到充分回答：

1. **梁振动理论的结果可以在多大精度上被三维声-结构耦合仿真复现？** 特别是在粗网格和有限时间窗口下的工程精度边界。
2. **材料变化如何通过结构动力学传递到声学频谱输出？** 频谱质心、平坦度等代理指标能否在仿真环境下形成可区分的材料分类依据？
3. **适合音色比较的线性工作条件是什么？** 给定双冲量策略，哪些材料在低冲量下满足小挠度线性假设，哪些材料即使低冲量也需谨慎解释？

为回答上述问题，本文设计了一个包含 27 个仿真 case 的系统性参数研究，采用增强 medium 品质仿真数据。本文的贡献在于：（1）对梁振动理论预测进行了高精度的仿真定量验证；（2）建立了基于频谱质心、频谱平坦度、频带能量比例和 Q 因子的材料音色仿真代理指标体系；（3）明确了不同材料在双冲量策略下的线性/非线性判定和结论适用范围。

### 1.4 本文结构

本文其余部分组织如下：第 2 节介绍仿真方法和指标定义；第 3 节报告音调与结构参数关系的验证结果；第 4 节分析响度与激励参数的关系；第 5 节展示材料对音色的影响；第 6 节讨论模态声学耦合验证结果；第 7 节报告频带衰减与 Q 因子估计结果；第 8 节总结主要结论并提出工作的局限性。

---

## 参考文献

[1] Rayleigh, J. W. S. *The Theory of Sound*, Vol. 1, Macmillan, 1877.
[2] Timoshenko, S. P. "On the correction for shear of the differential equation for transverse vibrations of prismatic bars." *Philosophical Magazine*, Vol. 41, 1921, pp. 744–746.
[3] Reddy, J. N. *An Introduction to the Finite Element Method*, 3rd ed., McGraw-Hill, 2006.
[4] Zienkiewicz, O. C., Taylor, R. L., and Zhu, J. Z. *The Finite Element Method: Its Basis and Fundamentals*, 7th ed., Butterworth-Heinemann, 2013.
[5] American National Standards Institute. *ANSI S1.1-1994: Acoustical Terminology*, 1994.
[6] Peeters, G. "A large set of audio features for sound description (similarity and classification) in the CUIDADO project." *IRCAM Technical Report*, 2004.
[7] Herrera, P., et al. "Automatic classification of musical instrument sounds." *Journal of New Music Research*, Vol. 29, No. 4, 2000, pp. 307–326.
[8] Eronen, A., and Klapuri, A. "Musical instrument recognition using cepstral coefficients and temporal features." *IEEE International Conference on Acoustics, Speech, and Signal Processing*, 2000.
[9] Tzanetakis, G., and Cook, P. "Musical genre classification of audio signals." *IEEE Transactions on Speech and Audio Processing*, Vol. 10, No. 5, 2002, pp. 293–302.
[10] Chopra, A. K. *Dynamics of Structures: Theory and Applications to Earthquake Engineering*, 5th ed., Pearson, 2017.
[11] Gibson, R. F. *Principles of Composite Material Mechanics*, 4th ed., CRC Press, 2016.
