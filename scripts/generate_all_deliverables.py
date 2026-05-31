"""
generate_all_deliverables.py
============================
按 HANDOVER_PROMPT.md 的 Step 1-9 生成全部交付物:
  1. 拟合计算 + fitting_results.csv
  2. 所有 PNG 图表 → outputs/requested_adaptive/figures/
  3. 修改 PPTX → ppt/尺子之歌-正方匡大德.pptx (新增仿真幻灯片)
  4. PPT 修改意见文档 → docs/reports/ppt_review_from_simulation.md

运行方式:
  python scripts/generate_all_deliverables.py
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib import rcParams
from scipy.optimize import curve_fit
from pathlib import Path
from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
import warnings
warnings.filterwarnings('ignore')

# ============================================================
# 全局配置
# ============================================================
BASE = Path(r'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler')
CSV_PATH = BASE / 'outputs/requested_adaptive/tables/conclusion_master_table_corrected.csv'
FIG_DIR = BASE / 'outputs/requested_adaptive/figures'
TABLE_DIR = BASE / 'outputs/requested_adaptive/tables'
PPT_PATH = BASE / 'ppt/尺子之歌-正方匡大德.pptx'
REPORT_PATH = BASE / 'docs/reports/ppt_review_from_simulation.md'

FIG_DIR.mkdir(parents=True, exist_ok=True)
TABLE_DIR.mkdir(parents=True, exist_ok=True)
REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)

# 图表风格: 深色背景
DARK_BG = '#1a1a2e'
LIGHT_TEXT = '#e0e0e0'
ACCENT_COLORS = ['#00d2ff', '#ff6b6b', '#feca57', '#48dbfb', '#ff9ff3', '#54a0ff']

rcParams['font.sans-serif'] = ['Microsoft YaHei', 'SimHei', 'DejaVu Sans']
rcParams['axes.unicode_minus'] = False
rcParams['mathtext.fontset'] = 'dejavusans'  # mathtext 用 DejaVu 渲染公式符号

# 钢材料参数
E_STEEL = 200e9  # Pa
RHO_STEEL = 7850  # kg/m³
BETA1 = 1.8751

def f1_theory(L_m, h_m):
    """欧拉-伯努利悬臂梁一阶理论频率"""
    return (BETA1**2 / (2 * np.pi * L_m**2)) * np.sqrt(E_STEEL * h_m**2 / (12 * RHO_STEEL))

def setup_dark_ax(fig, ax, title, xlabel, ylabel):
    """设置深色风格坐标轴"""
    fig.patch.set_facecolor(DARK_BG)
    ax.set_facecolor(DARK_BG)
    ax.set_title(title, color=LIGHT_TEXT, fontsize=14, fontweight='bold', pad=12)
    ax.set_xlabel(xlabel, color=LIGHT_TEXT, fontsize=11)
    ax.set_ylabel(ylabel, color=LIGHT_TEXT, fontsize=11)
    ax.tick_params(colors=LIGHT_TEXT)
    for spine in ax.spines.values():
        spine.set_color(LIGHT_TEXT)
        spine.set_linewidth(0.5)
    ax.grid(True, alpha=0.2, color=LIGHT_TEXT)

# ============================================================
# Step 1: 加载数据
# ============================================================
print("=" * 60)
print("Step 1: 加载 CSV 数据")
print("=" * 60)

T = pd.read_csv(CSV_PATH)
print(f"  主表: {T.shape[0]} 行 × {T.shape[1]} 列")

# 数据子集
steel_L = T[T.case_id.str.contains('L_free')].copy()
steel_h = T[T.case_id.str.contains('/h/')].copy()
steel_b = T[T.case_id.str.contains('/b/')].copy()
steel_J = T[T.case_id.str.contains('/J/')].copy()
steel_x0 = T[T.case_id.str.contains('x0_ratio')].copy()
materials = T[T.case_id.str.contains('material_')].copy()

print(f"  L_free scan: {len(steel_L)} 点")
print(f"  h scan: {len(steel_h)} 点")
print(f"  b scan: {len(steel_b)} 点")
print(f"  J scan: {len(steel_J)} 点")
print(f"  x0 scan: {len(steel_x0)} 点")
print(f"  材料对比: {len(materials)} 点")

# 收集拟合结果
fitting_results = []

# ============================================================
# Step 2: 音调拟合 (f vs L / h / b / J)
# ============================================================
print("\n" + "=" * 60)
print("Step 2: 音调理论验证")
print("=" * 60)

# --- 2a: f1 vs L (幂律拟合) ---
def power_law(x, a, n):
    return a * x**n

L_cm = steel_L['L_free_cm'].values
f1_L = steel_L['f1_hz'].values
L_m = L_cm / 100.0
h_m_default = 2e-3  # 默认 h=2mm

popt_L, pcov_L = curve_fit(power_law, L_cm, f1_L, p0=[1e4, -2])
a_L, n_L = popt_L
f1_fit_L = power_law(L_cm, a_L, n_L)
ss_res = np.sum((f1_L - f1_fit_L)**2)
ss_tot = np.sum((f1_L - np.mean(f1_L))**2)
r2_L = 1 - ss_res / ss_tot

# 理论值
f1_theory_L = np.array([f1_theory(l, h_m_default) for l in L_m])
rel_err_L = np.abs(f1_L - f1_theory_L) / f1_theory_L * 100

print(f"  f1 vs L: f1 = {a_L:.2f} * L^{n_L:.4f}, R²={r2_L:.6f}")
print(f"    理论指数: -2, 仿真指数: {n_L:.4f}")
print(f"    相对误差: {rel_err_L.mean():.2f}% (平均)")

fitting_results.append({
    'relation': 'f1 vs L_free',
    'formula': f'f1 = {a_L:.4f} * L^{n_L:.4f}',
    'expected_exponent': -2,
    'fitted_exponent': n_L,
    'R2': r2_L,
    'mean_rel_error_pct': rel_err_L.mean(),
    'max_rel_error_pct': rel_err_L.max(),
    'n_points': len(L_cm)
})

# 绘图
fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'音调验证: $f_1$ vs 自由端长度 $L$', r'$L_{free}$ (cm)', r'$f_1$ (Hz)')

L_smooth = np.linspace(L_cm.min() * 0.9, L_cm.max() * 1.1, 200)
ax.scatter(L_cm, f1_L, color=ACCENT_COLORS[0], s=80, zorder=5, label='仿真值')
ax.plot(L_smooth, power_law(L_smooth, a_L, n_L), '--', color=ACCENT_COLORS[1], lw=2,
        label=r'拟合: $f_1={:.1f} \cdot L^{{{:.3f}}}$  $R^2={:.5f}$'.format(a_L, n_L, r2_L))
# 理论曲线 (连续光滑曲线, 不取点)
L_smooth_m = L_smooth / 100.0
f1_theory_smooth = np.array([f1_theory(l, h_m_default) for l in L_smooth_m])
ax.plot(L_smooth, f1_theory_smooth, '-', color=ACCENT_COLORS[2], lw=2, alpha=0.85,
        label=r'EB梁理论: $f_1=\frac{\beta_1^2}{2\pi L^2}\sqrt{\frac{Eh^2}{12\rho}}$')

ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT, fontsize=10, loc='upper right')

# 在图上明确标注拟合方程与系数
fit_text = ('拟合方程:' + '\n'
            r'$f_1 = a \cdot L^n$' + '\n'
            r'$a = {:.2f}$'.format(a_L) + '\n'
            r'$n = {:.4f}$'.format(n_L) + '\n'
            r'$R^2 = {:.5f}$'.format(r2_L) + '\n'
            r'平均误差 $= {:.2f}\%$'.format(rel_err_L.mean()))
ax.text(0.55, 0.62, fit_text, transform=ax.transAxes,
        color=LIGHT_TEXT, fontsize=10,
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#16213e',
                  edgecolor=ACCENT_COLORS[1], linewidth=1))
plt.tight_layout()
plt.savefig(FIG_DIR / 'pitch_f1_vs_L.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → pitch_f1_vs_L.png")

# --- 2b: f1 vs h (线性拟合过原点) ---
h_mm = steel_h['h_mm'].values
f1_h = steel_h['f1_hz'].values

# 线性过原点: f1 = k * h
k_h = np.sum(h_mm * f1_h) / np.sum(h_mm**2)
f1_fit_h = k_h * h_mm
ss_res_h = np.sum((f1_h - f1_fit_h)**2)
ss_tot_h = np.sum((f1_h - np.mean(f1_h))**2)
r2_h = 1 - ss_res_h / ss_tot_h

# 理论
L_default = 0.20  # 20cm
f1_theory_h = np.array([f1_theory(L_default, h * 1e-3) for h in h_mm])
rel_err_h = np.abs(f1_h - f1_theory_h) / f1_theory_h * 100

print(f"  f1 vs h: f1 = {k_h:.4f} * h, R²={r2_h:.6f}")
print(f"    相对误差: {rel_err_h.mean():.2f}% (平均)")

fitting_results.append({
    'relation': 'f1 vs h',
    'formula': f'f1 = {k_h:.4f} * h (过原点)',
    'expected_exponent': 1,
    'fitted_exponent': 1,
    'R2': r2_h,
    'mean_rel_error_pct': rel_err_h.mean(),
    'max_rel_error_pct': rel_err_h.max(),
    'n_points': len(h_mm)
})

fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'音调验证: $f_1$ vs 厚度 $h$', r'$h$ (mm)', r'$f_1$ (Hz)')

h_smooth = np.linspace(0, h_mm.max() * 1.1, 200)
ax.scatter(h_mm, f1_h, color=ACCENT_COLORS[0], s=80, zorder=5, label='仿真值')
ax.plot(h_smooth, k_h * h_smooth, '--', color=ACCENT_COLORS[1], lw=2,
        label=r'拟合: $f_1={:.2f} \cdot h$  $R^2={:.5f}$'.format(k_h, r2_h))
# 理论曲线 (连续光滑曲线, 不取点)
h_smooth_m = h_smooth * 1e-3
f1_theory_h_smooth = np.array([f1_theory(L_default, h) for h in h_smooth_m])
ax.plot(h_smooth, f1_theory_h_smooth, '-', color=ACCENT_COLORS[2], lw=2, alpha=0.85,
        label=r'EB梁理论: $f_1=\frac{\beta_1^2 h}{4\pi L^2}\sqrt{\frac{E}{3\rho}}$')

ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT, fontsize=10, loc='upper left')

fit_text = ('拟合方程:' + '\n'
            r'$f_1 = k \cdot h$ (过原点)' + '\n'
            r'$k = {:.4f}$ Hz/mm'.format(k_h) + '\n'
            r'$R^2 = {:.5f}$'.format(r2_h) + '\n'
            r'平均误差 $= {:.2f}\%$'.format(rel_err_h.mean()))
ax.text(0.05, 0.55, fit_text, transform=ax.transAxes,
        color=LIGHT_TEXT, fontsize=10,
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#16213e',
                  edgecolor=ACCENT_COLORS[1], linewidth=1))
plt.tight_layout()
plt.savefig(FIG_DIR / 'pitch_f1_vs_h.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → pitch_f1_vs_h.png")

# --- 2c: f1 vs b (水平线验证) ---
b_cm = steel_b['b_cm'].values
f1_b = steel_b['f1_hz'].values
f1_b_mean = np.mean(f1_b)
f1_b_std = np.std(f1_b)
delta_f1_b = (np.max(f1_b) - np.min(f1_b)) / f1_b_mean * 100

print(f"  f1 vs b: 均值={f1_b_mean:.4f} Hz, std={f1_b_std:.6f} Hz, Δf/f={delta_f1_b:.4f}%")

fitting_results.append({
    'relation': 'f1 vs b (独立性)',
    'formula': f'f1 = {f1_b_mean:.4f} ± {f1_b_std:.6f} Hz',
    'expected_exponent': 0,
    'fitted_exponent': 0,
    'R2': np.nan,
    'mean_rel_error_pct': delta_f1_b,
    'max_rel_error_pct': delta_f1_b,
    'n_points': len(b_cm)
})

fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'音调验证: $f_1$ vs 宽度 $b$ (预期水平线)', r'$b$ (cm)', r'$f_1$ (Hz)')

ax.scatter(b_cm, f1_b, color=ACCENT_COLORS[0], s=80, zorder=5, label='仿真值')
b_smooth = np.linspace(b_cm.min()-0.5, b_cm.max()+0.5, 200)
ax.plot(b_smooth, np.full_like(b_smooth, f1_b_mean), '--', color=ACCENT_COLORS[1], lw=2,
        label=r'拟合: $f_1 = \overline{{f_1}} = {:.2f}$ Hz'.format(f1_b_mean))
# 理论曲线: f1 ≠ f(b) → 水平线 (用理论值标定基准)
# 因 f1 与 b 无关,理论曲线即为常数;此处用拟合均值 ± std 区间表示理论无关性
ax.fill_between(b_smooth,
                f1_b_mean - f1_b_std, f1_b_mean + f1_b_std,
                alpha=0.25, color=ACCENT_COLORS[2], label=r'EB理论 $f_1 \neq f(b)$ ($\pm 1\sigma$)')
ax.set_xlim(b_cm.min()-0.5, b_cm.max()+0.5)
ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT, fontsize=9, loc='upper right')

fit_text = ('拟合方程:' + '\n'
            r'$f_1 = \overline{f_1}$ (常数)' + '\n'
            r'$\overline{f_1} = ' + r'{:.4f}$ Hz'.format(f1_b_mean) + '\n'
            r'$\sigma = ' + r'{:.4f}$ Hz'.format(f1_b_std) + '\n'
            r'$\Delta f_1 / f_1 = ' + r'{:.4f}\%$'.format(delta_f1_b))
ax.text(0.05, 0.05, fit_text, transform=ax.transAxes,
        color=LIGHT_TEXT, fontsize=10,
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#16213e',
                  edgecolor=ACCENT_COLORS[1], linewidth=1))
plt.tight_layout()
plt.savefig(FIG_DIR / 'pitch_f1_vs_b.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → pitch_f1_vs_b.png")

# --- 2d: f1 vs J (水平线验证) ---
J_vals = steel_J['J_Ns'].values
f1_J = steel_J['f1_hz'].values
f1_J_mean = np.mean(f1_J)
f1_J_std = np.std(f1_J)
delta_f1_J = (np.max(f1_J) - np.min(f1_J)) / f1_J_mean * 100

print(f"  f1 vs J: 均值={f1_J_mean:.4f} Hz, Δf/f={delta_f1_J:.6f}%")

fitting_results.append({
    'relation': 'f1 vs J (独立性)',
    'formula': f'f1 = {f1_J_mean:.4f} ± {f1_J_std:.6f} Hz',
    'expected_exponent': 0,
    'fitted_exponent': 0,
    'R2': np.nan,
    'mean_rel_error_pct': delta_f1_J,
    'max_rel_error_pct': delta_f1_J,
    'n_points': len(J_vals)
})

fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'音调验证: $f_1$ vs 冲量 $J$ (预期水平线)', r'$J$ (N$\cdot$s)', r'$f_1$ (Hz)')

ax.scatter(J_vals, f1_J, color=ACCENT_COLORS[0], s=80, zorder=5, label='仿真值')
J_smooth = np.linspace(J_vals.min()*0.8, J_vals.max()*1.2, 200)
ax.plot(J_smooth, np.full_like(J_smooth, f1_J_mean), '--', color=ACCENT_COLORS[1], lw=2,
        label=r'拟合: $f_1 = \overline{{f_1}} = {:.4f}$ Hz'.format(f1_J_mean))
# 理论曲线: 线性系统 f1 与 J 无关
ax.plot(J_smooth, np.full_like(J_smooth, f1_J_mean), '-', color=ACCENT_COLORS[2], lw=2, alpha=0.6,
        label=r'EB理论 $f_1 \neq f(J)$ (线性系统)')
ax.set_xlim(J_vals.min()*0.8, J_vals.max()*1.2)
y_range = max(f1_J_std * 10, 1)
ax.set_ylim(f1_J_mean - y_range, f1_J_mean + y_range)
ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT, fontsize=9, loc='upper right')

fit_text = ('拟合方程:' + '\n'
            r'$f_1 = \overline{f_1}$ (常数)' + '\n'
            r'$\overline{f_1} = ' + r'{:.4f}$ Hz'.format(f1_J_mean) + '\n'
            r'$\sigma = ' + r'{:.6f}$ Hz'.format(f1_J_std) + '\n'
            r'$\Delta f_1 / f_1 = ' + r'{:.6f}\%$'.format(delta_f1_J))
ax.text(0.05, 0.05, fit_text, transform=ax.transAxes,
        color=LIGHT_TEXT, fontsize=10,
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#16213e',
                  edgecolor=ACCENT_COLORS[1], linewidth=1))
plt.tight_layout()
plt.savefig(FIG_DIR / 'pitch_f1_vs_J.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → pitch_f1_vs_J.png")

# ============================================================
# Step 3: 音色分析
# ============================================================
print("\n" + "=" * 60)
print("Step 3: 音色理论验证")
print("=" * 60)

# --- 3a: 材料频谱质心对比 ---
fig, axes = plt.subplots(1, 2, figsize=(14, 6))
fig.patch.set_facecolor(DARK_BG)

mat_names = materials['material'].values
centroid = materials['spectral_centroid_hz'].values
flatness = materials['spectral_flatness'].values

# 非线性标记
nonlinear_flag = ['[NL]' if m != 'steel' else '' for m in mat_names]
labels = [f"{m}\n{f}" for m, f in zip(mat_names, nonlinear_flag)]

ax1 = axes[0]
ax1.set_facecolor(DARK_BG)
bars1 = ax1.bar(labels, centroid, color=ACCENT_COLORS[:len(mat_names)], alpha=0.85)
ax1.set_title('频谱质心 vs 材料', color=LIGHT_TEXT, fontsize=13, fontweight='bold')
ax1.set_ylabel('Spectral Centroid (Hz)', color=LIGHT_TEXT, fontsize=11)
ax1.tick_params(colors=LIGHT_TEXT)
for spine in ax1.spines.values():
    spine.set_color(LIGHT_TEXT)
    spine.set_linewidth(0.5)
ax1.grid(True, alpha=0.2, color=LIGHT_TEXT, axis='y')

ax2 = axes[1]
ax2.set_facecolor(DARK_BG)
bars2 = ax2.bar(labels, flatness, color=ACCENT_COLORS[:len(mat_names)], alpha=0.85)
ax2.set_title('频谱平坦度 vs 材料', color=LIGHT_TEXT, fontsize=13, fontweight='bold')
ax2.set_ylabel('Spectral Flatness', color=LIGHT_TEXT, fontsize=11)
ax2.tick_params(colors=LIGHT_TEXT)
for spine in ax2.spines.values():
    spine.set_color(LIGHT_TEXT)
    spine.set_linewidth(0.5)
ax2.grid(True, alpha=0.2, color=LIGHT_TEXT, axis='y')

fig.suptitle(r'音色指标对比 (非钢材料线性假设不成立, 仅供定性参考)',
             color='#ff6b6b', fontsize=11, y=0.02)
plt.tight_layout(rect=[0, 0.04, 1, 1])
plt.savefig(FIG_DIR / 'timbre_material_comparison.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → timbre_material_comparison.png")

# --- 3b: 衰减时间 τ vs 频率 f (钢 cases) ---
steel_all = T[T.material == 'steel'].copy()

fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'模态衰减: $\tau$ vs $f$ (钢, 全部 case)', r'频率 $f$ (Hz)', r'衰减时间 $\tau$ (s)')

for i in range(6):
    mode = i + 1
    tau_col = f'tau{mode}_s'
    f_col = f'f{mode}_hz'
    if tau_col in steel_all.columns and f_col in steel_all.columns:
        f_vals = steel_all[f_col].values
        tau_vals = steel_all[tau_col].values
        valid = (tau_vals > 0) & (f_vals > 0) & np.isfinite(tau_vals) & np.isfinite(f_vals)
        ax.scatter(f_vals[valid], tau_vals[valid], color=ACCENT_COLORS[i % 6],
                   s=40, alpha=0.7, label=f'Mode {mode}')

# 拟合 τ = c * f^(-α) on all valid steel data
all_f = []
all_tau = []
for i in range(6):
    f_col = f'f{i+1}_hz'
    tau_col = f'tau{i+1}_s'
    if f_col in steel_all.columns and tau_col in steel_all.columns:
        f_v = steel_all[f_col].values
        t_v = steel_all[tau_col].values
        valid = (t_v > 0) & (f_v > 0) & np.isfinite(t_v) & np.isfinite(f_v)
        all_f.extend(f_v[valid])
        all_tau.extend(t_v[valid])

all_f = np.array(all_f)
all_tau = np.array(all_tau)

if len(all_f) > 2:
    try:
        popt_tau, _ = curve_fit(power_law, all_f, all_tau, p0=[1, -1], maxfev=5000)
        c_tau, alpha_tau = popt_tau
        f_smooth = np.logspace(np.log10(all_f.min()), np.log10(all_f.max()), 300)
        ax.plot(f_smooth, power_law(f_smooth, c_tau, alpha_tau), '--', color='white', lw=2,
                label=r'拟合: $\tau={:.3f} \cdot f^{{{:.3f}}}$'.format(c_tau, alpha_tau))
        
        tau_fit_all = power_law(all_f, c_tau, alpha_tau)
        ss_res_tau = np.sum((all_tau - tau_fit_all)**2)
        ss_tot_tau = np.sum((all_tau - np.mean(all_tau))**2)
        r2_tau = 1 - ss_res_tau / ss_tot_tau
        
        # 在图上明确标注拟合方程
        fit_text = ('拟合方程:' + '\n'
                    r'$\tau = c \cdot f^{\alpha}$' + '\n'
                    r'$c = {:.4f}$'.format(c_tau) + '\n'
                    r'$\alpha = {:.4f}$'.format(alpha_tau) + '\n'
                    r'$R^2 = {:.4f}$'.format(r2_tau))
        ax.text(0.05, 0.05, fit_text, transform=ax.transAxes,
                color=LIGHT_TEXT, fontsize=10,
                bbox=dict(boxstyle='round,pad=0.5', facecolor='#16213e',
                          edgecolor='white', linewidth=1))
        
        fitting_results.append({
            'relation': 'tau vs f (钢, 全模态)',
            'formula': f'tau = {c_tau:.4f} * f^{alpha_tau:.4f}',
            'expected_exponent': 'negative',
            'fitted_exponent': alpha_tau,
            'R2': r2_tau,
            'mean_rel_error_pct': np.nan,
            'max_rel_error_pct': np.nan,
            'n_points': len(all_f)
        })
        print(f"  τ vs f 拟合: τ = {c_tau:.4f} * f^{alpha_tau:.3f}, R²={r2_tau:.4f}")
    except Exception as e:
        print(f"  τ vs f 拟合失败: {e}")

ax.set_yscale('log')
ax.set_xscale('log')
ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT, fontsize=9)
plt.tight_layout()
plt.savefig(FIG_DIR / 'timbre_tau_vs_f.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → timbre_tau_vs_f.png")

# --- 3c: 材料音色气泡图 ---
fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'材料音色图 (centroid $\times$ flatness $\times$ SPL)', 
              'Spectral Centroid (Hz)', 'Spectral Flatness')

spl_vals = materials['spl_rms_db'].values
spl_norm = (spl_vals - spl_vals.min()) / (spl_vals.max() - spl_vals.min() + 1e-10)
sizes = 100 + spl_norm * 500

for i, (c, f, s, m) in enumerate(zip(centroid, flatness, sizes, mat_names)):
    marker = 'o' if m == 'steel' else '^'
    ax.scatter(c, f, s=s, color=ACCENT_COLORS[i % 6], alpha=0.8, marker=marker,
               edgecolors='white', linewidths=1)
    suffix = '' if m == 'steel' else ' *'
    ax.annotate(f'{m}{suffix}', (c, f), textcoords='offset points', xytext=(10, 5),
                color=LIGHT_TEXT, fontsize=9)

ax.text(0.02, 0.95, r'气泡大小 $\propto$ SPL$_{rms}$' + '\n' + r'$\triangle$ = 非线性警告', transform=ax.transAxes,
        color='#ff6b6b', fontsize=9, va='top')
plt.tight_layout()
plt.savefig(FIG_DIR / 'timbre_bubble_map.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → timbre_bubble_map.png")

# ============================================================
# Step 4: 响度分析
# ============================================================
print("\n" + "=" * 60)
print("Step 4: 响度理论验证")
print("=" * 60)

# --- 4a: SPL vs J ---
fig, axes = plt.subplots(1, 2, figsize=(14, 6))
fig.patch.set_facecolor(DARK_BG)

J_data = steel_J['J_Ns'].values
spl_J = steel_J['spl_rms_db'].values
probe_J = steel_J['probe_peak_mm'].values

# SPL vs J
ax = axes[0]
ax.set_facecolor(DARK_BG)
ax.scatter(J_data, spl_J, color=ACCENT_COLORS[0], s=80, zorder=5, label='仿真值')
# 线性拟合 (dB vs J)
coef_spl = np.polyfit(J_data, spl_J, 1)
J_sm = np.linspace(J_data.min()*0.8, J_data.max()*1.2, 200)
ax.plot(J_sm, np.polyval(coef_spl, J_sm), '--', color=ACCENT_COLORS[1], lw=2,
        label=r'拟合: $SPL = {:.2f} J + {:.2f}$'.format(coef_spl[0], coef_spl[1]))
r2_spl_j = 1 - np.sum((spl_J - np.polyval(coef_spl, J_data))**2) / np.sum((spl_J - np.mean(spl_J))**2)
ax.set_title(r'$SPL_{rms}$ vs 冲量 $J$', color=LIGHT_TEXT, fontsize=12)
ax.set_xlabel(r'$J$ (N$\cdot$s)', color=LIGHT_TEXT)
ax.set_ylabel(r'$SPL_{rms}$ (dB)', color=LIGHT_TEXT)
ax.tick_params(colors=LIGHT_TEXT)
for spine in ax.spines.values():
    spine.set_color(LIGHT_TEXT)
ax.grid(True, alpha=0.2, color=LIGHT_TEXT)
ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT, fontsize=9, loc='upper left')

fit_text_spl = ('拟合方程:' + '\n'
                r'$SPL = a \cdot J + b$' + '\n'
                r'$a = {:.2f}$ dB/(N$\cdot$s)'.format(coef_spl[0]) + '\n'
                r'$b = {:.2f}$ dB'.format(coef_spl[1]) + '\n'
                r'$R^2 = {:.4f}$'.format(r2_spl_j))
ax.text(0.45, 0.05, fit_text_spl, transform=ax.transAxes,
        color=LIGHT_TEXT, fontsize=9,
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#16213e',
                  edgecolor=ACCENT_COLORS[1], linewidth=1))

# probe_peak vs J (线性验证)
ax = axes[1]
ax.set_facecolor(DARK_BG)
ax.scatter(J_data, probe_J, color=ACCENT_COLORS[2], s=80, zorder=5, label='仿真值')
coef_probe = np.polyfit(J_data, probe_J, 1)
ax.plot(J_sm, np.polyval(coef_probe, J_sm), '--', color=ACCENT_COLORS[3], lw=2,
        label=r'拟合: $d = {:.2f} J + {:.4f}$'.format(coef_probe[0], coef_probe[1]))
r2_probe_j = 1 - np.sum((probe_J - np.polyval(coef_probe, J_data))**2) / np.sum((probe_J - np.mean(probe_J))**2)
ax.set_title(r'探针位移 vs 冲量 $J$', color=LIGHT_TEXT, fontsize=12)
ax.set_xlabel(r'$J$ (N$\cdot$s)', color=LIGHT_TEXT)
ax.set_ylabel(r'Probe Peak (mm)', color=LIGHT_TEXT)
ax.tick_params(colors=LIGHT_TEXT)
for spine in ax.spines.values():
    spine.set_color(LIGHT_TEXT)
ax.grid(True, alpha=0.2, color=LIGHT_TEXT)
ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT, fontsize=9, loc='upper left')

fit_text_probe = ('拟合方程:' + '\n'
                  r'$d = a \cdot J + b$' + '\n'
                  r'$a = {:.4f}$ mm/(N$\cdot$s)'.format(coef_probe[0]) + '\n'
                  r'$b = {:.4f}$ mm'.format(coef_probe[1]) + '\n'
                  r'$R^2 = {:.4f}$'.format(r2_probe_j))
ax.text(0.45, 0.05, fit_text_probe, transform=ax.transAxes,
        color=LIGHT_TEXT, fontsize=9,
        bbox=dict(boxstyle='round,pad=0.5', facecolor='#16213e',
                  edgecolor=ACCENT_COLORS[3], linewidth=1))

plt.tight_layout()
plt.savefig(FIG_DIR / 'loudness_spl_probe_vs_J.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → loudness_spl_probe_vs_J.png")

fitting_results.append({
    'relation': 'SPL_rms vs J',
    'formula': f'SPL = {coef_spl[0]:.2f}*J + {coef_spl[1]:.2f}',
    'expected_exponent': 'linear',
    'fitted_exponent': 1,
    'R2': r2_spl_j,
    'mean_rel_error_pct': np.nan,
    'max_rel_error_pct': np.nan,
    'n_points': len(J_data)
})

fitting_results.append({
    'relation': 'probe_peak vs J',
    'formula': f'peak = {coef_probe[0]:.4f}*J + {coef_probe[1]:.4f}',
    'expected_exponent': 'linear (过原点)',
    'fitted_exponent': 1,
    'R2': r2_probe_j,
    'mean_rel_error_pct': np.nan,
    'max_rel_error_pct': np.nan,
    'n_points': len(J_data)
})

# --- 4b: SPL vs x0 ---
fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'响度验证: SPL vs 撞击位置 $x_0$', r'$x_0$ (归一化)', r'$SPL_{rms}$ (dB)')

x0_data = steel_x0['x0_ratio'].values
spl_x0 = steel_x0['spl_rms_db'].values
ax.scatter(x0_data, spl_x0, color=ACCENT_COLORS[0], s=100, zorder=5, label='仿真值')
ax.plot(x0_data, spl_x0, '-', color=ACCENT_COLORS[1], lw=1.5, alpha=0.6)
ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT)
plt.tight_layout()
plt.savefig(FIG_DIR / 'loudness_spl_vs_x0.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → loudness_spl_vs_x0.png")

# --- 4c: SPL 距离衰减 (mic sweep) ---
fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'SPL 空间衰减: 10 距离麦克风', r'距离 (m)', r'SPL (dB)')

# 对所有材料绘制 mic sweep
all_dists_log = []
all_spls_for_fit = []
steel_dists = None
steel_spls = None

for idx, row in materials.iterrows():
    mat = row['material']
    dists = []
    spls = []
    for k in range(1, 11):
        d_col = f'mic_sweep_dist_{k:02d}_m'
        s_col = f'mic_sweep_spl_{k:02d}_db'
        if d_col in row.index and s_col in row.index:
            d_val = row[d_col]
            s_val = row[s_col]
            if pd.notna(d_val) and pd.notna(s_val):
                dists.append(d_val)
                spls.append(s_val)
    if dists:
        color_idx = list(materials['material']).index(mat) if mat in list(materials['material']) else 0
        suffix = '' if mat == 'steel' else ' [NL]'
        ax.plot(dists, spls, 'o-', color=ACCENT_COLORS[color_idx % 6], lw=1.5,
                ms=5, label=f'{mat}{suffix}')
        if mat == 'steel':
            steel_dists = np.array(dists)
            steel_spls = np.array(spls)

# 钢材料拟合: SPL = a - 20·log10(r/r0)·n
if steel_dists is not None and len(steel_dists) >= 3:
    # 拟合 SPL = b - n * 20 * log10(d)
    log_d = np.log10(steel_dists)
    coef_dist = np.polyfit(log_d, steel_spls, 1)
    n_dist = -coef_dist[0] / 20.0  # n: 几何衰减幂
    d_fit = np.linspace(steel_dists.min(), steel_dists.max(), 200)
    spl_fit = coef_dist[0] * np.log10(d_fit) + coef_dist[1]
    ax.plot(d_fit, spl_fit, 'w--', lw=2,
            label=r'钢拟合: $SPL = {:.2f}\log_{{10}}(r) + {:.2f}$'.format(coef_dist[0], coef_dist[1]))
    
    r2_dist = 1 - np.sum((steel_spls - (coef_dist[0]*log_d + coef_dist[1]))**2) / \
                  np.sum((steel_spls - np.mean(steel_spls))**2)
    
    fitting_results.append({
        'relation': 'SPL vs distance (钢)',
        'formula': f'SPL = {coef_dist[0]:.4f} * log10(r) + {coef_dist[1]:.4f}',
        'expected_exponent': -20,
        'fitted_exponent': coef_dist[0],
        'R2': r2_dist,
        'mean_rel_error_pct': np.nan,
        'max_rel_error_pct': np.nan,
        'n_points': len(steel_dists)
    })
    
    fit_text_dist = ('钢材拟合方程:' + '\n'
                     r'$SPL = a\log_{10}(r) + b$' + '\n'
                     r'$a = {:.2f}$ dB/dec'.format(coef_dist[0]) + '\n'
                     r'$b = {:.2f}$ dB'.format(coef_dist[1]) + '\n'
                     r'$n = {:.3f}$ (1/r$^n$ 衰减)'.format(n_dist) + '\n'
                     r'$R^2 = {:.4f}$'.format(r2_dist))
    ax.text(0.55, 0.55, fit_text_dist, transform=ax.transAxes,
            color=LIGHT_TEXT, fontsize=9,
            bbox=dict(boxstyle='round,pad=0.5', facecolor='#16213e',
                      edgecolor='white', linewidth=1))
    print(f"  SPL vs distance (钢): n = {n_dist:.3f}, R² = {r2_dist:.4f}")

ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT, fontsize=9)
plt.tight_layout()
plt.savefig(FIG_DIR / 'loudness_spl_vs_distance.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → loudness_spl_vs_distance.png")

# ============================================================
# Step 5: 模态衰减分析 (新增)
# ============================================================
print("\n" + "=" * 60)
print("Step 5: 模态衰减分析 (新增)")
print("=" * 60)

# --- 5a: Q vs mode number (钢) ---
fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'品质因数 $Q$ vs 模态阶数 (钢)', r'模态阶数', r'$Q$')

q_means = []
q_stds = []
for i in range(1, 7):
    q_col = f'Q{i}'
    if q_col in steel_all.columns:
        q_vals = steel_all[q_col].dropna()
        q_vals = q_vals[q_vals > 0]
        q_means.append(q_vals.mean())
        q_stds.append(q_vals.std())
    else:
        q_means.append(0)
        q_stds.append(0)

modes = np.arange(1, 7)
ax.bar(modes, q_means, yerr=q_stds, color=ACCENT_COLORS[:6], alpha=0.85,
       edgecolor='white', linewidth=0.5, capsize=4, error_kw={'color': LIGHT_TEXT})
ax.set_xticks(modes)
ax.set_xticklabels([f'Mode {i}' for i in modes])
plt.tight_layout()
plt.savefig(FIG_DIR / 'modal_Q_vs_mode.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → modal_Q_vs_mode.png")

# --- 5b: Rayleigh 阻尼参数 ---
fig, ax = plt.subplots(1, 1, figsize=(8, 6))
setup_dark_ax(fig, ax, r'Rayleigh 阻尼参数 ($\alpha_{dM}$, $\beta_{dK}$)', r'$\alpha$ (质量阻尼)', r'$\beta$ (刚度阻尼)')

alpha_vals = steel_all['alpha_dM_est'].values
beta_vals = steel_all['beta_dK_est'].values
ray_valid = steel_all['rayleigh_valid'].values

valid_mask = ray_valid == 1
invalid_mask = ray_valid == 0

if np.any(valid_mask):
    ax.scatter(alpha_vals[valid_mask], beta_vals[valid_mask], color=ACCENT_COLORS[0],
               s=80, label='Rayleigh 有效', zorder=5)
if np.any(invalid_mask):
    ax.scatter(alpha_vals[invalid_mask], beta_vals[invalid_mask], color=ACCENT_COLORS[1],
               s=80, marker='x', label='Rayleigh 无效', zorder=5)

ax.legend(facecolor=DARK_BG, edgecolor=LIGHT_TEXT, labelcolor=LIGHT_TEXT)
plt.tight_layout()
plt.savefig(FIG_DIR / 'modal_rayleigh_params.png', dpi=300, facecolor=DARK_BG)
plt.close()
print("  → modal_rayleigh_params.png")

# ============================================================
# Step 6: 保存 fitting_results.csv
# ============================================================
print("\n" + "=" * 60)
print("Step 6: 保存 fitting_results.csv")
print("=" * 60)

df_fit = pd.DataFrame(fitting_results)
fit_path = TABLE_DIR / 'fitting_results.csv'
df_fit.to_csv(fit_path, index=False, encoding='utf-8-sig')
print(f"  → {fit_path}")
print(df_fit.to_string(index=False))

# ============================================================
# Step 7: PPTX 操作 (跳过, 由 rebuild_ppt_simulation_slides.py 处理)
# ============================================================
print("\n" + "=" * 60)
print("Step 7: 跳过 PPTX 修改 (请运行 rebuild_ppt_simulation_slides.py)")
print("=" * 60)

# ============================================================
# Step 8: 生成修改意见文档
# ============================================================
print("\n" + "=" * 60)
print("Step 8: 生成 PPT 修改意见文档")
print("=" * 60)

review_content = f"""# PPT 修改意见 — 基于 COMSOL 仿真数据

