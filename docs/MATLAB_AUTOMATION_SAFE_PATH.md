# MATLAB 自动化正常路径与 COMSOL 边界

更新时间：2026-05-01

## 结论

当前项目的稳定自动化方案是：

```text
COMSOL 或人工流程生成 CSV -> manifest 描述输入输出 -> MATLAB R2025a -batch 纯后处理 -> status/log/figures/tables -> Codex 汇总与检查
```

已验证可用路径：

- MATLAB 正版安装可用：`D:\Program Files\Matlab R2025a\bin\matlab.exe`
- MATLAB batch 启动验证通过：`R2025a / 25.1.0.2943329`
- Codex 当前会话未暴露 MATLAB MCP 工具，因此本轮主路径使用 `matlab.exe -batch`
- 代表性 manifest 已通过 batch 验证：

```text
outputs/linear/acoustic_field/logs/linear_acoustic_field_matlab_manifest.json
```

验证命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath .\outputs\linear\acoustic_field\logs\linear_acoustic_field_matlab_manifest.json
```

验证结果：

```json
{
  "status": "completed",
  "message": "MATLAB handoff completed successfully."
}
```

2026-05-01 追加修正：

- `scripts/run_matlab_model.ps1` 已加入 COMSOL 边界预检。
- 缺少必需 CSV 的 COMSOL-backed manifest 默认不会再进入 MATLAB batch，也不会触发 7 次 MATLAB 启动重试。
- 如确需使用合法、完整配置的 COMSOL LiveLink 环境，必须显式使用 `-AllowComsolLiveLink`、`-LocalComsolPort` 或专用 local-port 脚本。

2026-05-02 追加修正：

- 已新增无需手动 MATLAB 命令的全自动主控脚本：`scripts/run_full_matlab_automation.ps1`。
- 该脚本自动生成 manifest 队列、自动调用 `matlab.exe -batch` 执行 CSV-ready manifest，并自动生成最终报告。
- 实测结果：`queued = 3`、`completed = 3`、`failed = 0`、`needs_comsol_csv = 35`、`matlab_exit = 0`。
- 最终报告路径：`outputs/automation/matlab_full_automation_report.md`。

## 许可证与合规边界

你的 MATLAB 是正版授权，因此 Codex 可以围绕 MATLAB 做自动化：运行 batch、检查代码、执行测试、生成文档、读取 status/log。

COMSOL 如果不是官方授权或许可证状态不可验证，Codex 不能帮助做以下事情：

- 配置、修复、绕过或调试 COMSOL 许可证认证
- 设计依赖破解授权才能运行的自动化流程
- 提供绕过 COMSOL server 登录、许可证、认证或授权限制的步骤
- 把破解 COMSOL 当作可靠 CI 或无人值守自动化依赖

Codex 可以帮助做以下合规工作：

- 编写 MATLAB 后处理代码，消费已经存在的 CSV、JSON、MAT 或文本数据
- 维护 manifest、status、log、figures、tables 的自动化规范
- 为合法 COMSOL/LiveLink 环境保留可选入口，但不默认执行
- 给出“如果你以后换成官方 COMSOL/LiveLink 授权，应如何接入”的接口边界
- 在不触碰许可证机制的前提下，诊断 MATLAB 代码、数据格式和 manifest 问题

## 自动化分层

| 层级 | 名称 | 是否推荐自动化 | 说明 |
|---|---|---:|---|
| L0 | MATLAB 环境检测 | 是 | `matlab.exe -batch` 查询版本、路径、产品 |
| L1 | MATLAB 静态检查 | 是 | 使用 `checkcode` 或 MCP `check_matlab_code` |
| L2 | MATLAB 单元测试 | 是 | 使用 `runtests`，优先 base MATLAB 测试 |
| L3 | 已有 CSV 的 manifest 后处理 | 是 | 当前最稳定的主路径 |
| L4 | 缺 CSV 但需要 `.mph` 提取 | 否，默认人工 | 需要 COMSOL/LiveLink，许可证与 GUI/session 状态不稳定 |
| L5 | COMSOL 求解、参数扫描、导出 CSV | 否，除非官方授权完整 | Codex 只可生成脚本和读取结果，不默认启动 |
| L6 | GitHub Actions 远程 CI 跑 COMSOL | 暂不建议 | 许可证、runner、COMSOL server 都不适合当前阶段 |

## 推荐日常流程

### 0. 一键全自动入口

默认推荐入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
```

该命令会自动完成：

1. 扫描 `outputs/**/*matlab_manifest.json`。
2. 生成 `outputs/automation/matlab_manifest_queue.json`。
3. 将已完成 manifest 标记为 `already_completed`。
4. 将缺 CSV 且依赖 COMSOL/LiveLink 的 manifest 标记为 `needs_comsol_csv`。
5. 只把确认 CSV-ready 的 manifest 交给 MATLAB。
6. 自动调用 `matlab.exe -batch` 执行 `matlab/run_matlab_manifest_queue.m`。
7. 生成 `outputs/automation/matlab_full_automation_report.md`。

常用参数：

```powershell
# 只生成队列和报告，不运行 MATLAB
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1 -SkipMatlabRun

# 强制重跑已 completed 的 CSV-ready manifest
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1 -Force

# 限制最多运行 1 个 queued manifest，用于 smoke test
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1 -Force -MaxQueued 1
```

### 1. Codex 先判断 manifest 是否可 batch

batch 可用条件：

```text
output_root/data/frequencies.csv
output_root/data/tip_timeseries.csv
output_root/data/mode_shapes.csv
output_root/data/mic_pressure_timeseries.csv
```

