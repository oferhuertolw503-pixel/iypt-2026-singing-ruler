#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from copy import deepcopy
from datetime import datetime
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from validate_csv_bundle import mic_sweep_filenames
from run_case import FULL_PROFILE, PACKAGE_ROOT, run_case


def token(value: float) -> str:
    return f"{value:g}".replace(".", "p").replace("-", "m")


def meter_from_cm(value_cm: float) -> str:
    return f"{value_cm / 100.0:.8g}[m]"


def meter_from_mm(value_mm: float) -> str:
    return f"{value_mm / 1000.0:.8g}[m]"


def meter_string(value_m: float) -> str:
    text = f"{value_m:.3f}".rstrip("0").rstrip(".")
    return f"{text}[m]"


def air_radius_m(l_free_cm: float, width_cm: float, thickness_mm: float) -> float:
    half_length = l_free_cm / 200.0
    half_width = width_cm / 200.0
    half_thickness = thickness_mm / 2000.0
    corner_radius = math.sqrt(half_length**2 + half_width**2 + half_thickness**2)
    return max(0.12, corner_radius + 0.02)


def make_case_overrides(
    *,
    material: dict[str, Any],
    l_free_cm: float,
    width_cm: float,
    thickness_mm: float,
    x0_ratio: float,
    impulse_ns: float,
) -> dict[str, Any]:
    radius = air_radius_m(l_free_cm, width_cm, thickness_mm)
    return {
        "geometry": {
            "L_free": meter_from_cm(l_free_cm),
            "b": meter_from_cm(width_cm),
            "h": meter_from_mm(thickness_mm),
        },
        "material": {
            "rho": material["rho"],
            "E": material["E"],
            "nu": material["nu"],
        },
        "excitation": {
            "x0": f"{x0_ratio:.8g}*L_free",
            "J": "{:.8g}[N*s]".format(impulse_ns * material.get("J_scale", 1.0)),
            "tau_imp": "2e-3[s]",
            "pulse_shape": "half_sine",
        },
        "damping": {
            "zeta_struct": str(material.get("zeta", 0.015)),
            "f_damp_low": "40[Hz]",
            "f_damp_high": "700[Hz]",
        },
        "acoustics": {
            "mic_x": "L_free/2",
            "mic_y": "0[m]",
            "mic_z": "0.02[m]",
            "mic_offset_from_surface_m": "0.02[m]",
            "radiation_source_x": "L_free/2",
            "radiation_source_y": "0[m]",
            "radiation_source_z": "0[m]",
            "air_radius": meter_string(radius),
        },
        "studies": {
            "time_end": FULL_PROFILE["time_end"],
            "time_step": FULL_PROFILE["time_step"],
            "mode_points": FULL_PROFILE["mode_points"],
        },
        "mesh": {
            "numelem": FULL_PROFILE["mesh_numelem"],
        },
    }


def case_record(
    *,
    case_id: str,
    group: str,
    primary_variable: str,
    value: float | str,
    value_unit: str,
    material: dict[str, Any],
    output_root: Path,
    overrides: dict[str, Any],
    l_free_cm: float,
    width_cm: float,
    thickness_mm: float,
    x0_ratio: float,
    impulse_ns: float,
) -> dict[str, Any]:
    return {
        "case_id": case_id,
        "group": group,
        "requested_role": "timbre" if primary_variable == "material" else "trend",
        "quality": "full",
        "material_key": material["key"],
        "material_name": material["name"],
        "primary_variable": primary_variable,
        "value": value,
        "value_unit": value_unit,
        "L_free_cm": l_free_cm,
        "b_cm": width_cm,
        "h_mm": thickness_mm,
        "x0_ratio": x0_ratio,
        "J_Ns": impulse_ns,
        "output_root": output_root.resolve().as_posix(),
        "mph_path": (output_root / "mph" / "linear_acoustic_field_3d_air.mph").resolve().as_posix(),
        "config_overrides": overrides,
    }


