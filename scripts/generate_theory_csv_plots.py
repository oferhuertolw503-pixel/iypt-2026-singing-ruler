from __future__ import annotations

import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
from matplotlib import font_manager


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "outputs" / "requested_theory_steel_mic2cm"
CSV_DIR = OUTPUT_ROOT / "csv"
FIG_DIR = OUTPUT_ROOT / "figures"
FIG_ZH_DIR = FIG_DIR / "zh"

E_PA = 193e9
RHO_KG_M3 = 7930.0
BETA1 = 1.875104068711961
RHO_AIR = 1.225
MIC_DISTANCE_M = 0.02
P_REF_PA = 20e-6

# Baseline calibration aligned to an existing repo summary:
# L=0.20 m, b=0.03 m, h=0.002 m, J=0.04 N*s, x0=0.85L, mic offset=0.02 m
CAL_L_M = 0.20
CAL_H_M = 0.002
CAL_J_NS = 0.04
CAL_XI = 0.85
CAL_P_RMS_PA = 1.366315941657539


@dataclass(frozen=True)
class VariableSpec:
    key: str
    display_name: str
    display_name_zh: str
    unit: str
    curve_min: float
    curve_max: float
    curve_step: float
    sample_values: tuple[float, ...]
    base_L_m: float = 0.20
    base_b_m: float = 0.03
    base_h_m: float = 0.002
    base_xi: float = 0.80
    base_J_ns: float = 0.04


VARIABLE_SPECS = (
    VariableSpec(
        key="length",
        display_name="Free Length",
        display_name_zh="自由端长度",
        unit="cm",
        curve_min=10.0,
        curve_max=26.0,
        curve_step=0.1,
        sample_values=(10.0, 14.0, 18.0, 22.0, 26.0),
    ),
    VariableSpec(
        key="width",
        display_name="Width",
        display_name_zh="宽度",
        unit="cm",
        curve_min=1.0,
        curve_max=5.0,
        curve_step=0.05,
        sample_values=(1.0, 2.0, 3.0, 4.0, 5.0),
    ),
    VariableSpec(
        key="thickness",
        display_name="Thickness",
        display_name_zh="厚度",
        unit="mm",
        curve_min=1.0,
        curve_max=5.0,
        curve_step=0.02,
        sample_values=(1.0, 2.0, 3.0, 4.0, 5.0),
    ),
    VariableSpec(
        key="impact_position",
        display_name="Impact Position",
        display_name_zh="撞击位置",
        unit="x0/L",
        curve_min=0.25,
        curve_max=0.95,
        curve_step=0.005,
        sample_values=(0.25, 0.50, 0.75),
    ),
    VariableSpec(
        key="impulse",
        display_name="Impulse",
        display_name_zh="冲量",
        unit="N*s",
        curve_min=0.02,
        curve_max=0.08,
        curve_step=0.001,
        sample_values=(0.02, 0.04, 0.06, 0.08),
    ),
)


def configure_font() -> None:
    candidates = [
        "Microsoft YaHei",
        "SimHei",
        "Noto Sans CJK SC",
        "Source Han Sans SC",
        "Arial Unicode MS",
    ]
    installed = {font.name for font in font_manager.fontManager.ttflist}
    for name in candidates:
        if name in installed:
            matplotlib.rcParams["font.sans-serif"] = [name]
            break
    matplotlib.rcParams["axes.unicode_minus"] = False


def ensure_dirs() -> None:
    CSV_DIR.mkdir(parents=True, exist_ok=True)
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    FIG_ZH_DIR.mkdir(parents=True, exist_ok=True)


def beam_frequency_hz(L_m: float, h_m: float) -> float:
    coeff = (BETA1**2) / (2.0 * math.pi * math.sqrt(12.0))
    return coeff * (h_m / (L_m**2)) * math.sqrt(E_PA / RHO_KG_M3)


def sigma(beta: float) -> float:
    return (math.sinh(beta) - math.sin(beta)) / (math.cosh(beta) + math.cos(beta))


SIGMA1 = sigma(BETA1)


def mode_shape_raw(xi: float) -> float:
    beta_x = BETA1 * xi
    return (
        math.cosh(beta_x)
        - math.cos(beta_x)
        - SIGMA1 * (math.sinh(beta_x) - math.sin(beta_x))
    )


MODE_TIP = mode_shape_raw(1.0)


def mode_shape_normalized(xi: float) -> float:
    return mode_shape_raw(xi) / MODE_TIP


PRESSURE_CALIBRATION = CAL_P_RMS_PA / (
    (CAL_J_NS * CAL_H_M / (CAL_L_M**3)) * mode_shape_normalized(CAL_XI)
)


def microphone_pressure_rms_pa(L_m: float, h_m: float, J_ns: float, xi: float) -> float:
    return PRESSURE_CALIBRATION * J_ns * h_m * mode_shape_normalized(xi) / (L_m**3)


def spl_db_from_pressure(p_rms_pa: float) -> float:
    if p_rms_pa <= 0.0:
        return float("-inf")
    return 20.0 * math.log10(p_rms_pa / P_REF_PA)