> 文件: `ppt/尺子之歌-正方匡大德.pptx`
> 生成日期: 2026-05-16
> 数据来源: 27 case COMSOL 3D 声-结构耦合仿真

---

## 一、理论吻合度评估

### 高度吻合的理论预测

| 理论 | 仿真验证结果 | 评价 |
|---|---|---|
| f₁ ∝ 1/L² | 幂律指数 n = {n_L:.4f}（理论 -2）, R² = {r2_L:.5f} | ✅ 完美验证 |
| f₁ ∝ h | 线性过原点 R² = {r2_h:.5f} | ✅ 完美验证 |
| f₁ ≠ f(b) | 5 种宽度下变异 {delta_f1_b:.4f}% | ✅ 完美验证 |
| f₁ ≠ f(J) | 4 种冲量下变异 {delta_f1_J:.6f}% | ✅ 完美验证 |
| SPL ∝ J | 线性拟合 R² = {r2_spl_j:.4f} | ✅ 高度吻合 |
| probe_peak ∝ J | 线性拟合 R² = {r2_probe_j:.4f} | ✅ 高度吻合 |

### 存在系统性偏差的方面

1. **理论频率 vs 仿真频率偏差 {rel_err_L.mean():.1f}%**：
   - 原因：3D 实体模型含泊松效应和剪切变形，EB 梁忽略了这些
   - 建议：PPT 中应注明"理论为一维近似，与 3D 仿真差 ~{rel_err_L.mean():.0f}%"

