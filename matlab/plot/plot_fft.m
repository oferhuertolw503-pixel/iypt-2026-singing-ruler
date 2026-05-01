function plot_fft(t, y, output_path, title_text, ylabel_text, max_freq_hz)
%PLOT_FFT Plot normalized FFT amplitude.

    arguments
        t (:, 1) double
        y (:, 1) double
        output_path (1, :) char
        title_text (1, :) char
        ylabel_text (1, :) char
        max_freq_hz (1, 1) double
    end

    if numel(t) < 4
        return;
    end
    dt = mean(diff(t));
    if ~(isfinite(dt) && dt > 0)
        return;
    end

    y0 = y - mean(y);
    yf = fft(y0);
    n = numel(y0);
    half_n = floor(n / 2) + 1;
    amp = abs(yf(1:half_n));
    xf = (0:half_n - 1).' / (n * dt);
    if max(amp) > 0
        amp = amp / max(amp);
    end

    fig = figure("Visible", "off", "Position", [100, 100, 800, 450]);
    ax = axes(fig);
    plot(ax, xf, amp, "Color", "#E76F51", "LineWidth", 1.0);
    xlabel(ax, "Frequency (Hz)");
    ylabel(ax, ylabel_text);
    title(ax, title_text);
    xlim(ax, [0, min(max_freq_hz, max(xf))]);
    grid(ax, "on");
    exportgraphics(fig, output_path, "Resolution", 150);
    close(fig);
end
