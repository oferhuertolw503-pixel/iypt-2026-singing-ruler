from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import numpy as np
from matplotlib import font_manager

MIN_TONAL_FREQ_HZ = 20.0
MAX_ANALYSIS_FREQ_HZ = 2500.0
MIN_PEAK_RELATIVE_AMPLITUDE = 0.05
DURATION_RELATIVE_POWER_THRESHOLD = 0.10

VARIABLE_SPECS = {
    "L_free": {
        "title": "自由端长度",
        "xlabel": "1 / L² (1/cm²)",
        "expected": [10, 14, 18, 22, 26],
        "fixed": "固定：x0=0.8L，b=3 cm，h=2 mm，J=0.04 N*s",
        "x_transform": "inverse_square",
    },
    "b": {
        "title": "宽度",
        "xlabel": "宽度 b (cm)",
        "expected": [1, 2, 3, 4, 5],
        "fixed": "固定：L=20 cm，x0=0.8L，h=2 mm，J=0.04 N*s",
    },
    "h": {
        "title": "厚度",
        "xlabel": "厚度 h (mm)",
        "expected": [1, 2, 3, 4, 5],
        "fixed": "固定：L=20 cm，x0=0.8L，b=3 cm，J=0.04 N*s",
    },
    "x0_ratio": {
        "title": "撞击位置",
        "xlabel": "撞击位置 x0/L",
        "expected": [0.25, 0.5, 0.75],
        "fixed": "固定：L=20 cm，b=3 cm，h=2 mm，J=0.04 N*s",
    },
    "J": {
        "title": "冲量",
        "xlabel": "冲量 J (N*s)",
        "expected": [0.02, 0.04, 0.06, 0.08],
        "fixed": "固定：L=20 cm，x0=0.8L，b=3 cm，h=2 mm",
    },
}

MATERIAL_LABELS = {
    "steel": "钢尺",
    "pvc": "PVC",
    "xuefu_board": "雪弗板",
    "acrylic": "亚克力板",
    "satinwood": "缎木板",
}


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


def read_numeric_csv(path: Path) -> tuple[list[str], np.ndarray]:
    header: list[str] | None = None
    rows: list[list[float]] = []

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith("%"):
                header = [item.strip() for item in line[1:].split(",")]
                continue
            parts = [item.strip() for item in line.split(",")]
            try:
                rows.append([float(item) for item in parts])
            except ValueError:
                header = parts

    if rows:
        data = np.asarray(rows, dtype=float)
        if data.ndim == 1:
            data = data.reshape(1, -1)
    else:
        data = np.zeros((0, len(header) if header else 0), dtype=float)

    if header is None:
        header = [f"col{i + 1}" for i in range(data.shape[1])]
    return header, data


def single_sided_amplitude(
    t_s: np.ndarray,
    signal: np.ndarray,
    nfft: int = 16384,
) -> tuple[np.ndarray, np.ndarray]:
    if t_s.size < 3 or signal.size < 3:
        return np.asarray([]), np.asarray([])

    dt = float(np.median(np.diff(t_s)))
    centered = signal - np.mean(signal)
    window = np.hanning(centered.size)
    scale = float(np.sum(window))
    if scale <= 0:
        return np.asarray([]), np.asarray([])

    spectrum = np.fft.rfft(centered * window, n=nfft)
    freq_hz = np.fft.rfftfreq(nfft, d=dt)
    amplitude = 2.0 * np.abs(spectrum) / scale
    if amplitude.size:
        amplitude[0] *= 0.5
    return freq_hz, amplitude


def dominant_peak(
    t_s: np.ndarray,
    pressure_pa: np.ndarray,
    min_freq_hz: float = MIN_TONAL_FREQ_HZ,
    max_freq_hz: float = MAX_ANALYSIS_FREQ_HZ,
) -> tuple[float, float]:
    freq_hz, amplitude = single_sided_amplitude(t_s, pressure_pa)
    if freq_hz.size == 0:
        return float("nan"), float("nan")

    mask = (freq_hz >= min_freq_hz) & (freq_hz <= max_freq_hz)
    if not np.any(mask):
        return float("nan"), float("nan")

    cropped_freq = freq_hz[mask]
    cropped_amp = amplitude[mask]
    peak_index = int(np.argmax(cropped_amp))
    return float(cropped_freq[peak_index]), float(cropped_amp[peak_index])


