function main_linear_acoustic_param_study(study_manifest_path, study_root)
%MAIN_LINEAR_ACOUSTIC_PARAM_STUDY Run parameter-study case postprocess and experiment aggregation.

    arguments
        study_manifest_path (1, :) char
        study_root (1, :) char
    end

    configure_plot_defaults();
    ensure_dir(study_root);

    study_manifest = read_json_file(study_manifest_path);
    cases = normalize_case_array(study_manifest);
    if isempty(cases)
        error("Study manifest has no cases: %s", study_manifest_path);
    end

    for i = 1:numel(cases)
        fprintf("[MATLAB batch] case %d/%d: %s\n", i, numel(cases), char(string(cases(i).case_id)));
        run_case_postprocess(cases(i));
    end

    tables_dir = fullfile(study_root, "tables");
    figures_dir = fullfile(study_root, "figures");
    ensure_dir(tables_dir);
    ensure_dir(figures_dir);

    rows = repmat(make_empty_case_row(), numel(cases), 1);
    for i = 1:numel(cases)
        rows(i) = build_case_row(cases(i));
    end
    all_cases = struct2table(rows);
    all_cases = sortrows(all_cases, {'is_baseline', 'primary_variable', 'case_id'}, {'descend', 'ascend', 'ascend'});
    writetable(all_cases, fullfile(tables_dir, "all_cases.csv"), 'Encoding', 'UTF-8');

    study_selection = lower(strtrim(char(string(study_manifest.study_selection))));
    table_files = {fullfile(tables_dir, "all_cases.csv")};
    figure_files = {};

    if is_requested_study(study_selection, 'timbre')
        timbre_summary = subset_for_study(all_cases, "timbre");
        writetable(timbre_summary, fullfile(tables_dir, "timbre_summary.csv"), 'Encoding', 'UTF-8');
        create_timbre_overview_figure(timbre_summary, fullfile(figures_dir, "linear_timbre_overview.png"));
        table_files{end + 1} = fullfile(tables_dir, "timbre_summary.csv"); %#ok<AGROW>
        figure_files{end + 1} = fullfile(figures_dir, "linear_timbre_overview.png"); %#ok<AGROW>
    end

    if is_requested_study(study_selection, 'amplitude')
        amplitude_summary = subset_for_study(all_cases, "amplitude");
        writetable(amplitude_summary, fullfile(tables_dir, "amplitude_summary.csv"), 'Encoding', 'UTF-8');
        create_amplitude_overview_figure(amplitude_summary, fullfile(figures_dir, "linear_amplitude_overview.png"));
        table_files{end + 1} = fullfile(tables_dir, "amplitude_summary.csv"); %#ok<AGROW>
        figure_files{end + 1} = fullfile(figures_dir, "linear_amplitude_overview.png"); %#ok<AGROW>
    end

    if is_requested_study(study_selection, 'frequency')
        frequency_summary = subset_for_frequency(all_cases);
        writetable(frequency_summary, fullfile(tables_dir, "frequency_summary.csv"), 'Encoding', 'UTF-8');
        create_frequency_overview_figure(frequency_summary, fullfile(figures_dir, "linear_frequency_overview.png"));
        table_files{end + 1} = fullfile(tables_dir, "frequency_summary.csv"); %#ok<AGROW>
        figure_files{end + 1} = fullfile(figures_dir, "linear_frequency_overview.png"); %#ok<AGROW>
    end

    summary = build_study_summary(study_manifest, all_cases, study_manifest_path, study_root, tables_dir, figures_dir);
    publish_output_bundle(study_root, summary, struct( ...
        "table_files", {table_files}, ...
        "figure_files", {figure_files}, ...
        "artifact_files", {{study_manifest_path}}));
end

function tf = is_requested_study(study_selection, target)
    tf = strcmpi(study_selection, 'all') || strcmpi(study_selection, target);
end

function cases = normalize_case_array(study_manifest)
    if ~isfield(study_manifest, "cases") || isempty(study_manifest.cases)
        cases = struct([]);
        return;
    end
    cases = study_manifest.cases;
    if iscell(cases)
        cases = [cases{:}];
    end
