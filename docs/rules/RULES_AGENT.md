---
audience: agent
agent-priority: high
canonical-rules: true
last-reviewed: 2026-05-03
context-budget: 5KB
agent-summary: "Codex/Claude 分工、权限边界、Git/Obsidian/COMSOL 受控自动化边界、角色操作边界"
---

# Agent 行为规则

<!-- rule-table: RULES_AGENT -->

## R1 角色分工

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| R101 | Codex 负责需求澄清、方案设计、任务拆分、任务卡下发、最终验收、MATLAB 全自动验证、Git/文档/Obsidian 同步 | error | COLLAB §1 |
| R102 | Claude Code 只接 Codex 下发的 bounded implementation task，不接开放式需求 | error | COLLAB §1 |
| R103 | Claude Code 严格按任务卡修改指定文件，不自行扩大范围 | error | COLLAB §3 |
| R104 | Claude Code 完成后返回变更摘要，Codex 做最终验收（accept/revise/reject）| error | COLLAB §3 |

## R2 Worker 操作边界

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| R201 | 不运行 git add / git commit / git push（验收后方可）| error | COLLAB §4 |
| R202 | 不删除文件 | error | COLLAB §4 |
| R203 | 不改 docs/，除非任务卡明确列出文档文件 | error | COLLAB §3 |
| R204 | 不发明新的 MATLAB 入口，优先使用 manifest 工作流 | error | COLLAB §3 |
| R205 | 仅在任务卡明确允许时启动 COMSOL、comsolbatch、comsolmphserver、mphstart、ModelUtil | error | COLLAB §4 |
| R206 | 不配置、修复、绕过或调试 COMSOL 许可证/认证 | error | COLLAB §4 |
| R207 | COMSOL/LiveLink 自动化仅限本机正版离线许可证环境，不进入 GitHub Actions/CI | error | COLLAB §5 |
| R208 | 不运行 taskkill（易误杀用户进程）| warn | COLLAB §4 |

## R3 COMSOL 边界

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| R301 | COMSOL 求解、参数扫描、导出 CSV 可由 Agent 在任务卡授权下本机自动化 | error | AUTOMATION §2 |
| R302 | 无 CSV 的 manifest 必须跳过或快速失败（<1s）| error | AUTOMATION §5 |
| R303 | MATLAB batch 默认优先使用已有 CSV；需要 LiveLink 时必须由任务卡显式授权 | error | AUTOMATION §9 |
| R304 | COMSOL 数据生产仅允许写入项目 outputs/、runtime/ 或任务卡指定路径 | warn | AUTOMATION §1 |

## R4 数据完整性

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| R401 | 不凭空指定基准数据 | error | RUNTARGETS §0 |
| R402 | 不生成合成数据、伪结果或未标注推断结果 | error | RUNTARGETS §0 |
| R403 | 不重用插值或合成频谱补缺失数据 | error | ARCHITECTURE §8 |
| R404 | 优先读取本地已有 outputs/ 数据，不检查不可重跑 | error | RUNTARGETS §0 |
| R405 | 论文/报告类输出必须能追溯到真实 CSV、summary 或 manifest | error | RUNTARGETS §0 |

## R5 Git/Obsidian 同步

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| R501 | Codex 验收后才进入 Git/文档/Obsidian 流程 | error | COLLAB §1 |
| R502 | 单向同步：repo docs/ → Obsidian Generated from Repo/ | error | COLLAB §8 |
| R503 | 不覆盖 Obsidian 项目根目录中的人工笔记（理论模型、实验方案、文献研究等）| error | COLLAB §8 |
| R504 | 同步入口：scripts/sync_project_docs_to_obsidian.ps1 | info | COLLAB §8 |

## R6 任务卡格式

| ID | 规则 | 等级 | 来源 |
|---|---|---|---|
| R601 | Codex 下发任务卡必须包含：ID、Leader、Worker、Goal、Allowed files、Required behavior、Checks | error | COLLAB §3 |
| R602 | 任务卡必须写明"只允许修改"和"禁止"列表 | error | COLLAB §3 |
| R603 | 验收后只有三种结论：accept / revise / reject | error | COLLAB §3 |