def pressure_metrics(t_s: np.ndarray, pressure_pa: np.ndarray) -> dict[str, float]:
    f_dom_hz, f_dom_amp_pa = dominant_peak(t_s, pressure_pa)
    centered = pressure_pa - np.mean(pressure_pa)
    p_rms_pa = float(np.sqrt(np.mean(np.square(centered))))
    p_pp_pa = float(np.max(pressure_pa) - np.min(pressure_pa))
    p_peak_abs_pa = float(np.max(np.abs(pressure_pa)))
    spl_db = float(20.0 * np.log10(max(p_rms_pa, 1e-30) / 20e-6))
    return {
        "f_dom_hz": f_dom_hz,
        "f_dom_amp_pa": f_dom_amp_pa,
        "p_rms_pa": p_rms_pa,
        "p_pp_pa": p_pp_pa,
        "p_peak_abs_pa": p_peak_abs_pa,
        "spl_db": spl_db,
    }


def select_main_peaks(
    freq_hz: np.ndarray,
    amplitude_pa: np.ndarray,
    count: int = 6,
    min_freq_hz: float = MIN_TONAL_FREQ_HZ,
    max_freq_hz: float = MAX_ANALYSIS_FREQ_HZ,
    min_relative_amplitude: float = MIN_PEAK_RELATIVE_AMPLITUDE,
) -> np.ndarray:
    mask = (freq_hz >= min_freq_hz) & (freq_hz <= max_freq_hz)
    cropped_freq = freq_hz[mask]
    cropped_amp = amplitude_pa[mask]
    if cropped_freq.size < 3:
        return np.asarray([], dtype=float)

    local_maxima = np.where(
        (cropped_amp[1:-1] > cropped_amp[:-2]) & (cropped_amp[1:-1] >= cropped_amp[2:])
    )[0] + 1
    if local_maxima.size == 0:
        local_maxima = np.arange(cropped_freq.size)

    strongest = float(np.max(cropped_amp[local_maxima])) if local_maxima.size else 0.0
    if strongest <= 0.0:
        return np.asarray([], dtype=float)
    local_maxima = local_maxima[cropped_amp[local_maxima] >= min_relative_amplitude * strongest]
    if local_maxima.size == 0:
        return np.asarray([], dtype=float)

    ranked = local_maxima[np.argsort(cropped_amp[local_maxima])[::-1]]
    selected = sorted(float(cropped_freq[index]) for index in ranked[:count])
    return np.asarray(selected, dtype=float)


