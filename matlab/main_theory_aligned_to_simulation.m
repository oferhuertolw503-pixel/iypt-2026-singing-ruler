function report = main_theory_aligned_to_simulation(proj_root, output_root)
%MAIN_THEORY_ALIGNED_TO_SIMULATION Compute theory tables aligned to simulation outputs.
%   report = MAIN_THEORY_ALIGNED_TO_SIMULATION()
%
%   This is a standalone theory mainline. It reads completed simulation CSV
%   outputs, computes Euler-Bernoulli/modal grey-box theory metrics with the
%   same observable columns, and writes aligned CSV/PNG/summary artifacts.
%   It does not run COMSOL and does not modify raw simulation outputs.

    if nargin < 1 || strlength(string(proj_root)) == 0
        proj_root = pwd;
    end
    if nargin < 2 || strlength(string(output_root)) == 0
        output_root = fullfile(proj_root, "outputs", "theory", "aligned_to_simulation");
    end

    addpath(fullfile(proj_root, "matlab", "core"));
    configure_plot_defaults();

    tables_dir = fullfile(output_root, "tables");
    figures_dir = fullfile(output_root, "figures");
    ensure_dir(tables_dir);
    ensure_dir(figures_dir);

    steel_csv = fullfile(proj_root, "outputs", "requested_3d_air_coarse_review_light", ...
        "tables", "all_requested_cases.csv");
    lowj_csv = fullfile(proj_root, "outputs", "requested_timbre_complete_enhanced_medium", ...
        "tables", "paper_analysis", "timbre_lowJ_primary_summary.csv");
    timbre_root = fullfile(proj_root, "outputs", "requested_timbre_complete_enhanced_medium");

    if ~isfile(steel_csv)
        error("Steel scan simulation table not found: %s", steel_csv);
    end
    if ~isfile(lowj_csv)
        error("Low-J timbre simulation table not found: %s", lowj_csv);
    end

    steel_sim = read_csv_table(steel_csv);
    steel_scan = steel_sim(steel_sim.group == "steel_scan" & steel_sim.status == "completed", :);
    steel_scan = sortrows(steel_scan, ["primary_variable", "value"]);

    lowj_sim = read_csv_table(lowj_csv);

    constants = theory_constants();
    pressure_scale = calibrate_pressure_scale(steel_scan, constants);

    steel_alignment = align_steel_scan(steel_scan, constants, pressure_scale);
    material_alignment = align_material_lowj(lowj_sim, timbre_root, constants, pressure_scale);
    all_alignment = [steel_alignment; material_alignment];

    writetable(steel_alignment, fullfile(tables_dir, "steel_scan_theory_alignment.csv"), ...
        "Encoding", "UTF-8");
    writetable(material_alignment, fullfile(tables_dir, "material_lowJ_theory_alignment.csv"), ...
        "Encoding", "UTF-8");
    writetable(all_alignment, fullfile(tables_dir, "all_theory_alignment.csv"), ...
        "Encoding", "UTF-8");

    plot_steel_alignment(steel_alignment, "frequency", figures_dir);
    plot_steel_alignment(steel_alignment, "spl", figures_dir);
    plot_material_frequency_alignment(material_alignment, figures_dir);
    plot_material_timbre_proxy_alignment(material_alignment, figures_dir);

    report = struct();
    report.model_line = "theory";
    report.model_id = "aligned_to_simulation";
    report.model_class = "Euler-Bernoulli modal grey-box";
    report.output_root = string(output_root);
    report.tables_dir = string(tables_dir);
    report.figures_dir = string(figures_dir);
    report.source_tables = struct( ...
        "steel_scan", string(steel_csv), ...
        "material_lowJ", string(lowj_csv));
    report.n_steel_scan_cases = height(steel_alignment);
    report.n_material_lowJ_cases = height(material_alignment);
    report.frequency_model = "Euler-Bernoulli cantilever modes 1-6";
    report.pressure_model = "one-point calibrated p_rms = C*J*h/L^3*sqrt(b/b0)*(rho_steel/rho)*modal_factor";
    report.pressure_calibration = pressure_scale;
    report.truth_policy = "Theory predictions are aligned to completed simulation rows; no simulation points are invented.";
    report.fit_policy = "Only one steel baseline pressure scale is calibrated for units; agreement is not optimized.";
    report.outputs = struct( ...
        "steel_scan_alignment_csv", string(fullfile(tables_dir, "steel_scan_theory_alignment.csv")), ...
        "material_lowJ_alignment_csv", string(fullfile(tables_dir, "material_lowJ_theory_alignment.csv")), ...
        "all_alignment_csv", string(fullfile(tables_dir, "all_theory_alignment.csv")), ...
        "steel_frequency_alignment_png", string(fullfile(figures_dir, "steel_scan_frequency_alignment.png")), ...
        "steel_spl_alignment_png", string(fullfile(figures_dir, "steel_scan_spl_alignment.png")), ...
        "material_frequency_alignment_png", string(fullfile(figures_dir, "material_lowJ_frequency_alignment.png")), ...
        "material_timbre_proxy_alignment_png", string(fullfile(figures_dir, "material_lowJ_timbre_proxy_alignment.png")));

    write_json_file(fullfile(output_root, "summary.json"), report);

    fprintf("=== THEORY ALIGNMENT MAINLINE COMPLETE ===\n");
    fprintf("Output root: %s\n", output_root);
    fprintf("Steel scan rows: %d\n", height(steel_alignment));
    fprintf("Material low-J rows: %d\n", height(material_alignment));
