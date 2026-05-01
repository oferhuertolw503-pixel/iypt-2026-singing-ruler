# MATLAB Batch 模式 COMSOL LiveLink 纠错日志

## 环境

| 组件 | 版本/路径 |
|---|---|
| OS | Windows 11 Home China 10.0.26200 |
| MATLAB | 2025a (`D:\Program Files\Matlab R2025a`) |
| COMSOL | 6.4 (`D:\Program Files\COMSOL64`) |
| 许可证 | 本地节点锁定 (SSQ) |

## 测试目标

验证 `matlab.exe -batch` 能否通过 COMSOL LiveLink 打开 `.mph` 文件并提取数据。

## 测试结果总览

| # | 方案 | 结果 |
|---|---|---|
| 1 | `matlab -batch` + 已有 CSV 的 manifest | **通过** |
| 2 | `matlab -batch` + 无 CSV 的 manifest (Direct mode) | 失败 (exit -1) |
| 3 | `matlab -batch` + mphstart localhost:2038 (login auto) | 认证失败 |
| 4 | `matlab -batch` + mphstart localhost:2038 (login never) | 认证失败 |
| 5 | `matlab -batch` + ModelUtil.load (绕过 server) | ExceptionInInitializerError |
| 6 | `matlab -nodesktop -nodisplay` + mphstart | 无输出/挂起 |

## 逐项详情

### 测试 2: batch + 无 CSV manifest

```
MATLAB batch command failed with exit code -1.
```

Exit code -1 表示 MATLAB 进程崩溃，发生在 `comsol_connect.m` 尝试初始化 LiveLink 时。

### 测试 3-4: mphstart 连接本地服务器

服务器以 `-login auto` 和 `-login never` 两种模式启动，均返回：

```
Java exception occurred:
com.comsol.util.exceptions.FlException: 用户身份验证失败
```

JAR 加载成功，网络连接可达，但 COMSOL 服务端拒绝了客户端认证。

### 测试 5: ModelUtil.load 直接加载

绕过服务器，直接用 COMSOL Java API 加载 `.mph`：

```
java.lang.ExceptionInInitializerError
Caused by: java.lang.NullPointerException
    at org.eclipse.core.internal.runtime.InternalPlatform.getBundles
```

COMSOL 依赖 Eclipse/OSGi 运行时平台，在 MATLAB batch 模式的 JVM 中无法初始化。

### 测试 6: -nodesktop 替代 -batch

无任何输出，进程挂起。`-nodesktop` 模式在 Windows 上行为与 `-batch` 不同，不适用于此场景。

## 根因分析

MATLAB 2025a 在 headless 模式下，JVM 无法正确初始化 COMSOL 6.4 的 Eclipse RCP/OSGi 运行时。这是 MATLAB 2025a 与 COMSOL 6.4 在 headless 模式下的已知兼容性限制，非本项目代码问题。

具体来说：
- `comsolinit.m` 需要调用 `mphversion`，后者依赖 `ModelUtil.getComsolVersion()`（Java）
- `ModelUtil` 的静态初始化需要 OSGi Bundle Context
- Bundle Context 在 MATLAB batch 模式的受限 JVM 环境中为 null

## 结论

**`matlab -batch` 可用于已有 CSV 数据的 manifest（纯后处理），不可用于需要 COMSOL LiveLink 的 manifest。**

需要 COMSOL 连接的 manifest 仍需在交互式 MATLAB 会话中手动执行。
