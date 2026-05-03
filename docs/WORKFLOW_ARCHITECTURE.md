---
audience: agent
agent-priority: medium
last-reviewed: 2026-05-02
context-budget: 8KB
agent-summary: "通用流水线架构文档。Phase 1 Shell 调度 → Phase 2 COMSOL 求解 → Phase 3 MATLAB 后处理。Manifest 协议交接、目录结构、新增模型检查清单"
---

# 流水线架构

> 本文档描述通用流水线接口。当前项目具体状态见 `docs/PROJECT_RUN_TARGETS.md`。
> MATLAB 调用规则见 `docs/rules/RULES_MATLAB.md`，输出规范见 `docs/rules/RULES_OUTPUT.md`。

---

## 1. 整体架构

```
┌─ Phase 1: Shell 调度层 (PowerShell) ──────────────────────┐
│  scripts/comsol_common.ps1    ← 共享底座（不随模型变化）      │
│  models/<model>/run.ps1       ← 模型入口（每个模型一个）      │
│  models/<model>/config/params.json ← 参数配置                │
├─ Phase 2: 求解层 (Java + COMSOL) ──────────────────────────┤
│  models/<model>/src/Model.java ← 模板（含 __LINEAR_PARAM_BLOCK__）│
│  → comsolcompile → comsolbatch → .mph                       │
├─ Phase 3: 后处理层 (MATLAB) ────────────────────────────────┤
│  matlab/run_matlab_manifest.m ← 入口枢纽                    │
│  matlab/core/run_*_pipeline.m ← 核心流水线                  │
│  matlab/extract/ plot/ export/                              │
│  → CSV + PNG + summary.json                                 │
└─────────────────────────────────────────────────────────────┘
```

核心设计原则：

1. **模型与基础设施分离** — 共享脚本不随模型变化
2. **Manifest 协议交接** — Phase 1 ↔ Phase 3 通过 JSON 文件交接
3. **Quality 档位注入** — 求解控制参数由 Quality 覆盖表统一管理
4. **Canonical output 规范** — 统一目录结构，支持自动发现

## 2. 目录结构

```
project/
  models/<line>/<model>/
    config/params.json         ← [模型作者] 参数定义
    src/Model.java             ← [模型作者] COMSOL 模板
    run.ps1                    ← [模型作者] 入口脚本
    sweep.ps1                  ← 可选：扫参编排
  matlab/
    run_matlab_manifest.m      ← Manifest 入口枢纽
    core/                      ← 共享核心函数
    extract/ plot/ export/     ← 职责分离模块
    tests/                     ← 单元测试
  scripts/
    comsol_common.ps1          ← 共享 PowerShell 底座
    run_matlab_model.ps1       ← MATLAB handoff 守卫
    run_full_matlab_automation.ps1 ← 全自动入口
  outputs/
    <line>/<model>/            ← 单次输出
      params_resolved.json, mph/, data/, figures/,
      summary.json, logs/
    sweeps/<line>/<model>/     ← 扫参输出
    automation/                ← 自动化队列和报告
```

## 3. Phase 1：Shell 调度层

**共享底座** `scripts/comsol_common.ps1` 提供：

| 函数 | 职责 |
|---|---|
| Get-LinearQualityProfile | 返回 quality 覆盖值 |
| New-ResolvedLinearConfig | 合并 params.json + Quality |
| Initialize-CanonicalOutputRoot | 创建规范输出目录 |
| Invoke-ComsolCompile | 调用 comsolcompile.exe |
| Invoke-ComsolBatch | 调用 comsolbatch.exe |
| New-CodexMatlabHandoffManifest | 写 manifest JSON |
| Invoke-MatlabBatchRobust | 带重试的 MATLAB batch |

**Quality 覆盖：**

| Quality | mesh_numelem | time_end | time_step | mode_points |
|---|---|---|---|---|
| full | 120–160 | 1.0 s | 1e-4 s | 241 |
| medium | 90–120 | 0.5 s | 2e-4 s | 161 |
| coarse | 40–50 | 0.10 s | 1e-3 s | 61–81 |

## 4. Phase 2：求解层（Java + COMSOL）

Java 模板结构：

```java
public class Model {
    public static void main(String[] args) {
        model = ModelUtil.create("Model");
        // __LINEAR_PARAM_BLOCK__   ← run.ps1 注入参数
        // 几何、物理场、网格、Study 定义
        // Java 端直接导出 CSV（供 MATLAB 离线使用）
        model.result().export("freq_export").run();
        model.result().export("tip_export").run();
        model.save(savePath);
    }
}
```

关键设计：Java 端直接导出 CSV → MATLAB 可跳过 COMSOL LiveLink 连接（实现 batch 模式的关键）。

## 5. Phase 3：后处理层（MATLAB）

**Manifest 协议：**

- `manifest.json` 包含：entry_function, output_root, config_path, mph_path, quality, model_line, model_id
- `status.json` 状态机：pending → running → completed / failed
- 入口枢纽：`run_matlab_manifest.m` 统一分发
- 每个模型需要：`main_<model>.m` + `main_<model>_from_manifest.m`

**离线检测：** MATLAB 核心流水线先检查 CSV 是否已存在；有则跳过 COMSOL 连接，无才尝试 LiveLink。

## 6. 新增模型检查清单

- [ ] models/\<line>/\<model>/config/params.json
- [ ] models/\<line>/\<model>/src/Model.java
- [ ] models/\<line>/\<model>/run.ps1
- [ ] matlab/main_\<model>.m + main_\<model>_from_manifest.m
- [ ] 在 run_matlab_model.ps1 注册 entry_function 的 CSV 依赖
- [ ] 在 prepare_matlab_automation_queue.ps1 确认覆盖
- [ ] Shell build-only 测试（-SkipMatlabPostprocess）
- [ ] CSV 完整时 batch 模式测试

## 7. 不可违反的规则

1. 不凭空指定基准数据。以已有 CSV 和 summary 为准。
2. 不在没有检查 outputs/ 的情况下重跑。
3. 不用插值或合成频谱补缺失数据。
4. COMSOL/LiveLink 不作为默认自动化依赖。
5. 不把 matlab.exe 作为"启动器"。所有 MATLAB 调用走 manifest。
6. 不把非线性结果混入线性主线。
7. 有 CSV → batch 可用；无 CSV → 快速失败 + 提示用户。
