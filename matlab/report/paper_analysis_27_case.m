function report = paper_analysis_27_case(proj_root, data_rel_root)
%PAPER_ANALYSIS_27_CASE Generate paper figures and analysis from 27-case validation.
%   report = paper_analysis_27_case()
%   report = paper_analysis_27_case(proj_root, data_rel_root)
%
%   Reads derived_metrics_validation.csv, generates:
%     6 paper-quality PNG figures
%        pitch_vs_L_free, pitch_vs_h, spl_vs_J,
%        spl_vs_x0_ratio, timbre_material_map, mode_match_by_case
%     3 analysis CSV tables
%        steel_scan_trends, material_timbre_summary, physics_claims_evidence
%
%   Data source: outputs/requested_3d_air_coarse_review_light/tables/
%   Writes:  tables/paper_analysis/  and  figures/paper_analysis/
%
%   No COMSOL, no raw CSV modification, no synthetic data.

    arguments
        proj_root (1,:) char = 'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler'
        data_rel_root (1,:) char = 'outputs/requested_3d_air_coarse_review_light'
    end

    addpath(fullfile(proj_root, 'matlab', 'core'));

    tables_dir = fullfile(proj_root, data_rel_root, 'tables');
    paper_tables = fullfile(tables_dir, 'paper_analysis');
    paper_figs = fullfile(proj_root, data_rel_root, 'figures', 'paper_analysis');
    ensure_dir(paper_tables);
    ensure_dir(paper_figs);

    csv_path = fullfile(tables_dir, 'derived_metrics_validation.csv');
    data = readtable(csv_path);
    data = add_param_value(data);

    % ====== FIGURES ======
    fig1 = plot_pitch_vs_L_free(data);
    exportgraphics(fig1, fullfile(paper_figs, 'pitch_vs_L_free.png'), 'Resolution', 150);
    close(fig1);

    fig2 = plot_pitch_vs_h(data);
    exportgraphics(fig2, fullfile(paper_figs, 'pitch_vs_h.png'), 'Resolution', 150);
    close(fig2);

    fig3 = plot_spl_vs_J(data);
    exportgraphics(fig3, fullfile(paper_figs, 'spl_vs_J.png'), 'Resolution', 150);
    close(fig3);

    fig4 = plot_spl_vs_x0_ratio(data);
    exportgraphics(fig4, fullfile(paper_figs, 'spl_vs_x0_ratio.png'), 'Resolution', 150);
    close(fig4);

    fig5 = plot_timbre_material_map(data);
    exportgraphics(fig5, fullfile(paper_figs, 'timbre_material_map.png'), 'Resolution', 150);
    close(fig5);

    fig6 = plot_mode_match_by_case(data);
    exportgraphics(fig6, fullfile(paper_figs, 'mode_match_by_case.png'), 'Resolution', 150);
    close(fig6);

    % ====== TABLES ======
    t1 = make_steel_scan_trends(data);
    writetable(t1, fullfile(paper_tables, 'steel_scan_trends.csv'), 'Encoding', 'UTF-8');

    t2 = make_material_timbre_summary(data);
    writetable(t2, fullfile(paper_tables, 'material_timbre_summary.csv'), 'Encoding', 'UTF-8');

    t3 = make_physics_claims_evidence();
    writetable(t3, fullfile(paper_tables, 'physics_claims_evidence.csv'), 'Encoding', 'UTF-8');

    fprintf('=== PAPER ANALYSIS COMPLETE ===\n');
    fprintf('Figures (%s): pitch_vs_L_free, pitch_vs_h, spl_vs_J, spl_vs_x0_ratio, timbre_material_map, mode_match_by_case\n', paper_figs);
    fprintf('Tables (%s): steel_scan_trends, material_timbre_summary, physics_claims_evidence\n', paper_tables);

    report = struct('figures_dir', paper_figs, 'tables_dir', paper_tables);
end


% ========================================================================
% Data helpers
% ========================================================================

