from __future__ import annotations

import argparse
import csv
import json
import math
import re
import shutil
from pathlib import Path

import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt


RESULT_FIGURES = (
    "frequencies_bar.png",
    "tip_timeseries.png",
    "tip_fft.png",
    "pgmode_mode01.png",
    "pgmode_mode02.png",
    "pgmode_mode03.png",
    "pgmode_mode04.png",
    "pgmode_mode05.png",
    "pgmode_mode06.png",
)

TABLE_FILES = (
    "frequencies.csv",
    "tip_timeseries.csv",
    "tip_fft.csv",
    "mode_shapes.csv",
)

ARTIFACT_FILES = (
    "run_summary.json",
    "run_summary.txt",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Refresh saved linear beam plots from existing CSV results."
    )
    parser.add_argument("roots", nargs="+", help="Model output roots, e.g. outputs/linear/impact_response")
    return parser.parse_args()


def parse_physical_scalar(raw: object) -> float:
    if raw is None:
        return math.nan
    if isinstance(raw, (int, float)):
        return float(raw)
    text = str(raw).strip()
    if not text:
        return math.nan
    try:
        return float(text)
    except ValueError:
        pass
    match = re.match(r"^\s*([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)", text)
    if match:
        return float(match.group(1))
    return math.nan


def read_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def read_csv_rows(path: Path) -> tuple[list[str], list[dict[str, float]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        headers = list(reader.fieldnames or [])
        rows: list[dict[str, float]] = []
        for row in reader:
            parsed = {key: float(value) for key, value in row.items() if key is not None and value is not None}
            rows.append(parsed)
    return headers, rows


def write_csv_rows(path: Path, headers: list[str], rows: list[dict[str, float]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=headers)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: format_float(row.get(key, math.nan)) for key in headers})


def format_float(value: float) -> str:
    if value is None:
        return ""
    if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
        return ""
    return f"{float(value):.16g}"


def single_sided_fft(t: np.ndarray, y: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    if t.size < 4:
        return np.zeros(0), np.zeros(0)
    dt = float(np.mean(np.diff(t)))
    if not math.isfinite(dt) or dt <= 0:
        return np.zeros(0), np.zeros(0)
    y0 = y - np.mean(y)
    n = y0.size
    yf = np.fft.fft(y0)
    half_n = n // 2 + 1
    freq_hz = np.arange(half_n, dtype=float) / (n * dt)
    amp = np.abs(yf[:half_n]) / n
    if amp.size > 2:
        amp[1:-1] *= 2.0
    return freq_hz, amp


def resolve_quality_root(root: Path, summary: dict) -> Path | None:
    quality_output_root = summary.get("quality_output_root")
    if quality_output_root:
        candidate = Path(str(quality_output_root))
        if candidate.exists():
            return candidate
    qualities_dir = root / "qualities"
    if not qualities_dir.exists():
        return None
    candidates = [path for path in qualities_dir.iterdir() if path.is_dir()]
    if not candidates:
        return None
    return sorted(candidates)[0]


def resolve_results_root(root: Path, quality_root: Path | None) -> tuple[Path, Path | None]:
    stable_results = root / "results"
    if stable_results.exists():
        return stable_results, (quality_root / "results") if quality_root else None
    if quality_root and (quality_root / "results").exists():
        return quality_root / "results", stable_results
    raise FileNotFoundError(f"No results directory found under {root}")


def ensure_mode_shape_coordinates(results_dir: Path, beam_length_m: float) -> None:
    mode_path = results_dir / "mode_shapes.csv"
    headers, rows = read_csv_rows(mode_path)
    if "x_m" in headers:
        return
    if "x_over_L" not in headers or not math.isfinite(beam_length_m):
        return
    new_headers = ["x_m"] + headers
    for row in rows:
        row["x_m"] = row["x_over_L"] * beam_length_m
    write_csv_rows(mode_path, new_headers, rows)


def refresh_tip_fft(results_dir: Path) -> None:
    headers, rows = read_csv_rows(results_dir / "tip_timeseries.csv")
    if "t_s" not in headers or "w_m" not in headers:
        raise ValueError(f"tip_timeseries.csv in {results_dir} is missing expected columns.")
    t = np.array([row["t_s"] for row in rows], dtype=float)
    y = np.array([row["w_m"] for row in rows], dtype=float)
    freq_hz, amp = single_sided_fft(t, y)
    fft_rows = [{"freq_hz": float(f), "amp_m": float(a)} for f, a in zip(freq_hz, amp)]
    write_csv_rows(results_dir / "tip_fft.csv", ["freq_hz", "amp_m"], fft_rows)


def plot_frequency_bar(results_dir: Path) -> None:
    _, rows = read_csv_rows(results_dir / "frequencies.csv")
    modes = np.array([row["mode"] for row in rows], dtype=float)
    freqs = np.array([row["freq_hz"] for row in rows], dtype=float)

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.bar(modes, freqs, color="#2D6A4F")
    ax.set_xlabel("Mode")
    ax.set_ylabel("Frequency (Hz)")
    ax.set_title("Eigenfrequencies")
    ax.set_xticks(modes)
    ax.grid(True, axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(results_dir / "frequencies_bar.png", dpi=150)
    plt.close(fig)


def plot_tip_series(results_dir: Path) -> None:
    _, rows = read_csv_rows(results_dir / "tip_timeseries.csv")
    t = np.array([row["t_s"] for row in rows], dtype=float)
    y = np.array([row["w_m"] for row in rows], dtype=float)

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.plot(t, y, color="#1D3557", linewidth=1.1)
    ax.set_xlabel("Time (s)")
    ax.set_ylabel("Tip displacement w (m)")
    ax.set_title("Tip displacement response")
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(results_dir / "tip_timeseries.png", dpi=150)
    plt.close(fig)


def plot_tip_fft(results_dir: Path) -> None:
    _, rows = read_csv_rows(results_dir / "tip_fft.csv")
    freq_hz = np.array([row["freq_hz"] for row in rows], dtype=float)
    amp = np.array([row["amp_m"] for row in rows], dtype=float)

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.plot(freq_hz, amp, color="#E76F51", linewidth=1.0)
    ax.set_xlabel("Frequency (Hz)")
    ax.set_ylabel("Amplitude |W(f)| (m)")
    ax.set_title("Tip displacement spectrum")
    if freq_hz.size:
        ax.set_xlim(0.0, min(1000.0, float(np.max(freq_hz))))
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(results_dir / "tip_fft.png", dpi=150)
    plt.close(fig)


def plot_mode_shapes(results_dir: Path) -> None:
    headers, rows = read_csv_rows(results_dir / "mode_shapes.csv")
    if "x_m" in headers:
        x = np.array([row["x_m"] for row in rows], dtype=float)
        x_label = "Position x (m)"
    else:
        x = np.array([row["x_over_L"] for row in rows], dtype=float)
        x_label = "Position x / L"

    mode_headers = [header for header in headers if header.startswith("w_mode")]
    for index, mode_header in enumerate(mode_headers, start=1):
        y = np.array([row[mode_header] for row in rows], dtype=float)
        fig, ax = plt.subplots(figsize=(8, 2.2))
        ax.plot(x, y, color="#111111", linewidth=1.5)
        ax.axhline(0.0, color="#9AA0A6", linewidth=0.8)
        ax.set_xlabel(x_label)
        ax.set_ylabel("w (m)")
        ax.set_title(f"Mode shape {index}")
        ymax = float(np.nanmax(np.abs(y))) if y.size else 0.0
        if math.isfinite(ymax) and ymax > 0:
            ax.set_ylim(-1.1 * ymax, 1.1 * ymax)
        ax.grid(True, alpha=0.3)
        fig.tight_layout()
        fig.savefig(results_dir / f"pgmode_mode{index:02d}.png", dpi=150)
        plt.close(fig)


def copy_if_exists(src: Path, dst: Path) -> None:
    if not src.exists():
        return
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def publish_results(root: Path, results_dir: Path) -> None:
    figures_dir = root / "figures"
    tables_dir = root / "tables"
    artifacts_dir = root / "artifacts"
    for name in RESULT_FIGURES:
        copy_if_exists(results_dir / name, figures_dir / name)
    for name in TABLE_FILES:
        copy_if_exists(results_dir / name, tables_dir / name)
    for name in ARTIFACT_FILES:
        copy_if_exists(results_dir / name, artifacts_dir / name)


def mirror_results(source_results: Path, target_results: Path | None, root: Path, quality_root: Path | None) -> None:
    if target_results is not None:
        for name in RESULT_FIGURES + TABLE_FILES + ARTIFACT_FILES:
            copy_if_exists(source_results / name, target_results / name)
    publish_results(root, source_results)
    if quality_root is not None:
        publish_results(quality_root, target_results or source_results)


def refresh_root(root: Path) -> None:
    summary = read_json(root / "summary.json")
    quality_root = resolve_quality_root(root, summary)
    results_dir, mirror_dir = resolve_results_root(root, quality_root)

    beam_length_m = parse_physical_scalar(summary.get("L_free"))
    if not math.isfinite(beam_length_m) and quality_root is not None:
        quality_summary = read_json(quality_root / "summary.json")
        beam_length_m = parse_physical_scalar(quality_summary.get("L_free"))

    ensure_mode_shape_coordinates(results_dir, beam_length_m)
    refresh_tip_fft(results_dir)
    plot_frequency_bar(results_dir)
    plot_tip_series(results_dir)
    plot_tip_fft(results_dir)
    plot_mode_shapes(results_dir)
    mirror_results(results_dir, mirror_dir, root, quality_root)

    print(f"refreshed {root}")


def main() -> None:
    args = parse_args()
    for raw_root in args.roots:
        refresh_root(Path(raw_root).resolve())


if __name__ == "__main__":
    main()
