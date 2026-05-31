# the_singing_ruler — "唱歌的尺子" 结构声学

3D 实体尺子受脉冲力敲击后，在空气中振动并产生声压波的 COMSOL 多物理场仿真。核心研究目标：音色（材料频谱特征）、音调（几何参数频率扫描）、声压（SPL 指标）。

仿真在 Linux 服务器运行（COMSOL 6.1），本地仅做 MATLAB 后处理和文档管理。

## 技术栈

| 层 | 技术 |
|---|---|
| FEM 求解 | COMSOL Multiphysics 6.1 (Linux 服务器 batch 模式) |
| 模型构建 | Java (COMSOL Java API) → Python 编排 |
| 后处理 | MATLAB R2025a（离线 CSV 优先） |
| 配置 | JSON |

## 服务器包（活跃仿真代码）

所有仿真代码在 Linux 服务器 `user@<your-linux-server>:~/comsol_work/the_singing_ruler/`：

| 包 | 目录 | 说明 |
|---|---|---|
| **full_server_source** | `the_singing_ruler_full_server_source/` | 主包：线性、非线性、阻尼+冲量 |
| **unified** | `the_singing_ruler_unified/` | 统一包：几何非线性 + 阻尼 + 冲量 + 长时间窗 |
| **hyperelastic** | `the_singing_ruler_hyperelastic/` | 超弹性（待开发） |

## 关键目录（本地）

```
matlab/
  core/run_beam_model_pipeline.m         # 通用管线（离线 CSV 优先）
  core/run_derived_metrics.m             # 衍生指标计算枢纽
  extract/                               # FFT、SPL、模态衰减、音色特征
  plot/plot_paper_figures_final.m        # 9 张论文图（300 DPI）
  report/batch_derived_metrics.m         # 批处理入口
  report/aggregate_conclusion_table.m    # 73 列主结论表
scripts/                                # PowerShell 编排（已少用）
docs/
  04_报告与PPT/PROJECT_MASTER_DOCUMENT_ZH.md  # 论文级总文档
  00_项目导航/PACKAGES_README.md              # 服务器包说明
  00_项目导航/HANDOVER_PROMPT.md              # 新人接手文档
outputs/                                 # 仿真结果 CSV（不入 Git）
  requested_adaptive/                    # 27-case 全扫描
  materials_combined/                    # 阻尼+冲量联合修正
  materials_eigenfix/                    # 线性基准
  materials_nonlinear/                   # 几何非线性
```

## 核心约定

- **离线 CSV 优先**：MATLAB 先检查已有 CSV，仅在 CSV 缺失时回退 LiveLink（需显式授权）
- **数据完整性硬规则**：每个数据点必须追溯到真实 COMSOL case；禁止合成、插值、曲线拟合
- **材料扫描**：钢、PVC、亚克力、缎木、雪弗板（5 种）
- **命名**：MATLAB 用 snake_case，Java 用 PascalCase，Python 用 snake_case
- **质量档位**：`full / medium / coarse / decay / fast / eco`（6 档）
- **Git 边界**：`outputs/`, `runtime/`, `*.mph`, `*.pptx`, `*.pdf` 不入 Git
- **COMSOL 仅服务器**：不进入 GitHub Actions/CI

## 物理模型

- **结构**: 3D 线弹性 Solid Mechanics, Rayleigh 阻尼
- **声学**: 3D 瞬态 Pressure Acoustics, 单向耦合
- **激励**: 半正弦脉冲 (Hertz 接触修正)
- **非线性**: Green-Lagrange 几何非线性（非钢材料）
- **求解**: Eigenfrequency → Structure Transient → Acoustics Transient

详见 `docs/04_报告与PPT/PROJECT_MASTER_DOCUMENT_ZH.md`
