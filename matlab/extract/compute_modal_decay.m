function [decay_table, summary] = compute_modal_decay(mic_t, mic_p, freq_table, opts)
%COMPUTE_MODAL_DECAY Per-mode exponential decay analysis from mic pressure.
%   [decay_table, summary] = compute_modal_decay(mic_t, mic_p, freq_table)
%
%   For each mode in freq_table, bandpass-filter the pressure signal around
%   the modal frequency, extract the envelope, and fit an exponential decay.
%
%   Output:
%     decay_table — one row per mode: f_hz, tau_s, decay_rate_1ps,
%                    Q_estimate, r_squared, n_cycles_captured
%     summary     — struct with alpha_dM, beta_dK estimates,
%                    overall quality flag

    arguments
        mic_t (:, 1) double
        mic_p (:, 1) double
        freq_table table
        opts.band_halfwidth_oct = 0.5   % half-width in octaves around each mode
        opts.min_cycles = 3             % minimum cycles required for fit
        opts.fit_start_pct = 10         % start fit from X% past peak envelope
        opts.plot_debug = false
    end

    n_modes = height(freq_table);
    dt = mean(diff(mic_t));
    fs = 1 / dt;
    T = mic_t(end) - mic_t(1);
    n_total = numel(mic_t);

    % Preallocate
    mode_freq = freq_table.freq_hz;
    tau_s = NaN(n_modes, 1);
    decay_rate = NaN(n_modes, 1);
    Q_est = NaN(n_modes, 1);
    r_sq = NaN(n_modes, 1);
    n_cycles = NaN(n_modes, 1);
    fit_valid = false(n_modes, 1);

    for m = 1:n_modes
        f0 = mode_freq(m);
        if isnan(f0) || f0 <= 0
            continue;
        end

        % --- Bandpass filter around modal frequency ---
        f_low = f0 / (2 ^ opts.band_halfwidth_oct);
        f_high = f0 * (2 ^ opts.band_halfwidth_oct);

        % Normalized cutoff
        wn_low = f_low / (fs / 2);
        wn_high = f_high / (fs / 2);

        % Clamp to valid range
        wn_low = max(wn_low, 0.001);
        wn_high = min(wn_high, 0.999);

        if wn_high <= wn_low
            continue;
        end

        % Bandpass around the mode. Prefer Signal Processing Toolbox when
        % available; otherwise use a deterministic FFT-domain mask.
        try
            if exist('butter', 'file') && exist('filtfilt', 'file')
                [b, a] = butter(2, [wn_low, wn_high], 'bandpass');
                filt_p = filtfilt(b, a, mic_p);
            else
                filt_p = fft_bandpass(mic_p, fs, f_low, f_high);
            end
        catch
            continue;
        end

        % --- Envelope via analytic signal (Hilbert transform) ---
        if exist('hilbert', 'file')
            envelope = abs(hilbert(filt_p));
        else
            envelope = analytic_envelope_fft(filt_p);
        end

        % --- Find peak and fit region ---
        [peak_val, peak_idx] = max(envelope);
        if peak_val <= 0 || peak_idx >= n_total - 10
            continue;
        end

        % Start fit from X% past peak to avoid near-field transients
        fit_start_pct = opts.fit_start_pct / 100;
        start_thresh = peak_val * (1 - fit_start_pct);

        % Find first index after peak where envelope drops below start_thresh
        fit_start_idx = peak_idx;
        for i = peak_idx:n_total
            if envelope(i) <= start_thresh
                fit_start_idx = i;
                break;
            end
        end

        % End fit where envelope drops below 5% of peak (or end of signal)
        end_thresh = peak_val * 0.05;
        fit_end_idx = n_total;
        for i = fit_start_idx:n_total
            if envelope(i) <= end_thresh
                fit_end_idx = i;
                break;
            end
        end

        if fit_end_idx - fit_start_idx < 5
            continue;  % too few points for fit
        end

        t_fit = mic_t(fit_start_idx:fit_end_idx);
        env_fit = envelope(fit_start_idx:fit_end_idx);
        t_fit_shifted = t_fit - t_fit(1);

        % --- Exponential fit: env = A * exp(-t / tau) ---
        % Linearize: log(env) = log(A) - t/tau
        valid_mask = env_fit > 0;
        t_lin = t_fit_shifted(valid_mask);
        y_lin = log(env_fit(valid_mask));

        if numel(t_lin) < 4
            continue;
        end

        % Linear regression on log-space
        X = [ones(numel(t_lin), 1), t_lin];
        coef = X \ y_lin;
        log_A = coef(1);
        neg_inv_tau = coef(2);

        if neg_inv_tau >= 0
            continue;  % no decay or growing
        end

        tau = -1 / neg_inv_tau;
        A_fit = exp(log_A);

        % R-squared
        env_pred = A_fit * exp(-t_lin / tau);
        ss_res = sum((exp(y_lin) - env_pred).^2);
        ss_tot = sum((exp(y_lin) - mean(exp(y_lin))).^2);
        if ss_tot > 0
            r_sq(m) = 1 - ss_res / ss_tot;
        end

        tau_s(m) = tau;
        decay_rate(m) = 1 / tau;
        Q_est(m) = pi * f0 * tau;
        n_cycles(m) = f0 * T;
        fit_valid(m) = (n_cycles(m) >= opts.min_cycles);
    end

    % --- Build output table ---
    decay_table = table((1:n_modes)', mode_freq, tau_s, decay_rate, Q_est, ...
        r_sq, n_cycles, fit_valid, ...
        'VariableNames', {'mode', 'freq_hz', 'tau_s', 'decay_rate_1ps', ...
        'Q_estimate', 'r_squared', 'n_cycles', 'fit_valid'});

    % --- Estimate Rayleigh damping parameters ---
    % Pick two modes with best fits for alpha/beta estimation
    valid_idx = find(fit_valid & r_sq > 0.7);
    summary = struct();
    summary.alpha_dM_est = NaN;
    summary.beta_dK_est = NaN;
    summary.rayleigh_valid = false;

    if numel(valid_idx) >= 2
        % Choose lowest valid mode and highest valid mode
        lo = valid_idx(1);
        hi = valid_idx(end);
        if lo < hi
            omega_lo = 2 * pi * mode_freq(lo);
            omega_hi = 2 * pi * mode_freq(hi);
            zeta_lo = 1 / (2 * Q_est(lo));
            zeta_hi = 1 / (2 * Q_est(hi));

            % Solve: [1/(2*omega_lo), omega_lo/2] * [alpha; beta] = [zeta_lo]
            %        [1/(2*omega_hi), omega_hi/2] * [alpha; beta] = [zeta_hi]
            A_mat = [1/(2*omega_lo), omega_lo/2; 1/(2*omega_hi), omega_hi/2];
            b_vec = [zeta_lo; zeta_hi];
            sol = A_mat \ b_vec;
            summary.alpha_dM_est = sol(1);
            summary.beta_dK_est = sol(2);
            summary.rayleigh_valid = (sol(1) > 0 && sol(2) > 0);
        end
    end

    summary.n_modes = n_modes;
    summary.n_valid_fits = sum(fit_valid);
    summary.n_good_fits = sum(fit_valid & r_sq > 0.7);
    summary.overall_quality = 'insufficient_data';
    if summary.n_good_fits >= 3
        summary.overall_quality = 'good';
    elseif summary.n_valid_fits >= 2
        summary.overall_quality = 'acceptable';
    end

    % --- Debug plot ---
    if opts.plot_debug && n_modes > 0
        figure('Name', 'Modal Decay Analysis');
        n_cols = min(3, n_modes);
        n_rows = ceil(n_modes / n_cols);
        for m = 1:n_modes
            subplot(n_rows, n_cols, m);
            f0 = mode_freq(m);
            % Re-filter for plotting
            f_low = f0 / (2 ^ 0.5);
            f_high = f0 * (2 ^ 0.5);
            wn_low = max(f_low / (fs/2), 0.001);
            wn_high = min(f_high / (fs/2), 0.999);
            try
                if exist('butter', 'file') && exist('filtfilt', 'file')
                    [b, a] = butter(2, [wn_low, wn_high], 'bandpass');
                    p_filt = filtfilt(b, a, mic_p);
                else
                    p_filt = fft_bandpass(mic_p, fs, f_low, f_high);
                end
                if exist('hilbert', 'file')
                    env = abs(hilbert(p_filt));
                else
                    env = analytic_envelope_fft(p_filt);
                end
                plot(mic_t, p_filt, 'b'); hold on;
                plot(mic_t, env, 'r', 'LineWidth', 1.5);
                if isfinite(tau_s(m))
                    t_line = linspace(mic_t(1), mic_t(end), 500);
                    [~, pk] = max(env);
                    plot(t_line, max(env)*exp(-(t_line-mic_t(pk))/tau_s(m)), 'k--');
                end
                title(sprintf('Mode %d: %.1f Hz, \\tau=%.3fs, R^2=%.2f', m, f0, tau_s(m), r_sq(m)));
                xlabel('t (s)'); ylabel('p (Pa)');
            catch
            end
        end
    end
end

function y_band = fft_bandpass(y, fs, f_low, f_high)
    y = y(:) - mean(y(:), 'omitnan');
    n = numel(y);
    Y = fft(y);
    freqs = (0:n-1).' * fs / n;
    neg_freqs = freqs - fs;
    mask = ((freqs >= f_low) & (freqs <= f_high)) | ...
        ((abs(neg_freqs) >= f_low) & (abs(neg_freqs) <= f_high));
    y_band = real(ifft(Y .* mask));
end

function envelope = analytic_envelope_fft(y)
    y = y(:);
    n = numel(y);
    Y = fft(y);
    h = zeros(n, 1);
    if mod(n, 2) == 0
        h(1) = 1;
        h(n/2 + 1) = 1;
        h(2:n/2) = 2;
    else
        h(1) = 1;
        h(2:(n+1)/2) = 2;
    end
    envelope = abs(ifft(Y .* h));
end
