function plot_paper_figures_zh(proj_root, data_rel_root)
%PLOT_PAPER_FIGURES_ZH 从结论主表生成中文论文图表。
%   plot_paper_figures_zh(proj_root, data_rel_root)

    arguments
        proj_root (1,:) char = fullfile(fileparts(mfilename('fullpath')), '..', '..')
        data_rel_root (1,:) char = 'outputs/requested_adaptive'
    end

    addpath(genpath(fullfile(proj_root, 'matlab')));

    T = readtable(fullfile(proj_root, data_rel_root, 'tables', 'conclusion_master_table.csv'));
    out_dir = fullfile(proj_root, data_rel_root, 'figures');
    ensure_dir(out_dir);

    % 全局绘图风格
    set(0, 'DefaultAxesFontName', 'SimHei');
    set(0, 'DefaultTextFontName', 'SimHei');
    set(0, 'DefaultAxesFontSize', 10);

    % =================================================================
    % 图1: 音调 — 前六阶固有频率 vs 自由端长度
    % =================================================================
    steel_mask = strcmp(T.material, 'steel') & ~contains(T.case_id, '/b/') & ...
                 ~contains(T.case_id, '/h/') & ~contains(T.case_id, '/J/') & ...
                 ~contains(T.case_id, '/x0_');
    L_cases = T(steel_mask, :);
    [L_sorted, ord] = sort(L_cases.L_free_cm);
    L_cases = L_cases(ord, :);

    figure('Position', [100 100 900 400]);
    hold on;
    colors = lines(6);
    mode_labels = {};
    for k = 1:6
        f_col = sprintf('f%d_hz', k);
        plot(L_cases.L_free_cm, L_cases.(f_col), 'o-', ...
            'Color', colors(k,:), 'LineWidth', 1.5, 'MarkerSize', 6);
        mode_labels{k} = sprintf('第%d阶', k);
    end
    xlabel('自由端长度 L (cm)');
    ylabel('固有频率 (Hz)');
    title('钢尺固有频率与自由端长度的关系');
    legend(mode_labels, 'Location', 'northwest');
    grid on;
    saveas(gcf, fullfile(out_dir, 'fig1_pitch_vs_L.png'));
    close;

    % 图1b: 基频 vs 厚度
    h_mask = (contains(T.case_id, '/h/') | contains(T.case_id, 'material_steel')) & ...
             strcmp(T.material, 'steel');
    h_cases = T(h_mask, :);
    [h_sorted, ord] = sort(h_cases.h_mm);
    h_cases = h_cases(ord, :);

    figure('Position', [100 100 700 400]);
    yyaxis left;
    plot(h_cases.h_mm, h_cases.f1_hz, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6, 'Color', colors(1,:));
    xlabel('尺厚 h (mm)');
    ylabel('基频 f_1 (Hz)');

    yyaxis right;
    tau_col = 'tau1_s';
    plot(h_cases.h_mm, h_cases.(tau_col)*1000, 's--', 'LineWidth', 1.5, 'MarkerSize', 6);
    ylabel('衰减时间常数 τ_1 (ms)');
    title('钢尺基频与衰减时间常数随厚度的变化');
    legend({'基频 f_1', '衰减常数 τ_1'}, 'Location', 'best');
    grid on;
    saveas(gcf, fullfile(out_dir, 'fig1b_pitch_decay_vs_h.png'));
    close;

    % =================================================================
    % 图2: 音色 — 频谱特征 vs 材料
    % =================================================================
    mat_idx = contains(T.case_id, 'material_') | contains(T.group, 'timbre_material');
    mat_cases = T(mat_idx, :);
    [~, ord] = sort(mat_cases.spectral_centroid_hz);
    mat_cases = mat_cases(ord, :);

    figure('Position', [100 100 1000 500]);
    subplot(1,2,1);
    bar_data = [mat_cases.spectral_centroid_hz, mat_cases.rolloff85_hz];
    b = bar(categorical(mat_cases.material), bar_data);
    b(1).FaceColor = [0.2 0.6 0.8];
    b(2).FaceColor = [0.8 0.4 0.2];
    xlabel('材料');
    ylabel('频率 (Hz)');
    title('频谱质心与85%滚降频率');
    legend({'频谱质心', '85%滚降频率'}, 'Location', 'northwest');
    grid on;

    subplot(1,2,2);
    scatter(mat_cases.spectral_centroid_hz, mat_cases.spectral_flatness, 120, ...
        mat_cases.spl_rms_db, 'filled', 'MarkerEdgeColor', 'k');
    colormap jet; cb = colorbar;
    cb.Label.String = 'SPL (dB)';
    for i = 1:height(mat_cases)
        text(mat_cases.spectral_centroid_hz(i)+10, mat_cases.spectral_flatness(i), ...
            mat_cases.material{i}, 'FontSize', 8);
    end
    xlabel('频谱质心 (Hz)');
    ylabel('频谱平坦度');
    title('音色映射：质心—平坦度—响度');
    grid on;
    saveas(gcf, fullfile(out_dir, 'fig2_timbre_material.png'));
    close;

    % =================================================================
    % 图3: 响度 — SPL vs 冲量与撞击位置
    % =================================================================
    figure('Position', [100 100 1000 400]);
    subplot(1,2,1);
    J_idx = contains(T.case_id, '/J/') | (contains(T.case_id, 'material_steel') & strcmp(T.material, 'steel'));
    J_cases = T(J_idx, :);
    [J_sorted, ord] = sort(J_cases.J_Ns);
    J_cases = J_cases(ord, :);
    yyaxis left;
    plot(J_cases.J_Ns, J_cases.spl_rms_db, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6);
    xlabel('冲量 J (N·s)');
    ylabel('RMS声压级 (dB)');
    yyaxis right;
    plot(J_cases.J_Ns, J_cases.probe_peak_mm, 's--', 'LineWidth', 1.5, 'MarkerSize', 6);
    ylabel('探针峰值位移 (mm)');
    title('响度与振幅随撞击冲量的变化');
    legend({'SPL (dB)', '位移 (mm)'}, 'Location', 'northwest');
    grid on;

    subplot(1,2,2);
    x0_idx = contains(T.case_id, '/x0_ratio/');
    x0_cases = T(x0_idx, :);
    [x0_sorted, ord] = sort(x0_cases.x0_ratio);
    x0_cases = x0_cases(ord, :);
    plot(x0_cases.x0_ratio*100, x0_cases.spl_rms_db, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6);
    hold on;
    plot(x0_cases.x0_ratio*100, x0_cases.spl_peak_db, 's--', 'LineWidth', 1.5, 'MarkerSize', 6);
    xlabel('撞击位置 x_0 / L (%)');
    ylabel('声压级 (dB)');
    title('响度随撞击位置的变化');
    legend({'RMS SPL', 'Peak SPL'}, 'Location', 'best');
    grid on;
    saveas(gcf, fullfile(out_dir, 'fig3_loudness_vs_J_x0.png'));
    close;

    % =================================================================
    % 图4: 声压空间衰减 — SPL vs mic距离
    % =================================================================
    figure('Position', [100 100 900 500]);
    mat_names = unique(T.material);
    legend_entries = {};
    hold on;
    for m = 1:numel(mat_names)
        row = find(strcmp(T.material, mat_names{m}) & contains(T.case_id, 'material_'), 1);
        if isempty(row), continue; end
        dists = zeros(10,1); spls = zeros(10,1);
        for s = 1:10
            dists(s) = T.(sprintf('mic_sweep_dist_%02d_m', s))(row);
            spls(s)  = T.(sprintf('mic_sweep_spl_%02d_db', s))(row);
        end
        plot(dists*100, spls, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6);
        legend_entries{end+1} = mat_names{m};
    end
    xlabel('麦克风距尺面距离 (cm)');
    ylabel('RMS声压级 (dB)');
    title('声压随传播距离的衰减');
    legend(legend_entries, 'Location', 'northeast');
    grid on;
    saveas(gcf, fullfile(out_dir, 'fig4_spl_vs_distance.png'));
    close;

    % =================================================================
    % 图5: 模态衰减 — τ, Q vs 频率（Rayleigh阻尼验证）
    % =================================================================
    steel_row = find(strcmp(T.material, 'steel') & contains(T.case_id, 'material_'), 1);
    freqs = zeros(6,1); taus = zeros(6,1); Qs = zeros(6,1); Rs = zeros(6,1);
    for k = 1:6
        freqs(k) = T.(sprintf('f%d_hz', k))(steel_row);
        taus(k)  = T.(sprintf('tau%d_s', k))(steel_row);
        Qs(k)    = T.(sprintf('Q%d', k))(steel_row);
        Rs(k)    = T.(sprintf('r2_%d', k))(steel_row);
    end

    figure('Position', [100 100 1000 400]);
    subplot(1,2,1);
    yyaxis left;
    bar(freqs, taus*1000, 0.6, 'FaceColor', [0.3 0.6 0.9]);
    ylabel('衰减时间常数 τ (ms)');
    yyaxis right;
    plot(freqs, Qs, 'ro', 'MarkerSize', 10, 'LineWidth', 1.5);
    ylabel('品质因数 Q');
    xlabel('模态频率 (Hz)');
    title('各模态衰减特性');
    legend({'τ', 'Q'}, 'Location', 'best');
    for k = 1:6
        text(freqs(k), Qs(k)+2, sprintf('R^2=%.2f', Rs(k)), ...
            'FontSize', 7, 'HorizontalAlignment', 'center');
    end
    grid on;

    subplot(1,2,2);
    rayleigh_mask = T.rayleigh_valid == 1 & strcmp(T.material, 'steel');
    if any(rayleigh_mask)
        rayleigh_cases = T(rayleigh_mask, :);
        alpha_vals = rayleigh_cases.alpha_dM_est;
        beta_vals  = rayleigh_cases.beta_dK_est;
        scatter(alpha_vals(~isnan(alpha_vals)), beta_vals(~isnan(beta_vals)), 60, 'filled');
        xlabel('Rayleigh α (质量阻尼)');
        ylabel('Rayleigh β (刚度阻尼)');
        title('Rayleigh阻尼参数估计');
        grid on;
    end
    saveas(gcf, fullfile(out_dir, 'fig5_modal_decay_rayleigh.png'));
    close;

    % =================================================================
    % 图6: 线性/非线性判定
    % =================================================================
    mat_idx2 = contains(T.case_id, 'material_');
    mat_cases2 = T(mat_idx2, :);
    probe_ratio = mat_cases2.probe_peak_mm ./ (mat_cases2.L_free_cm * 10);  % mm / mm

    figure('Position', [100 100 700 400]);
    bar_colors = zeros(height(mat_cases2), 3);
    for i = 1:height(mat_cases2)
        if probe_ratio(i) < 0.05
            bar_colors(i,:) = [0.2 0.8 0.2];  % green: linear
        elseif probe_ratio(i) < 0.10
            bar_colors(i,:) = [0.9 0.7 0.1];  % yellow: borderline
        else
            bar_colors(i,:) = [0.9 0.2 0.2];  % red: nonlinear
        end
    end
    b = bar(categorical(mat_cases2.material), probe_ratio*100, 'FaceColor', 'flat');
    b.CData = bar_colors;
    hold on;
    yline(5, 'k--', 'LineWidth', 1);
    yline(10, 'k--', 'LineWidth', 1);
    text(0.6, 5.5, '线性边界 (5%)', 'FontSize', 7);
    text(0.6, 10.5, '非线性风险 (10%)', 'FontSize', 7);
    xlabel('材料');
    ylabel('探针峰值位移 / 自由端长度 (%)');
    title('线性/非线性变形判定');
    grid on;
    saveas(gcf, fullfile(out_dir, 'fig6_linearity_check.png'));
    close;

    % =================================================================
    % 图7: 冲量—位移线性验证
    % =================================================================
    J_idx2 = contains(T.case_id, '/J/');
    J_cases2 = T(J_idx2, :);
    [J_sorted, ord] = sort(J_cases2.J_Ns);
    J_cases2 = J_cases2(ord, :);

    figure('Position', [100 100 500 400]);
    plot(J_cases2.J_Ns, J_cases2.probe_peak_mm, 'o-', 'LineWidth', 1.5, 'MarkerSize', 8);
    xlabel('冲量 J (N·s)');
    ylabel('探针峰值位移 (mm)');
    title('位移—冲量线性关系');
    grid on;
    saveas(gcf, fullfile(out_dir, 'fig7_displacement_vs_J.png'));
    close;

    % =================================================================
    % 输出汇总
    % =================================================================
    fprintf('论文图表已生成至: %s\n', out_dir);
    fprintf('  fig1_pitch_vs_L.png           — 频率 vs 自由端长度\n');
    fprintf('  fig1b_pitch_decay_vs_h.png    — 频率与衰减 vs 厚度\n');
    fprintf('  fig2_timbre_material.png      — 音色特征 vs 材料\n');
    fprintf('  fig3_loudness_vs_J_x0.png     — 响度 vs 冲量与位置\n');
    fprintf('  fig4_spl_vs_distance.png      — 声压空间衰减\n');
    fprintf('  fig5_modal_decay_rayleigh.png — 模态衰减与Rayleigh参数\n');
    fprintf('  fig6_linearity_check.png      — 线性/非线性判定\n');
    fprintf('  fig7_displacement_vs_J.png    — 位移—冲量线性关系\n');
end
