function features = extract_timbre_features_from_pressure(t_s, p_pa)
%EXTRACT_TIMBRE_FEATURES_FROM_PRESSURE Derive FFT-based timbre features from microphone pressure.

    t_s = double(t_s(:));
    p_pa = double(p_pa(:));

    features = struct( ...
        "peak1_hz", NaN, ...
        "peak1_amp_pa", NaN, ...
        "peak2_hz", NaN, ...
        "peak2_amp_pa", NaN, ...
        "peak3_hz", NaN, ...
        "peak3_amp_pa", NaN, ...
        "spectral_centroid_hz", NaN, ...
        "spectral_bandwidth_hz", NaN, ...
        "rolloff85_hz", NaN, ...
        "mic_peak_abs_pa", NaN);

    if numel(t_s) < 4 || numel(t_s) ~= numel(p_pa)
        return;
    end

    [freq_hz, amp_pa] = compute_single_sided_fft(t_s, p_pa);
    if isempty(freq_hz) || isempty(amp_pa)
        return;
    end

    valid = isfinite(freq_hz) & isfinite(amp_pa) & (freq_hz > 0);
    freq_hz = freq_hz(valid);
    amp_pa = amp_pa(valid);
    if isempty(freq_hz)
        return;
    end

    power_spec = amp_pa .^ 2;
    power_sum = sum(power_spec);
    if power_sum > 0
        features.spectral_centroid_hz = sum(freq_hz .* power_spec) / power_sum;
        features.spectral_bandwidth_hz = sqrt(sum(((freq_hz - features.spectral_centroid_hz) .^ 2) .* power_spec) / power_sum);
        cumulative_power = cumsum(power_spec);
        idx_rolloff = find(cumulative_power >= 0.85 * power_sum, 1, 'first');
        if ~isempty(idx_rolloff)
            features.rolloff85_hz = freq_hz(idx_rolloff);
        end
    end

    [sorted_amp, order] = sort(amp_pa, 'descend');
    top_count = min(3, numel(order));
    top_freq = nan(3, 1);
    top_amp = nan(3, 1);
    top_freq(1:top_count) = freq_hz(order(1:top_count));
    top_amp(1:top_count) = sorted_amp(1:top_count);

    features.peak1_hz = top_freq(1);
    features.peak1_amp_pa = top_amp(1);
    features.peak2_hz = top_freq(2);
    features.peak2_amp_pa = top_amp(2);
    features.peak3_hz = top_freq(3);
    features.peak3_amp_pa = top_amp(3);
    features.mic_peak_abs_pa = max(abs(p_pa));
end
