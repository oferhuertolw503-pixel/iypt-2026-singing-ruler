function results = run_matlab_manifest_queue(queue_path)
%RUN_MATLAB_MANIFEST_QUEUE Execute queued MATLAB handoff manifests.

    arguments
        queue_path (1, :) char
    end

    this_dir = fileparts(mfilename("fullpath"));
    addpath(genpath(this_dir));

    if exist(queue_path, "file") ~= 2
        error("MATLAB manifest queue not found: %s", queue_path);
    end

    queue = jsondecode(fileread(queue_path));
    entries = normalize_entries(queue.entries);
    project_root = char(string(queue.project_root));
    if exist(project_root, "dir") ~= 7
        error("Project root from queue not found: %s", project_root);
    end

    previous_dir = pwd;
    cleanup = onCleanup(@() cd(previous_dir));
    cd(project_root);
    addpath(genpath(fullfile(project_root, "matlab")));

    results = repmat(struct( ...
        "manifest_path", "", ...
        "action", "", ...
        "reason", "", ...
        "result", "", ...
        "message", ""), 0, 1);

    fprintf("=== MATLAB manifest queue start ===\n");
    fprintf("Queue: %s\n", queue_path);

    for idx = 1:numel(entries)
        entry = entries(idx);
        manifest_path = char(string(entry.manifest_path));
        action = char(string(entry.action));
        reason = char(string(entry.reason));

        if ~strcmp(action, "queued")
            fprintf("[%d/%d] SKIP %s (%s)\n", idx, numel(entries), manifest_path, reason);
            results(end + 1, 1) = make_result(entry, "skipped", reason); %#ok<AGROW>
            continue;
        end

        fprintf("[%d/%d] RUN %s\n", idx, numel(entries), manifest_path);
        try
            run_matlab_manifest(manifest_path);
            results(end + 1, 1) = make_result(entry, "completed", "MATLAB handoff completed."); %#ok<AGROW>
        catch ME
            results(end + 1, 1) = make_result(entry, "failed", ME.message); %#ok<AGROW>
            fprintf(2, "Queue entry failed: %s\n", getReport(ME, "extended", "hyperlinks", "off"));
        end
    end

    result_path = build_result_path(queue_path);
    write_json_text(result_path, results);
    fprintf("=== MATLAB manifest queue complete ===\n");
    fprintf("Result: %s\n", result_path);
end

function entries = normalize_entries(raw_entries)
    if isempty(raw_entries)
        entries = raw_entries;
        return;
    end
    if isstruct(raw_entries)
        entries = raw_entries(:);
        return;
    end
    error("Unsupported queue entries format.");
end

function result = make_result(entry, result_state, message)
    result = struct();
    result.manifest_path = string(entry.manifest_path);
    result.action = string(entry.action);
    result.reason = string(entry.reason);
    result.result = string(result_state);
    result.message = string(message);
end

function result_path = build_result_path(queue_path)
    [folder, stem, ~] = fileparts(queue_path);
    stamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
    result_path = fullfile(folder, stem + "_result_" + stamp + ".json");
end

function write_json_text(path, value)
    json = jsonencode(value, "PrettyPrint", true);
    fid = fopen(path, "w", "n", "UTF-8");
    if fid < 0
        error("Failed to open JSON output for writing: %s", path);
    end
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, json, "char");
end
