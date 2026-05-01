function comsol_disconnect(model)
%COMSOL_DISCONNECT Best-effort release of a COMSOL model handle.
    try
        if nargin >= 1 && ~isempty(model)
            modelTag = char(model.tag());
            if strlength(string(modelTag)) > 0
                import com.comsol.model.util.*
                ModelUtil.remove(modelTag);
            end
        end
    catch
    end

    try
        import com.comsol.model.util.*
        ModelUtil.disconnect();
    catch
    end
end