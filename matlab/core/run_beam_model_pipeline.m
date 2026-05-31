function result = run_beam_model_pipeline(spec)
%RUN_BEAM_MODEL_PIPELINE Open model, run studies, export data, and plot figures.

    arguments
        spec struct
    end

    configure_plot_defaults();
    export_timer = tic;

    data_subdir = get_output_subdir(spec, "data_dir_name", "results");
    figures_subdir = get_output_subdir(spec, "figures_dir_name", data_subdir);
    data_dir = fullfile(spec.output_root, data_subdir);
    figures_dir = fullfile(spec.output_root, figures_subdir);
    ensure_dir(data_dir);
    ensure_dir(figures_dir);
    ensure_dir(fullfile(spec.output_root, 'logs'));
    ensure_dir(fullfile(spec.output_root, 'mph'));

    offline = try_load_java_exported_result(spec, data_dir, figures_dir, export_timer);
    if offline.available
        result = offline.result;
        return;
    end

    model = comsol_connect(spec.model_path);
    disconnectOnCleanup = true;
    if isfield(spec, "disconnect_on_cleanup")
        disconnectOnCleanup = logical(spec.disconnect_on_cleanup);
    end
    if disconnectOnCleanup
        cleanupObj = onCleanup(@() comsol_disconnect(model)); %#ok<NASGU>
    else
        cleanupObj = onCleanup(@() release_model_only(model)); %#ok<NASGU>
    end

    shouldRunStudies = false;
    if isfield(spec, "run_studies")
        shouldRunStudies = logical(spec.run_studies);
    end
    hasPrecomputedStudies = has_required_study_results(model);
    studiesRerunInMatlab = false;
    if shouldRunStudies || ~hasPrecomputedStudies
        run_default_studies(model);
        studiesRerunInMatlab = true;
    end
    ensure_standard_result_nodes(model, spec);

    tipCoord = [];
    if isfield(spec, "beam_length_m")
        beamLengthCandidate = double(spec.beam_length_m);
        if isfinite(beamLengthCandidate)
            tipCoord = [beamLengthCandidate; 0; 0];
        end
    end

    try
        [freq_table, freqs] = extract_frequency_table(model);
    catch freqErr
        [studiesRerunInMatlab, didRetry] = rerun_studies_after_extract_failure(model, spec, studiesRerunInMatlab, freqErr, "eigenfrequency");
        if ~didRetry
            rethrow(freqErr);
        end
        [freq_table, freqs] = extract_frequency_table(model);
    end

    try
        [tip_table, tip_t, tip_w] = extract_point_timeseries(model, 'cptTip', {'t', 'w'}, {'t_s', 'w_m'}, tipCoord, 'dsetTime', 'sol2');
    catch tipErr
        [studiesRerunInMatlab, didRetry] = rerun_studies_after_extract_failure(model, spec, studiesRerunInMatlab, tipErr, "tip time-series");
        if ~didRetry
            rethrow(tipErr);
        end
        [tip_table, tip_t, tip_w] = extract_point_timeseries(model, 'cptTip', {'t', 'w'}, {'t_s', 'w_m'}, tipCoord, 'dsetTime', 'sol2');
    end

    beamLengthM = NaN;
    if isfield(spec, "beam_length_m")
        beamLengthM = double(spec.beam_length_m);
    end
    mode_table = extract_mode_shapes(model, spec.num_modes, spec.mode_points, beamLengthM);

    results_dir = data_dir;

    writetable(freq_table, fullfile(results_dir, 'frequencies.csv'), 'Encoding', 'UTF-8');
    writetable(tip_table, fullfile(results_dir, 'tip_timeseries.csv'), 'Encoding', 'UTF-8');
    writetable(mode_table, fullfile(results_dir, 'mode_shapes.csv'), 'Encoding', 'UTF-8');

    plot_frequency_bar(freq_table, fullfile(figures_dir, 'frequencies_bar.png'));
    plot_series(tip_t, tip_w, fullfile(figures_dir, 'tip_timeseries.png'), ...
        'Tip displacement time series', 'Tip displacement w (m)', '#1D3557');
    plot_fft(tip_t, tip_w, fullfile(figures_dir, 'tip_fft.png'), ...
        'Tip displacement spectrum', 'Amplitude |W(f)| (m)', 1000);
    plot_mode_shapes(mode_table, figures_dir);

    mic_table = table();
    q_info = struct();
    if isfield(spec, "include_mic") && spec.include_mic
        mic_dataset_tag = resolve_mic_dataset_tag(model);
        micCoord = [];
        if strcmp(mic_dataset_tag, 'cptTip')
            micCoord = tipCoord;
        end
        [mic_table, mic_t, mic_p] = extract_point_timeseries( ...
            model, mic_dataset_tag, {'t', char(spec.mic_expr)}, {'t_s', 'p_pa'}, micCoord, 'dsetTime', 'sol2');
        writetable(mic_table, fullfile(results_dir, 'mic_pressure_timeseries.csv'), 'Encoding', 'UTF-8');
        plot_series(mic_t, mic_p, fullfile(figures_dir, 'mic_pressure_timeseries.png'), ...
            'Microphone pressure time series', 'Pressure p (Pa)', '#7A3E9D');
        plot_fft(mic_t, mic_p, fullfile(figures_dir, 'mic_pressure_fft.png'), ...
            'Microphone pressure spectrum', 'Amplitude |P(f)| (Pa)', 1000);
        q_info = estimate_q_from_tip(tip_t, tip_w);
        write_json_file(fullfile(results_dir, 'q_estimate.json'), q_info);
    end

    save_comsol_model(model, spec.model_path);

    result = struct();
    result.freq_table = freq_table;
    result.freqs = freqs;
    result.tip_table = tip_table;
    result.tip_t = tip_t;
    result.tip_w = tip_w;
    result.mode_table = mode_table;
    result.mic_table = mic_table;
    result.q_info = q_info;
    result.data_dir = data_dir;
    result.figures_dir = figures_dir;
    result.studies_rerun_in_matlab = studiesRerunInMatlab;
    if studiesRerunInMatlab
        result.solve_owner = "matlab_livelink";
    else
        result.solve_owner = "java_batch_mph";
    end
    result.wallclock_export_s = toc(export_timer);

    result = run_derived_metrics(data_dir, figures_dir, result, spec);
