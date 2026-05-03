function [decay, frame_times, band_energy, bands, meta] = compute_band_decay_metrics(t_s, p_pa)
%COMPUTE_BAND_DECAY_METRICS Hand-written STFT band energy envelopes and decay times.
%   [decay, frame_times, band_energy, bands] = compute_band_decay_metrics(t_s, p_pa)
%   [decay, frame_times, band_energy, bands, meta] = compute_band_decay_metrics(t_s, p_pa)
%
%   meta: struct with win_sec, hop_sec, nfft, method
%
%   decay: table with decay metrics per band
%   frame_times: Nx1 time stamps for each STFT frame (for plotting)
%   band_energy: NxF band energy matrix (for plotting)
%   bands:       Kx3 [band_id, f_low, f_high; ...]
%
%   Uses base MATLAB only (no Signal Processing Toolbox).
%   Hann window: win_sec = 0.020, hop_sec = 0.005.
%   Fixed frequency bands:
%     Band 1:  30-90 Hz    (low)
%     Band 2: 180-330 Hz   (mid-low)
%     Band 3: 450-850 Hz   (mid-high)
%     Band 4: 1100-1700 Hz (high)
%
%   Output table columns:
%     band_id, f_low_hz, f_high_hz, peak_time_s, active_duration_10pct_s,
%     active_duration_1pct_s, decay_to_10pct_s, decay_to_1pct_s, band_energy

    arguments
        t_s (:, 1) double
        p_pa (:, 1) double
    end

    decay = table();

    meta = struct('win_sec', 0.020, 'hop_sec', 0.005, 'nfft', 0, 'method', "hann_stft_zero_padded");

    n = numel(t_s);
    if n < 10
        frame_times = [];
        band_energy = [];
        bands = [];
        return;
    end

    dt = mean(diff(t_s));
    if ~(isfinite(dt) && dt > 0)
        frame_times = [];
        band_energy = [];
        bands = [];
        return;
    end
    fs = 1 / dt;

    % STFT parameters
    win_sec = 0.020;
    hop_sec = 0.005;
    win_len = max(round(win_sec * fs), 4);
    hop_len = max(round(hop_sec * fs), 1);

    % Hann window (hand-written)
    win = 0.5 - 0.5 * cos(2 * pi * (0:win_len-1).' / (win_len - 1));

    % Frequency bands
    bands = [
        1,  30,   90;     % low
        2, 180,  330;     % mid-low
        3, 450,  850;     % mid-high
        4, 1100, 1700     % high
    ];
    n_bands = size(bands, 1);

    % Build time-frequency energy envelope per band
    n_frames = floor((n - win_len) / hop_len) + 1;
    if n_frames < 2
        frame_times = [];
        band_energy = [];
        bands = [];
        return;
    end

    band_energy = zeros(n_frames, n_bands);
    frame_times = zeros(n_frames, 1);

    % Zero-padded NFFT for better frequency resolution
    nfft = 2^nextpow2(4 * win_len);
    meta.nfft = nfft;

    for f = 1:n_frames
        idx_start = (f - 1) * hop_len + 1;
        idx_end = idx_start + win_len - 1;
        segment = p_pa(idx_start:idx_end);
        frame_times(f) = mean(t_s(idx_start:idx_end));

        % Zero-padded DFT for better frequency-bin precision
        seg_fft = fft(segment .* win, nfft);
        half_n = floor(nfft / 2) + 1;
        seg_amp = abs(seg_fft(1:half_n));
        seg_freqs = (0:half_n - 1).' * fs / nfft;

        for b = 1:n_bands
            lo = bands(b, 2);
            hi = bands(b, 3);
            idx_band = (seg_freqs >= lo) & (seg_freqs <= hi);
            if any(idx_band)
                band_energy(f, b) = sum(seg_amp(idx_band).^2);
            end
        end
    end

    % Per-band decay analysis
    band_id_list = [];
    f_low_list = [];
    f_high_list = [];
    peak_time_list = [];
    active_dur_10_list = [];
    active_dur_1_list = [];
    decay_10_list = [];
    decay_1_list = [];
    band_energy_list = [];

    for b = 1:n_bands
        env = band_energy(:, b);
        total_energy = sum(env);
        if total_energy <= 0
            continue;
        end

        [peak_val, idx_peak] = max(env);
        peak_time_s = frame_times(idx_peak);
        threshold_10 = peak_val * 0.10;
        threshold_1 = peak_val * 0.01;

        % Active duration: time from rise above threshold to fall below
        above_10 = env >= threshold_10;
        above_1 = env >= threshold_1;

        t_start_10 = frame_times(find(above_10, 1, 'first'));
        t_end_10 = frame_times(find(above_10, 1, 'last'));
        t_start_1 = frame_times(find(above_1, 1, 'first'));
        t_end_1 = frame_times(find(above_1, 1, 'last'));

        % Envelope smoothing: find where envelope first crosses below threshold after peak
        after_peak_10 = false(size(env));
        after_peak_1 = false(size(env));
        if idx_peak < n_frames
            after_peak_10(idx_peak+1:end) = env(idx_peak+1:end) < threshold_10;
            after_peak_1(idx_peak+1:end) = env(idx_peak+1:end) < threshold_1;
        end
        first_cross_10 = find(after_peak_10, 1, 'first');
        first_cross_1 = find(after_peak_1, 1, 'first');

        decay_10_s = NaN;
        decay_1_s = NaN;
        if ~isempty(first_cross_10)
            decay_10_s = frame_times(first_cross_10) - peak_time_s;
        end

        if ~isempty(first_cross_1)
            decay_1_s = frame_times(first_cross_1) - peak_time_s;
        end

        active_dur_10_s = t_end_10 - t_start_10;
        active_dur_1_s = t_end_1 - t_start_1;

        band_id_list(end + 1) = bands(b, 1);               %#ok<AGROW>
        f_low_list(end + 1) = bands(b, 2);                  %#ok<AGROW>
        f_high_list(end + 1) = bands(b, 3);                 %#ok<AGROW>
        peak_time_list(end + 1) = peak_time_s;              %#ok<AGROW>
        active_dur_10_list(end + 1) = active_dur_10_s;     %#ok<AGROW>
        active_dur_1_list(end + 1) = active_dur_1_s;       %#ok<AGROW>
        decay_10_list(end + 1) = decay_10_s;                %#ok<AGROW>
        decay_1_list(end + 1) = decay_1_s;                  %#ok<AGROW>
        band_energy_list(end + 1) = total_energy;           %#ok<AGROW>
    end

    if isempty(band_id_list)
        frame_times = [];
        band_energy = [];
        bands = [];
        return;
    end

    decay = table(band_id_list(:), f_low_list(:), f_high_list(:), ...
        peak_time_list(:), active_dur_10_list(:), active_dur_1_list(:), ...
        decay_10_list(:), decay_1_list(:), band_energy_list(:), ...
        'VariableNames', {'band_id', 'f_low_hz', 'f_high_hz', ...
        'peak_time_s', 'active_duration_10pct_s', 'active_duration_1pct_s', ...
        'decay_to_10pct_s', 'decay_to_1pct_s', 'band_energy'});
end
