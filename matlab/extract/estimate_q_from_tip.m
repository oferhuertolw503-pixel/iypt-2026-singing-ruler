function result = estimate_q_from_tip(t_s, w_m)
%ESTIMATE_Q_FROM_TIP Estimate damping/Q from tip-displacement decay.
    t_s = double(t_s(:));
    w_m = abs(double(w_m(:)));

    result = struct( ...
        "q_estimate", NaN, ...
        "log_decrement", NaN, ...
        "num_peaks", 0, ...
        "peak_times_s", zeros(0, 1), ...
        "peak_values_m", zeros(0, 1));

    if numel(t_s) < 3 || numel(w_m) ~= numel(t_s)
        return;
    end

    peak_idx = local_peak_indices(w_m);
    if numel(peak_idx) < 2
        return;
    end

    peak_vals = w_m(peak_idx);
    positive = peak_vals > 0;
    peak_idx = peak_idx(positive);
    peak_vals = peak_vals(positive);
    if numel(peak_idx) < 2
        return;
    end

    % Start log-decrement from the maximum peak (excludes pre-impact
    % small peaks and handles multi-modal envelopes where the global
    % maximum occurs after several cycles).
    [~, max_i] = max(peak_vals);
    decay_vals = peak_vals(max_i:end);
    decay_n = numel(decay_vals);
    if decay_n < 2
        return;
    end

    delta = log(decay_vals(1) / decay_vals(end)) / (decay_n - 1);
    if ~(isfinite(delta) && delta > 0)
        % Fallback: try least-squares fit of log(amp) vs peak index
        log_amp = log(decay_vals);
        x = (0:decay_n - 1)';
        p = [x, ones(decay_n, 1)] \ log_amp;
        delta = -p(1);
        if ~(isfinite(delta) && delta > 0)
            return;
        end
    end

    result.log_decrement = delta;
    result.q_estimate = pi / delta;
    result.num_peaks = numel(peak_idx);
    result.peak_times_s = t_s(peak_idx);
    result.peak_values_m = peak_vals;
end

function idx = local_peak_indices(y)
    if exist('findpeaks', 'file') ~= 0
        [~, idx] = findpeaks(y);
        idx = idx(:);
        return;
    end

    idx = zeros(0, 1);
    for i = 2:(numel(y) - 1)
        if y(i) >= y(i - 1) && y(i) > y(i + 1)
            idx(end + 1, 1) = i; %#ok<AGROW>
        end
    end
end