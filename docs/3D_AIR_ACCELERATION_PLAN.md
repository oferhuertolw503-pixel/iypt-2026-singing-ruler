# 3D Air Acceleration Plan

## Current Default

`linear_acoustic_field_3d_air` now uses strict sequential one-way coupling as the default implementation:

```text
std1: 3D solid ruler eigenfrequency, solve solid only
std2: 3D solid ruler transient, solve solid only
std3: real 3D air-domain transient, solve actd only
```

The acoustic drive boundary reads the stored structural acceleration through:

```text
withsol('sol2', solid.u_ttX, setval(t,t))
withsol('sol2', solid.u_ttY, setval(t,t))
withsol('sol2', solid.u_ttZ, setval(t,t))
```

Air does not feed back into the structure.

## Implemented Speedups

1. Mesh quality is now truly connected to the 3D Java model.
   - `mesh_numelem <= 50` -> `autoMeshSize(5)`
   - `51 <= mesh_numelem <= 100` -> `autoMeshSize(4)`
   - `mesh_numelem > 100` -> `autoMeshSize(3)`

2. Requested-output runs are role-layered.
   - `timbre` cases default to a `medium+` internal profile:
     - `mesh_numelem = 80`
     - `mode_points = 161`
     - `time_step = 2e-4[s]`
     - `time_end = 0.80[s]`
   - `trend` cases default to `coarse`:
     - `mesh_numelem = 40`
     - `mode_points = 81`
     - `time_step = 1e-4[s]`
     - `time_end = 0.10[s]`

3. Requested-output runs can use controlled parallelism through:

```powershell
-MaxParallelCases 1
```

or, when license/environment permit:

```powershell
-MaxParallelCases 2
```

4. Requested-output completion is now stricter. A case is treated as completed only when these core artifacts all exist:
   - `.mph`
   - `structure_probe_timeseries.csv`
   - `mic_pressure_timeseries.csv`
   - `impact_force_timeseries.csv`

5. Plotting no longer places fake missing points on the scan charts. Missing cases are reported as text only.

## Command Examples

Single-case smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build_comsol_model.ps1 `
  -Target linear_acoustic_field_3d_air `
  -Quality coarse
```

Requested outputs:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run_requested_outputs_3d_air.ps1 `
  -Quality coarse `
  -StudyId requested_3d_air_coarse `
  -MaxParallelCases 1 `
  -SkipExisting
```

Replot from existing CSV:

```powershell
python .\scripts\plot_requested_outputs_3d_air.py `
  --study-root .\outputs\linear\requested_3d_air\requested_3d_air_coarse
```

## Truth Rules

- Every plotted point must come from a real COMSOL case.
- No interpolation, fitting, synthetic spectra, or fake fill-in points.
- Microphone frequency, sound pressure, and duration plots all come from real `mic_pressure_timeseries.csv`.
- Pitch / dominant-frequency markers use the microphone FFT only in `20-2500 Hz`.
- `0-20 Hz` is still visible in spectra, but is treated as low-frequency envelope/drift and is not used as pitch or duration peak.
- Frequency-duration plots keep only valid peaks whose amplitude is at least `5%` of the strongest valid-band peak; active duration uses `10%` of that band peak power.
- Sound-pressure scan plots use microphone RMS as a coarse trend metric; they should not be read as a strictly monotonic law, especially for thickness sweeps without medium/full confirmation.

## Still Pending

These items are still future work and are not claimed as implemented:

- grouped sweep reuse for non-geometry variables (`material`, `x0_ratio`, `J`)
- skipping modal exports for trend-only requested-output cases
- timing-summary benchmarks comparing old and new requested-output wall-clock times
