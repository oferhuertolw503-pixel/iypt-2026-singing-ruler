function plot_mode_shapes_composite(mode_table, output_path)
%PLOT_MODE_SHAPES_COMPOSITE Overlay all mode shapes in a single figure.
%   plot_mode_shapes_composite(mode_table, output_path)
%
%   mode_table: from mode_shapes.csv (columns: x_over_L, w_mode1, w_mode2, ...)
%   output_path: .png file path

    arguments
        mode_table table
        output_path (1, :) char
    end

    colors = {"#1D3557", "#E76F51", "#2D6A4F", "#4A90D9", "#D4A017", "#7A3E9D", ...
              "#C0392B", "#16A085", "#F39C12", "#2980B9"};

    x = mode_table.x_over_L;
    mode_names = mode_table.Properties.VariableNames;
    mode_names = mode_names(~strcmp(mode_names, 'x_over_L'));
    n_modes = numel(mode_names);

    fig = figure("Visible", "off", "Position", [100, 100, 900, 500]);
    ax = axes(fig);
    hold(ax, "on");

    for k = 1:n_modes
        v = mode_table.(mode_names{k});
        if all(isnan(v))
            continue;
        end
        c = colors{min(k, numel(colors))};
        plot(ax, x, v, "Color", c, "LineWidth", 1.5, ...
            "DisplayName", sprintf("Mode %d", k));
    end

    yline(ax, 0.0, "Color", "#9AA0A6", "LineWidth", 0.8);
    xlabel(ax, "Normalized length x / L");
    ylabel(ax, "Normalized displacement w");
    title(ax, "Mode Shapes (all modes)");
    ylim(ax, [-1.2, 1.2]);
    grid(ax, "on");
    if n_modes > 1
        legend(ax, "Location", "best");
    end

    exportgraphics(fig, output_path, "Resolution", 150);
    close(fig);
end
