function main_linear_acoustic_field_3d_air(config_path, model_path, output_root, quality, wallclock_build_s, disconnect_on_cleanup)
%MAIN_LINEAR_ACOUSTIC_FIELD_3D_AIR Postprocess the 3D solid + real-air line.

    if nargin < 4 || isempty(quality)
        quality = 'full';
    end
    if nargin < 5 || isempty(wallclock_build_s)
        wallclock_build_s = '0';
    end
    if nargin < 6 || isempty(disconnect_on_cleanup)
        disconnect_on_cleanup = true; %#ok<NASGU>
    end

    configure_plot_defaults();
    config = read_json_file(config_path);
    build_s = parse_physical_scalar(wallclock_build_s, 0);

    data_dir = fullfile(output_root, 'data');
    figures_dir = fullfile(output_root, 'figures');
    ensure_dir(data_dir);
    ensure_dir(figures_dir);

    freq_table = read_exported_numeric_csv(fullfile(data_dir, 'frequencies.csv'));
    probe_table = read_exported_numeric_csv(fullfile(data_dir, 'structure_probe_timeseries.csv'));
    mode_table = read_exported_numeric_csv(fullfile(data_dir, 'mode_shapes.csv'));
    mic_table = read_exported_numeric_csv(fullfile(data_dir, 'mic_pressure_timeseries.csv'));
    force_table = read_exported_numeric_csv(fullfile(data_dir, 'impact_force_timeseries.csv'));

    plot_frequency_bar(freq_table, fullfile(figures_dir, 'frequencies_bar.png'));
    plot_series(probe_table.t_s, probe_table.uz_m, fullfile(figures_dir, 'structure_probe_timeseries.png'), ...
        'Structure probe z-displacement', 'u_z (m)', '#1D3557');
    plot_fft(probe_table.t_s, probe_table.uz_m, fullfile(figures_dir, 'structure_probe_fft.png'), ...
        'Structure probe spectrum', 'Amplitude |U_z(f)| (m)', 6000);
    plot_series(mic_table.t_s, mic_table.p_pa, fullfile(figures_dir, 'mic_pressure_timeseries.png'), ...
        'Microphone pressure time series', 'Pressure p (Pa)', '#7A3E9D');
    plot_fft(mic_table.t_s, mic_table.p_pa, fullfile(figures_dir, 'mic_pressure_fft.png'), ...
        'Microphone pressure spectrum', 'Amplitude |P(f)| (Pa)', 6000);
    plot_mode_shapes(mode_table, figures_dir);

    [f_fft, a_fft] = compute_single_sided_fft(mic_table.t_s, mic_table.p_pa);
    fft_table = table(f_fft, a_fft, 'VariableNames', {'freq_hz', 'amp_pa'});
    writetable(fft_table, fullfile(data_dir, 'mic_pressure_fft.csv'), 'Encoding', 'UTF-8');

    plot_structure_mic_compare(freq_table, f_fft, a_fft, fullfile(figures_dir, 'mic_structure_frequency_compare.png'));

    spl_info = compute_spl_from_pressure(mic_table.p_pa);
    p_pp_pa = max(mic_table.p_pa) - min(mic_table.p_pa);
    impact_force_impulse_Ns = integrate_trapezoid(force_table.t_s, force_table.force_z_N);
    impact_force_peak_abs_N = max(abs(force_table.force_z_N));
    if isempty(a_fft)
        f_dom_hz = [];
    else
        [~, idx_max] = max(a_fft);
        f_dom_hz = f_fft(idx_max);
    end

    summary = struct();
    summary.model_line = "linear";
    summary.model_id = "acoustic_field_3d_air";
    summary.model_class = "Linear_Acoustic_Field_3D_Air";
    summary.structure_formulation = "3d_solid_linear_elastic";
    summary.acoustic_formulation = "3d_pressure_acoustics_transient";
    summary.coupling_strategy = "strict_sequential_one_way_structure_then_air";
    summary.coupling_notes = "The structure transient is solved first. The real 3D air-domain transient is solved afterward and is driven by the stored structural boundary acceleration; acoustic pressure does not feed back into the structure.";
    summary.transient_solver_topology = "sequential_transient_studies_solid_then_actd";
    summary.structure_transient_solution = "sol2";
    summary.air_transient_solution = "sol3";
    summary.config_path = string(config_path);
    summary.model_path = string(model_path);
    summary.quality = string(quality);
    summary.output_root = string(output_root);
    summary.data_dir = string(data_dir);
    summary.figures_dir = string(figures_dir);
    summary.solve_owner = "java_batch_csv";
    summary.studies_rerun_in_matlab = false;
    summary.wallclock_build_s = build_s;
    summary.wallclock_export_s = 0;
    summary.wallclock_total_s = build_s;
    summary.f1_hz = get_freq_value(freq_table, 1);
    summary.f2_hz = get_freq_value(freq_table, 2);
    summary.f3_hz = get_freq_value(freq_table, 3);
    summary.f4_hz = get_freq_value(freq_table, 4);
    summary.f5_hz = get_freq_value(freq_table, 5);
    summary.f6_hz = get_freq_value(freq_table, 6);
    summary.max_structure_probe_abs_m = max(abs(probe_table.uz_m));
    summary.p_pp_pa = p_pp_pa;
    summary.p_rms_pa = spl_info.p_rms_pa;
    summary.spl_db = spl_info.spl_db;
    summary.spl_ref_pa = spl_info.spl_ref_pa;
    summary.f_dom_hz = f_dom_hz;
    summary.mic_peak_abs_pa = max(abs(mic_table.p_pa));
    summary.impact_force_peak_abs_N = impact_force_peak_abs_N;
    summary.impact_force_impulse_Ns = impact_force_impulse_Ns;
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
    summary.impulse_target_Ns = string(config.excitation.J);
    summary.tau_imp = string(config.excitation.tau_imp);
    summary.pulse_shape = string(config.excitation.pulse_shape);
    summary.impact_patch_dx = string(config.excitation.impact_patch_dx);
    summary.impact_patch_dy = string(config.excitation.impact_patch_dy);
    summary.zeta_struct = string(config.damping.zeta_struct);
    summary.f_damp_low = string(get_config_damping_value(config, 'f_damp_low', 'f_damp_ref'));
    summary.f_damp_high = string(get_config_damping_value(config, 'f_damp_high', 'f_damp_ref'));
    summary.damping_model = "rayleigh_mass_and_stiffness_two_reference_frequencies";
    summary.impact_model = "equivalent_impulse_no_explicit_ball";
    summary.force_time_function = "single_peak_half_sine";
    summary.force_direction = "thickness_direction_z";
    summary.use_real_air_domain = string(config.acoustics.use_real_air_domain);
    summary.air_shape = string(config.acoustics.air_shape);
    summary.air_radius = string(config.acoustics.air_radius);
    summary.rho_air = string(config.acoustics.rho_air);
    summary.c_air = string(config.acoustics.c_air);
    summary.mic_x = string(config.acoustics.mic_x);
    summary.mic_y = string(config.acoustics.mic_y);
    summary.mic_z = string(config.acoustics.mic_z);
    summary.mic_offset_from_surface_m = string(config.acoustics.mic_offset_from_surface_m);
    summary.time_end = string(config.studies.time_end);
    summary.time_step = string(config.studies.time_step);
    summary.structure_direct_outputs = ["frequencies.csv", "structure_probe_timeseries.csv", "mode_shapes.csv"];
    summary.air_direct_outputs = ["mic_pressure_timeseries.csv"];
    summary.excitation_direct_outputs = ["impact_force_timeseries.csv"];
    summary.matlab_derived_outputs = ["mic_pressure_fft.csv", "summary.json", "summary.txt", "run_summary.json", "run_summary.txt", "figures/*.png"];
    summary.provenance_structure = "COMSOL_direct_export_from_sequential_structure_solution_sol2";
    summary.provenance_air = "COMSOL_direct_export_from_sequential_air_solution_sol3";
    summary.provenance_excitation = "COMSOL_direct_export";
    summary.provenance_matlab = "MATLAB_postprocess";

    export_run_summary(data_dir, summary);
    publish_output_bundle(output_root, summary, struct( ...
        "config_path", config_path, ...
        "table_files", {{ ...
            fullfile(data_dir, 'frequencies.csv'), ...
            fullfile(data_dir, 'structure_probe_timeseries.csv'), ...
            fullfile(data_dir, 'mode_shapes.csv'), ...
            fullfile(data_dir, 'mic_pressure_timeseries.csv'), ...
            fullfile(data_dir, 'impact_force_timeseries.csv'), ...
            fullfile(data_dir, 'mic_pressure_fft.csv') ...
        }}, ...
        "figure_files", {{ ...
            fullfile(figures_dir, 'frequencies_bar.png'), ...
            fullfile(figures_dir, 'structure_probe_timeseries.png'), ...
            fullfile(figures_dir, 'structure_probe_fft.png'), ...
            fullfile(figures_dir, 'mic_pressure_timeseries.png'), ...
            fullfile(figures_dir, 'mic_pressure_fft.png'), ...
            fullfile(figures_dir, 'mic_structure_frequency_compare.png'), ...
            fullfile(figures_dir, 'pgmode_mode01.png'), ...
            fullfile(figures_dir, 'pgmode_mode02.png'), ...
            fullfile(figures_dir, 'pgmode_mode03.png'), ...
            fullfile(figures_dir, 'pgmode_mode04.png'), ...
            fullfile(figures_dir, 'pgmode_mode05.png'), ...
            fullfile(figures_dir, 'pgmode_mode06.png') ...
        }}, ...
        "artifact_files", {{ ...
            fullfile(data_dir, 'run_summary.json'), ...
            fullfile(data_dir, 'run_summary.txt'), ...
            fullfile(output_root, 'summary.json'), ...
            fullfile(output_root, 'summary.txt'), ...
            fullfile(output_root, 'run_manifest.txt') ...
        }} ...
    ));
