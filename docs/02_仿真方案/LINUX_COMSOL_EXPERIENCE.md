# Linux 服务器 COMSOL 使用经验

> 更新: 2026-05-16 | 服务器: `user@<your-linux-server>` | COMSOL 6.1

---

## 1. 服务器环境

| 项目 | 详情 |
|---|---|
| OS | Ubuntu 20.04, x86_64, kernel 5.15 |
| CPU | 256 核 (AMD EPYC 64C × 4 路) |
| RAM | 503 GB |
| Java | OpenJDK 11.0.27 |
| COMSOL | 6.1.0.252, 安装于 `/disk/home/zhangzhenlei/Comsol/comsol61/` |
| License | uncounted (不限核/不计数), 全模块 |
| MATLAB | 无（服务器不安装，后处理在本地 Windows MATLAB R2025a 做） |

### 全模块列表

ACDC, Acoustics, AC/DC, Batteries, CFD, Chemical Reaction, Composite Materials, Corrosion, ECAD, Electrodeposition, EM, Fatigue, Geomechanics, Heat Transfer, MEMS, **Microfluidics**, Mixer, Molecular Flow, Multibody Dynamics, Nonlinear Structural Materials, Optics, Optimization, Particle Tracing, Pipe Flow, Plasma, Ray Optics, RF, Semiconductor, **Structural Mechanics**, Subsurface Flow, Wave Optics, 以及 LiveLink for MATLAB/Excel/SolidWorks 等。

---

## 2. 连接与文件传输

### SSH 连接

```bash
ssh user@<your-linux-server>
```

Windows 终端用 PowerShell 或 WSL 均可。免密登录需配置 SSH key：

```powershell
# 生成密钥（若没有）
ssh-keygen -t ed25519
# 上传公钥
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh user@<your-linux-server> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

### 文件上传

```bash
# 上传整个包
scp -r <local_dir> user@<your-linux-server>:~/comsol_work/the_singing_ruler/<remote_dir>

# 仅上传修改的 Python 文件
scp tools/run_requested_full.py user@<your-linux-server>:~/comsol_work/the_singing_ruler/the_singing_ruler_full_server_source/tools/
```

### 结果下载

```bash
# 打包（排除 mph 大文件，只看 CSV）
ssh user@<your-linux-server> "cd ~/comsol_work/the_singing_ruler/the_singing_ruler_full_server_source/outputs/<study_id> && tar -czf /tmp/result.tar.gz --exclude='*.mph' --exclude='*/logs/*' cases/ *.csv *.json"

# 下载
scp user@<your-linux-server>:/tmp/result.tar.gz .
```

> **注意**: mph 文件每个约 1-4 GB，除非需要重新求解或修改模型，否则只下载 CSV 即可。

---

## 3. COMSOL 命令行工作流

### 核心三阶段

```
Java 模板 + JSON 配置 → comsol compile → Java .class → comsol batch → CSV / mph
```

### 3.1 编译 Java 模型

```bash
cd ~/comsol_work/the_singing_ruler/the_singing_ruler_full_server_source

# 编译单个 case
/disk/home/zhangzhenlei/Comsol/comsol61/multiphysics/bin/comsol compile \
  -configuration runtime/<study_id>/<case_id>/cfg \
  -data runtime/<study_id>/<case_id>/data \
  -prefsdir runtime/<study_id>/<case_id>/prefs \
  -recoverydir runtime/<study_id>/<case_id>/recoveries \
  -tmpdir runtime/<study_id>/<case_id>/tmp \
  -outputfile outputs/<study_id>/cases/<group>/<case_id>/mph/linear_acoustic_field_3d_air.mph \
  -classpath runtime/<study_id>/<case_id>/build/generated \
  -inputfile runtime/<study_id>/<case_id>/build/generated/Linear_Acoustic_Field_3D_Air.class \
  -batchlog outputs/<study_id>/cases/<group>/<case_id>/logs/linear_acoustic_field_3d_air.log \
  src/Linear_Acoustic_Field_3D_Air.java.template
```

> **关键**: compile 阶段只是 Java 编译 + 模型构建，**不做求解**。模型保存在 mph 文件中。

### 3.2 批量求解

```bash
/disk/home/zhangzhenlei/Comsol/comsol61/multiphysics/bin/comsol -np 12 batch \
  -inputfile runtime/<study_id>/<case_id>/build/generated/Linear_Acoustic_Field_3D_Air.class \
  ...
