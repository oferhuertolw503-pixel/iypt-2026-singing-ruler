# 仿真项目流水线架构文档

> 适用场景：COMSOL 建模 → MATLAB 后处理的三段式仿真项目
> 本文件描述通用架构，不绑定具体物理模型，可作为同类项目的模板

---

## 0. 整体架构

```
┌──────────────────────────────────────────────────────────────┐
│  Phase 1: Shell 调度层 (PowerShell)                            │
│  scripts/comsol_common.ps1          ← 共享底座（不随模型变化）  │
│  models/<model>/run.ps1             ← 模型入口（每个模型一个）  │
│  models/<model>/config/params.json  ← 参数配置                 │
├──────────────────────────────────────────────────────────────┤
│  Phase 2: 求解层 (Java + COMSOL)                               │
│  models/<model>/src/<Model>.java    ← COMSOL API 模板          │
│  → 注入参数 → comsolcompile.exe → comsolbatch.exe → .mph       │
├──────────────────────────────────────────────────────────────┤
│  Phase 3: 后处理层 (MATLAB)                                     │
│  matlab/run_matlab_manifest.m        ← 入口枢纽                │
│  matlab/core/run_*_pipeline.m        ← 核心流水线               │
│  matlab/extract/  matlab/plot/  matlab/export/                │
│  → CSV + PNG + summary.json + run_manifest.txt                │
└──────────────────────────────────────────────────────────────┘
```

### 核心设计原则

1. **模型与基础设施分离**：每个新模型只需提供 `params.json` + `Java模板` + 可选 `MATLAB后处理`，共享脚本不随模型变化
2. **Manifest 协议交接**：Phase 1 和 Phase 3 通过 JSON 文件交接，不直接互相调用
3. **Quality 档位注入**：参数分为原始输入和求解控制，后者由 Quality 覆盖表统一管理
4. **Canonical output 规范**：所有 case 输出统一目录结构，方便自动发现和汇总

---

## 1. 目录结构

```text
project/
  models/
    <line>/                         ← 模型线（如 linear、nonlinear）
      <model>/                      ← 具体模型
        config/params.json          ← [模型作者提供] 参数定义
        src/<Model>.java            ← [模型作者提供] COMSOL 模板
        run.ps1                     ← [模型作者提供] 入口脚本
        clean.ps1                   ← 清理脚本
        sweep.ps1                   ← 可选：扫参编排
  matlab/
    run_matlab_manifest.m           ← Manifest 入口枢纽
    run_pending_matlab_manifests.m  ← 批量续跑
    run_matlab_manifest_queue.m     ← 队列批量执行
    core/                           ← 共享核心函数
      run_*_pipeline.m              ← 核心流水线
      read_matlab_handoff_manifest.m
      write_matlab_handoff_status.m
      comsol_connect.m / comsol_disconnect.m
      read_json_file.m / write_json_file.m
      ensure_dir.m / parse_physical_scalar.m
      get_output_subdir.m
    extract/                        ← 数据提取函数
    plot/                           ← 绘图函数
    export/                         ← 导出/汇总函数
    tests/                          ← 单元测试
  scripts/
    comsol_common.ps1               ← 共享 PowerShell 底座（核心）
    run_matlab_model.ps1            ← MATLAB handoff 守卫/自动化入口
    prepare_matlab_automation_queue.ps1  ← 队列生成器
    run_full_matlab_automation.ps1  ← 全自动入口
    run_all_tests.ps1               ← Shell 回归测试
    project_housekeeping.ps1        ← 维护清理
  outputs/
    <line>/<model>/                 ← 单次输出
      params_resolved.json
      mph/<model>.mph
      data/*.csv
      figures/*.png
      summary.json / summary.txt / run_manifest.txt
      logs/<model>.log
      logs/<model>_matlab_manifest.json
      logs/<model>_matlab_status.json
    sweeps/<line>/<model>/<sweep_id>/  ← 扫参输出
    automation/                     ← 自动化队列和报告
  runtime/comsol/                   ← [gitignore] 运行时隔离
```

---

## 2. Phase 1：Shell 调度层

### 2.1 共享底座：`scripts/comsol_common.ps1`

这是整个 Shell 层的核心。所有模型入口脚本都 dot-source 它：

```powershell
. (Join-Path $PSScriptRoot "../scripts/comsol_common.ps1")
```

核心函数清单：

