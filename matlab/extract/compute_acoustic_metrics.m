function metrics = compute_acoustic_metrics(t_s, p_pa, fft_opts)
%COMPUTE_ACOUSTIC_METRICS Derive acoustic metrics from microphone pressure time series.
%   metrics = compute_acoustic_metrics(t_s, p_pa)
%   metrics = compute_acoustic_metrics(t_s, p_pa, fft_opts)
%
%   fft_opts: optional struct passed to compute_single_sided_fft (see its docs)
%
%   Outputs a struct with fields:
%     Bin-level (kept for traceability):
%       p_rms_pa, p_peak_pa, spl_rms_db, spl_peak_db,
%       f_dom_hz, spectral_centroid_hz, spectral_bandwidth_hz, rolloff85_hz,
%       band_30_120_ratio, band_120_500_ratio, band_500_2000_ratio
%     Refined (added for precision):
%       f_dom_refined_hz, f_dom_bin_amp_pa, fft_resolution_hz,
%       spectral_flatness, high_low_energy_ratio

    arguments
        t_s (:, 1) double
        p_pa (:, 1) double
        fft_opts.remove_mean (1, 1) logical = true
        fft_opts.window (1, 1) string = "hann"
        fft_opts.zero_padding_factor (1, 1) double {mustBePositive, mustBeInteger} = 4
    end

    % Defaults
    metrics = struct( ...
        "p_rms_pa", NaN, ...
        "p_peak_pa", NaN, ...
        "spl_rms_db", NaN, ...
        "spl_peak_db", NaN, ...
        "f_dom_hz", NaN, ...
        "spectral_centroid_hz", NaN, ...
        "spectral_bandwidth_hz", NaN, ...
        "rolloff85_hz", NaN, ...
        "band_30_120_ratio", NaN, ...
        "band_120_500_ratio", NaN, ...
        "band_500_2000_ratio", NaN, ...
        "f_dom_refined_hz", NaN, ...
        "f_dom_bin_amp_pa", NaN, ...
        "fft_resolution_hz", NaN, ...
        "spectral_flatness", NaN, ...
        "high_low_energy_ratio", NaN);

    if numel(t_s) < 4
        return;
    end

    % --- Loudness ---
    p_ref = 20e-6;
    p_rms = rms(p_pa, 'omitnan');
    p_peak = max(abs(p_pa), [], 'omitnan');

    metrics.p_rms_pa = p_rms;
    metrics.p_peak_pa = p_peak;
    if p_rms > 0
        metrics.spl_rms_db = 20 * log10(p_rms / p_ref);
    end
    if p_peak > 0
        metrics.spl_peak_db = 20 * log10(p_peak / p_ref);
    end

    % === Precision-improved FFT (name-value opts) ===
    [freq_hz, amp_pa, meta] = compute_single_sided_fft(t_s, p_pa, ...
        'remove_mean', fft_opts.remove_mean, ...
        'window', fft_opts.window, ...
        'zero_padding_factor', fft_opts.zero_padding_factor);
    if isempty(freq_hz)
        return;
    end

    metrics.fft_resolution_hz = meta.freq_resolution_hz;

    valid = isfinite(freq_hz) & isfinite(amp_pa) & (freq_hz > 0);
    freq_hz = freq_hz(valid);
    amp_pa = amp_pa(valid);
    if isempty(freq_hz)
        return;
    end

    % --- Dominant frequency (bin-level) ---
    [peak_amp, idx_max] = max(amp_pa);
    metrics.f_dom_hz = freq_hz(idx_max);
    metrics.f_dom_bin_amp_pa = peak_amp;

    % --- Parabolic refinement of dominant peak ---
    % Map idx_max back to original array indices for refine_peak_parabolic
    orig_idx = find(valid);
    if length(orig_idx) >= idx_max
        [f_ref, ~, ~] = refine_peak_parabolic(freq_hz, amp_pa, idx_max);
        if isfinite(f_ref)
            metrics.f_dom_refined_hz = f_ref;
        end
    end

    % --- Timbre: spectral centroid, bandwidth, rolloff ---
    power_spec = amp_pa .^ 2;
    power_sum = sum(power_spec);
    if power_sum > 0
        metrics.spectral_centroid_hz = sum(freq_hz .* power_spec) / power_sum;
        metrics.spectral_bandwidth_hz = sqrt(sum(((freq_hz - metrics.spectral_centroid_hz).^2) .* power_spec) / power_sum);

        % Rolloff 85%
        cumulative_power = cumsum(power_spec);
        idx85 = find(cumulative_power >= 0.85 * power_sum, 1, 'first');
        if ~isempty(idx85)
            metrics.rolloff85_hz = freq_hz(idx85);
        end

        % Spectral flatness (Wiener entropy)
        geo_mean = exp(mean(log(power_spec + eps)));
        arith_mean = mean(power_spec);
        if arith_mean > 0
            metrics.spectral_flatness = geo_mean / arith_mean;
        end

        % High / low energy ratio (split at 500 Hz)
        idx_high = freq_hz > 500;
        energy_high = sum(power_spec(idx_high));
        energy_low = sum(power_spec(~idx_high));
        if energy_low > 0
            metrics.high_low_energy_ratio = energy_high / energy_low;
        end
    end

    % --- Energy ratios in standard bands ---
    band_edges = [30, 120, 500, 2000];
    for b = 1:(numel(band_edges) - 1)
        lo = band_edges(b);
        hi = band_edges(b + 1);
        idx_band = (freq_hz >= lo) & (freq_hz < hi);
        band_energy = sum(power_spec(idx_band));
        if b == 1
            metrics.band_30_120_ratio = band_energy / power_sum;
        elseif b == 2
            metrics.band_120_500_ratio = band_energy / power_sum;
        else
            metrics.band_500_2000_ratio = band_energy / power_sum;
        end
    end
end
