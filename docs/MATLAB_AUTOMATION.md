---
audience: agent
agent-priority: high
last-reviewed: 2026-05-02
context-budget: 5KB
agent-summary: "MATLAB 操作手册：manifest 执行、batch 自动化、交互式流程、MCP 工具链。规则见 docs/rules/RULES_MATLAB.md、输出规范见 docs/rules/RULES_OUTPUT.md"
---

# MATLAB 操作手册

> 详细规则见 `docs/rules/RULES_MATLAB.md`。
> 输出规范（CSV/PNG/summary）见 `docs/rules/RULES_OUTPUT.md`。

---

## 1. 自动化分层

| 层级 | 内容 | 可自动 |
|---|---|---|
| L0 | MATLAB 环境检测（版本、路径）| 是 |
| L1 | MATLAB 静态检查（checkcode）| 是 |
| L2 | MATLAB 单元测试（runtests）| 是 |
| L3 | 已有 CSV 的 manifest 后处理 | **是（主路径）** |
| L4 | 缺 CSV 需 .mph 提取（交互式 MATLAB）| 否 |
| L5 | COMSOL 求解、参数扫描、导出 CSV | 否（需用户授权）|
| L6 | GitHub Actions 远程 CI | 暂不建议 |

## 2. 一键全自动入口

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
```

参数：

```powershell
# 只生成队列报告，不运行 MATLAB
-SkipMatlabRun

# 强制重跑已完成的 manifest
-Force

# 限制最多 N 个 queued manifest
-Force -MaxQueued N
```

## 3. 单个 manifest 执行

### 3.1 Batch 模式（有 CSV）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 -ManifestPath <manifest.json>
```

### 3.2 交互式 MATLAB（无 CSV，需 COMSOL LiveLink）

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
run_matlab_manifest('<manifest_path>')
```

## 4. MCP 工具链

| 优先级 | 工具 | 用途 |
|---|---|---|
| 1 | `detect_matlab_toolboxes` | 检测 MATLAB 版本和工具箱 |
| 2 | `check_matlab_code` | 静态分析 .m 文件 |
| 3 | `run_matlab_test_file` | 跑 MATLAB 单元测试 |
| 4 | `evaluate_matlab_code` | 小段代码验证 |
| 5 | `run_matlab_file` | 运行独立 .m 脚本 |
| fallback | `matlab.exe -batch` | MCP 不可用时的可靠路径 |

## 5. 失败诊断

| 现象 | 可能原因 | 处理 |
|---|---|---|
| MATLAB batch 无法启动 | 路径错误或安装损坏 | 检查 TSR_MATLAB_EXE |
| status 为 failed | 后处理代码或数据格式错误 | 读 log，修 MATLAB/CSV/manifest |
| manifest 缺 CSV 快速失败 | 需要 COMSOL 数据生产 | （正常行为）停止自动化，提示用户 |
| MATLAB 2025a + COMSOL | headless JVM 无法初始化 OSGi | 回到交互式 MATLAB（已知限制）|

## 6. 环境

| 变量 | 值 |
|---|---|
| TSR_MATLAB_EXE | D:\Program Files\Matlab R2025a\bin\matlab.exe |
