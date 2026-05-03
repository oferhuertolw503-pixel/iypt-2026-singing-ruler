function [freq_hz, amp, meta] = compute_single_sided_fft(t, y, opts)
%COMPUTE_SINGLE_SIDED_FFT Return single-sided FFT amplitude with physical units.
%   [freq_hz, amp] = compute_single_sided_fft(t, y)
%   [freq_hz, amp, meta] = compute_single_sided_fft(t, y, opts)
%
%   Optional opts struct fields (defaults):
%     remove_mean        (true)      — remove DC before FFT
%     window             ('hann')    — window type: 'hann', 'none'
%     zero_padding_factor (4)        — pad signal to nfft = factor * n
%
%   meta: struct with nfft, fs, dt, freq_resolution_hz, window_type, zero_padding_factor

    arguments
        t (:, 1) double
        y (:, 1) double
        opts.remove_mean (1, 1) logical = true
        opts.window (1, 1) string = "hann"
        opts.zero_padding_factor (1, 1) double {mustBePositive, mustBeInteger} = 4
    end

    t = double(t(:));
    y = double(y(:));

    n = numel(y);
    if n < 4
        freq_hz = zeros(0, 1);
        amp = zeros(0, 1);
        meta = struct('nfft', 0, 'fs', NaN, 'dt', NaN, 'freq_resolution_hz', NaN, ...
            'window_type', "", 'zero_padding_factor', 0);
        return;
    end

    dt = mean(diff(t));
    if ~(isfinite(dt) && dt > 0)
        freq_hz = zeros(0, 1);
        amp = zeros(0, 1);
        meta = struct('nfft', 0, 'fs', NaN, 'dt', NaN, 'freq_resolution_hz', NaN, ...
            'window_type', "", 'zero_padding_factor', 0);
        return;
    end
    fs = 1 / dt;

    % Remove DC
    if opts.remove_mean
        y = y - mean(y, 'omitnan');
    end

    % Apply window
    win = ones(n, 1);
    window_type = "none";
    if opts.window == "hann"
        win = 0.5 - 0.5 * cos(2 * pi * (0:n - 1).' / (n - 1));
        window_type = "hann_manual";
    end

    yw = y .* win;
    win_power = sum(win);

    % Zero-padding
    nfft = max(n * opts.zero_padding_factor, n);
    nfft = 2^nextpow2(nfft);  % power-of-two for efficiency

    yf = fft(yw, nfft);
    half_n = floor(nfft / 2) + 1;
    freq_hz = (0:half_n - 1).' * fs / nfft;

    % Amplitude: single-sided, compensated for window power
    amp = abs(yf(1:half_n)) / win_power;
    if numel(amp) > 2
        amp(2:end - 1) = 2 * amp(2:end - 1);
    end

    freq_resolution_hz = fs / nfft;

    meta = struct( ...
        'nfft', nfft, ...
        'fs', fs, ...
        'dt', dt, ...
        'freq_resolution_hz', freq_resolution_hz, ...
        'window_type', window_type, ...
        'zero_padding_factor', opts.zero_padding_factor);
end
