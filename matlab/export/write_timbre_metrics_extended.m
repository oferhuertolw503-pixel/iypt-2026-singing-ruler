function result = write_timbre_metrics_extended(data_dir, mic_t, mic_p, result)
%WRITE_TIMBRE_METRICS_EXTENDED Compute and write extended timbre metrics CSV.
%   result = write_timbre_metrics_extended(data_dir, mic_t, mic_p, result)
%
%   Appends to result struct: result.timbre_extended
%   Writes: data/timbre_metrics_extended.csv

    arguments
        data_dir (1, :) char
        mic_t (:, 1) double
        mic_p (:, 1) double
        result struct
    end

    tic_ext = tic;

    % Compute extended timbre metrics
    if numel(mic_t) >= 10
        ext = compute_timbre_metrics_extended(mic_t, mic_p);
    else
        ext = struct();
    end

    % Write to CSV
    if ~isempty(fieldnames(ext))
        t = struct2table(ext, 'AsArray', true);
        csv_path = fullfile(data_dir, 'timbre_metrics_extended.csv');
        writetable(t, csv_path, 'Encoding', 'UTF-8');
        fprintf('Extended timbre metrics written: %s (%.2f s)\n', csv_path, toc(tic_ext));
    else
        fprintf('Extended timbre metrics: skipped (no mic data)\n');
    end

    result.timbre_extended = ext;
end
