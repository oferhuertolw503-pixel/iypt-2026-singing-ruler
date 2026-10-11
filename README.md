# The Singing Ruler — 唱歌的尺子

> **IYPT 2026 Problem**: A ruler clamped to a table produces a sound when struck. Investigate how the sound depends on relevant parameters.

---

## Navigation / 导航

- [English](#english) | [中文](#中文-section)

---

# English

A multiphysics COMSOL simulation of a 3D ruler struck by a pulsed force, vibrating in air and generating sound pressure waves. The core research objective: **timbre** (material spectral signature), **pitch** (geometric parameter frequency sweep), and **loudness** (SPL metrics).

Simulation runs on a **Linux server** (COMSOL 6.1 batch mode). **MATLAB post-processing** runs locally with offline CSV files.

## Quick Start

```bash
# 1. (Server) Deploy and run the unified simulation package
#    SSH to your Linux server and execute:
cd ~/comsol_work/the_singing_ruler/the_singing_ruler_unified/
./run_sweep.sh

# 2. (Local) Post-process results — MATLAB reads CSV outputs
cd matlab/
# Batch process all sweep results:
matlab -batch "run('report/batch_derived_metrics.m')"
# Generate paper figures (9 figures, 300 DPI):
matlab -batch "run('plot/plot_paper_figures_final.m')"
```

**Workflow**: COMSOL on Linux server (Java API model → batch solve → CSV export) → SCP CSV files to local → MATLAB reads CSV (offline, no LiveLink needed) → metrics & figures.

**No LiveLink required.** MATLAB reads pre-exported CSV files. Falls back to LiveLink only when CSV is missing (requires explicit authorization).

## Physics Overview


1. **Mechanical vibration**: The ruler (a 3D cantilever beam) is struck by a pulsed force. It vibrates in its eigenmodes — bending, torsional, and axial.
2. **Sound radiation**: The vibrating surface displaces adjacent air molecules, creating pressure waves that propagate outward as sound.
3. **Multiphysics coupling**: Structural mechanics (solid) → Acoustics (fluid), one-way coupled: the structural vibration is the boundary condition for the acoustic pressure field.

### Three-Layer Theory Model

| Layer | Theory | Scope |
|-------|--------|-------|
| **L1** | **Euler-Bernoulli beam** | Linear bending vibration; predicts `f ∝ h/L²` (thin rulers, small amplitude) |
| **L2** | **Timoshenko beam + elastic clamping** | Shear deformation + rotary inertia + finite clamping stiffness `K_θ`; corrects L1 for thick/short rulers |
| **L3** | **Duffing + Rayleigh damping + acoustic radiation** | Geometric nonlinearity (stiffening at large amplitude), material damping, sound pressure directivity |

### Materials (5 types)

| Material | Type | Notes |
|----------|------|-------|
| Steel | Metal | High Q-factor, bright timbre, linear behavior |
| PVC | Plastic | Low Q-factor, muted timbre, may need geometric nonlinearity |
| Acrylic | Plastic | Medium Q-factor, clear timbre |
| Satiné | Wood | Anisotropic, medium Q-factor (E estimated from literature) |
| Foam PVC (Sintra) | Foam board | Very low Q, highly damped (E estimated from literature) |

### Parameter Scans

- **Length** `L`: 200–600 mm
- **Thickness** `h`: 1–6 mm
- **Width** `b`: 10–50 mm
- **Clamping length** `L_clamp`: 10–50 mm
- **Strike position**: tip, midpoint, 1/3 point
- **Strike force amplitude**: 0.1–10 N

## Key Findings

| Finding | Detail |
|---------|--------|
| **`f ∝ h/L²`** | Holds for thin rulers (deviation < 3%). Timoshenko correction needed for thick/short rulers. |
| **Clamping stiffness effects** | Clamping stiffness `K_θ ≈ 10⁴–10⁵ N·m/rad` shifts fundamental frequency by 5–15%. |
| **Strike position controls modal participation** | Tip → fundamental dominant; midpoint → even modes suppressed; 1/3 point → richer spectrum. |
| **Material timbre differences** | Steel: high Q, sustained bright tone. PVC/foam: low Q, dull thud. Wood: mid-range. |
| **SPL directivity** | Front face radiates 15–25 dB louder than side face. Dipole-like pattern at fundamental. |

## Project Progress

| Item | Status |
|------|--------|
| **L1 (Euler-Bernoulli) theory validation** | ✅ Verified |
| **L2 (Timoshenko + elastic clamp) theory** | ✅ Verified |
| **L3 (Duffing + Rayleigh + acoustic) theory** | ❌ Large-amplitude nonlinear validation pending |
| **COMSOL full parameter sweep (5 materials, multiple L/h)** | ✅ Completed on Linux server |
| **Frequency scaling `f ∝ h/L²`** | ✅ Verified (deviation < 3% for thin rulers) |
| **Clamping stiffness `K_θ` analysis** | ✅ Verified (5–15% shift) |
| **Strike position modal control** | ✅ Verified |
| **SPL directivity (front vs. side)** | ✅ Verified (15–25 dB difference) |
| **Material timbre characterization** | ✅ Verified (steel high Q / PVC low Q / wood medium) |
| **Geometric nonlinearity (Green-Lagrange)** | ⚠️ Implemented for non-steel materials; validation in progress |
| **Satiné & Sintra elastic moduli** | ❌ Literature estimates, not experimentally measured |
| **Hyperelastic material model** | ❌ Planned (future work) |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **FEM solver** | COMSOL Multiphysics 6.1 (Linux server, batch mode) |
| **Model construction** | Java (COMSOL Java API) + Python orchestration |
| **Post-processing** | MATLAB R2025a (offline CSV-first) |
| **Configuration** | JSON |

## Server Packages (Active Simulation Code)

All simulation code resides on the Linux server at `~/comsol_work/the_singing_ruler/`:

| Package | Directory | Description |
|---------|-----------|-------------|
| **full_server_source** | `the_singing_ruler_full_server_source/` | Main package: linear, nonlinear, damping + impulse |
| **unified** | `the_singing_ruler_unified/` | Unified package: geometric nonlinearity + damping + impulse + long time window |
| **hyperelastic** | `the_singing_ruler_hyperelastic/` | Hyperelastic material model (planned / in development) |

## Project Structure

```
the_singing_ruler/
├── matlab/                        # Post-processing pipeline
│   ├── core/                      # Pipeline + derived metrics
│   │   ├── run_beam_model_pipeline.m
│   │   └── run_derived_metrics.m
│   ├── extract/                   # FFT, SPL, modal decay, timbre features
│   ├── plot/                      # Paper-quality figures (9 figures, 300 DPI)
│   │   └── plot_paper_figures_final.m
│   └── report/                    # Batch processing + conclusion table
│       ├── batch_derived_metrics.m
│       └── aggregate_conclusion_table.m
├── the_singing_ruler_unified/     # Unified simulation package (symlink / server ref)
├── scripts/                       # Deployment scripts
└── ppt/                           # Presentation materials
```

## Coding Conventions

- **MATLAB**: `snake_case`
- **Java (COMSOL API)**: `PascalCase`
- **Python**: `snake_case`
- **Quality tiers**: `full / medium / coarse / decay / fast / eco` (6 levels)
- **Data integrity**: Every data point must trace to a real COMSOL case. No synthetic data, interpolation, or curve fitting.
- **Git boundary**: `outputs/`, `runtime/`, `*.mph`, `*.pptx`, `*.pdf` excluded from Git.
- **COMSOL**: server only — never runs in CI.

## Knowledge Base

Detailed documentation (theoretical derivations, paper drafts, experimental plans, literature research) is maintained separately from this code repository.

> Knowledge base is not part of this repository.

## License

MIT License — see [LICENSE](LICENSE)

---

# 中文 Section

> **IYPT 2026 赛题**：夹持在桌面的尺子被敲击时发出声音。探究声音如何依赖相关参数。

## 项目简介

三维实体尺子受脉冲力敲击后，在空气中振动并产生声压波的 **COMSOL 多物理场仿真**。核心研究目标：**音色**（材料频谱特征）、**音调**（几何参数频率扫描）、**响度**（声压级 SPL 指标）。

- **仿真**：在 Linux 服务器运行（COMSOL 6.1 batch 模式）
- **后处理**：本地 MATLAB 处理离线 CSV 文件

## 快速开始

```bash
# 1.（服务器）部署并运行统一仿真包
#    SSH 登录 Linux 服务器后执行：
cd ~/comsol_work/the_singing_ruler/the_singing_ruler_unified/
./run_sweep.sh

# 2.（本地）MATLAB 后处理 — 读取 CSV 输出
cd matlab/
# 批量处理所有扫描结果：
matlab -batch "run('report/batch_derived_metrics.m')"
# 生成论文级图表（9 张图，300 DPI）：
matlab -batch "run('plot/plot_paper_figures_final.m')"
```

**工作流程**：COMSOL Linux 服务器（Java API 建模 → batch 求解 → CSV 导出）→ SCP CSV 文件到本地 → MATLAB 读取 CSV（离线模式，无需 LiveLink）→ 计算指标 & 生成图表。

**无需 LiveLink**。MATLAB 优先读取预先导出的 CSV 文件，仅当 CSV 缺失时回退到 LiveLink（需显式授权）。

## 物理模型


1. **机械振动**：尺子（三维悬臂梁）受脉冲力敲击，以其本征模态振动——弯曲、扭转、轴向。
2. **声辐射**：振动表面推动相邻空气分子，产生向外传播的声压波。
3. **多物理耦合**：结构力学（固体）→ 声学（流体），单向耦合：结构振动作为声压场的边界条件。

### 三层理论模型

| 层次 | 理论 | 适用范围 |
|------|------|---------|
| **L1** | **Euler-Bernoulli 梁** | 线性弯曲振动；预言 `f ∝ h/L²`（薄尺、小振幅） |
| **L2** | **Timoshenko 梁 + 弹性夹持** | 剪切变形 + 转动惯量 + 有限夹持刚度 `K_θ`；对厚/短尺修正 L1 |
| **L3** | **Duffing + Rayleigh 阻尼 + 声辐射** | 几何非线性（大振幅硬化）、材料阻尼、声压指向性 |

### 五种材料

| 材料 | 类型 | 说明 |
|------|------|------|
| 钢 (Steel) | 金属 | 高 Q 值，明亮音色，线性行为 |
| PVC | 塑料 | 低 Q 值，沉闷音色，可能需要几何非线性 |
| 亚克力 (Acrylic) | 塑料 | 中 Q 值，清晰音色 |
| 缎木 (Satiné) | 木材 | 各向异性，中 Q 值（弹性模量为文献估计） |
| 雪弗板 (Sintra/PVC foam) | 发泡板 | 极低 Q 值，高阻尼（弹性模量为文献估计） |

### 参数扫描

- **长度** `L`：200–600 mm
- **厚度** `h`：1–6 mm
- **宽度** `b`：10–50 mm
- **夹持长度** `L_clamp`：10–50 mm
- **敲击位置**：末端、中点、1/3 处
- **敲击力幅值**：0.1–10 N

## 关键结论

| 结论 | 详情 |
|------|------|
| **`f ∝ h/L²`** | 薄尺成立（偏差 < 3%），厚/短尺需 Timoshenko 修正 |
| **夹持刚度影响** | `K_θ ≈ 10⁴–10⁵ N·m/rad` 时基频偏移 5–15% |
| **敲击位置控制模态参与** | 末端 → 基频主导；中点 → 偶次模态被抑制；1/3 处 → 丰富频谱 |
| **材料音色差异** | 钢高 Q 明亮延音 / PVC 低 Q 沉闷 / 木质中等 |
| **SPL 指向性** | 正面比侧面高 15–25 dB，基频呈偶极子模式 |

## 项目进展

| 项目 | 状态 |
|------|------|
| **L1（Euler-Bernoulli）理论验证** | ✅ 已完成 |
| **L2（Timoshenko + 弹性夹持）理论验证** | ✅ 已完成 |
| **L3（Duffing + Rayleigh + 声辐射）理论验证** | ❌ 大振幅非线性验证待完成 |
| **COMSOL 全参数扫描（5 种材料 × 多 L/h）** | ✅ 已在 Linux 服务器完成 |
| **频率缩放 `f ∝ h/L²`** | ✅ 已验证（薄尺偏差 < 3%） |
| **夹持刚度 `K_θ` 分析** | ✅ 已验证（5–15% 偏移） |
| **敲击位置模态控制** | ✅ 已验证 |
| **SPL 指向性（正面 vs 侧面）** | ✅ 已验证（15–25 dB 差异） |
| **材料音色表征** | ✅ 已验证（钢高 Q / PVC 低 Q / 木质中等） |
| **几何非线性（Green-Lagrange）** | ⚠️ 已对非钢材料实现，验证中 |
| **缎木 & 雪弗板弹性模量** | ❌ 文献估计值，未实测 |
| **超弹性材料模型** | ❌ 待开发（未来工作） |

## 技术栈

| 层 | 技术 |
|----|------|
| **FEM 求解** | COMSOL Multiphysics 6.1（Linux 服务器 batch 模式） |
| **模型构建** | Java（COMSOL Java API）+ Python 编排 |
| **后处理** | MATLAB R2025a（离线 CSV 优先） |
| **配置** | JSON |

## 服务器仿真包（活跃代码）

所有仿真代码位于 Linux 服务器 `~/comsol_work/the_singing_ruler/`：

| 包名 | 目录 | 说明 |
|------|------|------|
| **full_server_source** | `the_singing_ruler_full_server_source/` | 主包：线性、非线性、阻尼 + 冲量 |
| **unified** | `the_singing_ruler_unified/` | 统一包：几何非线性 + 阻尼 + 冲量 + 长时间窗 |
| **hyperelastic** | `the_singing_ruler_hyperelastic/` | 超弹性材料模型（待开发） |

## 项目结构

```
the_singing_ruler/
├── matlab/                        # 后处理管线
│   ├── core/                      # 通用管线 + 衍生指标
│   │   ├── run_beam_model_pipeline.m
│   │   └── run_derived_metrics.m
│   ├── extract/                   # FFT、SPL、模态衰减、音色特征
│   ├── plot/                      # 论文级图表（9 张图，300 DPI）
│   │   └── plot_paper_figures_final.m
│   └── report/                    # 批处理 + 结论表
│       ├── batch_derived_metrics.m
│       └── aggregate_conclusion_table.m
├── the_singing_ruler_unified/     # 统一仿真包（符号链接 / 服务器引用）
├── scripts/                       # 部署脚本
└── ppt/                           # 演示文稿素材
```

## 编码规范

- **MATLAB**：`snake_case`
- **Java（COMSOL API）**：`PascalCase`
- **Python**：`snake_case`
- **质量档位**：`full / medium / coarse / decay / fast / eco`（6 档）
- **数据完整性**：每个数据点必须追溯到真实 COMSOL case；禁止合成、插值、曲线拟合
- **Git 边界**：`outputs/`、`runtime/`、`*.mph`、`*.pptx`、`*.pdf` 不入 Git
- **COMSOL**：仅服务器，不进入 CI

## 知识库

详细文档（理论推导、论文草稿、实验方案、文献研究）独立维护，与代码仓库分离。

> 知识库不属于此代码仓库。

## 许可证

MIT License — 详见 [LICENSE](LICENSE)