def build_state(spec: VariableSpec, x_value: float) -> dict[str, float]:
    state = {
        "L_m": spec.base_L_m,
        "b_m": spec.base_b_m,
        "h_m": spec.base_h_m,
        "xi": spec.base_xi,
        "J_ns": spec.base_J_ns,
    }
    if spec.key == "length":
        state["L_m"] = x_value / 100.0
    elif spec.key == "width":
        state["b_m"] = x_value / 100.0
    elif spec.key == "thickness":
        state["h_m"] = x_value / 1000.0
    elif spec.key == "impact_position":
        state["xi"] = x_value
    elif spec.key == "impulse":
        state["J_ns"] = x_value
    return state


def x_values(spec: VariableSpec) -> np.ndarray:
    count = int(round((spec.curve_max - spec.curve_min) / spec.curve_step)) + 1
    return np.linspace(spec.curve_min, spec.curve_max, count)


def make_curve_rows(spec: VariableSpec) -> list[dict[str, float]]:
    rows: list[dict[str, float]] = []
    for x in x_values(spec):
        state = build_state(spec, float(x))
        f_hz = beam_frequency_hz(state["L_m"], state["h_m"])
        p_rms_pa = microphone_pressure_rms_pa(
            state["L_m"], state["h_m"], state["J_ns"], state["xi"]
        )
        rows.append(
            {
                "x_value": float(x),
                "frequency_hz": f_hz,
                "pressure_rms_pa": p_rms_pa,
                "spl_db": spl_db_from_pressure(p_rms_pa),
                "L_m": state["L_m"],
                "b_m": state["b_m"],
                "h_m": state["h_m"],
                "x0_over_L": state["xi"],
                "J_Ns": state["J_ns"],
            }
        )
    return rows


def make_sample_rows(spec: VariableSpec) -> list[dict[str, float]]:
    rows: list[dict[str, float]] = []
    for x in spec.sample_values:
        state = build_state(spec, float(x))
        f_hz = beam_frequency_hz(state["L_m"], state["h_m"])
        p_rms_pa = microphone_pressure_rms_pa(
            state["L_m"], state["h_m"], state["J_ns"], state["xi"]
        )
        rows.append(
            {
                "variable": spec.key,
                "x_value": float(x),
                "x_unit": spec.unit,
                "frequency_hz": f_hz,
                "pressure_rms_pa": p_rms_pa,
                "spl_db": spl_db_from_pressure(p_rms_pa),
                "L_m": state["L_m"],
                "b_m": state["b_m"],
                "h_m": state["h_m"],
                "x0_over_L": state["xi"],
                "J_Ns": state["J_ns"],
            }
        )
    return rows


def write_csv(path: Path, rows: list[dict[str, float]], fieldnames: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def plot_metric_panels(
    specs: tuple[VariableSpec, ...],
    curves: dict[str, list[dict[str, float]]],
    samples: dict[str, list[dict[str, float]]],
    metric_key: str,
    ylabel: str,
    title: str,
    filename_stem: str,
    chinese: bool = False,
    output_dir: Path | None = None,
) -> None:
    if output_dir is None:
        output_dir = FIG_DIR

    fig, axes = plt.subplots(3, 2, figsize=(14, 12), dpi=180)
    axes_flat = axes.flatten()
    for ax in axes_flat[len(specs) :]:
        ax.axis("off")

    for idx, spec in enumerate(specs):
        ax = axes_flat[idx]
        curve_rows = curves[spec.key]
        sample_rows = samples[spec.key]
        x_curve = [row["x_value"] for row in curve_rows]
        y_curve = [row[metric_key] for row in curve_rows]
        x_sample = [row["x_value"] for row in sample_rows]
        y_sample = [row[metric_key] for row in sample_rows]
        display_name = spec.display_name_zh if chinese else spec.display_name
        theory_label = "理论曲线" if chinese else "Theory curve"
        points_label = "给定离散点" if chinese else "Given points"
        xlabel = f"{display_name} ({spec.unit})"

        if chinese and spec.key == "length":
            x_curve = [1.0 / ((row["L_m"] * 100.0) ** 2) for row in curve_rows]
            x_sample = [1.0 / ((row["L_m"] * 100.0) ** 2) for row in sample_rows]
            xlabel = "1/L^2 (cm^-2)"

        ax.plot(x_curve, y_curve, color="#1D3557", linewidth=2.0, label=theory_label)
        ax.scatter(
            x_sample,
            y_sample,
            color="#D1495B",
            s=40,
            zorder=3,
            label=points_label,
        )
        ax.set_title(display_name)
        ax.set_xlabel(xlabel)
        ax.set_ylabel(ylabel)
        ax.grid(True, alpha=0.28)
        ax.legend(loc="best", fontsize=8)

    fig.suptitle(title, fontsize=16)
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    fig.savefig(output_dir / f"{filename_stem}.png")
    fig.savefig(output_dir / f"{filename_stem}.svg")
    plt.close(fig)


def write_metadata(specs: tuple[VariableSpec, ...]) -> None:
    payload = {
        "model": "steel_ruler_theory_mic_2cm",
        "frequency_formula": "f1 = beta1^2 /(2*pi*sqrt(12)) * h/L^2 * sqrt(E/rho)",
        "pressure_formula": "p_rms = C * J * h / L^3 * phi1(x0/L), calibrated to repo 3D-air baseline",
        "constants": {
            "E_Pa": E_PA,
            "rho_kg_m3": RHO_KG_M3,
            "beta1": BETA1,
            "rho_air_kg_m3": RHO_AIR,
            "mic_distance_m": MIC_DISTANCE_M,
            "pressure_reference_pa": P_REF_PA,
            "pressure_calibration_constant": PRESSURE_CALIBRATION,
        },
        "baseline_calibration": {
            "L_m": CAL_L_M,
            "h_m": CAL_H_M,
            "J_Ns": CAL_J_NS,
            "x0_over_L": CAL_XI,
            "p_rms_pa": CAL_P_RMS_PA,
        },
        "variables": [
            {
                "key": spec.key,
                "display_name": spec.display_name,
                "unit": spec.unit,
                "curve_min": spec.curve_min,
                "curve_max": spec.curve_max,
                "curve_step": spec.curve_step,
                "sample_values": list(spec.sample_values),
            }
            for spec in specs
        ],
    }
    with (OUTPUT_ROOT / "summary.json").open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)


