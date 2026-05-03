function result = run_derived_metrics(data_dir, figures_dir, result, spec)
%RUN_DERIVED_METRICS Compute all derived metrics from extracted raw data.
%   result = run_derived_metrics(data_dir, figures_dir, result, spec)
%
%   Reads from result fields (freq_table, tip_t, tip_w, mic_t, mic_p, etc.)
%   Writes:
%     data/acoustic_metrics.csv
%     data/structural_metrics.csv
%     data/modal_acoustic_coupling.csv
%     data/band_decay_metrics.csv
%     data/case_metrics.csv
%     figures/modal_acoustic_coupling.png
%     figures/band_decay_envelope.png

    arguments
        data_dir (1, :) char
        figures_dir (1, :) char
        result struct
        spec struct = struct()
    end
    if ~isempty(fieldnames(spec))
        result.derived_metrics_spec = spec;
    end

    % --- Acoustic metrics ---
    if isfield(result, 'mic_t') && isfield(result, 'mic_p') && ...
            ~isempty(result.mic_t) && ~isempty(result.mic_p)
        acoustic = compute_acoustic_metrics(result.mic_t, result.mic_p);
        write_table_to_csv(struct2rowtable(acoustic), fullfile(data_dir, 'acoustic_metrics.csv'));
    else
        acoustic = compute_acoustic_metrics([0; 1], [0; 0]); % placeholder with NaN
    end
    result.acoustic_metrics = acoustic;

    % --- Structural metrics ---
    % Prefer explicit structure-probe fields when present. Some historical
    % pipelines stored the structure probe in tip_t/tip_w; keep that as a
    % fallback, but do not report it as a real tip measurement.
    freq_table = table();
    if isfield(result, 'freq_table')
        freq_table = result.freq_table;
    end

    has_probe = isfield(result, 'structure_probe_t') && isfield(result, 'structure_probe_uz') && ...
            ~isempty(result.structure_probe_t) && ~isempty(result.structure_probe_uz);
    if has_probe
        probe_t = result.structure_probe_t;
        probe_uz = result.structure_probe_uz;
    elseif isfield(result, 'tip_t') && isfield(result, 'tip_w') && ...
            ~isempty(result.tip_t) && ~isempty(result.tip_w)
        probe_t = result.tip_t;
        probe_uz = result.tip_w;
        has_probe = true;
    else
        probe_t = zeros(0, 1);
        probe_uz = zeros(0, 1);
    end

    has_tip = isfield(result, 'tip_t') && isfield(result, 'tip_w') && ...
            ~isempty(result.tip_t) && ~isempty(result.tip_w) && ...
            isfile(fullfile(data_dir, 'tip_timeseries.csv'));
    if has_tip
        structural = compute_structural_metrics(probe_t, probe_uz, freq_table, result.tip_t, result.tip_w);
    elseif has_probe
        structural = compute_structural_metrics(probe_t, probe_uz, freq_table);
    else
        structural = compute_structural_metrics(zeros(0, 1), zeros(0, 1), freq_table);
    end
    write_table_to_csv(struct2rowtable(structural), fullfile(data_dir, 'structural_metrics.csv'));
    result.structural_metrics = structural;

    % --- Modal acoustic coupling ---
    if isfield(result, 'mic_t') && isfield(result, 'mic_p') && ...
            ~isempty(result.mic_t) && ~isempty(result.mic_p) && ...
            isfield(result, 'freq_table') && istable(result.freq_table) && ...
            height(result.freq_table) > 0

        [freq_hz, amp_pa] = compute_single_sided_fft(result.mic_t, result.mic_p);
        coupling = compute_modal_acoustic_coupling(freq_hz, amp_pa, result.freq_table);

        if istable(coupling) && height(coupling) > 0
            writetable(coupling, fullfile(data_dir, 'modal_acoustic_coupling.csv'), 'Encoding', 'UTF-8');
            plot_modal_acoustic_coupling(freq_hz, amp_pa, coupling, ...
                fullfile(figures_dir, 'modal_acoustic_coupling.png'));
        end
    else
        coupling = table();
    end
    result.modal_coupling = coupling;

    % --- Band decay metrics ---
    if isfield(result, 'mic_t') && isfield(result, 'mic_p') && ...
            ~isempty(result.mic_t) && ~isempty(result.mic_p) && ...
            numel(result.mic_t) >= 20

        [decay, frame_times, band_energy, bands, band_meta] = compute_band_decay_metrics(result.mic_t, result.mic_p);

        if istable(decay) && height(decay) > 0
            writetable(decay, fullfile(data_dir, 'band_decay_metrics.csv'), 'Encoding', 'UTF-8');
        end
        if ~isempty(frame_times)
            plot_band_decay_envelope(frame_times, band_energy, bands, ...
                fullfile(figures_dir, 'band_decay_envelope.png'));
        end
    else
        decay = table();
        band_meta = struct('win_sec', NaN, 'hop_sec', NaN, 'nfft', 0, 'method', "none");
    end
    result.band_decay = decay;
    result.band_decay_meta = band_meta;

    % --- Composite mode shapes overlay figure ---
    if isfield(result, 'mode_table') && istable(result.mode_table) && ...
            height(result.mode_table) > 0
        plot_mode_shapes_composite(result.mode_table, fullfile(figures_dir, 'mode_shapes.png'));
    end

    % --- Case metrics (single-row aggregation) ---
    case_metrics = compute_case_metrics(acoustic, structural, coupling, decay);
    write_table_to_csv(struct2rowtable(case_metrics), fullfile(data_dir, 'case_metrics.csv'));
    result.case_metrics = case_metrics;

    % --- Build precision metadata ---
    precision_meta = struct( ...
        'fft_window', 'hann_manual', ...
        'zero_padding_factor', 4, ...
        'peak_refinement_method', 'parabolic_3point_log', ...
        'spectral_flatness_method', 'wiener_entropy', ...
        'rolloff_percentile', 85, ...
        'band_decay_method', 'hann_stft_zero_padded', ...
        'band_decay_win_sec', 0.020, ...
        'band_decay_hop_sec', 0.005);
    % Add raw-signal metadata when mic data is present
    if isfield(result, 'mic_t') && ~isempty(result.mic_t) && numel(result.mic_t) >= 4
        mic_dt = mean(diff(result.mic_t));
        if isfinite(mic_dt) && mic_dt > 0
            precision_meta.raw_time_step_s = mic_dt;
            precision_meta.raw_duration_s = (numel(result.mic_t) - 1) * mic_dt;
            precision_meta.raw_fs_hz = 1 / mic_dt;
        end
    end

    % --- Enhance summary.json with derived metrics ---
    enhance_summary_with_metrics(data_dir, acoustic, structural, coupling, decay, band_meta, precision_meta, result);
