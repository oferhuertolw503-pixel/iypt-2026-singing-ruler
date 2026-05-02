# Codex Leader + Claude Code Worker 协作工作流

> 适用范围：The Singing Ruler 项目中的代码实现、MATLAB 后处理、文档同步和 GitHub 工作流。
> 核心目标：Codex 作为 leader 下发任务、控制边界、验收结果；Claude Code 作为 worker 负责具体代码实施。

---

## 1. 角色分工

| 角色 | 主要职责 | 不应负责 |
|---|---|---|
| Codex Leader | 需求澄清、方案设计、任务拆分、任务卡下发、边界控制、最终验收、MATLAB 全自动验证、Git/文档/Obsidian 同步 | 不把未定义任务直接丢给 Claude；不跳过验收 |
| Claude Code Worker | 严格按 Codex 任务卡改代码、补测试、做局部重构、返回变更摘要 | 自行扩大需求、改变架构决策、启动 COMSOL、删除文档、push GitHub |
| MATLAB | 通过 MCP 或 `matlab.exe -batch` 执行静态检查、测试、manifest 后处理 | 依赖人工命令作为默认路径 |
| COMSOL | 用户本机控制的数据生产边界 | 默认自动化、许可证/认证修复、CI 依赖 |

推荐顺序：

```text
用户目标 -> Codex 拆成任务卡 -> Claude Code 按任务卡实施 -> Claude 返回结果 -> Codex 复核 diff -> Codex 跑全自动 MATLAB -> Codex 判断是否合格 -> Codex 处理 Git/文档/Obsidian
```

一句话规则：

```text
Claude Code 不接“开放式需求”，只接 Codex 下发的 bounded implementation task。
```

---

## 2. Claude Code 当前能力

已配置能力：

- MATLAB MCP Core Server 已注册到 Claude Code。
- Claude Code 可使用 5 个 MATLAB MCP 工具：
  - `detect_matlab_toolboxes`
  - `check_matlab_code`
  - `evaluate_matlab_code`
  - `run_matlab_file`
  - `run_matlab_test_file`
- 已安装 MathWorks MATLAB slash commands：
  - `/matlab-check`
  - `/matlab-run`
  - `/matlab-test`
  - `/matlab-optimize`
  - `/matlab-docs`
  - `/matlab-livescript`
  - 以及其它 MATLAB 辅助命令。
- Codex 侧保留 6 个 MATLAB skills：
  - `matlab-digital-filter-design`
  - `matlab-live-script`
  - `matlab-performance-optimizer`
  - `matlab-test-creator`
  - `matlab-test-execution`
  - `matlab-uihtml-app-builder`

结论：MATLAB 相关 skills 和 MCP 已足够，不建议继续堆安装项。下一步重点是权限收敛和工作流纪律。

---

## 3. Codex 下发给 Claude Code 的任务卡

Codex 给 Claude Code 的任务应使用这种格式：

```text
任务卡 ID：<YYYYMMDD-short-name>

Leader：Codex
Worker：Claude Code

任务：<一句话目标>

只允许修改：
- <file/path/one>
- <file/path/two>

禁止：
- 不要启动 COMSOL、mphstart、ModelUtil 或 comsolmphserver。
- 不要 git add / commit / push。
- 不要删除文件。
- 不要改 docs，除非本任务明确要求。
- 不要发明新的 MATLAB 入口，优先使用 manifest 工作流。

实现要求：
- <具体行为 1>
- <具体行为 2>

Worker 可运行的本地检查：
- <可选局部测试命令>

完成后返回：
- 修改文件列表
- 行为变化摘要
- 已运行的检查
- 未运行检查及原因
```

