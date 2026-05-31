---
audience: agent
agent-priority: highest
canonical-rules: true
last-reviewed: 2026-05-02
context-budget: 8KB
agent-summary: "唯一默认入口。项目目标、边界、命令、禁止事项、输出约束、必读文件顺序"
---

# Agent Context — The Singing Ruler

> **入口文档。** Codex 或 Claude Code 在项目会话开始时应优先读取此文件。
> 详细规则见 `docs/rules/` 目录，专题文档见 `docs/` 其余文件。

---

## 1. 项目目标

以 COMSOL 仿真的 3D 实体尺子 + 3D 空气域模型数据为基础，通过 MATLAB 后处理提取物理指标（固有频率、时程、声压、FFT），生成论文所需的 CSV 数据表和 PNG 图表。

- **活跃主线**: `models/linear/acoustic_field_3d_air/`
- **数据基础**: 已有 22 个 steel 扫描 case + 5 材料 case 的完整 CSV
- **策略**: 优先用已有 CSV 出图分析，只在明确缺失时补跑

---

## 2. 必读文件顺序

Agent 应按以下顺序加载：

| 顺序 | 文件 | 原因 |
|---|---|---|
| 1 | `docs/rules/RULES_AGENT.md` | 角色分工、操作边界、COMSOL 禁区 |
| 2 | `docs/rules/RULES_MATLAB.md` | MATLAB 调用契约、batch/交互式、MCP 优先级 |
| 3 | `docs/rules/RULES_OUTPUT.md` | CSV/PNG/summary 规范、数据完整性 |
| 4 | `docs/AI_COLLABORATION_WORKFLOW.md` | Codex+Claude 执行协议详细版 |
| 5 | `docs/PROJECT_RUN_TARGETS.md` | 当前项目状态与目标清单 |
| 6 | `docs/MATLAB_AUTOMATION.md` | MATLAB 操作手册 |
| 7 | `docs/WORKFLOW_ARCHITECTURE.md` | 流水线接口文档 |
| 8 | `docs/GitHub仓库上传说明.md` | Git/GitHub/Obsidian 边界 |

> **human_archive/** 下的文件（如 `具体求解方案.md`）为人类学习手册，不包含 agent 可执行的规则，默认跳过。

---

## 3. 推荐命令

### 全自动 MATLAB 后处理（已有 CSV 时）

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
```

### 单个 manifest 执行

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 -ManifestPath <manifest.json>
```

### MATLAB 静态检查

```powershell
# MCP
/matlab-check <file.m>

# 或 batch
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch "cd('<project_root>'); addpath(genpath('matlab')); checkcode('<target.m>')"
```

### 运行 MATLAB 单元测试

```powershell
# MCP
/matlab-run-tests <test_file.m>

# 或 batch
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch "cd('<project_root>'); addpath(genpath('matlab')); results = runtests('matlab'); assertSuccess(results)"
```

### 环境检测

```powershell
# MATLAB 版本
/matlab-toolboxes

# COMSOL 服务器状态（仅当需要时）
& 'D:\Program Files\COMSOL64\Multiphysics\bin\win64\comsol.exe' -status
```

### 当前运行目标盘点

```powershell
# 扫描 outputs/ 下已有结果
ls outputs/**/logs/*_matlab_status.json 2>/dev/null
ls outputs/**/summary.json 2>/dev/null
```

---

## 4. 禁止事项

Agent 不得执行以下操作，除非所属任务卡明确授权：

```text
COMSOL:
  - 启动 comsolmphserver、mphstart、ModelUtil
  - 配置、修复或绕过 COMSOL 许可证
  - 默认将 COMSOL/LiveLink 作为自动化依赖

Git:
  - git add / git commit / git push（验收后由 Codex 执行）

Files:
  - 删除任何文件
  - 修改 docs/ 除非任务卡明确列出

MATLAB:
  - 发明临时入口替代 manifest 协议
  - 在缺 CSV 的 manifest 上跑 matlab -batch

Data:
  - 凭空指定基准数据
  - 生成合成数据或伪结果
```

---

## 5. 核心约束速查

| 场景 | 可自动执行？ | 条件 |
|---|---|---|
| 已有 CSV 的 manifest | **是** — batch | CSV 完整预检通过 |
| 缺 CSV 的 manifest | **否** — 快速失败 | 需用户本机 COMSOL 生产 |
| 新 COMSOL 模型构建 | 需授权 | COMSOL_BIN 可用、许可证可用 |
| 材料扫描参数补全 | 需授权 | 依赖已有 CSV 可用 |
| Git 推送 | 仅 Codex | 验收后 |
| Obsidian 同步 | 仅 Codex | 验收后 |
| 修改 docs/ | 仅任务卡列出时 | 不越界修改 |

---

## 6. 环境变量

| 变量 | 值 |
|---|---|
| `TSR_MATLAB_EXE` | `D:\Program Files\Matlab R2025a\bin\matlab.exe` |
| `COMSOL_BIN` | `D:\Program Files\COMSOL64\Multiphysics\bin\win64` |
| `TSR_COMSOL_PORT` | `2038` |
| 项目根 | `C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler` |
| Obsidian 同步目标 | `D:\Learning Resources\Obsidian\Archive\物理学术竞赛\Main 13  The Singing Ruler\Generated from Repo` |

---

## 7. 文件树速览

```
docs/
  AGENT_CONTEXT.md              ← 本文件（默认入口）
  rules/
    RULES_AGENT.md              ← Agent 行为规则（角色、边界、禁区）
    RULES_MATLAB.md             ← MATLAB 调用规则（manifest、batch、MCP）
    RULES_OUTPUT.md             ← 输出规范（CSV、PNG、summary）
  AI_COLLABORATION_WORKFLOW.md  ← Codex+Claude 执行协议
  MATLAB_AUTOMATION.md          ← MATLAB 操作手册
  PROJECT_RUN_TARGETS.md        ← 项目状态与目标清单
  WORKFLOW_ARCHITECTURE.md      ← 流水线接口文档
  GitHub仓库上传说明.md          ← Git/GitHub/Obsidian 同步说明
  human_archive/
    具体求解方案.md               ← [人类学习手册] agent 默认跳过
```
