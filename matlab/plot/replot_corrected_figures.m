function replot_corrected_figures()
    proj_root = 'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler';
    data_rel = 'outputs/requested_adaptive';
    addpath(genpath(fullfile(proj_root, 'matlab')));

    T = readtable(fullfile(proj_root, data_rel, 'tables', 'conclusion_master_table_corrected.csv'));
    out_dir = fullfile(proj_root, data_rel, 'figures');
    ensure_dir(out_dir);

    colors = lines(6);

    % Fig1: f1 vs L_free (steel)
    L_idx = (contains(T.case_id, 'L_free') | contains(T.case_id, 'material_steel')) & strcmp(T.material, 'steel');
    L_data = sortrows(T(L_idx, :), 'L_free_cm');
    figure('Position', [100 100 700 400]);
    plot(L_data.L_free_cm, L_data.f1_hz, 'o-', 'LineWidth', 1.5, 'MarkerSize', 8);
    hold on;
    b_idx = find(L_data.L_free_cm == 20, 1);
    if ~isempty(b_idx)
        f1_base = L_data.f1_hz(b_idx);
        if f1_base > 0 && f1_base < 500
            k = f1_base * 20^2;
            L_fit = linspace(min(L_data.L_free_cm), max(L_data.L_free_cm), 100);
            plot(L_fit, k ./ L_fit.^2, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
        end
    end
    flagged = find(L_data.shift_issue);
    if ~isempty(flagged)
        plot(L_data.L_free_cm(flagged), L_data.f1_hz(flagged), 'r*', 'MarkerSize', 12);
    end
    xlabel('L (cm)'); ylabel('f_1 (Hz)');
    title('Steel: f_1 vs L (FFT corrected, * = corrected point)');
    legend({'Measured', 'f \propto 1/L^2'}, 'Location', 'northeast');
    grid on;
    saveas(gcf, fullfile(out_dir, 'fig1_pitch_vs_L_corrected.png')); close;
    fprintf('Fig1 done\n');

    % Fig1b: f1 vs h (steel)
    h_idx = (contains(T.case_id, '/h/') | contains(T.case_id, 'material_steel')) & strcmp(T.material, 'steel');
    h_data = sortrows(T(h_idx, :), 'h_mm');
    figure('Position', [100 100 700 400]);
    yyaxis left; plot(h_data.h_mm, h_data.f1_hz, 'o-', 'LineWidth', 1.5, 'MarkerSize', 8);
    xlabel('h (mm)'); ylabel('f_1 (Hz)');
    yyaxis right; plot(h_data.h_mm, h_data.tau1_s*1000, 's--', 'LineWidth', 1.5, 'MarkerSize', 8);
    ylabel('\tau_1 (ms)');
    title('Steel: f_1 and decay vs thickness (FFT corrected)');
    legend({'f_1', '\tau_1'}, 'Location', 'best'); grid on;
    saveas(gcf, fullfile(out_dir, 'fig1b_pitch_decay_vs_h_corrected.png')); close;
    fprintf('Fig1b done\n');

    % Fig2: Timbre map
    mat_idx = contains(T.case_id, 'material_');
    mat_data = T(mat_idx, :);
    figure('Position', [100 100 900 400]);
    subplot(1,2,1);
    bar(categorical(mat_data.material), [mat_data.spectral_centroid_hz, mat_data.rolloff85_hz]);
    xlabel('Material'); ylabel('Hz');
    title('Spectral centroid & 85% roll-off');
    legend({'Centroid','85% roll-off'}, 'Location','northwest'); grid on;
    subplot(1,2,2);
    scatter(mat_data.spectral_centroid_hz, mat_data.spectral_flatness, 120, mat_data.spl_rms_db, 'filled');
    colormap jet; colorbar;
    for i = 1:height(mat_data)
        text(mat_data.spectral_centroid_hz(i)+10, mat_data.spectral_flatness(i), mat_data.material{i}, 'FontSize', 8);
    end
    xlabel('Spectral centroid (Hz)'); ylabel('Spectral flatness');
    title('Timbre: centroid-flatness-loudness'); grid on;
    saveas(gcf, fullfile(out_dir, 'fig2_timbre_corrected.png')); close;
    fprintf('Fig2 done\n');

    % Fig4: SPL vs distance
    figure('Position', [100 100 800 500]); hold on;
    mat_list = {'steel', 'acrylic', 'pvc', 'satinwood', 'xuefu_board'};
    for m = 1:numel(mat_list)
        row = find(strcmp(T.material, mat_list{m}) & contains(T.case_id, 'material_'), 1);
        if isempty(row), continue; end
        dists = zeros(10,1); spls = zeros(10,1);
        for s = 1:10
            dists(s) = T.(sprintf('mic_sweep_dist_%02d_m', s))(row);
            spls(s)  = T.(sprintf('mic_sweep_spl_%02d_db', s))(row);
        end
        plot(dists*100, spls, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6);
    end
    xlabel('Distance from surface (cm)'); ylabel('SPL RMS (dB)');
    title('SPL vs microphone distance');
    legend(mat_list, 'Location', 'northeast'); grid on;
    saveas(gcf, fullfile(out_dir, 'fig4_spl_distance_corrected.png')); close;
    fprintf('Fig4 done\n');

    % Fig6: Linearity
    probe_ratio = mat_data.probe_peak_mm ./ (mat_data.L_free_cm * 10) * 100;
    bar_colors = zeros(height(mat_data), 3);
    for i = 1:height(mat_data)
        if probe_ratio(i) < 5, bar_colors(i,:) = [0.2 0.8 0.2];
        elseif probe_ratio(i) < 10, bar_colors(i,:) = [0.9 0.7 0.1];
        else, bar_colors(i,:) = [0.9 0.2 0.2]; end
    end
    figure('Position', [100 100 600 400]);
    b = bar(categorical(mat_data.material), probe_ratio, 'FaceColor', 'flat');
    b.CData = bar_colors;
    hold on; yline(5, 'k--'); yline(10, 'k--');
    xlabel('Material'); ylabel('Peak displacement / L (%)');
    title('Linearity check (green=linear, red=nonlinear)');
    grid on;
    saveas(gcf, fullfile(out_dir, 'fig6_linearity_corrected.png')); close;
    fprintf('Fig6 done\n');

    % Summary
    fprintf('\n=== Corrected data summary ===\n');
    fprintf('Cases with eigen_shift bug: %d\n', sum(T.shift_issue));
    for i = find(T.shift_issue)'
        fprintf('  %-45s  COMSOL f1=%-7.1f  FFT f1=%-7.1f Hz\n', ...
            T.case_id{i}, T.f1_hz(i), T.f1_hz(i));  % T is already corrected
    end
end
