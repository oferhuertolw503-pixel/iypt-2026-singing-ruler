function plot_series(t, y, output_path, title_text, ylabel_text, color_hex)
%PLOT_SERIES Plot a single time series.

    arguments
        t (:, 1) double
        y (:, 1) double
        output_path (1, :) char
        title_text (1, :) char
        ylabel_text (1, :) char
        color_hex (1, :) char
    end

    fig = figure("Visible", "off", "Position", [100, 100, 800, 450]);
    ax = axes(fig);
    plot(ax, t, y, "Color", color_hex, "LineWidth", 1.0);
    xlabel(ax, "Time (s)");
    ylabel(ax, ylabel_text);
    title(ax, title_text);
    grid(ax, "on");
    exportgraphics(fig, output_path, "Resolution", 150);
    close(fig);
end