def peak_duration(
    t_s: np.ndarray,
    pressure_pa: np.ndarray,
    peaks_hz: np.ndarray,
    window_s: float = 0.03,
    hop_s: float = 0.002,
    nfft: int = 8192,
    relative_power_threshold: float = DURATION_RELATIVE_POWER_THRESHOLD,
    min_freq_hz: float = MIN_TONAL_FREQ_HZ,
    max_freq_hz: float = MAX_ANALYSIS_FREQ_HZ,
) -> tuple[np.ndarray, np.ndarray]:
    if peaks_hz.size == 0 or t_s.size < 3:
        return np.asarray([]), np.asarray([])

    dt = float(np.median(np.diff(t_s)))
    fs = 1.0 / dt
    band_limit_hz = min(max_freq_hz, fs / 2.0)
    peaks_hz = peaks_hz[(peaks_hz >= min_freq_hz) & (peaks_hz <= band_limit_hz)]
    if peaks_hz.size == 0:
        return np.asarray([]), np.asarray([])

    window_n = min(pressure_pa.size, max(8, int(round(window_s * fs))))
    hop_n = max(1, int(round(hop_s * fs)))
    window = np.hanning(window_n)
    freq_hz = np.fft.rfftfreq(nfft, d=dt)
    midpoints = (peaks_hz[:-1] + peaks_hz[1:]) / 2.0
    edges_hz = np.concatenate(([min_freq_hz], midpoints, [band_limit_hz]))

    band_masks = []
    for index in range(peaks_hz.size):
        if index == peaks_hz.size - 1:
            band_masks.append((freq_hz >= edges_hz[index]) & (freq_hz <= edges_hz[index + 1]))
        else:
            band_masks.append((freq_hz >= edges_hz[index]) & (freq_hz < edges_hz[index + 1]))

    power_rows: list[list[float]] = []
    for start in range(0, pressure_pa.size - window_n + 1, hop_n):
        segment = pressure_pa[start : start + window_n]
        centered = segment - np.mean(segment)
        spectrum = np.fft.rfft(centered * window, n=nfft)
        power = np.abs(spectrum) ** 2
        power_rows.append([float(np.sum(power[mask])) for mask in band_masks])

    if not power_rows:
        return np.zeros(peaks_hz.size, dtype=float), edges_hz

    power_array = np.asarray(power_rows, dtype=float)
    durations_s = np.zeros(peaks_hz.size, dtype=float)
    for index in range(peaks_hz.size):
        band_peak_power = float(np.max(power_array[:, index]))
        if band_peak_power > 0:
            active = power_array[:, index] >= relative_power_threshold * band_peak_power
            durations_s[index] = float(np.sum(active) * hop_s)

    return durations_s, edges_hz


def resolve_case_artifact_path(study_root: Path, case_row: dict, key: str) -> str:
    value = str(case_row.get(key, "") or "")
    path = Path(value)
    if value and path.exists():
        return str(path)

    case_id = str(case_row.get("case_id", "") or "")
    filename_by_key = {
        "mph_path": "linear_acoustic_field_3d_air.mph",
        "structure_probe_timeseries_csv": "structure_probe_timeseries.csv",
        "mic_pressure_timeseries_csv": "mic_pressure_timeseries.csv",
        "impact_force_timeseries_csv": "impact_force_timeseries.csv",
        "frequencies_csv": "frequencies.csv",
        "mode_shapes_csv": "mode_shapes.csv",
    }
    filename = filename_by_key.get(key)
    if not case_id or not filename:
        return value

    local_case_dirs = list((study_root / "cases").rglob(case_id))
    if not local_case_dirs:
        return value

    candidates = list(local_case_dirs[0].rglob(filename))
    if candidates:
        return str(candidates[0])
    return value


def resolve_case_artifact_paths(study_root: Path, case_row: dict) -> dict:
    row = dict(case_row)
    for key in (
        "mph_path",
        "frequencies_csv",
        "structure_probe_timeseries_csv",
        "mic_pressure_timeseries_csv",
        "impact_force_timeseries_csv",
        "mode_shapes_csv",
    ):
        row[key] = resolve_case_artifact_path(study_root, row, key)
    return row


def case_outputs_complete(case_row: dict) -> bool:
    required_keys = (
        "mph_path",
        "structure_probe_timeseries_csv",
        "mic_pressure_timeseries_csv",
        "impact_force_timeseries_csv",
    )
    for key in required_keys:
        path_value = case_row.get(key, "")
        if not path_value:
            return False
        if not Path(path_value).exists():
            return False
    return True


def case_csv_outputs_available(case_row: dict) -> bool:
    required_keys = (
        "structure_probe_timeseries_csv",
        "mic_pressure_timeseries_csv",
        "impact_force_timeseries_csv",
    )
    for key in required_keys:
        path_value = case_row.get(key, "")
        if not path_value or not Path(path_value).exists():
            return False
    return True


