function T = aggregate_conclusion_table(proj_root, data_rel_root)
%AGGREGATE_CONCLUSION_TABLE Master conclusion table across all cases.
%   T = aggregate_conclusion_table(proj_root, data_rel_root)
%
%   Reads all case directories, extracts key metrics from derived CSVs,
%   and produces a single comprehensive table mapping independent variables
%   to dependent variables (frequency, SPL, decay, timbre).
%
%   Output table columns:
%     INDEPENDENT:  L_free_cm, b_cm, h_mm, J_Ns, x0_ratio, material
%     FREQUENCY:    f1_hz ... f6_hz
%     SPL:          spl_rms_db, spl_peak_db
%     MIC SWEEP:    spl_at_0p02m ... spl_at_0p10m (10 distances)
%     DECAY:        tau1_s ... tau6_s (per-mode time constants)
%     TIMBRE:       spectral_centroid_hz, spectral_flatness, rolloff85_hz
%     QUALITY:      q_estimate, best_mode_match_pct, n_modal_matches

    arguments
        proj_root (1, :) char = fullfile(fileparts(mfilename('fullpath')), '..', '..')
        data_rel_root (1, :) char = 'outputs/requested_3d_air_coarse_review_light'
    end

    addpath(fullfile(proj_root, 'matlab', 'core'));
    addpath(fullfile(proj_root, 'matlab', 'extract'));

    cases_root = fullfile(proj_root, data_rel_root, 'cases');
    tables_dir = fullfile(proj_root, data_rel_root, 'tables');
    ensure_dir(tables_dir);

    % Discover cases
    listing = dir(fullfile(cases_root, '**', 'data', 'frequencies.csv'));
    case_dirs = {};
    for i = 1:numel(listing)
        data_dir = listing(i).folder;
        if isfile(fullfile(data_dir, 'mic_pressure_timeseries.csv'))
            rel = strrep(extractAfter(data_dir, cases_root), '\', '/');
            if startsWith(rel, '/'), rel = rel(2:end); end
            if endsWith(rel, '/data'), rel = rel(1:end-5); end
            case_dirs{end+1} = rel;
        end
    end
    case_dirs = sort(case_dirs);
    n_cases = numel(case_dirs);

    fprintf('Found %d cases under %s\n', n_cases, cases_root);

    % Preallocate table columns
    n_modes = 6;
    col_names = {
        'case_id', 'group', 'param', 'material', ...
        'L_free_cm', 'b_cm', 'h_mm', 'J_Ns', 'x0_ratio', ...
        'time_end_s', 'time_step_s', ...
    };
    % Modal frequencies
    for k = 1:n_modes
        col_names{end+1} = sprintf('f%d_hz', k);
    end
    % SPL
    col_names = [col_names, {'spl_rms_db', 'spl_peak_db', 'p_rms_pa', 'p_peak_pa'}];
    % Timbre
    col_names = [col_names, {'spectral_centroid_hz', 'spectral_flatness', ...
        'rolloff85_hz', 'f_dom_hz', 'f_dom_refined_hz'}];
    % Mic sweep SPL (10 points)
    for s = 1:10
        col_names{end+1} = sprintf('mic_sweep_spl_%02d_db', s);
        col_names{end+1} = sprintf('mic_sweep_dist_%02d_m', s);
    end
    % Modal decay
    for k = 1:n_modes
        col_names{end+1} = sprintf('tau%d_s', k);
        col_names{end+1} = sprintf('Q%d', k);
        col_names{end+1} = sprintf('r2_%d', k);
    end
    % Rayleigh
    col_names = [col_names, {'alpha_dM_est', 'beta_dK_est', 'rayleigh_valid'}];
    % Quality
    col_names = [col_names, {'q_estimate', 'q_source', 'best_mode_match_pct', ...
        'n_modal_matches', 'probe_peak_mm', 'decay_quality'}];

    data = cell(n_cases, numel(col_names));

    for i = 1:n_cases
        cr = case_dirs{i};
        case_root = fullfile(cases_root, cr);
        data_dir = fullfile(case_root, 'data');
        parts = strsplit(cr, '/');
        group = 'unknown';
        param = cr;
        if numel(parts) >= 2
            group = parts{end-1};
            param = parts{end};
        end

        % Parse independent variables from params_resolved.json
        params_path = fullfile(case_root, 'params_resolved.json');
        iv = parse_independent_vars(params_path, cr);

        % Read metrics
        row = {cr, group, param, iv.material, iv.L_free_cm, iv.b_cm, ...
            iv.h_mm, iv.J_Ns, iv.x0_ratio, iv.time_end_s, iv.time_step_s};

        % --- Frequencies ---
        freq_path = fullfile(data_dir, 'frequencies.csv');
        if isfile(freq_path)
            ft = read_exported_numeric_csv(freq_path);
            for k = 1:min(n_modes, height(ft))
                row{end+1} = ft.freq_hz(k);
            end
            for k = height(ft)+1:n_modes
                row{end+1} = NaN;
            end
        else
            for k = 1:n_modes, row{end+1} = NaN; end
        end

        % --- SPL ---
        acc_path = fullfile(data_dir, 'acoustic_metrics.csv');
        if isfile(acc_path)
            acc = read_metric_table(acc_path);
            row = [row, {acc.spl_rms_db(1), acc.spl_peak_db(1), ...
                acc.p_rms_pa(1), acc.p_peak_pa(1)}];
            row{end+1} = acc.spectral_centroid_hz(1);
            row{end+1} = acc.spectral_flatness(1);
            row{end+1} = acc.rolloff85_hz(1);
            try, row{end+1} = acc.f_dom_hz(1); catch, row{end+1} = NaN; end
            try, row{end+1} = acc.f_dom_refined_hz(1); catch, row{end+1} = NaN; end
        else
            % Compute SPL directly from mic timeseries
            mic_path = fullfile(data_dir, 'mic_pressure_timeseries.csv');
            if isfile(mic_path)
                mt = read_exported_numeric_csv(mic_path);
                rms_pa = rms(mt.p_pa);
                peak_pa = max(abs(mt.p_pa));
                spl_rms = 20*log10(max(rms_pa,1e-12)/20e-6);
                spl_peak = 20*log10(max(peak_pa,1e-12)/20e-6);
                row = [row, {spl_rms, spl_peak, rms_pa, peak_pa, NaN, NaN, NaN, NaN, NaN}];
            else
                row = [row, {NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN}];
            end
        end

        % --- Mic sweep SPL ---
        dist_vals = NaN(10, 1);
        dist_path = fullfile(data_dir, 'mic_sweep_distances.csv');
        if isfile(dist_path)
            dt = read_exported_numeric_csv(dist_path);
            for d = 1:min(10, height(dt))
                dist_vals(d) = dt.distance_from_surface_m(d);
            end
        end
        for s = 1:10
            sw_name = sprintf('mic_pressure_timeseries_sweep_%02d.csv', s);
            sw_path = fullfile(data_dir, sw_name);
            if isfile(sw_path)
                sw = read_exported_numeric_csv(sw_path);
                sw_rms = rms(sw.p_pa);
                row{end+1} = 20*log10(max(sw_rms,1e-12)/20e-6);
            else
                row{end+1} = NaN;
            end
            row{end+1} = dist_vals(s);
        end

        % --- Modal decay ---
        md_path = fullfile(data_dir, 'modal_decay.csv');
        if isfile(md_path)
            md = read_metric_table(md_path);
            for k = 1:min(n_modes, height(md))
                row{end+1} = md.tau_s(k);
                row{end+1} = md.Q_estimate(k);
                row{end+1} = md.r_squared(k);
            end
            for k = height(md)+1:n_modes
                row = [row, {NaN, NaN, NaN}];
            end
        else
            for k = 1:n_modes
                row = [row, {NaN, NaN, NaN}];
            end
        end

        % --- Rayleigh estimates ---
        if isfile(md_path)
            rayleigh_str = estimate_rayleigh_from_modal_decay(md);
        else
            rayleigh_str = {NaN, NaN, false};
        end
        row = [row, rayleigh_str];

        % --- Quality ---
        struct_path = fullfile(data_dir, 'structural_metrics.csv');
        if isfile(struct_path)
            sm = read_metric_table(struct_path);
            try, row{end+1} = sm.q_estimate(1); catch, row{end+1} = NaN; end
            try, row{end+1} = table_text_value(sm, 'q_source', 1); catch, row{end+1} = 'unknown'; end
        else
            row = [row, {NaN, 'unknown'}];
        end

        coupl_path = fullfile(data_dir, 'modal_acoustic_coupling.csv');
        if isfile(coupl_path)
            c = read_metric_table(coupl_path);
            if ismember('rel_delta_refined_pct', c.Properties.VariableNames)
                row{end+1} = min(c.rel_delta_refined_pct);
            else
                row{end+1} = min(c.rel_delta_pct);
            end
            row{end+1} = height(c);
        else
            row = [row, {NaN, NaN}];
        end

        % Probe peak
        probe_path = fullfile(data_dir, 'structure_probe_timeseries.csv');
        if isfile(probe_path)
            pt = read_exported_numeric_csv(probe_path);
            row{end+1} = max(abs(pt.uz_m)) * 1000; % mm
        else
            row{end+1} = NaN;
        end

        % Decay quality assessment
        md_path2 = fullfile(data_dir, 'modal_decay.csv');
        if isfile(md_path2)
            md2 = read_metric_table(md_path2);
            n_good = sum(md2.fit_valid & md2.r_squared > 0.7);
            if n_good >= 4, row{end+1} = 'excellent';
            elseif n_good >= 2, row{end+1} = 'good';
            elseif n_good >= 1, row{end+1} = 'marginal';
            else, row{end+1} = 'insufficient'; end
        else
            row{end+1} = 'no_data';
        end

        data(i, :) = row;
        fprintf('[%d/%d] %s\n', i, n_cases, cr);
    end

    T = cell2table(data, 'VariableNames', col_names);

    % Write
    out_path = fullfile(tables_dir, 'conclusion_master_table.csv');
    writetable(T, out_path, 'Encoding', 'UTF-8');
    fprintf('\nMaster conclusion table: %s (%d cases × %d columns)\n', ...
        out_path, height(T), width(T));

    % Print summary stats
    fprintf('\n=== COVERAGE ===\n');
    for c = col_names
        values = T.(c{1});
        if isnumeric(values) || islogical(values)
            n_valid = sum(~isnan(values));
        elseif iscell(values)
            n_valid = sum(~cellfun(@isempty, values));
        elseif isstring(values)
            n_valid = sum(strlength(values) > 0);
        else
            n_valid = height(T);
        end
        fprintf('  %s: %d/%d valid\n', c{1}, n_valid, height(T));
    end
end

function tbl = read_metric_table(path)
    opts = detectImportOptions(path, 'FileType', 'text');
    tbl = readtable(path, opts);
end

function value = table_text_value(tbl, var_name, idx)
    raw = tbl.(var_name);
    if iscell(raw)
        value = raw{idx};
    elseif isstring(raw)
        value = char(raw(idx));
    elseif ischar(raw)
        value = raw(idx, :);
    elseif iscategorical(raw)
        value = char(raw(idx));
    else
        value = char(string(raw(idx)));
    end
end

function rayleigh = estimate_rayleigh_from_modal_decay(md)
    rayleigh = {NaN, NaN, false};
    required = {'freq_hz', 'Q_estimate', 'fit_valid', 'r_squared'};
    if ~istable(md) || ~all(ismember(required, md.Properties.VariableNames))
        return;
    end

    valid_idx = find(md.fit_valid & md.r_squared > 0.7 & isfinite(md.Q_estimate) & md.Q_estimate > 0);
    if numel(valid_idx) < 2
        return;
    end

    lo = valid_idx(1);
    hi = valid_idx(end);
    if lo >= hi
        return;
    end

    omega_lo = 2 * pi * md.freq_hz(lo);
    omega_hi = 2 * pi * md.freq_hz(hi);
    zeta_lo = 1 / (2 * md.Q_estimate(lo));
    zeta_hi = 1 / (2 * md.Q_estimate(hi));
    A_mat = [1/(2*omega_lo), omega_lo/2; 1/(2*omega_hi), omega_hi/2];
    b_vec = [zeta_lo; zeta_hi];
    sol = A_mat \ b_vec;
    rayleigh = {sol(1), sol(2), sol(1) > 0 && sol(2) > 0};
end

function iv = parse_independent_vars(params_path, case_rel_path)
    iv = struct('material', 'unknown', 'L_free_cm', NaN, 'b_cm', NaN, ...
        'h_mm', NaN, 'J_Ns', NaN, 'x0_ratio', NaN, ...
        'time_end_s', NaN, 'time_step_s', NaN);

    if nargin >= 2
        parts = strsplit(case_rel_path, '/');
        material_part = parts(startsWith(parts, 'material_'));
        if ~isempty(material_part)
            iv.material = erase(material_part{end}, 'material_');
        end
    end

    if ~isfile(params_path), return; end

    try
        p = jsondecode(fileread(params_path));

        if strcmp(iv.material, 'unknown') && isfield(p, 'material')
            iv.material = 'unknown';
            if isfield(p.material, 'rho')
                rho = str2double(extractBefore(p.material.rho, '['));
                if rho > 7000, iv.material = 'steel';
                elseif rho > 1100 && rho < 1250, iv.material = 'acrylic';
                elseif rho > 1250 && rho < 1500, iv.material = 'pvc';
                elseif rho < 800, iv.material = 'xuefu_board';
                else, iv.material = 'other';
                end
            end
        end

        if isfield(p, 'geometry')
            iv.L_free_cm = parse_val_cm(p.geometry, 'L_free');
            iv.b_cm = parse_val_cm(p.geometry, 'b');
            iv.h_mm = parse_val_mm(p.geometry, 'h');
        end

        if isfield(p, 'excitation')
            iv.J_Ns = parse_val(p.excitation, 'J');
            x0_str = '';
            if isfield(p.excitation, 'x0'), x0_str = p.excitation.x0; end
            if contains(x0_str, '*L_free')
                iv.x0_ratio = str2double(extractBefore(x0_str, '*'));
            end
        end

        if isfield(p, 'studies')
            iv.time_end_s = parse_val(p.studies, 'time_end');
            iv.time_step_s = parse_val(p.studies, 'time_step');
        end
    catch
    end
end

function v = parse_val(section, field)
    v = NaN;
    if ~isfield(section, field), return; end
    raw = section.(field);
    if isnumeric(raw), v = raw; return; end
    str = extractBefore(char(raw), '[');
    v = str2double(strtrim(str));
end

function v = parse_val_cm(section, field)
    v = parse_val(section, field);
    if ~isnan(v), v = v * 100; end  % m → cm
end

function v = parse_val_mm(section, field)
    v = parse_val(section, field);
    if ~isnan(v), v = v * 1000; end  % m → mm
end
