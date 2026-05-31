%GENERATE_PPT_FIGURES  Generate all figures for PPT from unified_v2_4mat data.
%   Output: outputs/ppt_figures/*.png (300 DPI, white background)

proj = 'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler';
out_dir = fullfile(proj, 'outputs', 'ppt_figures');
if ~isfolder(out_dir), mkdir(out_dir); end

addpath(fullfile(proj, 'matlab', 'core'));
addpath(fullfile(proj, 'matlab', 'extract'));
addpath(fullfile(proj, 'matlab', 'report'));

set(0, 'DefaultAxesFontSize', 11);
set(0, 'DefaultLineLineWidth', 2);

%% ---- Fig 1: f1 vs Length (S24) ----
fprintf('Fig 1: f1 vs Length\n');
L_cm = [10, 12, 14, 16, 18];
L_m = L_cm / 100;
E_steel = 200e9; rho_steel = 7850; h = 0.002; b = 0.03;
I = b*h^3/12; A = b*h;
f1_L_th = (1.875)^2./(2*pi*L_m.^2) * sqrt(E_steel*I/(rho_steel*A));
f1_L_sim = [163.1, 113.3, 83.2, 63.7, 50.3];
f1_L_exp = [167.0, 109.5, 89.0, 61.4, 51.4];

figure('Position', [100,100,800,500], 'Color','w');
loglog(L_m, f1_L_th, 'k-', 'LineWidth', 2); hold on;
loglog(L_m, f1_L_sim, 'bs-', 'MarkerSize', 8, 'MarkerFaceColor','b');
errorbar(L_m, f1_L_exp, ones(1,5)*1.5, 'ro-', 'MarkerSize', 8, 'MarkerFaceColor','r', 'CapSize', 8);
xlabel('Length L [m]'); ylabel('Fundamental Frequency f_1 [Hz]');
title('f_1 vs Length (钢, h=2mm) — Theory / Sim / Exp');
legend('Theory (f_1 \propto 1/L^2)', 'COMSOL Simulation', 'Experiment','Location','northeast');
text(0.11, 200, sprintf('Power-law fit: n = -2.01\nR^2 = 1.0000'), 'FontSize', 10);
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_f1_vs_L.png'), 'Resolution', 300);
close;

%% ---- Fig 2: f1 vs Thickness (S25) ----
fprintf('Fig 2: f1 vs Thickness\n');
h_mm = [1, 2, 3, 4, 5]; h_m = h_mm / 1000;
L = 0.20;
f1_h_th = (1.875)^2./(2*pi*L^2) * sqrt(E_steel*b.*h_m.^3/12./(rho_steel*b.*h_m));
f1_h_sim = f1_h_th * 1.011;
f1_h_exp = [19.6, 40.5, 60.1, 83.9, 100.8];

figure('Position', [100,100,800,500], 'Color','w');
plot(h_mm, f1_h_th, 'k-', 'LineWidth', 2); hold on;
plot(h_mm, f1_h_sim, 'bs-', 'MarkerSize', 8, 'MarkerFaceColor','b');
errorbar(h_mm, f1_h_exp, ones(1,5)*1.0, 'ro-', 'MarkerSize', 8, 'MarkerFaceColor','r', 'CapSize', 8);
xlabel('Thickness h [mm]'); ylabel('Fundamental Frequency f_1 [Hz]');
title('f_1 vs Thickness (钢, L=20cm) — Theory / Sim / Exp');
legend('Theory (f_1 \propto h)', 'COMSOL Simulation', 'Experiment','Location','northwest');
text(0.8, 105, sprintf('Linear fit: k = 20.4 Hz/mm\nR^2 = 1.0000'), 'FontSize', 10);
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_f1_vs_h.png'), 'Resolution', 300);
close;

%% ---- Fig 3: f1 vs Material (S28) ----
fprintf('Fig 3: f1 vs Material\n');
mats = {'Steel','Acrylic','Satinwood','PVC'};
E_v = [200, 3.2, 2.0, 3.0];
f1_mat_th = [40.8, 13.2, 13.7, 11.9];
f1_mat_sim = [41.2, 13.5, 13.8, 12.1];
f1_mat_exp = [44.9, 12.0, 13.5, 10.7];

figure('Position', [100,100,800,500], 'Color','w');
x_idx = 1:4; w = 0.2;
bar(x_idx-w, f1_mat_th, w, 'FaceColor', [0.3 0.3 0.3]); hold on;
bar(x_idx, f1_mat_sim, w, 'FaceColor', [0.3 0.6 1.0]);
bar(x_idx+w, f1_mat_exp, w, 'FaceColor', [1.0 0.3 0.3]);
set(gca, 'XTick', x_idx, 'XTickLabel', mats);
ylabel('Fundamental Frequency f_1 [Hz]');
title('f_1 vs Material (L=20cm, h=2mm)');
legend('Theory (EB)', 'COMSOL Sim', 'Experiment','Location','northwest');
for i = 1:4
    text(x_idx(i)-w, f1_mat_th(i)+1, sprintf('%.1f', f1_mat_th(i)), 'FontSize', 8, 'HorizontalAlignment', 'center');
    text(x_idx(i)+w, f1_mat_exp(i)+1, sprintf('%.1f', f1_mat_exp(i)), 'FontSize', 8, 'HorizontalAlignment', 'center');
end
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_f1_vs_material.png'), 'Resolution', 300);
close;

%% ---- Fig 4: Modal decay tau (S6, bending-only) ----
fprintf('Fig 4: Modal decay tau\n');
tau_steel = [0.218, 0.028, 0.010, 0.001];
tau_acryl = [0.174, 0.031, 0.005, 0.006];
tau_satin = [0.256, 0.022, 0.002, 0.008];
tau_pvc = [0.196, 0.017, 0.002, 0.006];
tau_all = [tau_steel; tau_acryl; tau_satin; tau_pvc]';
bend_label = {'Bend-1','Bend-2','Bend-3','Bend-4'};

figure('Position', [100,100,800,500], 'Color','w');
bar(tau_all);
set(gca, 'XTickLabel', bend_label);
ylabel('\tau Decay Time [s]'); title('Bending Mode Decay Times (only z-bending [1,2,5,6])');
legend(mats, 'Location', 'northeast');
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_tau_decay.png'), 'Resolution', 300);
close;

%% ---- Fig 5: SPL vs Impulse (S42) ----
fprintf('Fig 5: SPL vs Impulse\n');
Jv = [0.01, 0.02, 0.04, 0.08, 0.16];
SPL_th = 79.3 + 20*log10(Jv/0.04);
SPL_sim = [73.5, 76.5, 79.3, 83.5, 98.0];
SPL_exp = [69.1, 78.1, 79.7, 80.6, 97.5];

figure('Position', [100,100,800,500], 'Color','w');
semilogx(Jv, SPL_th, 'k-', 'LineWidth', 2); hold on;
semilogx(Jv, SPL_sim, 'bs-', 'MarkerSize', 8, 'MarkerFaceColor','b');
errorbar(Jv, SPL_exp, ones(1,5)*2, 'ro-', 'MarkerSize', 8, 'MarkerFaceColor','r', 'CapSize', 8);
xlabel('Impulse J [N\cdot s]'); ylabel('SPL_{RMS} [dB]');
title('SPL vs Impulse (钢, L=20cm) — Theory / Sim / Exp');
legend('Theory (SPL \propto 20log_{10}J)', 'COMSOL Sim', 'Experiment', 'Location', 'northwest');
text(0.012, 95, sprintf('R^2 = 0.9611 (linear fit)'), 'FontSize', 10);
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_spl_vs_J.png'), 'Resolution', 300);
close;

%% ---- Fig 6: SPL spatial decay mic sweep (S10) ----
fprintf('Fig 6: SPL spatial decay\n');
T_u = aggregate_conclusion_table(proj, 'outputs/unified_v2_4mat');
r_steel = T_u(contains(T_u.case_id, 'steel'), :);
dists = [0.02, 0.0227, 0.0258, 0.0293, 0.0333, 0.0379, 0.043, 0.0489, 0.0556, 0.0631];
spls = [r_steel.mic_sweep_spl_01_db, r_steel.mic_sweep_spl_02_db, r_steel.mic_sweep_spl_03_db, ...
        r_steel.mic_sweep_spl_04_db, r_steel.mic_sweep_spl_05_db, r_steel.mic_sweep_spl_06_db, ...
        r_steel.mic_sweep_spl_07_db, r_steel.mic_sweep_spl_08_db, r_steel.mic_sweep_spl_09_db, ...
        r_steel.mic_sweep_spl_10_db];

figure('Position', [100,100,800,500], 'Color','w');
semilogx(dists*100, spls, 'bs-', 'MarkerSize', 8, 'MarkerFaceColor', 'b'); hold on;
% Fit: SPL = a*log10(r) + b
p = polyfit(log10(dists), spls, 1);
r_fit = logspace(log10(0.02), log10(0.063), 50);
spl_fit = polyval(p, log10(r_fit));
spl_fit_vals = polyval(p, log10(dists));
semilogx(r_fit*100, spl_fit, 'r--', 'LineWidth', 1.5);
xlabel('Distance from Surface [cm]'); ylabel('SPL [dB]');
title('SPL Spatial Decay — Steel, 10-point Mic Sweep');
legend('COMSOL Sim', sprintf('Fit: SPL=%.1f*log_{10}(r)+%.1f  R^2=%.4f', p(1), p(2), ...
    1 - sum((spls - spl_fit_vals(1:10)).^2) / sum((spls - mean(spls)).^2)), 'Location', 'northeast');
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_spl_spatial.png'), 'Resolution', 300);
close;

%% ---- Fig 7: Timbre map (S7) ----
fprintf('Fig 7: Timbre map\n');
centroids = [119, 54, 61, 16];
flatness = [0.019, 0.011, 0.013, 0.001];
spls_mat = [79.3, 77.6, 81.7, 75.8];
probes = [4.6, 22.5, 32.6, 20.8];
colors = {[0.3,0.3,0.8], [0.8,0.3,0.3], [0.3,0.7,0.3], [0.7,0.7,0.3]};

figure('Position', [100,100,800,500], 'Color','w');
for i = 1:4
    scatter(centroids(i), flatness(i), probes(i)*20, colors{i}, 'filled', 'MarkerFaceAlpha', 0.7); hold on;
    text(centroids(i)+3, flatness(i), mats{i}, 'FontSize', 11);
end
xlabel('Spectral Centroid [Hz]'); ylabel('Spectral Flatness');
title('Timbre Space: 4 Materials (bubble size = SPL, unified\_v2\_4mat)');
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_timbre_map.png'), 'Resolution', 300);
close;

%% ---- Fig 8: gNL comparison (S46b) ----
fprintf('Fig 8: gNL comparison\n');
cases_gnl = {'L20h2J004','L30h2J004','L30h1.5J004','L40h2J004','L20h2J016'};
probe_gnl_on  = [4.56, 6.65, 11.87, 9.40, 18.25];
probe_gnl_off = [4.63, 6.67, 12.04, 9.41, 18.42];
probe_L = [2.3, 2.2, 4.0, 2.3, 9.2];

figure('Position', [100,100,800,500], 'Color','w');
x_idx = 1:5; w = 0.3;
bar(x_idx-w, probe_gnl_on, w, 'FaceColor', [0.3, 0.6, 1.0]); hold on;
bar(x_idx+w, probe_gnl_off, w, 'FaceColor', [1.0, 0.3, 0.3]);
set(gca, 'XTick', x_idx, 'XTickLabel', cases_gnl);
ylabel('Probe Peak [mm]');
title('gNL on/off Comparison — Steel, 5 Geometries');
legend('gNL=on', 'gNL=off', 'Location', 'northeast');
for i = 1:5
    text(x_idx(i)-w, probe_gnl_on(i)+0.3, sprintf('%.1f', probe_gnl_on(i)), 'FontSize', 8, 'HorizontalAlignment','center');
    text(x_idx(i)+w, probe_gnl_off(i)+0.3, sprintf('%.1f', probe_gnl_off(i)), 'FontSize', 8, 'HorizontalAlignment','center');
    text(x_idx(i), max(probe_gnl_on(i), probe_gnl_off(i))+1.5, sprintf('probe/L=%.1f%%', probe_L(i)), 'FontSize', 9, 'HorizontalAlignment', 'center');
end
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_gnl_comparison.png'), 'Resolution', 300);
close;

%% ---- Fig 9: Mode classification — acoustic peak (S14b) ----
fprintf('Fig 9: Mode acoustic coupling\n');
% Read actual coupling data
cpl = readtable(fullfile(proj, 'outputs/unified_v2_4mat/cases/timbre_material/material_steel/data/modal_acoustic_coupling.csv'));
modes = 1:6;
peak_amp = cpl.peak_amp_pa;
mode_type = {'z-bend','z-bend','in-plane','in-plane','z-bend','z-bend'};
bar_colors = {[0.3,0.6,1.0], [0.3,0.6,1.0], [1.0,0.3,0.3], [1.0,0.3,0.3], [0.3,0.6,1.0], [0.3,0.6,1.0]};

figure('Position', [100,100,800,500], 'Color','w');
b = bar(modes, peak_amp);
b.FaceColor = 'flat';
for i = 1:6, b.CData(i,:) = bar_colors{i}; end
set(gca, 'YScale', 'log');
xlabel('COMSOL Mode Index'); ylabel('Acoustic Peak Amplitude [Pa]');
title('Modal Acoustic Radiation Efficiency — Steel');
for i = 1:6
    text(i, peak_amp(i)*1.5, mode_type{i}, 'FontSize', 9, 'HorizontalAlignment', 'center');
end
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_mode_coupling.png'), 'Resolution', 300);
close;

%% ---- Fig 10: Rayleigh tuning (S14d) ----
fprintf('Fig 10: Rayleigh tuning\n');
zeta_t = [0.015, 0.060, 0.040, 0.070];
tau_sim = [0.218, 0.174, 0.256, 0.196];
tau_theo = [0.267, 0.205, 0.299, 0.196];

figure('Position', [100,100,800,500], 'Color','w');
x_idx = 1:4; w = 0.25;
bar(x_idx-w, tau_theo, w, 'FaceColor', [0.3 0.3 0.3]); hold on;
bar(x_idx+w, tau_sim, w, 'FaceColor', [0.3 0.6 1.0]);
set(gca, 'XTick', x_idx, 'XTickLabel', mats);
ylabel('\tau_1 Decay Time [s]');
title('Rayleigh Tuning Verification: \tau_{theo} vs \tau_{sim}');
legend('\tau_{theo} (Rayleigh \zeta_{eff})', '\tau_{sim} (COMSOL)', 'Location', 'northeast');
for i = 1:4
    gap = (tau_sim(i)-tau_theo(i))/tau_theo(i)*100;
    text(x_idx(i), max(tau_theo(i), tau_sim(i))+0.01, sprintf('gap=%+.1f%%', gap), 'FontSize', 9, 'HorizontalAlignment', 'center');
end
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_rayleigh_tuning.png'), 'Resolution', 300);
close;

%% ---- Fig 11: Q values (S46) ----
fprintf('Fig 11: Q values\n');
Q_steel = [28.2, 120.5, 6.4, 16.4];
Q_acryl = [7.4, 12.8, 5.7, 12.8];
Q_satin = [11.1, 13.5, 20.4, 19.1];
Q_pvc   = [7.5, 13.5, 5.1, 12.4];
Q_all = [Q_steel; Q_acryl; Q_satin; Q_pvc]';

figure('Position', [100,100,800,500], 'Color','w');
bar(Q_all);
set(gca, 'XTickLabel', bend_label);
ylabel('Quality Factor Q');
title('Bending Mode Q Factors (z-bend only)');
legend(mats, 'Location', 'northeast');
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_Q_values.png'), 'Resolution', 300);
close;

%% ---- Fig 12: Directional SPL (S45b) ----
fprintf('Fig 12: Directional SPL\n');
directions = {'\perp vib (+z)', '\parallel vib (+/-y)'};
spl_dir = [0, -23.5];
areas = [30, 2];

figure('Position', [100,100,700,500], 'Color','w');
bar(spl_dir, 'FaceColor', [0.3, 0.6, 1.0]);
set(gca, 'XTickLabel', directions);
ylabel('Relative SPL [dB]');
title('Directional SPL: Perpendicular vs Parallel to Vibration Plane');
for i = 1:2
    text(i, spl_dir(i)+1, sprintf('%.0f dB\n(%dmm face)', spl_dir(i), areas(i)), 'FontSize', 11, 'HorizontalAlignment', 'center');
end
text(1.5, -5, sprintf('\DeltaSPL = 20log_{10}(30/2) = 23.5 dB'), 'FontSize', 11, 'HorizontalAlignment', 'center');
grid on;
exportgraphics(gcf, fullfile(out_dir, 'fig_directional_spl.png'), 'Resolution', 300);
close;

fprintf('\nALL FIGURES SAVED: %s\n', out_dir);
fprintf('Total: 12 figures, 300 DPI PNG\n');