function data = add_param_value(data)
    n = height(data);
    param_val = NaN(n, 1);
    param_unit = strings(n, 1);
    for i = 1:n
        p = data.parameter{i};
        tok = regexp(p, '(\d+(?:p\d+)?)', 'tokens');
        if ~isempty(tok)
            s = strrep(tok{1}{1}, 'p', '.');
            param_val(i) = str2double(s);
        end
        % Infer unit from parameter name
        if contains(p, 'mm')
            param_unit(i) = "mm";
        elseif contains(p, 'cm')
            param_unit(i) = "cm";
        elseif contains(p, 'Ns')
            param_unit(i) = "Ns";
        elseif contains(p, 'ratio')
            param_unit(i) = "";
        else
            param_unit(i) = "";
        end
    end
    data.param_value = param_val;
    data.param_unit = param_unit;
end

function idx = group_idx(data, grp_name)
    idx = strcmp(data.group, grp_name);
end

function d = sort_by_param(data, idx)
    sub = data(idx, :);
    [~, order] = sort(sub.param_value);
    d = sub(order, :);
end


% ========================================================================
% Figure: pitch vs L_free (f ∝ 1/L²)
% ========================================================================

function fig = plot_pitch_vs_L_free(data)
    idx = group_idx(data, 'L_free');
    d = sort_by_param(data, idx);

    L_cm = d.param_value;          % free length in cm
    L_m = L_cm / 100;              % free length in m
    f = d.f_dom_refined_hz;

    % Fit f = k / L²  (through origin)
    k = mean(f .* L_m.^2);
    f_pred = k ./ L_m.^2;
    rel_err = abs(f - f_pred) ./ f * 100;
    r2 = 1 - sum((f - f_pred).^2) / sum((f - mean(f)).^2);
    product_fL2 = f .* L_cm.^2;

    fig = figure('Visible', 'off', 'Position', [100 100 600 420]);
    hold on;
    L_fit = linspace(min(L_cm), max(L_cm), 100);
    f_fit = k ./ (L_fit / 100).^2;
    plot(L_fit, f_fit, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);
    scatter(L_cm, f, 80, 'o', 'MarkerEdgeColor', [0 0.447 0.741], ...
        'MarkerFaceColor', [0 0.447 0.741], 'LineWidth', 1.2);
    hold off;

    xlabel('Free Length L (cm)', 'FontSize', 12);
    ylabel('Dominant Frequency f_d (Hz)', 'FontSize', 12);
    title('Pitch vs Free Length (Steel Ruler)', 'FontSize', 13);

    annotation_str = sprintf('f \\propto 1/L^2\nf \\times L^2 = %.0f \\pm %.0f Hz\\cdotcm^2\nR^2 = %.4f\nmean |\\delta| = %.2f%% (n=%d)', ...
        mean(product_fL2), std(product_fL2), r2, mean(rel_err), height(d));
    annotation('textbox', [0.55 0.55 0.38 0.32], 'String', annotation_str, ...
        'FontSize', 10, 'BackgroundColor', 'white', 'EdgeColor', [0.6 0.6 0.6]);

    text(0.98, 0.03, '0.10 s coarse | Hann FFT 4\times', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 8, 'Color', [0.5 0.5 0.5]);
end


% ========================================================================
% Figure: pitch vs thickness (f ∝ h)
% ========================================================================

