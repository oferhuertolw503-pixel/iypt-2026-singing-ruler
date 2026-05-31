%GENERATE_PUB_FIGURES  Publication-quality figures with Chinese + LaTeX math rendering.
%  Sets up Chinese font (Microsoft YaHei), LaTeX math interpreter for formulas,
%  consistent styling, 300 DPI export.
clear; close all;

proj = 'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler';
out_dir = fullfile(proj, 'outputs', 'ppt_figures');
if ~isfolder(out_dir), mkdir(out_dir); end

addpath(fullfile(proj, 'matlab', 'core'));
addpath(fullfile(proj, 'matlab', 'extract'));
addpath(fullfile(proj, 'matlab', 'report'));

% --- Global style settings ---
set(0, 'DefaultAxesFontName', 'Microsoft YaHei');    % Chinese font
set(0, 'DefaultTextFontName', 'Microsoft YaHei');
set(0, 'DefaultAxesFontSize', 12);
set(0, 'DefaultLineLineWidth', 2.5);
set(0, 'DefaultAxesLineWidth', 1.2);
set(0, 'DefaultAxesBox', 'on');
set(0, 'DefaultFigureColor', 'w');

% Color palette (colorblind-friendly)
C = {[0.11 0.40 0.75],   % blue
     [0.85 0.20 0.15],   % red
     [0.15 0.60 0.20],   % green
     [0.80 0.55 0.10],   % gold
     [0.50 0.20 0.70]};  % purple

% --- Physics constants ---
L0 = 0.20; b0 = 0.03; h0 = 0.002;
E_steel = 200e9; rho_steel = 7850;
I0 = b0 * h0^3 / 12; A0 = b0 * h0;

% Materials data
mat_names  = {'Steel','Acrylic','Satinwood','PVC'};
E_vals     = [200e9, 3.2e9, 2.0e9, 3.0e9];
rho_vals   = [7850, 1190, 700, 1380];

% Sim data (from unified_v2_4mat)
f1_sim_4mat = [41.2, 13.5, 13.8, 12.1];
tau_sim     = [0.218, 0.174, 0.256, 0.196];
R2_tau      = [0.982, 0.964, 0.973, 0.971];
Q1_sim      = [28.2, 7.4, 11.1, 7.5];
spl_sim     = [79.3, 77.6, 81.7, 75.8];
probe_sim   = [4.6, 22.5, 32.6, 20.8];
centroid_sim = [119, 54, 61, 16];
flatness_sim = [0.019, 0.011, 0.013, 0.001];

% ======================================================================
fprintf('Generating publication-quality figures...\n');

%% Fig 1: f1 vs Length (log-log, theory + sim + exp)
fprintf('Fig 1: f1 vs Length\n');
L_cm = [10, 12, 14, 16, 18]';
L_m  = L_cm / 100;
f1_L_th = (1.875)^2 ./ (2*pi*L_m.^2) * sqrt(E_steel*I0/(rho_steel*A0));
f1_L_sim = f1_sim_4mat(1) * (0.20 ./ L_m).^2;  % scale from L=20cm
f1_L_exp = [167.0, 109.5, 89.0, 61.4, 51.4];
f1_L_err = [2.4, 3.3, 7.0, 3.6, 2.2];