end

function tbl = read_csv_table(path)
    opts = detectImportOptions(path, "TextType", "string");
    tbl = readtable(path, opts);
end

function constants = theory_constants()
    constants = struct();
    constants.mode_roots = [ ...
        1.875104068711961, ...
        4.694091132974174, ...
        7.854757438237613, ...
        10.995540734875467, ...
        14.13716839104647, ...
        17.278759532088237];
    constants.p_ref_pa = 20e-6;
    constants.base_b_m = 0.03;
    constants.rho_steel = 7930.0;
    constants.zeta_ref = 0.015;
    constants.f_damp_low_hz = 40.0;
    constants.f_damp_high_hz = 700.0;
    constants.bands_hz = [20, 120; 120, 500; 500, 2500];
end

function props = material_properties(material)
    key = string(material);
    switch key
        case "steel"
            props = struct("E_Pa", 193e9, "rho_kg_m3", 7930.0, "nu", 0.29);
        case "pvc"
            props = struct("E_Pa", 3.0e9, "rho_kg_m3", 1380.0, "nu", 0.38);
        case "xuefu_board"
            props = struct("E_Pa", 0.7e9, "rho_kg_m3", 700.0, "nu", 0.35);
        case "acrylic"
            props = struct("E_Pa", 3.2e9, "rho_kg_m3", 1180.0, "nu", 0.35);
        case "satinwood"
            props = struct("E_Pa", 10e9, "rho_kg_m3", 650.0, "nu", 0.35);
        otherwise
            error("Unknown material key: %s", key);
    end
end

function pressure_scale = calibrate_pressure_scale(steel_scan, constants)
    baseline = steel_scan(steel_scan.primary_variable == "J" & abs(steel_scan.value - 0.04) < 1e-9, :);
    if isempty(baseline)
        baseline = steel_scan(steel_scan.primary_variable == "b" & abs(steel_scan.value - 3.0) < 1e-9, :);
    end
    if isempty(baseline)
        error("Cannot find steel baseline row for pressure calibration.");
    end

    row = baseline(1, :);
    props = material_properties("steel");
    L_m = row.L_free_cm / 100.0;
    b_m = row.b_cm / 100.0;
    h_m = row.h_mm / 1000.0;
    xi = row.x0_ratio;
    J_Ns = row.J_Ns;
    mode_freqs = beam_frequencies_hz(L_m, h_m, props, constants);
    modal = modal_proxy(mode_freqs, xi, constants);
    geometry_factor = J_Ns * h_m / (L_m^3) * sqrt(b_m / constants.base_b_m) * ...
        (constants.rho_steel / props.rho_kg_m3) * modal.pressure_factor;

    pressure_scale = struct();
    pressure_scale.case_id = string(row.case_id);
    pressure_scale.reference_p_rms_pa = row.p_rms_pa;
    pressure_scale.reference_spl_db = row.spl_db;
    pressure_scale.constant = row.p_rms_pa / geometry_factor;
