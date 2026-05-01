function main_linear_acoustic_field_from_manifest(manifest_path)
%MAIN_LINEAR_ACOUSTIC_FIELD_FROM_MANIFEST Run acoustic-field postprocess from a handoff manifest.

    this_dir = fileparts(mfilename("fullpath"));
    addpath(fullfile(this_dir, "core"));
    manifest = read_matlab_handoff_manifest(manifest_path);
    main_linear_acoustic_field( ...
        required_text_field(manifest, "config_path"), ...
        required_text_field(manifest, "mph_path"), ...
        required_text_field(manifest, "output_root"), ...
        optional_text_field(manifest, "quality", "full"), ...
        optional_text_field(manifest, "build_wallclock_s", "0"), ...
        "1");
end

function value = required_text_field(manifest, field_name)
    value = optional_text_field(manifest, field_name, "");
    if strlength(string(value)) == 0
        error("Manifest field '%s' is missing or empty.", field_name);
    end
end

function value = optional_text_field(manifest, field_name, default_value)
    if isfield(manifest, field_name)
        raw = string(manifest.(field_name));
        if strlength(strtrim(raw)) > 0
            value = char(strtrim(raw));
            return;
        end
    end
    value = default_value;
end