| 函数 | 职责 |
|---|---|
| `Get-LinearQualityProfile` | 根据 `coarse/medium/full` 返回时间步、网格数、采样点覆盖值 |
| `New-ResolvedLinearConfig` | 合并 `params.json` + Quality 覆盖 → 写入 `params_resolved.json` |
| `Initialize-CanonicalOutputRoot` | 创建规范输出目录，归档旧结果到 `outputs/history/` |
| `Invoke-ComsolCompile` | 调用 `comsolcompile.exe` 编译 Java |
| `Invoke-ComsolBatch` | 调用 `comsolbatch.exe` 执行 `.class` |
| `Resolve-ComsolBin` | 自动搜索 COMSOL 安装路径 |
| `Resolve-MatlabExe` | 自动搜索 MATLAB 安装路径 |
| `New-CodexMatlabHandoffManifest` | 写 manifest JSON |
| `Write-CodexMatlabStatusFile` | 写 status JSON |
| `Read-JsonFile` / `Write-Utf8NoBomText` | JSON/文本读写 |
| `Invoke-MatlabBatchRobust` | 带重试和修复的 MATLAB batch 调用 |
| `Invoke-TsrModelClean` | 清理模型输出和 runtime |

### 2.2 Quality 覆盖机制

参数分为两类：
- **原始输入参数**：`params.json` 中的几何、材料、激励
- **求解控制参数**：`mesh_numelem`、`time_end`、`time_step`、`mode_points`，由 Quality 档位控制

参数生效顺序：
```text
config/params.json
  → Quality profile 覆盖求解控制参数
  → params_resolved.json（实际生效参数）
  → 注入 Java 模板 __LINEAR_PARAM_BLOCK__
  → comsolcompile → comsolbatch → .mph
```

Quality 覆盖表示例（具体数值可按项目调整）：

| Quality | mesh_numelem | time_end | time_step | mode_points |
|---|---|---|---|---|
| full | 120–160 | 1.0 s | 1e-4 s | 241 |
| medium | 90–120 | 0.5 s | 2e-4 s | 161 |
| coarse | 40–50 | 0.10 s | 1e-3 s | 61–81 |

### 2.3 模型入口脚本模板

新增模型时，`models/<line>/<model>/run.ps1` 通常只需：

```powershell
[CmdletBinding()]
param(
    [ValidateSet("coarse", "medium", "full")]
    [string]$Quality = "full",
    [switch]$SkipMatlabPostprocess
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 加载共享底座
. (Join-Path $PSScriptRoot "../../../scripts/comsol_common.ps1")

# 读取配置
$configPath = Join-Path $PSScriptRoot "config/params.json"
$config = Read-JsonFile -Path $configPath

# Quality 覆盖
$resolvedConfig = New-ResolvedLinearConfig -Config $config -Quality $Quality
$outputRoot = Initialize-CanonicalOutputRoot -ModelRoot $PSScriptRoot -Quality $Quality

# 写入 resolved
Write-Utf8NoBomText -Path (Join-Path $outputRoot "params_resolved.json") `
    -Text ($resolvedConfig | ConvertTo-Json -Depth 10)

# 生成参数注入块
$paramBlock = New-LinearParamBlock -Config $resolvedConfig

# 读取 Java 模板并注入参数
$javaTemplate = Get-Content -Path (Join-Path $PSScriptRoot "src/Model.java") -Raw
$generatedJava = $javaTemplate.Replace("__LINEAR_PARAM_BLOCK__", $paramBlock)

# 写入生成后的 Java
$buildDir = New-BuildArtifactsDir -ModelRoot $PSScriptRoot
$generatedJavaPath = Join-Path $buildDir "generated/Model.java"
Write-Utf8NoBomText -Path $generatedJavaPath -Text $generatedJava

# 编译 + 求解
Invoke-ComsolCompile -JavaPath $generatedJavaPath -OutputDir $buildDir
Invoke-ComsolBatch -ClassDir $buildDir -ClassName "Model" -MphOutput (Join-Path $outputRoot "mph/model.mph")

# 写 MATLAB handoff manifest
New-CodexMatlabHandoffManifest `
    -ManifestPath (Join-Path $outputRoot "logs/model_matlab_manifest.json") `
    -ProjectRoot $repoRoot `
    -EntryFunction "main_model_from_manifest" `
    -OutputRoot $outputRoot `
    -ModelId "model" `
    -MphPath (Join-Path $outputRoot "mph/model.mph") `
    -ConfigPath (Join-Path $outputRoot "params_resolved.json") `
    -Quality $Quality

