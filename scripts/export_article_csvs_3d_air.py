from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

import numpy as np

MIN_TONAL_FREQ_HZ = 20.0
MAX_ANALYSIS_FREQ_HZ = 2500.0

MATERIAL_ORDER = ["steel", "pvc", "xuefu_board", "acrylic", "satinwood"]
MATERIAL_LABELS = {
    "steel": "钢尺",
    "pvc": "PVC",
    "xuefu_board": "雪弗板",
    "acrylic": "亚克力板",
    "satinwood": "缎木板",
}

VARIABLE_ORDER = ["L_free", "b", "h", "x0_ratio", "J"]
VARIABLE_LABELS = {
    "L_free": "自由端长度",
    "b": "宽度",
    "h": "厚度",
    "x0_ratio": "撞击位置",
    "J": "冲量",
}
VARIABLE_UNITS = {
    "L_free": "cm",
    "b": "cm",
    "h": "mm",
    "x0_ratio": "L",
    "J": "N*s",
}


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


def read_table(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def build_case_dir_index(study_root: Path) -> dict[str, Path]:
    index: dict[str, Path] = {}
    cases_root = study_root / "cases"
    for data_dir in cases_root.rglob("data"):
        if data_dir.is_dir():
            index[data_dir.parent.name] = data_dir.parent
    return index


def to_float(value: str) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return float("nan")


def export_material_summary(
    article_dir: Path,
    rows: list[dict[str, str]],
) -> Path:
    selected = [
        row
        for row in rows
        if row.get("group") == "timbre" and row.get("status") == "completed"
    ]
    selected.sort(key=lambda item: MATERIAL_ORDER.index(item["material_key"]))
    export_rows: list[dict[str, object]] = []
    for row in selected:
        export_rows.append(
            {
                "材料": MATERIAL_LABELS.get(row["material_key"], row["material_key"]),
                "主峰频率_Hz": to_float(row["f_dom_hz"]),
                "主峰幅值_Pa": to_float(row["f_dom_amp_pa"]),
                "声压均方根_Pa": to_float(row["p_rms_pa"]),
                "峰峰值_Pa": to_float(row["p_pp_pa"]),
                "绝对峰值_Pa": to_float(row["p_peak_abs_pa"]),
                "声压级_dB": to_float(row["spl_db"]),
                "数据口径": "麦克风 20-2500 Hz 有效主峰与声压统计",
                "case_id": row["case_id"],
            }
        )
    output_path = article_dir / "01_音色_五种材料主峰与声压汇总.csv"
    write_csv(
        output_path,
        [
            "材料",
            "主峰频率_Hz",
            "主峰幅值_Pa",
            "声压均方根_Pa",
            "峰峰值_Pa",
            "绝对峰值_Pa",
            "声压级_dB",
            "数据口径",
            "case_id",
        ],
        export_rows,
    )
    return output_path


def export_material_duration(
    article_dir: Path,
    duration_rows: list[dict[str, str]],
) -> tuple[Path, Path]:
    ordered = sorted(
        duration_rows,
        key=lambda item: (
            MATERIAL_ORDER.index(item["material_key"]),
            int(item["peak_rank"]),
        ),
    )
    all_rows: list[dict[str, object]] = []
    steel_rows: list[dict[str, object]] = []
    for row in ordered:
        export_row = {
            "材料": row["material_name"],
            "峰序号": int(row["peak_rank"]),
            "频率_Hz": to_float(row["freq_hz"]),
            "持续时间_s": to_float(row["duration_s"]),
            "频带下限_Hz": to_float(row["band_low_hz"]),
            "频带上限_Hz": to_float(row["band_high_hz"]),
            "source_case_id": row["source_case_id"],
        }
        all_rows.append(export_row)
        if row["material_key"] == "steel":
            steel_rows.append(export_row)

    all_path = article_dir / "02_音色_各材料主要接收频率持续时间.csv"
    steel_path = article_dir / "03_音色_钢尺主要接收频率持续时间.csv"
    fieldnames = [
        "材料",
        "峰序号",
        "频率_Hz",
        "持续时间_s",
        "频带下限_Hz",
        "频带上限_Hz",
        "source_case_id",
    ]
    write_csv(all_path, fieldnames, all_rows)
    write_csv(steel_path, fieldnames, steel_rows)
    return all_path, steel_path


def export_material_spectra(
    article_dir: Path,
    rows: list[dict[str, str]],
    case_dir_index: dict[str, Path],
) -> list[Path]:
    outputs: list[Path] = []
    selected = [
        row
        for row in rows
        if row.get("group") == "timbre" and row.get("status") == "completed"
    ]
    selected.sort(key=lambda item: MATERIAL_ORDER.index(item["material_key"]))
    for row in selected:
        case_dir = case_dir_index[row["case_id"]]
        mic_path = case_dir / "data" / "mic_pressure_timeseries.csv"
        _, mic = read_numeric_csv(mic_path)
        freq_hz, amplitude = single_sided_amplitude(mic[:, 0], mic[:, 1])
        mask = (freq_hz >= 0.0) & (freq_hz <= MAX_ANALYSIS_FREQ_HZ)
        export_rows = [
            {
                "频率_Hz": float(f),
                "幅值_Pa": float(a),
            }
            for f, a in zip(freq_hz[mask], amplitude[mask])
        ]
        filename = f"音色_频率分布_{MATERIAL_LABELS.get(row['material_key'], row['material_key'])}.csv"
        output_path = article_dir / filename
        write_csv(output_path, ["频率_Hz", "幅值_Pa"], export_rows)
        outputs.append(output_path)
    return outputs


def export_scan_tables(
    article_dir: Path,
    rows: list[dict[str, str]],
    metric_key: str,
    prefix: str,
    metric_label: str,
) -> list[Path]:
    outputs: list[Path] = []
    for variable in VARIABLE_ORDER:
        selected = [
            row
            for row in rows
            if row.get("material_key") == "steel"
            and row.get("primary_variable") == variable
            and row.get("status") == "completed"
        ]
        selected.sort(key=lambda item: float(item["value"]))
        export_rows: list[dict[str, object]] = []
        for row in selected:
            value = to_float(row["value"])
            export_row: dict[str, object] = {
                "变量": VARIABLE_LABELS[variable],
                "数值": value,
                "单位": VARIABLE_UNITS[variable],
                metric_label: to_float(row[metric_key]),
                "case_id": row["case_id"],
            }
            if variable == "L_free":
                export_row["1除以L平方_每平方厘米"] = float(1.0 / (value * value))
            export_rows.append(export_row)

        filename = f"{prefix}_{VARIABLE_LABELS[variable]}.csv"
        output_path = article_dir / filename
        fieldnames = ["变量", "数值", "单位"]
        if variable == "L_free":
            fieldnames.append("1除以L平方_每平方厘米")
        fieldnames.extend([metric_label, "case_id"])
        write_csv(output_path, fieldnames, export_rows)
        outputs.append(output_path)
    return outputs


def export_impulse_force(
    article_dir: Path,
    rows: list[dict[str, str]],
    case_dir_index: dict[str, Path],
) -> Path:
    selected = [
        row
        for row in rows
        if row.get("material_key") == "steel"
        and row.get("primary_variable") == "J"
        and row.get("status") == "completed"
    ]
    selected.sort(key=lambda item: float(item["J_Ns"]))
    export_rows: list[dict[str, object]] = []
    for row in selected:
        case_dir = case_dir_index[row["case_id"]]
        _, force = read_numeric_csv(case_dir / "data" / "impact_force_timeseries.csv")
        impulse = float(np.trapezoid(force[:, 1], force[:, 0])) if force.size else float("nan")
        for t_s, f_n in force[:, :2]:
            export_rows.append(
                {
                    "冲量_Ns": to_float(row["J_Ns"]),
                    "时间_s": float(t_s),
                    "力_N": float(f_n),
                    "力时程积分_Ns": impulse,
                    "case_id": row["case_id"],
                }
            )

    output_path = article_dir / "14_冲量_力时间图.csv"
    write_csv(
        output_path,
        ["冲量_Ns", "时间_s", "力_N", "力时程积分_Ns", "case_id"],
        export_rows,
    )
    return output_path


def export_mapping_readme(
    output_path: Path,
    study_root: Path,
    generated_files: list[Path],
) -> None:
    lines = [
        "# 本文所需 CSV 对应文件说明",
        "",
        "以下文件均来自当前真实仿真结果，不是拟合补点数据。",
        "",
        f"- 当前结果根目录：`{study_root}`",
        f"- 总表：`{study_root / 'tables' / 'all_requested_cases.csv'}`",
        f"- 音色持续时间长表：`{study_root / 'tables' / 'material_frequency_duration_long.csv'}`",
        "",
        "## 正文可直接使用的 CSV",
    ]
    for file_path in generated_files:
        lines.append(f"- `{file_path.name}`")
    lines.extend(
        [
            "",
            "## 对应关系",
            "- 音色五种材料频率分布图：使用 `音色_频率分布_*.csv` 5 份频谱表。",
            "- 音色各材料主要接收频率持续时间：使用 `02_音色_各材料主要接收频率持续时间.csv`。",
            "- 钢尺各频率持续时间：使用 `03_音色_钢尺主要接收频率持续时间.csv`。",
            "- 频率趋势图：使用 `04_音调_自由端长度.csv` 到 `08_音调_冲量.csv`。",
            "- 声压趋势图：使用 `09_声压_自由端长度.csv` 到 `13_声压_冲量.csv`。",
            "- 冲量力-时间图：使用 `14_冲量_力时间图.csv`。",
            "",
            "## 口径说明",
            "- 麦克风主峰频率来自 `mic_pressure_timeseries.csv` 的 FFT 后处理。",
            "- 有效音调主峰频段固定为 20-2500 Hz。",
            "- 声压趋势量采用麦克风声压均方根。",
            "- 频率持续时间来自麦克风声压短时分析，不是结构模态寿命。",
        ]
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Export article-ready CSV tables from requested 3D air outputs.")
    parser.add_argument("--study-root", required=True, help="Requested-output study root directory.")
    args = parser.parse_args()

    study_root = Path(args.study_root).resolve()
    tables_dir = study_root / "tables"
    article_dir = tables_dir / "article_csv"

    all_rows = read_table(tables_dir / "all_requested_cases.csv")
    duration_rows = read_table(tables_dir / "material_frequency_duration_long.csv")
    case_dir_index = build_case_dir_index(study_root)

    generated_files: list[Path] = []
    generated_files.append(export_material_summary(article_dir, all_rows))
    duration_all, duration_steel = export_material_duration(article_dir, duration_rows)
    generated_files.extend([duration_all, duration_steel])
    generated_files.extend(export_material_spectra(article_dir, all_rows, case_dir_index))
    generated_files.extend(
        export_scan_tables(
            article_dir,
            all_rows,
            metric_key="f_dom_hz",
            prefix="04_音调",
            metric_label="麦克风有效主峰频率_Hz",
        )
    )
    generated_files.extend(
        export_scan_tables(
            article_dir,
            all_rows,
            metric_key="p_rms_pa",
            prefix="09_声压",
            metric_label="麦克风声压均方根_Pa",
        )
    )
    generated_files.append(export_impulse_force(article_dir, all_rows, case_dir_index))

    export_mapping_readme(article_dir / "README_论文数据说明.md", study_root, generated_files)

    for file_path in generated_files:
        print(str(file_path))
    print(str(article_dir / "README_论文数据说明.md"))


if __name__ == "__main__":
    main()
