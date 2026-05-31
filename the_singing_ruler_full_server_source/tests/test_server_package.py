#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True

PACKAGE_ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = PACKAGE_ROOT / "tools"
sys.path.insert(0, str(TOOLS_DIR))

import run_case
import run_requested_full
import validate_csv_bundle
from validate_csv_bundle import mic_sweep_filenames
from run_case import write_stdout_csvs


class ServerPackageTests(unittest.TestCase):
    def load_case_definition(self) -> dict:
        return json.loads((PACKAGE_ROOT / "config" / "requested_cases.json").read_text(encoding="utf-8"))

    def test_source_package_has_no_generated_artifacts(self) -> None:
        forbidden_suffixes = {".mph", ".class", ".csv", ".png", ".mp4", ".pyc"}
        ignored_dirs = {"outputs", "runtime", "__pycache__"}
        forbidden_dirs = {"result"}
        problems: list[str] = []

        for path in PACKAGE_ROOT.rglob("*"):
            rel_parts = set(path.relative_to(PACKAGE_ROOT).parts)
            if rel_parts & ignored_dirs:
                continue
            if path.is_dir() and path.name in forbidden_dirs:
                problems.append(path.as_posix())
            if path.is_file() and path.suffix.lower() in forbidden_suffixes:
                problems.append(path.as_posix())

        self.assertEqual(problems, [])

    def test_requested_set_has_27_unique_full_cases(self) -> None:
        definition = self.load_case_definition()
        cases = run_requested_full.build_cases(definition, PACKAGE_ROOT / "outputs" / "preview_full")

        self.assertEqual(len(cases), 27)
        self.assertEqual(len({case["case_id"] for case in cases}), 27)

        counts: dict[str, int] = {}
        for case in cases:
            counts[case["primary_variable"]] = counts.get(case["primary_variable"], 0) + 1
            overrides = case["config_overrides"]
            self.assertEqual(overrides["mesh"]["numelem"], 120)
            self.assertEqual(overrides["studies"]["mode_points"], 241)
            self.assertEqual(overrides["studies"]["time_end"], "1[s]")
            self.assertEqual(overrides["studies"]["time_step"], "1e-4[s]")

        self.assertEqual(
            counts,
            {
                "material": 5,
                "L_free": 5,
                "b": 5,
                "h": 5,
                "x0_ratio": 3,
                "J": 4,
            },
        )

    def test_case_overrides_are_applied_to_expected_cases(self) -> None:
        definition = self.load_case_definition()
        cases = {
            case["case_id"]: case
            for case in run_requested_full.build_cases(definition, PACKAGE_ROOT / "outputs" / "preview_full")
        }

        pvc = cases["material_pvc"]["config_overrides"]
        self.assertEqual(pvc["material"]["rho"], "1380[kg/m^3]")
        self.assertEqual(pvc["material"]["E"], "3.0e9[Pa]")

        length_case = cases["L_free_26cm"]["config_overrides"]
        self.assertEqual(length_case["geometry"]["L_free"], "0.26[m]")
        self.assertEqual(length_case["acoustics"]["air_radius"], "0.151[m]")

        impulse_case = cases["J_0p08Ns"]["config_overrides"]
        self.assertEqual(impulse_case["excitation"]["J"], "0.08[N*s]")

    def test_rendered_java_has_full_parameters_and_no_placeholders(self) -> None:
        base = json.loads((PACKAGE_ROOT / "config" / "params_base.json").read_text(encoding="utf-8"))
        resolved = run_case.resolve_config(base)
        params = run_case.normalized_params(resolved)

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            generated = tmp_path / "Linear_Acoustic_Field_3D_Air.java"
            model_path = tmp_path / "out" / "mph" / "linear_acoustic_field_3d_air.mph"
            run_case.render_java_source(
                PACKAGE_ROOT / "src" / "Linear_Acoustic_Field_3D_Air.java.template",
                generated,
                params,
                model_path,
            )

            text = generated.read_text(encoding="utf-8")

        self.assertNotIn("__LINEAR_PARAM_BLOCK__", text)
        self.assertNotIn("__MODE_POINTS__", text)
        self.assertNotIn("__AUTO_MESH_SIZE__", text)
        self.assertNotIn("__MODEL_SAVE_PATH__", text)
        self.assertIn('model.param().set("mesh_numelem", "120");', text)
        self.assertIn('model.param().set("time_end", "1[s]");', text)
        self.assertIn('exportMicSweepData', text)
        self.assertIn("linear_acoustic_field_3d_air.mph", text)

    def test_validate_csv_bundle_passes_for_minimal_valid_case(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "mph").mkdir()
            (root / "data").mkdir()
            (root / "mph" / "linear_acoustic_field_3d_air.mph").write_bytes(b"mph-placeholder")
            (root / "data" / "frequencies.csv").write_text("% mode,freq_hz\n1,100\n", encoding="utf-8")
            (root / "data" / "structure_probe_timeseries.csv").write_text("% t_s,uz_m\n0,0\n", encoding="utf-8")
            (root / "data" / "mic_pressure_timeseries.csv").write_text("% t_s,p_pa\n0,0\n", encoding="utf-8")
            (root / "data" / "impact_force_timeseries.csv").write_text("% t_s,force_z_N\n0,0\n", encoding="utf-8")
            (root / "data" / "mode_shapes.csv").write_text("% x_over_L,w_mode1\n0,0\n", encoding="utf-8")
            (root / "data" / "mic_pressure_timeseries_sweep_01.csv").write_text("% t_s,p_pa\n0,0\n", encoding="utf-8")

            extra = ["mic_pressure_timeseries_sweep_01.csv"]
            self.assertEqual(validate_csv_bundle.validate_bundle(root, extra_csv=extra), [])

    def test_validate_csv_bundle_rejects_missing_extra_csv(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "mph").mkdir()
            (root / "data").mkdir()
            (root / "mph" / "linear_acoustic_field_3d_air.mph").write_bytes(b"mph-placeholder")
            (root / "data" / "frequencies.csv").write_text("% mode,freq_hz\n1,100\n", encoding="utf-8")
            (root / "data" / "structure_probe_timeseries.csv").write_text("% t_s,uz_m\n0,0\n", encoding="utf-8")
            (root / "data" / "mic_pressure_timeseries.csv").write_text("% t_s,p_pa\n0,0\n", encoding="utf-8")
            (root / "data" / "impact_force_timeseries.csv").write_text("% t_s,force_z_N\n0,0\n", encoding="utf-8")
            (root / "data" / "mode_shapes.csv").write_text("% x_over_L,w_mode1\n0,0\n", encoding="utf-8")

            extra = ["mic_pressure_timeseries_sweep_01.csv"]
            errors = validate_csv_bundle.validate_bundle(root, extra_csv=extra)
            self.assertTrue(any("missing CSV" in error for error in errors))

    def test_validate_csv_bundle_rejects_missing_or_unnormalized_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "mph").mkdir()
            (root / "data").mkdir()
            (root / "mph" / "linear_acoustic_field_3d_air.mph").write_bytes(b"mph-placeholder")
            (root / "data" / "frequencies.csv").write_text("mode,freq_hz\n1,100\n", encoding="utf-8")

            errors = validate_csv_bundle.validate_bundle(root)

        self.assertTrue(any("header is not normalized" in error for error in errors))
        self.assertTrue(any("missing CSV" in error for error in errors))

    def test_requested_dry_run_does_not_create_outputs_or_runtime(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            output_root = tmp_path / "outputs" / "preview"
            runtime_root = tmp_path / "runtime" / "preview"
            env = os.environ.copy()
            env["PYTHONDONTWRITEBYTECODE"] = "1"
            subprocess.run(
                [
                    sys.executable,
                    "-B",
                    str(PACKAGE_ROOT / "tools" / "run_requested_full.py"),
                    "--study-id",
                    "preview",
                    "--output-root",
                    str(output_root),
                    "--runtime-root",
                    str(runtime_root),
                    "--dry-run",
                ],
                check=True,
                cwd=str(PACKAGE_ROOT),
                env=env,
                stdout=subprocess.DEVNULL,
            )

            self.assertFalse(output_root.exists())
            self.assertFalse(runtime_root.exists())


    def test_write_stdout_csvs_parses_markers_correctly(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            data_dir = Path(tmp)
            stdout = (
                "__CSV__frequencies.csv\n"
                "% mode,freq_hz\n"
                "1,100.0\n"
                "2,200.0\n"
                "__CSV_END__\n"
                "__CSV__mode_shapes.csv\n"
                "% x_over_L,w_mode1,w_mode2\n"
                "0,0,0\n"
                "1,1e-5,2e-5\n"
                "__CSV_END__\n"
            )
            write_stdout_csvs(stdout, data_dir)

            freq_csv = data_dir / "frequencies.csv"
            self.assertTrue(freq_csv.is_file())
            content = freq_csv.read_text(encoding="utf-8")
            self.assertIn("% mode,freq_hz", content)
            self.assertIn("1,100.0", content)
            self.assertIn("2,200.0", content)

            mode_csv = data_dir / "mode_shapes.csv"
            self.assertTrue(mode_csv.is_file())
            content = mode_csv.read_text(encoding="utf-8")
            self.assertIn("% x_over_L,w_mode1,w_mode2", content)
            self.assertIn("0,0,0", content)
            self.assertIn("1,1e-5,2e-5", content)

            unexpected = data_dir / "nonexistent.csv"
            self.assertFalse(unexpected.exists())

    def test_write_stdout_csvs_empty_marker_does_not_create_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            data_dir = Path(tmp)
            stdout = "__CSV__empty.csv\n__CSV_END__\n"
            write_stdout_csvs(stdout, data_dir)
            self.assertFalse((data_dir / "empty.csv").exists())

    def test_mic_sweep_filenames_count(self) -> None:
        result = mic_sweep_filenames()
        self.assertEqual(len(result), 11)  # 10 sweep + 1 metadata
        self.assertIn("mic_pressure_timeseries_sweep_01.csv", result)
        self.assertIn("mic_pressure_timeseries_sweep_10.csv", result)
        self.assertIn("mic_sweep_distances.csv", result)

    def test_write_stdout_csvs_no_markers_no_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            data_dir = Path(tmp)
            write_stdout_csvs("no markers here", data_dir)
            self.assertEqual(list(data_dir.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
