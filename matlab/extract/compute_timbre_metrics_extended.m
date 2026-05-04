function metrics = compute_timbre_metrics_extended(mic_t_s, mic_p_pa)
%COMPUTE_TIMBRE_METRICS_EXTENDED Extended timbre metrics beyond basic acoustic metrics.
%   metrics = compute_timbre_metrics_extended(mic_t_s, mic_p_pa)
%
%   Requires: mic_t_s, mic_p_pa (raw timeseries)
%   Returns struct with:
%     peak_count, dominant_to_second_peak_ratio,
%     low_energy_ratio, mid_energy_ratio, high_energy_ratio,
%     spectral_slope_db_per_hz, a_weighted_spl_proxy_db,
%     attack_time_10pct_s, decay_time_50pct_s, energy_decay_85pct_s

    arguments
        mic_t_s (:, 1) double
        mic_p_pa (:, 1) double
    end

    metrics = struct( ...
        'peak_count', NaN, ...
        'dominant_to_second_peak_ratio', NaN, ...
        'low_energy_ratio', NaN, ...
        'mid_energy_ratio', NaN, ...
        'high_energy_ratio', NaN, ...
        'spectral_slope_db_per_octave', NaN, ...
        'a_weighted_spl_proxy_db', NaN, ...
        'attack_time_10pct_s', NaN, ...
        'decay_time_50pct_s', NaN, ...
        'energy_decay_85pct_s', NaN, ...
        'second_peak_freq_hz', NaN, ...
        'total_energy_pa2', NaN);

    if numel(mic_t_s) < 10
        return;
    end

    % FFT for spectral analysis
    [freq_hz, amp_pa] = compute_single_sided_fft(mic_t_s, mic_p_pa);

    % === Spectral peaks ===
    % Find local peaks in spectrum
    n = numel(freq_hz);
    peak_idx = false(n, 1);
    for i = 2:n-1
        if amp_pa(i) >= amp_pa(i-1) && amp_pa(i) > amp_pa(i+1)
            peak_idx(i) = true;
        end
    end

    % Filter: only peaks > 1% of max amp, in audible range 20-20000 Hz
    mask = amp_pa > 0.01 * max(amp_pa) & freq_hz >= 20 & freq_hz <= 20000;
    visible_peaks = peak_idx & mask;
    metrics.peak_count = sum(visible_peaks);

    % Dominant to second peak ratio
    peak_amps = amp_pa(visible_peaks);
    peak_freqs = freq_hz(visible_peaks);
    if numel(peak_amps) >= 2
        sorted_amps = sort(peak_amps, 'descend');
        metrics.dominant_to_second_peak_ratio = sorted_amps(1) / sorted_amps(2);
        % Second peak frequency
        second_idx = find(peak_amps == sorted_amps(2), 1);
        metrics.second_peak_freq_hz = peak_freqs(second_idx);
    end

    % === Band energy ratios (Hz ranges) ===
    low_mask = freq_hz >= 20 & freq_hz < 300;
    mid_mask = freq_hz >= 300 & freq_hz < 2000;
    high_mask = freq_hz >= 2000 & freq_hz <= 20000;

    low_energy = sum(amp_pa(low_mask).^2);
    mid_energy = sum(amp_pa(mid_mask).^2);
    high_energy = sum(amp_pa(high_mask).^2);
    total = low_energy + mid_energy + high_energy;

    if total > 0
        metrics.low_energy_ratio = low_energy / total;
        metrics.mid_energy_ratio = mid_energy / total;
        metrics.high_energy_ratio = high_energy / total;
        metrics.total_energy_pa2 = total;
    end

    % === Spectral slope (dB per octave) ===
    % Fit log-log regression: log(amp) vs log(freq) in [100, 5000] Hz
    slope_mask = freq_hz >= 100 & freq_hz <= 5000;
    if any(slope_mask)
        log_f = log2(freq_hz(slope_mask));
        log_a = log(amp_pa(slope_mask) + eps);
        p = polyfit(log_f, log_a, 1);
        metrics.spectral_slope_db_per_octave = p(1) * 20 / log(10); % convert to dB/octave
    end

    % === A-weighted SPL proxy ===
    % Simplified A-weighting: -2dB at 100Hz, -0.5dB at 500Hz, flat above 1000Hz
    a_weight = ones(size(freq_hz));
    a_weight(freq_hz < 1000) = interp1([20, 100, 500, 1000], [0.0, 0.63, 0.89, 1.0], ...
        min(freq_hz(freq_hz < 1000), 1000), 'linear');
    a_weighted_amp = amp_pa .* a_weight;
    a_spl = 20 * log10(sqrt(2 * sum(a_weighted_amp.^2)) / 2e-5);
    metrics.a_weighted_spl_proxy_db = a_spl;

    % === Time-domain envelope metrics ===
    % Envelope via rectification + moving maximum (no Signal Processing Toolbox)
    env = abs(mic_p_pa);
    half_win = max(3, round(0.002 / mean(diff(mic_t_s))));
    env = movmax(env, 2 * half_win + 1);
    t = mic_t_s;

    % Attack time: 10% to 90% of max envelope
    [max_env, max_idx] = max(env);
    env_norm = env / max_env;

    % Find 10% and 90% crossings before peak
    t10 = t(1);
    t90 = t(1);
    for i = 1:max_idx
        if env_norm(i) >= 0.1 && t10 == t(1)
            t10 = t(i);
        end
        if env_norm(i) >= 0.9
            t90 = t(i);
            break;
        end
    end
    metrics.attack_time_10pct_s = t90 - t10;

    % Decay time: from peak to 50% envelope
    for i = max_idx:numel(env)
        if env_norm(i) <= 0.5
            metrics.decay_time_50pct_s = t(i) - t(max_idx);
            break;
        end
    end

    % Energy decay (Schroeder integration): time for 85% energy
    energy = env.^2;
    cumulative = cumsum(energy(end:-1:1));
    cumulative = cumulative(end:-1:1);  % backward integration
    cumulative_norm = cumulative / max(cumulative);
    for i = max_idx:numel(t)
        if cumulative_norm(i) <= 0.15
            metrics.energy_decay_85pct_s = t(i) - t(max_idx);
            break;
        end
    end
end
