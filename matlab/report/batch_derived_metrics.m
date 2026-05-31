function report = batch_derived_metrics(proj_root, data_rel_root)
%BATCH_DERIVED_METRICS Batch run derived metrics and validate all cases.
%   report = batch_derived_metrics()
%   report = batch_derived_metrics(proj_root, data_rel_root)
%
%   Discovers all case roots under <proj_root>/<data_rel_root>/cases/
%   that have data/frequencies.csv and data/mic_pressure_timeseries.csv.
%   For each case:
%     1. Load raw CSV → result struct
%     2. run_derived_metrics (generates CSV + PNG + summary)
%     3. validate_derived_metrics_output with RequirePrecision=true
%     4. Collect results
%
%   Writes:
%     <data_rel_root>/tables/derived_metrics_validation.csv
%     <data_rel_root>/tables/derived_metrics_validation_summary.md

    arguments
        proj_root (1, :) char = 'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler'
        data_rel_root (1, :) char = 'outputs/requested_3d_air_coarse_review_light'
    end

    % Add paths
    addpath(fullfile(proj_root, 'matlab', 'core'));
    addpath(fullfile(proj_root, 'matlab', 'extract'));
    addpath(fullfile(proj_root, 'matlab', 'plot'));
    addpath(fullfile(proj_root, 'matlab', 'validate'));
    addpath(fullfile(proj_root, 'matlab', 'export'));

    cases_root = fullfile(proj_root, data_rel_root, 'cases');
    tables_dir = fullfile(proj_root, data_rel_root, 'tables');
    ensure_dir(tables_dir);

    % === Step 1: Discover all valid case roots ===
    case_roots = discover_case_roots(cases_root);
    n_cases = numel(case_roots);
    fprintf('Discovered %d valid case roots under %s\n\n', n_cases, cases_root);

    % === Step 2: Batch run derived metrics + validate ===
    n_format_pass = 0;
    n_precision_pass = 0;
    n_total_pass = 0;

    % Collect validation results as cell array for CSV
    csv_header = {'case_root', 'group', 'parameter', 'format_pass', 'precision_pass', ...
        'metrics_status', 'band_decay_available', ...
        'f_dom_refined_hz', 'spl_rms_db', 'spectral_centroid_hz', 'spectral_flatness', ...
        'probe_peak_m', 'q_source', 'best_match_rel_delta_pct', 'n_modal_matches'};
    csv_rows = cell(n_cases, numel(csv_header));

    % Per-case details for report
    per_case = struct('root', cell(n_cases, 1), 'group', cell(n_cases, 1), ...
        'param', cell(n_cases, 1), 'format_pass', false(n_cases, 1), ...
        'precision_pass', false(n_cases, 1), 'overall_pass', false(n_cases, 1), ...
        'f_dom_refined', NaN(n_cases, 1), 'spl_rms', NaN(n_cases, 1), ...
        'spectral_centroid', NaN(n_cases, 1), 'spectral_flatness', NaN(n_cases, 1), ...
        'probe_peak', NaN(n_cases, 1), 'q_source', cell(n_cases, 1), ...
        'best_delta_pct', NaN(n_cases, 1), 'n_matched_modes', NaN(n_cases, 1));

    for i = 1:n_cases
        cr = case_roots{i};
        case_dir = fullfile(cases_root, cr);
        data_dir = fullfile(case_dir, 'data');
        figures_dir = fullfile(case_dir, 'figures');
        [group_name, param_name] = parse_case_path(cr);
        ensure_dir(figures_dir);

        fprintf('[%d/%d] %s (%s/%s) ... ', i, n_cases, cr, group_name, param_name);

        % Load raw CSV data
        result = load_case_data(data_dir);
        if isempty(result)
            fprintf('SKIP (no raw data)\n');
            continue;
        end

        % Run derived metrics
        try
            run_derived_metrics(data_dir, figures_dir, result);
            fprintf('derived OK, ');
        catch ex
            fprintf('DERIVED FAIL: %s\n', ex.message);
            continue;
        end

        pause(0.5);  % filesystem flush

        % Validate
        try
            vr = validate_derived_metrics_output(case_dir, RequirePrecision=true);
        catch ex
            fprintf('VALIDATION FAIL: %s\n', ex.message);
            csv_rows(i, :) = {cr, group_name, param_name, ...
                false, false, ...
                'validation_error', false, ...
                NaN, NaN, NaN, NaN, NaN, '', NaN, NaN};
            continue;
        end

        % Collect results
        per_case(i).root = cr;
        per_case(i).group = group_name;
        per_case(i).param = param_name;
        per_case(i).format_pass = vr.format_pass;
        per_case(i).precision_pass = vr.precision_pass;
        per_case(i).overall_pass = vr.pass;
        per_case(i).q_source = {};

        if vr.format_pass
            n_format_pass = n_format_pass + 1;
        end
        if vr.precision_pass
            n_precision_pass = n_precision_pass + 1;
        end
        if vr.pass
            n_total_pass = n_total_pass + 1;
        end

        % Read key metrics
        try
            acc_csv = fullfile(data_dir, 'acoustic_metrics.csv');
            if isfile(acc_csv)
                acc = readtable(acc_csv, detectImportOptions(acc_csv, 'FileType', 'text'));
                if height(acc) > 0
                    if ismember('f_dom_refined_hz', acc.Properties.VariableNames)
                        per_case(i).f_dom_refined = acc.f_dom_refined_hz(1);
                    end
                    per_case(i).spl_rms = acc.spl_rms_db(1);
                    per_case(i).spectral_centroid = acc.spectral_centroid_hz(1);
                    if ismember('spectral_flatness', acc.Properties.VariableNames)
                        per_case(i).spectral_flatness = acc.spectral_flatness(1);
                    end
                end
            end

            struct_csv = fullfile(data_dir, 'structural_metrics.csv');
            if isfile(struct_csv)
                s = readtable(struct_csv, detectImportOptions(struct_csv, 'FileType', 'text'));
                if height(s) > 0
                    per_case(i).probe_peak = s.probe_peak_m(1);
                    if ismember('q_source', s.Properties.VariableNames)
                        per_case(i).q_source = {char(s.q_source(1))};
                    end
                end
            end

            coupl_csv = fullfile(data_dir, 'modal_acoustic_coupling.csv');
            if isfile(coupl_csv)
                c = readtable(coupl_csv, detectImportOptions(coupl_csv, 'FileType', 'text'));
                per_case(i).n_matched_modes = height(c);
                if height(c) > 0 && ismember('rel_delta_refined_pct', c.Properties.VariableNames)
                    per_case(i).best_delta_pct = min(c.rel_delta_refined_pct);
                elseif height(c) > 0
                    per_case(i).best_delta_pct = min(c.rel_delta_pct);
                end
            end
        catch
            % Metrics read failures are non-fatal
        end

        % Fill CSV row
        csv_rows(i, :) = {cr, group_name, param_name, ...
            vr.format_pass, vr.precision_pass, ...
            char(vr.metrics_status), vr.band_decay_available, ...
            per_case(i).f_dom_refined, per_case(i).spl_rms, ...
            per_case(i).spectral_centroid, per_case(i).spectral_flatness, ...
            per_case(i).probe_peak, ...
            char(per_case(i).q_source), ...
            per_case(i).best_delta_pct, per_case(i).n_matched_modes};

        if vr.pass, status_str = 'PASS'; else, status_str = 'FAIL'; end
        fprintf('%s\n', status_str);
    end

    % === Step 3: Write validation CSV ===
    csv_path = fullfile(tables_dir, 'derived_metrics_validation.csv');
    csv_tbl = cell2table(csv_rows, 'VariableNames', csv_header);
    writetable(csv_tbl, csv_path, 'Encoding', 'UTF-8');
    fprintf('\nValidation CSV written: %s\n', csv_path);

    % === Step 4: Write summary report ===
    report_path = fullfile(tables_dir, 'derived_metrics_validation_summary.md');
    write_summary_report(report_path, n_cases, n_format_pass, n_precision_pass, n_total_pass, ...
        per_case, case_roots, data_rel_root);

    fprintf('\n=== BATCH COMPLETE ===\n');
    fprintf('Total cases:  %d\n', n_cases);
    fprintf('Format pass:  %d\n', n_format_pass);
    fprintf('Precision pass: %d\n', n_precision_pass);
    fprintf('Overall pass: %d\n', n_total_pass);

    % Return report struct
    report = struct(...
        'n_cases', n_cases, 'n_format_pass', n_format_pass, ...
        'n_precision_pass', n_precision_pass, 'n_total_pass', n_total_pass, ...
        'validation_csv', csv_path, 'report_path', report_path);
