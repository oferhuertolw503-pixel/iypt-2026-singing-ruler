function plot_mode_shapes(mode_table, output_dir)
%PLOT_MODE_SHAPES Plot normalized mode shapes.

    arguments
        mode_table table
        output_dir (1, :) char
    end

    x = mode_table.x_over_L;
    mode_names = mode_table.Properties.VariableNames(2:end);

    for k = 1:numel(mode_names)
        v = mode_table.(mode_names{k});
        if all(isnan(v))
            continue;
        end

        vmax = max(abs(v), [], "omitnan");
        if isfinite(vmax) && vmax > 0
            v = v / vmax;
        end

        fig = figure("Visible", "off", "Position", [100, 100, 800, 220]);
        ax = axes(fig);
        plot(ax, x, v, "Color", "#111111", "LineWidth", 1.5);
        yline(ax, 0.0, "Color", "#9AA0A6", "LineWidth", 0.8);
        xlabel(ax, "Normalized length x / L");
        ylabel(ax, "Normalized displacement w");
        title(ax, sprintf("Mode %d shape", k));
        ylim(ax, [-1.2, 1.2]);
        grid(ax, "on");
        exportgraphics(fig, fullfile(output_dir, sprintf("pgmode_mode%02d.png", k)), "Resolution", 150);
        close(fig);
    end
end