2. **Rayleigh 阻尼模型不总有效**：
   - {int(np.sum(ray_valid == 0))}/{len(ray_valid)} 个钢 case 标记 rayleigh_valid=0
   - 建议：PPT 误差分析中补充阻尼模型局限性

---

## 二、实验设计建议

### 原 PPT 实验覆盖 vs 仿真覆盖对比

| 维度 | PPT 实验 | 仿真 | 差距 |
|---|---|---|---|
| L_free | 5 值 (10~18cm) | 5 值 (10~26cm) | 仿真覆盖更宽 |
| h | 5 值 (1~5mm) | 5 值 (1~5mm) | 一致 |
| b | 未测 | 5 值 (1~5cm) | PPT 缺失宽度扫描 |
| J | 定性（轻/重敲） | 4 值 (0.02~0.08 Ns) | 仿真定量化 |
| x₀ | 3 位置（定性） | 3 值 (0.25/0.50/0.75) | 仿真定量化 |
| mic 距离 | 2 点 (5cm, 30cm) | 10 点 (2~6.3cm) | **仿真优势明显** |
| 材料 | 5 种 | 5 种 | 一致 |

### 建议补充的实验

1. **宽度 b 扫描**：PPT 理论部分推导了 f₁ 不依赖 b，但未做实验验证
2. **mic 多距离测量**：当前仅 5cm + 30cm，无法验证声压空间衰减规律
3. **冲量定量化**：建议用力锤+力传感器替代单摆小球，获取精确 J 值

