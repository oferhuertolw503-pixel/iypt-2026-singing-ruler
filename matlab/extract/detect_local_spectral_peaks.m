function [idx, prominence] = detect_local_spectral_peaks(amp, min_prominence_db)
%DETECT_LOCAL_SPECTRAL_PEAKS Find local peaks in a spectrum without Signal Processing Toolbox.
%   [idx, prominence] = detect_local_spectral_peaks(amp)
%   [idx, prominence] = detect_local_spectral_peaks(amp, min_prominence_db)
%
%   Inputs:
%     amp              : Nx1 amplitude vector (linear, not dB)
%     min_prominence_db: minimum peak prominence in dB (default 3.0)
%
%   Outputs:
%     idx       : Px1 indices of detected peaks
%     prominence: Px1 prominence values in dB (peak level minus lowest valley between peaks)
%
%   Peak detection rules:
%     1. amp(k) >= amp(k-1) AND amp(k) > amp(k+1)  (strict local max)
%     2. amp(k) > max(amp(1), amp(end))  (ignore edge effects)
%     3. prominence >= min_prominence_db
%
%   Prominence: for each peak, find the lowest valley (minimum amplitude) between
%   this peak and the next higher peak, or to the edge. Prominence = amp(k) - valley_amplitude in dB.

    arguments
        amp (:, 1) double {mustBeFinite}
        min_prominence_db (1, 1) double = 3.0
    end

    n = numel(amp);
    if n < 3
        idx = zeros(0, 1);
        prominence = zeros(0, 1);
        return;
    end

    % Strict local maxima: center >= left AND center > right
    left = amp(1:end - 2);
    center = amp(2:end - 1);
    right = amp(3:end);
    raw_idx = find(center >= left & center > right);
    raw_idx = raw_idx(:) + 1;

    % Exclude edge artifacts: peak must be above the DC and Nyquist levels
    edge_max = max(amp(1), amp(end));
    raw_idx = raw_idx(amp(raw_idx) > edge_max);

    if isempty(raw_idx)
        idx = zeros(0, 1);
        prominence = zeros(0, 1);
        return;
    end

    % Compute prominence for each candidate peak
    n_candidates = numel(raw_idx);
    prom_vals = zeros(n_candidates, 1);

    for i = 1:n_candidates
        k = raw_idx(i);

        % Left valley: minimum between previous higher peak (or edge) and this peak
        left_start = 1;
        for j = i - 1:-1:1
            if amp(raw_idx(j)) > amp(k)
                left_start = raw_idx(j);
                break;
            end
        end
        left_valley = min(amp(left_start:k));

        % Right valley: minimum between this peak and next higher peak (or edge)
        right_end = n;
        for j = i + 1:n_candidates
            if amp(raw_idx(j)) > amp(k)
                right_end = raw_idx(j);
                break;
            end
        end
        right_valley = min(amp(k:right_end));

        valley = min(left_valley, right_valley);
        prom_linear = max(amp(k) - valley, 0);
        if prom_linear > 0 && valley > 0
            prom_vals(i) = 20 * log10(amp(k) / valley);
        elseif valley <= 0
            prom_vals(i) = Inf;
        else
            prom_vals(i) = 0;
        end
    end

    % Filter by prominence
    keep = prom_vals >= min_prominence_db;
    idx = raw_idx(keep);
    prominence = prom_vals(keep);

    % Sort by descending prominence
    [~, order] = sort(prominence, 'descend');
    idx = idx(order);
    prominence = prominence(order);
end
