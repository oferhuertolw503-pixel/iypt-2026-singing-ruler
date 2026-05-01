function mode_table = extract_mode_shapes(model, num_modes, n_points, beam_length_m)
%EXTRACT_MODE_SHAPES Sample mode shapes along the beam length.

    arguments
        model
        num_modes (1, 1) double {mustBePositive, mustBeInteger}
        n_points (1, 1) double {mustBePositive, mustBeInteger}
        beam_length_m (1, 1) double = NaN
    end

    tmp_dset = sprintf('tmpModePt_%d', round(1e9 * rand()));
    tmp_eval = sprintf('tmpModeEv_%d', round(1e9 * rand()));

    model.result().dataset().create(tmp_dset, 'CutPoint3D');
    model.result().dataset(tmp_dset).set('data', 'dsetEig');
    model.result().dataset(tmp_dset).set('pointy', '0');
    model.result().dataset(tmp_dset).set('pointz', '0');

    model.result().numerical().create(tmp_eval, 'EvalPoint');
    model.result().numerical(tmp_eval).set('data', tmp_dset);
    model.result().numerical(tmp_eval).set('expr', {'w'});

    x = linspace(0, 1, n_points).';
    y = nan(n_points, num_modes);

    for i = 1:n_points
        s = x(i);
        if isfinite(beam_length_m) && beam_length_m > 0
            point_x = sprintf('%.16g[m]', s * beam_length_m);
        else
            point_x = sprintf('%.16g*L', s);
        end
        model.result().dataset(tmp_dset).set('pointx', point_x);
        raw = double(model.result().numerical(tmp_eval).getReal());
        if isvector(raw)
            raw = raw(:).';
        elseif size(raw, 1) ~= 1 && size(raw, 2) == 1
            raw = raw.';
        end

        available = min(num_modes, size(raw, 2));
        if available > 0
            y(i, 1:available) = raw(1, 1:available);
        end
    end

    mode_table = table(x, 'VariableNames', {'x_over_L'});
    for k = 1:num_modes
        mode_table.(sprintf('w_mode%d', k)) = y(:, k);
    end
end