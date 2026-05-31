# 尺子之歌 — 文档索引

> 按 PPT 制作流程排序。从上往下读。

---

## 一、PPT 制作（直接使用）

| 顺序 | 文件 | 用途 |
|---|---|---|
| 1 | `PPT_OUTLINE.md` | **大纲** — 50 页 Slide 结构，标注每页 ✅保留/➕新增/📐公式/📊图表 |
| 2 | `PPT_ADDITIONS.md` | **新增内容** — 需插入 PPT 的全部文本、公式、表格、插图名 |
| 3 | `PPT_FORMULAS.md` | **公式速查** — 28 条公式，Eq.1~Eq.28 编号，每条有解说 + LaTeX 代码 |
| 4 | `PPT_DATA_TABLES.md` | **数据表** — 理论/仿真/实验三列，含拟合系数审定和噪声来源 |

---

## 二、理论参考（备查）

| 顺序 | 文件 | 用途 |
|---|---|---|
| 5 | `THEORY_OF_THE_SINGING_RULER.md` | **完整理论框架** — 7 模块推导 + 全量仿真验证表 |
| 6 | `MODAL_TYPE_TIMBRE_ANALYSIS.md` | **模态分类** — z-bending vs in-plane 的完整分析 |
| 7 | `STEEL_GNL_ANALYSIS.md` | **gNL 扫掠** — 钢 5 几何 on/off 对比 |
| 8 | `SUPPLEMENTAL_EXPERIMENTS.md` | **补充实验方案** — 5 项推荐实验的详细步骤 |
| 9 | `PROJECT_CLOSURE.md` | **项目闭环** — 最终数据/结论/未完成项汇总 |

---

## 三、使用流程

```
打开 PPT 原文件 (50页)
  → 对照 PPT_OUTLINE.md 找到需要改的 Slide
    → 打开 PPT_ADDITIONS.md 复制对应 Slide 的:
        叙事文本 → 粘贴到 PPT 文本框
        公式代码 → Alt+= 打开公式框 → LaTeX 模式 → 粘贴 → 回车
        数据表格 → 粘贴到 PPT 表格
        插图文件名 → 从 outputs/ppt_figures/ 拖入 PNG
    → 公式语法有疑问 → 查 PPT_FORMULAS.md
    → 需要完整理论背景 → 查 THEORY_OF_THE_SINGING_RULER.md
```

---

## 四、旧文件（已归档至 `_archive/`）

以下文件已被上方新文件取代，不再维护：
- DERIVED_METRICS_27_CASE_VALIDATION_ZH.md
- LOCAL_PRIVATE_WORKFLOW_ZH.md
- MATERIAL_COMPARISON_AUDIT_ZH.md
- MEDIUM_TIP_DECAY_RERUN_PLAN_ZH.md
- PAPER_ANALYSIS_27_CASE_ZH.md
- PAPER_DRAFT_ABSTRACT_INTRODUCTION_ZH.md
- PAPER_DRAFT_RESULTS_DISCUSSION_ZH.md
- PHYSICS_MECHANISMS_AND_CONCLUSIONS.md
- THEORY_DEDUCTIVE_ANALYSIS_ZH.md
- THEORY_MATLAB_MAINLINE_ZH.md
- TIMBRE_ENHANCED_MEDIUM_ANALYSIS_ZH.md
- TIMBRE_TONE_LOUDNESS_COMPREHENSIVE_REPORT_ZH.md
- UNIFIED_PACKAGE_CONCLUSION.md
