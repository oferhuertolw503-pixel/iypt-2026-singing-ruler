function case_metrics = compute_case_metrics(acoustic, structural, coupling, decay)
%COMPUTE_CASE_METRICS Aggregate all derived metrics into a single-row struct.
%   case_metrics = compute_case_metrics(acoustic, structural, coupling, decay)
%
%   Inputs are output structs/tables from:
%     compute_acoustic_metrics
%     compute_structural_metrics
%     compute_modal_acoustic_coupling
%     compute_band_decay_metrics
%
%   Output is a single-row struct suitable for case_metrics.csv aggregation.

    case_metrics = struct();

    % --- Acoustic ---
    case_metrics.p_peak_pa = acoustic.p_peak_pa;
    case_metrics.p_rms_pa = acoustic.p_rms_pa;
    case_metrics.spl_peak_db = acoustic.spl_peak_db;
    case_metrics.spl_rms_db = acoustic.spl_rms_db;
    case_metrics.f_dom_hz = acoustic.f_dom_hz;
    case_metrics.spectral_centroid_hz = acoustic.spectral_centroid_hz;
    case_metrics.spectral_bandwidth_hz = acoustic.spectral_bandwidth_hz;
    case_metrics.rolloff85_hz = acoustic.rolloff85_hz;
    case_metrics.band_30_120_ratio = acoustic.band_30_120_ratio;
    case_metrics.band_120_500_ratio = acoustic.band_120_500_ratio;
    case_metrics.band_500_2000_ratio = acoustic.band_500_2000_ratio;

    % --- Structural ---
    case_metrics.probe_peak_m = structural.probe_peak_m;
    case_metrics.probe_rms_m = structural.probe_rms_m;
    case_metrics.tip_peak_m = structural.tip_peak_m;
    case_metrics.tip_rms_m = structural.tip_rms_m;
    case_metrics.dominant_structure_freq_hz = structural.dominant_structure_freq_hz;
    case_metrics.q_estimate = structural.q_estimate;
    case_metrics.log_decrement = structural.log_decrement;
    case_metrics.q_source = structural.q_source;
    if isfield(structural, 'num_modes')
        case_metrics.num_modes = structural.num_modes;
        for k = 1:structural.num_modes
            fname = sprintf("f%d_hz", k);
            if isfield(structural, fname)
                case_metrics.(fname) = structural.(fname);
            end
        end
    end

    % --- Modal coupling ---
    if istable(coupling) && height(coupling) > 0
        case_metrics.n_matched_modes = height(coupling);
        case_metrics.best_match_rel_delta_pct = min(coupling.rel_delta_pct);
        case_metrics.worst_match_rel_delta_pct = max(coupling.rel_delta_pct);
        n_excellent = sum(coupling.match_quality == "excellent");
        n_good = sum(coupling.match_quality == "good");
        case_metrics.n_excellent_matches = n_excellent;
        case_metrics.n_good_matches = n_good;
    end

    % --- Band decay ---
    if istable(decay) && height(decay) > 0
        case_metrics.n_bands = height(decay);
        for b = 1:height(decay)
            bid = decay.band_id(b);
            case_metrics.(sprintf("band%d_peak_time_s", bid)) = decay.peak_time_s(b);
            case_metrics.(sprintf("band%d_decay10_s", bid)) = decay.decay_to_10pct_s(b);
            case_metrics.(sprintf("band%d_decay1_s", bid)) = decay.decay_to_1pct_s(b);
        end
    end
end