end

function tbl = align_steel_scan(steel_scan, constants, pressure_scale)
    rows = repmat(empty_alignment_row(), 0, 1);
    for i = 1:height(steel_scan)
        sim = steel_scan(i, :);
        material = string(sim.material_key);
        props = material_properties(material);
        L_m = sim.L_free_cm / 100.0;
        b_m = sim.b_cm / 100.0;
        h_m = sim.h_mm / 1000.0;
        xi = sim.x0_ratio;
        J_Ns = sim.J_Ns;

        row = compute_alignment_row("steel_scan_coarse", string(sim.case_id), material, ...
            string(sim.primary_variable), sim.value, string(sim.value_unit), ...
            L_m, b_m, h_m, xi, J_Ns, props, constants, pressure_scale);
        row.sim_f_dom_hz = sim.f_dom_hz;
        row.sim_p_rms_pa = sim.p_rms_pa;
        row.sim_spl_db = sim.spl_db;
        row.note = "coarse steel scan aligned to nearest EB mode";
        row = add_errors(row);
        rows(end + 1) = row; %#ok<AGROW>
    end
    tbl = struct2table(rows);
end

function tbl = align_material_lowj(lowj_sim, timbre_root, constants, pressure_scale)
    rows = repmat(empty_alignment_row(), 0, 1);
    for i = 1:height(lowj_sim)
        sim = lowj_sim(i, :);
        material = string(sim.material);
        props = material_properties(material);
        params = read_material_case_params(timbre_root, string(sim.case_id));

        row = compute_alignment_row("material_lowJ_medium", string(sim.case_id), material, ...
            "material", i, "category", params.L_m, params.b_m, params.h_m, ...
            params.xi, params.J_Ns, props, constants, pressure_scale);
        row.sim_f_dom_hz = sim.f_dom_refined_hz;
        row.sim_spl_db = sim.spl_rms_db;
        row.sim_p_rms_pa = constants.p_ref_pa * 10.0^(sim.spl_rms_db / 20.0);
        row.sim_spectral_centroid_hz = sim.spectral_centroid_hz;
        row.sim_spectral_flatness = sim.spectral_flatness;
        row.sim_q_estimate = sim.q_estimate;
        row.sim_low_energy_ratio = sim.low_energy_ratio;
        row.sim_mid_energy_ratio = sim.mid_energy_ratio;
        row.sim_high_energy_ratio = sim.high_energy_ratio;
        row.sim_linear_status = string(sim.linear_status);
        row.note = "enhanced-medium low-J material row aligned to EB modal proxy";
        row = add_errors(row);
        rows(end + 1) = row; %#ok<AGROW>
    end
    tbl = struct2table(rows);
end

function params = read_material_case_params(timbre_root, case_id)
    params = struct("L_m", 0.20, "b_m", 0.03, "h_m", 0.002, "xi", 0.80, "J_Ns", 0.004);
    config_path = fullfile(timbre_root, "configs", case_id + ".json");
    if ~isfile(config_path)
        return;
    end

    cfg = jsondecode(fileread(config_path));
    if isfield(cfg, "geometry")
        if isfield(cfg.geometry, "L_free")
            params.L_m = parse_quantity(cfg.geometry.L_free);
        end
        if isfield(cfg.geometry, "b")
            params.b_m = parse_quantity(cfg.geometry.b);
        end
        if isfield(cfg.geometry, "h")
            params.h_m = parse_quantity(cfg.geometry.h);
        end
    end
    if isfield(cfg, "excitation")
        if isfield(cfg.excitation, "J")
            params.J_Ns = parse_quantity(cfg.excitation.J);
        end
        if isfield(cfg.excitation, "x0")
            params.xi = parse_x0_ratio(cfg.excitation.x0);
        end
    end
end

function value = parse_quantity(raw)
    token = regexp(char(raw), "[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", "match", "once");
    value = str2double(token);