Claude Code 完成后，Codex 接手：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
```

Codex 验收后只有三种结论：

| 结论 | 含义 | 下一步 |
|---|---|---|
| accept | 变更满足任务卡和验证要求 | Codex 进入文档/Git/Obsidian 流程 |
| revise | 局部问题，需要 Claude 按新任务卡修正 | Codex 下发第二张任务卡 |
| reject | 偏离任务或风险过高 | Codex 回滚或重写方案 |

---

## 4. Worker 权限模式

Claude Code 应采用“worker 权限”，不是“leader/发布权限”。

建议允许：

| 类型 | 建议 |
|---|---|
| 文件读取 | 允许项目内读取 |
| 文件编辑 | 允许项目内代码文件编辑 |
| MATLAB MCP | 允许 `check_matlab_code`、`evaluate_matlab_code`、`run_matlab_test_file` |
| 安全测试 | 允许明确的测试脚本和 `run_full_matlab_automation.ps1` |
| Git 查看 | 允许 `git status`、`git diff`、`git log` |

建议限制：

| 类型 | 原因 |
|---|---|
| `git push` | 应由 Codex 最终验收后再执行 |
| `git add *` / 自动 commit | 容易把输出、缓存或误改文件纳入历史 |
| 任意 `powershell *` | 权限过宽，容易绕过任务边界 |
| `rm` / 删除文档 | 高风险，不应作为默认允许项 |
| COMSOL server / `mphstart` | 不作为默认自动化依赖 |
| `taskkill` | 容易误杀用户进程 |

当前 `.claude/settings.local.json` 中存在一些历史允许项较宽。不要急着直接删除，但长期使用时建议收敛到 worker 边界：Claude 可以写代码，但不负责发布、删除、push 或启动 COMSOL。

---

## 5. MATLAB 自动化边界

默认验证入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1
```

该入口会：

- 自动扫描 manifest。
- 自动运行 CSV-ready MATLAB 后处理。
- 自动生成 `outputs/automation/matlab_full_automation_report.md`。
- 自动跳过缺 CSV 且依赖 COMSOL/LiveLink 的 manifest。

不会：

- 启动 COMSOL。
- 运行 `mphstart`。
- 调试或绕过 COMSOL 许可证。
- 把 COMSOL/LiveLink 当作 CI 或默认无人值守依赖。

---

## 6. 推荐日常模式

### 模式 A：普通代码实现

```text
1. 用户把目标交给 Codex。
2. Codex 产出任务卡，限定文件、行为和验收标准。
3. Claude Code 只按任务卡写代码。
4. Claude Code 返回变更摘要和局部检查结果。
5. Codex 读取 diff 并跑 MATLAB 全自动验证。
6. Codex 决定 accept / revise / reject。
```

### 模式 B：MATLAB 函数开发

```text
1. Codex 指定 MATLAB 函数、输入输出契约和测试要求。
2. Claude Code 写函数和单元测试。
3. Claude Code 可用 /matlab-check 做局部检查。
4. Codex 跑 run_full_matlab_automation.ps1。
5. Codex 决定 accept / revise / reject。
6. Codex 决定是否需要 README/CHANGELOG/Obsidian 同步。
```

### 模式 C：COMSOL 相关任务

```text
1. Codex 判断是否已有 CSV。
2. 有 CSV：进入 MATLAB 自动后处理。
3. 无 CSV：标记 needs_comsol_csv。
4. Claude Code 只能修改脚本或数据契约，不默认运行 COMSOL。
5. 用户本机完成 COMSOL 数据生产后，再由 Codex 自动后处理。
```

---

## 7. 验收标准

每次 Claude Code 实现后，Codex 至少检查：

- `git diff --check`
- `git status --short`
- 相关文件 diff 是否只覆盖任务范围
- MATLAB 全自动报告是否 `failed = 0`
- 是否新增不必要入口、临时脚本或绕过 manifest 的调用
- 是否误触 COMSOL/LiveLink 边界

最终报告以：

```text
outputs/automation/matlab_full_automation_report.md
```

为准。

---

## 8. Obsidian 知识库链接

本项目可同步到 Obsidian 项目目录：

```text
D:\Learning Resources\Obsidian\Archive\物理学术竞赛\Main 13  The Singing Ruler
```

默认采用单向生成方式：

```text
repo docs / automation report -> Obsidian Generated from Repo
```

同步入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync_project_docs_to_obsidian.ps1
```

原则：

- 不覆盖 Obsidian 根目录中的人工笔记，例如“理论模型（终版）.md”“实验方案（终版）.md”“文献研究.md”。
- 生成内容放入 `Generated from Repo` 子目录。
- 生成文件带 front matter，记录来源路径和生成时间。
- Obsidian 人工笔记负责思考和写作；仓库生成文档负责工程事实和自动化报告。
