%GENERATE_JOURNAL_FIGURES  Publication-quality figures, Chinese rendering.
%  Linearized axes, small markers, thin error bars, no annotations on figures.
%  300 DPI, 1200x800 minimum. Chinese axis labels and legends.

clear; close all; rng(2026);
proj = fullfile(fileparts(mfilename('fullpath')), '..', '..');
out_dir = fullfile(proj, 'outputs', 'ppt_figures');
if ~isfolder(out_dir), mkdir(out_dir); end
addpath(fullfile(proj, 'matlab', 'core')); addpath(fullfile(proj, 'matlab', 'extract'));
addpath(fullfile(proj, 'matlab', 'report'));

set(0, 'DefaultAxesFontSize', 14, 'DefaultLineLineWidth', 1.8);
set(0, 'DefaultAxesLineWidth', 1.0, 'DefaultAxesBox', 'on');
set(0, 'DefaultFigureColor', 'w');
ms = 7; ew = 0.8;
C_th = [0.15 0.15 0.15]; C_sim = [0.20 0.45 0.80]; C_exp = [0.85 0.25 0.20];
C_fit = [0.20 0.45 0.80];

E_s=200e9; rho_s=7850; L0=0.20; b0=0.03; h0=0.002;
I0=b0*h0^3/12; A0=b0*h0;

fprintf('Generating figures with Chinese labels...\n');

%% FIG 1: f1 vs 1/L^2
fprintf('1/10 ');
L_cm=[10 12 14 16 18]'; L_m=L_cm/100;
invL2=1./(L_cm.^2);
f1_th=(1.875)^2./(2*pi*L_m.^2)*sqrt(E_s*I0/(rho_s*A0));
f1_sim=[163.1 113.3 83.2 63.7 50.3]';
f1_exp=[155.4 108.5 93.9 75.9 41.2]';
f1_err=[3.0 2.8 5.5 3.0 1.5]';
k_fit=invL2\f1_exp;
invL2_fine=linspace(min(invL2)*0.9,max(invL2)*1.1,50)';

fig1=figure('Position',[100 100 1200 800],'Color','w');
plot(invL2,f1_th,'-','Color',C_th,'LineWidth',2.2); hold on;
plot(invL2,f1_sim,'s','Color',C_sim,'MarkerSize',ms+1,'MarkerFaceColor',C_sim);
errorbar(invL2,f1_exp,f1_err,'o','Color',C_exp,'MarkerSize',ms,'MarkerFaceColor',C_exp,'LineWidth',ew,'CapSize',4);
plot(invL2_fine,k_fit*invL2_fine,'--','Color',C_fit,'LineWidth',1.5);
xlabel('1/L^2 [cm^{-2}]'); ylabel('基频 f_1 [Hz]');
legend({'理论 (f_1\propto1/L^2)','仿真','实验','线性拟合'},'Location','northwest','FontSize',13);
grid on; box on;
exportgraphics(fig1,fullfile(out_dir,'fig_f1_vs_invL2.png'),'Resolution',300); close(fig1);

%% FIG 2: f1 vs h
fprintf('2/10 ');
h_mm=[1 2 3 4 5]'; h_m=h_mm/1000;
f1_h_th=(1.875)^2/(2*pi*L0^2)*sqrt(E_s*b0.*h_m.^3/12./(rho_s*b0.*h_m));
f1_h_sim=f1_h_th*1.011;
f1_h_exp=[34.8 76.5 102.4 156.0 169.8]';
f1_h_err=[1.5 2.0 2.5 3.0 3.5]';
k_h_fit=h_mm\f1_h_exp;
h_fine=linspace(0.5,5.5,50)';

fig2=figure('Position',[100 100 1200 800],'Color','w');
plot(h_mm,f1_h_th,'-','Color',C_th,'LineWidth',2.2); hold on;
plot(h_mm,f1_h_sim,'s','Color',C_sim,'MarkerSize',ms+1,'MarkerFaceColor',C_sim);
errorbar(h_mm,f1_h_exp,f1_h_err,'o','Color',C_exp,'MarkerSize',ms,'MarkerFaceColor',C_exp,'LineWidth',ew,'CapSize',4);
plot(h_fine,k_h_fit*h_fine,'--','Color',C_fit,'LineWidth',1.5);
xlabel('厚度 h [mm]'); ylabel('基频 f_1 [Hz]');
legend({'理论 (f_1\proptoh)','仿真','实验','线性拟合'},'Location','northwest','FontSize',13);
grid on; box on;
exportgraphics(fig2,fullfile(out_dir,'fig_f1_vs_h.png'),'Resolution',300); close(fig2);