end

function run_case_postprocess(case_info)
    case_manifest_path = required_case_text(case_info, "case_manifest_path");
    manifest = read_matlab_handoff_manifest(case_manifest_path);
    if strlength(string(manifest.status_path)) > 0
        write_matlab_handoff_status(manifest.status_path, "running", manifest, ...
            "message", "Case MATLAB postprocess is running inside study aggregation.");
    end

    try
        switch string(manifest.invoke_style)
            case "manifest_path"
                feval(manifest.entry_function, manifest.manifest_path);
            case "function_args"
                feval(manifest.entry_function, manifest.function_args{:});
            otherwise
                error("Unsupported manifest invoke_style: %s", manifest.invoke_style);
        end

        if strlength(string(manifest.status_path)) > 0
            write_matlab_handoff_status(manifest.status_path, "completed", manifest, ...
                "message", "Case MATLAB postprocess completed from study aggregation.");
        end
    catch ME
        report = getReport(ME, "extended", "hyperlinks", "off");
        if strlength(string(manifest.status_path)) > 0
            write_matlab_handoff_status(manifest.status_path, "failed", manifest, ...
                "message", "Case MATLAB postprocess failed from study aggregation.", ...
                "error_report", report);
        end
        rethrow(ME);
    end
end

function row = make_empty_case_row()
    row = struct( ...
        "case_id", "", ...
        "is_baseline", false, ...
        "primary_variable", "", ...
        "study_tags", "", ...
        "L_free_cm", NaN, ...
        "x0_ratio", NaN, ...
        "x0_cm", NaN, ...
        "b_cm", NaN, ...
        "h_mm", NaN, ...
        "J_Ns", NaN, ...
        "f1_hz", NaN, ...
        "f2_hz", NaN, ...
        "f3_hz", NaN, ...
        "f_dom_hz", NaN, ...
        "p_pp_pa", NaN, ...
        "p_rms_pa", NaN, ...
        "spl_db", NaN, ...
        "max_tip_displacement_m", NaN, ...
        "q_estimate", NaN, ...
        "log_decrement", NaN, ...
        "q_num_peaks", NaN, ...
        "peak1_hz", NaN, ...
        "peak1_amp_pa", NaN, ...
        "peak2_hz", NaN, ...
        "peak2_amp_pa", NaN, ...
        "peak3_hz", NaN, ...
        "peak3_amp_pa", NaN, ...
        "spectral_centroid_hz", NaN, ...
        "spectral_bandwidth_hz", NaN, ...
        "rolloff85_hz", NaN, ...
        "mic_peak_abs_pa", NaN, ...
        "data_provenance", "", ...
        "is_real_comsol_case", false, ...
        "output_root", "", ...
        "mph_path", "", ...
        "case_log_path", "", ...
        "frequencies_csv_path", "", ...
        "tip_timeseries_csv_path", "", ...
        "mode_shapes_csv_path", "", ...
        "mic_pressure_timeseries_csv_path", "", ...
        "mic_pressure_fft_csv_path", "", ...
        "q_estimate_json_path", "");
end

