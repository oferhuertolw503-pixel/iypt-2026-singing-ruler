from __future__ import annotations

import csv
import json
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import font_manager


REPO_ROOT = Path(__file__).resolve().parents[1]
BASE_ROOT = REPO_ROOT / "outputs" / "linear" / "acoustic_field_3d_air"
SCAN_ROOT = (
    REPO_ROOT
    / "outputs"
    / "linear"
    / "acoustic_field_3d_air_frequency_scan"
    / "steel_pitch_L_h_coarse_20260423"
)
OUT_ROOT = REPO_ROOT / "outputs" / "linear" / "acoustic_field_3d_air_requested_figures"
FIG_DIR = OUT_ROOT / "figures"
TABLE_DIR = OUT_ROOT / "tables"


MATERIALS = [
    ("钢尺", "steel", BASE_ROOT / "data" / "mic_pressure_timeseries.csv"),
    ("PVC", "pvc", None),
    ("雪弗板", "chevron_board", None),
    ("亚克力板", "acrylic", None),
    ("缎木板", "satinwood", None),
]


REQUESTED_VARIABLES = {
    "L_free": {
        "title": "自由端长度",
        "xlabel": "自由端长度 L (cm)",
        "unit": "cm",
        "values": [10, 14, 18, 22, 26],
        "fixed": "x0=0.8L, b=3 cm, h=2 mm, J=0.04 N*s",
    },
    "b": {
        "title": "宽度",
        "xlabel": "宽度 b (cm)",
        "unit": "cm",
        "values": [1, 2, 3, 4, 5],
        "fixed": "L=20 cm, x0=0.8L, h=2 mm, J=0.04 N*s",
    },
    "h": {
        "title": "厚度",
        "xlabel": "厚度 h (mm)",
        "unit": "mm",
        "values": [1, 2, 3, 4, 5],
        "fixed": "L=20 cm, x0=0.8L, b=3 cm, J=0.04 N*s",
    },
    "x0_ratio": {
        "title": "撞击位置",
        "xlabel": "撞击位置 x0/L",
        "unit": "ratio",
        "values": [0.25, 0.5, 0.75],
        "fixed": "L=20 cm, b=3 cm, h=2 mm, J=0.04 N*s",
    },
    "J": {
        "title": "冲量",
        "xlabel": "冲量 J (N*s)",
        "unit": "N*s",
        "values": [0.02, 0.04, 0.06, 0.08],
        "fixed": "L=20 cm, x0=0.8L, b=3 cm, h=2 mm",
    },
}


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
        reader = csv.reader(f)
        for row in reader:
            if not row:
                continue
            first = row[0].strip()
            if not first:
                continue
            if first.startswith("%"):
                first = first[1:].strip()
                header = [first] + [item.strip() for item in row[1:]]
                continue
            try:
                rows.append([float(item.strip()) for item in row])
            except ValueError:
                header = [item.strip() for item in row]
    data = np.asarray(rows, dtype=float)
    if header is None and data.ndim == 2:
        header = [f"col{i + 1}" for i in range(data.shape[1])]
    elif header is None:
        header = []
    return header, data


def single_sided_amplitude(t: np.ndarray, y: np.ndarray, nfft: int = 16384) -> tuple[np.ndarray, np.ndarray]:
    dt = float(np.median(np.diff(t)))
    centered = y - np.mean(y)
    window = np.hanning(centered.size)
    scale = float(np.sum(window))
    spectrum = np.fft.rfft(centered * window, n=nfft)
    freq = np.fft.rfftfreq(nfft, d=dt)
    amp = 2.0 * np.abs(spectrum) / scale
    if amp.size:
        amp[0] *= 0.5
    return freq, amp


def dominant_peak(t: np.ndarray, y: np.ndarray, max_freq_hz: float = 2500.0) -> tuple[float, float]:
    freq, amp = single_sided_amplitude(t, y)
    mask = (freq > 1.0) & (freq <= max_freq_hz)
    if not np.any(mask):
        return float("nan"), float("nan")
    local_freq = freq[mask]
    local_amp = amp[mask]
    idx = int(np.argmax(local_amp))
    return float(local_freq[idx]), float(local_amp[idx])