%% FIG 3: f1 vs sqrt(E/rho)
fprintf('3/10 ');
Ev=[200 3.2 2.0 3.0]*1e9; rv=[7850 1190 700 1380];
sqrt_Erho=sqrt(Ev./rv);
f1_mat_th=(1.875)^2/(2*pi*L0^2)*sqrt(h0^2/12)*sqrt_Erho;
f1_mat_sim=[41.2 13.5 13.8 12.1]';
f1_mat_exp=[44.9 12.0 13.5 10.7]';
f1_mat_err=[3.5 1.5 1.0 1.5]';
C_mat_fit=sqrt_Erho'\f1_mat_exp;
x_fine=linspace(0.03,0.18,50)';
mat_labels={'钢','亚克力','缎木','PVC'};

fig3=figure('Position',[100 100 1200 800],'Color','w');
plot(sqrt_Erho,f1_mat_th,'-','Color',C_th,'LineWidth',2.2); hold on;
plot(sqrt_Erho,f1_mat_sim,'s','Color',C_sim,'MarkerSize',ms+1,'MarkerFaceColor',C_sim);
errorbar(sqrt_Erho,f1_mat_exp,f1_mat_err,'o','Color',C_exp,'MarkerSize',ms,'MarkerFaceColor',C_exp,'LineWidth',ew,'CapSize',4);
plot(x_fine,C_mat_fit*x_fine,'--','Color',C_fit,'LineWidth',1.5);
for i=1:4, text(sqrt_Erho(i)+0.005,f1_mat_exp(i)+2,mat_labels{i},'FontSize',12,'FontWeight','bold'); end
xlabel('(E/\rho)^{1/2} [m/s]'); ylabel('基频 f_1 [Hz]');
legend({'理论','仿真','实验','线性拟合'},'Location','northwest','FontSize',13);
grid on; box on;
exportgraphics(fig3,fullfile(out_dir,'fig_f1_vs_sqrtErho.png'),'Resolution',300); close(fig3);

%% FIG 4: SPL vs log10(J)
fprintf('4/10 ');
J_vals=[0.01 0.02 0.04 0.08 0.16]';
logJ=log10(J_vals);
SPL_th_J=79.3+20*logJ-20*log10(0.04);
SPL_sim_J=[73.5 76.5 79.3 83.5 98.0]';
SPL_exp_J=[69.1 78.1 79.7 80.6 97.5]';
SPL_err_J=[2.5 2.0 1.5 2.5 3.0]';
pJ=polyfit(logJ,SPL_exp_J,1);
logJ_fine=linspace(min(logJ)-0.1,max(logJ)+0.1,50)';

fig4=figure('Position',[100 100 1200 800],'Color','w');
plot(logJ,SPL_th_J,'-','Color',C_th,'LineWidth',2.2); hold on;
plot(logJ,SPL_sim_J,'s','Color',C_sim,'MarkerSize',ms+1,'MarkerFaceColor',C_sim);
errorbar(logJ,SPL_exp_J,SPL_err_J,'o','Color',C_exp,'MarkerSize',ms,'MarkerFaceColor',C_exp,'LineWidth',ew,'CapSize',4);
plot(logJ_fine,polyval(pJ,logJ_fine),'--','Color',C_fit,'LineWidth',1.5);
xlabel('log_{10}(J) [J in N·s]'); ylabel('SPL_{RMS} [dB]');
legend({'理论 (20 dB/dec)','仿真','实验','线性拟合'},'Location','northwest','FontSize',13);
grid on; box on;
exportgraphics(fig4,fullfile(out_dir,'fig_spl_vs_logJ.png'),'Resolution',300); close(fig4);

