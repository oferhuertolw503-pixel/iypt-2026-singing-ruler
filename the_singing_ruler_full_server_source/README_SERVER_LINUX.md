# The Singing Ruler Full COMSOL Server Source

This folder is a Linux server source package for COMSOL Multiphysics 6.1.
It contains only source, configuration, and runner scripts. It does not ship
generated `outputs/`, `runtime/`, `.mph`, `.class`, CSV, PNG, or video files.

## Requirements

- Linux with COMSOL Multiphysics 6.1.
- Structural Mechanics Module and Acoustics Module licenses.
- `python3` standard library.
- No MATLAB, NumPy, Matplotlib, or PowerShell is required.

COMSOL command resolution order:

1. `--comsol-bin /path/to/comsol/bin`
2. `COMSOL_BIN=/path/to/comsol/bin`
3. `comsolcompile` and `comsolbatch` on `PATH`
4. fallback to `comsol compile` and `comsol batch` on `PATH`

## Smoke Run

Run one full baseline case first:

```bash
cd the_singing_ruler_full_server_source
chmod +x run_requested_full.sh run_single_full.sh

./run_single_full.sh \
  --comsol-bin /path/to/comsol/bin \
  --study-id smoke_full
```

Expected outputs:

```text
outputs/smoke_full/
  mph/linear_acoustic_field_3d_air.mph
  data/frequencies.csv
  data/structure_probe_timeseries.csv
  data/mic_pressure_timeseries.csv
  data/impact_force_timeseries.csv
  data/mode_shapes.csv
  logs/linear_acoustic_field_3d_air.log
```

## Full 27-Case Run

Run the requested full source set:

```bash
./run_requested_full.sh \
  --comsol-bin /path/to/comsol/bin \
  --study-id requested_3d_air_full_server \
  --max-parallel 1
```

The default full profile is applied to every case:

```text
mesh_numelem = 120
mode_points = 241
time_end = 1[s]
time_step = 1e-4[s]
```

Outputs are written under:

```text
outputs/requested_3d_air_full_server/
  study_manifest.json
  case_status.csv
  summary.json
  cases/
    ...
```

The run passes when `case_status.csv` contains 27 rows with `status=completed`.

## Dry Run

Use dry run to inspect all case paths and parameters without calling COMSOL:

```bash
./run_requested_full.sh --study-id preview_full --dry-run
```

Dry run does not create `outputs/` or `runtime/`.

## Source Tests

Run the package tests before launching COMSOL:

```bash
chmod +x run_tests.sh
./run_tests.sh
```

These tests use only the Python standard library. They do not start COMSOL.
They check the requested 27-case definition, full parameter injection, Java
template rendering, CSV bundle validation, dry-run behavior, and source-package
cleanliness.

## Local Validation Status

This source package was locally validated on 2026-05-11 without starting COMSOL:

```text
python3 -B -m unittest discover -s tests -p "test_*.py"
  PASS: 7 tests

PYTHONPYCACHEPREFIX=/tmp/pycache-comsol-package python3 -m py_compile tools/run_case.py tools/run_requested_full.py tools/validate_csv_bundle.py tests/test_server_package.py
  PASS

python3 -B tools/run_requested_full.py --study-id preview_full --dry-run
  PASS: case_count=27, COMSOL not called, no outputs/runtime created

source-package audit
  PASS: no .mph/.class/.csv/.png/.mp4/.pyc files
  PASS: no prebuilt outputs/, runtime/, result/, or __pycache__/ directories
  PASS: no hard-coded Windows drive path, PowerShell runner, or .exe COMSOL command
```

The validation guarantees the package is internally consistent as a source
bundle: Python files parse, the 27 requested full cases are generated, full
parameters are injected, Java placeholders render, dry-run is side-effect free,
and the post-run output validator checks the expected `.mph` plus five core CSV
files.

It cannot guarantee a full solver run will finish on a particular Linux server.
That still depends on the installed COMSOL 6.1 build, available Structural
Mechanics and Acoustics licenses, Java API compatibility, memory, wall time,
disk quota, and scheduler policy. Treat `run_single_full.sh` as the first real
server acceptance test.

## Known Server Risks

- COMSOL commands are not found. Fix by passing `--comsol-bin /path/to/comsol/bin`,
  setting `COMSOL_BIN`, or loading the server module that provides `comsol`,
  `comsolcompile`, and `comsolbatch`.
- License checkout fails. Run with `--max-parallel 1`, confirm both Structural
  Mechanics and Acoustics are licensed, and keep the COMSOL batch log for the
  license administrator.
- Java compile fails because a COMSOL 6.1 Linux feature key differs from the
  Windows-exported (6.4) API shape. Inspect the generated Java file under
  `runtime/<study-id>/.../build/generated/` and the compile error, then patch
  `src/Linear_Acoustic_Field_3D_Air.java.template`.
- Batch solve finishes without one of the required outputs. Check
  `outputs/<study-id>/.../logs/linear_acoustic_field_3d_air.log`; the model may
  have solved but a result export, probe, or table feature failed.
- The job is killed for memory or wall time. Start with `run_single_full.sh`,
  request more memory/time in the scheduler, keep `--max-parallel 1`, and only
  increase parallelism after several cases complete cleanly.
- The package is placed on a read-only or slow network filesystem. Copy it to a
  writable scratch/work directory because each case writes `runtime/`,
  generated Java/class files, `.mph`, logs, and CSV files.
- Shell scripts lose execute permission during transfer. Re-run
  `chmod +x run_requested_full.sh run_single_full.sh run_tests.sh`.
- Text files are edited after transfer and converted to CRLF. If Bash reports a
  bad interpreter or unexpected `$'\r'`, run `dos2unix *.sh tools/*.py`.

## Validate Existing Outputs

Validate a single case:

```bash
python3 tools/validate_csv_bundle.py outputs/smoke_full
```

Validate a full study:

```bash
python3 tools/validate_csv_bundle.py outputs/requested_3d_air_full_server --study
```

## Notes

- The model is the 3D solid ruler plus real 3D transient air-domain line.
- The Java model was exported from COMSOL 6.4 (Windows) and adapted for COMSOL 6.1 (Linux).
- If Linux COMSOL reports a Java API feature-key incompatibility, keep the
  failing log and adjust the Java template for that server installation.
