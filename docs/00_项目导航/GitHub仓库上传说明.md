---
audience: agent
agent-priority: low
last-reviewed: 2026-05-02
context-budget: 3KB
agent-summary: "Git/GitHub/Obsidian 同步说明。远程仓库配置、上传范围、排除规则、同步方向"
---

# Git/GitHub/Obsidian 同步说明

> Git 操作边界见 `docs/rules/RULES_AGENT.md`。
> Claude Code 不执行 git push——该操作由 Codex 验收后执行。

---

## 1. 远程仓库

| 项目 | 值 |
|---|---|
| 远程 | `origin` |
| URL | `git@github.com:oferhuertolw503-pixel/the_singing_ruler.git` |
| 认证 | SSH（HTTPS 在中国大陆不可用）|
| SSH 密钥 | `~/.ssh/id_ed25519.pub` 已添加到 GitHub Settings |

## 2. 上传内容

仓库跟踪活跃源码和文档，运行产物被 .gitignore 排除：

| 跟踪 | 目录 |
|---|---|
| 是 | matlab/, models/, scripts/, docs/, tools/, .vscode/, .github/ |
| 否 | outputs/, runtime/, \*.mph, \*.pptx, \*.pdf, \*.class |

首次提交约 1596 个文件 / 6.8MB。

## 3. Obsidian 同步

方向：**单向** — repo `docs/` → Obsidian `Generated from Repo/`

```text
repo docs/ + outputs/automation/report
  → sync_project_docs_to_obsidian.ps1
  → D:\Learning Resources\Obsidian\Archive\物理学术竞赛\
     Main 13  The Singing Ruler\Generated from Repo\
```

同步入口：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\sync_project_docs_to_obsidian.ps1
```

原则：
- 不覆盖 Obsidian 人工笔记（理论模型、实验方案、文献研究等）
- 生成文件带 front matter（来源路径和生成时间）
- Obsidian 笔记负责思考和写作；仓库文档负责工程事实