end

% --- Discover case roots ---
function case_roots = discover_case_roots(cases_root)
    % Walk cases_root and find directories containing both frequencies.csv and mic_pressure_timeseries.csv
    listing = dir(fullfile(cases_root, '**', 'data', 'frequencies.csv'));
    case_roots = {};
    for i = 1:numel(listing)
        data_dir = listing(i).folder;
        freq_path = fullfile(data_dir, 'frequencies.csv');
        mic_path = fullfile(data_dir, 'mic_pressure_timeseries.csv');
        if isfile(freq_path) && isfile(mic_path)
            % Get path relative to cases_root
            rel_path = extractAfter(data_dir, cases_root);
            rel_path = strrep(rel_path, '\', '/');
            if startsWith(rel_path, '/')
                rel_path = rel_path(2:end);
            end
            if endsWith(rel_path, '/data')
                rel_path = rel_path(1:end - 5);
            end
            case_roots{end + 1} = rel_path; %#ok<AGROW>
        end
    end
    case_roots = sort(case_roots);
end

% --- Parse case path into group + parameter ---
function [group, param] = parse_case_path(cr)
    parts = strsplit(cr, '/');
    if numel(parts) >= 2
        group = parts{end - 1};
        param = parts{end};
    else
        group = 'unknown';
        param = cr;
    end
end

% --- Load raw CSV data into result struct ---
function result = load_case_data(data_dir)
    result = [];

    required_files = {'frequencies.csv', 'mic_pressure_timeseries.csv', 'mode_shapes.csv', 'structure_probe_timeseries.csv'};
    for i = 1:numel(required_files)
        if ~isfile(fullfile(data_dir, required_files{i}))
            return;
        end
    end

    freq_table = read_exported_numeric_csv(fullfile(data_dir, 'frequencies.csv'));
    mic_table = read_exported_numeric_csv(fullfile(data_dir, 'mic_pressure_timeseries.csv'));
    mode_table = read_exported_numeric_csv(fullfile(data_dir, 'mode_shapes.csv'));
    probe_table = read_exported_numeric_csv(fullfile(data_dir, 'structure_probe_timeseries.csv'));

    tip_path = fullfile(data_dir, 'tip_timeseries.csv');
    if isfile(tip_path)
        tip_table = read_exported_numeric_csv(tip_path);
        tip_t = tip_table.t_s;
        tip_w = tip_table.w_m;
    else
        tip_t = zeros(0, 1);
        tip_w = zeros(0, 1);
    end

    result = struct();
    result.freq_table = freq_table;
    result.tip_t = tip_t;
    result.tip_w = tip_w;
    result.structure_probe_t = probe_table.t_s;
    result.structure_probe_uz = probe_table.uz_m;
    result.mode_table = mode_table;
    result.mic_t = mic_table.t_s;
    result.mic_p = mic_table.p_pa;

    % Load mic sweep files (mic_pressure_timeseries_sweep_01..10.csv)
    sweep_files = dir(fullfile(data_dir, 'mic_pressure_timeseries_sweep_*.csv'));
    if ~isempty(sweep_files)
        n_sweep = numel(sweep_files);
        mic_sweep = struct('label', cell(n_sweep, 1), 't', cell(n_sweep, 1), 'p', cell(n_sweep, 1), ...
            'distance_m', cell(n_sweep, 1));
        for s = 1:n_sweep
            sw_tbl = read_exported_numeric_csv(fullfile(data_dir, sweep_files(s).name));
            mic_sweep(s).label = sweep_files(s).name;
            mic_sweep(s).t = sw_tbl.t_s;
            mic_sweep(s).p = sw_tbl.p_pa;
        end
        % Load distance metadata if available
        dist_path = fullfile(data_dir, 'mic_sweep_distances.csv');
        if isfile(dist_path)
            dist_tbl = read_exported_numeric_csv(dist_path);
            for s = 1:min(n_sweep, height(dist_tbl))
                mic_sweep(s).distance_m = dist_tbl.distance_from_surface_m(s);
            end
        end
        for s = 1:n_sweep
            if isempty(mic_sweep(s).distance_m)
                mic_sweep(s).distance_m = NaN;
            end
        end
        result.mic_sweep = mic_sweep;
    end
end

% --- Write summary report ---
function write_summary_report(path, n_cases, n_fp, n_pp, n_tp, per_case, ~, data_rel_root)
    fid = fopen(path, 'w', 'n', 'UTF-8');
    fprintf(fid, '# Derived Metrics Validation Summary\n\n');
    fprintf(fid, '**Data root:** `%s`\n\n', data_rel_root);
    fprintf(fid, '**Run at:** %s\n\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
    fprintf(fid, '| Metric | Value |\n|---|---|\n');
    fprintf(fid, '| Total cases | %d |\n', n_cases);
    fprintf(fid, '| Format pass | %d / %d |\n', n_fp, n_cases);
    fprintf(fid, '| Precision pass | %d / %d |\n', n_pp, n_cases);
    fprintf(fid, '| Overall pass | %d / %d |\n', n_tp, n_cases);

    % Group summary
    groups = unique({per_case.group});
    fprintf(fid, '\n## Summary by Group\n\n');
    fprintf(fid, '| Group | Cases | Format Pass | Precision Pass | Overall Pass |\n');
    fprintf(fid, '|---|---|---|---|---|\n');
    for g = 1:numel(groups)
        grp = groups{g};
        idx = strcmp({per_case.group}, grp);
        n_grp = sum(idx);
        fp_grp = sum([per_case(idx).format_pass]);
        pp_grp = sum([per_case(idx).precision_pass]);
        tp_grp = sum([per_case(idx).overall_pass]);
        fprintf(fid, '| %s | %d | %d | %d | %d |\n', grp, n_grp, fp_grp, pp_grp, tp_grp);
    end

    % Case details
    fprintf(fid, '\n## Per-Case Details\n\n');
    fprintf(fid, '| # | Case | Format | Precision | SPL (dB) | f_dom_ref (Hz) | Centroid (Hz) | Flatness | Probe Peak (mm) | Best Mode Match (%%) | Modes Matched |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|---|---|---|\n');
    for i = 1:n_cases
        f_dom_str = sprintf('%.1f', per_case(i).f_dom_refined);
        spl_str = sprintf('%.1f', per_case(i).spl_rms);
        cent_str = sprintf('%.1f', per_case(i).spectral_centroid);
        flat_str = sprintf('%.4f', per_case(i).spectral_flatness);
        probe_str = sprintf('%.3f', per_case(i).probe_peak * 1000);
        delta_str = sprintf('%.2f', per_case(i).best_delta_pct);
        n_modes_str = sprintf('%d', per_case(i).n_matched_modes);
        if per_case(i).format_pass, fmt = 'P'; else, fmt = 'F'; end
        if per_case(i).precision_pass, prec = 'P'; else, prec = 'F'; end
        fprintf(fid, '| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n', ...
            i, per_case(i).root, fmt, prec, spl_str, f_dom_str, cent_str, flat_str, probe_str, delta_str, n_modes_str);
    end

    % Failed cases detail
    failed_mask = ~[per_case.overall_pass];
    if any(failed_mask)
        fprintf(fid, '\n## Failed Cases\n\n');
        fprintf(fid, '| Case | Format | Precision |\n');
        fprintf(fid, '|---|---|---|\n');
        for i = find(failed_mask)
            fprintf(fid, '| %s | %d | %d |\n', per_case(i).root, per_case(i).format_pass, per_case(i).precision_pass);
        end
    end

    fprintf(fid, '\n## Limitations\n\n');
    fprintf(fid, '- All cases use `0.10s coarse` time window unless otherwise noted.\n');
    fprintf(fid, '- Band decay metrics marked `preliminary_coarse_time_window` — insufficient window for strong decay conclusions.\n');
    fprintf(fid, '- No case has `tip_timeseries.csv`; Q estimation is unavailable (`q_source=missing_tip`).\n');
    fprintf(fid, '- Modal match quality degrades for higher modes due to limited frequency resolution and short time window.\n');
    fprintf(fid, '- FFT uses Hann window with 4× zero-padding; peak refinement via parabolic interpolation.\n');

    fclose(fid);
    fprintf('Summary report written: %s\n', path);
end
