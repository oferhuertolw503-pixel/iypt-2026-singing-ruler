function model = comsol_connect(mph_path)
%COMSOL_CONNECT Open a COMSOL model through LiveLink.

    arguments
        mph_path (1, :) char
    end

    ensure_livelink_on_path();
    if should_activate_managed_local_env()
        activate_local_comsol_env();
    end
    [model, opened_directly] = try_open_model_without_explicit_server(mph_path);
    if opened_directly
        return;
    end
    connect_if_requested();
    model = comsol_open_model(mph_path);
end

function [model, opened_directly] = try_open_model_without_explicit_server(mph_path)
    model = [];
    opened_directly = false;

    if should_skip_direct_open()
        return;
    end

    try
        model = comsol_open_model(mph_path);
        opened_directly = true;
        fprintf("Opened model through local COMSOL/LiveLink without explicit server startup.\n");
    catch ME
        if is_explicit_connection_needed_error(ME)
            fprintf("Direct local COMSOL open was not available; falling back to explicit LiveLink connection.\n");
            fprintf("Direct-open reason: %s\n", char(string(ME.message)));
            disconnect_livelink();
            model = [];
            opened_directly = false;
            return;
        end
        rethrow(ME);
    end
end

function connect_if_requested()
    host = string(getenv("TSR_COMSOL_HOST"));
    port = str2double(getenv("TSR_COMSOL_PORT"));
    username = string(getenv("TSR_COMSOL_USER"));
    password = string(getenv("TSR_COMSOL_PASSWORD"));
    comsol_root = detect_comsol_root();
    local_host = "127.0.0.1";

    if isfinite(port) && port > 0
        if strlength(strtrim(host)) == 0
            host = "localhost";
        end
        try
            connect_to_server(char(host), port, char(comsol_root), username, password);
        catch ME
            error("comsol_connect:ServerConnectionFailed", ...
                "Failed to connect to COMSOL server %s:%d. %s", ...
                char(host), port, char(string(ME.message)));
        end
        return;
    end

    if connect_to_preferred_existing_local_server(local_host, char(comsol_root), username, password)
        return;
    end

    if is_local_port_mode_requested()
        ports_text = join(string(get_preferred_local_comsol_ports()), ", ");
        error("comsol_connect:PreferredLocalServerNotFound", ...
            "Local COMSOL port mode is enabled, but no reachable server was found on preferred ports [%s]. Start comsolmphserver.exe first or set TSR_COMSOL_PORT explicitly.", ...
            char(ports_text));
    end

    [port, ~, proc] = start_local_server(comsol_root);
    try
        wait_for_local_server_connection(local_host, port, char(comsol_root), username, password, proc, 120);
    catch ME
        fprintf("Cached local COMSOL server %d is not usable; restarting local server.\n", port);
        reset_local_server_cache();
        disconnect_livelink();
        [port, ~, proc] = start_local_server(comsol_root);
        wait_for_local_server_connection(local_host, port, char(comsol_root), username, password, proc, 120);
    end
end

function tf = connect_to_preferred_existing_local_server(host, comsol_root, username, password)
    tf = false;
    preferred_ports = get_preferred_local_comsol_ports();
    for i = 1:numel(preferred_ports)
        probe_port = preferred_ports(i);
        if try_connect_existing_local_server(host, probe_port, comsol_root, username, password)
            fprintf("Reused existing local COMSOL server on port %d\n", probe_port);
            tf = true;
            return;
        end
    end
end

function connect_to_server(host, port, comsol_root, username, password)
    try
        do_mphstart(host, port, comsol_root, username, password);
        fprintf("Connected to COMSOL server %s:%d\n", host, port);
    catch ME
        lower_msg = lower(string(ME.message));
        if contains(lower_msg, "already connected")
            fprintf("COMSOL server already connected.\n");
            return;
        end

        % If a stale connection exists in the current MATLAB session, reset and retry once.
        try
            import com.comsol.model.util.*
            ModelUtil.disconnect();
        catch
        end

        try
            do_mphstart(host, port, comsol_root, username, password);
            fprintf("Connected to COMSOL server %s:%d after reconnect.\n", host, port);
            return;
        catch
            rethrow(ME);
        end
    end
end

