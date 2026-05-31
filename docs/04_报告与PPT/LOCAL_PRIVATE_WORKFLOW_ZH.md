# 本机私密工作流说明

> 本机优先：本地运行产物和数据不入 Git，只同步代码和文档。
> 更新日期：2026-05-03

---

## 1. 原则

1. **本机运行是最高优先级** — 所有 COMSOL 求解、MATLAB 后处理、图片生成都在本机完成。
2. **GitHub 是代码和文档的私密备份** — 不承载 `outputs/`、视频、运行时配置或大型二进制产物。
3. **`outputs/` 永远不入 Git** — `.gitignore` 已排除，所有派生指标、CSV、PNG、MPH 只存本地。
4. **视频素材不入 Git** — `*.mp4` 已加入 `.gitignore`，如需版本管理建议移至本地素材目录。

---

## 2. Git 边界

| 内容 | 入 Git | 说明 |
|---|---|---|
| `matlab/` | **是** | 所有 MATLAB 代码 |
| `models/` | **是** | COMSOL Java 模板和 run.ps1 |
| `scripts/` | **是** | PowerShell 自动化脚本 |
| `docs/` | **是** | 规则、架构、报告（含中文） |
| `.github/` | **是** | Codex 任务卡模板 |
| `.vscode/` | **是** | 编辑器配置 |
| `tools/` | **是** | 工具脚本 |
| **`outputs/`** | **否** | 大数据产物 (12 GB+) |
| **`runtime/`** | **否** | 运行时隔离目录 (1.4 GB) |
| **`*.mph`** | **否** | COMSOL 二进制模型文件 |
| **`*.pptx` / `*.pdf`** | **否** | 演示和 PDF |
| **`*.mp4`** | **否** | 视频素材（本机素材目录） |
| **`.claude/settings.local.json`** | **否** | 本机个人权限配置 |

---

## 3. COMSOL 运行边界

| 场景 | 状态 | 条件 |
|---|---|---|
| 新仿真求解 | ✅ 可运行 | 本机正版离线许可证 + 任务卡明确授权 |
| 已存在 CSV 时重复求解 | ❌ 不重跑 | 优先使用已有 CSV |
| 生成 tip_timeseries.csv | ✅ 已在 Java 模板中 | 修改 `Linear_Acoustic_Field_3D_Air.java` |
| 许可证配置/修复/绕过 | ❌ 永远不碰 | 不在任何文档、脚本或对话中处理 |
| CI / GitHub Actions 上运行 COMSOL | ❌ 永远不碰 | COMSOL 仅限本机交互式或 batch 运行 |

---

## 4. Obsidian 同步规则

方向：**单向** — 仓库 `docs/` → Obsidian vault `Generated from Repo/`

| 内容 | 同步 | 说明 |
|---|---|---|
| `docs/reports/*.md` | **是** | 所有报告进入 vault |
| `docs/rules/*.md` | **是** | 规则文档 |
| `docs/*.md` | **是** | 顶层文档 |
| `outputs/` 内 CSV/PNG | **否** | 大数据不入 Git 不 Obsidian |
| Obsidian 个人笔记 | **否** | 不反向覆盖 |


## 5. 数据存储位置

| 数据类型 | 路径 | 大小 | 版本管理 |
|---|---|---|---|
| 27 case coarse 派生指标 + 图表 | `outputs/requested_3d_air_coarse_review_light/` | ~1 GB | 本地 |
| Medium 补算 (5 case) | `outputs/requested_medium_tip_decay_validation/` | ~2 GB | 本地 |
| 论文图表 | 同上 `figures/paper_analysis/` | < 1 MB | 本地 |
| 论文分析表格 | 同上 `tables/paper_analysis/` | < 10 KB | 本地 |
| Code 和 docs | 仓库根目录 | ~7 MB | **Git** |

---

## 6. 日常操作备忘

### 提交前检查

```bash
git status --short          # 确认只有预期文件变更
git diff --check            # 确认无 trailing whitespace
```

不应出现：`outputs/`、`*.mp4`、`*.mph`、`*.pptx`、`.claude/settings.local.json`

### 同步 Obsidian

```powershell
cd repo-root
powershell -ExecutionPolicy Bypass -File .\scripts\sync_docs_to_obsidian_one_way.ps1
```

### 运行 COMSOL 补算

```powershell
# 只有代码变更（Java 模板 / run.ps1）后的首次运行才需要；
# 已有 CSV 时直接跑 MATLAB 即可。
powershell -ExecutionPolicy Bypass -File .\models\linear\acoustic_field_3d_air\run.ps1 `
  -Quality medium `
  -OutputRoot outputs\requested_medium_tip_decay_validation\<case_id>
```
