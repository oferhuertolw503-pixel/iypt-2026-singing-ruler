function model = comsol_open_model(mph_path)
%COMSOL_OPEN_MODEL Open an MPH model through local LiveLink.
    arguments
        mph_path (1, :) char
    end

    if exist(mph_path, "file") ~= 2
        error("Model file does not exist: %s", mph_path);
    end

    if exist("mphload", "file") ~= 0
        model = mphload(mph_path);
    elseif exist("mphopen", "file") ~= 0
        model = mphopen(mph_path);
    else
        import com.comsol.model.util.*
        model = ModelUtil.load("SingingRulerModel", mph_path);
    end

    fprintf("Opened model: %s\n", mph_path);
end