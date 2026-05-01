function configure_plot_defaults()
%CONFIGURE_PLOT_DEFAULTS Set stable plotting defaults.

    persistent configured
    if ~isempty(configured) && configured
        return;
    end

    set(groot, "defaultAxesFontName", "Helvetica");
    set(groot, "defaultTextFontName", "Helvetica");
    set(groot, "defaultAxesFontSize", 10);
    set(groot, "defaultLineLineWidth", 1.2);
    configured = true;
end
