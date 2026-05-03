function plot_modal_acoustic_coupling(freq_hz, amp_pa, coupling, output_path)
%PLOT_MODAL_ACOUSTIC_COUPLING Plot acoustic spectrum with overlaid structural modal lines.
%   plot_modal_acoustic_coupling(freq_hz, amp_pa, coupling, output_path)
%
%   coupling: table from compute_modal_acoustic_coupling
%   output_path: .png file path

    arguments
        freq_hz (:, 1) double
        amp_pa (:, 1) double
        coupling table
        output_path (1, :) char
    end

    fig = figure("Visible", "off", "Position", [100, 100, 900, 500]);
    ax = axes(fig);

    % Acoustic spectrum
    plot(ax, freq_hz, amp_pa, "Color", "#E76F51", "LineWidth", 1.0);
    xlabel(ax, "Frequency (Hz)");
    ylabel(ax, "Amplitude (Pa)");
    title(ax, "Modal-Acoustic Coupling");
    grid(ax, "on");
    hold(ax, "on");

    % Overlay structural mode lines
    if istable(coupling) && height(coupling) > 0 && ...
            all(ismember({'mode_freq_hz', 'peak_amp_pa', 'match_quality'}, coupling.Properties.VariableNames))

        qual_colors = struct( ...
            "excellent", "#2D6A4F", "good", "#4A90D9", ...
            "fair", "#D4A017", "poor", "#C0392B");

        for i = 1:height(coupling)
            mf = coupling.mode_freq_hz(i);
            pa = coupling.peak_amp_pa(i);
            qual_str = coupling.match_quality{i};
            if ischar(qual_str) || isstring(qual_str)
                qual_str = char(qual_str);
            end
            if isfield(qual_colors, qual_str)
                c = qual_colors.(qual_str);
            else
                c = "#888888";
            end

            % Vertical line at mode frequency
            xline(ax, mf, "--", "Color", c, "LineWidth", 1.5);

            % Diamond marker at peak amplitude
            plot(ax, mf, pa, "d", "Color", c, "MarkerSize", 8, ...
                "MarkerFaceColor", c, "DisplayName", sprintf("Mode %d (%s)", ...
                coupling.mode(i), qual_str));
        end
    end

    xlim(ax, [0, 2000]);
    legend(ax, "Location", "northeast");

    exportgraphics(fig, output_path, "Resolution", 150);
    close(fig);
end
