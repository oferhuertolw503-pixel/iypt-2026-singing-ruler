---
audience: agent
agent-priority: high
last-reviewed: 2026-05-03
context-budget: 5KB
agent-summary: "Codex leader + Claude Code worker 执行协议。任务卡格式、验收标准、权限边界。详细规则见 docs/rules/RULES_AGENT.md"
---

# Codex + Claude Code 执行协议

> 详细 Agent 行为规则见 `docs/rules/RULES_AGENT.md`。
> 本文档为执行协议的详细解释，不作为第一条约束来源。

---

## 1. 角色分工

| 角色 | 职责 | 不应负责 |
|---|---|---|
| Codex Leader | 需求澄清、方案设计、任务拆分、任务卡下发、边界控制、最终验收、MATLAB 全自动验证、Git/文档/Obsidian 同步 | 不把未定义任务直接丢给 Claude；不跳过验收 |
| Claude Code Worker | 严格按 Codex 任务卡改代码、补测试、做局部重构、返回变更摘要；在任务卡明确授权时运行本机 COMSOL 自动化 | 自行扩大需求、改变架构决策、未授权启动 COMSOL、删除文档、push GitHub |

推荐执行顺序：

```text
用户目标 → Codex 拆成任务卡 → Claude Code 按任务卡实施 →
Claude 返回结果 → Codex 复核 diff → Codex 跑全自动 MATLAB →
Codex 判断是否合格 → Codex 处理 Git/文档/Obsidian
```

## 2. 任务卡格式

```text
任务卡 ID：<YYYYMMDD-short-name>

Leader：Codex
Worker：Claude Code

任务：<一句话目标>

只允许修改：
- <file/path/one>
- <file/path/two>

禁止：
- 不要启动 COMSOL，除非任务卡明确列出允许的 COMSOL 脚本或命令
- 不要 git add / commit / push
- 不要删除文件
- 不要改 docs，除非本任务明确要求

实现要求：
- <具体行为>

完成后返回：
- 修改文件列表
- 行为变化摘要
- 已运行的检查
- 未运行检查及原因
```

## 3. 验收标准

验收后只有三种结论：

| 结论 | 含义 | 下一步 |
|---|---|---|
| accept | 变更满足任务卡和验证要求 | Codex 进入文档/Git/Obsidian 流程 |
| revise | 局部问题，需要修正 | Codex 下发第二张任务卡 |
| reject | 偏离任务或风险过高 | Codex 回滚或重写方案 |

Codex 至少检查：

- `git diff --check`
- `git status --short`
- diff 是否只覆盖任务范围
- MATLAB 全自动报告是否 `failed = 0`
- COMSOL/LiveLink 是否只在任务卡授权范围内运行

## 4. 权限边界

详见 `docs/rules/RULES_AGENT.md`：

- Codex 独占：Git 推送、Obsidian 同步、最终验收、全自动 MATLAB
- Claude Code 独占：按任务卡修改代码、局部测试
- 谁都不可默认：修许可证、绕过认证、批量 git add、未授权启动 COMSOL
- 可显式授权：本机正版离线许可证环境下的 `comsolbatch`、`comsolmphserver`、LiveLink/MATLAB 工作流