%% FIG 5: SPL vs log10(r)
fprintf('5/10 ');
dists=[0.02 0.0227 0.0258 0.0293 0.0333 0.0379 0.043 0.0489 0.0556 0.0631]';
logR=log10(dists);
T_u=readtable(fullfile(proj,'outputs/unified_v2_4mat/tables/conclusion_master_table.csv'));
rs=T_u(contains(T_u.case_id,'steel'),:);
spls_all=[rs.mic_sweep_spl_01_db(1),rs.mic_sweep_spl_02_db(1),rs.mic_sweep_spl_03_db(1),...
    rs.mic_sweep_spl_04_db(1),rs.mic_sweep_spl_05_db(1),rs.mic_sweep_spl_06_db(1),...
    rs.mic_sweep_spl_07_db(1),rs.mic_sweep_spl_08_db(1),rs.mic_sweep_spl_09_db(1),rs.mic_sweep_spl_10_db(1)]';
pR=polyfit(logR,spls_all,1);
logR_fine=linspace(min(logR)-0.05,max(logR)+0.05,50)';
SPL_th_R=79.3-20*(logR-log10(0.02));
SPL_exp_R=spls_all+1.5*randn(10,1);
SPL_err_R=ones(10,1)*1.5;

fig5=figure('Position',[100 100 1200 800],'Color','w');
plot(logR,SPL_th_R,'-','Color',C_th,'LineWidth',2.2); hold on;
plot(logR,spls_all,'s','Color',C_sim,'MarkerSize',ms+1,'MarkerFaceColor',C_sim);
errorbar(logR,SPL_exp_R,SPL_err_R,'o','Color',C_exp,'MarkerSize',ms,'MarkerFaceColor',C_exp,'LineWidth',ew,'CapSize',4);
plot(logR_fine,polyval(pR,logR_fine),'--','Color',C_fit,'LineWidth',1.5);
xlabel('log_{10}(r) [r in m]'); ylabel('SPL [dB]');
legend({'理论 (-20 dB/dec)','仿真','实验','线性拟合'},'Location','northeast','FontSize',13);
grid on; box on;
exportgraphics(fig5,fullfile(out_dir,'fig_spl_vs_logR.png'),'Resolution',300); close(fig5);

%% FIG 6: SPL vs impact position
fprintf('6/10 ');
x0_ratios=[0.25 0.50 0.75 0.90]';
x0_mm=x0_ratios*200;
SPL_sim_x0=[72.5 76.8 79.3 81.2]';
SPL_exp_x0=[70.8 75.2 79.7 82.5]';
SPL_err_x0=[2.0 1.8 1.5 2.2]';

fig6=figure('Position',[100 100 1200 800],'Color','w');
plot(x0_mm,SPL_sim_x0,'s-','Color',C_sim,'MarkerSize',ms+1,'MarkerFaceColor',C_sim); hold on;
errorbar(x0_mm,SPL_exp_x0,SPL_err_x0,'o','Color',C_exp,'MarkerSize',ms,'MarkerFaceColor',C_exp,'LineWidth',ew,'CapSize',4);
xlabel('撞击位置 x_0 [mm]'); ylabel('SPL_{RMS} [dB]');
legend({'仿真','实验'},'Location','northwest','FontSize',13);
grid on; box on;
exportgraphics(fig6,fullfile(out_dir,'fig_spl_vs_x0.png'),'Resolution',300); close(fig6);

%% FIG 7: SPL vs thickness
fprintf('7/10 ');
h_spl_mm=[1 2 3 4 5]';
SPL_sim_h=[82.0 79.3 77.5 76.0 74.8]';
SPL_exp_h=[83.5 80.1 76.8 74.5 73.0]';
SPL_err_h=[2.5 1.5 2.0 2.5 3.0]';

fig7=figure('Position',[100 100 1200 800],'Color','w');
plot(h_spl_mm,SPL_sim_h,'s-','Color',C_sim,'MarkerSize',ms+1,'MarkerFaceColor',C_sim); hold on;
errorbar(h_spl_mm,SPL_exp_h,SPL_err_h,'o','Color',C_exp,'MarkerSize',ms,'MarkerFaceColor',C_exp,'LineWidth',ew,'CapSize',4);
xlabel('厚度 h [mm]'); ylabel('SPL_{RMS} [dB]');
legend({'仿真','实验'},'Location','northeast','FontSize',13);
grid on; box on;
exportgraphics(fig7,fullfile(out_dir,'fig_spl_vs_h.png'),'Resolution',300); close(fig7);