def pressure_metrics(t: np.ndarray, p: np.ndarray) -> dict[str, float]:
    f_dom, f_amp = dominant_peak(t, p)
    p_rms = float(np.sqrt(np.mean(np.square(p - np.mean(p)))))
    p_pp = float(np.max(p) - np.min(p))
    p_peak = float(np.max(np.abs(p)))
    spl = float(20.0 * np.log10(max(p_rms, 1e-30) / 20e-6))
    return {
        "f_dom_hz": f_dom,
        "f_dom_amp_pa": f_amp,
        "p_rms_pa": p_rms,
        "p_pp_pa": p_pp,
        "p_peak_abs_pa": p_peak,
        "spl_db": spl,
    }


def select_main_peaks(freq: np.ndarray, amp: np.ndarray, count: int = 6, max_freq_hz: float = 2500.0) -> np.ndarray:
    mask = (freq > 1.0) & (freq <= max_freq_hz)
    f = freq[mask]
    a = amp[mask]
    if f.size < 3:
        return np.asarray([], dtype=float)
    local = np.where((a[1:-1] > a[:-2]) & (a[1:-1] >= a[2:]))[0] + 1
    if local.size == 0:
        local = np.arange(f.size)
    selected: list[float] = []
    for idx in local[np.argsort(a[local])[::-1]]:
        cand = float(f[idx])
        if all(abs(cand - old) >= 35.0 for old in selected):
            selected.append(cand)
        if len(selected) >= count:
            break
    return np.asarray(sorted(selected), dtype=float)