end

function xi = parse_x0_ratio(raw)
    text = string(raw);
    if contains(text, "L_free")
        token = regexp(char(text), "[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", "match", "once");
        xi = str2double(token);
    else
        xi = parse_quantity(raw);
    end
end

function row = compute_alignment_row(dataset, case_id, material, primary_variable, value, value_unit, ...
        L_m, b_m, h_m, xi, J_Ns, props, constants, pressure_scale)
    mode_freqs = beam_frequencies_hz(L_m, h_m, props, constants);
    modal = modal_proxy(mode_freqs, xi, constants);
    p_theory = theory_pressure_pa(L_m, b_m, h_m, xi, J_Ns, props, constants, pressure_scale);
    spl_theory = spl_db(p_theory, constants.p_ref_pa);
    q_modes = rayleigh_q(mode_freqs, constants);

    row = empty_alignment_row();
    row.dataset = string(dataset);
    row.case_id = string(case_id);
    row.material = string(material);
    row.primary_variable = string(primary_variable);
    row.value = value;
    row.value_unit = string(value_unit);
    row.L_free_cm = L_m * 100.0;
    row.b_cm = b_m * 100.0;
    row.h_mm = h_m * 1000.0;
    row.x0_ratio = xi;
    row.J_Ns = J_Ns;

    row.theory_f1_hz = mode_freqs(1);
    row.theory_f2_hz = mode_freqs(2);
    row.theory_f3_hz = mode_freqs(3);
    row.theory_f4_hz = mode_freqs(4);
    row.theory_f5_hz = mode_freqs(5);
    row.theory_f6_hz = mode_freqs(6);
    row.theory_f_weighted_dom_hz = modal.weighted_dom_hz;
    row.theory_weighted_dom_mode = modal.weighted_dom_mode;
    row.theory_p_rms_pa = p_theory;
    row.theory_spl_db = spl_theory;
    row.theory_spectral_centroid_hz = modal.spectral_centroid_hz;
    row.theory_spectral_flatness = modal.spectral_flatness;
    row.theory_low_energy_ratio = modal.low_energy_ratio;
    row.theory_mid_energy_ratio = modal.mid_energy_ratio;
    row.theory_high_energy_ratio = modal.high_energy_ratio;
    row.theory_q_estimate = q_modes(1);
end

function row = add_errors(row)
    if ~isnan(row.sim_f_dom_hz)
        freqs = [row.theory_f1_hz, row.theory_f2_hz, row.theory_f3_hz, ...
            row.theory_f4_hz, row.theory_f5_hz, row.theory_f6_hz];
        [~, idx] = min(abs(freqs - row.sim_f_dom_hz));
        row.theory_f_aligned_hz = freqs(idx);
        row.theory_aligned_mode = idx;
        row.frequency_aligned_error_pct = 100.0 * ...
            (row.theory_f_aligned_hz - row.sim_f_dom_hz) / row.sim_f_dom_hz;
    end
    if ~isnan(row.sim_spl_db)
        row.spl_error_db = row.theory_spl_db - row.sim_spl_db;
    end
    if ~isnan(row.sim_q_estimate)
        row.q_error_pct = 100.0 * (row.theory_q_estimate - row.sim_q_estimate) / row.sim_q_estimate;
    end
end

function freqs = beam_frequencies_hz(L_m, h_m, props, constants)
    coeff = (constants.mode_roots .^ 2) ./ (2.0 * pi * sqrt(12.0));
    freqs = coeff .* (h_m ./ (L_m^2)) .* sqrt(props.E_Pa ./ props.rho_kg_m3);
end

