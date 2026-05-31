# 尺子之歌 — 公式集

> Obsidian 中直接渲染。点击公式 → 复制 LaTeX 源码 → 粘贴到 PPT 公式框（Alt+=→LaTeX 模式）。

---

## 一、Euler-Bernoulli 悬臂梁推导

**Eq.1** — 控制方程。惯性力与弹性恢复力平衡。

$$
\rho A\frac{\partial^2 w(x,t)}{\partial t^2}+EI\frac{\partial^4 w(x,t)}{\partial x^4}=0
$$

**Eq.2** — 分离变量解。空间模态与简谐时间函数乘积叠加。

$$
w(x,t)=\sum_n\Phi_n(x)e^{i\omega_n t}
$$

**Eq.3** — 空间四阶常微分方程。

$$
EI\frac{d^4\Phi}{dx^4}-\omega^2\rho A\Phi=0
$$

**Eq.4** — 通解形式，三角函数与双曲函数的线性组合。

$$
\Phi(x)=C_1\cos(\beta x)+C_2\sin(\beta x)+C_3\cosh(\beta x)+C_4\sinh(\beta x)
$$

**Eq.5** — 固定端边界条件，位移与转角为零。

$$
\Phi(0)=0,\;\Phi'(0)=0
$$

**Eq.6** — 自由端边界条件，弯矩与剪力为零。

$$
\Phi''(L)=0,\;\Phi'''(L)=0
$$

**Eq.7** — 特征方程。边界条件代入通解，系数行列式为零导出。

$$
\cos(\beta L)\cosh(\beta L)+1=0
$$

**Eq.8** — 前四个特征根。

$$
\beta_1L=1.875,\;\beta_2L=4.694,\;\beta_3L=7.855,\;\beta_4L=10.996
$$

**Eq.9** — 基频公式。由 `β⁴=ρAω²/EI` 解出。

$$
f_1=\frac{(\beta_1L)^2}{2\pi L^2}\sqrt{\frac{EI}{\rho A}}
$$

**Eq.10** — 矩形截面几何量。

$$
I=\frac{bh^3}{12},\quad A=bh
$$

**Eq.11** — 基频简化形式。宽度 b 消去——基频与尺子宽度无关。

$$
f_1=\frac{1.875^2}{2\pi}\cdot\frac{h}{L^2}\cdot\sqrt{\frac{E}{12\rho}}
$$

**Eq.12** — 三条缩放律，构成实验验证的核心假设。

$$
f_1\propto\frac{1}{L^2},\quad f_1\propto h,\quad f_1\propto\sqrt{\frac{E}{\rho}}
$$

---

## 二、几何非线性 (gNL)

**Eq.13** — Green-Lagrange 应变张量。保留位移梯度二阶项。

$$
E_{ij}=\frac{1}{2}\left(\frac{\partial u_i}{\partial x_j}+\frac{\partial u_j}{\partial x_i}+\sum_k\frac{\partial u_k}{\partial x_i}\frac{\partial u_k}{\partial x_j}\right)
$$

**Eq.14** — 等效刚度近似。膜应力贡献正比于 (w/h)²。

$$
\frac{k_{\rm eff}}{k_{\rm linear}}\approx 1+\alpha\left(\frac{w_{\rm max}}{h}\right)^2
$$

---

## 三、模态分类

**Eq.15** — 面内与面外弯曲基频比。等于截面宽厚比 b/h。

$$
\frac{f_{\rm in,1}}{f_{z,1}}=\sqrt{\frac{I_y}{I_z}}=\frac{b}{h}
$$

$$
I_z=\frac{bh^3}{12},\quad I_y=\frac{hb^3}{12}
$$

**Eq.16** — 方向性声压级差。

$$
\Delta{\rm SPL}=20\log_{10}\left(\frac{b}{h}\right)=20\log_{10}(15)\approx 23.5\;{\rm dB}
$$

---

## 四、Rayleigh 阻尼与衰减

**Eq.17** — Rayleigh 阻尼矩阵。质量比例 α 项 + 刚度比例 β 项。

$$
[C]=\alpha[M]+\beta[K]
$$

**Eq.18** — 模态阻尼比。U 形曲线——低频由 α 主导，高频由 β 主导。

$$
\zeta_n=\frac{\alpha}{2\omega_n}+\frac{\beta\omega_n}{2}
$$

**Eq.19** — Rayleigh 参数的控制频率标定。

$$
\alpha=\frac{4\pi\zeta f_{\rm low}f_{\rm high}}{f_{\rm low}+f_{\rm high}},\quad\beta=\frac{\zeta}{\pi(f_{\rm low}+f_{\rm high})}
$$

**Eq.20** — 衰减时间。实验可测，仿真-理论对比的桥梁。

$$
\tau_1=\frac{1}{\zeta_{\rm eff}(f_1)\cdot 2\pi f_1}
$$

---

## 五、Hertz 接触与冲量

**Eq.21** — 接触半径。正比于载荷与球半径的立方根。

$$
a=\left(\frac{3FR}{4E^*}\right)^{1/3},\quad E^*=\frac{E}{1-\nu^2}
$$

**Eq.22** — 接触面压力分布。椭球形，中心最大。

$$
p(r)=p_0\sqrt{1-\left(\frac{r}{a}\right)^2}
$$

**Eq.23** — 跨材料有效冲量缩放。接触刚度 ∝ E^(2/3) → J ∝ E^(1/3)。

$$
\frac{J_{\rm eff}}{J_{\rm steel}}=\left(\frac{E_{\rm target}}{E_{\rm steel}}\right)^{1/3}
$$

---

## 六、音色

**Eq.24** — 多模态叠加声压。各阶独立频率 fₙ 与衰减时间 τₙ。

$$
p(t)=\sum_n A_n e^{-t/\tau_n}\sin(2\pi f_n t+\phi_n)
$$

**Eq.25** — 基频模态能量占比。随时间单调上升。

$$
R_1(t)=\frac{A_1^2 e^{-2t/\tau_1}}{\sum_k A_k^2 e^{-2t/\tau_k}}
$$

---

## 七、响度

**Eq.26** — SPL 与冲量的对数关系。

$$
{\rm SPL}=A+20\log_{10}J
$$

**Eq.27** — 方向性 SPL 差。辐射面积比的对数。

$$
\Delta{\rm SPL}=20\log_{10}\left(\frac{30\;{\rm mm}}{2\;{\rm mm}}\right)=23.5\;{\rm dB}
$$

**Eq.28** — 球面扩散距离衰减。

$$
{\rm SPL}(r)={\rm SPL}_0-20\log_{10}\left(\frac{r}{r_0}\right)
$$

---

## 八、实验拟合公式

**Eq.29** — f₁ vs L 幂律模型。

$$
f_1=C\cdot L^n
$$

**Eq.30** — f₁ vs h 线性过原点模型。

$$
f_1=k\cdot h
$$

**Eq.31** — f₁ vs 材质声速模型。

$$
f_1=C\cdot\sqrt{\frac{E}{\rho}}
$$

**Eq.32** — SPL vs J 半对数模型。

$$
{\rm SPL}=A+B\cdot\log_{10}J
$$

---

*共 32 条公式。Obsidian 中 $$ 块直接渲染。点击公式 → 复制 LaTeX → Alt+= 打开 PPT 公式框 → LaTeX 模式 → 粘贴。PPT 中 `\frac` 与 `\over` 均可用，推荐 `\frac`。*
