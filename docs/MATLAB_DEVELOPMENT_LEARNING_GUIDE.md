# MATLAB Development Learning Guide

This guide is tailored for this repository's workflow:

```text
PowerShell/COMSOL build -> raw CSV outputs -> MATLAB manifest postprocess -> figures/tables/status -> Python/PPT packaging
```

The goal is to make MATLAB development more reliable, testable, and easier to debug without breaking the existing rule that MATLAB is started manually by the user.

For the current safe automation boundary, see
[`MATLAB_AUTOMATION_SAFE_PATH.md`](MATLAB_AUTOMATION_SAFE_PATH.md).
The practical rule is: automate MATLAB batch postprocessing and tests; keep COMSOL/LiveLink as a user-controlled data production step unless a fully legitimate, stable COMSOL environment is explicitly available.

## Installed MATLAB Tooling

Official MathWorks resources were installed locally under:

```text
tools/matlab-official/
```

Installed repositories:

- `matlab-agentic-toolkit`
- `matlab-mcp-core-server`
- `skills`
- `rules`
- `prompts`
- `slash-commands`
- `matlab-actions/run-tests`
- `matlab-actions/setup-matlab`

Installed user-level files:

- MCP server binary: `C:\Users\OMEN.LAPTOP-8C8PH934\.local\bin\matlab-mcp-core-server.exe`
- Existing-session MATLAB toolbox package: `C:\Users\OMEN.LAPTOP-8C8PH934\.local\bin\MATLABMCPCoreServerToolkit.mltbx`
- MATLAB skills: `C:\Users\OMEN.LAPTOP-8C8PH934\.agents\skills\matlab-*`
- Claude slash commands: `%APPDATA%\claude\plugins\matlab-slash-commands`
- Copilot prompts: `.github/prompts/*.prompt.md`
- Cursor rule: `.cursor/rules/matlab-development.mdc`
- VS Code MCP config: `.vscode/mcp.json`

Codex global MCP configuration was updated at:

```text
C:\Users\OMEN.LAPTOP-8C8PH934\.codex\config.toml
```

The MATLAB MCP server is configured for `--matlab-session-mode=existing`, which matches this repository's manual MATLAB launch policy.

## One-Time MATLAB Setup

The MCP server can connect to an already-running MATLAB session only after the MATLAB-side toolbox is installed.

1. Open MATLAB manually.
2. Install this toolbox by double-clicking it from Windows Explorer:

```text
C:\Users\OMEN.LAPTOP-8C8PH934\.local\bin\MATLABMCPCoreServerToolkit.mltbx
```

3. In MATLAB, run:

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
shareMATLABSession()
```

4. In a new Codex session, ask:

```text
What MATLAB version and toolboxes are available?
```

If the connection works, Codex should use `detect_matlab_toolboxes`.

## Daily Development Loop

Use this sequence for MATLAB work in this project:

1. Keep source code in `matlab/`, not ad-hoc temporary scripts.
2. Use manifest entrypoints, especially `run_matlab_manifest(...)`.
3. Run static checks before executing expensive COMSOL/MATLAB jobs.
4. Run small function-level tests before full study postprocess.
5. Only trust plots/tables generated from completed COMSOL CSV outputs.

Current automation ladder:

1. Prefer MATLAB MCP tools when a fresh Codex session exposes them.
2. Fall back to `matlab.exe -batch` when MCP tools are unavailable.
3. Run `scripts/run_matlab_model.ps1` only for manifests with complete CSV inputs.
4. Stop before COMSOL-dependent manifests; generate/export CSV in a controlled local COMSOL session first.
5. Never make the correctness of MATLAB automation depend on bypassing COMSOL licensing or authentication.

Recommended MATLAB startup commands:

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
setenv('TSR_COMSOL_PORT', '2038')
shareMATLABSession()
```

Recommended manifest run:

```matlab
run_matlab_manifest('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler/outputs/linear/acoustic_field_3d_air/logs/linear_acoustic_field_3d_air_matlab_manifest.json')
```

## How To Use The New AI Tools

Use these requests in Codex after restarting the session:

```text
Use MATLAB to check matlab/extract/compute_single_sided_fft.m for code analyzer warnings.
```

```text
Use MATLAB to run the unit tests for the MATLAB helper functions.
```

```text
Review matlab/ for maintainability and propose small, safe refactors only.
```

```text
Create MATLAB unit tests for parse_physical_scalar and read_exported_numeric_csv.
```

```text
Use MATLAB to verify the manifest postprocess entrypoint without changing the workflow.
```

For GitHub Copilot, the installed prompts are available from `.github/prompts/`:

