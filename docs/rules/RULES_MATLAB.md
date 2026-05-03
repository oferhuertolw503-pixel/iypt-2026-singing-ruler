---
audience: agent
agent-priority: high
canonical-rules: true
last-reviewed: 2026-05-02
context-budget: 4KB
agent-summary: "MATLAB 调用约束：manifest 协议、batch vs 交互式、CSV-ready 判断、MCP 优先级、失败处理"
---

# MATLAB 行为规则

<!-- rule-table: RULES_MATLAB -->

## M1 Manifest 协议

所有 MATLAB 后处理必须走 manifest 协议。

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| M101 | 所有 MATLAB 调用通过 `*_matlab_manifest.json` 交接，不直接互相调用 | error | ARCHITECTURE §0 |
| M102 | 不把 matlab.exe 作为"启动器"，所有调用走 manifest | error | ARCHITECTURE §8 |
| M103 | manifest 必须包含：entry_function、output_root、config_path、mph_path、quality、model_line、model_id | error | ARCHITECTURE §4.1 |
| M104 | status JSON 状态机：pending → running → completed/failed | error | ARCHITECTURE §4.1 |
| M105 | 新增模型时需在 run_matlab_model.ps1 中注册 entry_function 的 CSV 依赖 | error | ARCHITECTURE §6.3 |

## M2 Batch 执行（有 CSV）

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| M201 | 已有完整 CSV 的 manifest → 使用 matlab -batch 自动化 | error | AUTOMATION §1 |
| M202 | 全自动入口：powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1 | info | AUTOMATION §3 |
| M203 | 参数 -SkipMatlabRun：只生成队列不运行；-Force：强制重跑；-MaxQueued N：限制数量 | info | AUTOMATION §3 |
| M204 | 单个 manifest：powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 -ManifestPath <path> | info | AUTOMATION §4 |

## M3 交互式执行（无 CSV）

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| M301 | 缺 CSV 且依赖 COMSOL LiveLink 的 manifest → 不自动执行 | error | AUTOMATION §2 |
| M302 | 如需手动执行：在交互式 MATLAB 中 cd 到项目根，addpath，调用 run_matlab_manifest('<path>') | info | AUTOMATION §4.2 |
| M303 | 批量待处理：run_pending_matlab_manifests | info | AUTOMATION §4.2 |

## M4 CSV-ready 判断

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| M401 | CSV 完整性预检在 PowerShell 层完成（run_matlab_model.ps1），不推给 MATLAB | error | AUTOMATION §5 |
| M402 | 缺 CSV 时快速失败（<1s），不再触发 MATLAB 崩溃 7 次重试 | error | AUTOMATION §5 |
| M403 | 各模型所需 CSV 列表在 Get-ManifestRequiredCsvPaths 中注册 | error | ARCHITECTURE §6.3 |

## M5 MCP 优先级

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| M501 | MCP 可用时：detect_matlab_toolboxes > check_matlab_code > run_matlab_test_file > evaluate_matlab_code > run_matlab_file | info | AUTOMATION §7 |
| M502 | MCP 不可用时：matlab -batch 作为可靠 fallback | info | AUTOMATION §7 |

## M6 环境

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| M601 | TSR_MATLAB_EXE = D:\Program Files\Matlab R2025a\bin\matlab.exe | info | AUTOMATION §6 |
| M602 | MATLAB 2025a headless JVM 无法初始化 COMSOL 6.4 Eclipse/OSGi 运行时（已知限制，非代码问题）| info | AUTOMATION §9 |
