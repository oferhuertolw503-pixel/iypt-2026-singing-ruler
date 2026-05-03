function [f_refined, amp_refined, p] = refine_peak_parabolic(freq_hz, amp, idx)
%REFINE_PEAK_PARABOLIC Three-point parabolic interpolation for sub-bin peak refinement.
%   [f_refined, amp_refined, p] = refine_peak_parabolic(freq_hz, amp, idx)
%
%   Inputs:
%     freq_hz : Nx1 frequency vector (must be uniformly spaced)
%     amp     : Nx1 amplitude vector
%     idx     : Mx1 integer peak indices (output of detect_local_spectral_peaks)
%
%   Outputs:
%     f_refined  : Mx1 refined frequencies (NaN if near edge)
%     amp_refined: Mx1 refined amplitudes (NaN if near edge)
%     p          : Mx1 parabolic shift in bins (0 = no shift, ±0.5 max)
%
%   Uses log-domain parabolic interpolation:
%     alpha = log(amp(k-1)), beta = log(amp(k)), gamma = log(amp(k+1))
%     p = 0.5 * (alpha - gamma) / (alpha - 2*beta + gamma)
%     f_refined = freq_hz(k) + p * df
%     amp_refined = amp(k) - 0.25 * (alpha - gamma) * p

    arguments
        freq_hz (:, 1) double {mustBeFinite}
        amp (:, 1) double {mustBeFinite}
        idx (:, 1) double {mustBeInteger, mustBePositive}
    end

    n = numel(amp);
    if n < 3
        f_refined = NaN(size(idx));
        amp_refined = NaN(size(idx));
        p = NaN(size(idx));
        return;
    end

    df = mean(diff(freq_hz));
    if ~(isfinite(df) && df > 0)
        f_refined = NaN(size(idx));
        amp_refined = NaN(size(idx));
        p = NaN(size(idx));
        return;
    end

    m = numel(idx);
    f_refined = NaN(m, 1);
    amp_refined = NaN(m, 1);
    p = NaN(m, 1);

    for i = 1:m
        k = idx(i);
        if k <= 1 || k >= n
            continue;
        end

        alpha = log(max(amp(k - 1), eps));
        beta  = log(max(amp(k),     eps));
        gamma = log(max(amp(k + 1), eps));

        denom = alpha - 2 * beta + gamma;
        if abs(denom) < eps
            continue;
        end

        p_i = 0.5 * (alpha - gamma) / denom;
        if abs(p_i) > 0.5
            p_i = max(min(p_i, 0.5), -0.5);
        end

        f_refined(i) = freq_hz(k) + p_i * df;
        amp_refined(i) = max(amp(k) - 0.25 * (alpha - gamma) * p_i, 0);
        p(i) = p_i;
    end
end