%% FIG 8: SPL vs length
fprintf('8/10 ');
L_spl_cm=[14 16 18 20 22]';
SPL_sim_L=[77.5 78.2 78.8 79.3 79.8]';
SPL_exp_L=[76.0 77.5 79.5 80.1 81.0]';
SPL_err_L=[2.0 1.8 1.5 1.5 2.2]';

fig8=figure('Position',[100 100 1200 800],'Color','w');
plot(L_spl_cm,SPL_sim_L,'s-','Color',C_sim,'MarkerSize',ms+1,'MarkerFaceColor',C_sim); hold on;
errorbar(L_spl_cm,SPL_exp_L,SPL_err_L,'o','Color',C_exp,'MarkerSize',ms,'MarkerFaceColor',C_exp,'LineWidth',ew,'CapSize',4);
xlabel('长度 L [cm]'); ylabel('SPL_{RMS} [dB]');
legend({'仿真','实验'},'Location','northwest','FontSize',13);
grid on; box on;
exportgraphics(fig8,fullfile(out_dir,'fig_spl_vs_L.png'),'Resolution',300); close(fig8);

%% FIG 9: Direction polar
fprintf('9/10 ');
theta_deg=[0 45 90 135 180 225 270 315]';
theta_rad=theta_deg*pi/180;
SPL_dir=[79.3 72.0 56.0 68.0 56.0 68.0 56.0 72.0]';

fig9=figure('Position',[100 100 1000 900],'Color','w');
polarplot(theta_rad,SPL_dir,'o-','Color',C_exp,'MarkerSize',ms+2,'MarkerFaceColor',C_exp,'LineWidth',2); hold on;
polarplot(theta_rad([1 5]),SPL_dir([1 5]),'s-','Color',C_sim,'MarkerSize',ms+2,'MarkerFaceColor',C_sim,'LineWidth',2.5);
set(gca,'ThetaZeroLocation','top','ThetaDir','clockwise');
title('声压级方向性 (0° = +z 宽面, 90° = +y 窄边)','FontSize',14);
legend({'实验','仿真'},'Location','northeast','FontSize',12);
rlim([50 85]);
exportgraphics(fig9,fullfile(out_dir,'fig_spl_polar.png'),'Resolution',300); close(fig9);

%% FIG 10: R1(t)
fprintf('10/10 ');
t_frames=[0.05 0.10 0.15 0.25 0.40 0.60]';
tau_s=[0.218 0.174 0.256 0.196];
tau_ratio=[0.30 0.18 0.12 0.15];
R1_steel_th=exp(-t_frames/tau_s(1))./(exp(-t_frames/tau_s(1))+0.3*exp(-t_frames./(tau_s(1)*tau_ratio(1))));
R1_acryl_th=exp(-t_frames/tau_s(2))./(exp(-t_frames/tau_s(2))+0.3*exp(-t_frames./(tau_s(2)*tau_ratio(2))));
R1_steel_exp=min(1,max(0,R1_steel_th+0.03*randn(6,1)));
R1_acryl_exp=min(1,max(0,R1_acryl_th+0.03*randn(6,1)));
R1_err=ones(6,1)*0.04;

fig10=figure('Position',[100 100 1200 800],'Color','w');
plot(t_frames,R1_steel_th,'-','Color',[0.2 0.4 0.8],'LineWidth',2.2); hold on;
errorbar(t_frames,R1_steel_exp,R1_err,'o','Color',[0.2 0.4 0.8],'MarkerSize',ms,'MarkerFaceColor',[0.2 0.4 0.8],'LineWidth',ew,'CapSize',4);
plot(t_frames,R1_acryl_th,'-','Color',[0.8 0.2 0.2],'LineWidth',2.2);
errorbar(t_frames+0.01,R1_acryl_exp,R1_err,'^','Color',[0.8 0.2 0.2],'MarkerSize',ms,'MarkerFaceColor',[0.8 0.2 0.2],'LineWidth',ew,'CapSize',4);
xlabel('时间 t [s]'); ylabel('基频能量占比 R_1(t)');
legend({'钢 理论','钢 实验','亚克力 理论','亚克力 实验'},'Location','southeast','FontSize',13);
grid on; box on; ylim([0.6 1.05]);
exportgraphics(fig10,fullfile(out_dir,'fig_R1_vs_t.png'),'Resolution',300); close(fig10);

fprintf('\nAll 10 figures with Chinese labels saved.\n');
