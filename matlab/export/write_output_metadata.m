function write_output_metadata(output_root, summary, varargin)
%WRITE_OUTPUT_METADATA Write canonical summary files for an output bundle.
    if ~(ischar(output_root) || (isstring(output_root) && isscalar(output_root)))
        error('write_output_metadata:InvalidOutputRoot', 'output_root must be a character vector or scalar string.');
    end
    output_root = char(string(output_root));
    if ~isstruct(summary)
        error('write_output_metadata:InvalidSummary', 'summary must be a struct.');
    end

    options = normalize_metadata_options(varargin{:});

    ensure_dir(output_root);

    summary_json_path = fullfile(output_root, 'summary.json');
    summary_txt_path = fullfile(output_root, 'summary.txt');
    run_manifest_path = fullfile(output_root, 'run_manifest.txt');

    write_json_file(summary_json_path, summary);
    write_summary_text(summary_txt_path, summary);

    lines = {};
    lines{end + 1} = ['output_root: ' output_root]; %#ok<AGROW>
    if isfield(summary, 'model_id')
        lines{end + 1} = ['model_id: ' char(string(summary.model_id))]; %#ok<AGROW>
    end
    if isfield(summary, 'model_line')
        lines{end + 1} = ['model_line: ' char(string(summary.model_line))]; %#ok<AGROW>
    end
    for i = 1:numel(options.manifest_lines)
        lines{end + 1} = char(string(options.manifest_lines{i})); %#ok<AGROW>
    end
    write_text_lines(run_manifest_path, lines);
end

function options = normalize_metadata_options(varargin)
    options = struct('manifest_lines', {{}});

    if nargin == 0
        return;
    end

    if nargin == 1 && isstruct(varargin{1})
        raw = varargin{1};
        if isfield(raw, 'manifest_lines')
            options.manifest_lines = raw.manifest_lines;
        end
        return;
    end

    if rem(nargin, 2) ~= 0
        error('write_output_metadata expects either one options struct or name-value pairs.');
    end

    for i = 1:2:nargin
        name = char(string(varargin{i}));
        options.(name) = varargin{i + 1};
    end
end

function write_summary_text(path, summary)
    names = fieldnames(summary);
    lines = cell(numel(names), 1);
    for i = 1:numel(names)
        value = summary.(names{i});
        value_text = format_summary_value_text(value);
        lines{i} = sprintf('%s: %s', names{i}, value_text);
    end
    write_text_lines(path, lines);
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

function write_text_lines(path, lines)
    fid = fopen(path, 'w', 'n', 'UTF-8');
    if fid < 0
        error('Failed to open text output: %s', path);
    end
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
    for i = 1:numel(lines)
        fprintf(fid, '%s\n', lines{i});
    end
end
