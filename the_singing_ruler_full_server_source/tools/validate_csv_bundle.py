#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

REQUIRED_CSV = (
    "frequencies.csv",
    "structure_probe_timeseries.csv",
    "mic_pressure_timeseries.csv",
    "impact_force_timeseries.csv",
    "mode_shapes.csv",
)


SWEEP_COUNT = 10


def mic_sweep_filenames() -> list[str]:
    """Return expected mic sweep CSV filenames (10 evenly-spaced distances)."""
    return [f"mic_pressure_timeseries_sweep_{i:02d}.csv" for i in range(1, SWEEP_COUNT + 1)] + [
        "mic_sweep_distances.csv"
    ]


def first_non_empty_line(path: Path) -> str:
    with path.open("r", encoding="utf-8-sig", errors="replace") as handle:
        for raw in handle:
            line = raw.strip()
            if line:
                return line
    return ""


def validate_bundle(case_root: Path, require_mph: bool = True,
                    extra_csv: list[str] | None = None) -> list[str]:
    errors: list[str] = []
    case_root = case_root.resolve()

    if require_mph:
        mph_path = case_root / "mph" / "linear_acoustic_field_3d_air.mph"
        if not mph_path.is_file() or mph_path.stat().st_size <= 0:
            errors.append(f"missing or empty MPH: {mph_path}")

    data_dir = case_root / "data"
    for name in list(REQUIRED_CSV) + (extra_csv or []):
        path = data_dir / name
        if not path.is_file():
            errors.append(f"missing CSV: {path}")
            continue
        if path.stat().st_size <= 0:
            errors.append(f"empty CSV: {path}")
            continue
        first = first_non_empty_line(path)
        if not first.startswith("%"):
            errors.append(f"CSV header is not normalized/commented: {path}")

    return errors


def validate_study(study_root: Path) -> list[tuple[str, list[str]]]:
    manifest_path = study_root / "study_manifest.json"
    if not manifest_path.is_file():
        return [("__study__", [f"missing study manifest: {manifest_path}"])]

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    results: list[tuple[str, list[str]]] = []
    for case in manifest.get("cases", []):
        case_id = str(case.get("case_id", ""))
        output_root = Path(str(case.get("output_root", "")))
        if not output_root.is_absolute():
            output_root = study_root / output_root
        results.append((case_id, validate_bundle(output_root)))
    return results


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("path", help="Case root, or study root containing study_manifest.json")
    parser.add_argument("--study", action="store_true", help="Validate every case in a study manifest")
    parser.add_argument("--no-mph", action="store_true", help="Only validate CSV files")
    args = parser.parse_args()

    root = Path(args.path).resolve()
    if args.study:
        results = validate_study(root)
        failed = [(case_id, errors) for case_id, errors in results if errors]
        if failed:
            for case_id, errors in failed:
                print(f"FAILED {case_id}")
                for error in errors:
                    print(f"  - {error}")
            return 1
        print(f"PASS study: {root}")
        return 0

    errors = validate_bundle(root, require_mph=not args.no_mph)
    if errors:
        print(f"FAILED case: {root}")
        for error in errors:
            print(f"  - {error}")
        return 1
    print(f"PASS case: {root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