def peak_duration(t: np.ndarray, p: np.ndarray, peaks: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    if peaks.size == 0:
        return np.asarray([], dtype=float), np.asarray([], dtype=float)
    dt = float(np.median(np.diff(t)))
    fs = 1.0 / dt
    window_s = 0.03
    hop_s = 0.002
    nfft = 8192
    win_n = min(p.size, max(8, int(round(window_s * fs))))
    hop_n = max(1, int(round(hop_s * fs)))
    window = np.hanning(win_n)
    freq = np.fft.rfftfreq(nfft, d=dt)
    mid = (peaks[:-1] + peaks[1:]) / 2.0
    edges = np.concatenate(([0.0], mid, [fs / 2.0]))
    masks = [(freq >= edges[i]) & (freq < edges[i + 1]) for i in range(peaks.size)]
    power_rows: list[list[float]] = []
    for start in range(0, p.size - win_n + 1, hop_n):
        segment = p[start : start + win_n] - np.mean(p[start : start + win_n])
        spectrum = np.fft.rfft(segment * window, n=nfft)
        power = np.abs(spectrum) ** 2
        power_rows.append([float(np.sum(power[m])) for m in masks])
    power_arr = np.asarray(power_rows, dtype=float)
    durations = np.zeros(peaks.size, dtype=float)
    for i in range(peaks.size):
        peak_power = float(np.max(power_arr[:, i])) if power_arr.size else 0.0
        if peak_power > 0:
            durations[i] = float(np.sum(power_arr[:, i] >= 0.01 * peak_power) * hop_s)
    return durations, edges


def load_completed_scan_rows() -> list[dict]:
    rows: list[dict] = []
    manifest_path = SCAN_ROOT / "study_manifest.json"
    if not manifest_path.exists():
        return rows
    with manifest_path.open("r", encoding="utf-8") as f:
        manifest = json.load(f)
    for case in manifest.get("cases", []):
        mic_path = Path(case["mic_pressure_timeseries_csv"])
        status = "missing"
        metrics = {
            "f_dom_hz": float("nan"),
            "f_dom_amp_pa": float("nan"),
            "p_rms_pa": float("nan"),
            "p_pp_pa": float("nan"),
            "p_peak_abs_pa": float("nan"),
            "spl_db": float("nan"),
        }
        if mic_path.exists():
            _, mic = read_numeric_csv(mic_path)
            if mic.ndim == 2 and mic.shape[1] >= 2 and mic.shape[0] > 4:
                metrics = pressure_metrics(mic[:, 0], mic[:, 1])
                status = "completed"
        rows.append(
            {
                "case_id": case["case_id"],
                "primary_variable": case["primary_variable"],
                "value": float(case["value"]),
                "value_unit": case["value_unit"],
                "status": status,
                "source": str(mic_path),
                **metrics,
            }
        )
    return rows


def add_expected_missing_rows(rows: list[dict]) -> list[dict]:
    keyed = {(row["primary_variable"], round(float(row["value"]), 8)): row for row in rows}
    merged = list(rows)
    for variable, spec in REQUESTED_VARIABLES.items():
        for value in spec["values"]:
            key = (variable, round(float(value), 8))
            if key in keyed:
                continue
            merged.append(
                {
                    "case_id": f"{variable}_{value:g}",
                    "primary_variable": variable,
                    "value": float(value),
                    "value_unit": spec["unit"],
                    "status": "not_generated",
                    "source": "",
                    "f_dom_hz": float("nan"),
                    "f_dom_amp_pa": float("nan"),
                    "p_rms_pa": float("nan"),
                    "p_pp_pa": float("nan"),
                    "p_peak_abs_pa": float("nan"),
                    "spl_db": float("nan"),
                }
            )
    return merged


def write_status_table(rows: list[dict]) -> Path:
    TABLE_DIR.mkdir(parents=True, exist_ok=True)
    path = TABLE_DIR / "当前请求输出_真实结果状态表.csv"
    fields = [
        "case_id",
        "primary_variable",
        "value",
        "value_unit",
        "status",
        "f_dom_hz",
        "f_dom_amp_pa",
        "p_rms_pa",
        "p_pp_pa",
        "p_peak_abs_pa",
        "spl_db",
        "source",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for row in sorted(rows, key=lambda r: (r["primary_variable"], r["value"])):
            writer.writerow({field: row.get(field, "") for field in fields})
    return path


def plot_material_frequency_distribution() -> Path:
    path = FIG_DIR / "01_音色_材料频率分布_当前真实结果.png"
    fig, axes = plt.subplots(3, 2, figsize=(13.2, 10.5), dpi=180)
    axes_flat = axes.ravel()
    for ax, (name, _key, mic_path) in zip(axes_flat, MATERIALS):
        if mic_path is not None and mic_path.exists():
            _, mic = read_numeric_csv(mic_path)
            freq, amp = single_sided_amplitude(mic[:, 0], mic[:, 1])
            mask = freq <= 2500
            ax.plot(freq[mask], amp[mask], color="#1D3557", linewidth=1.6)
            f_dom, a_dom = dominant_peak(mic[:, 0], mic[:, 1])
            if np.isfinite(f_dom):
                ax.scatter([f_dom], [a_dom], color="#D1495B", s=32, zorder=4)
                ax.text(f_dom, a_dom, f"主峰 {f_dom:.1f} Hz", ha="left", va="bottom", fontsize=9)
            ax.set_title(f"{name}：麦克风频率分布")
            ax.set_xlabel("频率 (Hz)")
            ax.set_ylabel("幅值 (Pa)")
            ax.grid(True, alpha=0.28)
        else:
            ax.set_title(f"{name}：未生成")
            ax.text(
                0.5,
                0.55,
                "未找到真实 COMSOL 3D 空气域算例\n不绘制伪造频谱",
                transform=ax.transAxes,
                ha="center",
                va="center",
                fontsize=12,
                color="#D1495B",
            )
            ax.set_axis_off()
    for ax in axes_flat[len(MATERIALS) :]:
        ax.set_axis_off()
    fig.suptitle("音色：材料频率分布图（当前只包含已完成真实结果）", fontsize=16)
    fig.text(0.5, 0.015, "说明：钢尺曲线来自 mic_pressure_timeseries.csv；其他材料尚无真实 3D 空气域输出。", ha="center", fontsize=10)
    fig.tight_layout(rect=(0, 0.04, 1, 0.96))
    fig.savefig(path)
    plt.close(fig)
    return path


def plot_steel_peak_duration() -> Path:
    path = FIG_DIR / "02_音色_钢尺主要频率持续时间.png"
    _, mic = read_numeric_csv(BASE_ROOT / "data" / "mic_pressure_timeseries.csv")
    freq, amp = single_sided_amplitude(mic[:, 0], mic[:, 1])
    peaks = select_main_peaks(freq, amp, count=6)
    durations, edges = peak_duration(mic[:, 0], mic[:, 1], peaks)
    labels = [f"{f:.1f} Hz" for f in peaks]
    fig, ax = plt.subplots(figsize=(11.5, 6.0), dpi=180)
    colors = ["#1D3557", "#2A9D8F", "#E9C46A", "#D1495B", "#6A4C93", "#457B9D"]
    bars = ax.bar(labels, durations, color=colors[: len(labels)], edgecolor="#222222", linewidth=0.5)
    for i, bar in enumerate(bars):
        ax.text(bar.get_x() + bar.get_width() / 2.0, bar.get_height() + 0.001, f"{durations[i]:.3f} s", ha="center", va="bottom", fontsize=9)
        if edges.size == peaks.size + 1:
            ax.text(
                bar.get_x() + bar.get_width() / 2.0,
                max(0.002, bar.get_height() * 0.45),
                f"{edges[i]:.0f}-{edges[i+1]:.0f} Hz",
                ha="center",
                va="center",
                fontsize=8,
                color="white",
            )
    ax.set_title("钢尺：麦克风主要频率持续时间（距离 2 cm）")
    ax.set_xlabel("麦克风主要频率")
    ax.set_ylabel("持续时间 (s)")
    ax.grid(axis="y", alpha=0.28)
    ax.set_ylim(0, max(0.11, float(np.max(durations)) * 1.25 if durations.size else 0.1))
    fig.text(0.5, 0.015, "定义：全段频谱选取主要峰；短时频带功率超过该频带峰值 1% 的窗口累计为持续时间。", ha="center", fontsize=9)
    fig.tight_layout(rect=(0, 0.045, 1, 1))
    fig.savefig(path)
    plt.close(fig)

    table = TABLE_DIR / "钢尺主要频率持续时间.csv"
    with table.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["freq_hz", "duration_s", "band_low_hz", "band_high_hz"])
        for i, f_hz in enumerate(peaks):
            writer.writerow([f_hz, durations[i], edges[i], edges[i + 1]])
    return path


def plot_scan_overview(rows: list[dict], metric: str, ylabel: str, title: str, filename: str) -> Path:
    path = FIG_DIR / filename
    fig, axes = plt.subplots(2, 3, figsize=(15.0, 8.8), dpi=180)
    axes_flat = axes.ravel()
    for ax, (variable, spec) in zip(axes_flat, REQUESTED_VARIABLES.items()):
        expected = np.asarray(spec["values"], dtype=float)
        selected = [row for row in rows if row["primary_variable"] == variable]
        completed = [row for row in selected if row["status"] == "completed" and np.isfinite(row[metric])]
        completed.sort(key=lambda item: item["value"])
        x = np.asarray([row["value"] for row in completed], dtype=float)
        y = np.asarray([row[metric] for row in completed], dtype=float)
        if x.size:
            ax.plot(x, y, marker="o", markersize=6, linewidth=1.8, color="#1D3557")
            for xx, yy in zip(x, y):
                ax.text(xx, yy, f"{yy:.2g}" if abs(yy) < 100 else f"{yy:.1f}", ha="center", va="bottom", fontsize=8)
        missing = [v for v in expected if not any(abs(float(row["value"]) - float(v)) < 1e-8 and row["status"] == "completed" for row in selected)]
        if missing:
            ymin, ymax = ax.get_ylim()
            ymark = ymin + 0.08 * (ymax - ymin) if ymax > ymin else 0.0
            ax.scatter(missing, [ymark] * len(missing), marker="x", color="#D1495B", s=42, label="未生成")
        ax.set_title(spec["title"])
        ax.set_xlabel(spec["xlabel"])
        ax.set_ylabel(ylabel)
        ax.set_xticks(expected)
        ax.grid(True, alpha=0.28)
        ax.text(0.5, -0.28, spec["fixed"], transform=ax.transAxes, ha="center", va="top", fontsize=8)
        if missing:
            ax.text(
                0.5,
                0.88,
                f"完成 {len(completed)}/{len(expected)} 个真实 case",
                transform=ax.transAxes,
                ha="center",
                va="center",
                fontsize=9,
                color="#D1495B",
            )
    axes_flat[-1].set_axis_off()
    fig.suptitle(title, fontsize=16)
    fig.text(0.5, 0.015, "圆点为已完成真实 COMSOL 3D 空气域结果；红色叉号为当前尚未生成的请求点。", ha="center", fontsize=10)
    fig.tight_layout(rect=(0, 0.04, 1, 0.96))
    fig.savefig(path)
    plt.close(fig)
    return path


def plot_impulse_force_time() -> Path:
    path = FIG_DIR / "05_冲量_力时间图像.png"
    _, data = read_numeric_csv(BASE_ROOT / "data" / "impact_force_timeseries.csv")
    t = data[:, 0]
    fz = data[:, 1]
    impulse = float(np.trapezoid(fz, t))
    fig, ax = plt.subplots(figsize=(11.5, 5.8), dpi=180)
    ax.plot(t * 1000.0, fz, color="#1D3557", linewidth=1.8)
    ax.fill_between(t * 1000.0, fz, 0, color="#1D3557", alpha=0.16)
    ax.set_title("冲量的力-时间图像（half-sine 单峰，钢尺基准算例）")
    ax.set_xlabel("时间 (ms)")
    ax.set_ylabel("厚度方向力 Fz (N)")
    ax.grid(True, alpha=0.28)
    ax.annotate(
        f"数值积分冲量 = {impulse:.5f} N*s\n目标 |J| = 0.04 N*s\n脉冲宽度 tau = 2 ms",
        xy=(0.62, 0.72),
        xycoords="axes fraction",
        bbox={"boxstyle": "round,pad=0.35", "fc": "white", "ec": "#555555", "alpha": 0.92},
        fontsize=10,
    )
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)
    return path


