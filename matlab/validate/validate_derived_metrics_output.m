function report = validate_derived_metrics_output(case_root, opts)
%VALIDATE_DERIVED_METRICS_OUTPUT Validate fixed derived-output contract for one case.
%   report = validate_derived_metrics_output(case_root)
%   report = validate_derived_metrics_output(case_root, RequirePrecision=true)
%
%   This validator is read-only. It checks files, required columns, summary
%   fields, q/tip semantics, and band-decay availability for one explicit
%   case root. It does not recompute metrics and does not modify raw CSV.
%
%   Optional name-value arguments:
%     RequirePrecision (false) — also check for refined/precision columns
%       and non-empty precision_metadata in summary.json

    arguments
        case_root (1, :) char
        opts.RequirePrecision (1, 1) logical = false
    end

    data_dir = fullfile(case_root, 'data');
    figures_dir = fullfile(case_root, 'figures');
    summary_path = fullfile(case_root, 'summary.json');

    report = struct( ...
        'case_root', case_root, ...
        'pass', false, ...
        'format_pass', false, ...
        'precision_pass', false, ...
        'precision_required', opts.RequirePrecision, ...
        'missing_files', {{}}, ...
        'missing_summary_fields', {{}}, ...
        'column_issues', {{}}, ...
        'precision_issues', {{}}, ...
        'semantic_issues', {{}}, ...
        'band_decay_available', false, ...
        'metrics_status', "");

    % === O3/O6: expected output files ===
    expected_files = {
        fullfile(data_dir, 'acoustic_metrics.csv');
        fullfile(data_dir, 'structural_metrics.csv');
        fullfile(data_dir, 'modal_acoustic_coupling.csv');
        fullfile(data_dir, 'band_decay_metrics.csv');
        fullfile(data_dir, 'case_metrics.csv');
        fullfile(figures_dir, 'modal_acoustic_coupling.png');
        fullfile(figures_dir, 'band_decay_envelope.png');
        fullfile(figures_dir, 'mode_shapes.png')
    };

    for i = 1:numel(expected_files)
        if ~isfile(expected_files{i})
            report.missing_files{end + 1} = char(relative_to_case(case_root, expected_files{i}));
        end
    end

    % === O5: required CSV columns ===
    report = check_required_columns(report, fullfile(data_dir, 'acoustic_metrics.csv'), ...
        {'p_rms_pa','p_peak_pa','spl_rms_db','spl_peak_db','f_dom_hz', ...
        'spectral_centroid_hz','spectral_bandwidth_hz','rolloff85_hz'});
    report = check_required_columns(report, fullfile(data_dir, 'structural_metrics.csv'), ...
        {'probe_peak_m','probe_rms_m','tip_peak_m','tip_rms_m', ...
        'dominant_structure_freq_hz','q_estimate','log_decrement','q_source'});
    report = check_required_columns(report, fullfile(data_dir, 'modal_acoustic_coupling.csv'), ...
        {'mode','mode_freq_hz','nearest_mic_peak_hz','delta_hz', ...
        'rel_delta_pct','peak_amp_pa','match_quality'});
    report = check_required_columns(report, fullfile(data_dir, 'band_decay_metrics.csv'), ...
        {'band_id','f_low_hz','f_high_hz','peak_time_s', ...
        'active_duration_10pct_s','active_duration_1pct_s', ...
        'decay_to_10pct_s','decay_to_1pct_s','band_energy'});

    % === O7: summary.json derived fields ===
    summary_fields = {'acoustic_metrics','structural_metrics', ...
        'modal_acoustic_coupling_summary','band_decay_summary', ...
        'metrics_outputs','metrics_status'};
    if ~isfile(summary_path)
        report.missing_files{end + 1} = 'summary.json';
        report.missing_summary_fields = summary_fields;
    else
        summary = read_json_file(summary_path);
        for i = 1:numel(summary_fields)
            if ~isfield(summary, summary_fields{i})
                report.missing_summary_fields{end + 1} = summary_fields{i};
            end
        end
        if isfield(summary, 'metrics_status')
            report.metrics_status = string(summary.metrics_status);
        end
    end

    % === O507: tip semantics ===
    report = check_tip_semantics(report, data_dir);

    % === O504: band decay availability ===
    report = check_band_decay(report, data_dir);

    % === Format pass: all basic checks ===
    report.format_pass = isempty(report.missing_files) && ...
        isempty(report.missing_summary_fields) && ...
        isempty(report.column_issues) && ...
        isempty(report.semantic_issues);

    % === Optional precision checks ===
    report.precision_pass = true;
    if opts.RequirePrecision
        report = check_precision(report, data_dir, summary_path);
    end

    % === Overall pass ===
    report.pass = report.format_pass;
    if opts.RequirePrecision
        report.pass = report.pass && report.precision_pass;
    end

    print_report(report);
end

