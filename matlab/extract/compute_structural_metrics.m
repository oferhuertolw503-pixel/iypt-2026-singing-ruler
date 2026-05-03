function metrics = compute_structural_metrics(probe_t_s, probe_uz_m, freq_table, tip_t_s, tip_w_m)
%COMPUTE_STRUCTURAL_METRICS Derive structural metrics from displacement time series.
%   metrics = compute_structural_metrics(probe_t_s, probe_uz_m, freq_table)
%   metrics = compute_structural_metrics(..., tip_t_s, tip_w_m)
%
%   freq_table must have columns: mode, freq_hz (from frequencies.csv)
%
%   Output struct fields:
%     probe_peak_m, probe_rms_m, tip_peak_m, tip_rms_m
%     dominant_structure_freq_hz
%     q_estimate, log_decrement
%     num_modes, f1_hz..f6_hz (up to 6 modes)

    arguments
        probe_t_s (:, 1) double
        probe_uz_m (:, 1) double
        freq_table table
        tip_t_s (:, 1) double = zeros(0, 1)
        tip_w_m (:, 1) double = zeros(0, 1)
    end

    metrics = struct( ...
        "probe_peak_m", NaN, ...
        "probe_rms_m", NaN, ...
        "tip_peak_m", NaN, ...
        "tip_rms_m", NaN, ...
        "dominant_structure_freq_hz", NaN, ...
        "q_estimate", NaN, ...
        "log_decrement", NaN, ...
        "q_source", "missing_tip");

    if numel(probe_t_s) < 3
        return;
    end

    % Basic stats
    metrics.probe_peak_m = max(abs(probe_uz_m));
    metrics.probe_rms_m = rms(probe_uz_m);

    % Dominant frequency from structure probe FFT
    [freq_hz, amp] = compute_single_sided_fft(probe_t_s, probe_uz_m);
    if ~isempty(freq_hz)
        valid = isfinite(amp) & (freq_hz > 0);
        if any(valid)
            [~, idx_max] = max(amp(valid));
            f_valid = freq_hz(valid);
            metrics.dominant_structure_freq_hz = f_valid(idx_max);
        end
    end

    % Damping / Q from tip decay when available. Do not silently treat
    % structure probe as the tip; the source must remain explicit.
    if numel(tip_t_s) >= 3 && numel(tip_t_s) == numel(tip_w_m)
        metrics.tip_peak_m = max(abs(tip_w_m));
        metrics.tip_rms_m = rms(tip_w_m);
        q_info = estimate_q_from_tip(tip_t_s, tip_w_m);
        metrics.q_estimate = q_info.q_estimate;
        metrics.log_decrement = q_info.log_decrement;
        metrics.q_source = "tip";
    end

    % Modal frequencies (up to 6)
    if istable(freq_table) && all(ismember({'mode', 'freq_hz'}, freq_table.Properties.VariableNames))
        n_modes = min(height(freq_table), 6);
        for k = 1:n_modes
            fname = sprintf("f%d_hz", k);
            metrics.(fname) = freq_table.freq_hz(k);
        end
        metrics.num_modes = n_modes;
    end
end
