---
description: Verify that MATLAB automation is available and will not block Codex work
---

You are verifying whether MATLAB can support the current Codex workflow without becoming a blocker.

Project root:

```text
C:\Users\<your-computer>\code\cupt\the_singing_ruler
```

MATLAB installation:

```text
D:\Program Files\Matlab R2025a
```

MATLAB executable:

```text
D:\Program Files\Matlab R2025a\bin\matlab.exe
```

MCP server binary:

```text
C:\Users\<your-computer>\.codex\bin\matlab-mcp-core-server-win64.exe
```

## Goal

Decide whether MATLAB automation is currently:

- `PASS`: Codex can use MATLAB directly through MCP or reliably through `matlab.exe -batch`.
- `WARN`: MATLAB works through fallback, but MCP tools are not visible in this session.
- `BLOCKED`: MATLAB itself cannot run even through batch mode.

Do not treat COMSOL/LiveLink as required for this smoke test.

## Safety Rules

1. Do not start GUI MATLAB.
2. Do not start COMSOL.
3. Do not run COMSOL LiveLink, `mphstart`, `ModelUtil`, or any `.mph` extraction.
4. Do not configure, repair, bypass, or troubleshoot COMSOL licensing or authentication.
5. Only run MATLAB checks that are safe for a licensed MATLAB installation and do not require extra toolboxes.
6. Prefer non-mutating checks. If a command writes project outputs, use only the known safe manifest listed below.

## Step 1: Check MCP Availability

First inspect whether this Codex session exposes MATLAB MCP tools.

Expected tools, if MCP is loaded:

- `detect_matlab_toolboxes`
- `check_matlab_code`
- `evaluate_matlab_code`
- `run_matlab_file`
- `run_matlab_test_file`

If these tools are available:

1. Run `detect_matlab_toolboxes`.
2. Run a tiny `evaluate_matlab_code` check:

```matlab
disp(version('-release'));
disp(version);
```

3. Run `check_matlab_code` on:

```text
C:\Users\<your-computer>\code\cupt\the_singing_ruler\matlab\run_matlab_manifest.m
```

If these tools are not available, do not stop. Continue with batch fallback.

## Step 2: Verify MCP Server Binary

Run:

```powershell
& 'C:\Users\<your-computer>\.codex\bin\matlab-mcp-core-server-win64.exe' --version
```

Expected: the command prints a MathWorks MATLAB MCP Core Server version and exits successfully.

If this passes but MCP tools are not visible, report:

```text
WARN: MCP server binary works, but this Codex session has not loaded the tools. Restart Codex to pick up MCP.
```

## Step 3: Verify MATLAB Batch Fallback

Run:

```powershell
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch "disp(version('-release')); disp(version);"
```

Expected:

```text
2025a
25.1.0.2943329 (R2025a)
```

If this fails, classify the result as `BLOCKED`.

## Step 4: Verify Base Project MATLAB Path

Run:

```powershell
& 'D:\Program Files\Matlab R2025a\bin\matlab.exe' -batch "cd('C:/Users/<your-computer>/code/cupt/the_singing_ruler'); addpath(genpath('matlab')); which run_matlab_manifest; checkcode('matlab/run_matlab_manifest.m')"
```

Expected:

- MATLAB finds `run_matlab_manifest`.
- `checkcode` runs without blocking.
- Warnings are acceptable; startup failure is not.

## Step 5: Verify Safe Manifest Postprocess

Run only this known safe CSV-backed manifest:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath .\outputs\linear\acoustic_field\logs\linear_acoustic_field_matlab_manifest.json
```

Expected status file:

```text
outputs\linear\acoustic_field\logs\linear_acoustic_field_matlab_status.json
```

Expected JSON result:

```json
{
  "status": "completed"
}
```

If the manifest is missing required CSV files, do not try COMSOL. Report that CSV inputs must be generated first.

## Step 6: Final Report Format

## Step 6: Verify COMSOL Boundary Fail-Fast

Run this regression check only to verify that the script stops before COMSOL/LiveLink:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_matlab_model.ps1 `
  -ManifestPath .\outputs\linear\base\logs\linear_base_matlab_manifest.json
```

Expected result:

- The command fails quickly in PowerShell.
- It reports `MATLAB automation stopped before COMSOL/LiveLink boundary`.
- It must not show `MATLAB attempt 1/7`.
- It must not start COMSOL, `mphstart`, or `ModelUtil`.

Treat this as a successful boundary check, not as a MATLAB automation failure.

## Step 7: Final Report Format

Return a concise report with this structure:

```text
MATLAB Automation Smoke Test: PASS | WARN | BLOCKED

MCP:
- Tools visible: yes/no
- Server binary: pass/fail
- Notes:

Batch fallback:
- MATLAB version command: pass/fail
- Project path/checkcode: pass/fail
- Safe manifest postprocess: pass/fail/not run
- COMSOL boundary fail-fast: pass/fail/not run

COMSOL boundary:
- COMSOL was not started.
- LiveLink was not required.
- Any COMSOL-dependent manifest should remain manual/user-controlled until CSV exists.

Decision:
- MATLAB will/will not block Codex work.
- Recommended next action:
```

## Classification Rules

Use `PASS` if:

- MCP tools work, or batch fallback works.
- The safe manifest postprocess completes, or there is a clear non-MATLAB reason it was not run.

Use `WARN` if:

- MCP tools are not visible, but `matlab.exe -batch` works.
- MCP binary works, but Codex needs restart to load tools.
- MATLAB works, but safe manifest inputs are missing.

Use `BLOCKED` only if:

- MATLAB cannot start through `matlab.exe -batch`, or
- MATLAB cannot load the project path at all.

Do not classify COMSOL license/authentication issues as MATLAB blockers.
