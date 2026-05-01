from __future__ import annotations

import csv
import json
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import font_manager


REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = REPO_ROOT / "outputs" / "linear" / "acoustic_field_3d_air"
DATA_DIR = OUTPUT_ROOT / "data"
FIGURES_DIR = OUTPUT_ROOT / "figures"


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
        header = [f"col{i + 1}" for i in range(data.shape[1])]
    return header, data


def single_sided_amplitude(t: np.ndarray, y: np.ndarray, nfft: int = 16384) -> tuple[np.ndarray, np.ndarray]:
    dt = float(np.median(np.diff(t)))
    fs = 1.0 / dt
    centered = y - np.mean(y)
    window = np.hanning(centered.size)
    scale = np.sum(window)
    fft = np.fft.rfft(centered * window, n=nfft)
    freq = np.fft.rfftfreq(nfft, d=dt)
    amp = 2.0 * np.abs(fft) / scale
    if amp.size:
        amp[0] *= 0.5
    return freq, amp


def windowed_single_sided_amplitude(
    t: np.ndarray,
    y: np.ndarray,
    center_s: float,
    window_s: float = 0.02,
    nfft: int = 8192,
) -> tuple[np.ndarray, np.ndarray, float, float]:
    dt = float(np.median(np.diff(t)))
    fs = 1.0 / dt
    half_n = max(1, int(round(0.5 * window_s * fs)))
    center_idx = int(np.argmin(np.abs(t - center_s)))
    start = max(0, center_idx - half_n)
    stop = min(y.size, center_idx + half_n + 1)
    segment = y[start:stop] - np.mean(y[start:stop])
    window = np.hanning(segment.size)
    scale = np.sum(window)
    fft = np.fft.rfft(segment * window, n=nfft)
    freq = np.fft.rfftfreq(nfft, d=dt)
    amp = 2.0 * np.abs(fft) / scale
    if amp.size:
        amp[0] *= 0.5
    return freq, amp, float(t[start]), float(t[stop - 1])


def make_snapshot_centers(t: np.ndarray, count: int = 8, window_s: float = 0.02) -> np.ndarray:
    start = float(t[0]) + 0.5 * window_s
    stop = float(t[-1]) - 0.5 * window_s
    if stop <= start:
        return np.asarray([float(np.mean(t))])
    return np.linspace(start, stop, count)


def select_microphone_peaks(
    freq: np.ndarray,
    amp: np.ndarray,
    max_freq_hz: float = 2500.0,
    peak_count: int = 6,
    min_separation_hz: float = 35.0,
) -> np.ndarray:
    mask = (freq > 1.0) & (freq <= max_freq_hz)
    freq_band = freq[mask]
    amp_band = amp[mask]
    if freq_band.size < 3:
        return np.asarray([], dtype=float)

    local = np.where((amp_band[1:-1] > amp_band[:-2]) & (amp_band[1:-1] >= amp_band[2:]))[0] + 1
    if local.size == 0:
        local = np.arange(freq_band.size)

    sorted_idx = local[np.argsort(amp_band[local])[::-1]]
    selected: list[float] = []
    for idx in sorted_idx:
        candidate = float(freq_band[idx])
        if all(abs(candidate - old) >= min_separation_hz for old in selected):
            selected.append(candidate)
        if len(selected) >= peak_count:
            break
    return np.asarray(sorted(selected), dtype=float)


