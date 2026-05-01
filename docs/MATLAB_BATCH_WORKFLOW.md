# MATLAB Batch 模式使用方案

> 主方案更新：正常 MATLAB 自动化路径见
> [`MATLAB_AUTOMATION_SAFE_PATH.md`](MATLAB_AUTOMATION_SAFE_PATH.md)。
> 该方案把 MATLAB R2025a `-batch` 作为稳定底座，把 COMSOL/LiveLink 视为可选的数据生产边界。

> 无需手动 MATLAB 命令的全自动入口：
>
> ```powershell
> powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
> ```

## 核心规则

`matlab -batch` 是否可用取决于 manifest 对应输出目录是否已有 CSV 数据：

| 场景 | batch 模式 | 说明 |
|---|---|---|
| 已有 CSV (`frequencies.csv` + `tip_timeseries.csv` + `mode_shapes.csv`) | 可用 | 跳过 COMSOL，纯后处理 |
| 无 CSV（需从 .mph 提取） | 默认快速失败 | `run_matlab_model.ps1` 会在 PowerShell 预检阶段停止，不再触发 7 次 MATLAB 崩溃重试 |
| sweep 后处理聚合 | 可用 | 各 case 已有 CSV，只做汇总 |

2026-05-01 代表性验证：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath .\outputs\linear\acoustic_field\logs\linear_acoustic_field_matlab_manifest.json
```

结果：`linear_acoustic_field_matlab_status.json` 返回 `status = completed`。

## 合规边界

Codex 可以自动化正版 MATLAB 的 batch、静态检查、测试和 CSV 后处理。
Codex 不应配置、修复、绕过或依赖任何非官方 COMSOL 授权状态；需要 COMSOL/LiveLink 的步骤应由用户在本机受控环境中完成，并把 CSV 作为 MATLAB 自动化输入。

如果确实要在完整合法的 LiveLink 环境中测试 COMSOL 连接，必须显式使用 `-AllowComsolLiveLink`、`-LocalComsolPort` 或 `scripts/run_matlab_manifest_local_port.ps1`，不要把它作为默认 Codex 自动化路径。

## 工作流一：batch 模式（有 CSV 的 manifest）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath <manifest.json路径>
```

示例：
```powershell
# acoustic_field（已有 CSV）
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath .\outputs\linear\acoustic_field\logs\linear_acoustic_field_matlab_manifest.json

# sweep 后处理
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath .\outputs\linear\sweep\study_param_smoke_20260422\logs\linear_acoustic_param_study_matlab_manifest.json
```

## 工作流二：交互式 MATLAB（无 CSV 的 manifest）

需要 COMSOL LiveLink 的 manifest（`base`、`impact_response`、`acoustic_field_3d_air` 首次运行），在 VSCode MATLAB 交互会话中执行：

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
run_matlab_manifest('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler/outputs/linear/base/logs/linear_base_matlab_manifest.json')
```

或批量执行所有待处理 manifest：

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
comsol_disconnect([])
clear comsol_connect
run_pending_matlab_manifests
```

## COMSOL 服务器管理

交互式 MATLAB 使用 COMSOL LiveLink 时，如需手动管理服务器：

```powershell
# 启动 COMSOL 服务器
D:\Program Files\COMSOL64\Multiphysics\bin\win64\comsolmphserver.exe `
  -port 2038 -login never -multi on -silent

# 终止 COMSOL 服务器
taskkill /F /IM comsolmphserver.exe
```

## 判断 manifest 是否需要 COMSOL

检查输出目录的 `data/` 子目录：
- 存在 `frequencies.csv`、`tip_timeseries.csv`、`mode_shapes.csv` → batch 可用
- 缺少任一文件 → 需要交互式 MATLAB

## 环境变量

| 变量 | 值 | 用途 |
|---|---|---|
| `TSR_MATLAB_EXE` | `D:\Program Files\Matlab R2025a\bin\matlab.exe` | 指定 MATLAB 路径 |
| `COMSOL_BIN` | `D:\Program Files\COMSOL64\Multiphysics\bin\win64` | 指定 COMSOL 路径 |
| `TSR_COMSOL_PORT` | `2038` | COMSOL LiveLink 端口 |

## 已知限制

- MATLAB 2025a headless 模式无法初始化 COMSOL 6.4 Eclipse/OSGi 运行时
- 这不是本项目代码问题，系 MATLAB/COMSOL 版本兼容性限制
- 一旦 CSV 数据通过交互式 MATLAB 首次生成，后续重跑可直接使用 batch 模式
