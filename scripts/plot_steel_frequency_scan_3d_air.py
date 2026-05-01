from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import font_manager


def configure_chinese_font() -> None:
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
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith("%"):
                header = [item.strip() for item in line[1:].split(",")]
                continue
            rows.append([float(item.strip()) for item in line.split(",")])
    data = np.asarray(rows, dtype=float)
    if header is None:
        header = [f"col{i + 1}" for i in range(data.shape[1] if data.ndim == 2 else 0)]
    return header, data


def single_sided_amplitude(t: np.ndarray, y: np.ndarray, nfft: int = 16384) -> tuple[np.ndarray, np.ndarray]:
    dt = float(np.median(np.diff(t)))
    centered = y - np.mean(y)
    window = np.hanning(centered.size)
    scale = np.sum(window)
    spectrum = np.fft.rfft(centered * window, n=nfft)
    freq = np.fft.rfftfreq(nfft, d=dt)
    amp = 2.0 * np.abs(spectrum) / scale
    if amp.size:
        amp[0] *= 0.5
    return freq, amp


def dominant_microphone_peak(t: np.ndarray, p: np.ndarray, max_freq_hz: float = 2500.0) -> tuple[float, float]:
    freq, amp = single_sided_amplitude(t, p)
    mask = (freq > 1.0) & (freq <= max_freq_hz)
    if not np.any(mask):
        return float("nan"), float("nan")
    freq_band = freq[mask]
    amp_band = amp[mask]
    idx = int(np.argmax(amp_band))
    return float(freq_band[idx]), float(amp_band[idx])


def collect_cases(study_root: Path) -> list[dict]:
    manifest_path = study_root / "study_manifest.json"
    with manifest_path.open("r", encoding="utf-8") as f:
        manifest = json.load(f)

    rows: list[dict] = []
    for case in manifest.get("cases", []):
        mic_path = Path(case["mic_pressure_timeseries_csv"])
        row = {
            "case_id": case["case_id"],
            "primary_variable": case["primary_variable"],
            "value": float(case["value"]),
            "value_unit": case["value_unit"],
            "L_free_cm": float(case["L_free_cm"]),
            "b_cm": float(case["b_cm"]),
            "h_mm": float(case["h_mm"]),
            "x0_ratio": float(case["x0_ratio"]),
            "J_Ns": float(case["J_Ns"]),
            "mic_offset_cm": float(case["mic_offset_cm"]),
            "output_root": case["output_root"],
            "mic_pressure_timeseries_csv": str(mic_path),
            "status": "missing",
            "f_dom_hz": float("nan"),
            "f_dom_amp_pa": float("nan"),
        }
        if mic_path.exists():
            _, mic = read_numeric_csv(mic_path)
            if mic.size and mic.shape[1] >= 2:
                f_dom, amp_dom = dominant_microphone_peak(mic[:, 0], mic[:, 1])
                row["status"] = "completed"
                row["f_dom_hz"] = f_dom
                row["f_dom_amp_pa"] = amp_dom
        rows.append(row)
    return rows


def write_summary_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "case_id",
        "primary_variable",
        "value",
        "value_unit",
        "L_free_cm",
        "b_cm",
        "h_mm",
        "x0_ratio",
        "J_Ns",
        "mic_offset_cm",
        "status",
        "f_dom_hz",
        "f_dom_amp_pa",
        "mic_pressure_timeseries_csv",
        "output_root",
    ]
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in fieldnames})


def plot_pitch_overview(study_root: Path, rows: list[dict]) -> Path:
    figures_dir = study_root / "figures"
    figures_dir.mkdir(parents=True, exist_ok=True)
    output_path = figures_dir / "steel_pitch_frequency_overview.png"

    fig, axes = plt.subplots(1, 2, figsize=(13.5, 5.8), dpi=180)
    specs = [
        ("L_free", "自由端长度 L (cm)", "自由端长度对麦克风主频的影响"),
        ("h", "厚度 h (mm)", "厚度对麦克风主频的影响"),
    ]
    for ax, (variable, xlabel, title) in zip(axes, specs):
        selected = [row for row in rows if row["primary_variable"] == variable and row["status"] == "completed"]
        selected.sort(key=lambda item: item["value"])
        x = np.asarray([row["value"] for row in selected], dtype=float)
        y = np.asarray([row["f_dom_hz"] for row in selected], dtype=float)
        ax.plot(x, y, marker="o", markersize=6, linewidth=1.8, color="#1D3557")
        for xx, yy in zip(x, y):
            ax.text(xx, yy, f"{yy:.1f}", ha="center", va="bottom", fontsize=9)
        ax.set_title(title)
        ax.set_xlabel(xlabel)
        ax.set_ylabel("麦克风主频 f_dom (Hz)")
        ax.grid(True, alpha=0.28)
        expected_count = 5
        if len(selected) < expected_count:
            ax.text(
                0.5,
                0.5,
                f"已完成 {len(selected)}/{expected_count} 个真实 COMSOL case",
                transform=ax.transAxes,
                ha="center",
                va="center",
                fontsize=11,
                color="#D1495B",
            )

    fig.suptitle("钢尺音调：麦克风 2 cm 处接收主频（仅保留最主要频率峰）", fontsize=15)
    fig.text(
        0.5,
        0.02,
        "固定条件：x0=0.8L，宽度 b=3 cm，冲量 J=0.04 N*s；左图固定 h=2 mm，右图固定 L=20 cm。",
        ha="center",
        fontsize=9,
    )
    fig.tight_layout(rect=(0, 0.06, 1, 0.94))
    fig.savefig(output_path)
    plt.close(fig)
    return output_path


def write_summary_json(study_root: Path, rows: list[dict]) -> None:
    completed = [row for row in rows if row["status"] == "completed"]
    payload = {
        "study_root": str(study_root),
        "metric": "microphone_dominant_frequency_only",
        "interpretation": "pitch",
        "variables": ["L_free", "h"],
        "omitted_variables": ["b"],
        "case_count": len(rows),
        "completed_case_count": len(completed),
        "missing_case_count": len(rows) - len(completed),
        "outputs": {
            "table": str(study_root / "tables" / "steel_pitch_summary.csv"),
            "figure": str(study_root / "figures" / "steel_pitch_frequency_overview.png"),
        },
    }
    with (study_root / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--study-root", required=True)
    args = parser.parse_args()

    configure_chinese_font()
    study_root = Path(args.study_root).resolve()
    rows = collect_cases(study_root)
    write_summary_csv(study_root / "tables" / "steel_pitch_summary.csv", rows)
    figure_path = plot_pitch_overview(study_root, rows)
    write_summary_json(study_root, rows)
    print(study_root / "tables" / "steel_pitch_summary.csv")
    print(figure_path)
    print(study_root / "summary.json")


if __name__ == "__main__":
    main()
