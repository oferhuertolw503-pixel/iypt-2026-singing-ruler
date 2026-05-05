---
audience: human-and-agent
agent-priority: high
last-reviewed: 2026-05-04
context-budget: 8KB
agent-summary: "可复用 COMSOL 仿真项目架构指南。面向其它物理模型迁移：PowerShell 调度、COMSOL Java/batch 求解、MATLAB manifest 后处理、输出规范和检查清单。"
---

# COMSOL 仿真项目复用技术指南

本文档把 The Singing Ruler 项目的 COMSOL 仿真流水线抽象成可复用架构，用于迁移到其它物理模型项目。目标是复用工程骨架，而不是复用具体物理方程。

适用项目特征：

- 使用 COMSOL Java API 定义模型、几何、物理场、网格、Study 和结果导出。
- 使用 PowerShell 统一调度 `comsolcompile.exe`、`comsolbatch.exe` 和 MATLAB。
- 使用 MATLAB 做离线后处理、绘图、summary 汇总和报告指标计算。
- 需要让 Codex/Claude 通过明确任务卡驱动仿真与验证。

## 1. 可复用核心架构

推荐保留三阶段结构：

```text
Phase 1: PowerShell 调度
  params.json -> resolved config -> Java 参数注入 -> compile -> batch

Phase 2: COMSOL Java/batch 求解
  Model.java -> .class -> .mph -> CSV / TXT / probe / table exports

Phase 3: MATLAB manifest 后处理
  manifest.json -> main_<model>_from_manifest.m -> figures / summary.json / reports
```

核心原则：

- 模型物理细节只放在 `models/<line>/<model>/` 和 `matlab/main_<model>*`。
- 调度、输出目录、manifest、MATLAB handoff 尽量由共享脚本处理。
- COMSOL 尽量在 Java/batch 阶段直接导出 CSV，让 MATLAB 后处理不依赖 LiveLink。
- 如果必须使用 LiveLink，必须由任务卡明确授权，并仅在本机正版离线许可证环境下运行。
- `outputs/` 和 `runtime/` 作为本机运行产物，默认不进入 Git。

## 2. 推荐目录模板

新项目可采用以下结构：

```text
project/
  docs/
    WORKFLOW_ARCHITECTURE.md
    COMSOL_PROJECT_REUSE_GUIDE.md
    rules/
      RULES_AGENT.md
      RULES_MATLAB.md
      RULES_OUTPUT.md
  scripts/
    comsol_common.ps1
    run_matlab_model.ps1
    prepare_matlab_automation_queue.ps1
    run_full_matlab_automation.ps1
  models/
    <line>/
      <model>/
        config/
          params.json
        src/
          Model.java
        run.ps1
        sweep.ps1
        artifacts/
  matlab/
    run_matlab_manifest.m
    run_matlab_manifest_queue.m
    main_<model>.m
    main_<model>_from_manifest.m
    core/
    extract/
    plot/
    export/
    tests/
  outputs/
    <line>/<model>/
      params_resolved.json
      mph/
      data/
      figures/
      logs/
      summary.json
  runtime/
    comsol/
```

## 3. 每个新模型必须实现的接口

### PowerShell 入口

每个模型提供一个 `models/<line>/<model>/run.ps1`，负责：

- 读取 `config/params.json`。
- 合并 quality 覆盖参数。
- 创建规范输出目录。
- 将参数注入 Java 模板。
- 调用 `comsolcompile.exe`。
- 调用 `comsolbatch.exe`。
- 写 MATLAB handoff manifest。
- 可选触发 MATLAB 后处理。

建议参数：

```powershell
param(
    [ValidateSet("coarse", "medium", "full")]
    [string]$Quality = "coarse",
    [string]$ConfigPath = "",
    [string]$OutputRoot = "",
    [switch]$SkipMatlabPostprocess
)
```

### COMSOL Java 模型

每个模型提供一个 `models/<line>/<model>/src/Model.java`，负责：

- 创建 COMSOL model。
- 定义参数、几何、材料、物理场、网格和 Study。
- 运行求解。
- 直接导出 MATLAB 所需 CSV。
- 保存 `.mph` 到 `outputs/.../mph/`。

Java 模板应包含可替换参数块：

```java
// __PARAM_BLOCK__
```

PowerShell 在编译前把 resolved config 注入该块。参数名应稳定，避免 MATLAB 和报告层依赖易变字段。

### MATLAB manifest 入口

每个模型至少提供：

```text
matlab/main_<model>.m
matlab/main_<model>_from_manifest.m
```

`main_<model>_from_manifest.m` 负责：

- 读取 manifest。
- 定位 `output_root`、`config_path`、`mph_path`。
- 优先读取 `data/*.csv`。
- 生成 `figures/`、`summary.json` 和必要的派生指标。
- 写 status 为 `completed` 或 `failed`。

## 4. Manifest 协议

推荐 manifest 字段：

