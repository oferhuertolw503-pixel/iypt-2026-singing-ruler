# The Singing Ruler — Linux 服务器仿真包

> 部署: user@<your-linux-server>:~/comsol_work/the_singing_ruler/the_singing_ruler_full_server_source/
> COMSOL: 6.1.0.252 | 服务器: 256-core AMD EPYC 64C, 503GB RAM

## 概述

本包是"唱歌的尺子"项目的核心仿真引擎。它在 Linux 服务器上运行 COMSOL Multiphysics 批处理，求解 3D 实体尺子 + 3D 空气域的多物理场瞬态模型。

**求解的物理**:
1. 弹性尺子的瞬态振动 (Structural Mechanics, 3D Solid)
2. 空气域的压力声波传播 (Pressure Acoustics, Transient)
3. 单向声-结构耦合 (结构加速度 → 声学边界条件)

## 目录结构

```
the_singing_ruler_full_server_source/
├── src/
│   └── Linear_Acoustic_Field_3D_Air.java.template  # COMSOL Java API 模型
├── config/
│   ├── params_base.json          # 基准参数
│   ├── requested_cases.json      # 27-case 全扫描定义
│   ├── materials_combined.json   # 阻尼+冲量修正材料
│   ├── materials_only.json       # 纯材料定义 (非线性用)
│   └── materials_nonlinear.json  # 非线性材料定义
├── tools/
│   ├── run_requested_full.py     # 批处理编排器 (主入口)
│   ├── run_case.py               # 单 case 构建+求解
│   ├── validate_csv_bundle.py    # 输出完整性验证
│   └── run_requested_summary.py  # 结果汇总
├── tests/
│   └── test_server_package.py    # 单元测试
├── run_single_full.sh            # 单 case 快捷脚本
├── run_requested_full.sh         # 批处理快捷脚本
├── outputs/                      # 仿真输出 (不入 Git)
└── runtime/                      # 临时编译/求解目录
```

## 快速开始

```bash
cd ~/comsol_work/the_singing_ruler/the_singing_ruler_full_server_source

# 单 case 测试
./run_single_full.sh --study-id my_test

# 5 材料联合修正 (阻尼+冲量)
python3 -B tools/run_requested_full.py \
  --study-id materials_combined \
  --case-definition config/materials_combined.json \
  --quality fast --max-parallel 5 --comsol-np 12

# 27-case 全扫描 (自适应质量)
python3 -B tools/run_requested_full.py \
  --study-id requested_adaptive \
  --case-definition config/requested_cases.json \
  --adaptive --max-parallel 5 --comsol-np 12

# 预览 (dry-run, 不调用 COMSOL)
python3 -B tools/run_requested_full.py --study-id preview --dry-run
```

## 关键参数

### 质量档位

| 档位 | time_end | time_step | mesh | 耗时/case |
|---|---|---|---|---|
| full | 0.5s | 5e-5s | 80 | ~3h |
| medium | 0.35s | 1e-4s | 60 | ~1.5h |
| fast | 0.25s | 2e-4s | 40 | ~25min |
| eco | 0.15s | 5e-4s | 30 | ~5min |

### 并行控制

- `--max-parallel N`: 同时跑 N 个 case (推荐 5, 每 case 12 核 = 60 核总量)
- `--comsol-np M`: 每 case 使用 M 核 COMSOL 批处理 (推荐 12)
- `--adaptive`: 按参数类型自动选质量 (f-sensitive→fast, amplitude→eco)

## 配置文件

### Case Definition JSON 格式

```json
{
  "baseline": {
    "L_free_cm": 20, "b_cm": 3, "h_mm": 2,
    "x0_ratio": 0.8, "J_Ns": 0.04
  },
  "materials": [
    {
      "key": "pvc", "name": "PVC",
      "rho": "1380[kg/m^3]", "E": "3.0e9[Pa]", "nu": 0.38,
      "J_scale": 0.25, "zeta": 0.07
    }
  ],
  "scan_values": {
    "L_free_cm": [14, 17, 20, 23, 26],
    "b_cm": [2, 3, 4, 5],
    "h_mm": [0.5, 1.0, 2.0, 3.5, 5.0],
    "J_Ns": [0.01, 0.02, 0.04, 0.08, 0.16],
    "x0_ratio": [0.3, 0.5, 0.8, 0.95]
  }
}
```

### 材料参数

| key | ρ (kg/m³) | E (GPa) | ν | J_scale | ζ |
|---|---|---|---|---|---|
| steel | 7850 | 200 | 0.30 | 1.000 | 0.015 |
| pvc | 1380 | 3.0 | 0.38 | 0.250 | 0.07 |
| acrylic | 1190 | 3.2 | 0.35 | 0.255 | 0.06 |
| satinwood | 700 | 2.0 | 0.30 | 0.218 | 0.04 |
| xuefu_board | 500 | 1.0 | 0.30 | 0.154 | 0.10 |

## 每个 Case 的输出

```
outputs/<study_id>/cases/<group>/<case_id>/
├── data/
│   ├── frequencies.csv                  # f₁...f₆ (Hz)
│   ├── mic_pressure_timeseries.csv       # 基准麦克风 p(t)
│   ├── mic_pressure_timeseries_sweep_01~10.csv  # 10 距离麦克风
│   ├── mic_sweep_distances.csv           # 各麦克风距离
│   ├── structure_probe_timeseries.csv    # 探针位移 u_z(t)
│   ├── impact_force_timeseries.csv       # 实际冲量力 F(t)
│   ├── mode_shapes.csv                   # 前 6 阶振型
│   └── tip_timeseries.csv (可选)        # 自由端位移
├── params_resolved.json                  # 实际使用参数
├── mph/
│   └── linear_acoustic_field_3d_air.mph  # COMSOL 模型 (大文件)
└── logs/
    └── linear_acoustic_field_3d_air.log  # COMSOL 求解日志
```

## 测试

```bash
cd ~/comsol_work/the_singing_ruler/the_singing_ruler_full_server_source
python3 -B -m unittest discover -s tests -p "test_*.py"
```

## 技术说明

- **COMSOL 版本**: 6.1 (服务器), 6.3 (本地 Windows) — Java API 向前兼容
- **模型编译**: `comsol compile` → Java class → `comsol batch`
- **特征频率**: eigen_shift=1Hz 确保捕获低频模态 (尤其是非钢材料 f₁<50Hz)
- **麦克风**: CutPoint3D 探针，求解后评估 p(t)，额外算力接近零
- **MPH 文件注意**: 每个 0.5-5.7 GB，不入 Git，定期清理

---

*参考: [MATLAB 后处理模块](../matlab/README.md) | [项目总文档](../docs/reports/PROJECT_MASTER_DOCUMENT_ZH.md)*