```

> **`-np N`**: 指定求解器使用的 CPU 核心数。N 越大越快，但内存占用也大。

### 3.3 三步实质

| 阶段 | 命令 | 产出 | 耗时占比 |
|---|---|---|---|
| `compile` | `comsol compile` | .mph (模型构建) | ~3% |
| `batch` | `comsol -np N batch` | 求解结果写入 .mph | ~95% |
| `export` | Java 内 `exportAllData()` | CSV 文件 | ~2% |

整个流程由 Python 脚本 `run_case.py` 自动编排，不需要手动执行上述命令。

---

## 4. 并行策略

### 4.1 单 case 内并行 (`-np`)

```bash
comsol -np 12 batch ...   # 12 核求解一个 case
```

- 12 核约 1196% CPU，单个 case ~25min (fast 质量)
- 24 核并不能快一倍，因为并行效率递减
- 推荐 12 核：性价比较高，核数适中

### 4.2 多 case 并行 (`ThreadPoolExecutor`)

```python
# run_requested_full.py
with ThreadPoolExecutor(max_workers=5) as executor:
    # 5 个 case 同时跑，每个 12 核 = 60 核总占用
```

- 5 case × 12 核 = 60 核，墙时 ~25min
- 串行跑：5 × 25 = 125min
- 服务器 256 核绰绰有余

### 4.3 推荐并行度

| 场景 | max_workers | comsol_np | 总核数 | 适用 |
|---|---|---|---|---|
| 快速验证 | 1 | 12 | 12 | 单 case smoke |
| 中等批量 | 5 | 12 | 60 | 5-10 case |
| 大批量 | 8 | 8 | 64 | 27 case |

---

## 5. 质量档位与耗时

### 5.1 六档质量

| 档位 | time_end | time_step | numelem | 特性 | 墙时(12核) |
|---|---|---|---|---|---|
| `eco` | 0.10s | 2e-5 | 1000 | 只用 eigenvalue + 短瞬态 | ~4min |
| `coarse` | 0.25s | 5e-5 | 2000 | 振幅用，粗网格 | ~10min |
| `fast` | 0.40s | 4e-5 | 4000 | 频率+衰减分析 | ~25min |
| `medium` | 0.50s | 3e-5 | 6000 | 平衡精度 | ~45min |
| `full` | 0.60s | 2e-5 | 10000 | 最高精度 | ~3h |
| `decay` | 1.00s | 4e-5 | 4000 | 长窗口，衰减专用 | ~60min |

### 5.2 自适应质量

不同参数对分辨率的需求不同：

```python
ADAPTIVE_QUALITY = {
    "material":  "fast",   # E 影响频率和衰减 → 需精度
    "L_free":    "fast",   # f ∝ 1/L² → 需精度
    "h":         "fast",   # f ∝ h → 需精度
    "b":         "eco",    # 宽度几乎不影响 f → 低精度即可
    "J":         "eco",    # 冲量仅影响振幅 → 低精度即可
    "x0_ratio":  "eco",    # 撞击位置仅影响振幅 → 低精度即可
}
```

27 case 全跑 fast 需 ~11h，自适应仅需 ~3h。

---

## 6. 常见坑与解决方案

### 6.1 `evaluate()` 类型问题 (6.1 特有)

COMSOL 6.1 的 Java API 中 `model.param().evaluate("param_name")` **返回 double**，不是 String。不能用它读取逗号分隔的字符串参数。

```java
// ❌ 错误 — 6.1 返回 double，报类型错
String distances = model.param().evaluate("mic_distances_from_surface_m");
// "0.02,0.04,0.06,0.10" 无法被 parseDouble

// ✅ 正确 — 在 Java 中硬编码或用 JSON 配置
double[] distances = {0.02, 0.04, 0.06, 0.08, 0.10};
```

### 6.2 eigen_shift 位置决定哪些模态被找到

```java
// ❌ 错误 — 找离 1000Hz 最近的 6 个模态
model.study("std1").feature("eig").set("shift", "1000[Hz]");
// 对于长尺/薄尺/低 E 材料，基频仅 20-80Hz
// → COMSOL 返回的是模态 7-12，漏掉 1-6！

// ✅ 正确 — 从 1Hz 开始搜索
model.study("std1").feature("eig").set("shift", "1[Hz]");
```

**教训**: 永远设 `eigen_shift=1[Hz]`，不要用大值。

### 6.3 compile 输出 0 字节 = Java 编译错误

`comsol compile` 成功后生成 .mph，但如果 Java 代码有编译错误，**mph 文件可能是 0 字节或不存在，且不报错**。

排查：查看 `batchlog` 文件，或在 compile 前用 `javac` 检查语法。

### 6.4 参数覆盖未被应用（沉默失败）

Python 的 `make_case_overrides()` 修改了 config dict，但如果 `run_case.py` 中的 `resolve_config()` 没有正确合并 overrides，**参数会回退到 base config 的值**。

验证方法：求解完成后检查 `params_resolved.json`：
```bash
cat outputs/<study_id>/cases/.../data/params_resolved.json | grep -E '"J"|"zeta"'
```

### 6.5 用户 kdd 权限

kdd 用户属于 `kdd` 组，COMSOL 安装在 `zhangzhenlei` 用户目录下。需要确认：
- `/disk/home/zhangzhenlei/Comsol/comsol61/` 对 kdd 有读+执行权限
- COMSOL 临时文件写入在 kdd 自己的 home 目录（由 `-tmpdir`, `-prefsdir` 指定）

### 6.6 macOS/Windows 文件编码

从 Windows 上传 .py/.java 到 Linux：
```bash
# ❌ 避免 — 可能引入 CRLF
scp file.py server:/path/

