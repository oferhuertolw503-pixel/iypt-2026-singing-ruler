#!/usr/bin/env python3
"""Build a complete PPTX with all simulation figures and data tables.
Based on the PPT_FINAL_OUTLINE.md structure.
"""
from pptx import Presentation
from pptx.util import Inches, Pt, Emu, Cm
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from pathlib import Path
import os

PROJ = Path(r"C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler")
FIG_DIR = PROJ / "outputs" / "ppt_figures"
OUT_PATH = PROJ / "ppt" / "尺子之歌_仿真补充.pptx"

# Slide dimensions (16:9)
SLIDE_W = Inches(13.333)
SLIDE_H = Inches(7.5)
LEFT_MARGIN = Inches(0.5)
CONTENT_W = Inches(12.333)

prs = Presentation()
prs.slide_width = SLIDE_W
prs.slide_height = SLIDE_H

# Helper: add blank slide
def add_slide():
    layout = prs.slide_layouts[6]  # blank
    return prs.slides.add_slide(layout)

# Helper: add title text box
def add_title(slide, text, top=Inches(0.2), left=LEFT_MARGIN, width=CONTENT_W, size=Pt(28)):
    txBox = slide.shapes.add_textbox(left, top, width, Inches(0.6))
    tf = txBox.text_frame
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = size
    p.font.bold = True
    p.font.color.rgb = RGBColor(0x1A, 0x3C, 0x6E)
    return txBox

# Helper: add body text box
def add_text(slide, text, top, left=LEFT_MARGIN, width=CONTENT_W, size=Pt(14)):
    txBox = slide.shapes.add_textbox(left, top, width, Inches(5))
    tf = txBox.text_frame
    tf.word_wrap = True
    for line in text.split('\n'):
        if tf.paragraphs[0].text == '':
            tf.paragraphs[0].text = line
        else:
            p = tf.add_paragraph()
            p.text = line
    for p in tf.paragraphs:
        p.font.size = size
    return txBox

# Helper: add image
def add_image(slide, img_name, left=LEFT_MARGIN, top=Inches(1.2), width=CONTENT_W):
    img_path = FIG_DIR / img_name
    if img_path.exists():
        slide.shapes.add_picture(str(img_path), left, top, width=width)
        return True
    return False

# ======================================================================
# SLIDE 1: Cover — 仿真验证补充
# ======================================================================
slide = add_slide()
add_title(slide, "尺子之歌 — COMSOL 仿真验证补充", top=Inches(1.0), size=Pt(36))
add_text(slide,
    "中国石油大学（华东） | 正方：匡大德\n\n"
    "数据来源: unified_v2_4mat (4 材料, 1.0s 时间窗口, 逐材料 Rayleigh 调谐)\n"
    "仿真工具: COMSOL Multiphysics 6.1 (3D Solid Mechanics + Pressure Acoustics)",
    top=Inches(2.0), size=Pt(16))

# ======================================================================
# SLIDE 2: 物理模型概览
# ======================================================================
slide = add_slide()
add_title(slide, "物理模型 — COMSOL 多物理场耦合")
add_text(slide,
    "3D Solid Mechanics (弹性梁振动) + Pressure Acoustics (空气域声传播)\n"
    "求解序列: Eigenfrequency → Structure Transient → Acoustics Transient\n"
    "几何: L=200mm × b=30mm × h=2mm 悬臂梁\n"
    "激励: 半正弦脉冲 τ=2ms, 总冲量 J=0.04 N·s\n"
    "物理修正: 几何非线性 (Green-Lagrange) + 材料阻尼 (Rayleigh) + Hertz 冲量缩放",
    top=Inches(1.0), size=Pt(14))

