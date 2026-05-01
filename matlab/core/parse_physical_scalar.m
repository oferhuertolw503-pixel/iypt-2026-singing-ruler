function value = parse_physical_scalar(raw, default_value)
%PARSE_PHYSICAL_SCALAR Parse a numeric scalar from a COMSOL-style value string.
    if nargin < 2
        default_value = NaN;
    end

    if isempty(raw)
        value = default_value;
        return;
    end

    if isnumeric(raw) || islogical(raw)
        value = double(raw);
        return;
    end

    text = char(string(raw));
    text = strtrim(text);
    if strlength(string(text)) == 0
        value = default_value;
        return;
    end

    parsed = str2double(text);
    if isfinite(parsed)
        value = parsed;
        return;
    end

    token = regexp(text, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match', 'once');
    if isempty(token)
        value = default_value;
        return;
    end

    parsed = str2double(token);
    if isfinite(parsed)
        value = parsed;
    else
        value = default_value;
    end
end