def load_cases(study_root: Path) -> tuple[dict, list[dict]]:
    with (study_root / "study_manifest.json").open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)

    rows: list[dict] = []
    for case in manifest.get("cases", []):
        row = dict(case)
        row["status"] = "missing"
        row.update(
            {
                "f_dom_hz": float("nan"),
                "f_dom_amp_pa": float("nan"),
                "p_rms_pa": float("nan"),
                "p_pp_pa": float("nan"),
                "p_peak_abs_pa": float("nan"),
                "spl_db": float("nan"),
                "force_impulse_integral_Ns": float("nan"),
            }
        )

        row = resolve_case_artifact_paths(study_root, row)

        mic_path = Path(row.get("mic_pressure_timeseries_csv", ""))
        if mic_path.exists():
            _, mic = read_numeric_csv(mic_path)
            if mic.ndim == 2 and mic.shape[0] > 4 and mic.shape[1] >= 2:
                row.update(pressure_metrics(mic[:, 0], mic[:, 1]))
                row["status"] = "incomplete"

        force_path = Path(row.get("impact_force_timeseries_csv", ""))
        if force_path.exists():
            _, force = read_numeric_csv(force_path)
            if force.ndim == 2 and force.shape[0] > 4 and force.shape[1] >= 2:
                row["force_impulse_integral_Ns"] = float(np.trapezoid(force[:, 1], force[:, 0]))

        row["csv_outputs_available"] = case_csv_outputs_available(row)
        row["full_case_outputs_complete"] = case_outputs_complete(row)
        if row["csv_outputs_available"]:
            row["status"] = "completed"

        rows.append(row)

    return manifest, rows


def write_cases_table(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "case_id",
        "group",
        "requested_role",
        "material_key",
        "material_name",
        "primary_variable",
        "value",
        "value_unit",
        "public_requested_quality",
        "effective_quality",
        "effective_model_quality",
        "internal_profile_label",
        "modal_exports_skipped",
        "L_free_cm",
        "b_cm",
        "h_mm",
        "x0_ratio",
        "J_Ns",
        "status",
        "csv_outputs_available",
        "full_case_outputs_complete",
        "f_dom_hz",
        "f_dom_amp_pa",
        "p_rms_pa",
        "p_pp_pa",
        "p_peak_abs_pa",
        "spl_db",
        "force_impulse_integral_Ns",
        "output_root",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})


def compute_material_duration_rows(rows: list[dict]) -> list[dict]:
    duration_rows: list[dict] = []
    for row in rows:
        if (
            row.get("primary_variable") != "material"
            or row.get("status") != "completed"
            or not row.get("csv_outputs_available")
        ):
            continue

        mic_path = Path(row["mic_pressure_timeseries_csv"])
        _, mic = read_numeric_csv(mic_path)
        if mic.ndim != 2 or mic.shape[0] < 4 or mic.shape[1] < 2:
            continue

        t_s = mic[:, 0]
        pressure_pa = mic[:, 1]
        freq_hz, amplitude_pa = single_sided_amplitude(t_s, pressure_pa)
        peaks_hz = select_main_peaks(freq_hz, amplitude_pa, count=6)
        durations_s, edges_hz = peak_duration(t_s, pressure_pa, peaks_hz)

        for index, peak_hz in enumerate(peaks_hz):
            duration_rows.append(
                {
                    "material_key": row.get("material_key", ""),
                    "material_name": MATERIAL_LABELS.get(
                        row.get("material_key", ""),
                        row.get("material_name", ""),
                    ),
                    "peak_rank": index + 1,
                    "freq_hz": float(peak_hz),
                    "duration_s": float(durations_s[index]) if index < len(durations_s) else float("nan"),
                    "band_low_hz": float(edges_hz[index]) if index < len(edges_hz) - 1 else float("nan"),
                    "band_high_hz": float(edges_hz[index + 1]) if index < len(edges_hz) - 1 else float("nan"),
                    "source_case_id": row.get("case_id", ""),
                }
            )
    return duration_rows


def write_material_duration_table(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "material_key",
        "material_name",
        "peak_rank",
        "freq_hz",
        "duration_s",
        "band_low_hz",
        "band_high_hz",
        "source_case_id",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})


