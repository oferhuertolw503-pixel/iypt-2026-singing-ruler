function report = timbre_enhanced_analysis(proj_root, data_rel_root)
%TIMBRE_ENHANCED_ANALYSIS Summarize enhanced-medium timbre material cases.
%   report = timbre_enhanced_analysis()
%
%   Reads the completed 5-material x 2-impulse enhanced-medium cases and
%   writes paper tables/figures. This is a read-only postprocessing pass
%   over existing outputs; it does not start COMSOL or modify raw CSV.

    arguments
        proj_root (1, :) char = fullfile(fileparts(mfilename('fullpath')), '..', '..')
        data_rel_root (1, :) char = 'outputs/requested_timbre_complete_enhanced_medium'
    end

    addpath(fullfile(proj_root, 'matlab', 'core'));

    data_root = fullfile(proj_root, data_rel_root);
    tables_dir = fullfile(data_root, 'tables', 'paper_analysis');
    figures_dir = fullfile(data_root, 'figures', 'paper_analysis');
    ensure_dir(tables_dir);
    ensure_dir(figures_dir);

    summary = collect_timbre_cases(data_root);
    summary = sortrows(summary, {'material_order', 'impulse_order'});

    writetable(removevars(summary, {'material_order', 'impulse_order'}), ...
        fullfile(tables_dir, 'timbre_enhanced_summary.csv'), 'Encoding', 'UTF-8');

    low_j = summary(summary.impulse == "J_low", :);
    writetable(removevars(low_j, {'material_order', 'impulse_order'}), ...
        fullfile(tables_dir, 'timbre_lowJ_primary_summary.csv'), 'Encoding', 'UTF-8');

    sensitivity = make_j_sensitivity(summary);
    writetable(sensitivity, fullfile(tables_dir, 'timbre_J_sensitivity.csv'), 'Encoding', 'UTF-8');

    fig1 = plot_lowj_timbre_map(low_j);
    exportgraphics(fig1, fullfile(figures_dir, 'timbre_lowJ_material_map.png'), 'Resolution', 150);
    close(fig1);

    fig2 = plot_energy_bands(low_j);
    exportgraphics(fig2, fullfile(figures_dir, 'timbre_lowJ_energy_bands.png'), 'Resolution', 150);
    close(fig2);

    fig3 = plot_q_and_frequency(low_j);
    exportgraphics(fig3, fullfile(figures_dir, 'timbre_lowJ_q_frequency.png'), 'Resolution', 150);
    close(fig3);

    fig4 = plot_j_sensitivity(sensitivity);
    exportgraphics(fig4, fullfile(figures_dir, 'timbre_J_sensitivity.png'), 'Resolution', 150);
    close(fig4);

    fprintf('=== TIMBRE ENHANCED ANALYSIS COMPLETE ===\n');
    fprintf('Cases: %d\n', height(summary));
    fprintf('Tables: %s\n', tables_dir);
    fprintf('Figures: %s\n', figures_dir);

    report = struct('tables_dir', tables_dir, 'figures_dir', figures_dir, ...
        'n_cases', height(summary));
end