这些文件都存在时，Codex 可以运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath <manifest.json>
```

### 2. 如果 CSV 不完整，停止自动执行

CSV 不完整时，不要让 Codex 自动启动 COMSOL 或尝试修复许可证。应输出明确提示：

```text
该 manifest 需要 COMSOL/LiveLink 数据生产步骤。
Codex 不自动运行 COMSOL。
请先在你本机可用的 COMSOL 环境中生成 CSV，再重跑 MATLAB batch 后处理。
```

`scripts/run_matlab_model.ps1` 现在会执行这个规则：如果 manifest 缺少必需 CSV 且含有 `.mph` 输入，默认直接写入 `failed` status，并说明“stopped before COMSOL/LiveLink boundary”。

### 3. 人工或本地 COMSOL 会话生成 CSV

这一步由你在本机环境中控制。项目只要求最终产物满足 CSV 数据契约，不要求 Codex 参与 COMSOL 授权或启动。

推荐导出格式：

```text
% col1,col2,...
numeric_row_1
numeric_row_2
...
```

### 4. MATLAB batch 重跑后处理

CSV 生成后，重新运行同一个 manifest。不要临时换入口，也不要绕过 manifest。

### 5. Codex 汇总结果

Codex 检查：

- `*_matlab_status.json` 是否为 `completed`
- log 是否存在错误
- `figures/`、`tables/`、`data/` 是否生成预期文件
- README、CHANGELOG、Obsidian Markdown 是否需要同步

## MCP 与 batch 的优先级

当前会话未发现 MATLAB MCP 工具，因此使用 batch。

未来如果新 Codex 会话暴露 MATLAB MCP 工具，优先级如下：

| 优先级 | 工具 | 用途 |
|---:|---|---|
| 1 | `detect_matlab_toolboxes` | 检测 MATLAB 版本和工具箱 |
| 2 | `check_matlab_code` | 静态分析 `.m` 文件 |
| 3 | `run_matlab_test_file` | 跑 MATLAB 单元测试 |
| 4 | `evaluate_matlab_code` | 小段代码验证、变量检查、快速实验 |
| 5 | `run_matlab_file` | 运行独立 `.m` 脚本 |
| fallback | `matlab.exe -batch` | MCP 不可用时的可靠主路径 |

注意：MCP 是增强层，不应替代 manifest 工作流。

## 可执行命令模板

全自动运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
```

检测 MATLAB：

```powershell
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch "disp(version('-release')); disp(version);"
```

静态检查单文件：

```powershell
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch `
  "cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler'); addpath(genpath('matlab')); checkcode('matlab/extract/read_exported_numeric_csv.m')"
```

运行测试：

```powershell
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch `
  "cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler'); addpath(genpath('matlab')); results = runtests('matlab'); assertSuccess(results)"
```

运行已具备 CSV 的 manifest：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath .\outputs\linear\acoustic_field\logs\linear_acoustic_field_matlab_manifest.json
```

验证 COMSOL 边界是否能安全停止：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath .\outputs\linear\base\logs\linear_base_matlab_manifest.json
```

预期：失败是正常结果，但应在 PowerShell 预检阶段快速失败，不应启动 MATLAB 进行 7 次重试。

## 失败诊断

| 现象 | 可能原因 | 正确处理 |
|---|---|---|
| MATLAB batch 无法启动 | MATLAB 路径错误或安装损坏 | 检查 `TSR_MATLAB_EXE` 和 `matlab.exe -batch` |
| status 为 `failed` | MATLAB 后处理代码或数据格式错误 | 读 log，修 MATLAB/CSV/manifest |
| manifest 缺少 CSV | 需要 COMSOL 数据生产 | 停止自动化，要求先生成 CSV |
| `mphstart` 认证失败 | COMSOL server 登录/许可证/授权问题 | 不由 Codex 处理，不尝试绕过 |
| batch 触发 COMSOL Java/OSGi 异常 | LiveLink 不适合当前 headless 模式 | 回到交互式/人工 COMSOL 产出 CSV |
| MCP 工具不存在 | 当前 Codex 会话未加载 MCP | 用 `matlab.exe -batch` fallback |

## 文档更新规则

- `MATLAB_BATCH_WORKFLOW.md`：记录 batch 主流程和 CSV 判定规则。
- `MATLAB_USER_WORKFLOW.md`：记录人机协作流程和 manifest 入口。
- `MATLAB_BATCH_COMSOL_ERRATA.md`：记录 COMSOL/LiveLink 失败边界，不作为破解或绕过指南。
- `MATLAB_DEVELOPMENT_LEARNING_GUIDE.md`：记录学习路线和 AI 工具使用方式。

## 官方参考

- MATLAB MCP Core Server: https://github.com/matlab/matlab-mcp-core-server
- MATLAB Agentic Toolkit: https://github.com/matlab/matlab-agentic-toolkit
- MATLAB `-batch` startup option: https://www.mathworks.com/help/matlab/ref/matlabwindows.html
- MATLAB `checkcode`: https://www.mathworks.com/help/matlab/ref/checkcode.html
- MATLAB `runtests`: https://www.mathworks.com/help/matlab/ref/runtests.html
- MATLAB GitHub Actions `run-tests`: https://github.com/matlab-actions/run-tests
- COMSOL LiveLink for MATLAB documentation: https://doc.comsol.com/

## 最终建议

把“正常自动化”定义为 MATLAB 可重复处理链，而不是 COMSOL 无人值守求解链：

```text
Codex 自动化 = MATLAB batch + manifest + CSV + tests + docs
COMSOL 环节 = 你本机控制的数据生产步骤
```

这样可以最大化利用正版 MATLAB 授权，同时避免让整个工作流依赖 COMSOL 许可证状态、GUI/session 状态或不可验证的本地环境。
