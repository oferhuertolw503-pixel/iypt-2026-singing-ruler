function [freq_hz, amp] = compute_single_sided_fft(t, y)
%COMPUTE_SINGLE_SIDED_FFT Return single-sided FFT amplitude with physical units.
    t = double(t(:));
    y = double(y(:));

    if numel(t) < 4
        freq_hz = zeros(0, 1);
        amp = zeros(0, 1);
        return;
    end

    dt = mean(diff(t));
    if ~(isfinite(dt) && dt > 0)
        freq_hz = zeros(0, 1);
        amp = zeros(0, 1);
        return;
    end

    y0 = y - mean(y);
    n = numel(y0);
    yf = fft(y0);
    half_n = floor(n / 2) + 1;
    freq_hz = (0:half_n - 1).' / (n * dt);
    amp = abs(yf(1:half_n)) / n;
    if numel(amp) > 2
        amp(2:end-1) = 2 * amp(2:end-1);
    end
end