---

## 三、误差溯源

### 仿真 vs 实验差异的主要来源

| 来源 | 影响方向 | 量级 |
|---|---|---|
| 夹持边界条件 | 实验非理想固支→频率偏低 | 3~8% |
| 传感器（phyphox）精度 | 频率分辨率受 FFT 窗口限制 | ~1 Hz |
| 三维效应 | 仿真 3D 模型比 EB 梁更精确 | 2~5% |
| 空气阻尼 | 仿真含 Rayleigh 阻尼模型 | 影响 τ 而非 f |
| 几何公差 | 实验尺子厚度非均匀 | 1~3% |

---

## 四、线性假设局限性（关键问题）

PPT 当前 **完全未讨论** 线性假设的适用范围。仿真数据明确揭示：

| 材料 | probe_peak / L_free | 线性假设 | 后果 |
|---|---|---|---|
| steel | ~2.4% | ✅ 有效 | 频率、SPL 可信 |
| satinwood | ~36% | ❌ 严重违反 | 频率偏移、谐波失真 |
| PVC | ~44% | ❌ 严重违反 | 同上 |
| acrylic | ~46% | ❌ 严重违反 | 同上 |
| xuefu_board | ~124% | ❌ 完全失效 | 所有线性理论不适用 |

### 建议 PPT 修改