function tbl = collect_timbre_cases(data_root)
    case_dirs = dir(data_root);
    case_dirs = case_dirs([case_dirs.isdir]);
    case_dirs = case_dirs(~ismember({case_dirs.name}, {'.', '..', 'configs', 'tables', 'figures'}));

    rows = table();
    for i = 1:numel(case_dirs)
        case_id = string(case_dirs(i).name);
        case_root = fullfile(case_dirs(i).folder, case_dirs(i).name);
        data_dir = fullfile(case_root, 'data');
        if ~isfile(fullfile(data_dir, 'acoustic_metrics.csv')) || ...
                ~isfile(fullfile(data_dir, 'structural_metrics.csv')) || ...
                ~isfile(fullfile(data_dir, 'timbre_metrics_extended.csv'))
            continue;
        end

        [material, impulse] = parse_case_id(case_id);
        acoustic = readtable(fullfile(data_dir, 'acoustic_metrics.csv'));
        structural = readtable(fullfile(data_dir, 'structural_metrics.csv'));
        timbre = readtable(fullfile(data_dir, 'timbre_metrics_extended.csv'));
        params = read_params(fullfile(case_root, 'params_resolved.json'));

        probe_peak_m = structural.probe_peak_m(1);
        linear_ratio = probe_peak_m / params.L_free_m;
        [linear_status, data_usage] = classify_linearity(linear_ratio, impulse);

        row = table();
        row.case_id = case_id;
        row.material = material;
        row.impulse = impulse;
        row.J_Ns = params.J_Ns;
        row.f_dom_refined_hz = acoustic.f_dom_refined_hz(1);
        row.spl_rms_db = acoustic.spl_rms_db(1);
        row.spectral_centroid_hz = acoustic.spectral_centroid_hz(1);
        row.spectral_flatness = acoustic.spectral_flatness(1);
        row.rolloff85_hz = acoustic.rolloff85_hz(1);
        row.q_estimate = structural.q_estimate(1);
        row.log_decrement = structural.log_decrement(1);
        row.probe_peak_m = probe_peak_m;
        row.probe_peak_over_L = linear_ratio;
        row.peak_count = timbre.peak_count(1);
        row.dominant_to_second_peak_ratio = timbre.dominant_to_second_peak_ratio(1);
        row.low_energy_ratio = timbre.low_energy_ratio(1);
        row.mid_energy_ratio = timbre.mid_energy_ratio(1);
        row.high_energy_ratio = timbre.high_energy_ratio(1);
        row.spectral_slope_db_per_octave = timbre.spectral_slope_db_per_octave(1);
        row.decay_time_50pct_s = timbre.decay_time_50pct_s(1);
        row.energy_decay_85pct_s = timbre.energy_decay_85pct_s(1);
        row.second_peak_freq_hz = timbre.second_peak_freq_hz(1);
        row.linear_status = linear_status;
        row.data_usage = data_usage;
        row.material_order = material_order(material);
        row.impulse_order = impulse_order(impulse);

        rows = [rows; row]; %#ok<AGROW>
    end

    tbl = rows;
end

function [material, impulse] = parse_case_id(case_id)
    if endsWith(case_id, "_J_low")
        impulse = "J_low";
        material = extractBefore(case_id, "_J_low");
    elseif endsWith(case_id, "_J_orig")
        impulse = "J_orig";
        material = extractBefore(case_id, "_J_orig");
    else
        error('Unexpected timbre case id: %s', case_id);
    end
end

function params = read_params(path)
    params = struct('L_free_m', 0.20, 'J_Ns', NaN);
    if ~isfile(path)
        return;
    end
    txt = fileread(path);
    cfg = jsondecode(txt);
    if isfield(cfg, 'geometry') && isfield(cfg.geometry, 'L_free')
        params.L_free_m = parse_quantity(cfg.geometry.L_free);
    end
    if isfield(cfg, 'excitation') && isfield(cfg.excitation, 'J')
        params.J_Ns = parse_quantity(cfg.excitation.J);
    end
end

