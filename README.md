# The Singing Ruler — IYPT 2026 结构声学

3D 实体尺子受脉冲力敲击后，在空气中振动并产生声压波的 COMSOL 多物理场仿真。核心研究目标：音色（材料频谱特征）、音调（几何参数频率扫描）、声压（SPL 指标）。

仿真在 Linux 服务器运行（COMSOL 6.1），本地做 MATLAB 后处理和文档管理。

## 技术栈

| 层 | 技术 |
|---|---|
| FEM 求解 | COMSOL Multiphysics 6.1 (Linux batch 模式) |
| 模型构建 | Java (COMSOL Java API) + Python 编排 |
| 后处理 | MATLAB R2025a（离线 CSV 优先） |
| 配置 | JSON |

## 项目结构

```
the_singing_ruler/
├── matlab/               # 后处理管线
│   ├── core/             # 通用管线 + 衍生指标
│   ├── extract/          # FFT、SPL、模态衰减、音色特征
│   ├── plot/             # 论文级图表（9 张图，300 DPI）
│   └── report/           # 批处理 + 结论表
├── docs/                 # 设计文档、报告
│   └── reports/          # PROJECT_MASTER_DOCUMENT_ZH.md 主文档
├── the_singing_ruler_unified/  # 统一仿真包（几何非线性 + 阻尼 + 冲量）
├── scripts/              # 部署脚本
└── ppt/                  # 演示文稿素材
```

## 物理模型

- **结构**: 3D 线弹性 Solid Mechanics, Rayleigh 阻尼
- **声学**: 3D 瞬态 Pressure Acoustics, 单向耦合
- **激励**: 半正弦脉冲 (Hertz 接触修正)
- **非线性**: Green-Lagrange 几何非线性（非钢材料）
- **求解**: Eigenfrequency → Structure Transient → Acoustics Transient

详见 `docs/reports/PROJECT_MASTER_DOCUMENT_ZH.md`

## 许可证

MIT License — 详见 [LICENSE](LICENSE)