def plot_timbre_materials(
    figures_dir: Path,
    material_keys: list[str],
    case_by_material: dict[str, dict],
) -> Path:
    output_path = figures_dir / "timbre_material_frequency_distribution.png"
    fig, axes = plt.subplots(3, 2, figsize=(13.2, 10.5), dpi=180)
    flat_axes = axes.ravel()

    for ax, material_key in zip(flat_axes, material_keys):
        row = case_by_material.get(material_key)
        label = MATERIAL_LABELS.get(material_key, material_key)
        if row and row.get("status") == "completed":
            _, mic = read_numeric_csv(Path(row["mic_pressure_timeseries_csv"]))
            freq_hz, amplitude_pa = single_sided_amplitude(mic[:, 0], mic[:, 1])
            mask = freq_hz <= MAX_ANALYSIS_FREQ_HZ
            ax.axvspan(0.0, MIN_TONAL_FREQ_HZ, color="#F2CC8F", alpha=0.28, zorder=0)
            ax.plot(freq_hz[mask], amplitude_pa[mask], color="#1D3557", linewidth=1.5)
            ax.set_xlim(0.0, MAX_ANALYSIS_FREQ_HZ)
            ax.text(
                0.02,
                0.92,
                "0-20 Hz：包络/漂移区，不作为音调主峰",
                transform=ax.transAxes,
                fontsize=7,
                color="#6C584C",
                ha="left",
            )
            valid_tonal_peak = np.isfinite(row["f_dom_hz"]) and np.isfinite(row["f_dom_amp_pa"])
            if not valid_tonal_peak:
                ax.text(
                    0.54,
                    0.84,
                    "20-2500 Hz no valid tonal peak",
                    transform=ax.transAxes,
                    fontsize=8,
                    color="#D1495B",
                    ha="center",
                )
            if valid_tonal_peak:
                ax.scatter([row["f_dom_hz"]], [row["f_dom_amp_pa"]], color="#D1495B", s=28, zorder=4)
                ax.text(
                    row["f_dom_hz"],
                    row["f_dom_amp_pa"],
                    f"主峰 {row['f_dom_hz']:.1f} Hz",
                    fontsize=8,
                    ha="left",
                    va="bottom",
                )
            ax.set_title(f"{label}：频率分布图")
            ax.set_xlabel("频率 (Hz)")
            ax.set_ylabel("幅值 (Pa)")
            ax.grid(True, alpha=0.25)
        else:
            ax.set_title(f"{label}：未完成")
            ax.text(
                0.5,
                0.5,
                "暂无已完成的 COMSOL case\n不绘制伪频谱",
                transform=ax.transAxes,
                ha="center",
                va="center",
                color="#D1495B",
                fontsize=12,
            )
            ax.set_axis_off()

    for ax in flat_axes[len(material_keys) :]:
        ax.set_axis_off()

    fig.suptitle(
        "音色：材料麦克风频率分布",
        fontsize=16,
    )
    fig.text(
        0.5,
        0.015,
        "主峰标记使用 20-2500 Hz 麦克风 FFT；0-20 Hz 仅显示，不作为音调。",
        ha="center",
        fontsize=9,
    )
    fig.tight_layout(rect=(0, 0.04, 1, 0.96))
    fig.savefig(output_path)
    plt.close(fig)
    return output_path


