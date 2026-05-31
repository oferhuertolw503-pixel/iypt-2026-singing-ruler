%ANIMATE_RULER_VIBRATION  Generate animated GIF via modal superposition.
%   No toolboxes required — uses FFT-based band-pass filtering.
%   Output: outputs/unified_v2_4mat/animation/ruler_vibration_steel.gif

proj_root = 'C:\Users\OMEN.LAPTOP-8C8PH934\code\cupt\the_singing_ruler';
material_name = 'steel';
framerate = 25;
duration_s = 0.3;

data_dir = fullfile(proj_root, 'outputs', 'unified_v2_4mat', 'cases', ...
    'timbre_material', sprintf('material_%s', material_name), 'data');
out_dir = fullfile(proj_root, 'outputs', 'unified_v2_4mat', 'animation');
if ~isfolder(out_dir), mkdir(out_dir); end

% --- Load data ---
opts = detectImportOptions(fullfile(data_dir, 'mode_shapes.csv'), 'FileType', 'text');
opts.VariableNamingRule = 'preserve';
for ii = 1:numel(opts.VariableTypes), opts = setvartype(opts, ii, 'double'); end
mode_tbl = readtable(fullfile(data_dir, 'mode_shapes.csv'), opts);

opts = detectImportOptions(fullfile(data_dir, 'structure_probe_timeseries.csv'), 'FileType', 'text');
opts.VariableNamingRule = 'preserve';
for ii = 1:numel(opts.VariableTypes), opts = setvartype(opts, ii, 'double'); end
probe_tbl = readtable(fullfile(data_dir, 'structure_probe_timeseries.csv'), opts);

opts = detectImportOptions(fullfile(data_dir, 'frequencies.csv'), 'FileType', 'text');
opts.VariableNamingRule = 'preserve';
for ii = 1:numel(opts.VariableTypes), opts = setvartype(opts, ii, 'double'); end
freq_tbl = readtable(fullfile(data_dir, 'frequencies.csv'), opts);

x_rel = mode_tbl{:, 1};
phi_all = mode_tbl{:, 2:end};
t_s = probe_tbl{:, 1};
uz_probe = probe_tbl{:, 2};
freqs = freq_tbl{:, 2};
f1 = freqs(1);

L = 0.20;
x_m = x_rel * L;
[~, probe_idx] = min(abs(x_rel - 0.8));
dt = t_s(2) - t_s(1);
n_modes = min(6, width(mode_tbl) - 1);

% --- FFT-based band-pass filter per mode ---
N = length(t_s);
freq_fft = (0:N-1)' / (N*dt);  % frequency axis
Uz_fft = fft(uz_probe);

q_scaled = zeros(length(t_s), n_modes);

for k = 1:n_modes
    if k > length(freqs), continue; end
    fc = freqs(k);
    f_low = 0.7 * fc;
    f_high = 1.3 * fc;

    % Create symmetric band-pass mask in frequency domain
    mask = zeros(N, 1);
    for jj = 1:N
        fj = freq_fft(jj);
        if fj > 0.5/dt, fj = 1/dt - fj; end  % fold back Nyquist
        if fj >= f_low && fj <= f_high
            mask(jj) = 1;
        end
    end

    q_raw = real(ifft(Uz_fft .* mask));

    phi_at_probe = phi_all(probe_idx, k);
    if abs(phi_at_probe) > 1e-15
        q_scaled(:, k) = q_raw / phi_at_probe;
    end
end

% --- Reconstruct full-field displacement ---
bending_idx = [1, 2, 5, 6];
uz_full = zeros(length(t_s), length(x_rel));
for k = bending_idx
    uz_full = uz_full + q_scaled(:, k) * phi_all(:, k)';
end

% --- Generate animated GIF ---
t_anim = 0 : 1/framerate : duration_s;
frame_indices = round(t_anim / dt) + 1;
frame_indices(frame_indices > length(t_s)) = length(t_s);

gif_path = fullfile(out_dir, sprintf('ruler_vibration_%s.gif', material_name));
fig = figure('Position', [100, 100, 900, 400], 'Color', 'white', 'Visible', 'off');
u_amp = max(abs(uz_full(:)));
if u_amp < 1e-12, u_amp = 1e-6; end
yrange = [-u_amp * 60, u_amp * 60];

for f = 1:length(frame_indices)
    clf;
    tidx = frame_indices(f);
    u = uz_full(tidx, :)' * 50;  % column vector

    xx = [x_m(:); flipud(x_m(:))];
    yy = [u(:); zeros(length(u), 1)];
    fill(xx, yy, ...
        [0.3, 0.6, 1.0], 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    hold on;
    plot(x_m, zeros(size(x_m(:))), 'k--', 'LineWidth', 0.5);
    plot(x_m, u, 'b-', 'LineWidth', 2);
    plot(x_m(probe_idx), u(probe_idx), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    hold off;

    xlabel('x [m]'); ylabel('50x Displacement');
    title(sprintf('Steel Ruler  t=%.3fs  f_1=%.0fHz', t_s(tidx), f1));
    ylim(yrange); xlim([0, L]); grid on;

    frame = getframe(fig);
    im = frame2im(frame);
    [imind, cm] = rgb2ind(im, 256);
    if f == 1
        imwrite(imind, cm, gif_path, 'gif', 'Loopcount', inf, 'DelayTime', 1/framerate);
    else
        imwrite(imind, cm, gif_path, 'gif', 'WriteMode', 'append', 'DelayTime', 1/framerate);
    end
end

close(fig);
fprintf('Animation saved: %s (%d frames)\n', gif_path, length(frame_indices));
