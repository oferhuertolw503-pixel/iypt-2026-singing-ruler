#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path
from typing import Any

sys.dont_write_bytecode = True

from validate_csv_bundle import REQUIRED_CSV, validate_bundle, mic_sweep_filenames

PACKAGE_ROOT = Path(__file__).resolve().parents[1]
JAVA_CLASS = "Linear_Acoustic_Field_3D_Air"
MODEL_MPH_NAME = "linear_acoustic_field_3d_air.mph"

FULL_PROFILE = {
    "mesh_numelem": 120,
    "mode_points": 241,
    "time_end": "1[s]",
    "time_step": "1e-4[s]",
}

MEDIUM_PROFILE = {
    "mesh_numelem": 80,
    "mode_points": 161,
    "time_end": "0.5[s]",
    "time_step": "2e-4[s]",
}

COARSE_PROFILE = {
    "mesh_numelem": 40,
    "mode_points": 81,
    "time_end": "0.10[s]",
    "time_step": "1e-4[s]",
}

DECAY_PROFILE = {
    "mesh_numelem": 40,
    "mode_points": 101,
    "time_end": "0.60[s]",
    "time_step": "2e-4[s]",
}

FAST_PROFILE = {
    "mesh_numelem": 40,
    "mode_points": 101,
    "time_end": "0.25[s]",
    "time_step": "2e-4[s]",
}

ECO_PROFILE = {
    "mesh_numelem": 40,
    "mode_points": 61,
    "time_end": "0.12[s]",
    "time_step": "2.5e-4[s]",
}

QUALITY_PROFILES = {
    "full": FULL_PROFILE,
    "medium": MEDIUM_PROFILE,
    "coarse": COARSE_PROFILE,
    "decay": DECAY_PROFILE,
    "fast": FAST_PROFILE,
    "eco": ECO_PROFILE,
}

LEAF_SECTIONS = (
    "geometry",
    "material",
    "boundary",
    "excitation",
    "damping",
    "studies",
    "acoustics",
    "mesh",
)

REQUIRED_KEYS = (
    "L_free",
    "b",
    "h",
    "rho",
    "E",
    "nu",
    "x0",
    "J",
    "tau_imp",
    "eigen_modes",
    "time_end",
    "time_step",
    "mode_points",
    "use_real_air_domain",
    "air_shape",
    "air_radius",
    "rho_air",
    "c_air",
    "mic_x",
    "mic_y",
    "mic_z",
    "mic_offset_from_surface_m",
    "numelem",
)

COMMENTED_HEADERS = {
    "frequencies.csv": "% mode,freq_hz",
    "structure_probe_timeseries.csv": "% t_s,uz_m",
    "mic_pressure_timeseries.csv": "% t_s,p_pa",
    "impact_force_timeseries.csv": "% t_s,force_z_N",
    "tip_timeseries.csv": "% t_s,w_m",
}


@dataclass(frozen=True)
class ComsolTools:
    compile_cmd: list[str]
    batch_cmd: list[str]