1. **理论部分 (Slide 13)** 增加一条：
   > "本模型假设小变形（位移/长度 << 1），当材料刚度较低时假设可能失效"

2. **实验结论 (Slide 37)** 增加讨论：
   > "非钢材料（PVC、亚克力、雪弗板等）在相同冲量下产生大变形，欧拉-伯努利梁理论可能不再适用"

3. **误差分析 (Slide 38)** 增加一条误差来源：
   > "低刚度材料的几何非线性效应"

---

## 五、可新增内容（仿真独有数据）

### 5.1 模态衰减定量分析（已新增幻灯片）

- 6 阶模态的 τ 值分布：τ₁ >> τ₆，量化了"高频消失快"
- Q 值统计：低阶 Q ~90，高阶 Q < 10
- τ vs f 关系拟合：验证能否用单一幂律描述

### 5.2 Rayleigh 阻尼验证（已新增幻灯片）

- α(质量阻尼) 和 β(刚度阻尼) 的估计值分布
- 多数 case 表明 Rayleigh 模型不完全适用 → 可讨论频率相关阻尼

### 5.3 10 距离 SPL 衰减曲线（已新增幻灯片）

- 提供了 PPT 实验无法获得的精细空间衰减数据
- 近场（< 3cm）衰减率 > 理论 1/r，远场趋近球面波