function modal = modal_proxy(mode_freqs, xi, constants)
    roots = constants.mode_roots;
    shape = zeros(size(roots));
    for i = 1:numel(roots)
        shape(i) = abs(cantilever_mode_shape_normalized(roots(i), xi));
    end

    radiation = (mode_freqs ./ (mode_freqs + 120.0)) .^ 2;
    modal_penalty = 1.0 ./ ((1:numel(roots)) .^ 2);
    weights = (shape .^ 2) .* radiation .* modal_penalty;
    if all(weights <= 0)
        weights(1) = 1;
    end

    [~, idx] = max(weights);
    modal = struct();
    modal.weights = weights;
    modal.pressure_factor = sqrt(sum(weights));
    modal.weighted_dom_hz = mode_freqs(idx);
    modal.weighted_dom_mode = idx;
    modal.spectral_centroid_hz = sum(mode_freqs .* weights) / sum(weights);
    modal.spectral_flatness = exp(mean(log(weights + eps))) / mean(weights + eps);
    modal.low_energy_ratio = band_ratio(mode_freqs, weights, constants.bands_hz(1, :));
    modal.mid_energy_ratio = band_ratio(mode_freqs, weights, constants.bands_hz(2, :));
    modal.high_energy_ratio = band_ratio(mode_freqs, weights, constants.bands_hz(3, :));
end

function ratio = band_ratio(freqs, weights, band)
    total = sum(weights);
    if total <= 0
        ratio = NaN;
        return;
    end
    mask = freqs >= band(1) & freqs < band(2);
    ratio = sum(weights(mask)) / total;
end

function phi = cantilever_mode_shape_normalized(lambda, xi)
    sigma = (cosh(lambda) + cos(lambda)) / (sinh(lambda) + sin(lambda));
    raw = cosh(lambda * xi) - cos(lambda * xi) - ...
        sigma * (sinh(lambda * xi) - sin(lambda * xi));
    tip = cosh(lambda) - cos(lambda) - sigma * (sinh(lambda) - sin(lambda));
    phi = raw / tip;
end

function p_pa = theory_pressure_pa(L_m, b_m, h_m, xi, J_Ns, props, constants, pressure_scale)
    mode_freqs = beam_frequencies_hz(L_m, h_m, props, constants);
    modal = modal_proxy(mode_freqs, xi, constants);
    p_pa = pressure_scale.constant * J_Ns * h_m / (L_m^3) * ...
        sqrt(b_m / constants.base_b_m) * (constants.rho_steel / props.rho_kg_m3) * ...
        modal.pressure_factor;
end

function spl = spl_db(p_pa, p_ref_pa)
    if p_pa <= 0
        spl = NaN;
    else
        spl = 20.0 * log10(p_pa / p_ref_pa);
    end
end

function q = rayleigh_q(freqs_hz, constants)
    w1 = 2.0 * pi * constants.f_damp_low_hz;
    w2 = 2.0 * pi * constants.f_damp_high_hz;
    target = [constants.zeta_ref; constants.zeta_ref];
    coeff = [1.0 / (2.0 * w1), w1 / 2.0; 1.0 / (2.0 * w2), w2 / 2.0] \ target;
    alpha = coeff(1);
    beta = coeff(2);
    omega = 2.0 * pi .* freqs_hz;
    zeta = alpha ./ (2.0 .* omega) + beta .* omega ./ 2.0;
    q = 1.0 ./ (2.0 .* zeta);
end

function row = empty_alignment_row()
    row = struct( ...
        "dataset", "", ...
        "case_id", "", ...
        "material", "", ...
        "primary_variable", "", ...
        "value", NaN, ...
        "value_unit", "", ...
        "L_free_cm", NaN, ...
        "b_cm", NaN, ...
        "h_mm", NaN, ...
        "x0_ratio", NaN, ...
        "J_Ns", NaN, ...
        "sim_f_dom_hz", NaN, ...
        "sim_p_rms_pa", NaN, ...
        "sim_spl_db", NaN, ...
        "sim_spectral_centroid_hz", NaN, ...
        "sim_spectral_flatness", NaN, ...
        "sim_q_estimate", NaN, ...
        "sim_low_energy_ratio", NaN, ...
        "sim_mid_energy_ratio", NaN, ...
        "sim_high_energy_ratio", NaN, ...
        "sim_linear_status", "", ...
        "theory_f1_hz", NaN, ...
        "theory_f2_hz", NaN, ...
        "theory_f3_hz", NaN, ...
        "theory_f4_hz", NaN, ...
        "theory_f5_hz", NaN, ...
        "theory_f6_hz", NaN, ...
        "theory_f_aligned_hz", NaN, ...
        "theory_aligned_mode", NaN, ...
        "theory_f_weighted_dom_hz", NaN, ...
        "theory_weighted_dom_mode", NaN, ...
        "theory_p_rms_pa", NaN, ...
        "theory_spl_db", NaN, ...
        "theory_spectral_centroid_hz", NaN, ...
        "theory_spectral_flatness", NaN, ...
        "theory_q_estimate", NaN, ...
        "theory_low_energy_ratio", NaN, ...
        "theory_mid_energy_ratio", NaN, ...
        "theory_high_energy_ratio", NaN, ...
        "frequency_aligned_error_pct", NaN, ...
        "spl_error_db", NaN, ...
        "q_error_pct", NaN, ...
        "note", "");
