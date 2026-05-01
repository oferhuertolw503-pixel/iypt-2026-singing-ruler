function results = run_pending_matlab_manifests(queue_path)
%RUN_PENDING_MATLAB_MANIFESTS Run the prepared MATLAB manifest queue.
%
%   Run from the project root after Codex/PowerShell prepares
%   outputs/automation/matlab_manifest_queue.json.

    if nargin < 1 || strlength(string(queue_path)) == 0
        queue_path = fullfile(pwd, "outputs", "automation", "matlab_manifest_queue.json");
    end

    results = run_matlab_manifest_queue(char(queue_path));
end
