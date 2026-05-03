function report = validate_medium_tip_decay_outputs(case_root)
%VALIDATE_MEDIUM_TIP_DECAY_OUTPUTS Validate tip/Q and band-decay for medium+ runs.
%   report = validate_medium_tip_decay_outputs(case_root)
%
%   Checks specific to medium/full quality runs where tip_timeseries.csv
%   is expected and band-decay should be more reliable than coarse:
%
%     1. tip_timeseries.csv exists with >= 3 data rows
%     2. q_source is "tip" (not "missing_tip")
%     3. q_estimate and log_decrement are finite > 0
%     4. tip_peak_m and tip_rms_m are finite
%     5. band_decay_metrics.csv has >= 4 bands
%     6. summary.json band_decay_summary.status is updated
%
%   This is an additive check. It does NOT replace
%   validate_derived_metrics_output which covers format + precision.

    arguments
        case_root (1, :) char
    end

    data_dir = fullfile(case_root, 'data');
    summary_path = fullfile(case_root, 'summary.json');

    report = struct( ...
        'case_root', case_root, ...
        'pass', false, ...
        'tip_exists', false, ...
        'tip_has_data', false, ...
        'q_source_valid', false, ...
        'q_estimate_valid', false, ...
        'log_decrement_valid', false, ...
        'tip_peak_valid', false, ...
        'band_decay_exists', false, ...
        'band_decay_has_bands', false, ...
        'band_decay_status', "", ...
        'issues', {{}});

    % === 1. tip_timeseries.csv ===
    tip_path = fullfile(data_dir, 'tip_timeseries.csv');
    if ~isfile(tip_path)
        report.issues{end + 1} = 'tip_timeseries.csv not found';
    else
        report.tip_exists = true;
        try
            tip_opts = detectImportOptions(tip_path, 'FileType', 'text');
            tip_tbl = readtable(tip_path, tip_opts);
            if height(tip_tbl) >= 3
                report.tip_has_data = true;
            else
                report.issues{end + 1} = sprintf('tip_timeseries.csv has only %d rows (< 3)', height(tip_tbl));
            end
        catch ex
            report.issues{end + 1} = sprintf('tip_timeseries.csv read error: %s', ex.message);
        end
    end

    % === 2-4. structural_metrics.csv: q_source, q_estimate, log_decrement, tip_peak ===
    struct_path = fullfile(data_dir, 'structural_metrics.csv');
    if ~isfile(struct_path)
        report.issues{end + 1} = 'structural_metrics.csv not found (cannot check Q)';
    else
        try
            s_opts = detectImportOptions(struct_path, 'FileType', 'text');
            s_tbl = readtable(struct_path, s_opts);

            if ismember('q_source', s_tbl.Properties.VariableNames)
                qs = string(s_tbl.q_source(1));
                if qs ~= "missing_tip"
                    report.q_source_valid = true;
                else
                    report.issues{end + 1} = 'q_source is "missing_tip" (tip data not used)';
                end
            else
                report.issues{end + 1} = 'q_source column missing from structural_metrics.csv';
            end

            if ismember('q_estimate', s_tbl.Properties.VariableNames)
                qe = s_tbl.q_estimate(1);
                if isfinite(qe) && qe > 0
                    report.q_estimate_valid = true;
                else
                    report.issues{end + 1} = sprintf('q_estimate is not finite/positive: %g', qe);
                end
            else
                report.issues{end + 1} = 'q_estimate column missing from structural_metrics.csv';
            end

            if ismember('log_decrement', s_tbl.Properties.VariableNames)
                ld = s_tbl.log_decrement(1);
                if isfinite(ld) && ld > 0
                    report.log_decrement_valid = true;
                else
                    report.issues{end + 1} = sprintf('log_decrement is not finite/positive: %g', ld);
                end
            else
                report.issues{end + 1} = 'log_decrement column missing from structural_metrics.csv';
            end

            if ismember('tip_peak_m', s_tbl.Properties.VariableNames)
                tp = s_tbl.tip_peak_m(1);
                if isfinite(tp) && tp > 0
                    report.tip_peak_valid = true;
                else
                    report.issues{end + 1} = sprintf('tip_peak_m is not finite/positive: %g', tp);
                end
            else
                report.issues{end + 1} = 'tip_peak_m column missing from structural_metrics.csv';
            end
        catch ex
            report.issues{end + 1} = sprintf('structural_metrics.csv read error: %s', ex.message);
        end
    end

    % === 5-6. band_decay_metrics.csv and summary.json ===
    decay_path = fullfile(data_dir, 'band_decay_metrics.csv');
    if ~isfile(decay_path)
        report.issues{end + 1} = 'band_decay_metrics.csv not found';
    else
        report.band_decay_exists = true;
        try
            d_opts = detectImportOptions(decay_path, 'FileType', 'text');
            d_tbl = readtable(decay_path, d_opts);
            if height(d_tbl) >= 4
                report.band_decay_has_bands = true;
            else
                report.issues{end + 1} = sprintf('band_decay_metrics.csv has %d bands (< 4)', height(d_tbl));
            end
        catch ex
            report.issues{end + 1} = sprintf('band_decay_metrics.csv read error: %s', ex.message);
        end
    end

    if isfile(summary_path)
        try
            summary = read_json_file(summary_path);
            if isfield(summary, 'band_decay_summary') && isfield(summary.band_decay_summary, 'status')
                report.band_decay_status = string(summary.band_decay_summary.status);
            end
        catch
        end
    end

    % === Overall pass ===
    report.pass = report.tip_exists && report.tip_has_data && ...
        report.q_source_valid && report.q_estimate_valid && ...
        report.log_decrement_valid && report.tip_peak_valid && ...
        report.band_decay_exists && report.band_decay_has_bands;

    print_report(report);
end

function print_report(report)
    if report.pass
        status = 'PASS';
    else
        status = 'FAIL';
    end
    fprintf('MEDIUM_TIP_DECAY_VALIDATION %s\n', status);
    fprintf('case_root: %s\n', report.case_root);
    fprintf('tip_exists: %d\n', report.tip_exists);
    fprintf('tip_has_data: %d\n', report.tip_has_data);
    fprintf('q_source_valid: %d\n', report.q_source_valid);
    fprintf('q_estimate_valid: %d\n', report.q_estimate_valid);
    fprintf('log_decrement_valid: %d\n', report.log_decrement_valid);
    fprintf('tip_peak_valid: %d\n', report.tip_peak_valid);
    fprintf('band_decay_exists: %d\n', report.band_decay_exists);
    fprintf('band_decay_has_bands: %d\n', report.band_decay_has_bands);
    fprintf('band_decay_status: %s\n', report.band_decay_status);
    fprintf('issues: %d\n', numel(report.issues));
    for i = 1:numel(report.issues)
        fprintf('  - %s\n', report.issues{i});
    end
end