```json
{
  "manifest_version": 1,
  "created_at": "ISO-8601 timestamp",
  "project_root": "absolute path",
  "matlab_project_root": "absolute path",
  "source_script": "models/<line>/<model>/run.ps1",
  "model_line": "<line>",
  "model_id": "<model>",
  "entry_function": "main_<model>_from_manifest",
  "invoke_style": "manifest_path",
  "output_root": "absolute path",
  "config_path": "absolute path",
  "mph_path": "absolute path",
  "log_path": "absolute path",
  "status_path": "absolute path",
  "function_args": [],
  "quality": "coarse|medium|full"
}
```

Status 文件推荐状态机：

```text
pending -> running -> completed
pending -> running -> failed
pending -> skipped
```

## 5. 输出规范

每次运行必须产出规范目录：

```text
outputs/<line>/<model_or_case>/
  params_resolved.json
  mph/
    <model>.mph
  data/
    <domain_specific>.csv
  figures/
    <domain_specific>.png
  logs/
    <model>.log
    <model>_matlab_manifest.json
    <model>_matlab_status.json
    <model>_matlab.log
  summary.json
```

规则：

- 原始大文件、`.mph`、大型 CSV、图片默认留在 `outputs/`，不进入 Git。
- 可复现所需的轻量摘要可以复制到 `docs/reports/`。
- 文档引用 `outputs/` 时必须说明它是本地生成路径。
- 不生成伪数据、合成数据或未标注推断结果。

## 6. Quality 档位设计

每个项目应定义三档：

| Quality | 用途 | 典型策略 |
|---|---|---|
| coarse | 快速冒烟测试 | 小网格、短时间、少频点 |
| medium | 论文/报告前验证 | 中等网格、中等时间、稳定导出 |
| full | 最终结果 | 高精度、高成本、长时间 |

Quality 只改变数值成本参数，不应改变物理模型含义。若某个物理模型需要改变边界条件或材料，应创建新的 case config，而不是用 quality 暗中改变物理设定。

## 7. Agent/Codex/Claude 复用规则

推荐分工：

- Codex 负责方案、任务卡、边界、最终验收。
- Claude Code 负责按任务卡实现代码。
- COMSOL 自动化仅在任务卡明确授权时运行。
- MATLAB 后处理优先使用 manifest 和 batch。
- GitHub/Obsidian 同步不应由 Claude 默认执行。

Claude 任务卡必须写明：

```text
Allowed files:
- ...

COMSOL allowance:
- not allowed
```

或：

```text
COMSOL allowance:
- allowed
- exact command: pwsh -NoProfile -File .\models\<line>\<model>\run.ps1 -Quality coarse -SkipMatlabPostprocess
- allowed output root: outputs/<line>/<case>
```

## 8. 迁移到新物理模型的步骤

1. 复制共享脚本骨架：`scripts/comsol_common.ps1`、MATLAB manifest runner、输出规则文档。
2. 创建 `models/<line>/<model>/config/params.json`。
3. 创建 `models/<line>/<model>/src/Model.java`，只实现该模型的物理细节。
4. 创建 `models/<line>/<model>/run.ps1`，接入共享 compile/batch/output/manifest 函数。
5. 创建 `matlab/main_<model>.m` 和 `main_<model>_from_manifest.m`。
6. 在 MATLAB 队列脚本中注册该 entry function 的 CSV 依赖。
7. 运行 coarse build-only 测试。
8. 运行 coarse COMSOL + MATLAB 全链路测试。
9. 再升级到 medium/full。
10. 把轻量报告写入 `docs/reports/`，不要把 `outputs/` 入 Git。

## 9. 验收清单

新增模型合格条件：

- [ ] `run.ps1 -Quality coarse -SkipMatlabPostprocess` 可生成 `.mph` 和 CSV。
- [ ] manifest 中路径均为绝对路径或可稳定解析路径。
- [ ] MATLAB manifest 后处理可在已有 CSV 时独立运行。
- [ ] `summary.json` 含关键指标和数据来源。
- [ ] `logs/` 中保存 COMSOL 与 MATLAB 日志。
- [ ] `outputs/` 不进入 Git。
- [ ] `docs/reports/` 保存轻量结论或验证摘要。
- [ ] 任务卡明确 COMSOL 是否允许运行。
- [ ] 不依赖联网许可证检查或 CI 中的 COMSOL。

## 10. 当前项目中可参考的文件

| 用途 | 文件 |
|---|---|
| 通用架构说明 | `docs/WORKFLOW_ARCHITECTURE.md` |
| Agent 边界 | `docs/rules/RULES_AGENT.md` |
| MATLAB 自动化 | `docs/MATLAB_AUTOMATION.md` |
| 输出规范 | `docs/rules/RULES_OUTPUT.md` |
| COMSOL 共享调度 | `scripts/comsol_common.ps1` |
| 示例模型入口 | `models/linear/acoustic_field_3d_air/run.ps1` |
| 示例 COMSOL Java | `models/linear/acoustic_field_3d_air/src/Linear_Acoustic_Field_3D_Air.java` |
| MATLAB manifest 入口 | `matlab/run_matlab_manifest.m` |

复用时优先复制架构和接口，不要复制 The Singing Ruler 的材料参数、边界条件、几何尺寸或论文结论。