function row = build_case_row(case_info)
    row = make_empty_case_row();
    row.case_id = string(required_case_text(case_info, "case_id"));
    row.is_baseline = logical(get_case_value(case_info, "is_baseline", false));
    row.primary_variable = string(required_case_text(case_info, "primary_variable"));
    row.study_tags = string(strjoin(to_cellstr(get_case_value(case_info, "study_tags", {})), "|"));
    row.L_free_cm = get_case_number(case_info, "L_free_cm", NaN);
    row.x0_ratio = get_case_number(case_info, "x0_ratio", NaN);
    row.x0_cm = get_case_number(case_info, "x0_cm", NaN);
    row.b_cm = get_case_number(case_info, "b_cm", NaN);
    row.h_mm = get_case_number(case_info, "h_mm", NaN);
    row.J_Ns = get_case_number(case_info, "J_Ns", NaN);

    row.output_root = string(required_case_text(case_info, "output_root"));
    row.mph_path = string(required_case_text(case_info, "mph_path"));
    row.case_log_path = string(required_case_text(case_info, "case_log_path"));
    row.frequencies_csv_path = string(required_case_text(case_info, "frequencies_csv_path"));
    row.tip_timeseries_csv_path = string(required_case_text(case_info, "tip_timeseries_csv_path"));
    row.mode_shapes_csv_path = string(required_case_text(case_info, "mode_shapes_csv_path"));
    row.mic_pressure_timeseries_csv_path = string(required_case_text(case_info, "mic_pressure_timeseries_csv_path"));
    row.mic_pressure_fft_csv_path = string(required_case_text(case_info, "mic_pressure_fft_csv_path"));
    row.q_estimate_json_path = string(required_case_text(case_info, "q_estimate_json_path"));

    summary = read_json_file(required_case_text(case_info, "summary_json_path"));
    row.f1_hz = get_numeric_field(summary, "f1_hz", NaN);
    row.f2_hz = get_numeric_field(summary, "f2_hz", NaN);
    row.f3_hz = get_numeric_field(summary, "f3_hz", NaN);
    row.f_dom_hz = get_numeric_field(summary, "f_dom_hz", NaN);
    row.p_pp_pa = get_numeric_field(summary, "p_pp_pa", NaN);
    row.p_rms_pa = get_numeric_field(summary, "p_rms_pa", NaN);
    row.spl_db = get_numeric_field(summary, "spl_db", NaN);
    row.max_tip_displacement_m = get_numeric_field(summary, "max_tip_displacement_m", NaN);

    q_info = read_optional_json(required_case_text(case_info, "q_estimate_json_path"));
    if ~isempty(q_info)
        row.q_estimate = get_numeric_field(q_info, "q_estimate", NaN);
        row.log_decrement = get_numeric_field(q_info, "log_decrement", NaN);
        row.q_num_peaks = get_numeric_field(q_info, "num_peaks", NaN);
    end

    mic_table = read_exported_numeric_csv(required_case_text(case_info, "mic_pressure_timeseries_csv_path"));
    timbre = extract_timbre_features_from_pressure(double(mic_table.t_s), double(mic_table.p_pa));
    row.peak1_hz = timbre.peak1_hz;
    row.peak1_amp_pa = timbre.peak1_amp_pa;
    row.peak2_hz = timbre.peak2_hz;
    row.peak2_amp_pa = timbre.peak2_amp_pa;
    row.peak3_hz = timbre.peak3_hz;
    row.peak3_amp_pa = timbre.peak3_amp_pa;
    row.spectral_centroid_hz = timbre.spectral_centroid_hz;
    row.spectral_bandwidth_hz = timbre.spectral_bandwidth_hz;
    row.rolloff85_hz = timbre.rolloff85_hz;
    row.mic_peak_abs_pa = timbre.mic_peak_abs_pa;

    row.data_provenance = "COMSOL_case + MATLAB_postprocess";
    row.is_real_comsol_case = isfile(required_case_text(case_info, "mph_path")) && ...
        isfile(required_case_text(case_info, "case_log_path")) && ...
        isfile(required_case_text(case_info, "frequencies_csv_path")) && ...
        isfile(required_case_text(case_info, "tip_timeseries_csv_path")) && ...
        isfile(required_case_text(case_info, "mode_shapes_csv_path")) && ...
        isfile(required_case_text(case_info, "mic_pressure_timeseries_csv_path"));
end

function tbl = subset_for_study(all_cases, study_name)
    mask = contains(string(all_cases.study_tags), study_name);
    tbl = all_cases(mask, :);
end

function tbl = subset_for_frequency(all_cases)
    mask = contains(string(all_cases.study_tags), "frequency");
    tbl = all_cases(mask, :);
    tbl.f_dom_minus_f1_hz = tbl.f_dom_hz - tbl.f1_hz;
    tbl.f_dom_minus_f1_abs_hz = abs(tbl.f_dom_minus_f1_hz);