def plot_material_duration_panels(
    figures_dir: Path,
    duration_rows: list[dict],
    material_keys: list[str],
) -> Path:
    output_path = figures_dir / "timbre_material_frequency_duration_panels.png"
    fig, axes = plt.subplots(3, 2, figsize=(13.2, 10.5), dpi=180)
    flat_axes = axes.ravel()

    for ax, material_key in zip(flat_axes, material_keys):
        label = MATERIAL_LABELS.get(material_key, material_key)
        selected = [row for row in duration_rows if row["material_key"] == material_key]
        selected.sort(key=lambda row: row["peak_rank"])
        if not selected:
            ax.set_title(f"{label}：未完成")
            ax.text(
                0.5,
                0.5,
                "暂无频率持续时间数据",
                transform=ax.transAxes,
                ha="center",
                va="center",
                color="#D1495B",
                fontsize=12,
            )
            ax.set_axis_off()
            continue

        labels = [f"p{row['peak_rank']}\n{row['freq_hz']:.1f} Hz" for row in selected]
        values = [row["duration_s"] for row in selected]
        bars = ax.bar(labels, values, color="#1D3557", edgecolor="#222222", linewidth=0.5)
        for bar, row in zip(bars, selected):
            ax.text(
                bar.get_x() + bar.get_width() / 2.0,
                bar.get_height() + 0.001,
                f"{row['duration_s']:.3f} s",
                ha="center",
                va="bottom",
                fontsize=8,
            )
        ax.set_title(f"{label}：有效接收频率持续时间")
        ax.set_xlabel("有效接收频率 (20-2500 Hz)")
        ax.set_ylabel("持续时间 (s)")
        ax.grid(axis="y", alpha=0.25)

    for ax in flat_axes[len(material_keys) :]:
        ax.set_axis_off()

    fig.suptitle(
        "音色：各材料主要接收频率持续时间",
        fontsize=16,
    )
    fig.text(
        0.5,
        0.015,
        "持续时间只统计 20-2500 Hz 有效峰；峰幅值 >= 有效频段最强峰的 5%，活跃功率 >= 该频带峰值的 10%。",
        ha="center",
        fontsize=9,
    )
    fig.tight_layout(rect=(0, 0.04, 1, 0.96))
    fig.savefig(output_path)
    plt.close(fig)
    return output_path


def plot_steel_peak_duration(figures_dir: Path, duration_rows: list[dict]) -> Path:
    output_path = figures_dir / "timbre_steel_frequency_duration.png"
    fig, ax = plt.subplots(figsize=(11.5, 6.0), dpi=180)
    selected = [row for row in duration_rows if row["material_key"] == "steel"]
    selected.sort(key=lambda row: row["peak_rank"])

    if not selected:
        ax.text(
            0.5,
            0.5,
            "钢尺频率持续时间数据尚未完成",
            ha="center",
            va="center",
            transform=ax.transAxes,
            fontsize=13,
        )
        ax.set_axis_off()
    else:
        labels = [f"p{row['peak_rank']}\n{row['freq_hz']:.1f} Hz" for row in selected]
        bars = ax.bar(
            labels,
            [row["duration_s"] for row in selected],
            color="#1D3557",
            edgecolor="#222222",
            linewidth=0.5,
        )
        for bar, row in zip(bars, selected):
            ax.text(
                bar.get_x() + bar.get_width() / 2.0,
                bar.get_height() + 0.001,
                f"{row['duration_s']:.3f} s",
                ha="center",
                va="bottom",
                fontsize=9,
            )
        ax.set_title("钢尺：有效接收频率持续时间")
        ax.set_xlabel("有效接收频率 (20-2500 Hz)")
        ax.set_ylabel("持续时间 (s)")
        ax.grid(axis="y", alpha=0.28)

    fig.text(
        0.5,
        0.015,
        "持续时间只统计 20-2500 Hz 的钢尺有效峰；0-20 Hz 低频包络/漂移不计入。",
        ha="center",
        fontsize=9,
    )
    fig.tight_layout(rect=(0, 0.04, 1, 1.0))
    fig.savefig(output_path)
    plt.close(fig)
    return output_path