def stft_peak_duration(
    t: np.ndarray,
    y: np.ndarray,
    peak_freqs: np.ndarray,
    window_s: float = 0.03,
    hop_s: float = 0.002,
    nfft: int = 8192,
    relative_power_threshold: float = 0.01,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    dt = float(np.median(np.diff(t)))
    fs = 1.0 / dt
    win_n = max(8, int(round(window_s * fs)))
    hop_n = max(1, int(round(hop_s * fs)))
    if win_n > y.size:
        win_n = y.size
    window = np.hanning(win_n)
    if peak_freqs.size == 0:
        return np.asarray([], dtype=float), np.zeros((0, 0)), np.asarray([], dtype=float), np.asarray([], dtype=float)

    half_points = (peak_freqs[:-1] + peak_freqs[1:]) / 2.0
    band_edges = np.concatenate(([0.0], half_points, [fs / 2.0]))
    freq = np.fft.rfftfreq(nfft, d=dt)
    band_masks = [(freq >= band_edges[i]) & (freq < band_edges[i + 1]) for i in range(peak_freqs.size)]

    centers: list[float] = []
    band_power_rows: list[list[float]] = []
    for start in range(0, y.size - win_n + 1, hop_n):
        segment = y[start : start + win_n] - np.mean(y[start : start + win_n])
        spectrum = np.fft.rfft(segment * window, n=nfft)
        power = np.abs(spectrum) ** 2
        band_power_rows.append([float(np.sum(power[mask])) for mask in band_masks])
        centers.append(float(t[start] + 0.5 * (win_n - 1) * dt))

    centers_arr = np.asarray(centers, dtype=float)
    band_power = np.asarray(band_power_rows, dtype=float)
    durations = np.zeros(peak_freqs.size, dtype=float)
    for i in range(peak_freqs.size):
        peak = float(np.max(band_power[:, i])) if band_power.size else 0.0
        if peak <= 0:
            continue
        active = band_power[:, i] >= relative_power_threshold * peak
        durations[i] = float(np.sum(active) * hop_s)
    return centers_arr, band_power, durations, band_edges


def write_spectrum_csv(path: Path, freq: np.ndarray, amp: np.ndarray) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["freq_hz", "amp_pa"])
        writer.writerows(zip(freq, amp))


def write_duration_csv(
    path: Path,
    peak_freqs: np.ndarray,
    durations: np.ndarray,
    band_edges: np.ndarray,
    threshold: float,
) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["mic_peak_rank", "freq_hz", "band_low_hz", "band_high_hz", "duration_s", "threshold_relative_power"])
        for i, freq in enumerate(peak_freqs):
            writer.writerow([i + 1, freq, band_edges[i], band_edges[i + 1], durations[i], threshold])