end

function dataset_tag = resolve_mic_dataset_tag(model)
    dataset_tag = 'cptTip';
    try
        model.result().dataset('cptMic');
        dataset_tag = 'cptMic';
    catch
    end
end

function [studiesRerunInMatlab, didRetry] = rerun_studies_after_extract_failure(model, spec, studiesRerunInMatlab, cause, stage_name)
    didRetry = false;
    if studiesRerunInMatlab
        return;
    end

    warning("Precomputed COMSOL result nodes were present, but %s extraction failed. Rerunning std1/std2 in MATLAB. Original error: %s", stage_name, cause.message);
    run_default_studies(model);
    studiesRerunInMatlab = true;
    ensure_standard_result_nodes(model, spec);
    didRetry = true;
end

function release_model_only(model)
    import com.comsol.model.util.*
    try
        if ~isempty(model)
            modelTag = char(model.tag());
            if strlength(string(modelTag)) > 0
                ModelUtil.remove(modelTag);
            end
        end
    catch
    end
end

function offline = try_load_java_exported_result(spec, data_dir, figures_dir, export_timer)
    offline = struct("available", false, "result", []);

    freq_path = fullfile(data_dir, 'frequencies.csv');
    tip_path = fullfile(data_dir, 'tip_timeseries.csv');
    structure_probe_path = fullfile(data_dir, 'structure_probe_timeseries.csv');
    mode_path = fullfile(data_dir, 'mode_shapes.csv');
    required = {freq_path, mode_path};

    include_mic = isfield(spec, "include_mic") && spec.include_mic;
    mic_path = fullfile(data_dir, 'mic_pressure_timeseries.csv');
    if include_mic
        required{end + 1} = mic_path;
    end

    for i = 1:numel(required)
        if ~isfile(required{i})
            return;
        end
    end
    if ~isfile(tip_path) && ~isfile(structure_probe_path)
        return;
    end

    freq_table = read_exported_numeric_csv(freq_path);
    if isfile(tip_path)
        tip_table = read_exported_numeric_csv(tip_path);
        tip_t = tip_table.t_s;
        tip_w = tip_table.w_m;
        probe_t = tip_t;
        probe_uz = tip_w;
    else
        tip_table = table();
        tip_t = zeros(0, 1);
        tip_w = zeros(0, 1);
        probe_table = read_exported_numeric_csv(structure_probe_path);
        probe_t = probe_table.t_s;
        probe_uz = probe_table.uz_m;
    end
    mode_table = read_exported_numeric_csv(mode_path);
    freqs = freq_table.freq_hz;

    plot_frequency_bar(freq_table, fullfile(figures_dir, 'frequencies_bar.png'));
    if ~isempty(tip_t)
        plot_series(tip_t, tip_w, fullfile(figures_dir, 'tip_timeseries.png'), ...
            'Tip displacement time series', 'Tip displacement w (m)', '#1D3557');
        plot_fft(tip_t, tip_w, fullfile(figures_dir, 'tip_fft.png'), ...
            'Tip displacement spectrum', 'Amplitude |W(f)| (m)', 1000);
    else
        plot_series(probe_t, probe_uz, fullfile(figures_dir, 'structure_probe_timeseries.png'), ...
            'Structure probe displacement time series', 'Probe displacement uz (m)', '#1D3557');
        plot_fft(probe_t, probe_uz, fullfile(figures_dir, 'structure_probe_fft.png'), ...
            'Structure probe displacement spectrum', 'Amplitude |Uz(f)| (m)', 1000);
    end
    plot_mode_shapes(mode_table, figures_dir);

    mic_table = table();
    q_info = struct();
    if include_mic
        mic_table = read_exported_numeric_csv(mic_path);
        mic_t = mic_table.t_s;
        mic_p = mic_table.p_pa;
        plot_series(mic_t, mic_p, fullfile(figures_dir, 'mic_pressure_timeseries.png'), ...
            'Microphone pressure time series', 'Pressure p (Pa)', '#7A3E9D');
        plot_fft(mic_t, mic_p, fullfile(figures_dir, 'mic_pressure_fft.png'), ...
            'Microphone pressure spectrum', 'Amplitude |P(f)| (Pa)', 1000);
        if ~isempty(tip_t)
            q_info = estimate_q_from_tip(tip_t, tip_w);
            write_json_file(fullfile(data_dir, 'q_estimate.json'), q_info);
        end
    end

    result = struct();
    result.freq_table = freq_table;
    result.freqs = freqs;
    result.tip_table = tip_table;
    result.tip_t = tip_t;
    result.tip_w = tip_w;
    result.structure_probe_t = probe_t;
    result.structure_probe_uz = probe_uz;
    result.mode_table = mode_table;
    result.mic_table = mic_table;
    result.q_info = q_info;
    result.data_dir = data_dir;
    result.figures_dir = figures_dir;
    result.studies_rerun_in_matlab = false;
    result.solve_owner = "java_batch_csv";
    result.wallclock_export_s = toc(export_timer);

    result = run_derived_metrics(data_dir, figures_dir, result, spec);

    offline.available = true;
    offline.result = result;