function value = parse_quantity(text_value)
    s = char(text_value);
    tok = regexp(s, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match', 'once');
    value = str2double(tok);
end

function [status, usage] = classify_linearity(ratio, impulse)
    if ratio <= 0.05
        status = "linear";
        if impulse == "J_low"
            usage = "primary";
        else
            usage = "comparison";
        end
    elseif ratio <= 0.10
        status = "borderline";
        usage = "diagnostic";
    else
        status = "nonlinear_risk";
        usage = "diagnostic";
    end
end

function order = material_order(material)
    names = ["steel", "acrylic", "pvc", "satinwood", "xuefu_board"];
    idx = find(names == material, 1);
    if isempty(idx)
        order = 99;
    else
        order = idx;
    end
end

function order = impulse_order(impulse)
    if impulse == "J_low"
        order = 1;
    else
        order = 2;
    end
end

function label = material_label(material)
    switch char(material)
        case 'steel'
            label = "Steel";
        case 'acrylic'
            label = "Acrylic";
        case 'pvc'
            label = "PVC";
        case 'satinwood'
            label = "Satinwood";
        case 'xuefu_board'
            label = "Xuefu board";
        otherwise
            label = string(material);
    end
end

function labels = material_labels(materials)
    labels = strings(numel(materials), 1);
    for i = 1:numel(materials)
        labels(i) = material_label(materials(i));
    end
end

function sensitivity = make_j_sensitivity(summary)
    mats = unique(summary.material, 'stable');
    sensitivity = table();
    for i = 1:numel(mats)
        mat = mats(i);
        low = summary(summary.material == mat & summary.impulse == "J_low", :);
        orig = summary(summary.material == mat & summary.impulse == "J_orig", :);
        if isempty(low) || isempty(orig)
            continue;
        end
        row = table();
        row.material = mat;
        row.spl_gain_db = orig.spl_rms_db(1) - low.spl_rms_db(1);
        row.f_shift_hz = orig.f_dom_refined_hz(1) - low.f_dom_refined_hz(1);
        row.centroid_shift_hz = orig.spectral_centroid_hz(1) - low.spectral_centroid_hz(1);
        row.q_shift = orig.q_estimate(1) - low.q_estimate(1);
        row.lowJ_linear_status = low.linear_status(1);
        row.orig_linear_status = orig.linear_status(1);
        row.lowJ_probe_over_L = low.probe_peak_over_L(1);
        row.orig_probe_over_L = orig.probe_peak_over_L(1);
        sensitivity = [sensitivity; row]; %#ok<AGROW>
    end
end

function fig = plot_lowj_timbre_map(low_j)
    fig = figure('Visible', 'off', 'Position', [100 100 760 520]);
    scatter(low_j.spectral_centroid_hz, low_j.spectral_flatness, ...
        90 + 5 * low_j.q_estimate, low_j.spl_rms_db, 'filled', ...
        'MarkerEdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.8);
    colormap(parula);
    cb = colorbar;
    ylabel(cb, 'SPL_{RMS} (dB)');
    xlabel('Spectral centroid (Hz)');
    ylabel('Spectral flatness');
    title('Material Timbre Map (Enhanced Medium, J_{low}=0.004 N s)');
    grid on;

    for i = 1:height(low_j)
        text(low_j.spectral_centroid_hz(i) + 8, low_j.spectral_flatness(i), ...
            material_label(low_j.material(i)), 'FontSize', 9);
    end

    text(0.98, 0.03, '0.75 s | dt=1e-4 s | mesh=100 | marker size=Q', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 8, 'Color', [0.45 0.45 0.45]);
end

function fig = plot_energy_bands(low_j)
    fig = figure('Visible', 'off', 'Position', [100 100 760 520]);
    bands = [low_j.low_energy_ratio, low_j.mid_energy_ratio, low_j.high_energy_ratio];
    bar(bands, 'stacked');
    xticklabels(material_labels(low_j.material));
    xtickangle(25);
    ylim([0 1]);
    ylabel('Energy ratio');
    title('Low/Mid/High Frequency Energy Split (J_{low})');
    legend({'Low', 'Mid', 'High'}, 'Location', 'eastoutside');
    grid on;
    text(0.98, 0.03, 'Ratios from timbre\_metrics\_extended.csv', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 8, 'Color', [0.45 0.45 0.45]);
end

function fig = plot_q_and_frequency(low_j)
    fig = figure('Visible', 'off', 'Position', [100 100 760 520]);
    x = 1:height(low_j);
    yyaxis left;
    bar(x - 0.15, low_j.f_dom_refined_hz, 0.3, 'FaceColor', [0.2 0.45 0.75]);
    ylabel('f_{dom} (Hz)');
    yyaxis right;
    bar(x + 0.15, low_j.q_estimate, 0.3, 'FaceColor', [0.85 0.45 0.15]);
    ylabel('Q estimate');
    xticks(x);
    xticklabels(material_labels(low_j.material));
    xtickangle(25);
    title('Dominant Frequency and Q by Material (J_{low})');
    grid on;
    legend({'f_{dom}', 'Q'}, 'Location', 'northwest');
end

function fig = plot_j_sensitivity(sensitivity)
    fig = figure('Visible', 'off', 'Position', [100 100 820 520]);
    x = 1:height(sensitivity);
    yyaxis left;
    bar(x, sensitivity.spl_gain_db, 0.5, 'FaceColor', [0.45 0.65 0.35]);
    ylabel('SPL gain: J_{orig} - J_{low} (dB)');
    yyaxis right;
    plot(x, sensitivity.orig_probe_over_L, 'o-', 'Color', [0.85 0.2 0.2], ...
        'LineWidth', 1.6, 'MarkerFaceColor', [0.85 0.2 0.2]);
    hold on;
    yline(0.05, '--', 'Linear threshold 0.05', 'Color', [0.3 0.3 0.3]);
    yline(0.10, ':', 'Diagnostic threshold 0.10', 'Color', [0.3 0.3 0.3]);
    hold off;
    ylabel('J_{orig} probe peak / L');
    xticks(x);
    xticklabels(material_labels(sensitivity.material));
    xtickangle(25);
    title('Impulse Sensitivity and Linearity Risk');
    grid on;
    text(0.98, 0.03, 'J_{orig} is diagnostic except where linearity holds', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 8, 'Color', [0.45 0.45 0.45]);
end