end

function value = get_freq_value(freq_table, idx)
    if height(freq_table) >= idx
        value = freq_table.freq_hz(idx);
    else
        value = [];
    end
end

function plot_structure_mic_compare(freq_table, f_fft, a_fft, output_path)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100, 100, 1200, 600]);
    ax = axes(fig);
    hold(ax, 'on');
    plot(ax, f_fft, a_fft, 'LineWidth', 1.4, 'Color', '#7A3E9D');
    mode_freqs = freq_table.freq_hz(:);
    ymax = max([a_fft(:); 1e-12]);
    for i = 1:min(6, numel(mode_freqs))
        xline(ax, mode_freqs(i), '--', sprintf('f%d', i), 'Color', '#D1495B', 'LineWidth', 1.0, ...
            'LabelVerticalAlignment', 'middle', 'LabelOrientation', 'horizontal');
    end
    xlim(ax, [0, max([mode_freqs(:); 6000])]);
    ylim(ax, [0, ymax * 1.1]);
    grid(ax, 'on');
    xlabel(ax, 'Frequency (Hz)');
    ylabel(ax, 'Amplitude (Pa)');
    title(ax, 'Microphone FFT with structural eigenfrequency markers');
    exportgraphics(fig, output_path, 'Resolution', 200);
    close(fig);
end

function value = integrate_trapezoid(t_s, y)
    if numel(t_s) < 2 || numel(y) < 2
        value = 0;
        return;
    end
    value = trapz(t_s, y);
end

function value = get_config_damping_value(config, primary_field, fallback_field)
    if isfield(config, 'damping') && isfield(config.damping, primary_field)
        value = config.damping.(primary_field);
        return;
    end
    if isfield(config, 'damping') && isfield(config.damping, fallback_field)
        value = config.damping.(fallback_field);
        return;
    end
    value = "";
end