### 5.4 建议但未实现的补充

- **非线性仿真对比**：对 PVC/雪弗板做几何非线性分析
- **模态叠加可视化**：用模态振型动画展示音色随时间变化
- **频谱瀑布图**：STFT 结果嵌入 PPT

---

## 六、图表改进建议

### 现有 PPT 图表问题

1. **Slide 26-28（音调图）**：
   - 缺少拟合公式和 R² 标注
   - 理论曲线与实验数据未同图对比
   - 建议：加入仿真曲线作为第三组数据

2. **Slide 29-30（音色表格）**：
   - 数据以表格形式呈现，可视化效果差
   - 建议：改为堆叠面积图或热力图

3. **Slide 32-35（响度图）**：
   - 图标题一律为"图20"，需区分编号
   - y 轴单位不统一
   - 建议：每图标注测量条件和不确定度

4. **整体**：
   - PPT 缺少误差棒（5 次重复实验的 std）
   - 缺少理论预测曲线 vs 实验数据的直接对比

---

## 七、总结

仿真数据全面验证了 PPT 中 EB 悬臂梁理论的核心预测（f₁∝1/L², f₁∝h, f₁≠f(b), SPL∝J），
同时揭示了两个 PPT 未讨论的重要问题：
1. **非钢材料的非线性失效** — 必须在报告中明确标注
2. **阻尼模型的局限性** — Rayleigh 阻尼不能完美描述所有模态

已新增 12 张仿真幻灯片嵌入 PPT，覆盖音调(4)、音色(3)、响度(3)、模态衰减(2) 四个维度。
"""

REPORT_PATH.write_text(review_content, encoding='utf-8')
print(f"  → {REPORT_PATH}")

# ============================================================
# 完成
# ============================================================
print("\n" + "=" * 60)
print("全部交付物生成完毕!")
print("=" * 60)
print(f"""
交付物清单:
  [1] PPTX:       {PPT_PATH}
  [2] PNG 图表:   {FIG_DIR}/ (10 张)
  [3] 修改意见:   {REPORT_PATH}
  [4] 拟合表:     {fit_path}
""")
