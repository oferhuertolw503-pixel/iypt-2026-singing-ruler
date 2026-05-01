function write_matlab_handoff_status(status_path, state, manifest, varargin)
%WRITE_MATLAB_HANDOFF_STATUS Persist manifest runner status for Codex handoff.

    if ~ismember(state, ["pending", "running", "completed", "failed"])
        error("Unsupported MATLAB handoff state: %s", state);
    end

    opts = parse_name_values(varargin{:});

    status_dir = fileparts(status_path);
    if strlength(string(status_dir)) > 0 && exist(status_dir, "dir") ~= 7
        mkdir(status_dir);
    end

    payload = struct();
    payload.status = char(state);
    payload.updated_at = char(string(datetime("now", "Format", "yyyy-MM-dd HH:mm:ss")));
    payload.manifest_path = manifest.manifest_path;
    payload.entry_function = manifest.entry_function;
    payload.log_path = manifest.log_path;
    payload.message = opts.message;

    if strlength(string(opts.error_report)) > 0
        payload.error_report = opts.error_report;
    end

    write_json_file(status_path, payload);
end

function opts = parse_name_values(varargin)
    opts = struct("message", "", "error_report", "");
    if mod(numel(varargin), 2) ~= 0
        error("Status options must be name/value pairs.");
    end

    for i = 1:2:numel(varargin)
        name = string(varargin{i});
        value = varargin{i + 1};
        switch name
            case "message"
                opts.message = char(string(value));
            case "error_report"
                opts.error_report = char(string(value));
            otherwise
                error("Unknown status option: %s", name);
        end
    end
end
