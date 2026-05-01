function main_linear_acoustic_field(config_path, model_path, output_root, quality, wallclock_build_s, disconnect_on_cleanup)
%MAIN_LINEAR_ACOUSTIC_FIELD Run acoustic-field postprocess for the EB line.

    if nargin < 4 || isempty(quality)
        quality = 'full';
    end
    if nargin < 5 || isempty(wallclock_build_s)
        wallclock_build_s = '0';
    end
    if nargin < 6 || isempty(disconnect_on_cleanup)
        disconnect_on_cleanup = true;
    else
        disconnect_on_cleanup = parse_scalar_double(disconnect_on_cleanup, 1) ~= 0;
    end

    config = read_json_file(config_path);
    mode_points = get_mode_points(config, 241);
    build_s = parse_scalar_double(wallclock_build_s, 0);
    mic_expr = 'if(use_air_domain,rho_air*A/(4*pi*mic_distance)*d(d(w,t),t),0[Pa])';
    result = run_beam_model_pipeline(struct( ...
        "model_path", model_path, ...
        "output_root", output_root, ...
        "data_dir_name", "data", ...
        "figures_dir_name", "figures", ...
        "num_modes", 6, ...
        "mode_points", mode_points, ...
        "beam_length_m", parse_physical_scalar(config.geometry.L_free, NaN), ...
        "include_mic", true, ...
        "mic_expr", mic_expr, ...
        "disconnect_on_cleanup", disconnect_on_cleanup ...
    ));

    data_dir = char(string(result.data_dir));
    figures_dir = char(string(result.figures_dir));

    [f_fft, a_fft] = compute_single_sided_fft(result.mic_table.t_s, result.mic_table.p_pa);
    fft_table = table(f_fft, a_fft, 'VariableNames', {'freq_hz', 'amp_pa'});
    writetable(fft_table, fullfile(data_dir, "mic_pressure_fft.csv"), 'Encoding', 'UTF-8');

    p_pp_pa = max(result.mic_table.p_pa) - min(result.mic_table.p_pa);
    spl_info = compute_spl_from_pressure(result.mic_table.p_pa);
    [~, idx_max] = max(a_fft);
    if isempty(idx_max)
        f_dom_hz = [];
    else
        f_dom_hz = f_fft(idx_max);
    end

    summary = struct();
    summary.model_line = "linear";
    summary.model_id = "acoustic_field";
    summary.model_class = "Linear_Acoustic_Field";
    summary.beam_formulation = "Euler-Bernoulli";
    summary.acoustic_formulation = "beam_to_surface_transient_air_scaffold_v1";
    summary.config_path = string(config_path);
    summary.quality = string(quality);
    summary.output_root = string(output_root);
    summary.data_dir = string(data_dir);
    summary.figures_dir = string(figures_dir);
    summary.solve_owner = string(result.solve_owner);
    summary.studies_rerun_in_matlab = logical(result.studies_rerun_in_matlab);
    summary.wallclock_build_s = build_s;
    summary.wallclock_export_s = result.wallclock_export_s;
    summary.wallclock_total_s = build_s + result.wallclock_export_s;
    summary.f1_hz = get_freq_value(result.freq_table, 1);
    summary.f2_hz = get_freq_value(result.freq_table, 2);
    summary.f3_hz = get_freq_value(result.freq_table, 3);
    summary.max_tip_displacement_m = max(abs(result.tip_w));
    summary.p_pp_pa = p_pp_pa;
    summary.p_rms_pa = spl_info.p_rms_pa;
    summary.spl_db = spl_info.spl_db;
    summary.spl_ref_pa = spl_info.spl_ref_pa;
    summary.f_dom_hz = f_dom_hz;
    summary.mode_points = mode_points;
    summary.mesh_numelem = get_mesh_numelem(config, 160);
    summary.L_total = string(config.geometry.L_total);
    summary.L_free = string(config.geometry.L_free);
    summary.b = string(config.geometry.b);
    summary.h = string(config.geometry.h);
    summary.rho = string(config.material.rho);
    summary.E = string(config.material.E);
    summary.nu = string(config.material.nu);
    summary.root = string(config.boundary.root);
    summary.tip = string(config.boundary.tip);
    summary.excitation_mode = string(config.excitation.mode);
    summary.x0 = string(config.excitation.x0);
    summary.J = string(config.excitation.J);
    summary.tau_imp = string(config.excitation.tau_imp);
    summary.initial_tip_displacement = string(config.excitation.initial_tip_displacement);
    summary.mic_position = "(L_free/2, 0, 0.06)[m]";
    summary.use_air_domain = string(config.acoustics.use_air_domain);
    summary.air_radius = string(config.acoustics.air_radius);
    summary.mic_distance = string(config.acoustics.mic_distance);
    summary.rho_air = string(config.acoustics.rho_air);
    summary.c_air = string(config.acoustics.c_air);

    export_run_summary(data_dir, summary);
    publish_output_bundle(output_root, summary, struct( ...
        "config_path", config_path, ...
        "table_files", {{ ...
            fullfile(data_dir, "frequencies.csv"), ...
            fullfile(data_dir, "tip_timeseries.csv"), ...
            fullfile(data_dir, "mode_shapes.csv"), ...
            fullfile(data_dir, "mic_pressure_timeseries.csv"), ...
            fullfile(data_dir, "mic_pressure_fft.csv") ...
        }}, ...
        "figure_files", {{ ...
            fullfile(figures_dir, "frequencies_bar.png"), ...
            fullfile(figures_dir, "tip_timeseries.png"), ...
            fullfile(figures_dir, "tip_fft.png"), ...
            fullfile(figures_dir, "mic_pressure_timeseries.png"), ...
            fullfile(figures_dir, "mic_pressure_fft.png"), ...
            fullfile(figures_dir, "pgmode_mode01.png"), ...
            fullfile(figures_dir, "pgmode_mode02.png"), ...
            fullfile(figures_dir, "pgmode_mode03.png"), ...
            fullfile(figures_dir, "pgmode_mode04.png"), ...
            fullfile(figures_dir, "pgmode_mode05.png"), ...
            fullfile(figures_dir, "pgmode_mode06.png") ...
        }}, ...
        "artifact_files", {{ ...
            fullfile(data_dir, "q_estimate.json"), ...
            fullfile(data_dir, "run_summary.json"), ...
            fullfile(data_dir, "run_summary.txt") ...
        }} ...
    ));
end

function value = get_mode_points(config, default_value)
    value = default_value;
    if isfield(config, "studies") && isfield(config.studies, "mode_points")
        value = parse_scalar_double(config.studies.mode_points, default_value);
    end
end

function value = get_mesh_numelem(config, default_value)
    value = default_value;
    if isfield(config, "mesh") && isfield(config.mesh, "numelem")
        value = parse_scalar_double(config.mesh.numelem, default_value);
    end
end

function value = parse_scalar_double(raw, default_value)
    value = parse_physical_scalar(raw, default_value);
end

function value = get_freq_value(freq_table, idx)
    if height(freq_table) >= idx
        value = freq_table.freq_hz(idx);
    else
        value = [];
    end
end
