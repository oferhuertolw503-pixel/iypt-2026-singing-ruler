# MATLAB 自动化完整方案

> 覆盖：batch 工作流、交互式流程、合规边界、错误诊断、COMSOL/LiveLink 已知限制
> 日常自动化优先使用 `matlab.exe -batch`；本文件是 MATLAB 相关操作的唯一参考文档

---

## 1. 核心规则

1. Codex 不启动 GUI MATLAB，不启动 COMSOL，不配置/绕过许可证
2. 所有 MATLAB 后处理走 manifest 协议（`*_matlab_manifest.json`），不发明临时入口
3. 已有 CSV 的 manifest → batch 自动化；无 CSV 的 manifest → 快速失败 + 提示用户
4. COMSOL/LiveLink 是用户本机控制的数据生产步骤，不作为 Codex 自动化依赖

## 2. 自动化分层

| 层级 | 内容 | 自动化 |
|---|---|---|
| L0 | MATLAB 环境检测（版本、路径） | 是 |
| L1 | MATLAB 静态检查（`checkcode`） | 是 |
| L2 | MATLAB 单元测试（`runtests`） | 是 |
| L3 | 已有 CSV 的 manifest 后处理 | **是（主路径）** |
| L4 | 缺 CSV 需 `.mph` 提取 | 否（需交互式 MATLAB） |
| L5 | COMSOL 求解、参数扫描、导出 CSV | 否（需用户授权 + 环境就绪） |
| L6 | GitHub Actions 远程 CI 跑 COMSOL | 暂不建议 |

## 3. 一键全自动入口

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
```

流程：扫描 `outputs/**/*matlab_manifest.json` → 生成队列 → 分类（queued / already_completed / needs_comsol_csv）→ 对 CSV-ready manifest 调用 `matlab -batch` → 生成 `outputs/automation/matlab_full_automation_report.md`

常用参数：

```powershell
# 只生成队列报告，不运行 MATLAB
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1 -SkipMatlabRun

# 强制重跑已完成的 manifest
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1 -Force

# 限制最多 1 个 queued manifest（烟雾测试）
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1 -Force -MaxQueued 1
```

## 4. 单个 manifest 执行

### 4.1 Batch 模式（有 CSV）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath <manifest.json>
```

CSV 完整条件（按模型类型）：

| 模型 | 所需 CSV |
|---|---|
| `*base_from_manifest` | `frequencies.csv`, `tip_timeseries.csv`, `mode_shapes.csv` |
| `*acoustic_field_from_manifest` | 同上 + `mic_pressure_timeseries.csv` |
| `*3d_air_from_manifest` | `frequencies.csv`, `structure_probe_timeseries.csv`, `mode_shapes.csv`, `mic_pressure_timeseries.csv`, `impact_force_timeseries.csv` |

### 4.2 交互式 MATLAB（无 CSV，需要 COMSOL LiveLink）

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
run_matlab_manifest('<manifest_path>')
```

或批量执行所有待处理：

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
comsol_disconnect([])
clear comsol_connect
run_pending_matlab_manifests
```

### 4.3 带 COMSOL 服务器（需显式授权）

```powershell
# 先启动服务器
D:\Program Files\COMSOL64\Multiphysics\bin\win64\comsolmphserver.exe `
  -port 2038 -login never -multi on -silent

# 显式绕过边界
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath <manifest.json> -AllowComsolLiveLink -LocalComsolPort 2038
```

## 5. 快速失败机制

`run_matlab_model.ps1` 在 PowerShell 层预检 CSV。缺 CSV 的 manifest **默认瞬间停止**（<1 秒），不再触发 7 次 MATLAB 崩溃重试。

```powershell
# 预期：快速失败（正常行为）
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath .\outputs\linear\base\logs\linear_base_matlab_manifest.json
```

输出示例：

```text
MATLAB automation stopped before COMSOL/LiveLink boundary.
Missing or unverified CSV inputs:
  - .../frequencies.csv
  - .../tip_timeseries.csv
  - .../mode_shapes.csv