def write_snapshots_csv(path: Path, snapshots: list[tuple[float, float, float, np.ndarray, np.ndarray]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["snapshot_time_s", "window_start_s", "window_end_s", "freq_hz", "amp_pa"])
        for center_s, start_s, end_s, freq, amp in snapshots:
            for f_hz, a_pa in zip(freq, amp):
                writer.writerow([center_s, start_s, end_s, f_hz, a_pa])


def load_context() -> tuple[np.ndarray, np.ndarray, dict]:
    _, mic = read_numeric_csv(DATA_DIR / "mic_pressure_timeseries.csv")
    with (OUTPUT_ROOT / "params_resolved.json").open("r", encoding="utf-8") as f:
        params = json.load(f)
    return mic[:, 0], mic[:, 1], params


def plot_frequency_distribution(freq: np.ndarray, amp: np.ndarray, mic_peak_freqs: np.ndarray, params: dict) -> Path:
    output_path = FIGURES_DIR / "steel_ruler_mic_frequency_distribution.png"
    fig, ax = plt.subplots(figsize=(11.5, 6.2), dpi=180)
    mask = freq <= 2500
    ax.plot(freq[mask], amp[mask], color="#1D3557", linewidth=1.8)
    peak_amps = np.interp(mic_peak_freqs, freq, amp) if mic_peak_freqs.size else np.asarray([])
    for i, (f, a) in enumerate(zip(mic_peak_freqs, peak_amps), start=1):
        ax.axvline(f, color="#D1495B", linestyle="--", linewidth=1.0, alpha=0.82)
        ax.scatter([f], [a], color="#D1495B", s=24, zorder=5)
        ax.text(f, max(a, ax.get_ylim()[1] * 0.12), f"p{i}\n{f:.1f} Hz", rotation=90, va="bottom", ha="right", fontsize=8)
    dom_idx = int(np.argmax(amp[mask]))
    dom_freq = float(freq[mask][dom_idx])
    dom_amp = float(amp[mask][dom_idx])
    ax.scatter([dom_freq], [dom_amp], color="#2A9D8F", s=42, zorder=5)
    ax.annotate(f"主峰 {dom_freq:.1f} Hz", xy=(dom_freq, dom_amp), xytext=(dom_freq + 120, dom_amp * 0.82),
                arrowprops={"arrowstyle": "->", "color": "#2A9D8F"}, fontsize=10)
    ax.set_title("钢尺麦克风接收频率分布（距离 2 cm）")
    ax.set_xlabel("频率 (Hz)")
    ax.set_ylabel("幅值 (Pa)")
    ax.grid(True, alpha=0.28)
    subtitle = (
        f"L={params['geometry']['L_free']}, b={params['geometry']['b']}, h={params['geometry']['h']}, "
        f"J={params['excitation']['J']}, 麦克风=({params['acoustics']['mic_x']}, "
        f"{params['acoustics']['mic_y']}, {params['acoustics']['mic_z']})"
    )
    fig.text(0.5, 0.01, subtitle, ha="center", fontsize=9)
    fig.tight_layout(rect=(0, 0.04, 1, 1))
    fig.savefig(output_path)
    plt.close(fig)
    return output_path


def plot_frequency_snapshots(snapshots: list[tuple[float, float, float, np.ndarray, np.ndarray]]) -> Path:
    output_path = FIGURES_DIR / "steel_ruler_mic_frequency_snapshots.png"
    if not snapshots:
        return output_path

    fig, axes = plt.subplots(4, 2, figsize=(12.5, 11.0), dpi=180, sharex=True)
    axes_flat = axes.ravel()
    max_amp = 0.0
    for _, _, _, freq, amp in snapshots:
        mask = freq <= 2500
        if np.any(mask):
            max_amp = max(max_amp, float(np.max(amp[mask])))

    for ax, (center_s, start_s, end_s, freq, amp) in zip(axes_flat, snapshots):
        mask = freq <= 2500
        ax.plot(freq[mask], amp[mask], color="#1D3557", linewidth=1.25)
        if np.any(mask):
            peak_idx = int(np.argmax(amp[mask]))
            peak_freq = float(freq[mask][peak_idx])
            peak_amp = float(amp[mask][peak_idx])
            ax.scatter([peak_freq], [peak_amp], color="#D1495B", s=20, zorder=5)
            ax.text(peak_freq, peak_amp, f"{peak_freq:.1f} Hz", fontsize=8, ha="left", va="bottom")
        ax.set_title(f"t = {center_s:.3f} s  ({start_s:.3f}-{end_s:.3f} s)")
        ax.grid(True, alpha=0.25)
        ax.set_ylim(0, max_amp * 1.12 if max_amp > 0 else 1.0)

    for ax in axes_flat[len(snapshots):]:
        ax.axis("off")
    for ax in axes_flat[-2:]:
        ax.set_xlabel("频率 (Hz)")
    for ax in axes_flat[::2]:
        ax.set_ylabel("幅值 (Pa)")

    fig.suptitle("钢尺麦克风接收频率分布：多个时间窗（距离 2 cm）", fontsize=15)
    fig.text(0.5, 0.015, "每个子图为对应时间窗内麦克风声压的 Hann 窗局部 FFT；只显示麦克风接收频率，不叠加结构频率。",
             ha="center", fontsize=9)
    fig.tight_layout(rect=(0, 0.035, 1, 0.965))
    fig.savefig(output_path)
    plt.close(fig)
    return output_path


def plot_peak_duration(peak_freqs: np.ndarray, durations: np.ndarray, band_edges: np.ndarray) -> Path:
    output_path = FIGURES_DIR / "steel_ruler_mic_peak_duration.png"
    labels = [f"p{i}\n{freq:.1f} Hz" for i, freq in enumerate(peak_freqs, start=1)]
    fig, ax = plt.subplots(figsize=(10.5, 5.8), dpi=180)
    colors = ["#1D3557", "#2A9D8F", "#E9C46A", "#D1495B", "#6A4C93", "#457B9D"]
    bars = ax.bar(labels, durations, color=colors[: len(labels)], edgecolor="#222222", linewidth=0.5)
    for bar, dur, lo, hi in zip(bars, durations, band_edges[:-1], band_edges[1:]):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.001, f"{dur:.3f}s",
                ha="center", va="bottom", fontsize=10)
        ax.text(bar.get_x() + bar.get_width() / 2, max(0.001, bar.get_height() * 0.45),
                f"{lo:.0f}-{hi:.0f}Hz", ha="center", va="center", fontsize=8, color="white")
    ax.set_title("钢尺麦克风接收的主要声音频率持续时间（距离 2 cm）")
    ax.set_xlabel("麦克风频谱主峰")
    ax.set_ylabel("持续时间 (s)")
    ax.set_ylim(0, max(0.105, float(np.max(durations)) * 1.25 if durations.size else 0.1))
    ax.grid(axis="y", alpha=0.28)
    fig.text(0.5, 0.01, "定义：先从麦克风全段频谱选取主要声音频率，再统计短时谱中对应频带功率超过该频带峰值 1% 的累计时间；当前 coarse 时程长度为 0.10 s。",
             ha="center", fontsize=9)
    fig.tight_layout(rect=(0, 0.05, 1, 1))
    fig.savefig(output_path)
    plt.close(fig)
    return output_path