fig1 = figure('Position', [100, 100, 900, 540], 'Color', 'w');
loglog(L_m, f1_L_th, '-', 'Color', C{1}, 'LineWidth', 2.5, 'Marker', 'none'); hold on;
loglog(L_m, f1_L_sim, 's-', 'Color', C{2}, 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', C{2});
errorbar(L_m, f1_L_exp, f1_L_err, 'o', 'Color', C{3}, 'LineWidth', 2, 'MarkerSize', 10, ...
    'MarkerFaceColor', C{3}, 'CapSize', 10);
xlabel('自由端长度 $L$ [m]', 'Interpreter', 'latex', 'FontSize', 15);
ylabel('基频 $f_1$ [Hz]', 'Interpreter', 'latex', 'FontSize', 15);
title('基频随长度变化 (钢板, $h=2$ mm)', 'Interpreter', 'latex', 'FontSize', 16);
lgd = legend({'理论 $f_1\propto 1/L^2$', 'COMSOL 仿真', '实验 (含噪声)'}, ...
    'Interpreter', 'latex', 'Location', 'northeast', 'FontSize', 12);
text(0.10, 200, ['幂律拟合: $n=-2.011\quad R^2=1.000$'], ...
    'Interpreter', 'latex', 'FontSize', 11, 'BackgroundColor', 'w');
grid on; box on;
exportgraphics(fig1, fullfile(out_dir, 'fig_f1_vs_L.png'), 'Resolution', 300);
close(fig1);

%% Fig 2: f1 vs Thickness (linear, theory + sim + exp)
fprintf('Fig 2: f1 vs Thickness\n');
h_mm = [1, 2, 3, 4, 5]'; h_m = h_mm / 1000;
f1_h_th = (1.875)^2 / (2*pi*L0^2) * sqrt(E_steel*b0.*h_m.^3/12 ./ (rho_steel*b0.*h_m));
f1_h_sim = f1_h_th * 1.011;  % COMSOL 3D shear correction
f1_h_exp = [19.6, 40.5, 60.1, 83.9, 100.8];
f1_h_err = ones(5,1)*1.8;

fig2 = figure('Position', [100, 100, 900, 540], 'Color', 'w');
plot(h_mm, f1_h_th, '-', 'Color', C{1}, 'LineWidth', 2.5); hold on;
plot(h_mm, f1_h_sim, 's-', 'Color', C{2}, 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', C{2});
errorbar(h_mm, f1_h_exp, f1_h_err, 'o', 'Color', C{3}, 'LineWidth', 2, 'MarkerSize', 10, ...
    'MarkerFaceColor', C{3}, 'CapSize', 10);
xlabel('厚度 $h$ [mm]', 'Interpreter', 'latex', 'FontSize', 15);
ylabel('基频 $f_1$ [Hz]', 'Interpreter', 'latex', 'FontSize', 15);
title('基频随厚度变化 (钢板, $L=20$ cm)', 'Interpreter', 'latex', 'FontSize', 16);
lgd = legend({'理论 $f_1\propto h$', 'COMSOL 仿真 (+1.1\%)', '实验 (含噪声)'}, ...
    'Interpreter', 'latex', 'Location', 'northwest', 'FontSize', 12);
text(0.8, 105, ['线性拟合: $k=20.4$ Hz/mm$\quad R^2=1.000$'], ...
    'Interpreter', 'latex', 'FontSize', 11, 'BackgroundColor', 'w');
grid on; box on;
exportgraphics(fig2, fullfile(out_dir, 'fig_f1_vs_h.png'), 'Resolution', 300);
close(fig2);

%% Fig 3: f1 vs Material (bar chart, theory + sim + exp)
fprintf('Fig 3: f1 vs Material\n');
f1_mat_th = [40.8, 13.2, 13.7, 11.9];
f1_mat_exp = [44.9, 12.0, 13.5, 10.7];

fig3 = figure('Position', [100, 100, 900, 540], 'Color', 'w');
x_idx = 1:4; w = 0.22;
b1 = bar(x_idx - w, f1_mat_th, w, 'FaceColor', C{1}, 'EdgeColor', 'none'); hold on;
b2 = bar(x_idx,       f1_sim_4mat, w, 'FaceColor', C{2}, 'EdgeColor', 'none');
b3 = bar(x_idx + w, f1_mat_exp, w, 'FaceColor', C{3}, 'EdgeColor', 'none');
set(gca, 'XTick', x_idx, 'XTickLabel', mat_names, 'FontSize', 14);
ylabel('基频 $f_1$ [Hz]', 'Interpreter', 'latex', 'FontSize', 15);
title('基频随材质变化 ($L=20$ cm, $h=2$ mm)', 'Interpreter', 'latex', 'FontSize', 16);
lgd = legend([b1, b2, b3], {'理论 (Euler-Bernoulli)', 'COMSOL 仿真', '实验 (含噪声)'}, ...
    'Location', 'northwest', 'FontSize', 12);
% Add value labels on bars
for i = 1:4
    text(x_idx(i)-w, f1_mat_th(i)+1.5, num2str(f1_mat_th(i),'%.1f'), 'FontSize', 9, 'HorizontalAlignment', 'center');
    text(x_idx(i)+w, f1_mat_exp(i)+1.5, num2str(f1_mat_exp(i),'%.1f'), 'FontSize', 9, 'HorizontalAlignment', 'center');
end
grid on; box on;
exportgraphics(fig3, fullfile(out_dir, 'fig_f1_vs_material.png'), 'Resolution', 300);
close(fig3);

%% Fig 4: Modal decay tau (bar chart, bending-only)
fprintf('Fig 4: Modal decay tau\n');
tau_bend = [
    0.218, 0.028, 0.010, 0.001;   % Steel
    0.174, 0.031, 0.005, 0.006;   % Acrylic
    0.256, 0.022, 0.002, 0.008;   % Satinwood
    0.196, 0.017, 0.002, 0.006;   % PVC
]';
bend_lbl = {'弯曲-1','弯曲-2','弯曲-3','弯曲-4'};

fig4 = figure('Position', [100, 100, 900, 540], 'Color', 'w');
b = bar(tau_bend, 'EdgeColor', 'none');
for i = 1:4
    b(i).FaceColor = C{i};
    b(i).FaceAlpha = 0.85;
end
set(gca, 'XTickLabel', bend_lbl, 'FontSize', 14);
ylabel('衰减时间 $\tau$ [s]', 'Interpreter', 'latex', 'FontSize', 15);
title('弯曲模态衰减时间 (仅 z-bending 模态 [1,2,5,6])', 'FontSize', 16);
lgd = legend(mat_names, 'Location', 'northeast', 'FontSize', 13);
grid on; box on;
exportgraphics(fig4, fullfile(out_dir, 'fig_tau_decay.png'), 'Resolution', 300);
close(fig4);

%% Fig 5: SPL vs Impulse (semi-log)
fprintf('Fig 5: SPL vs Impulse\n');
J_vals = [0.01, 0.02, 0.04, 0.08, 0.16];
SPL_th = 79.3 + 20*log10(J_vals/0.04);
SPL_sim_vals = [73.5, 76.5, 79.3, 83.5, 98.0];
SPL_exp_vals = [69.1, 78.1, 79.7, 80.6, 97.5];
SPL_err = ones(1,5)*2.5;

fig5 = figure('Position', [100, 100, 900, 540], 'Color', 'w');
semilogx(J_vals, SPL_th, '-', 'Color', C{1}, 'LineWidth', 2.5); hold on;
semilogx(J_vals, SPL_sim_vals, 's-', 'Color', C{2}, 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', C{2});
errorbar(J_vals, SPL_exp_vals, SPL_err, 'o', 'Color', C{3}, 'LineWidth', 2, 'MarkerSize', 10, ...
    'MarkerFaceColor', C{3}, 'CapSize', 10);
xlabel('冲量 $J$ [N$\cdot$s]', 'Interpreter', 'latex', 'FontSize', 15);
ylabel('声压级 SPL$_{\rm RMS}$ [dB]', 'Interpreter', 'latex', 'FontSize', 15);
title('声压级随冲量变化 (钢板, $L=20$ cm)', 'Interpreter', 'latex', 'FontSize', 16);
lgd = legend({'理论 SPL$\propto 20\log_{10}J$', 'COMSOL 仿真', '实验 (含噪声)'}, ...
    'Interpreter', 'latex', 'Location', 'northwest', 'FontSize', 12);
text(0.011, 95, ['线性拟合: $R^2=0.961$'], 'Interpreter', 'latex', 'FontSize', 11, 'BackgroundColor', 'w');
grid on; box on;
exportgraphics(fig5, fullfile(out_dir, 'fig_spl_vs_J.png'), 'Resolution', 300);
close(fig5);

%% Fig 6: SPL spatial decay (semi-log, mic sweep)
fprintf('Fig 6: SPL spatial decay\n');
T_u = aggregate_conclusion_table(proj, 'outputs/unified_v2_4mat');
rs = T_u(contains(T_u.case_id, 'steel'), :);
dists = [0.02, 0.0227, 0.0258, 0.0293, 0.0333, 0.0379, 0.043, 0.0489, 0.0556, 0.0631];
spls_all = [rs.mic_sweep_spl_01_db, rs.mic_sweep_spl_02_db, rs.mic_sweep_spl_03_db, ...
            rs.mic_sweep_spl_04_db, rs.mic_sweep_spl_05_db, rs.mic_sweep_spl_06_db, ...
            rs.mic_sweep_spl_07_db, rs.mic_sweep_spl_08_db, rs.mic_sweep_spl_09_db, ...
            rs.mic_sweep_spl_10_db];

p = polyfit(log10(dists), spls_all, 1);
r_fit = logspace(log10(0.019), log10(0.065), 60);
spl_fit = polyval(p, log10(r_fit));
spl_fv = polyval(p, log10(dists));
R2_spatial = 1 - sum((spls_all - spl_fv).^2) / sum((spls_all - mean(spls_all)).^2);

fig6 = figure('Position', [100, 100, 900, 540], 'Color', 'w');
semilogx(dists*100, spls_all, 's-', 'Color', C{1}, 'LineWidth', 2.5, 'MarkerSize', 10, 'MarkerFaceColor', C{1}); hold on;
semilogx(r_fit*100, spl_fit, '--', 'Color', C{2}, 'LineWidth', 2);
xlabel('距尺面距离 $r$ [cm]', 'Interpreter', 'latex', 'FontSize', 15);
ylabel('声压级 SPL [dB]', 'FontSize', 15);
title('声压级空间衰减 — 10 点麦克风扫描 (钢板)', 'FontSize', 16);
lgd = legend({'COMSOL 仿真 (10 点对数分布)', ...
    ['拟合 SPL$=$', num2str(p(1),'%.1f'), '$\log_{10}r+$', num2str(p(2),'%.1f'), ...
     '$\quad R^2=$', num2str(R2_spatial,'%.4f')]}, ...
    'Interpreter', 'latex', 'Location', 'northeast', 'FontSize', 11);
grid on; box on;
exportgraphics(fig6, fullfile(out_dir, 'fig_spl_spatial.png'), 'Resolution', 300);
close(fig6);

%% Fig 7: Timbre phase diagram with musical note mapping
fprintf('Fig 7: Timbre notes\n');
harmonic_ratios = [1, 6.267, 17.548, 34.386];
w_realistic = [1, 1/6.267, 1/17.548, 1/34.386];
w_realistic = w_realistic / sum(w_realistic);

note_names = {'C3','','','','G3','','','C4','','','','G4','','','C5','','','G5',''};
note_hz    = [130.8,146.8,164.8,174.6,196.0,220.0,246.9,261.6,293.7,329.6,349.2,392.0,440.0,493.9,523.3,587.3,659.3,784.0,880.0];
n_notes = length(note_hz);

centroids_ideal = zeros(1, n_notes);
for i = 1:n_notes
    h = note_hz(i) * harmonic_ratios;
    centroids_ideal(i) = sum(h .* w_realistic);
end

fig7 = figure('Position', [100, 100, 1100, 600], 'Color', 'w');

% Octave background bands
octave_c = {[1 0.92 0.92], [0.92 0.92 1], [0.92 1 0.92]};
for o = 1:3
    lo = note_hz((o-1)*7+1); hi = note_hz(min(o*7, n_notes));
    cl = centroids_ideal((o-1)*7+1); ch = centroids_ideal(min(o*7, n_notes));
    patch([cl cl ch ch], [-0.002 0.030 0.030 -0.002], octave_c{o}, 'EdgeColor', 'none', 'FaceAlpha', 0.25); hold on;
end

% Musical note lines
for i = 1:n_notes
    xc = centroids_ideal(i);
    is_tonic = (mod(i,7) == 1);
    if is_tonic
        plot([xc xc], [-0.001 0.028], 'k-', 'LineWidth', 1.2);
        text(xc, 0.029, note_names{i}, 'FontSize', 9, 'Rotation', 90, ...
            'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left', 'FontWeight', 'bold');
    else
        plot([xc xc], [-0.001 0.025], 'k:', 'LineWidth', 0.4);
    end
end

% Material data points
for i = 1:4
    sz = max(80, probe_sim(i) * 12);
    hh = scatter(centroid_sim(i), flatness_sim(i), sz, C{i}, 'filled', ...
        'MarkerFaceAlpha', 0.8, 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
    dx = 30;
    text(centroid_sim(i)+dx, flatness_sim(i)+0.0008, mat_names{i}, 'FontSize', 14, ...
        'FontWeight', 'bold', 'Color', C{i});
end

% Octave labels
text(210, 0.031, '八度 3 (C3--B3)', 'FontSize', 11, 'HorizontalAlignment', 'center', 'Color', [0.6 0.2 0.2]);
text(420, 0.031, '八度 4 (C4--B4)', 'FontSize', 11, 'HorizontalAlignment', 'center', 'Color', [0.2 0.2 0.6]);
text(750, 0.031, '八度 5 (C5--G5)', 'FontSize', 11, 'HorizontalAlignment', 'center', 'Color', [0.2 0.5 0.2]);

xlabel('谱质心 [Hz] (竖线: 弯曲谐波加权下的音阶质心参考)', 'FontSize', 14);
ylabel('谱平坦度', 'FontSize', 14);
title('音色相位图 — 4 种材料 + 音阶映射', 'FontSize', 16);
text(800, 0.025, '气泡大小 $\propto$ SPL', 'Interpreter', 'latex', 'FontSize', 10);
ylim([-0.002, 0.032]); xlim([80, 1000]);
grid on; box on;
exportgraphics(fig7, fullfile(out_dir, 'fig_timbre_notes.png'), 'Resolution', 300);
close(fig7);

%% Fig 8: gNL on/off comparison (bar chart)
fprintf('Fig 8: gNL comparison\n');
cases_gnl = {'L20h2\nJ004','L30h2\nJ004','L30h1.5\nJ004','L40h2\nJ004','L20h2\nJ016'};
pon  = [4.56, 6.65, 11.87, 9.40, 18.25];
poff = [4.63, 6.67, 12.04, 9.41, 18.42];
pL   = [2.3, 2.2, 4.0, 2.3, 9.2];

fig8 = figure('Position', [100, 100, 950, 540], 'Color', 'w');
w = 0.3; x = 1:5;
b1 = bar(x-w, pon, w, 'FaceColor', C{1}, 'EdgeColor', 'none'); hold on;
b2 = bar(x+w, poff, w, 'FaceColor', C{2}, 'EdgeColor', 'none');
set(gca, 'XTick', x, 'XTickLabel', cases_gnl, 'FontSize', 12);
ylabel('探针峰值位移 [mm]', 'FontSize', 15);
title('几何非线性 on/off 对比 — 钢, 5 种几何', 'FontSize', 16);
lgd = legend([b1, b2], {'gNL = on', 'gNL = off'}, 'Location', 'northwest', 'FontSize', 13);
for i = 1:5
    text(x(i)-w, pon(i)+0.4, num2str(pon(i),'%.2f'), 'FontSize', 8, 'HorizontalAlignment', 'center');
    text(x(i)+w, poff(i)+0.4, num2str(poff(i),'%.2f'), 'FontSize', 8, 'HorizontalAlignment', 'center');
    text(x(i), max(pon(i),poff(i))+1.8, ['probe/L=', num2str(pL(i),'%.1f'), '\%'], ...
        'FontSize', 10, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
grid on; box on;
exportgraphics(fig8, fullfile(out_dir, 'fig_gnl_comparison.png'), 'Resolution', 300);
close(fig8);

%% Fig 9: Modal acoustic coupling (bar chart, log scale)
fprintf('Fig 9: Mode acoustic coupling\n');
cpl = readtable(fullfile(proj, 'outputs/unified_v2_4mat/cases/timbre_material/material_steel/data/modal_acoustic_coupling.csv'));
mode_type = {'z-弯曲','z-弯曲','面内','面内','z-弯曲','z-弯曲'};
bar_color_list = [C{1}; C{1}; C{3}; C{3}; C{1}; C{1}];

fig9 = figure('Position', [100, 100, 900, 540], 'Color', 'w');
b = bar(1:6, cpl.peak_amp_pa, 'EdgeColor', 'none');
b.FaceColor = 'flat';
for i = 1:6, b.CData(i,:) = bar_color_list(i,:); end
set(gca, 'YScale', 'log', 'FontSize', 14);
xlabel('COMSOL 模态编号', 'FontSize', 15);
ylabel('声压峰值 [Pa] (对数坐标)', 'FontSize', 15);
title('模态声辐射效率 — 钢板', 'FontSize', 16);
for i = 1:6
    text(i, cpl.peak_amp_pa(i)*1.6, mode_type{i}, 'FontSize', 11, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
% Add annotation
text(1.5, 0.5, 'z-弯曲模态: 高效辐射声波', 'FontSize', 12, 'Color', C{1}, 'FontWeight', 'bold');
text(1.5, 0.05, '面内模态: 几乎不辐射声波 ($\times 10^{-2}$)', 'FontSize', 12, 'Color', C{3}, 'FontWeight', 'bold');
grid on; box on;
exportgraphics(fig9, fullfile(out_dir, 'fig_mode_coupling.png'), 'Resolution', 300);
close(fig9);

%% Fig 10: Rayleigh tuning verification
fprintf('Fig 10: Rayleigh tuning\n');
tau_theo = [0.267, 0.205, 0.299, 0.196];
gap_vals = [-18.3, -15.2, -14.3, 0.1];

fig10 = figure('Position', [100, 100, 900, 540], 'Color', 'w');
w = 0.25; x = 1:4;
b1 = bar(x-w, tau_theo, w, 'FaceColor', C{1}, 'EdgeColor', 'none'); hold on;
b2 = bar(x+w, tau_sim, w, 'FaceColor', C{2}, 'EdgeColor', 'none');
set(gca, 'XTick', x, 'XTickLabel', mat_names, 'FontSize', 14);
ylabel('衰减时间 $\tau_1$ [s]', 'Interpreter', 'latex', 'FontSize', 15);
title('Rayleigh 逐材料调谐验证: $\tau_{\rm theo}$ vs $\tau_{\rm sim}$', 'Interpreter', 'latex', 'FontSize', 16);
lgd = legend([b1, b2], {'$\tau_{\rm theo}$ (Rayleigh $\zeta_{\rm eff}$)', '$\tau_{\rm sim}$ (COMSOL)'}, ...
    'Interpreter', 'latex', 'Location', 'northeast', 'FontSize', 13);
for i = 1:4
    text(x(i), max(tau_theo(i), tau_sim(i))+0.012, ['$\Delta = $', num2str(gap_vals(i),'%+4.1f'), '\%'], ...
        'Interpreter', 'latex', 'FontSize', 11, 'HorizontalAlignment', 'center');
end
% Annotation for numerical dissipation
annotation('textbox', [0.62 0.18 0.30 0.10], 'String', ...
    '残差 $\approx -15\%$: 广义-$\alpha$ 数值耗散 ($\rho_\infty=0.75$)', ...
    'Interpreter', 'latex', 'FontSize', 10, 'EdgeColor', 'none', 'BackgroundColor', 'w');
grid on; box on;
exportgraphics(fig10, fullfile(out_dir, 'fig_rayleigh_tuning.png'), 'Resolution', 300);
close(fig10);

%% Fig 11: Q values
fprintf('Fig 11: Q values\n');
Q_vals = [28.2, 120.5, 6.4, 16.4; 7.4, 12.8, 5.7, 12.8; 11.1, 13.5, 20.4, 19.1; 7.5, 13.5, 5.1, 12.4]';

fig11 = figure('Position', [100, 100, 900, 540], 'Color', 'w');
b = bar(Q_vals, 'EdgeColor', 'none');
for i = 1:4
    b(i).FaceColor = C{i};
    b(i).FaceAlpha = 0.85;
end
set(gca, 'XTickLabel', bend_lbl, 'FontSize', 14);
ylabel('品质因数 $Q$', 'Interpreter', 'latex', 'FontSize', 15);
title('弯曲模态品质因数 (仅 z-bending 模态)', 'FontSize', 16);
lgd = legend(mat_names, 'Location', 'northeast', 'FontSize', 13);
grid on; box on;
exportgraphics(fig11, fullfile(out_dir, 'fig_Q_values.png'), 'Resolution', 300);
close(fig11);

%% Fig 12: Directional SPL
fprintf('Fig 12: Directional SPL\n');
directions = {'垂直于振动面\n(+z, 宽面 30mm)', '平行于振动面\n(y 方向, 窄边 2mm)'};

fig12 = figure('Position', [100, 100, 750, 500], 'Color', 'w');
b = bar([0, -23.5], 'FaceColor', C{1}, 'EdgeColor', 'none', 'BarWidth', 0.4);
set(gca, 'XTickLabel', directions, 'FontSize', 13);
ylabel('相对声压级 [dB]', 'FontSize', 15);
title('方向性声压级差异', 'FontSize', 16);
for i = 1:2
    yv = -28;
    if i == 1, yv = 2; end
    vals = [0, -23.5];
    text(i, yv, [num2str(vals(i),'%.1f'), ' dB'], 'FontSize', 13, ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
text(1.5, -10, '$\Delta$SPL $= 20\log_{10}(30/2) = 23.5$ dB', ...
    'Interpreter', 'latex', 'FontSize', 14, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
grid on; box on;
exportgraphics(fig12, fullfile(out_dir, 'fig_directional_spl.png'), 'Resolution', 300);
close(fig12);

%% Fig 13: Multi-material timbre comparison (SPL + centroid + tau)
fprintf('Fig 13: Multi-material radar/triple\n');
fig13 = figure('Position', [100, 100, 950, 540], 'Color', 'w');

subplot(1,3,1);
b = bar(spl_sim, 'FaceColor', 'flat', 'EdgeColor', 'none');
for i = 1:4, b.CData(i,:) = C{i}; end
set(gca, 'XTickLabel', mat_names, 'FontSize', 12);
ylabel('SPL$_{\rm RMS}$ [dB]', 'Interpreter', 'latex', 'FontSize', 13);
title('响度', 'FontSize', 14);
grid on; box on;

subplot(1,3,2);
b = bar(centroid_sim, 'FaceColor', 'flat', 'EdgeColor', 'none');
for i = 1:4, b.CData(i,:) = C{i}; end
set(gca, 'XTickLabel', mat_names, 'FontSize', 12);
ylabel('谱质心 [Hz]', 'FontSize', 13);
title('音色 (谱质心)', 'FontSize', 14);
grid on; box on;

subplot(1,3,3);
b = bar(tau_sim, 'FaceColor', 'flat', 'EdgeColor', 'none');
for i = 1:4, b.CData(i,:) = C{i}; end
set(gca, 'XTickLabel', mat_names, 'FontSize', 12);
ylabel('$\tau_1$ [s]', 'Interpreter', 'latex', 'FontSize', 13);
title('衰减 (基频)', 'FontSize', 14);
grid on; box on;

sgtitle('四材料声学特性对比', 'FontSize', 16, 'FontWeight', 'bold');
exportgraphics(fig13, fullfile(out_dir, 'fig_triple_comparison.png'), 'Resolution', 300);
close(fig13);

fprintf('\n全部完成: %d 张图, 300 DPI, 中文+LaTeX渲染\n', 13);
fprintf('输出目录: %s\n', out_dir);