function save_comsol_model(model, model_path)
%SAVE_COMSOL_MODEL Best-effort save of the current COMSOL model.
    arguments
        model
        model_path (1, :) char
    end

    if strlength(string(model_path)) == 0
        return;
    end

    try
        model.save(model_path);
    catch saveErr
        warning("Failed to save COMSOL model '%s': %s", model_path, saveErr.message);
    end
end