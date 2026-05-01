function result = compute_spl_from_pressure(p_pa)
%COMPUTE_SPL_FROM_PRESSURE Compute RMS pressure and SPL from a pressure trace.
    arguments
        p_pa (:, 1) double
    end

    p_ref_pa = 20e-6;
    p_rms_pa = rms(p_pa);
    if p_rms_pa > 0
        spl_db = 20 * log10(p_rms_pa / p_ref_pa);
    else
        spl_db = -Inf;
    end

    result = struct("p_rms_pa", p_rms_pa, "spl_db", spl_db, "spl_ref_pa", p_ref_pa);
end