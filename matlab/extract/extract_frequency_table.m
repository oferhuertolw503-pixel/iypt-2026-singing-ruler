function [freq_table, freqs] = extract_frequency_table(model)
%EXTRACT_FREQUENCY_TABLE Export eigenfrequency rows.

    arguments
        model
    end

    try
        raw = double(model.result().table('tblFreq').getReal());
    catch
        tmp_tag = temp_tag('tmpFreq');
        model.result().numerical().create(tmp_tag, 'EvalGlobal');
        model.result().numerical(tmp_tag).set('expr', {'freq'});
        model.result().numerical(tmp_tag).set('data', 'dsetEig');
        raw = double(model.result().numerical(tmp_tag).getReal());
    end

    if isvector(raw)
        freqs = raw(:);
    else
        freqs = raw(:, 1);
        if size(raw, 1) == 1
            freqs = raw(:);
        end
    end

    modes = transpose(1:numel(freqs));
    freq_table = table(modes, freqs, 'VariableNames', {'mode', 'freq_hz'});
end

function tag = temp_tag(prefix)
    tag = sprintf('%s_%d', prefix, round(1e9 * rand()));
end