def plot_scan_metric(
    figures_dir: Path,
    rows: list[dict],
    metric: str,
    ylabel: str,
    title: str,
    filename: str,
) -> Path:
    output_path = figures_dir / filename
    fig, axes = plt.subplots(2, 3, figsize=(15.0, 8.8), dpi=180)
    flat_axes = axes.ravel()

    for ax, (variable, spec) in zip(flat_axes, VARIABLE_SPECS.items()):
        selected = [
            row
            for row in rows
            if row.get("primary_variable") == variable and row.get("material_key") == "steel"
        ]
        completed = [
            row
            for row in selected
            if row["status"] == "completed" and np.isfinite(row.get(metric, float("nan")))
        ]
        completed.sort(key=lambda row: float(row["value"]))
        raw_x_values = np.asarray([float(row["value"]) for row in completed], dtype=float)
        if spec.get("x_transform") == "inverse_square":
            x_values = 1.0 / np.square(raw_x_values)
        else:
            x_values = raw_x_values
        y_values = np.asarray([float(row[metric]) for row in completed], dtype=float)

        if x_values.size:
            ax.plot(x_values, y_values, marker="o", markersize=6, linewidth=1.8, color="#1D3557")
            for x_value, y_value in zip(x_values, y_values):
                label = f"{y_value:.1f}" if abs(y_value) >= 10.0 else f"{y_value:.3g}"
                ax.text(x_value, y_value, label, ha="center", va="bottom", fontsize=8)
        else:
            ax.text(
                0.5,
                0.55,
                "无已完成 COMSOL case",
                transform=ax.transAxes,
                ha="center",
                va="center",
                color="#D1495B",
                fontsize=10,
            )

        expected_values = np.asarray(spec["expected"], dtype=float)
        if spec.get("x_transform") == "inverse_square":
            tick_values = 1.0 / np.square(expected_values)
            tick_labels = [f"{value:.4f}" for value in tick_values]
        else:
            tick_values = expected_values
            tick_labels = [f"{value:g}" for value in expected_values]
        missing_values = [
            value
            for value in expected_values
            if not any(
                abs(float(row["value"]) - float(value)) < 1e-9 and row["status"] == "completed"
                for row in selected
            )
        ]

        if missing_values:
            ax.text(
                0.5,
                0.88,
                "缺失: " + ", ".join(f"{value:g}" for value in missing_values),
                transform=ax.transAxes,
                ha="center",
                color="#D1495B",
                fontsize=9,
            )

        ax.set_title(spec["title"])
        ax.set_xlabel(spec["xlabel"])
        ax.set_ylabel(ylabel)
        ax.set_xticks(tick_values)
        ax.set_xticklabels(tick_labels)
        ax.grid(True, alpha=0.28)
        ax.text(0.5, -0.28, spec["fixed"], transform=ax.transAxes, ha="center", va="top", fontsize=8)

    flat_axes[-1].set_axis_off()
    fig.suptitle(title, fontsize=16)
    fig.text(
        0.5,
        0.015,
        "只绘制已完成 COMSOL case；不补点、不插值。频率为 20-2500 Hz 麦克风有效主峰；声压为 coarse RMS 趋势量。",
        ha="center",
        fontsize=10,
    )
    fig.tight_layout(rect=(0, 0.04, 1, 0.96))
    fig.savefig(output_path)
    plt.close(fig)
    return output_path


