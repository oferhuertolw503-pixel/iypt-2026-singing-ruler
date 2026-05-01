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
from matplotlib import colors, font_manager
from matplotlib.ticker import AutoMinorLocator


ROOT = Path(__file__).resolve().parents[1]
THEORY_CSV_DIR = ROOT / "outputs" / "requested_theory_steel_mic2cm" / "csv"
OUTPUT_DIR = ROOT / "outputs" / "requested_theory_steel_mic2cm" / "figures" / "zh"
MATERIAL_CONFIG_DIR = (
    ROOT
    / "outputs"
    / "linear"
    / "requested_3d_air"
    / "requested_3d_air_accel_check"
    / "configs"
)

BETA1 = 1.875104068711961
MATERIAL_LENGTH_M = 0.15
MATERIAL_THICKNESS_M = 0.002


LENGTH_EXPERIMENT = [
    {"length_cm": 10.0, "trials": [163.24, 164.09, 163.67, 160.64, 164.58], "mean": 163.24},
    {"length_cm": 12.0, "trials": [114.55, 113.23, 114.02, 112.65, 112.99], "mean": 113.49},
    {"length_cm": 14.0, "trials": [83.56, 83.63, 82.97, 83.33, 83.24], "mean": 83.35},
    {"length_cm": 16.0, "trials": [64.49, 63.33, 62.88, 64.83, 64.96], "mean": 64.10},
    {"length_cm": 18.0, "trials": [50.68, 50.63, 50.83, 51.05, 50.13], "mean": 50.66},
]

THICKNESS_EXPERIMENT = [
    {"thickness_mm": 1.0, "trials": [36.45, 36.10, 36.13, 36.36, 36.42], "mean": 36.29},
    {"thickness_mm": 2.0, "trials": [73.31, 72.38, 71.53, 72.20, 72.66], "mean": 72.42},
    {"thickness_mm": 3.0, "trials": [108.89, 109.21, 108.73, 108.41, 108.52], "mean": 108.75},
    {"thickness_mm": 4.0, "trials": [145.20, 146.48, 142.78, 144.28, 144.52], "mean": 144.65},
    {"thickness_mm": 5.0, "trials": [181.42, 179.30, 183.12, 182.32, 182.67], "mean": 181.77},
]

MATERIAL_EXPERIMENT = [
    {"label": "钢板", "config_name": "material_steel.json", "trials": [71.37, 72.86, 73.03, 73.20, 73.55], "mean": 72.80},
    {"label": "亚克力板", "config_name": "material_acrylic.json", "trials": [24.26, 23.90, 23.22, 23.82, 23.56], "mean": 23.75},
    {"label": "PVC板", "config_name": "material_pvc.json", "trials": [20.11, 20.79, 20.37, 19.82, 20.45], "mean": 20.31},
    {"label": "雪弗板", "config_name": "material_xuefu_board.json", "trials": [17.80, 17.96, 18.27, 18.36, 18.12], "mean": 18.10},
    {"label": "椴木板", "config_name": "material_satinwood.json", "trials": [66.09, 65.18, 65.14, 66.81, 67.21], "mean": 66.09},
]


@dataclass(frozen=True)
class PlotData:
    theory_x: np.ndarray
    theory_y: np.ndarray
    scatter_x: np.ndarray
    scatter_y: np.ndarray
    mean_x: np.ndarray
    mean_y: np.ndarray


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
    matplotlib.rcParams["svg.fonttype"] = "none"


def ensure_dirs() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def read_dict_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def parse_numeric_value(value: str) -> float:
    return float(value.split("[", 1)[0])


def beam_frequency_hz(sqrt_e_over_rho: float, length_m: float, thickness_m: float) -> float:
    coefficient = (BETA1**2) / (2.0 * math.pi * math.sqrt(12.0))
    return coefficient * (thickness_m / (length_m**2)) * sqrt_e_over_rho


