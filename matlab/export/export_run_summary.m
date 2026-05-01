function export_run_summary(results_dir, summary)
%EXPORT_RUN_SUMMARY Write run_summary.json and run_summary.txt into results_dir.
    ensure_dir(results_dir);
    write_json_file(fullfile(results_dir, 'run_summary.json'), summary);

    names = fieldnames(summary);
    lines = cell(numel(names), 1);
    for i = 1:numel(names)
        value = summary.(names{i});
        value_text = format_summary_value_text(value);
        lines{i} = sprintf('%s: %s', names{i}, value_text);
    end

    fid = fopen(fullfile(results_dir, 'run_summary.txt'), 'w', 'n', 'UTF-8');
    if fid < 0
        error('Failed to open run_summary.txt in %s', results_dir);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
end

function value_text = format_summary_value_text(value)
    if isnumeric(value) || islogical(value)
        value_text = mat2str(value);
        return;
    end

    if isstring(value)
        if isscalar(value)
            value_text = char(value);
        else
            value_text = jsonencode(cellstr(value(:).'));
        end
        return;
    end

    if ischar(value)
        if isrow(value)
            value_text = value;
        else
            value_text = jsonencode(cellstr(value));
        end
        return;
    end

    value_text = jsonencode(value);
end
