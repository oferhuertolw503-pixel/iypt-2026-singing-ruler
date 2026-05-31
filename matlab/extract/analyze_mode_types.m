function T = analyze_mode_types(proj_root, data_rel_root, material_name)
%ANALYZE_MODE_TYPES Classify structural modes as bending/torsional/in-plane
% using EB theory harmonic ratios and acoustic coupling strength.
%
%   T = analyze_mode_types(proj_root, data_rel_root, material_name)
%
%   For each case matching material_name, reads frequencies.csv and
%   modal_acoustic_coupling.csv, classifies 6 modes, and returns a
%   table with per-mode: type, deviation from EB, radiation efficiency,
%   and corrected decay metrics.

    addpath(fullfile(proj_root, 'matlab', 'core'));
    addpath(fullfile(proj_root, 'matlab', 'extract'));

    % EB theoretical harmonic ratios for clamped-free cantilever
    % beta_n*L: 1.875, 4.694, 7.855, 10.996, 14.137, 17.279
    % f_n/f_1 = (beta_n/beta_1)^2
    EB_RATIOS = [1.000, 6.267, 17.548, 34.386, 56.843, 84.986];

    % Discover case roots
    cases_root = fullfile(proj_root, data_rel_root, 'cases');
    case_dirs = {};
    listing = dir(fullfile(cases_root, '**', 'data', 'frequencies.csv'));
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

    if nargin < 3 || isempty(material_name)
        material_name = '';
    end

    all_rows = {};
    for c = 1:numel(case_dirs)
        cr = case_dirs{c};
        data_dir = fullfile(cases_root, cr, 'data');

        % Check material match if specified
        if ~isempty(material_name)
            parts = strsplit(cr, '/');
            mat_part = parts(contains(parts, material_name));
            if isempty(mat_part), continue; end
        end

        % Read frequencies
        freq_path = fullfile(data_dir, 'frequencies.csv');
        if ~isfile(freq_path), continue; end
        ft = read_exported_numeric_csv(freq_path);
        freqs = ft.freq_hz;

        % Read coupling data
        coupl_path = fullfile(data_dir, 'modal_acoustic_coupling.csv');
        if ~isfile(coupl_path)
            % Compute coupling directly
            coupl = compute_coupling_from_raw(data_dir, freqs);
        else
            coupl = readtable(coupl_path);
        end

        % Read decay data
        decay_path = fullfile(data_dir, 'modal_decay.csv');
        has_decay = isfile(decay_path);
        if has_decay
            decay = readtable(decay_path);
        end

        % Classify each mode
        n_modes = min(6, length(freqs));
        for mode_k = 1:n_modes
            f_k = freqs(mode_k);
            f1 = freqs(1);
            actual_ratio = f_k / f1;

            % Find closest EB bending ratio
            [min_dev, best_eb_idx] = min(abs(actual_ratio - EB_RATIOS));

            % Get coupling data for this mode
            if istable(coupl) && height(coupl) >= mode_k
                peak_amp = coupl.peak_amp_pa(mode_k);
                snr_db = coupl.snr_db(mode_k);
            else
                peak_amp = NaN;
                snr_db = NaN;
            end

            % Get decay data
            if has_decay && height(decay) >= mode_k
                tau_s = decay.tau_s(mode_k);
                Q_val = decay.Q_estimate(mode_k);
                r2_val = decay.r_squared(mode_k);
            else
                tau_s = NaN; Q_val = NaN; r2_val = NaN;
            end

            % Classification logic
            deviation_pct = (actual_ratio - EB_RATIOS(best_eb_idx)) / EB_RATIOS(best_eb_idx) * 100;
            abs_deviation = abs(deviation_pct);

            % Bending: close to EB ratio AND strong acoustic radiation
            if abs_deviation < 3 && (~isnan(snr_db) && snr_db > 10)
                mode_type = 'bending';
            elseif abs_deviation < 5 && (~isnan(snr_db) && snr_db > 5)
                mode_type = 'bending';
            % Torsional: weak radiation, frequency between bending harmonics
            elseif ~isnan(snr_db) && snr_db < 5 && ~isnan(peak_amp) && peak_amp < 0.001
                mode_type = 'torsional';
            % In-plane: frequency proportional to b (width) rather than h
            elseif abs_deviation > 10
                mode_type = 'in_plane';
            else
                mode_type = 'uncertain';
            end

            all_rows{end+1} = {cr, mode_k, f_k, f1, actual_ratio, EB_RATIOS(best_eb_idx), ...
                best_eb_idx, deviation_pct, mode_type, peak_amp, snr_db, tau_s, Q_val, r2_val};
        end
    end

    T = cell2table(all_rows, 'VariableNames', {
        'case_root', 'mode_k', 'freq_hz', 'f1_hz', 'f_ratio_actual', ...
        'eb_ratio_nearest', 'eb_mode_order', 'deviation_pct', 'mode_type', ...
        'acoustic_peak_pa', 'snr_db', 'tau_s', 'Q', 'r2'});
end

function coupl = compute_coupling_from_raw(data_dir, freqs)
    % Fallback: compute modal-acoustic coupling from raw timeseries
    mic_path = fullfile(data_dir, 'mic_pressure_timeseries.csv');
    if ~isfile(mic_path)
        coupl = table();
        return;
    end
    mt = read_exported_numeric_csv(mic_path);
    [psd, f] = pwelch(mt.p_pa, hann(min(1024,length(mt.p_pa))), [], [], 1/mean(diff(mt.t_s)));
    mode_freq = freqs(:);
    n_modes = length(mode_freq);
    peak_amp = zeros(n_modes, 1);
    peak_freq = zeros(n_modes, 1);
    snr_db = zeros(n_modes, 1);
    for k = 1:n_modes
        [~, idx] = min(abs(f - mode_freq(k)));
        lo = max(1, idx - 5);
        hi = min(length(f), idx + 5);
        [peak_amp(k), peak_idx] = max(psd(lo:hi));
        peak_freq(k) = f(lo + peak_idx - 1);
        noise_floor = median(psd(lo:hi));
        snr_db(k) = 20*log10(max(peak_amp(k), 1e-20) / max(noise_floor, 1e-20));
    end
    coupl = table((1:n_modes)', mode_freq, peak_freq, ...
        abs(peak_freq - mode_freq), abs(peak_freq - mode_freq)./mode_freq*100, ...
        peak_freq, abs(peak_freq - mode_freq), abs(peak_freq - mode_freq)./mode_freq*100, ...
        peak_amp, snr_db, ...
        'VariableNames', {'mode','mode_freq_hz','nearest_mic_peak_hz', ...
        'delta_hz','rel_delta_pct','nearest_mic_peak_refined_hz', ...
        'delta_refined_hz','rel_delta_refined_pct','peak_amp_pa','snr_db'});
end