# MATLAB handoff
if (-not $SkipMatlabPostprocess) {
    & (Join-Path $PSScriptRoot "../../scripts/run_matlab_model.ps1") `
        -ManifestPath (Join-Path $outputRoot "logs/model_matlab_manifest.json")
}
```

---

## 3. Phase 2：求解层（Java + COMSOL）

### 3.1 Java 模板结构

COMSOL 模型树通过 Java API 构建。模板包含：

```java
import com.comsol.model.*;
import com.comsol.model.util.*;

public class Model {
    public static void main(String[] args) {
        model = ModelUtil.create("Model");
        model.label("model.mph");

        // === 1. 组件 ===
        model.component().create("comp1", true);

        // === 2. 参数 ===
        // __LINEAR_PARAM_BLOCK__    ← 此处由 run.ps1 注入

        // === 3. 几何 ===
        // 具体几何构建代码 ...

        // === 4. 物理场 ===
        // 具体物理场构建代码 ...

        // === 5. 网格 ===
        model.component("comp1").mesh().create("mesh1");
        // 网格设置 ...

        // === 6. Study ===
        model.study().create("std1");
        // Eigenfrequency study ...
        model.study().create("std2");
        // Transient study ...

        // === 7. 求解 ===
        model.study("std1").run();
        model.study("std2").run();

        // === 8. 导出 CSV ===
        // 在 Java 端直接导出基础数据，供 MATLAB 跳过 COMSOL 连接
        model.result().export("freq_export").run();
        model.result().export("tip_export").run();
        model.result().export("mode_export").run();

        // === 9. 保存 ===
        model.save(savePath);
    }
}
```

### 3.2 参数注入

模板中保留占位符：
```java
// __LINEAR_PARAM_BLOCK__
```

`run.ps1` 中的 `New-LinearParamBlock` 生成：
```java
model.param().set("L_free", "0.20[m]");
model.param().set("b", "0.03[m]");
model.param().set("h", "0.002[m]");
model.param().set("rho", "7930[kg/m^3]");
// ... 等
```

### 3.3 Java 端直接导出 CSV

关键设计：如果 Java/COMSOL 端已经导出了所有需要的 CSV，MATLAB 后处理可以**跳过 COMSOL LiveLink 连接**，直接读取 CSV 做分析。

这使 MATLAB batch 模式成为可能（不需要 COMSOL LiveLink）。

---

## 4. Phase 3：后处理层（MATLAB）

### 4.1 Manifest 协议

#### manifest JSON 结构

```json
{
    "manifest_version": 1,
    "project_root": "<项目根路径>",
    "matlab_project_root": "<MATLAB代码根路径>",
    "entry_function": "main_model_from_manifest",
    "invoke_style": "manifest_path",
    "output_root": "<输出根路径>",
    "config_path": "<params_resolved.json路径>",
    "mph_path": "<.mph文件路径>",
    "log_path": "<MATLAB日志路径>",
    "status_path": "<MATLAB状态路径>",
    "quality": "coarse",
    "model_line": "linear",
    "model_id": "model"
}
```

#### status JSON 状态机

```json
{
    "status": "pending|running|completed|failed",
    "updated_at": "<时间戳>",
    "manifest_path": "<manifest路径>",
    "message": "<状态说明>",
    "error_report": "<失败时的错误详情>"
}
```

### 4.2 入口枢纽：`run_matlab_manifest.m`

所有 MATLAB 后处理的统一入口：

```matlab
function run_matlab_manifest(manifest_path)
    manifest = read_matlab_handoff_manifest(manifest_path);
    % 设置路径、diary、状态机
    % 根据 manifest.entry_function 和 invoke_style 分发

    switch manifest.invoke_style
        case "manifest_path"
            feval(manifest.entry_function, manifest.manifest_path);
        case "function_args"
            feval(manifest.entry_function, manifest.function_args{:});
    end
end
```

### 4.3 Manifest Wrapper 模式

每个模型需要两个 MATLAB 文件：

**Wrapper** (`main_<model>_from_manifest.m`)：翻译 manifest 字段为函数实参
```matlab
function main_model_from_manifest(manifest_path)
    manifest = read_matlab_handoff_manifest(manifest_path);
    main_model( ...
        manifest.config_path, ...
        manifest.mph_path, ...
        manifest.output_root, ...
        manifest.quality, ...
        manifest.build_wallclock_s);
end
```

**主函数** (`main_<model>.m`)：实际后处理逻辑
```matlab
function main_model(config_path, model_path, output_root, quality, build_s)
    config = read_json_file(config_path);
    % 调用核心流水线
    result = run_beam_model_pipeline(struct( ... ));
    % 写 summary、导出 CSV、绘图
    write_output_metadata(output_root, result);
end
```

### 4.4 离线检测机制

MATLAB 核心流水线中最重要的优化：

```matlab
% 检查 CSV 是否已由 Java/COMSOL 直接导出
offline = try_load_java_exported_result(spec, data_dir, ...);
if offline.available
    return;  % 跳过 COMSOL 连接，直接使用已有 CSV
end

% 如果 CSV 不存在，才连接 COMSOL LiveLink
model = comsol_connect(spec.model_path);
```

这使 MATLAB batch 模式可以处理所有**已有 CSV 数据**的 case。

### 4.5 MATLAB 自动化边界

| 场景 | batch 可用？ | 说明 |
|---|---|---|
| 已有 CSV 的 manifest | 是 | 跳过 COMSOL，纯后处理 |
| 无 CSV 的 manifest | 否 | 需交互式 MATLAB 连接 COMSOL |
| sweep 后处理聚合 | 是 | 各 case 已有 CSV |

`run_matlab_model.ps1` 会在 PowerShell 层面预检 CSV 完整性，缺 CSV 时**快速失败**（<1 秒），不再触发 MATLAB 崩溃重试。

---

## 5. 全自动入口

### 5.1 `run_full_matlab_automation.ps1`

一次性运行所有可自动处理的 manifest：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_full_matlab_automation.ps1 `
  -ManifestRoot outputs -MaxQueued 10
```

内部流程：
```text
1. 扫描 outputs/ 下所有 *_matlab_manifest.json
2. 按模型类型匹配所需 CSV 列表
3. 检查 CSV 是否存在
4. 分类：queued / already_completed / needs_comsol_csv / unknown
5. 对 queued 的 manifest，单次 matlab -batch 批量执行
6. 生成 full_automation_report.md
```

### 5.2 单个 manifest 执行

```powershell
# 有 CSV — 直接 batch
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath <manifest.json>

# 无 CSV — 需要加 -AllowComsolLiveLink（且需要 COMSOL 服务器在线）
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath <manifest.json> -AllowComsolLiveLink -LocalComsolPort 2038
```

---

## 6. 新增模型检查清单

要新增一个模型（如 `nonlinear/large_deflection`），需完成以下步骤：

### 6.1 模型定义
- [ ] `models/<line>/<model>/config/params.json` — 参数配置
- [ ] `models/<line>/<model>/src/<Model>.java` — COMSOL 模板（预留 `__LINEAR_PARAM_BLOCK__`）
- [ ] `models/<line>/<model>/run.ps1` — 入口脚本（dot-source `comsol_common.ps1`）
- [ ] `models/<line>/<model>/clean.ps1` — 清理脚本

### 6.2 MATLAB 后处理
- [ ] `matlab/main_<model>.m` — 主后处理函数
- [ ] `matlab/main_<model>_from_manifest.m` — Manifest wrapper
- [ ] 在 `run_matlab_manifest.m` 中确认 dispatch 逻辑已覆盖

### 6.3 自动化队列注册
- [ ] 在 `run_matlab_model.ps1` 的 `Get-ManifestRequiredCsvPaths` 中添加该 entry_function 的 CSV 需求
- [ ] 在 `prepare_matlab_automation_queue.ps1` 中确认扫描逻辑覆盖

### 6.4 测试
- [ ] Shell build-only 测试（`-SkipMatlabPostprocess`）
- [ ] CSV 完整时 batch 模式测试
- [ ] 全自动脚本队列生成测试

---

## 7. 关键文件速查

| 文件 | 角色 | 是否随模型变化 |
|---|---|---|
| `scripts/comsol_common.ps1` | Shell 共享底座 | 否 |
| `scripts/run_matlab_model.ps1` | MATLAB handoff 守卫 | 仅需注册新 entry_function |
| `scripts/run_full_matlab_automation.ps1` | 全自动入口 | 否 |
| `scripts/prepare_matlab_automation_queue.ps1` | 队列生成器 | 否 |
| `models/<model>/config/params.json` | 参数配置 | **是** |
| `models/<model>/src/<Model>.java` | COMSOL 模板 | **是** |
| `models/<model>/run.ps1` | 模型入口 | **是** |
| `matlab/run_matlab_manifest.m` | MATLAB 入口枢纽 | 否 |
| `matlab/main_<model>.m` | MATLAB 后处理 | **是** |
| `matlab/main_<model>_from_manifest.m` | Manifest wrapper | **是** |
| `matlab/core/run_*_pipeline.m` | 核心流水线 | 按需调整 |
| `matlab/extract/` `plot/` `export/` | 提取/绘图/导出 | 否 |

---

## 8. 不可违反的规则

```text
1. 不凭空指定基准数据。以已有 CSV 和 summary 为准。
2. 不在没有检查 outputs/ 的情况下重跑。
3. 不用插值或合成频谱补缺失数据。
4. COMSOL/LiveLink 不作为默认自动化依赖。
5. 不把 matlab.exe 作为"启动器"。所有 MATLAB 调用走 manifest。
6. 不把非线性结果混入线性主线。
7. 有 CSV → batch 可用；无 CSV → 快速失败 + 提示用户。
```