def main() -> None:
    configure_chinese_font()
    FIGURES_DIR.mkdir(parents=True, exist_ok=True)
    t, p, params = load_context()

    freq, amp = single_sided_amplitude(t, p)
    mic_peak_freqs = select_microphone_peaks(freq, amp)
    centers, band_power, durations, band_edges = stft_peak_duration(t, p, mic_peak_freqs)
    snapshot_centers = make_snapshot_centers(t, count=8, window_s=0.02)
    snapshots = []
    for center_s in snapshot_centers:
        snap_freq, snap_amp, start_s, end_s = windowed_single_sided_amplitude(t, p, center_s, window_s=0.02)
        snapshots.append((float(center_s), start_s, end_s, snap_freq, snap_amp))

    write_spectrum_csv(DATA_DIR / "steel_ruler_mic_frequency_spectrum.csv", freq, amp)
    write_duration_csv(DATA_DIR / "steel_ruler_mic_peak_duration.csv", mic_peak_freqs, durations, band_edges, 0.01)
    write_snapshots_csv(DATA_DIR / "steel_ruler_mic_frequency_snapshots.csv", snapshots)

    spectrum_fig = plot_frequency_distribution(freq, amp, mic_peak_freqs, params)
    snapshots_fig = plot_frequency_snapshots(snapshots)
    duration_fig = plot_peak_duration(mic_peak_freqs, durations, band_edges)

    for stale in [
        FIGURES_DIR / "steel_ruler_mic_modal_duration.png",
        DATA_DIR / "steel_ruler_mic_modal_duration.csv",
    ]:
        if stale.exists():
            stale.unlink()

    print(spectrum_fig)
    print(snapshots_fig)
    print(duration_fig)
    print(DATA_DIR / "steel_ruler_mic_frequency_spectrum.csv")
    print(DATA_DIR / "steel_ruler_mic_frequency_snapshots.csv")
    print(DATA_DIR / "steel_ruler_mic_peak_duration.csv")


if __name__ == "__main__":
    main()
