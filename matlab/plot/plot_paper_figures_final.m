function plot_paper_figures_final()
%PLOT_PAPER_FIGURES_FINAL 论文级图表：微软雅黑中文 + tex 数学公式，300 DPI
    proj = 'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler';
    addpath(genpath(fullfile(proj, 'matlab')));
    T = readtable(fullfile(proj, 'outputs/requested_adaptive/tables/conclusion_master_table_corrected.csv'));
    out_dir = fullfile(proj, 'outputs/requested_adaptive/figures');
    if ~isfolder(out_dir), mkdir(out_dir); end

    set(0, 'DefaultAxesFontName', '微软雅黑');
    set(0, 'DefaultTextFontName', '微软雅黑');
    set(0, 'DefaultAxesFontSize', 11);
    colors = lines(6);

    % ================================================================
    % 图1: f1~f6 vs L — 钢尺频率分布
    % ================================================================
    steel_L = sortrows(T(contains(T.case_id, 'L_free'), :), 'L_free_cm');
    fig = figure('Position', [100 100 1000 540], 'Color', 'white');
    axes('FontName', '微软雅黑', 'FontSize', 11); hold on;
    for k = 1:6
        f_col = sprintf('f%d_hz', k);
        plot(steel_L.L_free_cm, steel_L.(f_col), 'o-', 'Color', colors(k,:), ...
            'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', colors(k,:));
    end
    base = find(steel_L.L_free_cm == 20, 1);
    if ~isempty(base) && steel_L.f1_hz(base) > 0 && steel_L.f1_hz(base) < 500
        k_val = steel_L.f1_hz(base) * 20^2;
        Lf = linspace(10, 26, 100);
        plot(Lf, k_val./Lf.^2, 'k--', 'LineWidth', 1.2);
    end
    xlabel('自由端长度 L (cm)', 'FontSize', 13);
    ylabel('固有频率 (Hz)', 'FontSize', 13);
    title('钢尺各阶固有频率与自由端长度的关系', 'FontSize', 15);
    leg_names = {'f_1','f_2','f_3','f_4','f_5','f_6'};
    Lg = legend(leg_names, 'Location', 'northwest', 'FontSize', 10);
    set(Lg, 'Interpreter', 'tex');
    annotation('textbox', [0.62 0.82 0.25 0.06], 'String', 'f_1 \propto 1/L^2', ...
        'Interpreter', 'tex', 'FontSize', 10, 'EdgeColor', 'none', 'Color', [0.3 0.3 0.3]);
    grid on; box on;
    exportgraphics(fig, fullfile(out_dir, 'fig1_pitch_vs_L.png'), 'Resolution', 300);
    close(fig);

    % ================================================================
    % 图2: 基频 f1 + 衰减 tau1 vs 厚度 h
    % ================================================================
    steel_h = sortrows(T(contains(T.case_id, '/h/'), :), 'h_mm');
    fig = figure('Position', [100 100 800 480], 'Color', 'white');
    yyaxis left;
    plot(steel_h.h_mm, steel_h.f1_hz, 'o-', 'Color', colors(1,:), ...
        'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors(1,:));
    base_h = find(steel_h.h_mm == 2, 1);
    if ~isempty(base_h) && steel_h.f1_hz(base_h) > 0
        k_h = steel_h.f1_hz(base_h) / 2;
        hf = linspace(0, 5.5, 100);
        hold on; plot(hf, k_h*hf, '--', 'Color', [colors(1,:) 0.4], 'LineWidth', 1.2);
    end
    ylabel('基频 f_1 (Hz)', 'Interpreter', 'tex', 'FontSize', 12);
    yyaxis right;
    valid_tau = steel_h.tau1_s > 0 & ~isnan(steel_h.tau1_s);
    plot(steel_h.h_mm(valid_tau), steel_h.tau1_s(valid_tau)*1000, 's--', ...
        'Color', colors(2,:), 'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors(2,:));
    ylabel('\tau_1 (ms)', 'Interpreter', 'tex', 'FontSize', 12);
    xlabel('尺厚 h (mm)', 'FontSize', 13);
    title('钢尺基频与衰减常数随厚度的变化', 'FontSize', 15);
    Lg = legend({'f_1 实测', 'f_1 \propto h 理论', '\tau_1 衰减常数'}, ...
        'Location', 'south', 'FontSize', 10);
    set(Lg, 'Interpreter', 'tex');
    grid on; box on;
    exportgraphics(fig, fullfile(out_dir, 'fig2_pitch_decay_vs_h.png'), 'Resolution', 300);
    close(fig);

    % ================================================================
    % 图3: tau vs f — 模态衰减时间常数与频率关系
    % ================================================================
    steel_all = T(strcmp(T.material, 'steel'), :);
    tau_all = []; f_all = [];
    for i = 1:height(steel_all)
        for k = 1:6
            tv = steel_all.(sprintf('tau%d_s', k))(i);
            fv = steel_all.(sprintf('f%d_hz', k))(i);
            if ~isnan(tv) && ~isnan(fv) && fv > 0 && fv < 10000 && tv > 0
                tau_all(end+1) = tv; f_all(end+1) = fv;
            end
        end
    end
    fig = figure('Position', [100 100 760 500], 'Color', 'white');
    scatter(f_all, tau_all*1000, 40, [0.3 0.5 0.8], 'filled', 'MarkerEdgeColor', 'k', ...
        'MarkerFaceAlpha', 0.5);
    set(gca, 'XScale', 'log', 'YScale', 'log');
    xlabel('模态频率 f_n (Hz)', 'FontSize', 13);
    ylabel('衰减时间常数 \tau_n (ms)', 'Interpreter', 'tex', 'FontSize', 13);
    title('钢尺各模态衰减时间常数与频率的关系', 'FontSize', 15);
    grid on; box on; hold on;
    valid = f_all > 0 & tau_all > 0;
    if sum(valid) > 5
        p = polyfit(log(f_all(valid)), log(tau_all(valid)*1000), 1);
        xf = logspace(log10(min(f_all)), log10(max(f_all)), 100);
        loglog(xf, exp(p(2))*xf.^p(1), 'r-', 'LineWidth', 1.8);
        yp = exp(p(2))*f_all(valid).^p(1);
        ssr = sum((tau_all(valid)*1000 - yp).^2);
        sst = sum((tau_all(valid)*1000 - mean(tau_all(valid)*1000)).^2);
        r2 = 1 - ssr/sst;
        text(50, max(tau_all)*1000*0.5, ...
            sprintf('\\tau \\propto f^{%.2f}    R^2 = %.3f', p(1), r2), ...
            'Interpreter', 'tex', 'FontSize', 12, ...
            'BackgroundColor', 'white', 'EdgeColor', 'k');
    end
    exportgraphics(fig, fullfile(out_dir, 'fig3_tau_vs_freq.png'), 'Resolution', 300);
    close(fig);

    % ================================================================
    % 图4: SPL vs J 与 SPL vs x0
    % ================================================================
    steel_J = sortrows(T(contains(T.case_id, '/J/'), :), 'J_Ns');
    fig = figure('Position', [100 100 960 420], 'Color', 'white');
    subplot(1,2,1);
    yyaxis left;
    plot(steel_J.J_Ns, steel_J.spl_rms_db, 'o-', 'Color', colors(1,:), ...
        'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors(1,:));
    ylabel('RMS 声压级 (dB)', 'FontSize', 11);
    yyaxis right;
    plot(steel_J.J_Ns, steel_J.probe_peak_mm, 's-', 'Color', colors(2,:), ...
        'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors(2,:));
    ylabel('探针峰值位移 (mm)', 'FontSize', 11);
    xlabel('冲量 J (N\cdot s)', 'Interpreter', 'tex', 'FontSize', 12);
    title('响度与振幅 vs 冲量', 'FontSize', 14);
    Lg = legend({'SPL (dB)', '位移 (mm)'}, 'Location', 'northwest', 'FontSize', 9);
    set(Lg, 'Interpreter', 'tex');
    grid on; box on;

    subplot(1,2,2);
    steel_x0 = sortrows(T(contains(T.case_id, 'x0_ratio'), :), 'x0_ratio');
    plot(steel_x0.x0_ratio*100, steel_x0.spl_rms_db, 'o-', 'Color', colors(1,:), ...
        'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors(1,:));
    hold on;
    plot(steel_x0.x0_ratio*100, steel_x0.spl_peak_db, 's--', 'Color', colors(2,:), ...
        'LineWidth', 1.5, 'MarkerSize', 8);
    xlabel('撞击位置 x_0 / L (%)', 'Interpreter', 'tex', 'FontSize', 12);
    ylabel('声压级 (dB)', 'FontSize', 11);
    title('响度 vs 撞击位置', 'FontSize', 14);
    Lg = legend({'RMS SPL', 'Peak SPL'}, 'Location', 'best', 'FontSize', 9);
    set(Lg, 'Interpreter', 'tex');
    grid on; box on;
    exportgraphics(fig, fullfile(out_dir, 'fig4_loudness_vs_J_x0.png'), 'Resolution', 300);
    close(fig);

    % ================================================================
    % 图5: SPL vs mic 距离 — 声压空间衰减
    % ================================================================
    fig = figure('Position', [100 100 860 520], 'Color', 'white');
    mat_names = {'steel', 'acrylic', 'pvc', 'satinwood', 'xuefu_board'};
    hold on;
    for m = 1:numel(mat_names)
        row = find(strcmp(T.material, mat_names{m}) & contains(T.case_id, 'material_'), 1);
        if isempty(row), continue; end
        dists = zeros(10,1); spls = zeros(10,1);
        for s = 1:10
            dists(s) = T.(sprintf('mic_sweep_dist_%02d_m', s))(row);
            spls(s)  = T.(sprintf('mic_sweep_spl_%02d_db', s))(row);
        end
        plot(dists*100, spls, 'o-', 'LineWidth', 1.5, 'MarkerSize', 7, 'MarkerFaceColor', 'auto');
    end
    xlabel('麦克风距尺面距离 (cm)', 'FontSize', 13);
    ylabel('RMS 声压级 (dB)', 'FontSize', 13);
    title('声压随传播距离的空间衰减', 'FontSize', 15);
    Lg = legend(mat_names, 'Location', 'northeast', 'FontSize', 10);
    set(Lg, 'Interpreter', 'none');
    grid on; box on;
    exportgraphics(fig, fullfile(out_dir, 'fig5_spl_vs_distance.png'), 'Resolution', 300);
    close(fig);

    % ================================================================
    % 图6: 音色映射 — 质心 × 平坦度 × SPL (气泡图)
    % ================================================================
    mat_data = T(contains(T.case_id, 'material_'), :);
    fig = figure('Position', [100 100 960 420], 'Color', 'white');
    subplot(1,2,1);
    bar(categorical(mat_data.material), ...
        [mat_data.spectral_centroid_hz, mat_data.rolloff85_hz]);
    xlabel('材料', 'FontSize', 11);
    ylabel('频率 (Hz)', 'FontSize', 11);
    title('频谱质心与 85% 滚降频率', 'FontSize', 14);
    Lg = legend({'频谱质心', '85% 滚降频率'}, 'Location', 'northwest', 'FontSize', 9);
    set(Lg, 'Interpreter', 'none');
    grid on; box on;

    subplot(1,2,2);
    scatter(mat_data.spectral_centroid_hz, mat_data.spectral_flatness, ...
        160, mat_data.spl_rms_db, 'filled', 'MarkerEdgeColor', 'k');
    colormap jet; cb = colorbar; cb.Label.String = 'SPL (dB)';
    for i = 1:height(mat_data)
        text(mat_data.spectral_centroid_hz(i)+15, mat_data.spectral_flatness(i)+0.0001, ...
            mat_data.material{i}, 'FontSize', 9);
    end
    xlabel('频谱质心 (Hz)', 'FontSize', 12);
    ylabel('频谱平坦度', 'FontSize', 12);
    title('音色映射: 质心 - 平坦度 - 响度', 'FontSize', 14);
    grid on; box on;
    exportgraphics(fig, fullfile(out_dir, 'fig6_timbre_material_map.png'), 'Resolution', 300);
    close(fig);

    % ================================================================
    % 图7: 线性/非线性判定
    % ================================================================
    probe_ratio = mat_data.probe_peak_mm ./ (mat_data.L_free_cm * 10) * 100;
    bar_colors = zeros(height(mat_data), 3);
    for i = 1:height(mat_data)
        if probe_ratio(i) < 5, bar_colors(i,:) = [0.15 0.70 0.15];
        elseif probe_ratio(i) < 10, bar_colors(i,:) = [0.90 0.70 0.10];
        else, bar_colors(i,:) = [0.85 0.15 0.15]; end
    end
    fig = figure('Position', [100 100 680 440], 'Color', 'white');
    b = bar(categorical(mat_data.material), probe_ratio, 'FaceColor', 'flat');
    b.CData = bar_colors;
    hold on;
    yline(5, 'k--', 'LineWidth', 1.2);
    yline(10, 'k--', 'LineWidth', 1.2);
    text(0.5, 5.8, '线性边界 (5%)', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
    text(0.5, 10.8, '非线性风险 (10%)', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
    xlabel('材料', 'FontSize', 13);
    ylabel('探针峰值位移 / 自由端长度 (%)', 'FontSize', 12);
    title('线性假设适用范围判定', 'FontSize', 15);
    grid on; box on;
    exportgraphics(fig, fullfile(out_dir, 'fig7_linearity_check.png'), 'Resolution', 300);
    close(fig);

    % ================================================================
    % 图8: 频率稳定性验证 — b 和 J 不影响 f1
    % ================================================================
    fig = figure('Position', [100 100 920 380], 'Color', 'white');
    subplot(1,2,1);
    steel_b = sortrows(T(contains(T.case_id, '/b/'), :), 'b_cm');
    plot(steel_b.b_cm, steel_b.f1_hz, 'o-', 'Color', colors(1,:), ...
        'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors(1,:));
    ylim([35 45]);
    xlabel('宽度 b (cm)', 'FontSize', 12);
    ylabel('基频 f_1 (Hz)', 'Interpreter', 'tex', 'FontSize', 12);
    title('基频与宽度无关', 'FontSize', 14);
    grid on; box on;

    subplot(1,2,2);
    steel_J2 = sortrows(T(contains(T.case_id, '/J/'), :), 'J_Ns');
    plot(steel_J2.J_Ns, steel_J2.f1_hz, 's-', 'Color', colors(2,:), ...
        'LineWidth', 1.5, 'MarkerSize', 8, 'MarkerFaceColor', colors(2,:));
    ylim([35 45]);
    xlabel('冲量 J (N\cdot s)', 'Interpreter', 'tex', 'FontSize', 12);
    ylabel('基频 f_1 (Hz)', 'Interpreter', 'tex', 'FontSize', 12);
    title('基频与冲量无关', 'FontSize', 14);
    grid on; box on;
    exportgraphics(fig, fullfile(out_dir, 'fig8_freq_stability.png'), 'Resolution', 300);
    close(fig);

    % ================================================================
    % 图9: 振型示例 (从 steel baseline mode_shapes.csv 读取)
    % ================================================================
    mode_path = fullfile(proj, 'outputs/requested_adaptive/cases/timbre_material/material_steel/data/mode_shapes.csv');
    if isfile(mode_path)
        mode_tbl = read_exported_numeric_csv(mode_path);
        fig = figure('Position', [100 100 860 500], 'Color', 'white');
        n_plot = min(6, width(mode_tbl)-1);
        n_cols = 3; n_rows = ceil(n_plot / n_cols);
        for k = 1:n_plot
            subplot(n_rows, n_cols, k);
            col_name = sprintf('w_mode%d', k);
            if ismember(col_name, mode_tbl.Properties.VariableNames)
                plot(mode_tbl.x_over_L, mode_tbl.(col_name), 'LineWidth', 1.5, 'Color', colors(k,:));
            end
            xlabel('x / L'); ylabel(sprintf('w_%d', k));
            title(sprintf('第 %d 阶振型', k));
            grid on; box on;
        end
        sgtitle('钢尺前 6 阶模态振型 (仿真)', 'FontSize', 15, 'FontWeight', 'bold');
        exportgraphics(fig, fullfile(out_dir, 'fig9_mode_shapes.png'), 'Resolution', 300);
        close(fig);
    end

    % ================================================================
    % 完成
    % ================================================================
    fprintf('\n=== 图表生成完成 ===\n');
    fprintf('输出: %s\n', out_dir);
    d = dir(fullfile(out_dir, 'fig*.png'));
    for i = 1:numel(d)
        fprintf('  %s  %.0f KB\n', d(i).name, d(i).bytes/1024);
    end
end
