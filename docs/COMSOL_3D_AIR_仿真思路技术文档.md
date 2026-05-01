# COMSOL 3D 空气域仿真思路技术文档

## 1. 目标与主线

本仓库研究的是“会唱歌的尺子”：一端被夹紧、另一端悬空的尺子在短时冲击后发生振动，并向空气中辐射声音。当前正式的 COMSOL 主线是 `linear_acoustic_field_3d_air`，它把问题拆成两个连续阶段：

1. 先求 3D 实体尺子的结构振动。
2. 再用结构表面的加速度驱动真实 3D 空气域声学瞬态，得到麦克风声压。

因此，这条线不是用经验公式直接“造”声音，也不是只做梁振动后处理；它会实际建立 COMSOL 三维结构和三维空气域，逐个 case 求解并导出 CSV，再从导出的麦克风声压数据中计算频谱、音高、声压和持续时间。

## 2. 仓库分层

本项目的仿真链路分为四层：

- `scripts/`：外层调度。PowerShell 负责读取配置、生成 case manifest、调用 COMSOL、隔离运行时目录、检查输出完整性和触发绘图。
- `models/linear/acoustic_field_3d_air/`：当前核心 COMSOL 模型。Java 模板显式搭建 COMSOL 模型树，并直接导出标准 CSV。
- `matlab/`：后处理层。3D 空气域主线中，MATLAB 主要读取 COMSOL 已经导出的 CSV，生成图、FFT、SPL 和 summary。
- `outputs/`：结果层。批量请求输出写入 `outputs/linear/requested_3d_air/<StudyId>/`。

`runtime/`、`models/*/artifacts/build/`、`.codex_tmp/` 这类目录主要是运行产物或临时工作区，不是理解仿真思想的核心入口。

## 3. 物理模型抽象

模型把尺子看成小变形线弹性三维实体：

- 尺子几何是长方体，参数为自由长度 `L_free`、宽度 `b`、厚度 `h_ruler`。
- `x = 0` 端面为理想固定端，另一端自由。
- 冲击力作用在上表面一个有限小矩形区域，而不是数学点载荷。
- 结构阻尼采用 Rayleigh 阻尼。
- 空气域是包围尺子的球形 3D 声学域，并从空气球中扣除尺子实体体积。
- 空气域外边界使用球面波辐射边界，模拟向远场辐射。
- 麦克风是空气域中的一个 Cut Point，记录瞬态声压。

这是一种线性、单向耦合的振动声学模型：尺子振动会驱动空气声压，但空气声压不会反过来影响尺子的结构响应。

## 4. 参数来源

默认参数位于 `models/linear/acoustic_field_3d_air/config/params.json`，主要分组如下：

- `geometry`：`L_free`、`b`、`h`。
- `material`：密度 `rho`、杨氏模量 `E`、泊松比 `nu`。
- `excitation`：冲击位置 `x0`、冲量 `J`、脉冲宽度 `tau_imp`、冲击区域尺寸。
- `damping`：结构阻尼比和 Rayleigh 阻尼参考频率。
- `studies`：特征频率阶数、瞬态总时长、时间步长、模态采样点数。
- `acoustics`：空气半径、空气密度、声速、麦克风坐标、辐射源参考点。
- `mesh`：网格档位参数。

批量输出由 `scripts/run_requested_outputs_3d_air.ps1` 负责生成。它会复制默认 JSON，并按材料、长度、宽度、厚度、冲击位置、冲量等变量生成每个 case 的独立配置文件。

## 5. COMSOL 模型树

核心 Java 模板是 `models/linear/acoustic_field_3d_air/src/Linear_Acoustic_Field_3D_Air.java`。它的模型树可以概括为：

```text
ModelUtil
  -> model
  -> component comp1
  -> geometry geom1
  -> selections
  -> materials
  -> solid mechanics
  -> eigenfrequency study
  -> structure transient study
  -> pressure acoustics
  -> air transient study
  -> result datasets and CSV exports
  -> save .mph
```

几何部分包含：

- `blkRuler`：实体尺子。
- `blkVoid`：与尺子等尺寸的扣除体。
- `sphAir`：球形空气域。
- `difAir`：`sphAir - blkVoid`，也就是去掉尺子体积后的空气。
- `uni1`：尺子实体和空气域的联合体，并保留内部边界。

选择集用于定位：

- 固定端面；
- 冲击加载小面；
- 尺子与空气接触的声学驱动边界。

材料则分别赋给尺子实体域和空气域。

## 6. 冲击载荷与阻尼

冲击被建模为等效冲量载荷，而不是显式建一个小球和接触过程。默认力时程为半正弦脉冲：

```text
Fimp(t) = pi*J/(2*tau_imp) * sin(pi*(t - t_imp_start)/tau_imp)
```

在脉冲区间外，力为零。为了避免三维网格上的奇异点载荷，Java 模型把总力分布到一个有限矩形 patch 上，并在 `x`、`y` 两个方向用余弦形状函数平滑分布，使积分后的总力仍对应目标冲量。

结构阻尼采用 Rayleigh 形式：

```text
C = alpha_dM*M + beta_dK*K
```

其中 `alpha_dM_struct` 和 `beta_dK_struct` 由 `zeta_struct`、`f_damp_low`、`f_damp_high` 推出。

## 7. 单向顺序耦合策略

这是整个仿真思路中最关键的一点。当前模型采用严格顺序的一向耦合：

```text
std1: 特征频率，求 solid
std2: 结构瞬态，求 solid
std3: 空气声学瞬态，求 actd
```

结构瞬态完成后，空气声学边界通过 `withsol('sol2', ...)` 读取结构解中的加速度：