end

function summary = build_study_summary(study_manifest, all_cases, study_manifest_path, study_root, tables_dir, figures_dir)
    summary = struct();
    summary.model_line = "linear";
    summary.model_id = "acoustic_param_study";
    summary.study_id = string(get_struct_text(study_manifest, "study_id", ""));
    summary.study_selection = string(get_struct_text(study_manifest, "study_selection", ""));
    summary.design = string(get_struct_text(study_manifest, "design", ""));
    summary.quality = string(get_struct_text(study_manifest, "quality", ""));
    summary.output_root = string(study_root);
    summary.study_manifest_path = string(study_manifest_path);
    summary.tables_dir = string(tables_dir);
    summary.figures_dir = string(figures_dir);
    summary.case_count = height(all_cases);
    summary.case_count_by_variable = get_struct_value(study_manifest, "case_count_by_variable", struct());
    summary.point_count_by_variable = get_struct_value(study_manifest, "point_count_by_variable", struct());
    summary.baseline_case_id = string(get_struct_text(study_manifest, "baseline_case_id", "baseline"));
    summary.baseline = get_struct_value(study_manifest, "baseline", struct());
    summary.scan_values = get_struct_value(study_manifest, "scan_values", struct());
    summary.data_provenance = struct( ...
        "raw_comsol_artifacts", {{"mph/linear_acoustic_field.mph", "logs/linear_acoustic_field.log", "data/frequencies.csv", "data/tip_timeseries.csv", "data/mode_shapes.csv", "data/mic_pressure_timeseries.csv"}}, ...
        "matlab_derived_artifacts", {{"data/q_estimate.json", "data/mic_pressure_fft.csv", "summary.json", "summary.txt", "tables/all_cases.csv", "tables/timbre_summary.csv", "tables/amplitude_summary.csv", "tables/frequency_summary.csv", "figures/linear_timbre_overview.png", "figures/linear_amplitude_overview.png", "figures/linear_frequency_overview.png"}});

    summary.provenance_check = struct( ...
        "case_count_total", height(all_cases), ...
        "case_count_with_mph", sum(isfile(cellstr(all_cases.mph_path))), ...
        "case_count_with_comsol_log", sum(isfile(cellstr(all_cases.case_log_path))), ...
        "case_count_with_raw_csv_bundle", sum(isfile(cellstr(all_cases.frequencies_csv_path)) & isfile(cellstr(all_cases.tip_timeseries_csv_path)) & isfile(cellstr(all_cases.mode_shapes_csv_path)) & isfile(cellstr(all_cases.mic_pressure_timeseries_csv_path))), ...
        "case_count_verified_real_comsol", sum(all_cases.is_real_comsol_case), ...
        "all_cases_verified_real_comsol", all(all_cases.is_real_comsol_case));

    summary.loudest_case_id = key_case_id(all_cases, "spl_db", "max");
    summary.max_displacement_case_id = key_case_id(all_cases, "max_tip_displacement_m", "max");
    summary.highest_centroid_case_id = key_case_id(all_cases, "spectral_centroid_hz", "max");
    summary.min_f1_case_id = key_case_id(all_cases, "f1_hz", "min");
    summary.max_f1_case_id = key_case_id(all_cases, "f1_hz", "max");
end

function case_id = key_case_id(tbl, column_name, mode_name)
    values = double(tbl.(column_name));
    if isempty(values) || all(~isfinite(values))
        case_id = "";
        return;
    end
    finite_mask = isfinite(values);
    switch mode_name
        case "max"
            candidate_values = values;
            candidate_values(~finite_mask) = -Inf;
            [~, idx] = max(candidate_values);
        case "min"
            candidate_values = values;
            candidate_values(~finite_mask) = Inf;
            [~, idx] = min(candidate_values);
        otherwise
            error("Unsupported key case mode: %s", mode_name);
    end
    case_id = string(tbl.case_id(idx));
end