```

## 6. 环境变量

| 变量 | 值 |
|---|---|
| `TSR_MATLAB_EXE` | `D:\Program Files\Matlab R2025a\bin\matlab.exe` |
| `COMSOL_BIN` | `D:\Program Files\COMSOL64\Multiphysics\bin\win64` |
| `TSR_COMSOL_PORT` | `2038` |

## 7. MCP 与 Batch 优先级

当前会话未暴露 MATLAB MCP 工具时，使用 batch 作为主路径。

| 优先级 | 工具 | 用途 |
|---|---|---|
| 1 | `detect_matlab_toolboxes` | 检测 MATLAB 版本和工具箱 |
| 2 | `check_matlab_code` | 静态分析 `.m` 文件 |
| 3 | `run_matlab_test_file` | 跑 MATLAB 单元测试 |
| 4 | `evaluate_matlab_code` | 小段代码验证 |
| 5 | `run_matlab_file` | 运行独立 `.m` 脚本 |
| fallback | `matlab.exe -batch` | MCP 不可用时的可靠路径 |

## 8. 可执行命令模板

```powershell
# 检测 MATLAB
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch "disp(version('-release')); disp(version);"

# 静态检查
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch "cd('C:/.../the_singing_ruler'); addpath(genpath('matlab')); checkcode('matlab/extract/read_exported_numeric_csv.m')"

# 跑测试
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch "cd('C:/.../the_singing_ruler'); addpath(genpath('matlab')); results = runtests('matlab'); assertSuccess(results)"

# 跑单个安全 manifest
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 -ManifestPath <manifest.json>

# 全自动
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
```

## 9. COMSOL LiveLink 已知限制（2026-05-01 测试）

6 轮测试结论：**`matlab -batch` 不可用于需要 COMSOL LiveLink 的 manifest。**

| # | 方案 | 结果 |
|---|---|---|
| 1 | batch + 已有 CSV manifest | 通过 |
| 2 | batch + 无 CSV manifest (Direct) | 崩溃 (exit -1) |
| 3 | batch + mphstart (login auto) | `FlException: 用户身份验证失败` |
| 4 | batch + mphstart (login never) | 同上 |
| 5 | batch + ModelUtil.load | `ExceptionInInitializerError` (OSGi 为 null) |
| 6 | `-nodesktop -nodisplay` + mphstart | 无输出/挂起 |

根因：MATLAB 2025a headless JVM 无法初始化 COMSOL 6.4 Eclipse/OSGi 运行时。非本项目代码问题。

一旦 CSV 通过交互式 MATLAB 首次生成，后续重跑可直接使用 batch 模式。

## 10. 失败诊断

| 现象 | 可能原因 | 处理 |
|---|---|---|
| MATLAB batch 无法启动 | 路径错误或安装损坏 | 检查 `TSR_MATLAB_EXE`，手动跑 `matlab -batch` |
| status 为 `failed` | 后处理代码或数据格式错误 | 读 log，修 MATLAB/CSV/manifest |
| manifest 缺 CSV 快速失败 | 需要 COMSOL 数据生产 | 停止自动化，提示用户生成 CSV |
| `mphstart` 认证失败 | COMSOL 许可证问题 | 不由 Codex 处理 |
| batch 触发 Java/OSGi 异常 | LiveLink 不适合 headless | 回到交互式 MATLAB |
| MCP 工具不存在 | 会话未加载 MCP | 使用 batch fallback |

## 11. CSV 导出格式规范

```text
% col1,col2,...
numeric_row_1
numeric_row_2
...
```

| 文件 | 列 |
|---|---|
| `frequencies.csv` | `mode`, `freq_hz` |
| `tip_timeseries.csv` | `t_s`, `w_m` |
| `structure_probe_timeseries.csv` | `t_s`, `uz_m` |
| `mic_pressure_timeseries.csv` | `t_s`, `p_pa` |
| `impact_force_timeseries.csv` | `t_s`, `force_z_N` |
| `mic_pressure_fft.csv` | `freq_hz`, `amp_pa` |
| `mode_shapes.csv` | `x_over_L`, `w_mode1...` |
