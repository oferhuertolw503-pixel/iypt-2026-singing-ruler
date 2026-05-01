function main_linear_acoustic_param_study_postprocess(study_manifest_path, study_root)
%MAIN_LINEAR_ACOUSTIC_PARAM_STUDY_POSTPROCESS Run case postprocess first, then aggregate study outputs.

    arguments
        study_manifest_path (1, :) char
        study_root (1, :) char
    end

    main_linear_acoustic_param_study(study_manifest_path, study_root);
end
