function plot_frequency_bar(freq_table, output_path)
%PLOT_FREQUENCY_BAR Plot eigenfrequency bars.

    arguments
        freq_table table
        output_path (1, :) char
    end

    fig = figure("Visible", "off", "Position", [100, 100, 800, 450]);
    ax = axes(fig);
    bar(ax, freq_table.mode, freq_table.freq_hz, "FaceColor", "#2D6A4F");
    xlabel(ax, "Mode index");
    ylabel(ax, "Frequency (Hz)");
    title(ax, "Eigenfrequencies");
    grid(ax, "on");
    ax.XTick = freq_table.mode;
    exportgraphics(fig, output_path, "Resolution", 150);
    close(fig);
end
