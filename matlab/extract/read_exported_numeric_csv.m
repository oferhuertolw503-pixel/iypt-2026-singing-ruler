function tbl = read_exported_numeric_csv(path)
%READ_EXPORTED_NUMERIC_CSV Read COMSOL/Java numeric CSV with optional commented header.

    arguments
        path (1, :) char
    end

    lines = readlines(path, 'EmptyLineRule', 'skip');
    header = "";
    data_lines = strings(0, 1);

    for i = 1:numel(lines)
        line = strtrim(lines(i));
        if strlength(line) == 0
            continue;
        end
        if startsWith(line, "%")
            candidate = strtrim(extractAfter(line, 1));
            if contains(candidate, ",") && ~any(startsWith(candidate, ["Model,", "Version,", "Date,", "Table,"]))
                header = candidate;
            end
            continue;
        end
        data_lines(end + 1, 1) = line; %#ok<AGROW>
    end

    if strlength(header) == 0
        values = parse_numeric_lines(data_lines);
        names = infer_variable_names(path, size(values, 2));
        tbl = array2table(values, 'VariableNames', names);
        return;
    end

    raw_names = strtrim(split(header, ",")).';
    names = matlab.lang.makeValidName(cellstr(raw_names), 'ReplacementStyle', 'delete');
    values = parse_numeric_lines(data_lines, numel(names));
    tbl = array2table(values, 'VariableNames', names);
end

function values = parse_numeric_lines(data_lines, expected_cols)
    if nargin < 2
        expected_cols = 0;
    end

    if isempty(data_lines)
        values = zeros(0, expected_cols);
        return;
    end

    if expected_cols <= 0
        first_parts = split(data_lines(1), ",");
        expected_cols = numel(first_parts);
    end

    values = nan(numel(data_lines), expected_cols);
    for row = 1:numel(data_lines)
        parts = strtrim(split(data_lines(row), ",")).';
        for col = 1:min(numel(parts), expected_cols)
            values(row, col) = str2double(parts(col));
        end
    end
end

function names = infer_variable_names(path, num_cols)
    [~, stem, ~] = fileparts(path);

    switch lower(stem)
        case 'frequencies'
            expected = {'mode', 'freq_hz'};
        case 'tip_timeseries'
            expected = {'t_s', 'w_m'};
        case 'structure_probe_timeseries'
            expected = {'t_s', 'uz_m'};
        case 'mic_pressure_timeseries'
            expected = {'t_s', 'p_pa'};
        case 'impact_force_timeseries'
            expected = {'t_s', 'force_z_N'};
        case 'mic_pressure_fft'
            expected = {'freq_hz', 'amp_pa'};
        case 'mode_shapes'
            expected = [{'x_over_L'}, arrayfun(@(k) sprintf('w_mode%d', k), 1:max(num_cols - 1, 0), 'UniformOutput', false)];
        otherwise
            expected = arrayfun(@(k) sprintf('col%d', k), 1:num_cols, 'UniformOutput', false);
    end

    if numel(expected) < num_cols
        extra = arrayfun(@(k) sprintf('col%d', k), numel(expected) + 1:num_cols, 'UniformOutput', false);
        expected = [expected, extra];
    elseif numel(expected) > num_cols
        expected = expected(1:num_cols);
    end

    names = matlab.lang.makeUniqueStrings(expected, {}, namelengthmax);
end
