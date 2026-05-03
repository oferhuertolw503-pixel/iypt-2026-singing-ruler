function plot_band_decay_envelope(frame_times, band_energy, bands, output_path)
%PLOT_BAND_DECAY_ENVELOPE Plot band energy envelopes over time.
%   plot_band_decay_envelope(frame_times, band_energy, bands, output_path)
%
%   frame_times: Nx1 time stamps for each STFT frame
%   band_energy: Nx4 band energy matrix
%   bands:       Kx3 [band_id, f_low, f_high; ...]
%   output_path: .png file path

    arguments
        frame_times (:, 1) double
        band_energy (:, :) double
        bands (:, 3) double
        output_path (1, :) char
    end

    fig = figure("Visible", "off", "Position", [100, 100, 900, 600]);
    colors = {"#2D6A4F", "#4A90D9", "#D4A017", "#C0392B"};

    for b = 1:size(bands, 1)
        ax = subplot(4, 1, b, "Parent", fig);
        env = band_energy(:, b);
        if max(env) > 0
            env = env / max(env);
        end
        plot(ax, frame_times, env, "Color", colors{b}, "LineWidth", 1.5);
        ylabel(ax, "Norm. energy");
        title(ax, sprintf("Band %d: %.0f-%.0f Hz", bands(b, 1), bands(b, 2), bands(b, 3)));

        % 10% threshold line
        yline(ax, 0.10, "--", "Color", "#888888", "LineWidth", 0.8);
        grid(ax, "on");
        xlim(ax, [min(frame_times), max(frame_times)]);

        if b < size(bands, 1)
            set(ax, 'XTickLabel', {});
        else
            xlabel(ax, "Time (s)");
        end
    end

    sgtitle(fig, "Band Energy Envelopes");

    exportgraphics(fig, output_path, "Resolution", 150);
    close(fig);
end
