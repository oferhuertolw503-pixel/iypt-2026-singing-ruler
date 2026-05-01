# GitHub 仓库上传说明

## 仓库地址

**https://github.com/oferhuertolw503-pixel/the_singing_ruler**

SSH: `git@github.com:oferhuertolw503-pixel/the_singing_ruler.git`

## 上传内容

首次提交包含 **1596 个文件**，约 **6.8MB**，仅包含活跃源码和文档：

| 目录 | 内容 |
|---|---|
| `matlab/` | MATLAB 后处理流水线（主函数、核心流水线、提取/绘图/导出函数、单元测试） |
| `models/linear/` | 线性模型源码（Java COMSOL 模板、params.json 配置、PowerShell 入口） |
| `models/nonlinear/` | 非线性大振幅 Duffing 分析模型 |
| `scripts/` | PowerShell 调度脚本、Python 绘图与辅助工具 |
| `docs/` | 技术文档（.md 格式，不含 .pdf 和 .pptx） |
| `tools/` | MATLAB 官方工具链（MCP server、slash-commands、prompts） |
| `.vscode/` | VS Code 编辑器配置 |
| `.github/` | GitHub AI prompts |
| `PACKAGE_README.md` | 3D 空气域输出说明 |

## 已排除的内容（通过 .gitignore）

| 目录/文件 | 原因 | 大小 |
|---|---|---|
| `outputs/` | COMSOL/MATLAB 运行产物（.mph、CSV、PNG、summary） | ~12GB |
| `runtime/` | COMSOL/MATLAB 运行时隔离目录，每次运行自动重建 | ~1.4GB |
| `the_singing_ruler_solver_package/` | 与主项目重复的打包副本 | ~40MB |
| `*.pptx` | PowerPoint 演示文稿 | ~90MB |
| `*.pdf` | PDF 文献与文档 | ~50MB |
| `*.mph` | COMSOL 二进制模型文件（每个 3-15MB 不等） | — |
| `*.class` / `*.class.status` | Java 编译产物 | — |
| `models/**/artifacts/` | COMSOL 构建产物（生成的 .java 和 .class） | — |
| `__pycache__/` | Python 字节码缓存 | — |
| `.codex_tmp/` | Codex 临时目录 | — |
| `debug.log` | 临时调试日志 | — |

## .gitignore 文件内容

```gitignore
# Run outputs (12GB+)
outputs/

# Runtime isolation (1.4GB+, regenerated on each run)
runtime/

# Duplicate package
the_singing_ruler_solver_package/

# Presentations and PDFs
*.pptx
*.pdf
ppt/

# COMSOL model files (large binaries)
*.mph

# Java build artifacts
*.class
*.class.status
models/**/artifacts/

# Python cache
__pycache__/
*.pyc

# Temporary / IDE
.codex_tmp/
debug.log

# Office temp files
~$*

# MATLAB temp
*.m~
*.asv

# OS files
Thumbs.db
.DS_Store
```

## 后续推送流程

```powershell
# 1. 添加修改的文件
git add .

# 2. 提交
git commit -m "<描述本次改动>"

# 3. 推送
git push
```

## 首次上传配置记录

```powershell
# 初始化
git init

# 远程仓库（最终使用 SSH）
git remote add origin git@github.com:oferhuertolw503-pixel/the_singing_ruler.git

# 首次推送
git push -u origin main
```

## 注意事项

- **HTTPS 不可用**：中国大陆网络环境 GitHub HTTPS 被阻断，须使用 SSH 方式连接。
- **SSH 密钥**：确保 `~/.ssh/id_rsa.pub`（或 `id_ed25519.pub`）已添加到 GitHub Settings > SSH and GPG keys。
- **不要提交大文件**：GitHub 单文件限制 100MB，仓库总大小限制 1GB。运行产物务必保持在 `outputs/` 目录（已在 .gitignore 中排除）。
- **Outputs 本地保留**：`outputs/` 不会被 git 跟踪，但仍在本地磁盘上，不会被删除。
