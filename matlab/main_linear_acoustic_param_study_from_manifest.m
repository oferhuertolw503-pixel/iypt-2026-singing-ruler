function main_linear_acoustic_param_study_from_manifest(manifest_path)
%MAIN_LINEAR_ACOUSTIC_PARAM_STUDY_FROM_MANIFEST Run parameter-study postprocess from a handoff manifest.

    this_dir = fileparts(mfilename("fullpath"));
    addpath(fullfile(this_dir, "core"));
    manifest = read_matlab_handoff_manifest(manifest_path);

    study_manifest_path = required_text_field(manifest, "study_manifest_path");
    study_root = required_text_field(manifest, "output_root");
    main_linear_acoustic_param_study_postprocess(study_manifest_path, study_root);
end

function value = required_text_field(manifest, field_name)
    value = "";
    if isfield(manifest, field_name)
        raw = string(manifest.(field_name));
        if strlength(strtrim(raw)) > 0
            value = char(strtrim(raw));
        end
    end
    if strlength(string(value)) == 0
        error("Manifest field '%s' is missing or empty.", field_name);
    end
end
