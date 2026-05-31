function T_corrected = correct_frequencies_from_fft(proj_root, data_rel_root)
%CORRECT_FREQUENCIES_FROM_FFT  FFT 峰值修正 COMSOL 特征频率（eigen_shift 偏移 bug）。
%   对所有 case，从 mic 压力 FFT 中提取真实声学峰值，
%   与 COMSOL 特征值对比，替换被错误标记的低阶模态。

    arguments
        proj_root (1,:) char = 'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler'
        data_rel_root (1,:) char = 'outputs/requested_adaptive'
    end

    addpath(genpath(fullfile(proj_root, 'matlab')));
    tables_dir = fullfile(proj_root, data_rel_root, 'tables');

    T = readtable(fullfile(tables_dir, 'conclusion_master_table.csv'));
    fprintf('Loaded: %d cases\n', height(T));

    corrected_f1 = NaN(height(T), 1);
    corrected_f2 = NaN(height(T), 1);
    corrected_f3 = NaN(height(T), 1);
    corrected_f4 = NaN(height(T), 1);
    corrected_f5 = NaN(height(T), 1);
    corrected_f6 = NaN(height(T), 1);
    shift_issue = false(height(T), 1);

    for i = 1:height(T)
        cr = T.case_id{i};
        parts = strsplit(cr, '/');
        if numel(parts) >= 2
            group = parts{end-1};
        else
            group = '';
        end
        param = parts{end};

        data_dir = fullfile(proj_root, data_rel_root, 'cases', cr, 'data');
        mic_path = fullfile(data_dir, 'mic_pressure_timeseries.csv');
        freq_path = fullfile(data_dir, 'frequencies.csv');
        if ~isfile(mic_path) || ~isfile(freq_path)
            continue;
        end

        mt = read_exported_numeric_csv(mic_path);
        ft = read_exported_numeric_csv(freq_path);

        % FFT of mic pressure
        [f_fft, a_fft] = compute_single_sided_fft(mt.t_s, mt.p_pa);
        [~, sorted_idx] = sort(a_fft, 'descend');

        % Use FFT peaks as ground truth: find distinct peaks > 20 dB below max
        max_amp = a_fft(sorted_idx(1));
        threshold_db = 20;
        threshold_amp = max_amp * 10^(-threshold_db/20);

        fft_peaks = [];
        for k = 1:min(200, numel(sorted_idx))
            idx = sorted_idx(k);
            if a_fft(idx) < threshold_amp, break; end
            % Check it's a local maximum
            is_peak = true;
            if idx > 1 && a_fft(idx-1) > a_fft(idx), is_peak = false; end
            if idx < numel(a_fft) && a_fft(idx+1) > a_fft(idx), is_peak = false; end
            if is_peak
                fft_peaks(end+1) = f_fft(idx); %#ok<AGROW>
            end
        end

        comsol_freqs = ft.freq_hz(:)';
        n_modes = numel(comsol_freqs);

        % Check if COMSOL modes match FFT peaks
        matched = zeros(1, n_modes);
        for k = 1:n_modes
            [~, closest] = min(abs(fft_peaks - comsol_freqs(k)));
            if abs(fft_peaks(closest) - comsol_freqs(k)) / comsol_freqs(k) < 0.15
                if ~ismember(closest, matched(matched > 0))
                    matched(k) = closest;
                end
            end
        end

        % Heuristic: eigen_shift=1000Hz causes the solver to miss low modes.
        % Detect this by checking if lowest COMSOL mode is >> lowest FFT peak.
        comsol_lowest = min(comsol_freqs);
        fft_peaks_asc = sort(fft_peaks);
        fft_lowest = fft_peaks_asc(1);
        fft_second = min(fft_peaks_asc(2:end));

        shift_issue(i) = false;

        % Criterion A: COMSOL's lowest is > 2x the FFT's lowest AND
        % there is a FFT peak below 100 Hz with > 5% of total energy
        fft_low_energy = sum(a_fft(f_fft < 100).^2);
        fft_total_energy = sum(a_fft.^2);
        low_frac = fft_low_energy / max(fft_total_energy, 1e-30);

        critA = (comsol_lowest > 2 * fft_lowest) && (low_frac > 0.05);

        % Criterion B: non-steel material with COMSOL f1 > 200 Hz
        mat = T.material{i};
        critB = ~strcmp(mat, 'steel') && comsol_lowest > 200;

        % Criterion C: thin/long geometry (h <= 1mm, L >= 26cm)
        critC = (T.h_mm(i) <= 1.0 || T.L_free_cm(i) >= 26) && comsol_lowest > 3 * fft_lowest;

        if critA || critB || critC
            shift_issue(i) = true;
            % Collect up to 6 lowest FFT peaks as corrected modes
            n_fft = min(6, numel(fft_peaks_asc));
            for k = 1:n_fft
                eval(sprintf('corrected_f%d(i) = fft_peaks_asc(k);', k));
            end
        end

        if ~shift_issue(i)
            % COMSOL data is fine, copy directly
            corrected_f1(i) = T.f1_hz(i);
            corrected_f2(i) = T.f2_hz(i);
            corrected_f3(i) = T.f3_hz(i);
            corrected_f4(i) = T.f4_hz(i);
            corrected_f5(i) = T.f5_hz(i);
            corrected_f6(i) = T.f6_hz(i);
        end

        if mod(i, 5) == 0
            fprintf('[%d/%d] %s/%s: COMSOL=%.1f, FFT=%.1f, fixed=%d\n', ...
                i, height(T), group, param, min(comsol_freqs), min(fft_peaks), shift_issue(i));
        end
    end

    % Build corrected table
    T_corrected = T;
    T_corrected.f1_hz = corrected_f1;
    T_corrected.f2_hz = corrected_f2;
    T_corrected.f3_hz = corrected_f3;
    T_corrected.f4_hz = corrected_f4;
    T_corrected.f5_hz = corrected_f5;
    T_corrected.f6_hz = corrected_f6;
    T_corrected.shift_issue = shift_issue;

    % Write
    out_path = fullfile(tables_dir, 'conclusion_master_table_corrected.csv');
    writetable(T_corrected, out_path, 'Encoding', 'UTF-8');
    fprintf('\nCorrected table written: %s\n', out_path);
    fprintf('Cases with eigen_shift issue: %d / %d\n', sum(shift_issue), height(T));
    for i = find(shift_issue)'
        fprintf('  %-50s  COMSOL f1=%.1f -> FFT f1=%.1f Hz\n', ...
            T.case_id{i}, T.f1_hz(i), corrected_f1(i));
    end
end
