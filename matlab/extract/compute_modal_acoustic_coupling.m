function coupling = compute_modal_acoustic_coupling(freq_hz, amp_pa, freq_table)
%COMPUTE_MODAL_ACOUSTIC_COUPLING Match acoustic FFT peaks to structural modal frequencies.
%   coupling = compute_modal_acoustic_coupling(freq_hz, amp_pa, freq_table)
%
%   freq_table must have columns: mode, freq_hz
%   freq_hz, amp_pa: single-sided FFT output (preferably windowed/padded)
%
%   Returns table with columns:
%     Bin-level (kept for traceability):
%       mode, mode_freq_hz, nearest_mic_peak_hz, delta_hz, rel_delta_pct,
%       peak_amp_pa, snr_db, match_quality
%     Refined (added for precision):
%       nearest_mic_peak_refined_hz, delta_refined_hz, rel_delta_refined_pct

    arguments
        freq_hz (:, 1) double
        amp_pa (:, 1) double
        freq_table table
    end

    coupling = table();

    if isempty(freq_hz) || isempty(amp_pa) || ~istable(freq_table)
        return;
    end
    if ~all(ismember({'mode', 'freq_hz'}, freq_table.Properties.VariableNames))
        return;
    end

    % Detect local peaks (uses standalone function with min_prominence_db=3)
    peak_idx = detect_local_spectral_peaks(amp_pa, 3.0);
    if isempty(peak_idx)
        return;
    end

    peak_freqs = freq_hz(peak_idx);
    peak_amps = amp_pa(peak_idx);

    % Refine peak frequencies (sub-bin parabolic interpolation)
    [peak_freqs_refined, ~] = refine_peak_parabolic(freq_hz, amp_pa, peak_idx);
    % Fall back to bin frequency where refinement failed
    nan_ref = isnan(peak_freqs_refined);
    peak_freqs_refined(nan_ref) = peak_freqs(nan_ref);

    % Noise floor estimate (median of non-peak amplitudes)
    non_peak_mask = true(size(amp_pa));
    non_peak_mask(peak_idx) = false;
    noise_floor = median(amp_pa(non_peak_mask), 'omitnan');
    if ~isfinite(noise_floor) || noise_floor <= 0
        noise_floor = eps;
    end

    n_modes = height(freq_table);
    mode_list = [];
    mode_freqs = [];
    nearest_peaks = [];
    nearest_peaks_ref = [];
    peak_amps_matched = [];
    deltas = [];
    deltas_ref = [];
    rel_deltas = [];
    rel_deltas_ref = [];

    for i = 1:n_modes
        mf = freq_table.freq_hz(i);
        if ~isfinite(mf) || mf <= 0
            continue;
        end

        % Nearest acoustic peak (bin-level)
        [delta, idx] = min(abs(peak_freqs - mf));
        nearest_pf = peak_freqs(idx);
        nearest_pa = peak_amps(idx);
        rel_delta = abs(delta) / mf * 100;

        % Nearest refined peak
        delta_ref = abs(peak_freqs_refined(idx) - mf);
        nearest_pf_ref = peak_freqs_refined(idx);
        rel_delta_ref = abs(delta_ref) / mf * 100;

        mode_list(end + 1) = freq_table.mode(i);              %#ok<AGROW>
        mode_freqs(end + 1) = mf;                              %#ok<AGROW>
        nearest_peaks(end + 1) = nearest_pf;                   %#ok<AGROW>
        nearest_peaks_ref(end + 1) = nearest_pf_ref;           %#ok<AGROW>
        peak_amps_matched(end + 1) = nearest_pa;               %#ok<AGROW>
        deltas(end + 1) = delta;                               %#ok<AGROW>
        deltas_ref(end + 1) = delta_ref;                       %#ok<AGROW>
        rel_deltas(end + 1) = rel_delta;                       %#ok<AGROW>
        rel_deltas_ref(end + 1) = rel_delta_ref;               %#ok<AGROW>
    end

    if isempty(mode_list)
        return;
    end

    % SNR relative to noise floor
    snr_db = 20 * log10(peak_amps_matched / noise_floor + eps);

    % Match quality: refined error preferred, bin error fallback
    quality_str = strings(numel(mode_list), 1);
    for i = 1:numel(mode_list)
        err = rel_deltas_ref(i);
        if ~isfinite(err)
            err = rel_deltas(i);
        end
        if err < 2 && snr_db(i) > 20
            quality_str(i) = "excellent";
        elseif err < 5 && snr_db(i) > 10
            quality_str(i) = "good";
        elseif err < 10
            quality_str(i) = "fair";
        else
            quality_str(i) = "poor";
        end
    end

    coupling = table(mode_list(:), mode_freqs(:), ...
        nearest_peaks(:), deltas(:), rel_deltas(:), ...
        nearest_peaks_ref(:), deltas_ref(:), rel_deltas_ref(:), ...
        peak_amps_matched(:), snr_db(:), quality_str(:), ...
        'VariableNames', {'mode', 'mode_freq_hz', ...
        'nearest_mic_peak_hz', 'delta_hz', 'rel_delta_pct', ...
        'nearest_mic_peak_refined_hz', 'delta_refined_hz', 'rel_delta_refined_pct', ...
        'peak_amp_pa', 'snr_db', 'match_quality'});
end