end

% --- Enhance summary.json with derived metric fields ---
function enhance_summary_with_metrics(data_dir, acoustic, structural, coupling, decay, band_meta, precision_meta, ~)
    parts = strsplit(data_dir, filesep);
    summary_path = fullfile(strjoin(parts(1:end-1), filesep), 'summary.json');

    if isfile(summary_path)
        summary = read_json_file(summary_path);
    else
        summary = struct();
    end

    % Acoustic metrics (compact)
    acoustic_summary = struct();
    fnames = fieldnames(acoustic);
    for i = 1:numel(fnames)
        v = acoustic.(fnames{i});
        if isnumeric(v) && isscalar(v)
            acoustic_summary.(fnames{i}) = v;
        end
    end

    % Structural metrics (compact)
    structural_summary = struct();
    s_names = fieldnames(structural);
    for i = 1:numel(s_names)
        v = structural.(s_names{i});
        if isnumeric(v) && isscalar(v)
            structural_summary.(s_names{i}) = v;
        elseif ischar(v) || isstring(v)
            structural_summary.(s_names{i}) = char(v);
        end
    end

    % Modal acoustic coupling summary
    coupling_summary = struct( ...
        "n_modes", 0, "n_excellent", 0, "n_good", 0, ...
        "n_fair", 0, "n_poor", 0, ...
        "best_match_rel_delta_pct", NaN, "worst_match_rel_delta_pct", NaN);
    if istable(coupling) && height(coupling) > 0
        coupling_summary.n_modes = height(coupling);
        coupling_summary.n_excellent = sum(coupling.match_quality == "excellent");
        coupling_summary.n_good = sum(coupling.match_quality == "good");
        coupling_summary.n_fair = sum(coupling.match_quality == "fair");
        coupling_summary.n_poor = sum(coupling.match_quality == "poor");
        coupling_summary.best_match_rel_delta_pct = min(coupling.rel_delta_pct);
        coupling_summary.worst_match_rel_delta_pct = max(coupling.rel_delta_pct);
    end

    % Band decay summary (preliminary)
    decay_summary = struct( ...
        "preliminary_high_frequency_decay_supported", false, ...
        "status", "preliminary_coarse_time_window", ...
        "method", string(band_meta.method), ...
        "win_sec", band_meta.win_sec, ...
        "hop_sec", band_meta.hop_sec, ...
        "nfft", band_meta.nfft);
    if istable(decay) && height(decay) > 0
        for i = 1:height(decay)
            bid = decay.band_id(i);
            decay_summary.(sprintf("band%d_decay_to_10pct_s", bid)) = decay.decay_to_10pct_s(i);
            decay_summary.(sprintf("band%d_active_duration_10pct_s", bid)) = decay.active_duration_10pct_s(i);
        end
        % Check if highest band decays faster than lowest band
        d10_list = [decay.decay_to_10pct_s];
        if height(decay) >= 2
            valid_d10 = isfinite(d10_list);
            if any(valid_d10)
                first_valid = find(valid_d10, 1, 'first');
                last_valid = find(valid_d10, 1, 'last');
                if first_valid < last_valid && isfinite(d10_list(first_valid)) && isfinite(d10_list(last_valid))
                    decay_summary.preliminary_high_frequency_decay_supported = ...
                        d10_list(first_valid) > d10_list(last_valid);
                end
            end
        end
    end

    % Metrics outputs file list
    metrics_outputs = {};
    expected_files = {
        'acoustic_metrics.csv';
        'structural_metrics.csv';
        'modal_acoustic_coupling.csv';
        'band_decay_metrics.csv';
        'case_metrics.csv'
    };
    for i = 1:numel(expected_files)
        fpath = fullfile(data_dir, expected_files{i});
        if isfile(fpath)
            metrics_outputs{end + 1} = expected_files{i}; %#ok<AGROW>
        end
    end

    metrics_status = "complete";
    if numel(metrics_outputs) < numel(expected_files)
        metrics_status = "partial";
    end

    % Merge into summary (don't overwrite existing fields)
    summary.acoustic_metrics = acoustic_summary;
    summary.structural_metrics = structural_summary;
    summary.modal_acoustic_coupling_summary = coupling_summary;
    summary.band_decay_summary = decay_summary;
    summary.metrics_outputs = metrics_outputs;
    summary.metrics_status = metrics_status;
    summary.precision_metadata = precision_meta;

    write_json_file(summary_path, summary);
end

% --- Helper: convert a scalar struct to a single-row table ---
function t = struct2rowtable(s)
    names = fieldnames(s);
    values = cell(numel(names), 1);
    for i = 1:numel(names)
        v = s.(names{i});
        if istable(v) || isstruct(v)
            values{i} = jsonencode(v);
        elseif ischar(v)
            values{i} = string(v);
        elseif isstring(v)
            values{i} = v;
        else
            values{i} = v;
        end
    end
    t = table(values{:}, 'VariableNames', names);
end

% --- Helper: write a table to CSV (handles cell/string columns) ---
function write_table_to_csv(t, path)
    writetable(t, path, 'Encoding', 'UTF-8');
end