# ✅ 正确 — 确保 LF 换行
dos2unix file.py   # 在上传前或上传后转换
```

---

## 7. Python 编排脚本要点

### 7.1 两种编排模式

| 脚本 | 用途 | 并行 |
|---|---|---|
| `run_case.py` | 单 case 构建+求解 | 无（COMSOL 内部 -np） |
| `run_requested_full.py` | 多 case 批量编排 | ThreadPoolExecutor |

### 7.2 常用命令

```bash
# 自适应质量 27 case
python3 -B tools/run_requested_full.py --study-id my_study --adaptive --max-parallel 5 --comsol-np 12

# 指定质量 + 材质扫描
python3 -B tools/run_requested_full.py --study-id materials_study \
  --case-definition config/materials_combined.json \
  --quality fast --max-parallel 5 --comsol-np 12

# Dry run（不求解，只打印 manifest）
python3 -B tools/run_requested_full.py --study-id preview --dry-run

# 单 case 测试
python3 -B tools/run_case.py --case-id test_01 --quality fast --comsol-np 12
```

### 7.3 进程管理

```bash
# 查看 COMSOL 进程
ps aux | grep '[c]omsol'

# 查看 Python 编排进程
ps aux | grep '[r]un_requested'

# 杀死所有 COMSOL 进程
pkill -f comsollauncher
pkill -f 'comsol.*batch'

# 查看 CPU 占用
ps aux --sort=-%cpu | head -10

# 实时监视日志
tail -f outputs/<study_id>/cases/<group>/<case_id>/logs/linear_acoustic_field_3d_air.log
```

---

## 8. 输出目录结构

```
outputs/<study_id>/
  study_manifest.json       # 所有 case 的清单
  case_status.csv           # 每个 case 的状态/耗时
  summary.json              # 最终汇总
  cases/
    <group>/
      <case_id>/
        mph/
          linear_acoustic_field_3d_air.mph   # COMSOL 模型（大文件）
        data/
          frequencies.csv                    # 固有频率 f1-f6 + Q
          mode_shapes.csv                    # 模态振型
          structure_probe_timeseries.csv     # 探针位移 u_z(t)
          mic_pressure_timeseries.csv        # 麦克风声压 p(t)
          impact_force_timeseries.csv        # 撞击力 F(t)
          tip_timeseries.csv                 # 尺端位移
          mic_pressure_timeseries_sweep_01~10.csv  # 多距离麦克风
          mic_sweep_distances.csv            # 麦克风距离元数据
          acoustic_metrics.csv               # 派生：SPL, 频谱质心等
          structural_metrics.csv             # 派生：峰值位移
          modal_acoustic_coupling.csv        # 派生：模态-声耦合
        figures/                             # MATLAB 生成的图
        logs/
          linear_acoustic_field_3d_air.log   # COMSOL 求解日志
  tables/                                    # MATLAB 汇总表
    derived_metrics_validation.csv
    conclusion_master_table.csv
```

---

## 9. 调试检查清单

遇到问题时按顺序检查：

1. **进程还在吗？** `ps aux | grep -E 'comsol|python3'`
2. **日志说什么？** `tail -100 outputs/<study_id>/cases/.../logs/*.log`
3. **case_status.csv 更新了吗？** `cat outputs/<study_id>/case_status.csv`
4. **CSV 产出了吗？** `find outputs/<study_id>/cases/ -name '*.csv'`
5. **参数覆盖生效了吗？** `cat outputs/<study_id>/cases/.../data/params_resolved.json`
6. **硬盘够吗？** `df -h` (每个 mph 1-4G)
7. **内存够吗？** `free -h` (12核 job 约需 10-20G)

---

## 10. 本地 MATLAB 后处理

服务器无 MATLAB，所有后处理在本地 Windows 执行：

```matlab
% 1. 计算派生指标（SPL, 衰减, 耦合）
batch_derived_metrics('C:\Users\...\the_singing_ruler', 'outputs/materials_combined');

% 2. 生成汇总表
aggregate_conclusion_table();

% 3. 绘制论文图表
plot_paper_figures_final();
```

后处理管线详见 `matlab/report/batch_derived_metrics.m` 和 `matlab/main_linear_acoustic_field_3d_air.m`。