def json_load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def json_write(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def config_string(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, (int, float)):
        return f"{value:g}"
    return str(value)


def java_literal(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def set_nested(config: dict[str, Any], section: str, key: str, value: Any) -> None:
    target = config.setdefault(section, {})
    if not isinstance(target, dict):
        raise ValueError(f"Config section is not an object: {section}")
    target[key] = value


def deep_update(target: dict[str, Any], updates: dict[str, Any]) -> dict[str, Any]:
    for key, value in updates.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            deep_update(target[key], value)
        else:
            target[key] = deepcopy(value)
    return target


def apply_quality_profile(config: dict[str, Any], quality: str = "full") -> dict[str, Any]:
    profile = dict(QUALITY_PROFILES.get(quality, FULL_PROFILE))
    # Allow QUICK_TEST env var to override profile for verification
    if os.environ.get("QUICK_TEST") == "1":
        profile["mesh_numelem"] = 12
        profile["mode_points"] = 13
        profile["time_end"] = "0.02[s]"
        profile["time_step"] = "5e-3[s]"
    set_nested(config, "studies", "time_end", profile["time_end"])
    set_nested(config, "studies", "time_step", profile["time_step"])
    set_nested(config, "studies", "mode_points", profile["mode_points"])
    set_nested(config, "mesh", "numelem", profile["mesh_numelem"])
    return config


def resolve_config(base_config: dict[str, Any], overrides: dict[str, Any] | None = None,
                   quality: str = "full") -> dict[str, Any]:
    config = deepcopy(base_config)
    if overrides:
        deep_update(config, overrides)
    return apply_quality_profile(config, quality)


def leaf_map(config: dict[str, Any]) -> dict[str, str]:
    values: dict[str, str] = {}
    for section_name in LEAF_SECTIONS:
        section = config.get(section_name, {})
        if not isinstance(section, dict):
            continue
        for key, value in section.items():
            if isinstance(value, (dict, list)):
                continue
            values[key] = config_string(value)
    return values


def normalized_params(config: dict[str, Any]) -> dict[str, str]:
    leaves = leaf_map(config)
    missing = [key for key in REQUIRED_KEYS if not leaves.get(key)]
    if missing:
        raise ValueError("Missing required config value(s): " + ", ".join(missing))

    return {
        "L_free": leaves["L_free"],
        "b": leaves["b"],
        "h_ruler": leaves["h"],
        "rho": leaves["rho"],
        "E": leaves["E"],
        "nu": leaves["nu"],
        "root": leaves.get("root", "ideal_clamp"),
        "tip": leaves.get("tip", "free"),
        "excitation_mode": leaves.get("mode", "impact"),
        "x0": leaves["x0"],
        "use_impulse": leaves.get("use_impulse", "1"),
        "J": leaves["J"],
        "tau_imp": leaves["tau_imp"],
        "pulse_shape": leaves.get("pulse_shape", "gaussian"),
        "impact_patch_dx": leaves.get("impact_patch_dx", "0.010[m]"),
        "impact_patch_dy": leaves.get("impact_patch_dy", "0.006[m]"),
        "zeta_struct": leaves.get("zeta_struct", "0.015"),
        "f_damp_low": leaves.get("f_damp_low", leaves.get("f_damp_ref", "40[Hz]")),
        "f_damp_high": leaves.get("f_damp_high", leaves.get("f_damp_ref", "700[Hz]")),
        "eigen_modes": leaves["eigen_modes"],
        "eigen_shift": leaves.get("eigen_shift", "1[Hz]"),
        "time_end": leaves["time_end"],
        "time_step": leaves["time_step"],
        "mode_points": leaves["mode_points"],
        "mesh_numelem": leaves["numelem"],
        "use_real_air_domain": leaves["use_real_air_domain"],
        "air_shape": leaves["air_shape"],
        "air_radius": leaves["air_radius"],
        "rho_air": leaves["rho_air"],
        "c_air": leaves["c_air"],
        "mic_x": leaves["mic_x"],
        "mic_y": leaves["mic_y"],
        "mic_z": leaves["mic_z"],
        "mic_offset_from_surface_m": leaves["mic_offset_from_surface_m"],
        "radiation_source_x": leaves.get("radiation_source_x", "L_free/2"),
        "radiation_source_y": leaves.get("radiation_source_y", "0[m]"),
        "radiation_source_z": leaves.get("radiation_source_z", "0[m]"),
    }


def auto_mesh_size(mesh_numelem: str) -> int:
    value = int(round(float(mesh_numelem)))
    if value <= 50:
        return 5
    if value <= 100:
        return 4
    return 3


def render_param_block(params: dict[str, str]) -> str:
    lines = []
    for key, value in params.items():
        lines.append(f'    model.param().set("{key}", "{java_literal(value)}");')
    return "\n".join(lines)


def render_java_source(template_path: Path, generated_path: Path, params: dict[str, str], model_path: Path) -> None:
    template = template_path.read_text(encoding="utf-8")
    model_path_literal = model_path.resolve().as_posix()
    rendered = template.replace("    // __LINEAR_PARAM_BLOCK__", render_param_block(params))
    rendered = rendered.replace("__MODE_POINTS__", params.get("mode_points", "241"))
    rendered = rendered.replace("__AUTO_MESH_SIZE__", str(auto_mesh_size(params["mesh_numelem"])))
    rendered = rendered.replace("__MODEL_SAVE_PATH__", java_literal(model_path_literal))
    generated_path.parent.mkdir(parents=True, exist_ok=True)
    generated_path.write_text(rendered, encoding="utf-8")


def resolve_comsol_tools(comsol_bin: str | None = None) -> ComsolTools:
    candidates: list[Path] = []
    if comsol_bin:
        candidates.append(Path(comsol_bin).expanduser())
    env_bin = os.environ.get("COMSOL_BIN")
    if env_bin:
        candidates.append(Path(env_bin).expanduser())

    for bin_dir in candidates:
        compile_path = first_existing(bin_dir, ("comsolcompile",))
        batch_path = first_existing(bin_dir, ("comsolbatch",))
        if compile_path and batch_path:
            return ComsolTools([str(compile_path)], [str(batch_path)])

        comsol = first_existing(bin_dir, ("comsol",))
        if comsol:
            return ComsolTools([str(comsol), "compile"], [str(comsol), "batch"])

    compile_which = shutil.which("comsolcompile")
    batch_which = shutil.which("comsolbatch")
    if compile_which and batch_which:
        return ComsolTools([compile_which], [batch_which])

    comsol_which = shutil.which("comsol")
    if comsol_which:
        return ComsolTools([comsol_which, "compile"], [comsol_which, "batch"])

    raise FileNotFoundError(
        "COMSOL commands not found. Pass --comsol-bin, set COMSOL_BIN, "
        "or add comsolcompile/comsolbatch to PATH."
    )


def first_existing(bin_dir: Path, names: tuple[str, ...]) -> Path | None:
    for name in names:
        candidate = bin_dir / name
        if candidate.exists():
            return candidate
    return None


def make_state(runtime_root: Path) -> tuple[dict[str, Path], dict[str, str], list[str]]:
    state = {
        "home": runtime_root / "home",
        "configuration": runtime_root / "cfg",
        "data": runtime_root / "data",
        "prefs": runtime_root / "prefs",
        "recovery": runtime_root / "recoveries",
        "tmp": runtime_root / "tmp",
    }
    for path in state.values():
        path.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env.update(
        {
            "HOME": str(state["home"].resolve()),
            "TMPDIR": str(state["tmp"].resolve()),
            "TMP": str(state["tmp"].resolve()),
            "TEMP": str(state["tmp"].resolve()),
        }
    )
    args = [
        "-configuration",
        str(state["configuration"].resolve()),
        "-data",
        str(state["data"].resolve()),
        "-prefsdir",
        str(state["prefs"].resolve()),
        "-recoverydir",
        str(state["recovery"].resolve()),
        "-tmpdir",
        str(state["tmp"].resolve()),
    ]
    return state, env, args


def clean_known_outputs(case_root: Path, extra_names: list[str] | None = None) -> None:
    all_names = list(REQUIRED_CSV) + (extra_names or [])
    for path in [case_root / "mph" / MODEL_MPH_NAME, *(case_root / "data" / name for name in all_names)]:
        if path.exists():
            path.unlink()


def expected_mode_shape_header(path: Path) -> str:
    col_count = 1
    with path.open("r", encoding="utf-8-sig", errors="replace") as handle:
        for raw in handle:
            line = raw.strip()
            if line and not line.startswith("%"):
                col_count = len(line.split(","))
                break
    headers = ["x_over_L"] + [f"w_mode{i}" for i in range(1, col_count)]
    return "% " + ",".join(headers)


def normalize_exported_csv(path: Path) -> None:
    if not path.exists():
        return
    header = COMMENTED_HEADERS.get(path.name)
    if path.name == "mode_shapes.csv":
        header = expected_mode_shape_header(path)
    if not header:
        return

    bare = header[2:]
    normalized_bare = "".join(bare.split()).lower()
    data_lines: list[str] = []
    with path.open("r", encoding="utf-8-sig", errors="replace") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("%"):
                continue
            if "".join(line.split()).lower() == normalized_bare:
                continue
            data_lines.append(line)
    path.write_text(header + "\n" + "\n".join(data_lines) + ("\n" if data_lines else ""), encoding="utf-8")


def normalize_csv_headers(case_root: Path, extra_names: list[str] | None = None) -> None:
    for name in [*REQUIRED_CSV, "tip_timeseries.csv"] + (extra_names or []):
        normalize_exported_csv(case_root / "data" / name)


def run_subprocess(cmd: list[str], cwd: Path, env: dict[str, str]) -> str:
    print("==>", " ".join(cmd), flush=True)
    result = subprocess.run(cmd, cwd=str(cwd), env=env, check=True, capture_output=True, text=True)
    return result.stdout


def write_stdout_csvs(stdout: str, data_dir: Path) -> None:
    """Parse __CSV__ markers from Java stdout and write CSV files."""
    data_dir.mkdir(parents=True, exist_ok=True)
    current_file: str | None = None
    current_lines: list[str] = []
    for line in stdout.splitlines():
        stripped = line.rstrip("\r\n")
        if stripped.startswith("__CSV__"):
            if current_file and current_lines:
                (data_dir / current_file).write_text("\n".join(current_lines) + "\n", encoding="utf-8")
            current_file = stripped[len("__CSV__"):]
            current_lines = []
        elif stripped == "__CSV_END__":
            if current_file and current_lines:
                (data_dir / current_file).write_text("\n".join(current_lines) + "\n", encoding="utf-8")
            current_file = None
            current_lines = []
        elif current_file is not None:
            current_lines.append(stripped)


def run_case(
    *,
    case_id: str,
    output_root: Path,
    runtime_root: Path,
    base_config_path: Path,
    template_path: Path,
    comsol_bin: str | None = None,
    overrides: dict[str, Any] | None = None,
    dry_run: bool = False,
    quality: str = "full",
    comsol_np: int = 0,
) -> dict[str, Any]:
    start = time.monotonic()
    output_root = output_root.resolve()
    runtime_root = runtime_root.resolve()
    model_path = output_root / "mph" / MODEL_MPH_NAME
    generated_dir = runtime_root / "build" / "generated"
    generated_java = generated_dir / f"{JAVA_CLASS}.java"
    class_file = generated_dir / f"{JAVA_CLASS}.class"

    base_config = json_load(base_config_path)
    resolved = resolve_config(base_config, overrides, quality)
    params = normalized_params(resolved)

    # Compute expected mic sweep CSV file names (10 evenly-spaced distances + metadata)
    sweep_files = mic_sweep_filenames()
    for fname in sweep_files:
        if fname == "mic_sweep_distances.csv":
            COMMENTED_HEADERS[fname] = "% sweep_index,distance_from_surface_m,mic_z_expr"
        else:
            COMMENTED_HEADERS[fname] = "% t_s,p_pa"

    if dry_run:
        print(f"DRY RUN case {case_id}")
        print(f"  output_root: {output_root.as_posix()}")
        print(f"  runtime_root: {runtime_root.as_posix()}")
        print(f"  mph: {model_path.as_posix()}")
        print(f"  quality: {quality}")
        print(f"  profile: {QUALITY_PROFILES.get(quality, FULL_PROFILE)}")
        return {
            "case_id": case_id,
            "status": "planned",
            "message": "dry run; COMSOL was not called",
            "output_root": output_root.as_posix(),
            "mph_path": model_path.as_posix(),
            "elapsed_seconds": 0.0,
        }

    for directory in (output_root / "mph", output_root / "data", output_root / "logs", generated_dir):
        directory.mkdir(parents=True, exist_ok=True)
    clean_known_outputs(output_root, sweep_files)
    json_write(output_root / "params_resolved.json", resolved)
    render_java_source(template_path, generated_java, params, model_path)

    tools = resolve_comsol_tools(comsol_bin)
    _, env, state_args = make_state(runtime_root)
    log_path = output_root / "logs" / "linear_acoustic_field_3d_air.log"

    if class_file.exists():
        class_file.unlink()

    run_subprocess([*tools.compile_cmd, *state_args, generated_java.name], generated_dir, env)
    if not class_file.is_file():
        raise RuntimeError(f"COMSOL compile did not produce class file: {class_file}")

    batch_args = [
        *tools.batch_cmd,
        *state_args,
        "-outputfile",
        str(model_path.resolve()),
        "-classpath",
        str(generated_dir),
        "-inputfile",
        str(class_file),
        "-batchlog",
        str(log_path.resolve()),
    ]
    # Add COMSOL parallel cores
    if comsol_np > 0:
        batch_args.insert(1, "-np")
        batch_args.insert(2, str(comsol_np))

    stdout = run_subprocess(
        batch_args,
        PACKAGE_ROOT,
        env,
    )

    # COMSOL 6.1 appends _Model.mph to the -outputfile path; rename if needed
    mph_dir = output_root / "mph"
    model_suffixed = mph_dir / f"{MODEL_MPH_NAME.rsplit('.', 1)[0]}_Model.mph"
    if not model_path.is_file() and model_suffixed.is_file():
        model_suffixed.rename(model_path)
        # Clean up auxiliary files COMSOL creates alongside
        for aux in mph_dir.glob(f"{MODEL_MPH_NAME.rsplit('.', 1)[0]}.mph.*"):
            aux.unlink()

    write_stdout_csvs(stdout, output_root / "data")
    normalize_csv_headers(output_root, sweep_files)
    errors = validate_bundle(output_root, extra_csv=sweep_files)
    if errors:
        raise RuntimeError("; ".join(errors))

    elapsed = round(time.monotonic() - start, 6)
    case_manifest = {
        "case_id": case_id,
        "status": "completed",
        "quality": quality,
        "profile": QUALITY_PROFILES.get(quality, FULL_PROFILE),
        "output_root": output_root.as_posix(),
        "mph_path": model_path.as_posix(),
        "required_csv": [(output_root / "data" / name).as_posix() for name in list(REQUIRED_CSV) + sweep_files],
        "elapsed_seconds": elapsed,
    }
    json_write(output_root / "case_manifest.json", case_manifest)
    return {
        "case_id": case_id,
        "status": "completed",
        "message": "completed",
        "output_root": output_root.as_posix(),
        "mph_path": model_path.as_posix(),
        "elapsed_seconds": elapsed,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case-id", default="single_full")
    parser.add_argument("--output-root", default="")
    parser.add_argument("--runtime-root", default="")
    parser.add_argument("--base-config", default=str(PACKAGE_ROOT / "config" / "params_base.json"))
    parser.add_argument("--template", default=str(PACKAGE_ROOT / "src" / "Linear_Acoustic_Field_3D_Air.java.template"))
    parser.add_argument("--comsol-bin", default="")
    parser.add_argument("--quality", default="full", choices=["full", "medium", "coarse", "decay", "fast", "eco"])
    parser.add_argument("--comsol-np", type=int, default=0, help="Number of CPU cores for COMSOL batch solver")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output_root = Path(args.output_root) if args.output_root else PACKAGE_ROOT / "outputs" / args.case_id
    runtime_root = Path(args.runtime_root) if args.runtime_root else PACKAGE_ROOT / "runtime" / args.case_id
    try:
        result = run_case(
            case_id=args.case_id,
            output_root=output_root,
            runtime_root=runtime_root,
            base_config_path=Path(args.base_config),
            template_path=Path(args.template),
            comsol_bin=args.comsol_bin or None,
            dry_run=args.dry_run,
            quality=args.quality,
            comsol_np=args.comsol_np,
        )
    except Exception as exc:
        print(f"FAILED {args.case_id}: {exc}")
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
