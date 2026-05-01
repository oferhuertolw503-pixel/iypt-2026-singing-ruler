function main_linear_base_from_manifest(manifest_path)
%MAIN_LINEAR_BASE_FROM_MANIFEST Run linear/base postprocess from a handoff manifest.

    this_dir = fileparts(mfilename("fullpath"));
    addpath(fullfile(this_dir, "core"));
    manifest = read_matlab_handoff_manifest(manifest_path);
    main_linear_base( ...
        required_text_field(manifest, "config_path"), ...
        required_text_field(manifest, "mph_path"), ...
        required_text_field(manifest, "output_root"));
end

function value = required_text_field(manifest, field_name)
    if isfield(manifest, field_name)
        raw = string(manifest.(field_name));
        if strlength(strtrim(raw)) > 0
            value = char(strtrim(raw));
            return;
        end
    end
    error("Manifest field '%s' is missing or empty.", field_name);
end