function create_timbre_overview_figure(tbl, output_path)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 80, 1280, 900]);
    cleanup_obj = onCleanup(@() close(fig)); %#ok<NASGU>

    tbl = sortrows(tbl, "J_Ns");
    tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    nexttile;
    plot(tbl.J_Ns, tbl.peak1_hz, '-o', 'LineWidth', 1.4, 'MarkerSize', 5); hold on;
    plot(tbl.J_Ns, tbl.peak2_hz, '-s', 'LineWidth', 1.4, 'MarkerSize', 5);
    plot(tbl.J_Ns, tbl.peak3_hz, '-^', 'LineWidth', 1.4, 'MarkerSize', 5);
    grid on;
    xlabel('Impulse J (N*s)');
    ylabel('Peak frequency (Hz)');
    title('Top spectral peaks');
    legend({'peak1', 'peak2', 'peak3'}, 'Location', 'best');

    nexttile;
    plot(tbl.J_Ns, tbl.spectral_centroid_hz, '-o', 'LineWidth', 1.6, 'MarkerSize', 5);
    grid on;
    xlabel('Impulse J (N*s)');
    ylabel('Centroid (Hz)');
    title('Spectral centroid');

    nexttile;
    plot(tbl.J_Ns, tbl.rolloff85_hz, '-o', 'LineWidth', 1.6, 'MarkerSize', 5);
    grid on;
    xlabel('Impulse J (N*s)');
    ylabel('Rolloff85 (Hz)');
    title('Spectral rolloff 85%');

    nexttile;
    hold on;
    spectrum_rows = 0;
    color_order = lines(height(tbl));
    legend_labels = {};
    for i = 1:height(tbl)
        spectrum_path = char(tbl.mic_pressure_fft_csv_path(i));
        if ~isfile(spectrum_path)
            continue;
        end
        fft_tbl = readtable(spectrum_path, 'Encoding', 'UTF-8');
        plot(fft_tbl.freq_hz, fft_tbl.amp_pa, 'LineWidth', 1.1, 'Color', color_order(i, :));
        spectrum_rows = spectrum_rows + 1;
        legend_labels{end + 1} = sprintf('J=%.3g', tbl.J_Ns(i)); %#ok<AGROW>
    end
    grid on;
    xlabel('Frequency (Hz)');
    ylabel('Amplitude (Pa)');
    title('Microphone spectra overlay');
    if spectrum_rows > 0
        legend(legend_labels, 'Location', 'northeastoutside');
    end

    save_figure(fig, output_path);
end

function create_amplitude_overview_figure(tbl, output_path)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 60, 1500, 900]);
    cleanup_obj = onCleanup(@() close(fig)); %#ok<NASGU>

    metrics = {'spl_db', 'p_pp_pa', 'max_tip_displacement_m'};
    metric_titles = {'SPL', 'Peak-to-peak pressure', 'Max tip displacement'};
    variables = {'L_free', 'x0_ratio', 'b', 'h', 'J'};
    x_columns = {'L_free_cm', 'x0_ratio', 'b_cm', 'h_mm', 'J_Ns'};
    x_labels = {'L_{free} (cm)', 'x_0 / L_{free}', 'b (cm)', 'h (mm)', 'J (N*s)'};

    tiledlayout(fig, 3, 5, 'Padding', 'compact', 'TileSpacing', 'compact');
    for row_idx = 1:numel(metrics)
        for col_idx = 1:numel(variables)
            nexttile;
            mask = tbl.is_baseline | strcmp(string(tbl.primary_variable), variables{col_idx});
            local_tbl = sortrows(tbl(mask, :), x_columns{col_idx});
            plot(local_tbl.(x_columns{col_idx}), local_tbl.(metrics{row_idx}), '-o', 'LineWidth', 1.4, 'MarkerSize', 5);
            grid on;
            xlabel(x_labels{col_idx});
            ylabel(metric_titles{row_idx});
            title(sprintf('%s vs %s', metric_titles{row_idx}, variables{col_idx}), 'Interpreter', 'none');
        end
    end

    save_figure(fig, output_path);
