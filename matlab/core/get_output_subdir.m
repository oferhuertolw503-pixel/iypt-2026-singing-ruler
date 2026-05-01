function value = get_output_subdir(spec, field_name, default_value)
%GET_OUTPUT_SUBDIR Resolve an output subdirectory name from a spec struct.
    value = default_value;
    if isfield(spec, field_name)
        candidate = string(spec.(field_name));
        if strlength(strtrim(candidate)) > 0
            value = char(strtrim(candidate));
        end
    end
end