- `matlab-check.prompt.md`
- `matlab-docs.prompt.md`
- `matlab-optimize.prompt.md`
- `matlab-readme.prompt.md`
- `matlab-run.prompt.md`
- `matlab-test.prompt.md`

For Claude Code, slash commands are installed as `/matlab-*` commands after restarting Claude.

## Core MATLAB Practices To Build

### 1. Function Boundaries

Prefer small functions with clear input/output contracts. This repo already has a good shape:

```text
matlab/core/      workflow and IO glue
matlab/extract/   signal and numeric extraction
matlab/plot/      plotting only
matlab/export/    summaries and metadata
```

Keep physics-specific assumptions near the manifest/model layer, and keep reusable numerical operations in `extract/`.

### 2. Data Contracts

For every CSV-reading function, document:

- Required columns
- Units
- Whether headers are required or optional
- Behavior for empty rows, comments, NaN, and malformed numeric values

This is especially important because the project supports COMSOL-style commented headers:

```text
% t_s,p_pa
0.0000,0.0123
```

### 3. Tests Before Refactors

Start with low-cost unit tests for pure functions:

- `compute_single_sided_fft`
- `compute_spl_from_pressure`
- `parse_physical_scalar`
- `read_exported_numeric_csv`
- `estimate_q_from_tip`

Then add integration-style tests for manifest/status behavior.

### 4. Plot Reproducibility

Every plot function should be deterministic:

- Inputs are explicit arrays/tables.
- Output path is explicit.
- Figure size and renderer are set.
- No hidden dependency on current folder except the caller's controlled output path.

### 5. Error Messages

MATLAB errors should name the file, missing field, and expected unit when possible. Good errors save entire evenings.

Example style:

```matlab
error('TSR:MissingColumn', 'Expected column "%s" in %s.', columnName, csvPath);
```

## Suggested 4-Week Learning Plan

### Week 1: MATLAB Code Quality

- Read `tools/matlab-official/rules/matlab-coding-standards.md`.
- Run code analyzer checks on `matlab/core/*.m`.
- Fix only warnings that are clearly safe.
- Practice converting scripts into functions with explicit arguments.

### Week 2: Testing

- Read `tools/matlab-official/skills/skills/matlab-test-creator/SKILL.md`.
- Add tests for pure extraction functions.
- Learn `matlab.unittest.TestCase`, `verifyEqual`, `verifyLessThan`, and temporary folders.
- Make tests independent of COMSOL and large output files.

### Week 3: Signal Processing And Acoustic Features

- Focus on `compute_single_sided_fft`, SPL, peak picking, band duration, and Q estimation.
- Create small synthetic signals only for tests, not for final scientific output.
- Compare expected analytical frequencies/amplitudes against computed values.

### Week 4: Workflow Automation

- Harden manifest/status handling.
- Add preflight checks for missing COMSOL CSVs.
- Use MCP tools for static checks and targeted test runs.
- Keep long COMSOL solves manual/controlled, but make postprocess validation fast.

## CI Guidance

The `matlab-actions` repositories were installed for reference and future CI use. For this project, do not put full COMSOL LiveLink runs in GitHub Actions unless the runner has COMSOL, MATLAB, LiveLink, and licensing configured.

Good CI candidates:

- Pure MATLAB unit tests for `matlab/extract/`
- CSV parser tests with small fixture files
- Python plotting scripts that consume tiny fixture CSVs
- Documentation/link checks

Bad CI candidates for now:

- Full COMSOL model generation
- Long transient acoustic runs
- Anything requiring local license servers or GUI MATLAB

## Safety Rules For This Repository

- Codex should not auto-start MATLAB.
- Use `shareMATLABSession()` when you want MCP tools to connect to your open MATLAB.
- Do not replace manifest-based workflow with temporary one-off scripts.
- Do not fabricate spectra or interpolate missing COMSOL cases.
- Keep generated outputs under `outputs/`, not inside `matlab/`.

## Useful Local References

- Agentic Toolkit overview: `tools/matlab-official/matlab-agentic-toolkit/README.md`
- Setup guide: `tools/matlab-official/matlab-agentic-toolkit/GETTING_STARTED.md`
- MCP server docs: `tools/matlab-official/matlab-mcp-core-server/README.md`
- Coding standards: `tools/matlab-official/rules/matlab-coding-standards.md`
- Performance rules: `tools/matlab-official/rules/matlab-performance-optimization.md`
- Live script rules: `tools/matlab-official/rules/live-script-generation.md`
- Slash command guide: `tools/matlab-official/slash-commands/docs/usage-guide.md`