def build_cases(definition: dict[str, Any], study_root: Path) -> list[dict[str, Any]]:
    baseline = definition["baseline"]
    materials = definition["materials"]
    steel = next(item for item in materials if item["key"] == "steel")
    cases: list[dict[str, Any]] = []

    def add_case(
        case_id: str,
        group: str,
        primary_variable: str,
        value: float | str,
        value_unit: str,
        material: dict[str, Any],
        subdir: str,
        l_free_cm: float,
        width_cm: float,
        thickness_mm: float,
        x0_ratio: float,
        impulse_ns: float,
    ) -> None:
        output_root = study_root / "cases" / subdir / case_id
        overrides = make_case_overrides(
            material=material,
            l_free_cm=l_free_cm,
            width_cm=width_cm,
            thickness_mm=thickness_mm,
            x0_ratio=x0_ratio,
            impulse_ns=impulse_ns,
        )
        cases.append(
            case_record(
                case_id=case_id,
                group=group,
                primary_variable=primary_variable,
                value=value,
                value_unit=value_unit,
                material=material,
                output_root=output_root,
                overrides=overrides,
                l_free_cm=l_free_cm,
                width_cm=width_cm,
                thickness_mm=thickness_mm,
                x0_ratio=x0_ratio,
                impulse_ns=impulse_ns,
            )
        )

    for material in materials:
        add_case(
            f"material_{material['key']}",
            "timbre",
            "material",
            material["key"],
            "category",
            material,
            "timbre_material",
            baseline["L_free_cm"],
            baseline["b_cm"],
            baseline["h_mm"],
            baseline["x0_ratio"],
            baseline["J_Ns"],
        )

    scans = definition["scan_values"]
    for value in scans["L_free_cm"]:
        add_case(
            f"L_free_{token(value)}cm",
            "steel_scan",
            "L_free",
            value,
            "cm",
            steel,
            "steel_scan/L_free",
            value,
            baseline["b_cm"],
            baseline["h_mm"],
            baseline["x0_ratio"],
            baseline["J_Ns"],
        )
    for value in scans["b_cm"]:
        add_case(
            f"b_{token(value)}cm",
            "steel_scan",
            "b",
            value,
            "cm",
            steel,
            "steel_scan/b",
            baseline["L_free_cm"],
            value,
            baseline["h_mm"],
            baseline["x0_ratio"],
            baseline["J_Ns"],
        )
    for value in scans["h_mm"]:
        add_case(
            f"h_{token(value)}mm",
            "steel_scan",
            "h",
            value,
            "mm",
            steel,
            "steel_scan/h",
            baseline["L_free_cm"],
            baseline["b_cm"],
            value,
            baseline["x0_ratio"],
            baseline["J_Ns"],
        )
    for value in scans["x0_ratio"]:
        add_case(
            f"x0_ratio_{token(value)}",
            "steel_scan",
            "x0_ratio",
            value,
            "ratio",
            steel,
            "steel_scan/x0_ratio",
            baseline["L_free_cm"],
            baseline["b_cm"],
            baseline["h_mm"],
            value,
            baseline["J_Ns"],
        )
    for value in scans["J_Ns"]:
        add_case(
            f"J_{token(value)}Ns",
            "steel_scan",
            "J",
            value,
            "N*s",
            steel,
            "steel_scan/J",
            baseline["L_free_cm"],
            baseline["b_cm"],
            baseline["h_mm"],
            baseline["x0_ratio"],
            value,
        )
    return cases


def manifest_case_view(case: dict[str, Any]) -> dict[str, Any]:
    keys = [
        "case_id",
        "group",
        "requested_role",
        "quality",
        "material_key",
        "material_name",
        "primary_variable",
        "value",
        "value_unit",
        "L_free_cm",
        "b_cm",
        "h_mm",
        "x0_ratio",
        "J_Ns",
        "output_root",
        "mph_path",
    ]
    row = {key: case[key] for key in keys}
    row["required_csv"] = [
        str((Path(case["output_root"]) / "data" / name).resolve().as_posix())
        for name in (
            "frequencies.csv",
            "structure_probe_timeseries.csv",
            "mic_pressure_timeseries.csv",
            "impact_force_timeseries.csv",
            "mode_shapes.csv",
        )
    ]
    # Append mic sweep files (10 points + metadata)
    row["required_csv"].extend(
        str((Path(case["output_root"]) / "data" / name).resolve().as_posix())
        for name in mic_sweep_filenames()
    )
    return row


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_status(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = ["case_id", "status", "message", "output_root", "mph_path", "elapsed_seconds"]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})


# Adaptive quality: decay-sensitive → fast, amplitude-only → eco
ADAPTIVE_QUALITY = {
    "material":  "fast",   # E affects f and decay strongly
    "L_free":    "fast",   # f ∝ 1/L², decay times scale
    "h":         "fast",   # f ∝ h, decay varies
    "b":         "eco",    # very weak effect on f, amplitude only
    "J":         "eco",    # amplitude only, no f or decay effect
    "x0_ratio":  "eco",    # amplitude only, no f or decay effect
}


