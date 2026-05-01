function run_matlab_manifest(manifest_path)
%RUN_MATLAB_MANIFEST Execute a MATLAB handoff manifest inside the live session.

    arguments
        manifest_path (1, :) char
    end

    this_dir = fileparts(mfilename("fullpath"));
    addpath(fullfile(this_dir, "core"));

    manifest = read_matlab_handoff_manifest(manifest_path);
    matlab_root = fullfile(manifest.project_root, "matlab");
    if exist(matlab_root, "dir") ~= 7
        error("MATLAB project root not found: %s", matlab_root);
    end

    addpath(genpath(matlab_root));
    previous_dir = pwd;
    restore_dir = onCleanup(@() cd(previous_dir)); %#ok<NASGU>
    cd(manifest.project_root);

    prepare_parent_dir(manifest.log_path);
    prepare_parent_dir(manifest.status_path);

    diary_cleanup = [];
    status_manifest = manifest;

    try
        [diary_cleanup, actual_log_path, log_note] = start_diary_with_fallback(manifest.log_path);
        status_manifest.log_path = actual_log_path;

        running_message = "MATLAB handoff is running in the active session.";
        if strlength(string(log_note)) > 0
            running_message = char(string(running_message) + " " + string(log_note));
        end

        if strlength(string(manifest.status_path)) > 0
            write_matlab_handoff_status(manifest.status_path, "running", status_manifest, ...
                "message", running_message);
        end

        fprintf("=== MATLAB handoff runner start ===\n");
        fprintf("Manifest: %s\n", manifest.manifest_path);
        fprintf("Entry function: %s\n", manifest.entry_function);
        fprintf("Invoke style: %s\n", manifest.invoke_style);
        if strlength(string(actual_log_path)) > 0
            fprintf("Diary log: %s\n", actual_log_path);
        end
        if strlength(string(log_note)) > 0
            fprintf("%s\n", log_note);
        end

        invoke_manifest_entry(manifest);
        if strlength(string(manifest.status_path)) > 0
            write_matlab_handoff_status(manifest.status_path, "completed", status_manifest, ...
                "message", "MATLAB handoff completed successfully.");
        end
    catch ME
        report = getReport(ME, "extended", "hyperlinks", "off");
        fprintf(2, "%s\n", report);
        if strlength(string(manifest.status_path)) > 0
            write_matlab_handoff_status(manifest.status_path, "failed", status_manifest, ...
                "message", "MATLAB handoff failed.", ...
                "error_report", report);
        end
        rethrow(ME);
    end
end

function [diary_cleanup, actual_log_path, log_note] = start_diary_with_fallback(requested_log_path)
    diary_cleanup = [];
    actual_log_path = requested_log_path;
    log_note = "";

    if strlength(string(requested_log_path)) == 0
        return;
    end

    diary off;
    try
        diary(requested_log_path);
        diary on;
        diary_cleanup = onCleanup(@() diary("off")); %#ok<NASGU>
        return;
    catch primary_err
        fallback_log_path = build_fallback_log_path(requested_log_path);
        prepare_parent_dir(fallback_log_path);
        try
            diary(fallback_log_path);
            diary on;
            diary_cleanup = onCleanup(@() diary("off")); %#ok<NASGU>
            actual_log_path = fallback_log_path;
            log_note = sprintf("Primary diary path was locked. Using fallback log: %s", fallback_log_path);
            warning("%s", log_note);
            return;
        catch fallback_err
            error("Failed to open diary log. Primary path '%s' error: %s. Fallback path '%s' error: %s.", ...
                requested_log_path, primary_err.message, fallback_log_path, fallback_err.message);
        end
    end
end

function fallback_log_path = build_fallback_log_path(requested_log_path)
    [folder, stem, ext] = fileparts(requested_log_path);
    if strlength(string(ext)) == 0
        ext = ".log";
    end
    stamp = char(string(datetime("now", "Format", "yyyyMMdd_HHmmss")));
    fallback_log_path = fullfile(folder, sprintf("%s_session_%s%s", stem, stamp, ext));
end

function invoke_manifest_entry(manifest)
    switch string(manifest.invoke_style)
        case "manifest_path"
            feval(manifest.entry_function, manifest.manifest_path);
        case "function_args"
            feval(manifest.entry_function, manifest.function_args{:});
        otherwise
            error("Unsupported manifest invoke_style: %s", manifest.invoke_style);
    end
end

function prepare_parent_dir(target_path)
    if strlength(string(target_path)) == 0
        return;
    end

    parent_dir = fileparts(target_path);
    if strlength(string(parent_dir)) > 0 && exist(parent_dir, "dir") ~= 7
        mkdir(parent_dir);
    end
end
