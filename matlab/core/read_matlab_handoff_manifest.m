function manifest = read_matlab_handoff_manifest(manifest_path)
%READ_MATLAB_HANDOFF_MANIFEST Read and normalize a MATLAB handoff manifest.

    arguments
        manifest_path (1, :) char
    end

    manifest = read_json_file(manifest_path);
    manifest.manifest_path = manifest_path;
    manifest.project_root = required_text_field(manifest, "project_root");
    manifest.entry_function = required_text_field(manifest, "entry_function");
    manifest.invoke_style = optional_text_field(manifest, "invoke_style", "manifest_path");
    manifest.output_root = optional_text_field(manifest, "output_root", "");
    manifest.config_path = optional_text_field(manifest, "config_path", "");
    manifest.mph_path = optional_text_field(manifest, "mph_path", "");
    manifest.log_path = optional_text_field(manifest, "log_path", "");
    manifest.status_path = optional_text_field(manifest, "status_path", "");
    manifest.model_line = optional_text_field(manifest, "model_line", "");
    manifest.model_id = optional_text_field(manifest, "model_id", "");
    manifest.quality = optional_text_field(manifest, "quality", "");
    manifest.build_wallclock_s = optional_text_field(manifest, "build_wallclock_s", "0");
    manifest.function_args = normalize_args_field(manifest);
end

function value = required_text_field(manifest, field_name)
    value = optional_text_field(manifest, field_name, "");
    if strlength(string(value)) == 0
        error("MATLAB handoff manifest field '%s' is missing or empty.", field_name);
    end
end

function value = optional_text_field(manifest, field_name, default_value)
    if isfield(manifest, field_name)
        raw = manifest.(field_name);
        text_value = string(raw);
        if strlength(strtrim(text_value)) > 0
            value = char(strtrim(text_value));
            return;
        end
    end
    value = default_value;
end

function args = normalize_args_field(manifest)
    if ~isfield(manifest, "function_args") || isempty(manifest.function_args)
        args = {};
        return;
    end

    raw = manifest.function_args;
    if iscell(raw)
        args = cellfun(@(item) char(string(item)), raw, 'UniformOutput', false);
        return;
    end
    if isstring(raw)
        args = cellstr(raw(:));
        return;
    end
    if ischar(raw)
        args = {raw};
        return;
    end

    args = cellstr(string(raw));
end
