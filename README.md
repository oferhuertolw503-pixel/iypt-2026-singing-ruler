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
├── the_singing_ruler_unified/  # 统一仿真包（几何非线性 + 阻尼 + 冲量）
├── scripts/              # 部署脚本
└── ppt/                  # 演示文稿素材
```

> 📚 项目知识库（理论推导、论文草稿、实验方案、文献研究等）独立维护。结构索引见 [CLAUDE.md](CLAUDE.md)。

## 物理模型

- **结构**: 3D 线弹性 Solid Mechanics, Rayleigh 阻尼
- **声学**: 3D 瞬态 Pressure Acoustics, 单向耦合
- **激励**: 半正弦脉冲 (Hertz 接触修正)
- **非线性**: Green-Lagrange 几何非线性（非钢材料）
- **求解**: Eigenfrequency → Structure Transient → Acoustics Transient

## Project Progress

### Completed ✅
- **三层理论模型**：L1 Euler-Bernoulli → L2 Timoshenko+弹性夹持 → L3 Duffing+Rayleigh 声辐射
- **COMSOL 仿真**：在 Linux 服务器全量验证，Java API 模型编译运行通过，5 种材料 × 多长度/厚度的参数扫描
- **关键结论已验证**：
  - f ∝ h/L² 在薄尺区成立（偏差 < 3%）
  - 夹持刚度 K_θ ≈ 10⁴-10⁵ N·m/rad 时基频偏移 5-15%
  - 敲击位置控制模态参与（末端/中点/1/3 处）
  - 声辐射指向性：正面比侧面高 15-25dB
  - 音色的材料依赖性（钢高 Q / 塑料低 Q / 木质中等）

### Incomplete ❌
- 非线性 L3 模型（Duffing+Rayleigh）的大振幅验证
- 缎木和雪弗板弹性模量为文献估计而非实测

## 许可证

MIT License — 详见 [LICENSE](LICENSE)