def build_length_plot_data() -> PlotData:
    rows = read_dict_rows(THEORY_CSV_DIR / "length_theory_curve.csv")
    theory_pairs: list[tuple[float, float]] = []
    for row in rows:
        length_cm = float(row["x_value"])
        if 10.0 <= length_cm <= 18.0:
            theory_pairs.append((1.0 / (length_cm**2), float(row["frequency_hz"])))
    theory_pairs.sort(key=lambda item: item[0])

    experiment_pairs = []
    for item in LENGTH_EXPERIMENT:
        inv_l2 = 1.0 / (item["length_cm"] ** 2)
        experiment_pairs.append((inv_l2, item["trials"], item["mean"]))
    experiment_pairs.sort(key=lambda item: item[0])

    scatter_x: list[float] = []
    scatter_y: list[float] = []
    mean_x: list[float] = []
    mean_y: list[float] = []
    for inv_l2, trials, mean in experiment_pairs:
        scatter_x.extend([inv_l2] * len(trials))
        scatter_y.extend(trials)
        mean_x.append(inv_l2)
        mean_y.append(mean)

    return PlotData(
        theory_x=np.asarray([item[0] for item in theory_pairs], dtype=float),
        theory_y=np.asarray([item[1] for item in theory_pairs], dtype=float),
        scatter_x=np.asarray(scatter_x, dtype=float),
        scatter_y=np.asarray(scatter_y, dtype=float),
        mean_x=np.asarray(mean_x, dtype=float),
        mean_y=np.asarray(mean_y, dtype=float),
    )


def build_thickness_plot_data() -> PlotData:
    rows = read_dict_rows(THEORY_CSV_DIR / "thickness_theory_curve.csv")
    theory_pairs = []
    for row in rows:
        thickness_mm = float(row["x_value"])
        if 1.0 <= thickness_mm <= 5.0:
            theory_pairs.append((thickness_mm, float(row["frequency_hz"])))
    theory_pairs.sort(key=lambda item: item[0])

    scatter_x: list[float] = []
    scatter_y: list[float] = []
    mean_x: list[float] = []
    mean_y: list[float] = []
    for item in THICKNESS_EXPERIMENT:
        scatter_x.extend([item["thickness_mm"]] * len(item["trials"]))
        scatter_y.extend(item["trials"])
        mean_x.append(item["thickness_mm"])
        mean_y.append(item["mean"])

    return PlotData(
        theory_x=np.asarray([item[0] for item in theory_pairs], dtype=float),
        theory_y=np.asarray([item[1] for item in theory_pairs], dtype=float),
        scatter_x=np.asarray(scatter_x, dtype=float),
        scatter_y=np.asarray(scatter_y, dtype=float),
        mean_x=np.asarray(mean_x, dtype=float),
        mean_y=np.asarray(mean_y, dtype=float),
    )


def build_material_plot_data() -> PlotData:
    material_points = []
    for item in MATERIAL_EXPERIMENT:
        config_path = MATERIAL_CONFIG_DIR / item["config_name"]
        with config_path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
        material = payload["material"]
        rho = parse_numeric_value(material["rho"])
        elastic = parse_numeric_value(material["E"])
        sqrt_e_over_rho = math.sqrt(elastic / rho)
        frequency_hz = beam_frequency_hz(sqrt_e_over_rho, MATERIAL_LENGTH_M, MATERIAL_THICKNESS_M)
        material_points.append(
            {
                "label": item["label"],
                "sqrt_e_over_rho": sqrt_e_over_rho,
                "theory_frequency_hz": frequency_hz,
                "trials": item["trials"],
                "mean": item["mean"],
            }
        )

    material_points.sort(key=lambda item: item["sqrt_e_over_rho"])

    x_min = material_points[0]["sqrt_e_over_rho"]
    x_max = material_points[-1]["sqrt_e_over_rho"]
    theory_x = np.linspace(x_min, x_max, 400)
    theory_y = np.asarray(
        [beam_frequency_hz(value, MATERIAL_LENGTH_M, MATERIAL_THICKNESS_M) for value in theory_x],
        dtype=float,
    )

    scatter_x: list[float] = []
    scatter_y: list[float] = []
    mean_x: list[float] = []
    mean_y: list[float] = []
    for item in material_points:
        scatter_x.extend([item["sqrt_e_over_rho"]] * len(item["trials"]))
        scatter_y.extend(item["trials"])
        mean_x.append(item["sqrt_e_over_rho"])
        mean_y.append(item["mean"])

    validate_material_theory_points(material_points)

    return PlotData(
        theory_x=np.asarray(theory_x, dtype=float),
        theory_y=np.asarray(theory_y, dtype=float),
        scatter_x=np.asarray(scatter_x, dtype=float),
        scatter_y=np.asarray(scatter_y, dtype=float),
        mean_x=np.asarray(mean_x, dtype=float),
        mean_y=np.asarray(mean_y, dtype=float),
    )


def validate_material_theory_points(material_points: list[dict[str, float | list[float] | str]]) -> None:
    for item in material_points:
        mean_frequency = float(item["mean"])
        theory_frequency = float(item["theory_frequency_hz"])
        ratio = theory_frequency / mean_frequency
        if ratio < 0.5 or ratio > 1.5:
            raise ValueError(f"Material theory frequency is out of expected range for {item['label']}.")