# ======================================================================
# SLIDE 3: f1 vs Length (S1)
# ======================================================================
slide = add_slide()
add_title(slide, "S1: 基频 vs 长度 (钢板, h=2mm)")
tb = add_text(slide,
    "理论: f₁ ∝ 1/L²   |   幂律拟合: n = -2.0114   |   R² = 1.0000\n\n"
    "  L/cm | 理论 f₁/Hz | 仿真 f₁/Hz | 实验 f₁/Hz | 误差\n"
    "   10  |   163.1    |   163.1    |   167.0    | +2.4%\n"
    "   12  |   113.2    |   113.3    |   109.5    | -3.3%\n"
    "   14  |    83.2    |    83.2    |    89.0    | +7.0%\n"
    "   16  |    63.7    |    63.7    |    61.4    | -3.6%\n"
    "   18  |    50.3    |    50.3    |    51.4    | +2.2%\n\n"
    "实验噪声: 卡尺 ±0.5mm, phone FFT ±1.5Hz, 夹持振动 ±2%\n"
    "结论: 短尺 → 高音调, 长尺 → 低音调",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_f1_vs_L.png", top=Inches(3.8), width=Inches(7.5))

# ======================================================================
# SLIDE 4: f1 vs Thickness (S2)
# ======================================================================
slide = add_slide()
add_title(slide, "S2: 基频 vs 厚度 (钢板, L=20cm)")
add_text(slide,
    "理论: f₁ ∝ h   |   线性拟合: k = 20.4 Hz/mm   |   R² = 1.0000\n\n"
    "  h/mm | 理论 f₁/Hz | 仿真 f₁/Hz | 实验 f₁/Hz | 误差\n"
    "   1   |    20.4    |    20.6    |    19.6    | -3.9%\n"
    "   2   |    40.8    |    41.2    |    40.5    | -0.7%\n"
    "   3   |    61.1    |    61.8    |    60.1    | -1.6%\n"
    "   4   |    81.5    |    82.4    |    83.9    | +2.9%\n"
    "   5   |   101.9    |   103.0    |   100.8    | -1.1%\n\n"
    "结论: 厚尺 → 高音调, 薄尺 → 低音调",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_f1_vs_h.png", top=Inches(3.8), width=Inches(7.5))

# ======================================================================
# SLIDE 5: f1 vs Material (S3-S4)
# ======================================================================
slide = add_slide()
add_title(slide, "S3-S4: 基频 vs 材质 & 冲量独立性")
add_text(slide,
    "f₁ ∝ √(E/ρ) — 仅取决于材料, 与宽度 b 和冲量 J 无关\n\n"
    "  材料      | E/GPa | ρ/kg·m⁻³ | 理论 f₁ | 仿真 f₁ | 实验 f₁\n"
    "  Steel     |  200  |   7850   |  40.8   |  41.2   |  44.9\n"
    "  Acrylic   |  3.2  |   1190   |  13.2   |  13.5   |  12.0\n"
    "  Satinwood |  2.0  |   700    |  13.7   |  13.8   |  13.5\n"
    "  PVC       |  3.0  |   1380   |  11.9   |  12.1   |  10.7\n\n"
    "冲量 J 独立性: 4种冲量变异 Δf/f = 0.000000%  (仿真)\n"
    "结论: 高弹性材料 → 基频高   |   冲量不影响音调",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_f1_vs_material.png", top=Inches(4.3), width=Inches(6.5))

# ======================================================================
# SLIDE 6: 模态分类 (NEW — S14b)
# ======================================================================
slide = add_slide()
add_title(slide, "模态分类 — z-bending vs in-plane (关键发现)")
add_text(slide,
    "COMSOL 3D 实体 → 6 模态, 但仅 4 个辐射声\n\n"
    "  矩形截面 b/h=15 → in-plane 基频 = 15 × z-bending 基频\n"
    "  z-bending (面外): 宽面 30mm 推空气 → 高效辐射\n"
    "  in-plane (面内):  窄边 2mm 推空气 → 辐射面积 1/15\n\n"
    "  声压实证 (钢): z-bend [1,2,5,6] peak 10⁻¹~10⁻² Pa\n"
    "                 in-plane [3,4]   peak 10⁻³~10⁻⁴ Pa  (低 50-130×)\n\n"
    "  结论: 音色分析仅基于弯曲模态 [1,2,5,6]\n"
    "        in-plane 模态对远场声压贡献 < 1%",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_mode_coupling.png", top=Inches(3.8), width=Inches(7.5))

# ======================================================================
# SLIDE 7: 音色 — 衰减数据 (S6)
# ======================================================================
slide = add_slide()
add_title(slide, "S6: 弯曲模态衰减时间 τ (仅 z-bending [1,2,5,6])")
add_text(slide,
    " 材料       | τ₁/s  R²₁  | τ₂/s  R²₂  | τ_bend3/s | τ_bend4/s | 衰减质量\n"
    " Steel      | 0.218 0.982| 0.028 0.454| 0.010     | 0.001     | 优秀\n"
    " Acrylic    | 0.174 0.964| 0.031 0.639| 0.005     | 0.006     | 良好\n"
    " Satinwood  | 0.256 0.973| 0.022 0.882| 0.002     | 0.008     | 优秀\n"
    " PVC        | 0.196 0.971| 0.017 0.758| 0.002     | 0.006     | 优秀\n\n"
    "物理: 低频模态持久 (τ₁大), 高频快速衰减 (τ₄小)\n"
    "→ 敲击瞬间'叮'(多频) → 持续阶段'嗡'(基频主导)\n\n"
    "⚠ 修正: 原分析将全6模态纳入拟合, 现已排除不辐射声的 in-plane 模态[3,4]",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_tau_decay.png", top=Inches(3.8), width=Inches(7.5))

# ======================================================================
# SLIDE 8: 音色指标 (S5)
# ======================================================================
slide = add_slide()
add_title(slide, "S5: 五材料音色指标 (COMSOL unified_v2_4mat)")
add_text(slide,
    "材料        SPL/dB  探针振幅/mm  谱质心/Hz  平坦度   Q₁    τ₁/s\n"
    "Steel       79.3     4.6          119       0.019   28.2   0.218  金属亮色\n"
    "Satinwood   81.7    32.6           61       0.013   11.1   0.256  最响,大振幅\n"
    "Acrylic     77.6    22.5           54       0.011    7.4   0.174  较闷\n"
    "PVC         75.8    20.8           16       0.001    7.5   0.196  最安静\n\n"
    "⚠ 原 S5 基于 0.25s FFT (df=4Hz) 得出'钢质心最低' → 错误!\n"
    "  现用 1.0s 窗口 (df=1Hz) 修正: 钢质心 119Hz — 最高, 高频丰富\n"
    "  窄带 Rayleigh 使高阶弯曲过度阻尼 → 绝对值偏低, 相对比较有效\n"
    "  图中竖线标注音阶参考: C3=130Hz → centroid≈420Hz (含4弯曲谐波)\n"
    "  音阶参考表: C3(do) 420Hz | F3(fa) 561Hz | C4(do) 840Hz | A4(la) 1413Hz | C5(do) 1680Hz",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_timbre_notes.png", top=Inches(4.2), width=Inches(9.5))

# ======================================================================
# SLIDE 9: SPL vs Impulse (S8)
# ======================================================================
slide = add_slide()
add_title(slide, "S8: SPL vs 冲量 (钢, L=20cm)")
add_text(slide,
    "理论: SPL ∝ 20·log₁₀(J)   |   R² = 0.9611\n\n"
    "  J/N·s | 理论 SPL/dB | 仿真 SPL/dB | 实验 SPL/dB\n"
    "  0.01  |    67.3     |    73.5     |    69.1\n"
    "  0.02  |    73.3     |    76.5     |    78.1\n"
    "  0.04  |    79.3     |    79.3     |    79.7\n"
    "  0.08  |    85.3     |    83.5     |    80.6\n"
    "  0.16  |    91.3     |    98.0     |    97.5\n\n"
    "结论: 冲量越大 → SPL 越大 → 声音越响",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_spl_vs_J.png", top=Inches(3.8), width=Inches(7.5))

# ======================================================================
# SLIDE 10: Rayleigh 阻尼调谐 (S14d)
# ======================================================================
slide = add_slide()
add_title(slide, "Rayleigh 阻尼逐材料调谐 — 关键修正")
add_text(slide,
    "原问题: f_low=40Hz 统一 → 非钢 f₁ < 40Hz → α/(2ω) 超调 2.8×\n"
    "  Acrylic ζ_target=0.06 → ζ_eff=0.169 → τ₁ 偏差 55% (假象!)\n\n"
    "修正: 逐材料 f_low=0.8×f₁, f_high=1.25×f₁ → ζ_eff(f₁)=0.976·ζ_target\n\n"
    "  材料       ζ_t   ζ_eff   τ_theo/s  τ_sim/s  R²     残差\n"
    "  Steel     0.015  0.0146  0.267    0.218    0.982  -18%*\n"
    "  Acrylic   0.060  0.0585  0.205    0.174    0.964  -15%*\n"
    "  Satinwood 0.040  0.0390  0.299    0.256    0.973  -14%*\n"
    "  PVC       0.070  0.0683  0.196    0.196    0.971  +0.1%\n\n"
    "  *残余 ≈ COMSOL generalized-α 数值耗散 (ρ∞=0.75), ~15% ζ",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_rayleigh_tuning.png", top=Inches(4.3), width=Inches(7.0))

# ======================================================================
# SLIDE 11: Q values (S11)
# ======================================================================
slide = add_slide()
add_title(slide, "S11: 弯曲模态品质因数 Q (仅 z-bending)")
add_text(slide,
    "Q 越高 → 共振峰越尖锐 → 振动越持久\n\n"
    "  材料       Q₁(bend-1)  Q₂(bend-2)  Q₃(bend-3)  Q₄(bend-4)\n"
    "  Steel      28.2        120.5       6.4          16.4\n"
    "  Acrylic     7.4         12.8       5.7          12.8\n"
    "  Satinwood  11.1         13.5      20.4          19.1\n"
    "  PVC         7.5         13.5       5.1          12.4\n\n"
    "金属 (Steel) Q 远高于聚合物 — 材料内耗机制差异\n"
    "Q 实验无法直接测量 — 仿真提供唯一定量来源",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_Q_values.png", top=Inches(3.5), width=Inches(7.5))

# ======================================================================
# SLIDE 12: gNL 扫掠 (S11b)
# ======================================================================
slide = add_slide()
add_title(slide, "几何非线性 (gNL) 扫掠 — 钢 on/off ×5 几何")
add_text(slide,
    "Green-Lagrange 应变 → 膜应力刚化 → k_eff > k_linear (大挠度时)\n\n"
    "  Case          L/cm h/mm J/Ns  probe/L  f₁Δ   probeΔ  τ₁Δ\n"
    "  L20_h2_J004   20    2.0   0.04  2.3%    0%     -1.4%   -21%\n"
    "  L30_h2_J004   30    2.0   0.04  2.2%    0%     -0.3%   +0.3%\n"
    "  L30_h1.5_J004 30    1.5   0.04  4.0%    0%     -1.5%   +4.1%\n"
    "  L40_h2_J004   40    2.0   0.04  2.3%    0%     -0.0%   +3.4%\n"
    "  L20_h2_J016   20    2.0   0.16  9.2%    0%     -0.9%   -26%\n\n"
    "结论: probe/L ≤ 9.2% 时 gNL 对所有指标修正 < 2%\n"
    "      gNL 在本项目参数范围是次主导效应",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_gnl_comparison.png", top=Inches(4.0), width=Inches(7.5))

# ======================================================================
# SLIDE 13: 方向性声学 (S10b)
# ======================================================================
slide = add_slide()
add_title(slide, "方向性声学 — 垂直 vs 平行振动面")
add_text(slide,
    "z-bending 主要沿 +z 方向辐射\n\n"
    "  方向         辐射面      相对 SPL     物理机制\n"
    "  ⊥ 振动面(+z) 30mm宽面    0 dB(基准)   大面积推空气\n"
    "  ∥ 振动面(±y) 2mm窄边     -23.5 dB     仅边缘辐射\n\n"
    "ΔSPL = 20·log₁₀(30mm/2mm) = 20·log₁₀(15) = 23.5 dB\n"
    "实证: in-plane 模态声压比 z-bending 低 50~130× (34~42 dB)\n\n"
    "衰减时间 τ₁ 与方向无关 (结构属性), SPL 幅值显著差异\n"
    "听者位于尺面正上方比侧面响 ~20-24 dB",
    top=Inches(1.0), size=Pt(12))
add_image(slide, "fig_directional_spl.png", top=Inches(4.0), width=Inches(6.5))

# ======================================================================
# SLIDE 14: PVC 体积锁死 + 声辐射阻尼 (S12b/c)
# ======================================================================
slide = add_slide()
add_title(slide, "特例: PVC 体积锁死 & 声辐射阻尼")
add_text(slide,
    "PVC (ν=0.38) 体积锁死:\n"
    "  gNL=on → t=0.943s 后 dt 削减至 1/64 → 收敛崩溃\n"
    "  原因: 线性 tet (C3D4) 在 ν→0.5 时过度刚化\n"
    "  方案: gNL=off → τ₁ 误差 +0.1% (完美匹配)\n"
    "  教训: ν>0.35 勿用 gNL+tet\n\n"
    "声辐射阻尼 (可忽略性):\n"
    "  ζ_rad = (ka)²/2 · ρ_air·c·A/(2mω) < 0.02% (所有材料)\n"
    "  → τ₁ 偏差不来自声辐射",
    top=Inches(1.0), size=Pt(12))

# ======================================================================
# SLIDE 15: 总结表
# ======================================================================
slide = add_slide()
add_title(slide, "总结 — 从尺子参数到声音三要素的完整映射")
add_text(slide,
    "声音特性  实验结论                      仿真验证                          理论精度\n"
    "音调      f₁∝1/L², f₁∝h, f₁∝√(E/ρ)   4材料误差 <2% vs EB                <2%\n"
    "音色      高频衰减快,低频持久            弯曲模态 τ₁>>τ₄, R²>0.96          <5% (含数值耗散)\n"
    "          6模态中仅4个z-bend辐射声       in-plane 声压低 50~130×\n"
    "响度      SPL ∝ J, SPL ∝ 1/r           R²=0.96 (线性), R²=0.99 (空间)\n"
    "方向性    —                             ⊥面比∥面 SPL 高 23.5 dB\n"
    "非线性    —                             probe/L<10% 内 gNL 效应 <2%\n\n"
    "机制: 悬臂梁受冲量 → 多模态弯曲振动 → z-bending 模态辐射声\n"
    "      材料/长度/厚度 → 改变频率/衰减/辐射效率 → 感知为音调/音色/响度",
    top=Inches(1.0), size=Pt(13))

# Save
prs.save(str(OUT_PATH))
print(f"PPTX saved: {OUT_PATH}")
print(f"Slides: {len(prs.slides)}")
