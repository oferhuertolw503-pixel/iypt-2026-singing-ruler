# The Singing Ruler Requested 3D Air Outputs

This repository contains the scripts needed to build real COMSOL 3D air-domain cases and generate the requested acoustic output figures and tables.

Every plotted point must come from a completed COMSOL case. Missing cases remain marked as missing. No interpolation, curve fitting, synthetic spectra, or fake material points are used.

## Requested Outputs

1. Timbre
   - Material microphone spectra
   - Material microphone frequency duration panels
   - Steel microphone frequency duration
2. Pitch (steel, microphone at 2 cm)
   - Free length scan: `10, 14, 18, 22, 26 cm`
   - Width scan: `1, 2, 3, 4, 5 cm`
   - Thickness scan: `1, 2, 3, 4, 5 mm`
   - Impact position scan: `0.25L, 0.5L, 0.75L`
   - Impulse scan: `0.02, 0.04, 0.06, 0.08 N*s`
3. Sound pressure (steel, microphone at 2 cm)
   - Uses the same completed steel scan cases as the pitch plots
4. Impulse force-time curves

No cross-material frequency-duration comparison figure is generated.

## Frequency-Duration Definition

The duration analysis is based only on `mic_pressure_timeseries.csv`.

- Full-signal single-sided FFT over `0-2500 Hz`
- Select the top `6` microphone peaks for each material separately
- Split frequency bands by adjacent-peak midpoints
- Short-time analysis parameters:
  - Hann window
  - Window length `0.03 s`
  - Hop `0.002 s`
  - `nfft = 8192`
- A band is counted as active when its short-time power is at least `1%` of that band's peak power

The exported duration table is:

- `tables\material_frequency_duration_long.csv`
  - Columns:
    `material_key, material_name, peak_rank, freq_hz, duration_s, band_low_hz, band_high_hz, source_case_id`

## Main Scripts

- `scripts\run_requested_outputs_3d_air.ps1`
  - Prepares and runs the full requested case set
- `scripts\plot_requested_outputs_3d_air.py`
  - Rebuilds the requested tables and figures from existing CSV outputs
- `scripts\build_comsol_model.ps1`
  - Single-case COMSOL build entry

## Recommended Workflow

Open PowerShell in the repository root:

```powershell
Set-Location .
```

### 1. Single-Case Smoke Check

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_comsol_model.ps1 `
  -Target linear_acoustic_field_3d_air `
  -Quality coarse
```

### 2. Prepare Only

This creates the requested case manifest without running COMSOL:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_requested_outputs_3d_air.ps1 `
  -Quality coarse `
  -StudyId requested_3d_air_contract_check `
  -PrepareOnly
```

### 3. Full Requested Output Run

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_requested_outputs_3d_air.ps1 `
  -Quality coarse `
  -StudyId requested_3d_air_coarse `
  -MaxParallelCases 1 `
  -SkipExisting
```

For a license/environment that safely supports two independent COMSOL jobs, the recommended upper bound is:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_requested_outputs_3d_air.ps1 `
  -Quality coarse `
  -StudyId requested_3d_air_coarse `
  -MaxParallelCases 2 `
  -SkipExisting
```

### 4. Replot From Existing CSV

```powershell
python .\scripts\plot_requested_outputs_3d_air.py `
  --study-root .\outputs\linear\requested_3d_air\requested_3d_air_coarse
```

## Output Location

Requested-output studies are written under:

```text
outputs\linear\requested_3d_air\<StudyId>\
```

Key files:

- `study_manifest.json`
- `tables\all_requested_cases.csv`
- `tables\material_frequency_duration_long.csv`
- `figures\timbre_material_frequency_distribution.png`
- `figures\timbre_material_frequency_duration_panels.png`
- `figures\timbre_steel_frequency_duration.png`
- `figures\steel_pitch_frequency_scan.png`
- `figures\steel_sound_pressure_scan.png`
- `figures\impulse_force_time.png`
- `summary.json`

Each case directory is expected to contain direct COMSOL outputs:

- `.mph`
- `params_resolved.json`
- `data\frequencies.csv`
- `data\structure_probe_timeseries.csv`
- `data\mic_pressure_timeseries.csv`
- `data\impact_force_timeseries.csv`
- `data\mode_shapes.csv`

## Notes

- The requested-output workflow does not auto-start MATLAB.
- These requested figures are generated directly from exported COMSOL CSV files.
- Requested-output runs are role-layered by default:
  - timbre material cases use a `medium+` internal profile (`medium` mesh/time-step base plus `time_end = 0.80 s`)
  - trend cases use `coarse`
- Requested-output cases use a per-case air-domain radius: `max(0.12 m, ruler-corner radius from sphere center + 0.02 m clearance)`.
- Non-steel material properties remain engineering approximations until replaced with measured or literature-backed values.
- The acceleration plan for the 3D air-domain line is recorded in [docs\3D_AIR_ACCELERATION_PLAN.md](docs\3D_AIR_ACCELERATION_PLAN.md).
- The current 3D line uses strict sequential one-way coupling: structure transient first, then real 3D air-domain transient driven by the stored structural acceleration.