def main() -> None:
    configure_font()
    ensure_dirs()

    curves: dict[str, list[dict[str, float]]] = {}
    samples: dict[str, list[dict[str, float]]] = {}

    curve_fields = [
        "x_value",
        "frequency_hz",
        "pressure_rms_pa",
        "spl_db",
        "L_m",
        "b_m",
        "h_m",
        "x0_over_L",
        "J_Ns",
    ]
    sample_fields = [
        "variable",
        "x_value",
        "x_unit",
        "frequency_hz",
        "pressure_rms_pa",
        "spl_db",
        "L_m",
        "b_m",
        "h_m",
        "x0_over_L",
        "J_Ns",
    ]

    all_sample_rows: list[dict[str, float]] = []
    for spec in VARIABLE_SPECS:
        curve_rows = make_curve_rows(spec)
        sample_rows = make_sample_rows(spec)
        curves[spec.key] = curve_rows
        samples[spec.key] = sample_rows
        all_sample_rows.extend(sample_rows)

        write_csv(CSV_DIR / f"{spec.key}_theory_curve.csv", curve_rows, curve_fields)
        write_csv(CSV_DIR / f"{spec.key}_theory_points.csv", sample_rows, sample_fields)

    write_csv(CSV_DIR / "all_theory_points.csv", all_sample_rows, sample_fields)

    plot_metric_panels(
        VARIABLE_SPECS,
        curves,
        samples,
        metric_key="frequency_hz",
        ylabel="Frequency (Hz)",
        title="Steel ruler theory frequency at microphone position 2 cm",
        filename_stem="frequency_theory_panels",
    )
    plot_metric_panels(
        VARIABLE_SPECS,
        curves,
        samples,
        metric_key="frequency_hz",
        ylabel="频率 (Hz)",
        title="钢尺在麦克风 2 cm 处的理论频率",
        filename_stem="frequency_theory_panels_zh",
        chinese=True,
        output_dir=FIG_ZH_DIR,
    )
    plot_metric_panels(
        VARIABLE_SPECS,
        curves,
        samples,
        metric_key="pressure_rms_pa",
        ylabel="Pressure RMS (Pa)",
        title="Steel ruler theory pressure at microphone position 2 cm",
        filename_stem="pressure_theory_panels",
    )
    plot_metric_panels(
        VARIABLE_SPECS,
        curves,
        samples,
        metric_key="pressure_rms_pa",
        ylabel="声压有效值 (Pa)",
        title="钢尺在麦克风 2 cm 处的理论声压",
        filename_stem="pressure_theory_panels_zh",
        chinese=True,
        output_dir=FIG_ZH_DIR,
    )
    plot_metric_panels(
        VARIABLE_SPECS,
        curves,
        samples,
        metric_key="spl_db",
        ylabel="SPL (dB)",
        title="Steel ruler theory SPL at microphone position 2 cm",
        filename_stem="spl_theory_panels",
    )
    plot_metric_panels(
        VARIABLE_SPECS,
        curves,
        samples,
        metric_key="spl_db",
        ylabel="声压级 SPL (dB)",
        title="钢尺在麦克风 2 cm 处的理论声压级",
        filename_stem="spl_theory_panels_zh",
        chinese=True,
        output_dir=FIG_ZH_DIR,
    )
    write_metadata(VARIABLE_SPECS)

    print(str(CSV_DIR))
    print(str(FIG_DIR))
    print(str(OUTPUT_ROOT / "summary.json"))


if __name__ == "__main__":
    main()