end

function create_frequency_overview_figure(tbl, output_path)
    fig = figure('Visible', 'off', 'Color', 'w', 'Position', [80, 120, 1500, 340]);
    cleanup_obj = onCleanup(@() close(fig)); %#ok<NASGU>

    variables = {'L_free', 'x0_ratio', 'b', 'h', 'J'};
    x_columns = {'L_free_cm', 'x0_ratio', 'b_cm', 'h_mm', 'J_Ns'};
    x_labels = {'L_{free} (cm)', 'x_0 / L_{free}', 'b (cm)', 'h (mm)', 'J (N*s)'};

    tiledlayout(fig, 1, 5, 'Padding', 'compact', 'TileSpacing', 'compact');
    for col_idx = 1:numel(variables)
        nexttile;
        mask = tbl.is_baseline | strcmp(string(tbl.primary_variable), variables{col_idx});
        local_tbl = sortrows(tbl(mask, :), x_columns{col_idx});
        plot(local_tbl.(x_columns{col_idx}), local_tbl.f1_hz, '-o', 'LineWidth', 1.4, 'MarkerSize', 5); hold on;
        plot(local_tbl.(x_columns{col_idx}), local_tbl.f_dom_hz, '-s', 'LineWidth', 1.4, 'MarkerSize', 5);
        grid on;
        xlabel(x_labels{col_idx});
        ylabel('Frequency (Hz)');
        title(sprintf('Frequency vs %s', variables{col_idx}), 'Interpreter', 'none');
        legend({'f1', 'f_{dom}'}, 'Location', 'best');
    end

    save_figure(fig, output_path);
end

function save_figure(fig, output_path)
    [parent_dir, ~, ~] = fileparts(output_path);
    if strlength(string(parent_dir)) > 0
        ensure_dir(parent_dir);
    end
    if exist('exportgraphics', 'file') ~= 0
        exportgraphics(fig, output_path, 'Resolution', 180);
    else
        saveas(fig, output_path);
    end
end

function value = required_case_text(case_info, field_name)
    value = char(string(get_case_value(case_info, field_name, "")));
    if strlength(string(value)) == 0
        error("Case field '%s' is missing or empty.", field_name);
    end
end

function value = get_case_value(case_info, field_name, default_value)
    if isstruct(case_info) && isfield(case_info, field_name)
        value = case_info.(field_name);
        return;
    end
    value = default_value;
end

function value = get_case_number(case_info, field_name, default_value)
    raw = get_case_value(case_info, field_name, default_value);
    value = convert_to_double(raw, default_value);
end

function value = read_optional_json(path)
    if isfile(path)
        value = read_json_file(path);
    else
        value = [];
    end
end

function value = get_numeric_field(data, field_name, default_value)
    if isstruct(data) && isfield(data, field_name)
        value = convert_to_double(data.(field_name), default_value);
        return;
    end
    value = default_value;
end

function value = convert_to_double(raw, default_value)
    if isempty(raw)
        value = default_value;
        return;
    end
    if isnumeric(raw) || islogical(raw)
        value = double(raw);
        return;
    end
    value = str2double(string(raw));
    if ~isfinite(value)
        value = default_value;
    end
end

function out = to_cellstr(value)
    if iscell(value)
        out = cellfun(@(item) char(string(item)), value, 'UniformOutput', false);
        return;
    end
    if isstring(value)
        out = cellstr(value(:));
        return;
    end
    if ischar(value)
        out = {value};
        return;
    end
    if isempty(value)
        out = {};
        return;
    end
    out = cellstr(string(value));
end

function value = get_struct_text(data, field_name, default_value)
    value = default_value;
    if isstruct(data) && isfield(data, field_name)
        raw = string(data.(field_name));
        if strlength(strtrim(raw)) > 0
            value = char(strtrim(raw));
        end
    end
end

function value = get_struct_value(data, field_name, default_value)
    if isstruct(data) && isfield(data, field_name)
        value = data.(field_name);
    else
        value = default_value;
    end
end
