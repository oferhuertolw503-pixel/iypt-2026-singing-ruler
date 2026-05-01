function [series_table, t, value] = extract_point_timeseries(model, dataset_tag, exprs, headers, point_coord, solution_dataset_tag, solution_tag)
%EXTRACT_POINT_TIMESERIES Evaluate point data over all time levels.

    arguments
        model
        dataset_tag (1, :) char
        exprs (1, :) cell
        headers (1, :) cell
        point_coord = []
        solution_dataset_tag (1, :) char = ''
        solution_tag (1, :) char = ''
    end

    %#ok<NASGU>
    point_coord = point_coord;
    solution_dataset_tag = solution_dataset_tag;
    solution_tag = solution_tag;

    tmp_tag = sprintf('tmpEval_%d', round(1e9 * rand()));
    cleanup_tmp = onCleanup(@() safe_remove_evalpoint(model, tmp_tag));
    model.result().numerical().create(tmp_tag, 'EvalPoint');
    model.result().numerical(tmp_tag).set('data', dataset_tag);
    model.result().numerical(tmp_tag).set('expr', exprs);
    raw = double(model.result().numerical(tmp_tag).getReal());

    if size(raw, 1) ~= numel(exprs) && size(raw, 2) == numel(exprs)
        raw = raw.';
    end
    if size(raw, 1) ~= numel(exprs)
        error("Unexpected EvalPoint output size for dataset '%s'.", dataset_tag);
    end

    t = raw(1, :).';
    value = raw(2, :).';
    series_table = table(t, value, 'VariableNames', headers);
end

function safe_remove_evalpoint(model, tag)
    try
        model.result().numerical().remove(tag);
    catch
    end
end