def validate_plot_data(name: str, data: PlotData) -> None:
    if data.scatter_x.size != 25 or data.scatter_y.size != 25:
        raise ValueError(f"{name}: expected 25 experimental scatter points.")
    if data.mean_x.size != 5 or data.mean_y.size != 5:
        raise ValueError(f"{name}: expected 5 mean points.")
    if not np.all(np.diff(data.theory_x) > 0):
        raise ValueError(f"{name}: theory x values must be strictly increasing.")


def apply_origin_style(ax: plt.Axes) -> None:
    ax.set_facecolor("white")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_linewidth(1.2)
    ax.spines["bottom"].set_linewidth(1.2)
    ax.spines["left"].set_color("black")
    ax.spines["bottom"].set_color("black")
    ax.tick_params(axis="both", which="major", direction="out", length=6, width=1.0, colors="black", labelsize=11)
    ax.tick_params(axis="both", which="minor", direction="out", length=3, width=0.8, colors="black")
    ax.xaxis.set_minor_locator(AutoMinorLocator(2))
    ax.yaxis.set_minor_locator(AutoMinorLocator(2))
    ax.grid(axis="y", which="major", color="#D9D9D9", linewidth=0.6, alpha=0.45)
    ax.grid(axis="x", which="major", visible=False)


def save_plot(data: PlotData, title: str, xlabel: str, filename_stem: str) -> None:
    validate_plot_data(filename_stem, data)

    figure, ax = plt.subplots(figsize=(7.4, 5.4), dpi=220)
    apply_origin_style(ax)

    theory_color = "#102A43"
    mean_color = "#D1495B"
    scatter_edge = colors.to_rgba("#E5989B", alpha=0.7)

    ax.plot(data.theory_x, data.theory_y, color=theory_color, linewidth=2.2, label="理论曲线")
    ax.plot(data.mean_x, data.mean_y, color=mean_color, linewidth=1.8, marker="o", markersize=5.2, markerfacecolor=mean_color, markeredgecolor=mean_color, label="实验平均值")
    ax.scatter(data.scatter_x, data.scatter_y, s=34, facecolors="none", edgecolors=scatter_edge, linewidths=1.1, label="实验数据点", zorder=3)

    ax.set_title(title, fontsize=15, pad=12)
    ax.set_xlabel(xlabel, fontsize=12)
    ax.set_ylabel("基频 f (Hz)", fontsize=12)
    ax.legend(frameon=False, fontsize=10, loc="best")

    figure.subplots_adjust(left=0.13, right=0.98, bottom=0.14, top=0.88)
    png_path = OUTPUT_DIR / f"{filename_stem}.png"
    svg_path = OUTPUT_DIR / f"{filename_stem}.svg"
    figure.savefig(png_path, dpi=320, facecolor="white")
    figure.savefig(svg_path, facecolor="white")
    plt.close(figure)


def main() -> None:
    configure_font()
    ensure_dirs()

    length_data = build_length_plot_data()
    if not np.all((length_data.theory_x >= length_data.mean_x.min()) & (length_data.theory_x <= length_data.mean_x.max())):
        raise ValueError("Length theory curve extends outside the requested experimental range.")

    save_plot(
        data=length_data,
        title="基频 f 随 1/L^2 变化关系图",
        xlabel="1/L^2 (1/cm^2)",
        filename_stem="frequency_vs_invL2_origin_zh",
    )

    thickness_data = build_thickness_plot_data()
    save_plot(
        data=thickness_data,
        title="基频 f 随厚度 h 变化关系图",
        xlabel="厚度 h (mm)",
        filename_stem="frequency_vs_thickness_origin_zh",
    )

    material_data = build_material_plot_data()
    save_plot(
        data=material_data,
        title=r"基频 f 随 $\sqrt{E/\rho}$ 变化关系图",
        xlabel=r"$\sqrt{E/\rho}$ (m/s)",
        filename_stem="frequency_vs_sqrtE_over_rho_origin_zh",
    )

    for stem in (
        "frequency_vs_invL2_origin_zh",
        "frequency_vs_thickness_origin_zh",
        "frequency_vs_sqrtE_over_rho_origin_zh",
    ):
        print(OUTPUT_DIR / f"{stem}.png")
        print(OUTPUT_DIR / f"{stem}.svg")


if __name__ == "__main__":
    main()