% --- Column validation ---
function report = check_required_columns(report, csv_path, required_columns)
    if ~isfile(csv_path)
        return;
    end

    opts = detectImportOptions(csv_path, 'FileType', 'text');
    tbl = readtable(csv_path, opts);
    names = tbl.Properties.VariableNames;
    missing = required_columns(~ismember(required_columns, names));
    if ~isempty(missing)
        [~, file_name, ext] = fileparts(csv_path);
        report.column_issues{end + 1} = sprintf('%s%s missing columns: %s', ...
            file_name, ext, strjoin(missing, ', '));
    end
end

% --- Tip semantics ---
function report = check_tip_semantics(report, data_dir)
    tip_path = fullfile(data_dir, 'tip_timeseries.csv');
    structural_path = fullfile(data_dir, 'structural_metrics.csv');
    if ~isfile(structural_path)
        return;
    end

    opts = detectImportOptions(structural_path, 'FileType', 'text');
    tbl = readtable(structural_path, opts);
    if isempty(tbl)
        report.semantic_issues{end + 1} = 'structural_metrics.csv is empty';
        return;
    end

    if ~isfile(tip_path)
        q_source = "";
        if ismember('q_source', tbl.Properties.VariableNames)
            q_source = string(tbl.q_source(1));
        end
        if q_source ~= "missing_tip"
            report.semantic_issues{end + 1} = 'missing tip_timeseries.csv requires q_source=missing_tip';
        end

        numeric_fields = {'tip_peak_m','tip_rms_m','q_estimate','log_decrement'};
        for i = 1:numel(numeric_fields)
            field = numeric_fields{i};
            if ismember(field, tbl.Properties.VariableNames)
                value = tbl.(field)(1);
                if ~(isnumeric(value) && isnan(value))
                    report.semantic_issues{end + 1} = sprintf('missing tip requires %s=NaN', field);
                end
            end
        end
    end
end

% --- Band decay ---
function report = check_band_decay(report, data_dir)
    decay_path = fullfile(data_dir, 'band_decay_metrics.csv');
    if ~isfile(decay_path)
        return;
    end

    opts = detectImportOptions(decay_path, 'FileType', 'text');
    tbl = readtable(decay_path, opts);
    report.band_decay_available = istable(tbl) && height(tbl) >= 4 && ...
        all(ismember({'band_id','decay_to_10pct_s','active_duration_10pct_s'}, tbl.Properties.VariableNames));
    if ~report.band_decay_available
        report.semantic_issues{end + 1} = 'band_decay_metrics.csv must contain at least 4 bands and decay fields';
    end
end

% --- Precision checks ---
function report = check_precision(report, data_dir, summary_path)
    % Check acoustic_metrics.csv for refined/precision columns
    precision_cols = {'f_dom_refined_hz', 'fft_resolution_hz', 'spectral_flatness'};
    csv_path = fullfile(data_dir, 'acoustic_metrics.csv');
    if isfile(csv_path)
        opts = detectImportOptions(csv_path, 'FileType', 'text');
        tbl = readtable(csv_path, opts);
        names = tbl.Properties.VariableNames;
        for i = 1:numel(precision_cols)
            if ~ismember(precision_cols{i}, names)
                report.precision_issues{end + 1} = sprintf('acoustic_metrics.csv missing precision column: %s', precision_cols{i});
            end
        end
    else
        report.precision_issues{end + 1} = 'acoustic_metrics.csv not found (cannot check precision columns)';
    end

    % Check summary.json for precision_metadata
    if isfile(summary_path)
        summary = read_json_file(summary_path);
        if ~isfield(summary, 'precision_metadata')
            report.precision_issues{end + 1} = 'summary.json missing precision_metadata';
        elseif isempty(fieldnames(summary.precision_metadata))
            report.precision_issues{end + 1} = 'summary.json precision_metadata is empty';
        end
    else
        report.precision_issues{end + 1} = 'summary.json not found (cannot check precision_metadata)';
    end

    if ~isempty(report.precision_issues)
        report.precision_pass = false;
    end
end

% --- Helpers ---
function rel = relative_to_case(case_root, path)
    rel = string(path);
    root = string(case_root);
    if startsWith(rel, root)
        rel = extractAfter(rel, strlength(root) + 1);
    end
end

function print_report(report)
    if report.pass
        status = 'PASS';
    else
        status = 'FAIL';
    end

    fprintf('DERIVED_METRICS_VALIDATION %s\n', status);
    fprintf('case_root: %s\n', report.case_root);
    fprintf('format_pass: %d\n', report.format_pass);
    if report.precision_required
        fprintf('precision_pass: %d\n', report.precision_pass);
    end
    fprintf('metrics_status: %s\n', report.metrics_status);
    fprintf('band_decay_available: %d\n', report.band_decay_available);
    print_list('missing_files', report.missing_files);
    print_list('missing_summary_fields', report.missing_summary_fields);
    print_list('column_issues', report.column_issues);
    print_list('precision_issues', report.precision_issues);
    print_list('semantic_issues', report.semantic_issues);
end

function print_list(label, values)
    fprintf('%s: %d\n', label, numel(values));
    for i = 1:numel(values)
        fprintf('  - %s\n', values{i});
    end
end