def main() -> None:
    configure_chinese_font()
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    TABLE_DIR.mkdir(parents=True, exist_ok=True)

    rows = add_expected_missing_rows(load_completed_scan_rows())
    status_table = write_status_table(rows)
    outputs = [
        plot_material_frequency_distribution(),
        plot_steel_peak_duration(),
        plot_scan_overview(
            rows,
            "f_dom_hz",
            "麦克风主峰频率 (Hz)",
            "频率（钢尺，麦克风 2 cm 处）：当前真实进度",
            "03_频率_钢尺_麦克风2cm_当前进度.png",
        ),
        plot_scan_overview(
            rows,
            "p_rms_pa",
            "麦克风声压 RMS (Pa)",
            "声压（钢尺，麦克风 2 cm 处）：当前真实进度",
            "04_声压_钢尺_麦克风2cm_当前进度.png",
        ),
        plot_impulse_force_time(),
    ]

    summary = {
        "output_root": str(OUT_ROOT),
        "truth_policy": "Only completed COMSOL 3D air-domain cases are plotted as data points; missing requests are marked as not generated.",
        "status_table": str(status_table),
        "figures": [str(path) for path in outputs],
        "completed_scan_cases": len([row for row in rows if row["status"] == "completed"]),
        "requested_scan_points": sum(len(spec["values"]) for spec in REQUESTED_VARIABLES.values()),
    }
    with (OUT_ROOT / "summary.json").open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    print(status_table)
    for path in outputs:
        print(path)
    print(OUT_ROOT / "summary.json")


if __name__ == "__main__":
    main()