end

function tbl = read_exported_numeric_csv(path)
    lines = readlines(path, 'EmptyLineRule', 'skip');
    header = '';
    data_lines = strings(0, 1);

    for i = 1:numel(lines)
        line = strtrim(lines(i));
        if strlength(line) == 0
            continue;
        end
        if startsWith(line, '%')
            candidate = strtrim(extractAfter(line, 1));
            if contains(candidate, ',') && ~any(startsWith(candidate, {'Model,', 'Version,', 'Date,', 'Table,'}))
                header = candidate;
            end
            continue;
        end
        data_lines(end + 1, 1) = line; %#ok<AGROW>
    end

    if strlength(header) == 0
        values = parse_numeric_lines(data_lines);
        names = infer_variable_names(path, size(values, 2));
        tbl = array2table(values, 'VariableNames', names);
        return;
    end

    raw_names = strtrim(split(header, ',')).';
    names = matlab.lang.makeValidName(cellstr(raw_names), 'ReplacementStyle', 'delete');
    values = parse_numeric_lines(data_lines, numel(names));
    tbl = array2table(values, 'VariableNames', names);
end

function values = parse_numeric_lines(data_lines, expected_cols)
    if nargin < 2
        expected_cols = 0;
    end

    if isempty(data_lines)
        values = zeros(0, expected_cols);
        return;
    end

    if expected_cols <= 0
        expected_cols = numel(split(data_lines(1), ','));
    end

    values = nan(numel(data_lines), expected_cols);
    for row = 1:numel(data_lines)
        parts = strtrim(split(data_lines(row), ',')).';
        for col = 1:min(numel(parts), expected_cols)
            values(row, col) = str2double(parts(col));
        end
    end
end

function names = infer_variable_names(path, num_cols)
    [~, stem, ~] = fileparts(path);

    switch lower(stem)
        case 'frequencies'
            expected = {'mode', 'freq_hz'};
        case 'tip_timeseries'
            expected = {'t_s', 'w_m'};
        case 'mic_pressure_timeseries'
            expected = {'t_s', 'p_pa'};
        case 'mic_pressure_fft'
            expected = {'freq_hz', 'amp_pa'};
        case 'mode_shapes'
            expected = [{'x_over_L'}, arrayfun(@(k) sprintf('w_mode%d', k), 1:max(num_cols - 1, 0), 'UniformOutput', false)];
        otherwise
            expected = arrayfun(@(k) sprintf('col%d', k), 1:num_cols, 'UniformOutput', false);
    end

    if numel(expected) < num_cols
        expected = [expected, arrayfun(@(k) sprintf('col%d', k), numel(expected) + 1:num_cols, 'UniformOutput', false)];
    elseif numel(expected) > num_cols
        expected = expected(1:num_cols);
    end

    names = matlab.lang.makeUniqueStrings(expected, {}, namelengthmax);
end