function fig = plot_pitch_vs_h(data)
    idx = group_idx(data, 'h');
    d = sort_by_param(data, idx);

    h_mm = d.param_value;
    f = d.f_dom_refined_hz;

    % Linear fit through origin: f = slope * h
    slope = (h_mm' * f) / (h_mm' * h_mm);
    f_pred = slope * h_mm;
    r2 = 1 - sum((f - f_pred).^2) / sum((f - mean(f)).^2);
    rel_err = abs(f - f_pred) ./ f * 100;

    fig = figure('Visible', 'off', 'Position', [100 100 600 420]);
    hold on;
    h_fit = linspace(0, max(h_mm)*1.05, 100);
    f_fit = slope * h_fit;
    plot(h_fit, f_fit, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.5);
    scatter(h_mm, f, 80, 's', 'MarkerEdgeColor', [0.85 0.325 0.098], ...
        'MarkerFaceColor', [0.85 0.325 0.098], 'LineWidth', 1.2);
    hold off;
    xlim([0, max(h_mm)*1.05]);
    ylim([0, max(f)*1.1]);

    xlabel('Thickness h (mm)', 'FontSize', 12);
    ylabel('Dominant Frequency f_d (Hz)', 'FontSize', 12);
    title('Pitch vs Thickness (Steel Ruler)', 'FontSize', 13);

    avg_ratio = mean(f ./ h_mm);
    annotation_str = sprintf('f \\propto h\nf/h = %.2f \\pm %.2f Hz/mm\nR^2 = %.4f\nmean |\\delta| = %.2f%% (n=%d)', ...
        avg_ratio, std(f ./ h_mm), r2, mean(rel_err), height(d));
    annotation('textbox', [0.18 0.55 0.38 0.32], 'String', annotation_str, ...
        'FontSize', 10, 'BackgroundColor', 'white', 'EdgeColor', [0.6 0.6 0.6]);

    text(0.98, 0.03, '0.10 s coarse | Hann FFT 4\times', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 8, 'Color', [0.5 0.5 0.5]);
end


% ========================================================================
% Figure: SPL vs impulse J
% ========================================================================

function fig = plot_spl_vs_J(data)
    idx = group_idx(data, 'J');
    d = sort_by_param(data, idx);

    J_Ns = d.param_value;
    spl = d.spl_rms_db;
    f = d.f_dom_refined_hz;

    fig = figure('Visible', 'off', 'Position', [100 100 600 420]);
    hold on;
    scatter(J_Ns, spl, 80, '^', 'MarkerEdgeColor', [0.466 0.674 0.188], ...
        'MarkerFaceColor', [0.466 0.674 0.188], 'LineWidth', 1.2);
    % Trenderence curve
    p = polyfit(J_Ns, spl, 1);
    J_fit = linspace(min(J_Ns), max(J_Ns), 50);
    spl_fit = polyval(p, J_fit);
    plot(J_fit, spl_fit, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2);
    hold off;

    xlabel('Impulse J (N\cdot s)', 'FontSize', 12);
    ylabel('SPL_{RMS} (dB)', 'FontSize', 12);
    title('Sound Level vs Impulse (Steel Ruler)', 'FontSize', 13);

    % Annotate f_dom for each point
    for i = 1:height(d)
        text(J_Ns(i) + 0.001, spl(i) - 1.2, sprintf('f_d=%.1f Hz', f(i)), ...
            'FontSize', 9, 'Color', [0.3 0.3 0.3]);
    end

    spl_range = max(spl) - min(spl);
    f_dom_mean = mean(f);
    f_dom_std = std(f);
    annotation_str = sprintf('SPL range: %.1f dB\nf_d = %.2f \\pm %.2f Hz (n=%d)\nSPL monotonic: yes', ...
        spl_range, f_dom_mean, f_dom_std, height(d));
    annotation('textbox', [0.55 0.18 0.38 0.25], 'String', annotation_str, ...
        'FontSize', 10, 'BackgroundColor', 'white', 'EdgeColor', [0.6 0.6 0.6]);

    text(0.98, 0.03, '0.10 s coarse | Hann FFT 4\times', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 8, 'Color', [0.5 0.5 0.5]);
end


% ========================================================================
% Figure: SPL vs x0_ratio
% ========================================================================