def run_one(case: dict[str, Any], args: argparse.Namespace, study_root: Path) -> dict[str, Any]:
    quality = args.quality
    if args.adaptive:
        quality = ADAPTIVE_QUALITY.get(case.get("primary_variable", ""), "fast")
    try:
        return run_case(
            case_id=case["case_id"],
            output_root=Path(case["output_root"]),
            runtime_root=Path(args.runtime_root).resolve() / case["case_id"],
            base_config_path=Path(args.base_config).resolve(),
            template_path=Path(args.template).resolve(),
            comsol_bin=args.comsol_bin or None,
            overrides=case["config_overrides"],
            dry_run=args.dry_run,
            quality=quality,
            comsol_np=args.comsol_np,
        )
    except Exception as exc:
        return {
            "case_id": case["case_id"],
            "status": "failed",
            "message": str(exc),
            "output_root": case["output_root"],
            "mph_path": case["mph_path"],
            "elapsed_seconds": "",
        }


def parse_args() -> argparse.Namespace:
    default_study = "requested_3d_air_full_" + datetime.now().strftime("%Y%m%d_%H%M%S")
    parser = argparse.ArgumentParser()
    parser.add_argument("--study-id", default=default_study)
    parser.add_argument("--output-root", default="")
    parser.add_argument("--runtime-root", default="")
    parser.add_argument("--comsol-bin", default="")
    parser.add_argument("--quality", default="full", choices=["full", "medium", "coarse", "decay", "fast", "eco"])
    parser.add_argument("--max-parallel", type=int, default=1)
    parser.add_argument("--adaptive", action="store_true", help="Use adaptive quality per group (fast for freq-sensitive, eco for amplitude-only)")
    parser.add_argument("--comsol-np", type=int, default=0, help="Number of CPU cores for COMSOL batch solver")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--base-config", default=str(PACKAGE_ROOT / "config" / "params_base.json"))
    parser.add_argument("--case-definition", default=str(PACKAGE_ROOT / "config" / "requested_cases.json"))
    parser.add_argument("--template", default=str(PACKAGE_ROOT / "src" / "Linear_Acoustic_Field_3D_Air.java.template"))
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.max_parallel < 1:
        print("--max-parallel must be at least 1", file=sys.stderr)
        return 2

    study_root = Path(args.output_root).resolve() if args.output_root else (PACKAGE_ROOT / "outputs" / args.study_id).resolve()
    args.runtime_root = args.runtime_root or str((PACKAGE_ROOT / "runtime" / args.study_id).resolve())
    definition = json.loads(Path(args.case_definition).read_text(encoding="utf-8"))
    cases = build_cases(definition, study_root)

    manifest = {
        "study_id": args.study_id,
        "model_id": "linear_acoustic_field_3d_air",
        "quality": "full",
        "full_profile": FULL_PROFILE,
        "case_count": len(cases),
        "created_by": "the_singing_ruler_full_server_source/tools/run_requested_full.py",
        "output_root": study_root.as_posix(),
        "runtime_root": str(Path(args.runtime_root).resolve().as_posix()),
        "cases": [manifest_case_view(case) for case in cases],
    }

    if args.dry_run:
        print("DRY RUN requested full run")
        print(json.dumps(manifest, ensure_ascii=False, indent=2))
        print("COMSOL was not called and no output directories were created.")
        return 0

    study_root.mkdir(parents=True, exist_ok=True)
    write_json(study_root / "study_manifest.json", manifest)
    status_path = study_root / "case_status.csv"
    results: list[dict[str, Any]] = []

    if args.max_parallel == 1:
        for case in cases:
            result = run_one(case, args, study_root)
            results.append(result)
            write_status(status_path, results)
            if result["status"] != "completed":
                print(f"FAILED {case['case_id']}: {result['message']}", file=sys.stderr)
                return 1
    else:
        with ThreadPoolExecutor(max_workers=args.max_parallel) as executor:
            future_to_case = {executor.submit(run_one, case, args, study_root): case for case in cases}
            for future in as_completed(future_to_case):
                result = future.result()
                results.append(result)
                write_status(status_path, sorted(results, key=lambda row: row["case_id"]))
                if result["status"] != "completed":
                    print(f"FAILED {result['case_id']}: {result['message']}", file=sys.stderr)
                    return 1

    completed = sum(1 for row in results if row["status"] == "completed")
    summary = {
        "study_id": args.study_id,
        "case_count": len(cases),
        "completed_case_count": completed,
        "failed_case_count": len(cases) - completed,
        "study_manifest": (study_root / "study_manifest.json").as_posix(),
        "case_status": status_path.as_posix(),
    }
    write_json(study_root / "summary.json", summary)
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0 if completed == len(cases) else 1


if __name__ == "__main__":
    raise SystemExit(main())