```text
withsol('sol2', solid.u_ttX, setval(t,t))
withsol('sol2', solid.u_ttY, setval(t,t))
withsol('sol2', solid.u_ttZ, setval(t,t))
```

这些加速度分量作为空气域中尺子表面的 Normal Acceleration 声学边界条件，驱动 `TransientPressureAcoustics` 求解。空气瞬态解保存为 `sol3`。

这种做法比完全耦合的声固瞬态便宜、稳定，也更适合大量扫参。代价是忽略了空气声压对结构的反作用，也就是没有辐射阻抗反馈。

## 8. 输出契约

3D 空气域 Java 模型会直接导出标准数据：

- `frequencies.csv`：来自 `sol1` 的特征频率。
- `structure_probe_timeseries.csv`：来自 `sol2` 的结构探针位移。
- `mode_shapes.csv`：特征模态沿尺长采样。
- `mic_pressure_timeseries.csv`：来自 `sol3` 的麦克风声压。
- `impact_force_timeseries.csv`：实际冲击力时程。
- `.mph`：每个 case 对应的 COMSOL 模型文件。

运行脚本会规范化 CSV 表头、检查关键输出是否存在，并写出 MATLAB handoff manifest。批量请求输出中，一个 case 只有在 `.mph`、结构时程、麦克风声压时程、冲击力时程都存在时才被视为完成。

## 9. 后处理逻辑

`matlab/main_linear_acoustic_field_3d_air.m` 读取上述 CSV 后生成：

- 结构特征频率柱状图；
- 结构探针时程和 FFT；
- 麦克风声压时程和 FFT；
- 麦克风频谱与结构模态频率对比图；
- 模态振型图；
- SPL、峰峰值、RMS、主频等 summary。

`scripts/plot_requested_outputs_3d_air.py` 则负责批量请求图表。它遵守几条数据真实性规则：

- 音高从麦克风声压 FFT 中取，不从理论公式直接填；
- 声压趋势来自麦克风压力指标；
- 频率持续时间来自 `mic_pressure_timeseries.csv` 的短时分析；
- 缺失 case 只标为缺失，不做插值、不拟合、不补假点。

## 10. 批量研究设计

`scripts/run_requested_outputs_3d_air.ps1` 会构造两类 case：

- 音色组：钢尺、PVC、雪弗板、亚克力、木板材料对比。
- 趋势组：只用钢尺，扫描自由长度、宽度、厚度、冲击位置和冲量。

脚本采用角色分层精度：

- 音色 case 使用较长时长和中等网格，以支持频率持续时间分析。
- 趋势 case 使用较短时长和粗网格，以降低总计算成本。

每个 case 的空气半径按以下规则选取：

```text
max(0.12 m, 尺子角点到空气球心的半径 + 0.02 m 裕量)
```

这样既保证外边界离尺子足够远，又避免小尺子 case 使用过大的空气域。

## 11. 这种思路的合理性

尺子发声问题天然分成“结构振动源”和“空气传播”两个部分。结构瞬态相对便宜，3D 空气瞬态相对昂贵。如果每个扫参点都做完全声固耦合，计算成本会很高；如果只做梁振动和经验声压，又难以支撑“麦克风位置处真实声压”的说法。

本仓库采用的折中方案是：

- 结构侧用真实三维实体力学求振动；
- 声学侧用真实三维空气域求压力；
- 二者用结构加速度做单向传递；
- 所有图都追溯到每个 COMSOL case 的 CSV。

因此它比纯解析近似更物理，比完全耦合声固瞬态更容易批量运行，适合作为竞赛或技术报告中的工程仿真方案。

## 12. 假设与局限

- 尺子是线弹性、各向同性材料。
- 非钢材料参数目前是工程近似，需要实验或文献值进一步替换。
- 固定端是理想夹持，没有夹具柔度和接触滑移。
- 冲击是等效力脉冲，没有建球-尺接触。
- 声固耦合是单向的，忽略空气反作用。
- 空气外边界是有限球面配合辐射边界，不是真正无限域。
- 高频声压对网格和时间步长敏感。
- 声压趋势图可用于比较仿真趋势，但若要对应实验绝对 SPL，还需要校准材料、边界、冲击和麦克风条件。

## 13. 复现命令

单个 3D 空气域 case 冒烟检查：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_comsol_model.ps1 `
  -Target linear_acoustic_field_3d_air `
  -Quality coarse
```

只生成批量 case 清单，不运行 COMSOL：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_requested_outputs_3d_air.ps1 `
  -Quality coarse `
  -StudyId requested_3d_air_contract_check `
  -PrepareOnly
```

运行批量请求输出：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_requested_outputs_3d_air.ps1 `
  -Quality coarse `
  -StudyId requested_3d_air_coarse `
  -MaxParallelCases 1 `
  -SkipExisting
```

从已有 CSV 重新绘图：

```powershell
python .\scripts\plot_requested_outputs_3d_air.py `
  --study-root .\outputs\linear\requested_3d_air\requested_3d_air_coarse
```

## 14. 推荐阅读顺序

后续维护或讲解时，建议按这个顺序读仓库：

1. `PACKAGE_README.md`
2. `models/linear/acoustic_field_3d_air/config/params.json`
3. `models/linear/acoustic_field_3d_air/src/Linear_Acoustic_Field_3D_Air.java`
4. `models/linear/acoustic_field_3d_air/run.ps1`
5. `scripts/run_requested_outputs_3d_air.ps1`
6. `matlab/main_linear_acoustic_field_3d_air.m`
7. `scripts/plot_requested_outputs_3d_air.py`
8. `docs/3D_AIR_ACCELERATION_PLAN.md`
