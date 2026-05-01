# MATLAB User Workflow

## Mandatory Rules

1. Codex does not start MATLAB.
2. Repository scripts may prepare manifests and status files, but MATLAB is launched by the user in a real local session.
3. The authoritative entry for parameter-study postprocess is `*_matlab_manifest.json`.
4. Do not invent alternate MATLAB entrypoints, temporary scripts, or direct calls to internal study functions when a manifest already exists.
5. If a MATLAB postprocess fails, retry the same manifest after code fixes. Do not replace the workflow with a new one.
6. The 3D real-air line follows the same rule: use `linear_acoustic_field_3d_air_matlab_manifest.json` as the only formal MATLAB entry.
7. Do not auto-launch MATLAB for the 3D line; the user starts MATLAB manually and runs the manifest.

## Standard Manual Flow

Use this exact pattern inside a real MATLAB session:

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
setenv('TSR_COMSOL_PORT', '2038')
run_matlab_manifest('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler/outputs/linear/sweep/<study_id>/logs/<manifest_name>.json')
```

## Current Smoke Study

Current parameter-study manifest:

```text
C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler/outputs/linear/sweep/study_param_smoke_public_20260422/logs/linear_acoustic_param_study_matlab_manifest.json
```

Recommended manual command:

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
setenv('TSR_COMSOL_PORT', '2038')
run_matlab_manifest('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler/outputs/linear/sweep/study_param_smoke_public_20260422/logs/linear_acoustic_param_study_matlab_manifest.json')
```

## 3D Real-Air Line

Current 3D real-air manifest:

```text
C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler/outputs/linear/acoustic_field_3d_air/logs/linear_acoustic_field_3d_air_matlab_manifest.json
```

Recommended manual command:

```matlab
cd('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler')
addpath(genpath(fullfile(pwd, 'matlab')))
setenv('TSR_COMSOL_PORT', '2038')
run_matlab_manifest('C:/Users/OMEN.LAPTOP-8C8PH934/code/cupt/the_singing_ruler/outputs/linear/acoustic_field_3d_air/logs/linear_acoustic_field_3d_air_matlab_manifest.json')
```

## What To Check After Manual Run

1. `logs/linear_acoustic_param_study_matlab_status.json` becomes `completed`.
2. Each case root contains `summary.json`, `summary.txt`, `run_manifest.txt`, `data/q_estimate.json`, and figure outputs.
3. Study root contains:
   - `tables/all_cases.csv`
   - `tables/timbre_summary.csv`
   - `tables/amplitude_summary.csv`
   - `tables/frequency_summary.csv`
   - `figures/linear_timbre_overview.png`
   - `figures/linear_amplitude_overview.png`
   - `figures/linear_frequency_overview.png`

## Current Code Expectations

The current acoustic-field MATLAB path accepts COMSOL raw CSV with a commented header line and still remains compatible with older headerless files. Preferred headers are:

- `frequencies.csv` -> `mode`, `freq_hz`
- `tip_timeseries.csv` -> `t_s`, `w_m`
- `structure_probe_timeseries.csv` -> `t_s`, `uz_m`
- `mic_pressure_timeseries.csv` -> `t_s`, `p_pa`
- `impact_force_timeseries.csv` -> `t_s`, `force_z_N`
- `mic_pressure_fft.csv` -> `freq_hz`, `amp_pa`
- `mode_shapes.csv` -> `x_over_L`, `w_mode1...`

Preferred COMSOL/Java export format:

```text
% col1,col2,...
numeric_row_1
numeric_row_2
...
```

Legacy headerless numeric CSV remains readable for backward compatibility, but new 3D real-air exports should include the commented header line.