def plot_impulse_force(figures_dir: Path, rows: list[dict]) -> Path:
    output_path = figures_dir / "impulse_force_time.png"
    impulse_rows = [
        row
        for row in rows
        if row.get("primary_variable") == "J"
        and row.get("material_key") == "steel"
        and row["status"] == "completed"
        and Path(row["impact_force_timeseries_csv"]).exists()
    ]
    baseline_rows = [
        row
        for row in rows
        if row.get("material_key") == "steel"
        and row["status"] == "completed"
        and abs(float(row.get("J_Ns", 0.0)) - 0.04) < 1e-9
        and Path(row["impact_force_timeseries_csv"]).exists()
    ]
    plot_rows = impulse_rows if impulse_rows else baseline_rows[:1]

    fig, ax = plt.subplots(figsize=(11.5, 6.0), dpi=180)
    if not plot_rows:
        ax.text(
            0.5,
            0.5,
            "暂无可用的 impact_force_timeseries.csv",
            ha="center",
            va="center",
            transform=ax.transAxes,
            fontsize=13,
        )
        ax.set_axis_off()
    else:
        for row in sorted(plot_rows, key=lambda item: float(item.get("J_Ns", 0.0))):
            _, force = read_numeric_csv(Path(row["impact_force_timeseries_csv"]))
            t_ms = force[:, 0] * 1000.0
            force_z = force[:, 1]
            impulse = float(np.trapezoid(force_z, force[:, 0]))
            ax.plot(
                t_ms,
                force_z,
                linewidth=1.8,
                label=f"J={row.get('J_Ns')} N*s，积分 {impulse:.4g} N*s",
            )
        ax.set_title("冲量的力-时间图像")
        ax.set_xlabel("时间 (ms)")
        ax.set_ylabel("厚度方向力 Force_z (N)")
        ax.grid(True, alpha=0.28)
        ax.legend(fontsize=9)

    fig.tight_layout()
    fig.savefig(output_path)
    plt.close(fig)
    return output_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--study-root", required=True)
    args = parser.parse_args()

    configure_font()
    study_root = Path(args.study_root).resolve()
    figures_dir = study_root / "figures"
    tables_dir = study_root / "tables"
    figures_dir.mkdir(parents=True, exist_ok=True)
    tables_dir.mkdir(parents=True, exist_ok=True)

    manifest, rows = load_cases(study_root)
    write_cases_table(tables_dir / "all_requested_cases.csv", rows)

    duration_rows = compute_material_duration_rows(rows)
    write_material_duration_table(tables_dir / "material_frequency_duration_long.csv", duration_rows)

    material_keys = [material["key"] for material in manifest.get("materials", [])]
    case_by_material = {
        row["material_key"]: row
        for row in rows
        if row.get("primary_variable") == "material"
    }

    figures = {
        "timbre_material_frequency_distribution": plot_timbre_materials(
            figures_dir, material_keys, case_by_material
        ),
        "timbre_material_frequency_duration_panels": plot_material_duration_panels(
            figures_dir, duration_rows, material_keys
        ),
        "timbre_steel_frequency_duration": plot_steel_peak_duration(figures_dir, duration_rows),
        "steel_pitch_frequency_scan": plot_scan_metric(
            figures_dir,
            rows,
            "f_dom_hz",
            "麦克风有效主峰频率 (Hz)",
            "频率（钢尺，麦克风 2 cm 处）",
            "steel_pitch_frequency_scan.png",
        ),
        "steel_sound_pressure_scan": plot_scan_metric(
            figures_dir,
            rows,
            "p_rms_pa",
            "麦克风声压 RMS (Pa)",
            "声压（钢尺，麦克风 2 cm 处）",
            "steel_sound_pressure_scan.png",
        ),
        "impulse_force_time": plot_impulse_force(figures_dir, rows),
    }

    completed_rows = [row for row in rows if row["status"] == "completed"]
    incomplete_rows = [row for row in rows if row["status"] == "incomplete"]
    summary = {
        "study_root": str(study_root),
        "study_id": manifest.get("study_id"),
        "truth_policy": manifest.get("truth_policy"),
        "microphone_frequency_postprocess": {
            "source": "mic_pressure_timeseries.csv",
            "tonal_peak_band_hz": [MIN_TONAL_FREQ_HZ, MAX_ANALYSIS_FREQ_HZ],
            "low_frequency_policy": "0-20 Hz is shown in spectra but excluded from pitch/duration peaks.",
            "duration_peak_min_relative_amplitude": MIN_PEAK_RELATIVE_AMPLITUDE,
            "duration_active_relative_power_threshold": DURATION_RELATIVE_POWER_THRESHOLD,
            "pressure_metric": "p_rms_pa is a coarse microphone RMS trend, not a monotonic physical law.",
        },
        "case_count": len(rows),
        "completed_case_count": len(completed_rows),
        "incomplete_case_count": len(incomplete_rows),
        "missing_case_count": len(rows) - len(completed_rows) - len(incomplete_rows),
        "outputs": {
            "all_requested_cases_csv": str(tables_dir / "all_requested_cases.csv"),
            "material_frequency_duration_long_csv": str(tables_dir / "material_frequency_duration_long.csv"),
            "figures": {key: str(path) for key, path in figures.items()},
        },
    }

    with (study_root / "summary.json").open("w", encoding="utf-8") as handle:
        json.dump(summary, handle, ensure_ascii=False, indent=2)

    print(tables_dir / "all_requested_cases.csv")
    print(tables_dir / "material_frequency_duration_long.csv")
    for path in figures.values():
        print(path)
    print(study_root / "summary.json")


if __name__ == "__main__":
    main()