end

function plot_steel_alignment(tbl, metric, figures_dir)
    variables = ["L_free", "b", "h", "x0_ratio", "J"];
    labels = ["L free", "Width", "Thickness", "Impact position", "Impulse"];

    fig = figure("Visible", "off", "Position", [100, 100, 900, 650]);
    tiledlayout(3, 2, "TileSpacing", "compact", "Padding", "compact");
    for i = 1:numel(variables)
        nexttile;
        subset = tbl(tbl.primary_variable == variables(i), :);
        subset = sortrows(subset, "value");
        if metric == "frequency"
            sim_y = subset.sim_f_dom_hz;
            theory_y = subset.theory_f_aligned_hz;
            y_label = "Frequency (Hz)";
            title_suffix = "frequency";
            filename = "steel_scan_frequency_alignment.png";
        else
            sim_y = subset.sim_spl_db;
            theory_y = subset.theory_spl_db;
            y_label = "SPL (dB)";
            title_suffix = "SPL";
            filename = "steel_scan_spl_alignment.png";
        end
        plot(subset.value, sim_y, "o-", "DisplayName", "Simulation");
        hold on;
        plot(subset.value, theory_y, "s--", "DisplayName", "Theory");
        title(labels(i) + " " + title_suffix);
        xlabel(string(subset.value_unit(1)));
        ylabel(y_label);
        grid on;
        legend("Location", "best");
    end
    nexttile;
    axis off;
    exportgraphics(fig, fullfile(figures_dir, filename), "Resolution", 150);
    close(fig);
end

function plot_material_frequency_alignment(tbl, figures_dir)
    fig = figure("Visible", "off", "Position", [100, 100, 800, 450]);
    x = categorical(cellstr(tbl.material));
    x = reordercats(x, cellstr(tbl.material));
    y = [tbl.sim_f_dom_hz, tbl.theory_f_aligned_hz, tbl.theory_f1_hz];
    bar(x, y);
    ylabel("Frequency (Hz)");
    title("Material low-J frequency alignment");
    legend(["Simulation f_{dom}", "Theory nearest mode", "Theory f_1"], "Location", "northwest");
    grid on;
    exportgraphics(fig, fullfile(figures_dir, "material_lowJ_frequency_alignment.png"), "Resolution", 150);
    close(fig);
end

function plot_material_timbre_proxy_alignment(tbl, figures_dir)
    fig = figure("Visible", "off", "Position", [100, 100, 900, 500]);
    tiledlayout(1, 2, "TileSpacing", "compact", "Padding", "compact");

    x = categorical(cellstr(tbl.material));
    x = reordercats(x, cellstr(tbl.material));

    nexttile;
    bar(x, [tbl.sim_spectral_centroid_hz, tbl.theory_spectral_centroid_hz]);
    ylabel("Spectral centroid (Hz)");
    title("Frequency-distribution proxy");
    legend(["Simulation", "Theory proxy"], "Location", "northwest");
    grid on;

    nexttile;
    bar(x, [tbl.sim_q_estimate, tbl.theory_q_estimate]);
    ylabel("Q");
    title("Decay proxy");
    legend(["Simulation", "Rayleigh theory"], "Location", "northwest");
    grid on;

    exportgraphics(fig, fullfile(figures_dir, "material_lowJ_timbre_proxy_alignment.png"), "Resolution", 150);
    close(fig);
end
