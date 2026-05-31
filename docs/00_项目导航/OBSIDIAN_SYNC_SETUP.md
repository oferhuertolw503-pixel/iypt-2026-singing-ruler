# Obsidian 同步方案 — 跨项目复用

> 将任意项目的文档/数据/源码自动同步到 Obsidian vault

---

## 一、方案原理

Obsidian vault 本质上是一个**普通文件夹**。任何 `.md` 文件放进 vault 目录后，Obsidian 会自动索引、显示双向链接 `[[...]]`、支持全文搜索。

同步策略：**单向复制**（项目 → vault），不修改源文件。

```
项目目录                           Obsidian Vault
├── README.md          ──copy──>    Generated from Repo/
├── docs/reports/*.md  ──copy──>    docs/reports/
├── outputs/*/tables/  ──copy──>    outputs/
├── src/*.java         ──copy──>    src/
└── matlab/*.m         ──copy──>    matlab/
```

## 二、在现有项目中使用

### 2.1 单次手动同步 (最简单)

在项目的 `docs/reports/` 目录中生成 `.md` 文件后：

```powershell
# 把报告文档复制到 Obsidian
cp docs/reports/*.md "D:\Learning Resources\Obsidian\...\Generated from Repo\docs/reports/"
```

### 2.2 使用自动化脚本

1. 复制 `scripts/sync_to_obsidian_generic.ps1` 到你的项目
2. 修改脚本顶部的 `$OBSIDIAN_VAULT` 路径指向你的 vault
3. 根据需要修改 `$syncMap` 数组来指定需要同步的文件
4. 运行：
```powershell
.\scripts\sync_to_obsidian_generic.ps1
```

### 2.3 配置文件格式

脚本的核心是 `$syncMap` 数组，每项指定源和目标：

```powershell
$syncMap = @(
    @{Src = "README.md";              Dst = ""},                # 根目录文件
    @{Src = "docs/reports/*.md";      Dst = "docs/reports/"},  # 用 *.md 匹配全部报告
    @{Src = "outputs/*/tables/*.csv"; Dst = "outputs/"},       # 用 * 匹配子目录
    @{Src = "src/*.java";             Dst = "src/"},
    @{Src = "tools/*.py";             Dst = "tools/"}
)
```

支持的写法：
- `*.md` — 匹配当前目录下所有 markdown 文件
- `**/*.py` — 递归匹配所有 Python 文件
- `outputs/*/tables/*.csv` — 匹配 outputs 下任意子目录的 tables 中的 CSV

## 三、在新项目中初始化

### Step 1: 创建 vault 目录

在 Obsidian vault 中创建项目子目录：

```
<你的 vault>/<项目名>/Generated from Repo/
```

例如我用的结构：
```
D:\Learning Resources\Obsidian\Archive\
  物理学术竞赛\
    Main 13  The Singing Ruler\
      Generated from Repo/    ← 同步目标
```

### Step 2: 复制脚本

```powershell
cp /path/to/scripts/sync_to_obsidian_generic.ps1 <新项目>/scripts/
```

### Step 3: 修改两条配置

编辑脚本顶部：
```powershell
$OBSIDIAN_VAULT = "<你的 vault 完整路径>/<项目名>/Generated from Repo"
```

编辑 `$syncMap`，填入新项目需要同步的文件/目录。

### Step 4: 首次同步

```powershell
.\scripts\sync_to_obsidian_generic.ps1
```

### Step 5 (可选): 每次 git commit 自动同步

在 `.git/hooks/post-commit` 中：
```bash
#!/bin/bash
powershell.exe -File scripts/sync_to_obsidian_generic.ps1
```

## 四、本项目的同步配置

### 已同步内容

| 源 | 目标 (vault 内) | 内容 |
|---|---|---|
| `docs/reports/*.md` | `docs/reports/` | THEORY, PROJECT_CLOSURE, PPT_FINAL_OUTLINE, PPT_SCRIPT, PPT_DATA_TABLES, PPT_MODIFICATION_PLAN, STEEL_GNL_ANALYSIS, MODAL_TYPE_TIMBRE_ANALYSIS, UNIFIED_PACKAGE_CONCLUSION, ppt_review_from_simulation |
| `outputs/unified_v2_4mat/tables/conclusion_master_table.csv` | `outputs/` | 4 材料 73 列结论表 |
| `outputs/unified_v2_4mat/animation/*.gif` | `outputs/` | 钢尺 MATLAB 振动动画 |
| `outputs/steel_gnl_*_v2/tables/*.csv` | `outputs/` | gNL on/off 结论表 |
| `src/Linear_Acoustic_Field_3D_Air.java.template` | `src/` | COMSOL Java 模板 |
| `tools/run_case.py`, `tools/run_requested_full.py` | `tools/` | Python 编排脚本 |
| `matlab/plot/animate_ruler_vibration.m` | `matlab/plot/` | MATLAB 动画脚本 |
| `matlab/extract/analyze_mode_types.m` | `matlab/extract/` | 模态分类分析 |

### Vault 路径

```
D:\Learning Resources\Obsidian\Archive\
  物理学术竞赛\
    Main 13  The Singing Ruler\
      Generated from Repo/
        ├── docs/reports/   ← 全部报告文档
        ├── outputs/        ← 结论表 + 动画
        ├── src/            ← COMSOL 源码
        ├── tools/          ← Python 脚本
        └── matlab/         ← MATLAB 分析脚本
```

### 手动同步命令 (备选)

```powershell
$VAULT = "D:\Learning Resources\Obsidian\Archive\物理学术竞赛\Main 13  The Singing Ruler\Generated from Repo"
$PROJ  = "C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler"

# 同步所有报告
cp "$PROJ\docs\reports\*.md" "$VAULT\docs\reports\"

# 同步动画
cp "$PROJ\outputs\unified_v2_4mat\animation\*.gif" "$VAULT\outputs\unified_v2_4mat\animation\"
```

---

*本方案适用于任何使用 Obsidian 管理项目文档的场景。核心思路：项目负责生成内容，Obsidian 负责展示和链接。*