function disconnect_livelink()
    try
        import com.comsol.model.util.*
        ModelUtil.disconnect();
    catch
    end
end

function do_mphstart(host, port, comsol_root, username, password)
    if strlength(strtrim(username)) > 0 || strlength(strtrim(password)) > 0
        mphstart(host, port, comsol_root, char(username), char(password));
    else
        mphstart(host, port, comsol_root);
    end
end

function [port, pid, proc] = start_local_server(comsol_root, reset_cache)
    persistent local_port local_pid local_proc

    if nargin < 2
        reset_cache = false;
    end
    if reset_cache
        local_port = [];
        local_pid = [];
        local_proc = [];
        port = [];
        pid = [];
        proc = [];
        return;
    end

    if ~isempty(local_port)
        if ~isempty(local_proc)
            try
                local_proc.Refresh();
                if local_proc.HasExited
                    local_port = [];
                    local_pid = [];
                    local_proc = [];
                end
            catch
                local_port = [];
                local_pid = [];
                local_proc = [];
            end
        end
    end

    if ~isempty(local_port)
        port = local_port;
        pid = local_pid;
        proc = local_proc;
        return;
    end

    state = get_local_comsol_state();
    port = get_default_local_comsol_port();
    [pid, proc] = launch_local_mphserver( ...
        comsol_root, ...
        state.configuration_dir, ...
        state.data_dir, ...
        state.prefs_dir, ...
        state.recovery_dir, ...
        state.tmp_dir, ...
        port);

    local_port = port;
    local_pid = pid;
    local_proc = proc;
    fprintf("Started local COMSOL server on port %d\n", port);
end

function activate_local_comsol_env()
    persistent env_cleanup active_state_root

    state = get_local_comsol_state();
    if isempty(env_cleanup) || ~strcmp(active_state_root, state.state_root)
        env_cleanup = push_local_comsol_env( ...
            state.home_dir, ...
            state.tmp_dir, ...
            state.appdata_dir, ...
            state.localappdata_dir);
        active_state_root = state.state_root;
    end
end

function state = get_local_comsol_state()
    project_root = detect_project_root();
    state_root = fullfile(project_root, ".codex_tmp", "matlab_livelink_state");

    state = struct();
    state.state_root = state_root;
    state.home_dir = fullfile(state_root, "home");
    state.configuration_dir = fullfile(state_root, "configuration");
    state.data_dir = fullfile(state_root, "data");
    state.prefs_dir = fullfile(state_root, "prefs");
    state.recovery_dir = fullfile(state_root, "recoveries");
    state.tmp_dir = fullfile(state_root, "tmp");
    state.appdata_dir = fullfile(state_root, "appdata");
    state.localappdata_dir = fullfile(state_root, "localappdata");

    ensure_dir(state.home_dir);
    ensure_dir(state.configuration_dir);
    ensure_dir(state.data_dir);
    ensure_dir(state.prefs_dir);
    ensure_dir(state.recovery_dir);
    ensure_dir(state.tmp_dir);
    ensure_dir(state.appdata_dir);
    ensure_dir(state.localappdata_dir);
end

function tf = should_activate_managed_local_env()
    host = string(getenv("TSR_COMSOL_HOST"));
    port = str2double(getenv("TSR_COMSOL_PORT"));
    use_system_local = string(getenv("TSR_COMSOL_USE_SYSTEM_LOCAL"));
    if strlength(strtrim(host)) > 0 || (isfinite(port) && port > 0) || is_local_port_mode_requested()
        tf = false;
        return;
    end
    tf = ~any(strcmpi(strtrim(use_system_local), ["1", "true", "yes", "on"]));
end

function tf = should_skip_direct_open()
    % Skip bare mphopen/mphload when the caller wants an explicit local-port workflow.
    host = string(getenv("TSR_COMSOL_HOST"));
    port = str2double(getenv("TSR_COMSOL_PORT"));
    use_system_local = string(getenv("TSR_COMSOL_USE_SYSTEM_LOCAL"));

    tf = strlength(strtrim(host)) > 0 || ...
        (isfinite(port) && port > 0) || ...
        is_local_port_mode_requested();
    if any(strcmpi(strtrim(use_system_local), ["1", "true", "yes", "on"]))
        tf = false;
    end
end