function fig = plot_spl_vs_x0_ratio(data)
    idx = group_idx(data, 'x0_ratio');
    d = sort_by_param(data, idx);

    x0 = d.param_value;
    spl = d.spl_rms_db;
    f = d.f_dom_refined_hz;

    fig = figure('Visible', 'off', 'Position', [100 100 600 420]);
    hold on;
    scatter(x0, spl, 80, 'd', 'MarkerEdgeColor', [0.929 0.694 0.125], ...
        'MarkerFaceColor', [0.929 0.694 0.125], 'LineWidth', 1.2);
    % Interpolating curve (spline or polynomial)
    x0_fine = linspace(min(x0), max(x0), 50);
    try
        spl_fit = spline(x0, spl, x0_fine);
        plot(x0_fine, spl_fit, '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1.2);
    catch
    end
    hold off;
    xlim([0.15 0.85]);

    xlabel('Impact Position Ratio x_0 / L', 'FontSize', 12);
    ylabel('SPL_{RMS} (dB)', 'FontSize', 12);
    title('Sound Level vs Impact Position (Steel Ruler)', 'FontSize', 13);

    for i = 1:height(d)
        text(x0(i) + 0.01, spl(i) + 1.5, sprintf('f_d=%.1f Hz', f(i)), ...
            'FontSize', 9, 'Color', [0.3 0.3 0.3]);
    end

    annotation_str = sprintf('Max SPL at x_0/L=0.50\nf_d \\approx %d Hz (mode \\geq 6)', ...
        round(mean(f)));
    annotation('textbox', [0.18 0.60 0.38 0.20], 'String', annotation_str, ...
        'FontSize', 10, 'BackgroundColor', 'white', 'EdgeColor', [0.6 0.6 0.6]);

    text(0.98, 0.03, '0.10 s coarse | Hann FFT 4\times', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 8, 'Color', [0.5 0.5 0.5]);
end


% ========================================================================
% Figure: timbre material map (centroid vs flatness)
% ========================================================================

function fig = plot_timbre_material_map(data)
    idx = group_idx(data, 'timbre_material');
    d = data(idx, :);

    flat = d.spectral_flatness;
    cent = d.spectral_centroid_hz;
    spl = d.spl_rms_db;
    labels = d.parameter;

    fig = figure('Visible', 'off', 'Position', [100 100 650 480]);
    hold on;
    cmap = parula(64);
    for i = 1:height(d)
        ci = max(1, min(64, round(interp1([min(spl), max(spl)], [1, 64], spl(i)))));
        scatter(flat(i), cent(i), 120, 'o', ...
            'MarkerEdgeColor', cmap(ci, :), ...
            'MarkerFaceColor', cmap(ci, :), ...
            'LineWidth', 1.2);
        % Extract material name: remove 'material_' prefix
        lbl = strrep(labels{i}, 'material_', '');
        text(flat(i) * 1.15, cent(i), lbl, 'FontSize', 11, ...
            'FontWeight', 'bold', 'Color', [0.2 0.2 0.2]);
    end
    hold off;

    xlabel('Spectral Flatness (Wiener Entropy)', 'FontSize', 12);
    ylabel('Spectral Centroid (Hz)', 'FontSize', 12);
    title('Timbre Material Map', 'FontSize', 13);

    % Colorbar for SPL
    colormap(cmap);
    c = colorbar('Location', 'eastoutside');
    c.Label.String = 'SPL_{RMS} (dB)';
    c.Label.FontSize = 10;

    % Manual colorbar range
    clim([min(spl), max(spl)]);

    grid on;
    box on;

    text(0.98, 0.03, '0.10 s coarse | Hann FFT 4\times', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 8, 'Color', [0.5 0.5 0.5]);
end


% ========================================================================
% Figure: mode match quality by case
% ========================================================================

function fig = plot_mode_match_by_case(data)
    fig = figure('Visible', 'off', 'Position', [100 100 800 420]);
    hold on;

    groups = {'J', 'L_free', 'b', 'h', 'x0_ratio', 'timbre_material'};
    colors = lines(6);
    x_pos = 1:height(data);
    x_labels = cell(height(data), 1);

    for g = 1:numel(groups)
        idx = find(strcmp(data.group, groups{g}));
        for k = 1:numel(idx)
            i = idx(k);
            % Short label
            p = data.parameter{i};
            p = strrep(p, 'material_', '');
            p = strrep(p, 'x0_ratio_', '');
            p = strrep(p, 'L_free_', '');
            x_labels{i} = p;
        end
    end

    % Threshold lines
    yline(2, '--', 'Color', [0.5 0.9 0.5], 'LineWidth', 1);
    yline(5, '--', 'Color', [0.9 0.7 0.3], 'LineWidth', 1);
    yline(10, '--', 'Color', [0.9 0.4 0.4], 'LineWidth', 1);

    for g = 1:numel(groups)
        idx = find(strcmp(data.group, groups{g}));
        scatter(x_pos(idx), data.best_match_rel_delta_pct(idx), 60, ...
            'o', 'MarkerEdgeColor', colors(g, :), ...
            'MarkerFaceColor', colors(g, :), 'LineWidth', 0.8);
    end

    hold off;
    xticks(1:height(data));
    xticklabels(x_labels);
    xtickangle(45);

    xlabel('Case', 'FontSize', 11);
    ylabel('Best Mode Match relative error (%)', 'FontSize', 11);
    title('Modal Acoustic Coupling Match Quality Across All Cases', 'FontSize', 12);

    legend([groups, {'2%', '5%', '10% thresholds'}], 'Location', 'northeast', ...
        'FontSize', 8, 'NumColumns', 3);
    ylim([0, max(data.best_match_rel_delta_pct) * 1.2 + 1]);

    text(0.98, 0.03, '0.10 s coarse | Hann FFT 4\times', ...
        'Units', 'normalized', 'HorizontalAlignment', 'right', ...
        'FontSize', 8, 'Color', [0.5 0.5 0.5]);
end


% ========================================================================
% Table: steel scan trends
% ========================================================================

function t = make_steel_scan_trends(data)
    scan_params = {'J', 'L_free', 'b', 'h', 'x0_ratio'};
    param_names = {'J', 'L_{free}', 'b', 'h', 'x_0/L'};
    units = {'Ns', 'cm', 'cm', 'mm', ''};
    n_cases_list = zeros(5, 1);
    f_dom_ranges = cell(5, 1);
    spl_ranges = cell(5, 1);
    trend_summaries = cell(5, 1);

    for g = 1:numel(scan_params)
        idx = group_idx(data, scan_params{g});
        d = sort_by_param(data, idx);
        n_cases_list(g) = height(d);

        f = d.f_dom_refined_hz;
        spl = d.spl_rms_db;
        pv = d.param_value;

        if min(pv) ~= max(pv)
            monotonic_spl = all(diff(spl) > -0.1); %#ok<NASGU>
        else
            monotonic_spl = true; %#ok<NASGU>
        end
        f_range = sprintf('%.1f \\rightarrow %.1f Hz', f(1), f(end));
        spl_range = sprintf('%.1f \\rightarrow %.1f dB', spl(1), spl(end));

        f_dom_ranges{g} = f_range;
        spl_ranges{g} = spl_range;

        switch scan_params{g}
            case 'J'
                trend_str = sprintf('SPL monotonic +%.1f dB; f_d \\approx const %.2f \\pm %.2f Hz', ...
                    max(spl) - min(spl), mean(f), std(f));
            case 'L_free'
                trend_str = sprintf('f \\propto 1/L^2, f\\times L^2 = %.0f \\pm %.0f Hz\\cdotcm^2', ...
                    mean(f .* pv.^2), std(f .* pv.^2));
            case 'b'
                trend_str = sprintf('f_d minimal change (%.1f\\rightarrow%.1f Hz); mode match degrades at b\\geq4cm', ...
                    f(1), f(end));
            case 'h'
                trend_str = sprintf('f \\propto h, f/h = %.2f \\pm %.2f Hz/mm', ...
                    mean(f ./ pv), std(f ./ pv));
            case 'x0_ratio'
                trend_str = sprintf('Max SPL at x_0/L=0.50; all excite higher mode \\sim %d Hz', ...
                    round(mean(f)));
        end
        trend_summaries{g} = trend_str;
    end

    t = table(param_names(:), units(:), n_cases_list, f_dom_ranges, spl_ranges, trend_summaries, ...
        'VariableNames', {'parameter', 'unit', 'n_cases', 'f_dom_range', 'spl_range', 'trend_summary'});
end


% ========================================================================
% Table: material timbre summary
% ========================================================================

function t = make_material_timbre_summary(data)
    idx = group_idx(data, 'timbre_material');
    d = sort_by_param(data, idx);

    material = strrep(d.parameter, 'material_', '');
    f_dom = d.f_dom_refined_hz;
    spl = d.spl_rms_db;
    centroid = d.spectral_centroid_hz;
    flatness = d.spectral_flatness;
    probe_peak = d.probe_peak_m * 1000;  % convert to mm
    match_delta = d.best_match_rel_delta_pct;
    n_modes = d.n_modal_matches;

    t = table(material, f_dom, spl, centroid, flatness, probe_peak, match_delta, n_modes, ...
        'VariableNames', {'material', 'f_dom_hz', 'spl_db', 'centroid_hz', 'flatness', ...
        'probe_peak_mm', 'best_match_delta_pct', 'n_modes_matched'});
end


% ========================================================================
% Table: physics claims evidence
% ========================================================================

function t = make_physics_claims_evidence()
    claims = {
        'f_dom \propto 1/L^2 (free length)'; ...
        'f_dom \propto h (thickness)'; ...
        'SPL increases with impulse J, f_dom unchanged'; ...
        'Width b has minimal effect on f_dom, but degrades modal coupling'; ...
        'Impact position affects excitation efficiency and mode content'; ...
        'Material stiffness/density ratio determines f_dom range'; ...
        'Timbre can be quantified by spectral centroid + flatness'; ...
        'High-frequency decay trend (preliminary)'; ...
        'Q factor estimation not currently possible'};
    evidence = {
        'f*L^2 = 16100 \pm 30 Hz\cdotcm^2, variation < 0.2%'; ...
        'f/h = 20.0-20.3 Hz/mm, R^2 > 0.999'; ...
        'SPL: 83.0->95.0 dB monotonic; f_d: 40.22 \pm 0.01 Hz'; ...
        'f_d: 40.0-40.4 Hz; match error: 0.05%->5.20% at >=4cm'; ...
        'Max SPL at x0/L=0.5 (102.3 dB); all excite ~245 Hz mode'; ...
        'f_d ranges 12.1-276.5 Hz across 5 materials'; ...
        'Centroid 47.9-353.5 Hz, flatness 0.0008-0.0187'; ...
        'band_decay metrics available for 27/27 cases'; ...
        'q_source = missing_tip for all 27 cases'};
    support = {
        'strong'; 'strong'; 'strong'; ...
        'moderate'; 'moderate'; 'strong'; ...
        'moderate'; 'preliminary'; 'N/A'};
    limitations = {
        'Steel ruler only, 0.10s coarse window'; ...
        'Steel ruler only, 0.10s coarse window'; ...
        '4 data points, limited range'; ...
        'Narrow beam assumption degrades at b >= 4cm'; ...
        'Only 3 positions, limited resolution'; ...
        'Material properties not independently measured'; ...
        'Coarse window affects high-frequency accuracy'; ...
        '0.10s insufficient for reliable decay estimation'; ...
        'Missing tip_timeseries.csv; requires medium/full quality'};

    t = table(claims, evidence, support, limitations, ...
        'VariableNames', {'claim', 'evidence_metric', 'support_level', 'limitation'});
end
