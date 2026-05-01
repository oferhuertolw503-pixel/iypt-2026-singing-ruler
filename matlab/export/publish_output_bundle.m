function publish_output_bundle(output_root, summary, varargin)
%PUBLISH_OUTPUT_BUNDLE Publish canonical root-level metadata for a model output bundle.
    if ~(ischar(output_root) || (isstring(output_root) && isscalar(output_root)))
        error('publish_output_bundle:InvalidOutputRoot', 'output_root must be a character vector or scalar string.');
    end
    output_root = char(string(output_root));
    if ~isstruct(summary)
        error('publish_output_bundle:InvalidSummary', 'summary must be a struct.');
    end

    spec = normalize_bundle_spec(varargin{:});

    lines = {};
    if strlength(string(spec.config_path)) > 0
        lines{end + 1} = ['config_path: ' spec.config_path]; %#ok<AGROW>
    end
    for i = 1:numel(spec.table_files)
        lines{end + 1} = ['table: ' char(string(spec.table_files{i}))]; %#ok<AGROW>
    end
    for i = 1:numel(spec.figure_files)
        lines{end + 1} = ['figure: ' char(string(spec.figure_files{i}))]; %#ok<AGROW>
    end
    for i = 1:numel(spec.artifact_files)
        lines{end + 1} = ['artifact: ' char(string(spec.artifact_files{i}))]; %#ok<AGROW>
    end

    write_output_metadata(output_root, summary, struct('manifest_lines', {lines}));
end

function spec = normalize_bundle_spec(varargin)
    spec = struct( ...
        'config_path', '', ...
        'table_files', {{}}, ...
        'figure_files', {{}}, ...
        'artifact_files', {{}});

    if nargin == 0
        return;
    end

    if nargin == 1 && isstruct(varargin{1})
        raw = varargin{1};
        fields = fieldnames(raw);
        for i = 1:numel(fields)
            spec.(fields{i}) = raw.(fields{i});
        end
        return;
    end

    if rem(nargin, 2) ~= 0
        error('publish_output_bundle expects either one spec struct or name-value pairs.');
    end

    for i = 1:2:nargin
        name = char(string(varargin{i}));
        spec.(name) = varargin{i + 1};
    end
end
